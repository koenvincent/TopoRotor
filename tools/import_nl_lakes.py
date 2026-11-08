"""Import Natural Earth's IJsselmeer without filling its Flevoland holes.

uv run --with shapely python tools/import_nl_lakes.py /path/to/ne_10m_lakes.geojson
Source revision and license are recorded in THIRD-PARTY.md.
"""
import json
import sys
from pathlib import Path
from shapely.geometry import LineString, Polygon, shape
from shapely.ops import split

source=json.loads(Path(sys.argv[1]).read_text())
feature=next(f for f in source["features"] if f["properties"].get("name")=="IJsselmeer")
pending=[shape(feature["geometry"]).simplify(.0015,preserve_topology=True)]
rings=[]
while pending:
    polygon=pending.pop()
    if polygon.interiors:
        # The game's rings are simple polygons. Split water through each island
        # rather than throwing away holes (which would flood reclaimed land).
        point=Polygon(polygon.interiors[0]).representative_point()
        pieces=split(polygon,LineString([(-25,point.y),(45,point.y)]))
        if len(pieces.geoms)<2:
            raise ValueError("Could not split an interior lake ring")
        pending.extend(pieces.geoms)
    else:
        rings.append([[round(x,6),round(y,6)] for x,y in polygon.exterior.coords])
path=Path(__file__).resolve().parents[1]/"data/map_nl.json"
data=json.loads(path.read_text())
data["lakes"]=rings
path.write_text(json.dumps(data,separators=(",",":"))+"\n")
print(f"Imported {len(rings)} water polygons preserving islands/polders")
print("The fields, province fills and city plans are cut against these lakes and are now stale. "
      "Rebuild them in order (tools/build_data.py does this), then run tools/check_data.py.")
