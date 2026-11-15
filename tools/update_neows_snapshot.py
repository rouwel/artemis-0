#!/usr/bin/env python3
"""Fetch a key-free offline snapshot from NASA. Key comes only from the environment."""
import datetime
import json
import math
import os
import pathlib
import sys
import urllib.parse
import urllib.request

SOURCE = "https://api.nasa.gov/neo/rest/v1/feed"
DATES = ("2010-11-14", "2010-11-15")


def main():
    key = os.environ.get("NASA_API_KEY", "").strip()
    if not key:
        raise SystemExit("Set NASA_API_KEY before updating the snapshot.")
    query = urllib.parse.urlencode({"start_date": DATES[0], "end_date": DATES[1],
                                   "api_key": key})
    try:
        with urllib.request.urlopen(SOURCE + "?" + query, timeout=30) as response:
            raw = response.read(2097153)
        if len(raw) > 2097152:
            raise ValueError("Response exceeds limit")
        payload = json.loads(raw)
        records = {}
        for date, entries in payload["near_earth_objects"].items():
            if date not in DATES:
                raise ValueError("Wrong date range")
            for entry in entries:
                approach = next(a for a in entry["close_approach_data"]
                                if a["close_approach_date"] == date
                                and a["orbiting_body"] == "Earth")
                diameter = entry["estimated_diameter"]["meters"]
                record = {
                    "id": entry["neo_reference_id"], "name": entry["name"],
                    "date": date, "hazardous": entry["is_potentially_hazardous_asteroid"],
                    "absolute_magnitude_h": float(entry["absolute_magnitude_h"]),
                    "diameter_min_m": float(diameter["estimated_diameter_min"]),
                    "diameter_max_m": float(diameter["estimated_diameter_max"]),
                    "velocity_km_s": float(approach["relative_velocity"]["kilometers_per_second"]),
                    "miss_distance_km": float(approach["miss_distance"]["kilometers"]),
                    "miss_distance_lunar": float(approach["miss_distance"]["lunar"]),
                }
                if any(not math.isfinite(v) for v in record.values() if isinstance(v, float)):
                    raise ValueError("Nonfinite field")
                records[record["date"] + ":" + record["id"]] = record
        if not records or len(records) > 500:
            raise ValueError("Unexpected catalogue size")
    except Exception:
        # urllib exceptions can include the request URL and API key.
        raise SystemExit("NASA snapshot update failed. Existing snapshot retained.") from None
    data = {"schema_version": 1, "source": SOURCE, "period_start": DATES[0],
            "period_end": DATES[1],
            "retrieved_at": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z"),
            "records": [records[k] for k in sorted(records)]}
    destination = pathlib.Path(__file__).resolve().parents[1] / "data/neows_2010.json"
    destination.parent.mkdir(exist_ok=True)
    temporary = destination.with_suffix(".tmp")
    temporary.write_text(json.dumps(data, indent=2) + "\n")
    temporary.replace(destination)
    print(f"Saved {len(records)} NASA close-approach records to {destination.name}. No credentials included.")


if __name__ == "__main__":
    main()
