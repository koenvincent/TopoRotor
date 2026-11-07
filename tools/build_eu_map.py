"""Rebuild the country outlines of data/map_eu.json from Natural Earth admin-0.

uv run --with shapely python tools/build_eu_map.py /path/to/ne_10m_admin_0_countries_nld.geojson --pov NLD

Source: Natural Earth 1:10m Cultural Vectors, admin-0 countries *with an explicit point of view*
(https://github.com/nvkelso/natural-earth-vector/tree/master/geojson). The NLD file follows the
Dutch position (Crimea is Ukraine, Northern Cyprus is Cyprus); UKR works too. The default
ne_10m_admin_0_countries.geojson follows de-facto control and must NOT be used: it puts Crimea in Russia.
Natural Earth is public domain.

What this script does:
  - clips to BOUNDS, merges Aland into Finland, drops the British enclaves (Gibraltar, Cyprus bases),
  - simplifies topologically (shared borders keep identical vertices, which world.gd relies on),
  - writes outer rings only (the game has no holes), clockwise, rounded to 6 decimals,
  - keeps rivers and lakes of the existing data/map_eu.json untouched (their origin was never recorded),
  - writes one country per line so a change is reviewable.
Run tools/check_data.py afterwards.
"""
import argparse
import hashlib
import json
import sys
from pathlib import Path
from shapely.geometry import LineString, Polygon, box, shape
from shapely.geometry.polygon import orient
from shapely.ops import linemerge, polygonize, unary_union

ROOT = Path(__file__).resolve().parents[1]
BOUNDS = [-25, 34, 45, 72]  # [minLon, minLat, maxLon, maxLat], WGS84. Also the playable area.
TOLERANCE = 0.04  # Douglas-Peucker tolerance in degrees
MIN_RING_AREA = 0.006  # square degrees; smaller islands are dropped ...
ALWAYS_KEEP = {"MCO", "SMR", "LIE", "AND", "MLT", "JEY", "GGY", "IMN", "FRO"}  # ... except these countries
MERGE = {"ALD": "FIN"}  # Aland is Finnish; the game used to merge it at load time
DROP = {"ESB", "WSB", "GIB"}  # British enclaves inside Cyprus and Spain, far below the ring threshold
CODE_FIX = {"KOS": "XKX"}  # Kosovo has no ISO 3166-1 code; XKX is the user-assigned code in common use
# The real Vatican is 0.44 km2, too small to hover over. The game used a 1.5 km circle around the
# catalog point; this square (about 2 x 2 km) keeps that reach and is NOT the true outline.
MARKER_RINGS = {"VAT": (12.453, 41.904, 0.014, 0.010)}  # lon, lat, half-width lon, half-height lat
# Country order of the first committed map_eu.json (Aland and Northern Cyprus gone). world.gd colours countries
# by list position, so a stable order keeps the map from reshuffling its greens on every rebuild.
ORDER = ("VAT JEY GGY IMN GBR UKR TUR TUN SYR CHE SWE ESP SVK SVN SRB SMR RUS ROU PRT POL NOR NLD MAR MNE MDA MCO MLT "
         "MKD LUX LTU LIE LBN LVA XKX ITA IRL IRQ IRN ISL HUN GRC DEU GEO FRA FIN EST GRL FRO DNK CZE CYP HRV BGR BIH "
         "BEL BLR AZE AUT ARM AND DZA ALB").split()
URL = "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/{ref}/geojson/ne_10m_admin_0_countries_{pov}.geojson"
# Last commit touching ne_10m_admin_0_countries_nld.geojson (2022-05-13); the URL above resolves to the same bytes.
SOURCE_REF = "9380cca83db5f9aef52d5e762765100745f84b27"


def rounded(coords):
    return [(round(x, 6), round(y, 6)) for x, y in coords]


def clean(coords):
    """Round to 6 decimals and drop the repeats rounding can create."""
    ring = []
    for point in rounded(coords):
        if not ring or point != tuple(ring[-1]):
            ring.append(list(point))
    return ring


def on_frame(point):
    return point[0] in (BOUNDS[0], BOUNDS[2]) or point[1] in (BOUNDS[1], BOUNDS[3])


