#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
"""Record the README example using an already-built swift-sh executable."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess


root = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--executable", type=Path, default=root / ".build/release/swift-sh")
args = parser.parse_args()
executable = args.executable.resolve()
session = root / ".build/demo-session"
session.mkdir(parents=True, exist_ok=True)
shutil.copyfile(root / "Examples/version.swift", session / "version.swift")
environment = dict(os.environ, PATH=str(executable.parent) + os.pathsep + os.environ["PATH"],
                   XDG_CACHE_HOME=str(root / ".build/demo-cache"))
commands = []
for index, argv in enumerate([
    ["cat", "version.swift"],
    ["swift", "sh", "version.swift", "1.2.3"],
    ["swift", "sh", "version.swift", "2.4.0"],
]):
    result = subprocess.run(argv, cwd=session, env=environment, text=True, capture_output=True)
    (session / f"stderr-{index}.txt").write_text(result.stderr)
    result.check_returncode()
    commands.append({"command": shlex.join(argv), "stdout": result.stdout, "exit_code": result.returncode})
record = {"title": "swift-sh · inline package dependencies", "commands": commands}
(root / "Documentation/Assets/Demo-record.json").write_text(json.dumps(record, indent=2) + "\n")
provenance = {
    "source_revision": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip(),
    "executable_sha256": hashlib.sha256(executable.read_bytes()).hexdigest(),
    "example_sha256": hashlib.sha256((session / "version.swift").read_bytes()).hexdigest(),
    "swift": subprocess.check_output(["swift", "--version"], text=True).strip(),
    "swift_sh": subprocess.check_output([str(executable), "--version"], text=True).strip(),
    "dependency": "https://github.com/swift-library/swift-semver.git @ 0.1.1",
    "command_exit_codes": [item["exit_code"] for item in commands],
}
(session / "provenance.json").write_text(json.dumps(provenance, indent=2) + "\n")
print("Recorded example and two script runs")
