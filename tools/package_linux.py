#!/usr/bin/env python3
"""Verify, export and package the Linux demo using the pinned Godot version."""

import hashlib
import pathlib
import shutil
import subprocess
import tarfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
BUILD = ROOT / "build" / "linux"
DIST = ROOT / "dist"
GODOT = ["mise", "exec", "--", "godot"]


def run(arguments, cwd=ROOT):
    result = subprocess.run(arguments, cwd=cwd, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, timeout=600)
    print(result.stdout, flush=True)
    if result.returncode or any(marker in result.stdout for marker in
                               ("SCRIPT ERROR:", "\nERROR:", "FAILURES")):
        raise SystemExit(f"Check failed: {' '.join(map(str, arguments))}")
    return result.stdout


def main():
    BUILD.mkdir(parents=True, exist_ok=True)
    DIST.mkdir(parents=True, exist_ok=True)
    (BUILD.parent / ".gdignore").touch()
    (DIST / ".gdignore").touch()
    run(GODOT + ["--headless", "--editor", "--path", ".", "--import"])
    for script in ("test_life_support.gd", "test_mission.gd", "test_greenhouse_api.gd"):
        run(GODOT + ["--headless", "--path", ".", "--script", f"tools/{script}"])
    run(GODOT + ["--headless", "--path", ".", "--export-release", "Linux"])
    binary = BUILD / "artemis-0.x86_64"
    binary.chmod(binary.stat().st_mode | 0o111)
    smoke = run([str(binary), "--headless", "--quit-after", "300",
                 "--", "--smoke-test"], cwd=BUILD)
    if "Packaged mission smoke test: PASS" not in smoke:
        raise SystemExit("Packaged mission did not reach the smoke-test checkpoint.")
    for name in ("README.md", "INTERACTIONS.md", "CREDITS.md"):
        shutil.copy2(ROOT / name, BUILD / name)
    shutil.copy2(ROOT / "assets" / "License.txt", BUILD / "Kenney-License.txt")
    run(GODOT + ["--headless", "--path", ".", "--script",
                 "tools/export_notices.gd", "--", str(BUILD)])
    package_artifacts()


def package_artifacts():
    archive = DIST / "artemis-0-linux-x86_64.tar.gz"
    temporary = archive.with_suffix(".gz.tmp")
    with tarfile.open(temporary, "w:gz", compresslevel=3) as bundle:
        bundle.add(BUILD, arcname="artemis-0-linux-x86_64")
    temporary.replace(archive)
    with archive.open("rb") as stream:
        digest = hashlib.file_digest(stream, "sha256").hexdigest()
    archive.with_suffix(archive.suffix + ".sha256").write_text(
        f"{digest}  {archive.name}\n")
    print(f"Linux release: {archive} ({archive.stat().st_size / 1048576:.1f} MiB)")


if __name__ == "__main__":
    main()
