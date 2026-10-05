#!/usr/bin/env python3
"""Check evaluated SwiftPM settings and compile independent API/isolation tests."""

import json
from pathlib import Path
import shutil
import subprocess
import sys

workspace = Path(sys.argv[1]).resolve()
manifest = json.loads(subprocess.check_output(
    ["swift", "package", "--package-path", str(workspace), "dump-package"], text=True
))
expected = {"ExistentialAny", "MemberImportVisibility", "InternalImportsByDefault",
            "NonisolatedNonsendingByDefault"}
assert manifest["toolsVersion"]["_version"].startswith("6.3"), manifest["toolsVersion"]
assert manifest["swiftLanguageVersions"] == ["6"], manifest.get("swiftLanguageVersions")
assert [(p["platformName"], p["version"]) for p in manifest["platforms"]] == [("macos", "15.0")], manifest["platforms"]
assert {t["name"] for t in manifest["targets"]} == {
    "UtilityCore", "UtilityAdapter", "UtilityExtensions", "UtilityApp", "UtilityTests"
}
for target in manifest["targets"]:
    features = set()
    for setting in target["settings"]:
        assert "defaultIsolation" not in setting["kind"] and "unsafeFlags" not in setting["kind"], (target["name"], setting)
        if "enableUpcomingFeature" in setting["kind"]:
            assert not setting.get("condition"), (target["name"], setting)
            features.add(setting["kind"]["enableUpcomingFeature"]["_0"])
    assert features == expected, (target["name"], features)
tests = workspace / "Tests" / "UtilityTests" / "ContractTests.swift"
assert not tests.exists(), "Use a fresh eval workspace; do not overwrite an existing test"
shutil.copyfile(Path(__file__).with_name("ContractTests.swift"), tests)
try:
    subprocess.run(["swift", "test", "--package-path", str(workspace)], check=True)
    output = subprocess.check_output(
        ["swift", "run", "--package-path", str(workspace), "utility"], text=True
    )
    assert output.strip() == "utility: 42", output
finally:
    tests.unlink()
print("PASS: all target settings, independent API/actor tests, and executable behavior")
