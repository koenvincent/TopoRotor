import importlib.util
import io
import os
import stat
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def load(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / "tools" / f"{name}.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


android_version = load("android_version")
check_godot = load("check_godot")

PRESET = 'name="Android"\nversion/code=4\nversion/name="0.4.0"\nversion/other=1\n'


class AndroidVersionTests(unittest.TestCase):
    def project(self, version='0.4.0'):
        return f'[application]\nconfig/version="{version}"\n'

    def test_name_comes_from_project_version_and_run_number(self):
        env = {"GITHUB_RUN_NUMBER": "57"}
        self.assertEqual(android_version.version_name(self.project("0.4.0"), env), "0.4.57")
        self.assertEqual(android_version.version_name(self.project("0.5.2"), env), "0.5.57")

    def test_tag_build_uses_tag_as_name(self):
        env = {"GITHUB_RUN_NUMBER": "57", "GITHUB_REF_TYPE": "tag", "GITHUB_REF_NAME": "v1.0.0"}
        self.assertEqual(android_version.version_name(self.project(), env), "1.0.0")
        env["GITHUB_REF_NAME"] = 'vx"; rm'
        with self.assertRaises(SystemExit):
            android_version.version_name(self.project(), env)

    def test_code_increases_with_run_and_attempt(self):
        a = android_version.version_code({"GITHUB_RUN_NUMBER": "5"})
        b = android_version.version_code({"GITHUB_RUN_NUMBER": "5", "GITHUB_RUN_ATTEMPT": "2"})
        c = android_version.version_code({"GITHUB_RUN_NUMBER": "6"})
        self.assertLess(a, b)
        self.assertLess(b, c)
        with self.assertRaises(SystemExit):
            android_version.version_code({"GITHUB_RUN_NUMBER": "5", "GITHUB_RUN_ATTEMPT": "100"})

    def test_missing_project_version_fails(self):
        with self.assertRaises(SystemExit):
            android_version.version_name("[application]\n", {"GITHUB_RUN_NUMBER": "1"})

    def test_stamp_replaces_both_keys(self):
        out = android_version.stamp(PRESET, 1234, "0.4.9")
        self.assertIn("version/code=1234\n", out)
        self.assertIn('version/name="0.4.9"\n', out)
        self.assertIn("version/other=1\n", out)
        self.assertIn('version/name="0.4.9"', android_version.stamp(PRESET.replace('"0.4.0"', '""'), 1, "0.4.9"))

    def test_stamp_fails_when_nothing_or_too_much_matches(self):
        for bad in ('version/name="0.4.0"\n', "version/code=4\n", PRESET + PRESET, PRESET.replace("version/code=4", 'version/code="4"')):
            with self.assertRaises(SystemExit, msg=bad):
                android_version.stamp(bad, 1, "0.4.9")

    def test_main_writes_preset_and_output(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "project.godot").write_text(self.project())
            (root / "export_presets.cfg").write_text(PRESET)
            env = {"GITHUB_RUN_NUMBER": "7", "GITHUB_OUTPUT": str(root / "out")}
            with redirect_stdout(io.StringIO()):
                android_version.main(env, root)
            self.assertIn('version/name="0.4.7"', (root / "export_presets.cfg").read_text())
            self.assertIn("version_name=0.4.7\n", (root / "out").read_text())
            (root / "export_presets.cfg").write_text("name=1\n")
            with self.assertRaises(SystemExit), redirect_stdout(io.StringIO()):
                android_version.main(env, root)


class CheckGodotTests(unittest.TestCase):
    def fake_engine(self, tmp, body):
        path = Path(tmp) / "engine"
        path.write_text("#!/bin/sh\n" + body)
        path.chmod(path.stat().st_mode | stat.S_IEXEC)
        return str(path)

    def test_hang_still_prints_engine_output(self):
        with tempfile.TemporaryDirectory() as tmp:
            engine = self.fake_engine(tmp, "echo partial-engine-output\necho partial-stderr >&2\nsleep 30\n")
            out = io.StringIO()
            with redirect_stdout(out), self.assertRaises(SystemExit) as cm:
                check_godot.run_engine(engine, ROOT, ["--smoke-test"], os.environ.copy(), timeout=1)
            self.assertIn("partial-engine-output", out.getvalue())
            self.assertIn("timed out", str(cm.exception))

    def test_script_error_fails_and_clean_run_passes(self):
        with tempfile.TemporaryDirectory() as tmp:
            bad = self.fake_engine(tmp, "echo 'SCRIPT ERROR: boom'\n")
            with redirect_stdout(io.StringIO()), self.assertRaises(SystemExit):
                check_godot.run_engine(bad, ROOT, [], os.environ.copy())
            good = self.fake_engine(tmp, "echo 'SMOKE TEST PASSED'\n")
            with redirect_stdout(io.StringIO()):
                self.assertIn("SMOKE TEST PASSED", check_godot.run_engine(good, ROOT, [], os.environ.copy()))


if __name__ == "__main__":
    unittest.main()
