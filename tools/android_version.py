"""Stamp the Android version into export_presets.cfg for CI exports.

versionName: major.minor from project.godot config/version plus the run number
(0.4.57), or the tag without its leading "v" for v* tag builds.
versionCode: VERSION_CODE_BASE + run number * 100 + run attempt, so reruns increase too.
Fails when a version key is not found exactly once, so nothing is shipped unstamped.
"""
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
# Raise this above the last released versionCode if the workflow's run counter ever
# restarts (workflow renamed or recreated); Android refuses lower codes as downgrades.
VERSION_CODE_BASE = 1000


def project_major_minor(project_text):
    m = re.search(r'(?m)^config/version="(\d+)\.(\d+)(?:\.[^"]*)?"$', project_text)
    if not m:
        sys.exit('project.godot: config/version="<major>.<minor>[.<patch>]" not found')
    return f'{m.group(1)}.{m.group(2)}'


def version_name(project_text, env):
    if env.get('GITHUB_REF_TYPE') == 'tag':
        tag = env.get('GITHUB_REF_NAME', '')
        if not re.fullmatch(r'v\d[0-9A-Za-z.+_-]*', tag):
            sys.exit(f'Tag {tag!r} is not usable as an Android versionName (expected v<number>...)')
        return tag[1:]
    return f'{project_major_minor(project_text)}.{int(env["GITHUB_RUN_NUMBER"])}'


def version_code(env):
    attempt = int(env.get('GITHUB_RUN_ATTEMPT', '1'))
    if not 1 <= attempt < 100:
        sys.exit(f'GITHUB_RUN_ATTEMPT {attempt} is outside 1..99')
    return VERSION_CODE_BASE + int(env['GITHUB_RUN_NUMBER']) * 100 + attempt


def stamp(preset_text, code, name):
    text, n_code = re.subn(r'(?m)^version/code=\d+$', f'version/code={code}', preset_text)
    text, n_name = re.subn(r'(?m)^version/name="[^"]*"$', lambda _: f'version/name="{name}"', text)
    if n_code != 1 or n_name != 1:
        sys.exit(f'export_presets.cfg: expected exactly one version/code and one version/name line (found code={n_code}, name={n_name})')
    return text


def main(env=os.environ, root=ROOT):
    if 'GITHUB_RUN_NUMBER' not in env:
        sys.exit('GITHUB_RUN_NUMBER is not set; this script is meant for CI exports')
    name = version_name((root / 'project.godot').read_text(), env)
    code = version_code(env)
    preset = root / 'export_presets.cfg'
    preset.write_text(stamp(preset.read_text(), code, name))
    print(f'Android version {name} (code {code})')
    if env.get('GITHUB_OUTPUT'):
        with open(env['GITHUB_OUTPUT'], 'a') as out:
            out.write(f'version_name={name}\nversion_code={code}\n')


if __name__ == '__main__':
    main()
