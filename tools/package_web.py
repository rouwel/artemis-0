#!/usr/bin/env python3
"""Verify and export the browser edition with Godot 4.7.2."""
import pathlib
import shutil
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[1]
BUILD = ROOT / "build" / "web"
GODOT = ["mise", "exec", "--", "godot"]


def run(*arguments):
    result = subprocess.run(arguments, cwd=ROOT, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, timeout=600)
    print(result.stdout, flush=True)
    if result.returncode or any(marker in result.stdout for marker in
                                ("SCRIPT ERROR:", "\nERROR:", "FAILURES")):
        raise SystemExit(f"Web build check failed: {' '.join(map(str, arguments))}")


def main():
    BUILD.mkdir(parents=True, exist_ok=True)
    (BUILD.parent / ".gdignore").touch()
    (BUILD / ".gdignore").touch()
    run(*(GODOT + ["--headless", "--editor", "--path", ".", "--import"]))
    for script in ("test_life_support.gd", "test_mission.gd", "test_greenhouse_api.gd"):
        run(*(GODOT + ["--headless", "--rendering-method", "gl_compatibility",
                      "--path", ".", "--script", f"tools/{script}"]))
    run(*(GODOT + ["--headless", "--path", ".", "--export-release", "Web"]))
    for name in ("index.html", "index.js", "index.wasm", "index.pck"):
        path = BUILD / name
        if not path.is_file() or path.stat().st_size == 0:
            raise SystemExit(f"Missing or empty web export file: {name}")
    if (BUILD / ".env.local").exists():
        raise SystemExit("Remove build/web/.env.local before serving or deploying the export")
    shutil.copy2(ROOT / "web" / "vercel.json", BUILD / "vercel.json")
    size = sum(p.stat().st_size for p in BUILD.iterdir() if p.is_file())
    # Hobby CLI uploads are limited to 100 MB of source files (decimal).
    if size >= 95_000_000:
        raise SystemExit(f"Web export is too large for Vercel Hobby: {size / 1_000_000:.1f} MB")
    print("Web export: %s (%.1f MB)" % (BUILD, size / 1_000_000))


if __name__ == "__main__":
    main()
