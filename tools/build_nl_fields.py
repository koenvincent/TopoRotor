"""Rebuild decorative Dutch fields, never geography or mission coordinates.

Optional authoring dependency: uv run --with shapely python tools/build_nl_fields.py
The game only reads the committed JSON and needs no Python/Shapely at runtime.
"""
import hashlib
import json
import random
from pathlib import Path
from shapely import voronoi_polygons
from shapely.geometry import MultiPoint, Polygon
from shapely.ops import unary_union

path = Path(__file__).resolve().parents[1] / "data/map_nl.json"
data = json.loads(path.read_text())
land = unary_union([Polygon(ring) for country in data["countries"] if country["code"] == "NLD" for ring in country["polygons"]])
lakes = unary_union([Polygon(ring) for ring in data["lakes"]])
land = land.difference(lakes)
rng = random.Random(1206)
# Jittered seeds produce small irregular parcels rather than a national grid.
seeds = []
for row in range(53):
    for col in range(43):
        seeds.append((3.0 + col * .11 + rng.uniform(-.042, .042), 50.4 + row * .072 + rng.uniform(-.027, .027)))
cells = voronoi_polygons(MultiPoint(seeds))
fields = []
for cell in cells.geoms:
    clipped = cell.intersection(land).buffer(-.0008)
    polygons = [clipped] if clipped.geom_type == "Polygon" else list(getattr(clipped, "geoms", []))
    for polygon in polygons:
        if polygon.geom_type != "Polygon" or polygon.area < .00002:
            continue
        # Retain exact coast/lake clipping, using only exterior simple rings.
        if polygon.interiors:
            continue
        fields.append({"polygon": [[round(x, 6), round(y, 6)] for x, y in polygon.exterior.coords], "tone": rng.randrange(7)})
data["fields"] = fields
# Fingerprint of the lakes these fields were cut against; tools/check_data.py fails when the lakes change without a rebuild.
data["fields_lakes_sha"] = hashlib.sha1(json.dumps(data["lakes"], separators=(",", ":")).encode()).hexdigest()[:12]
path.write_text(json.dumps(data, separators=(",", ":")) + "\n")
print(f"Built {len(fields)} clipped decorative fields")
