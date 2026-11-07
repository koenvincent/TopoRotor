"""Run engine checks in an isolated profile and fail on Godot script errors."""
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

root = Path(__file__).resolve().parents[1]
engine = os.environ.get("GODOT_BIN", "godot")
with tempfile.TemporaryDirectory(prefix="toporotor-check-") as profile:
    env = {**os.environ, "XDG_DATA_HOME": profile, "XDG_CONFIG_HOME": profile, "XDG_CACHE_HOME": profile}
    for args in [["--editor", "--import", "--quit"], ["--", "--smoke-test"]]:
        result = subprocess.run([engine, "--headless", "--path", str(root), *args], capture_output=True, text=True, timeout=120, env=env)
        log = result.stdout + result.stderr
        print(log)
        if result.returncode or re.search(r"(?m)^(SCRIPT ERROR|ERROR:)", log):
            sys.exit(1)
        if "--smoke-test" in args and "SMOKE TEST PASSED" not in log:
            sys.exit("Game did not complete its checks")
