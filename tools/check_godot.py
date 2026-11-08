"""Run engine checks in an isolated profile and fail on Godot script errors."""
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

TIMEOUT = 120


def text(data):
    return data.decode("utf-8", "replace") if isinstance(data, bytes) else data or ""


def run_engine(engine, root, args, env, timeout=TIMEOUT):
    """Return the combined engine log; on a hang print what was captured, then exit non-zero."""
    try:
        result = subprocess.run([engine, "--headless", "--path", str(root), *args], capture_output=True, text=True, timeout=timeout, env=env)
    except subprocess.TimeoutExpired as e:
        print(text(e.stdout) + text(e.stderr))
        sys.exit(f"Godot {' '.join(args)} timed out after {timeout} s")
    log = result.stdout + result.stderr
    print(log)
    if result.returncode or re.search(r"(?m)^(SCRIPT ERROR|ERROR:)", log):
        sys.exit(1)
    return log


def main():
    root = Path(__file__).resolve().parents[1]
    engine = os.environ.get("GODOT_BIN", "godot")
    with tempfile.TemporaryDirectory(prefix="toporotor-check-") as profile:
        env = {**os.environ, "XDG_DATA_HOME": profile, "XDG_CONFIG_HOME": profile, "XDG_CACHE_HOME": profile}
        for args in [["--editor", "--import", "--quit"], ["--", "--smoke-test"]]:
            log = run_engine(engine, root, args, env)
            if "--smoke-test" in args and "SMOKE TEST PASSED" not in log:
                sys.exit("Game did not complete its checks")


if __name__ == "__main__":
    main()
