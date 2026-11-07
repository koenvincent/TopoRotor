"""Assign increasing Android version codes to CI exports (including reruns)."""
import os
import re
from pathlib import Path

preset = Path('export_presets.cfg')
text = preset.read_text()
code = 1000 + int(os.environ['GITHUB_RUN_NUMBER']) * 100 + int(os.environ.get('GITHUB_RUN_ATTEMPT', '1'))
text = re.sub(r'version/code=\d+', f'version/code={code}', text)
text = re.sub(r'version/name="[^"]+"', f'version/name="0.4.{os.environ["GITHUB_RUN_NUMBER"]}"', text)
preset.write_text(text)
