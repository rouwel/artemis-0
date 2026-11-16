extends Node
## Historical catalogue only; never mutates the fictional mission.
signal updated

const SOURCE := "https://api.nasa.gov/neo/rest/v1/feed"
const START_DATE := "2010-11-14"
const END_DATE := "2010-11-15"
const SNAPSHOT := "res://data/neows_2010.json"
const CACHE := "user://neows_2010_cache.json"
const MAX_BYTES := 2097152
const MAX_RECORDS := 500

var records: Array = []
var retrieved_at := ""
var source_mode := "Bundled snapshot"
var status := "Loading historical NASA catalogue."
var busy := false
var _request: HTTPRequest
var _next_request_msec := 0

func _ready() -> void:
	_request = HTTPRequest.new()
	_request.timeout = 10.0
	_request.body_size_limit = MAX_BYTES
	_request.max_redirects = 2
	add_child(_request)
	_request.request_completed.connect(_on_response)
	load_offline()

func load_offline() -> void:
	var bundled := validate_snapshot(_read_json(SNAPSHOT))
	var cached := validate_snapshot(_read_json(CACHE))
	var selected := bundled
	source_mode = "Bundled snapshot"
	if cached.get("ok", false) and (not bundled.get("ok", false) or str(cached.data.retrieved_at) >= str(bundled.data.retrieved_at)):
		selected = cached
		source_mode = "Saved NASA response"
	if selected.get("ok", false):
		records = selected.data.records
		retrieved_at = selected.data.retrieved_at
		status = "Historical close approaches loaded from offline data." if OS.has_feature("web") else "Historical close approaches loaded. Internet is optional."
	else:
		records = []
		status = "No valid offline catalogue available." if OS.has_feature("web") else "No valid offline catalogue available. Configure a NASA key and refresh."
	updated.emit()

func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		return null
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return null
	return parser.data

func has_api_key() -> bool:
	if OS.has_feature("web"):
		return false
	return not _api_key().is_empty()

func _api_key() -> String:
	var key := OS.get_environment("NASA_API_KEY").strip_edges()
	if key.is_empty():
		var config := ConfigFile.new()
		if config.load("user://nasa.cfg") == OK:
			key = str(config.get_value("api", "key", "")).strip_edges()
	return key

func refresh_catalogue() -> void:
	if OS.has_feature("web"):
		status = "Browser edition uses the bundled historical catalogue. Live refresh is available in the Linux build."
		updated.emit()
		return
	if busy:
		return
	if Time.get_ticks_msec() < _next_request_msec:
		status = "Refresh cooldown active. The loaded catalogue remains available."
		updated.emit()
		return
	var key := _api_key()
	if key.is_empty():
		status = "Offline catalogue available. To refresh, set NASA_API_KEY or [api] key in user://nasa.cfg, then restart or refresh."
		updated.emit()
		return
	busy = true
	status = "Fetching the historical 2010 catalogue from NASA…"
	_next_request_msec = Time.get_ticks_msec() + 60000
	updated.emit()
	var url := SOURCE + "?start_date=" + START_DATE + "&end_date=" + END_DATE + "&api_key=" + key.uri_encode()
	if _request.request(url) != OK:
		busy = false
		status = "NASA request could not start. Using the loaded offline data."
		updated.emit()

func _on_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	busy = false
	if response_code == 429:
		_next_request_msec = Time.get_ticks_msec() + 300000
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200 or body.size() > MAX_BYTES:
		status = "NASA refresh unavailable (HTTP %d). Loaded data retained; retry later." % response_code
		updated.emit()
		return
	var parser := JSON.new()
	if parser.parse(body.get_string_from_utf8()) != OK:
		status = "NASA returned unreadable data. Loaded data retained."
		updated.emit()
		return
	var parsed := parse_feed(parser.data)
	if not parsed.ok:
		status = "NASA response did not match the expected historical schema. Loaded data retained."
		updated.emit()
		return
	records = parsed.records
	retrieved_at = Time.get_datetime_string_from_system(true) + "Z"
	source_mode = "Fetched from NASA"
	status = "NASA historical catalogue updated. These are 2010 encounters, not live radar readings."
	var snapshot := {"schema_version": 1, "source": SOURCE, "period_start": START_DATE,
		"period_end": END_DATE, "retrieved_at": retrieved_at, "records": records}
	# Only normalized, key-free fields are persisted. Never save raw API links.
	var temporary := CACHE + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(snapshot))
		file.close()
		if DirAccess.rename_absolute(temporary, CACHE) != OK:
			status += " Disk cache unavailable; data usable for this session."
	else:
		status += " Disk cache unavailable; data usable for this session."
	updated.emit()

