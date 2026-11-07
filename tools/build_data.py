"""Rebuild the generated game data in dependency order, then validate it.

uv run --with shapely python tools/build_data.py --admin-source work/admin-source --source-updated 2026-01-28 \\
    --urban-areas /path/to/ne_10m_urban_areas.geojson --eu-source /path/to/ne_10m_admin_0_countries_nld.geojson \\
    [--lakes /path/to/ne_10m_lakes.geojson]

Order matters: the lakes in data/map_nl.json are the base. The decorative fields, the province fills and the
city plans are cut against them and record a fingerprint (lakes_sha) that tools/check_data.py compares.
  1. tools/import_nl_lakes.py      (only with --lakes)
  2. tools/build_nl_fields.py
  3. tools/build_admin_boundaries.py
  4. tools/build_city_plans.py --keep-existing   (a full rebuild of the plans is documented there)
  5. tools/build_eu_map.py         (independent of the lakes)
  6. tools/check_data.py
Steps 3 to 5 run only when their source is given; with --lakes, steps 3 and 4 are required.
"""
import argparse
import subprocess
import sys
from pathlib import Path

TOOLS = Path(__file__).resolve().parent


def run(script, *args):
    print("==", script, *args, flush=True)
    subprocess.run([sys.executable, str(TOOLS / script), *map(str, args)], check=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--lakes", type=Path)
    parser.add_argument("--admin-source", type=Path)
    parser.add_argument("--source-updated")
    parser.add_argument("--urban-areas", type=Path)
    parser.add_argument("--eu-source", type=Path)
    parser.add_argument("--pov", default="NLD", choices=["NLD", "UKR"])
    args = parser.parse_args()
    if args.lakes and not (args.admin_source and args.urban_areas):
        parser.error("--lakes makes the province fills and city plans stale; give --admin-source and --urban-areas too")
    if args.admin_source and not args.source_updated:
        parser.error("--admin-source needs --source-updated")
    if args.lakes:
        run("import_nl_lakes.py", args.lakes)
    run("build_nl_fields.py")
    if args.admin_source:
        run("build_admin_boundaries.py", args.admin_source, "--source-updated", args.source_updated)
    if args.urban_areas:
        run("build_city_plans.py", args.urban_areas, "--keep-existing")
    if args.eu_source:
        run("build_eu_map.py", args.eu_source, "--pov", args.pov)
    run("check_data.py")


if __name__ == "__main__":
    main()