def split_at_frame(arc):
    points = list(arc.coords)
    cuts = [0] + [i for i in range(1, len(points) - 1) if on_frame(points[i])] + [len(points) - 1]
    return [LineString(points[a:b + 1]) for a, b in zip(cuts, cuts[1:])]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("--pov", required=True, choices=["NLD", "UKR"])
    parser.add_argument("--source-ref", default=SOURCE_REF)
    args = parser.parse_args()
    target = ROOT / "data/map_eu.json"
    previous = json.loads(target.read_text())
    raw = args.source.read_bytes()
    features = json.loads(raw)["features"]
    frame = box(*BOUNDS)
    names = {f["properties"]["ADM0_A3"]: f["properties"]["ADMIN"] for f in features}
    by_name = {f["properties"]["ADMIN"]: f["properties"]["ADM0_A3"] for f in features}
    shapes, meta, clipped = {}, {}, set()
    for feature in features:
        props = feature["properties"]
        code = props["ADM0_A3"]
        geometry = shape(feature["geometry"])
        if code in DROP or not geometry.intersects(frame):
            continue
        cut = geometry.intersection(frame)
        # Clipped means a part really crosses the frame (overseas parts far outside it do not count).
        if any(part.intersects(frame) and not frame.contains(part) for part in (geometry.geoms if hasattr(geometry, "geoms") else [geometry])):
            clipped.add(MERGE.get(code, code))
        code = MERGE.get(code, code)
        shapes.setdefault(code, []).append(cut)
        sovereign = by_name.get(props["SOVEREIGNT"], code)
        meta.setdefault(code, {"name": names[code], "part_of": sovereign if sovereign != code else None})
    pieces = []  # (code, outer ring polygon); holes are not representable in the game format
    for code, parts in shapes.items():
        merged = unary_union(parts)
        for part in merged.geoms if hasattr(merged, "geoms") else [merged]:
            if part.geom_type == "Polygon":
                pieces.append((code, Polygon(part.exterior)))
    # Topological simplification: node all rings, simplify every arc once, rebuild the faces.
    noded = linemerge(unary_union([piece.exterior for _, piece in pieces]))
    arcs = list(noded.geoms) if hasattr(noded, "geoms") else [noded]
    # Short arcs get a proportionally smaller tolerance, so Monaco-sized outlines do not collapse. Arcs are also cut
    # wherever they touch the frame, so clip edges stay exactly on the frame instead of being cut across.
    simple = unary_union([LineString(rounded(piece.simplify(min(TOLERANCE, piece.length / 20), preserve_topology=True).coords))
                          for arc in arcs for piece in split_at_frame(arc)])
    rings = {}
    for face in polygonize(simple):
        inside = face.representative_point()
        owners = sorted((piece.area, code) for code, piece in pieces if piece.contains(inside))
        if owners:  # the smallest containing outline wins, so San Marino stays out of Italy
            rings.setdefault(owners[0][1], []).append(Polygon(face.exterior))
    countries = []
    for code in sorted(rings):
        faces = sorted(rings[code], key=lambda p: -p.area)
        keep = [f for f in faces if f.area >= MIN_RING_AREA] or ([faces[0]] if code in ALWAYS_KEEP else [])
        if not keep or code in MARKER_RINGS:  # markers replace the real outline below
            continue
        out_code = CODE_FIX.get(code, code)
        entry = {"name": meta[code]["name"], "code": out_code}
        if meta[code]["part_of"]:
            entry["part_of"] = CODE_FIX.get(meta[code]["part_of"], meta[code]["part_of"])
        if code in clipped:
            entry["clipped"] = True
        entry["polygons"] = [clean(orient(f, -1).exterior.coords) for f in keep]
        countries.append(entry)
    for code, (lon, lat, dx, dy) in MARKER_RINGS.items():
        countries.append({"name": names[code], "code": code, "marker": True,
                          "polygons": [rounded([(lon - dx, lat + dy), (lon + dx, lat + dy), (lon + dx, lat - dy), (lon - dx, lat - dy), (lon - dx, lat + dy)])]})
    countries.sort(key=lambda c: (ORDER.index(c["code"]) if c["code"] in ORDER else len(ORDER), c["code"]))
    header = {
        "format_version": 1,
        "generator": "tools/build_eu_map.py",
        "source": "Natural Earth 1:10m admin-0 countries, point of view " + args.pov,
        "source_url": URL.format(ref=args.source_ref, pov=args.pov.lower()),
        "source_sha256": hashlib.sha256(raw).hexdigest(),
        "license": "Public domain (Natural Earth)",
        "pov": args.pov,
        "pov_note": "Internationally recognised borders (Dutch and EU position): Crimea is part of Ukraine, Northern Cyprus part of Cyprus, Aland part of Finland.",
        "crs": "EPSG:4326",
        "coord_order": "lon,lat",
        "bounds_order": "minLon,minLat,maxLon,maxLat",
        "clip": "Rings are clipped to bounds. Vertices on lat 34, lat 72, lon -25 or lon 45 are clip edges, not coast or border; countries cut this way carry clipped:true.",
        "ring_format": "countries[].polygons is a list of outer rings, clockwise, closed, no holes. A country may have several rings (islands, exclaves). Enclaves such as San Marino overlap the ring of the surrounding country.",
        "codes": "ISO 3166-1 alpha-3. XKX (Kosovo) is user-assigned, not an ISO code. part_of names the sovereign state of a dependency (JEY, GGY, IMN, FRO, GRL).",
        "markers": "Entries with marker:true (VAT) are enlarged stand-ins for a country too small to draw or hit at map scale.",
        "simplify_tolerance_deg": TOLERANCE,
        "min_ring_area_deg2": MIN_RING_AREA,
        "rivers_lakes": "Carried over unchanged from the previous data/map_eu.json; their source was not recorded.",
    }
    lines = ['{"meta":' + json.dumps(header, separators=(",", ":"), ensure_ascii=False) + ',',
             '"bounds":' + json.dumps(BOUNDS) + ',', '"countries":[']
    lines.append(",\n".join(json.dumps(c, separators=(",", ":"), ensure_ascii=False) for c in countries))
    lines.append('],\n"rivers":[')
    lines.append(",\n".join(json.dumps(r, separators=(",", ":")) for r in previous["rivers"]))
    lines.append('],\n"lakes":[')
    lines.append(",\n".join(json.dumps(r, separators=(",", ":")) for r in previous["lakes"]))
    lines.append("]}")
    target.write_text("\n".join(lines) + "\n")
    print(f"Wrote {len(countries)} countries, {sum(len(c['polygons']) for c in countries)} rings")


if __name__ == "__main__":
    sys.exit(main())