static func _numeric(value: Variant) -> float:
	if not (value is float or value is int or value is String):
		return NAN
	if value is String and not value.is_valid_float():
		return NAN
	var number := float(value)
	return number if is_finite(number) else NAN

static func _valid_record(record: Variant) -> bool:
	if not record is Dictionary:
		return false
	for key in ["id", "name", "date"]:
		if not record.get(key) is String or record[key].is_empty() or record[key].length() > 160:
			return false
	if record.date not in [START_DATE, END_DATE] or not record.get("hazardous") is bool:
		return false
	for key in ["absolute_magnitude_h", "diameter_min_m", "diameter_max_m", "velocity_km_s", "miss_distance_km", "miss_distance_lunar"]:
		if not (record.get(key) is int or record.get(key) is float):
			return false
		var value := _numeric(record.get(key))
		if not is_finite(value) or (key != "absolute_magnitude_h" and value < 0.0):
			return false
	return float(record.diameter_max_m) >= float(record.diameter_min_m)

static func validate_snapshot(payload: Variant) -> Dictionary:
	var invalid := {"ok": false}
	if not payload is Dictionary:
		return invalid
	if payload.get("schema_version") != 1 or payload.get("source") != SOURCE or payload.get("period_start") != START_DATE or payload.get("period_end") != END_DATE:
		return invalid
	if not payload.get("retrieved_at") is String or payload.retrieved_at.length() < 19 or payload.retrieved_at.length() > 30:
		return invalid
	if not payload.get("records") is Array or payload.records.size() > MAX_RECORDS:
		return invalid
	var seen := {}
	for record in payload.records:
		if not _valid_record(record):
			return invalid
		var key: String = record.id + ":" + record.date
		if seen.has(key):
			return invalid
		seen[key] = true
	return {"ok": true, "data": payload}

static func parse_feed(payload: Variant) -> Dictionary:
	var invalid := {"ok": false, "records": []}
	if not payload is Dictionary or not payload.get("near_earth_objects") is Dictionary:
		return invalid
	var output: Array = []
	var seen := {}
	var dates: Dictionary = payload.near_earth_objects
	if dates.is_empty() and payload.get("element_count", -1) != 0:
		return invalid
	for date in dates:
		if date not in [START_DATE, END_DATE] or not dates[date] is Array:
			return invalid
		for asteroid in dates[date]:
			if not asteroid is Dictionary:
				return invalid
			var diameter = asteroid.get("estimated_diameter", {})
			if not diameter is Dictionary or not diameter.get("meters") is Dictionary:
				return invalid
			var approaches = asteroid.get("close_approach_data")
			if not approaches is Array:
				return invalid
			var approach: Dictionary = {}
			for candidate in approaches:
				if candidate is Dictionary and candidate.get("close_approach_date") == date and candidate.get("orbiting_body") == "Earth":
					approach = candidate
					break
			if approach.is_empty() or not approach.get("relative_velocity") is Dictionary or not approach.get("miss_distance") is Dictionary:
				return invalid
			var record := {
				"id": asteroid.get("neo_reference_id"), "name": asteroid.get("name"), "date": date,
				"hazardous": asteroid.get("is_potentially_hazardous_asteroid"),
				"absolute_magnitude_h": _numeric(asteroid.get("absolute_magnitude_h")),
				"diameter_min_m": _numeric(diameter.meters.get("estimated_diameter_min")),
				"diameter_max_m": _numeric(diameter.meters.get("estimated_diameter_max")),
				"velocity_km_s": _numeric(approach.relative_velocity.get("kilometers_per_second")),
				"miss_distance_km": _numeric(approach.miss_distance.get("kilometers")),
				"miss_distance_lunar": _numeric(approach.miss_distance.get("lunar")),
			}
			if not _valid_record(record):
				return invalid
			var key: String = record.id + ":" + date
			if not seen.has(key):
				seen[key] = true
				output.append(record)
			if output.size() > MAX_RECORDS:
				return invalid
	output.sort_custom(func(a: Dictionary, b: Dictionary):
		return (a.date + ":" + a.id) < (b.date + ":" + b.id))
	return {"ok": true, "records": output}
