"""Import the Dutch rivers from Natural Earth 1:10m river centerlines.

python3 tools/import_nl_rivers.py /path/to/ne_10m_rivers_lake_centerlines.geojson

Replaces "rivers" in data/map_nl.json with the Rijn, Waal, Nederrijn, Lek,
IJssel and Maas, clipped to the map bounds and simplified. The earlier river
lines had no Maas or IJssel at all. Source revision and license are recorded
in THIRD-PARTY.md. No other data depends on the rivers (the fields, province
fills and city plans are cut against the lakes only), so nothing else needs a
rebuild; run tools/check_data.py afterwards.
"""
import json
import sys
from pathlib import Path

NAMES = ["Rhine", "Waal", "Nederrijn", "Lek", "IJssel", "Maas"]
# Degrees; about 300 m, well below a stroke on the map, and it keeps the meanders.
TOLERANCE = 0.003


def simplify(points, tolerance):
    """Douglas-Peucker on lon/lat pairs."""
    if len(points) < 3:
        return points
    (ax, ay), (bx, by) = points[0], points[-1]
    dx, dy = bx - ax, by - ay
    length = (dx * dx + dy * dy) ** 0.5
    worst, index = -1.0, 0
    for i in range(1, len(points) - 1):
        px, py = points[i]
        if length == 0:
            d = ((px - ax) ** 2 + (py - ay) ** 2) ** 0.5
        else:
            d = abs(dy * px - dx * py + bx * ay - by * ax) / length
        if d > worst:
            worst, index = d, i
    if worst <= tolerance:
        return [points[0], points[-1]]
    return simplify(points[:index + 1], tolerance)[:-1] + simplify(points[index:], tolerance)


def clip(points, box):
    """Pieces of a line inside box (lon0, lat0, lon1, lat1); an edge crossing gets a point on the edge."""
    x0, y0, x1, y1 = box

    def inside(p):
        return x0 <= p[0] <= x1 and y0 <= p[1] <= y1

    def crossing(a, b):
        # The point where segment a->b meets the box edge, walking from the inside point a.
        best = 1.0
        for i, (lo, hi) in enumerate([(x0, x1), (y0, y1)]):
            d = b[i] - a[i]
            for edge in (lo, hi):
                if d != 0:
                    t = (edge - a[i]) / d
                    if 0 <= t < best:
                        best = t
        return [a[0] + (b[0] - a[0]) * best, a[1] + (b[1] - a[1]) * best]

    pieces, current = [], []
    for i, p in enumerate(points):
        if inside(p):
            if not current and i > 0:
                current.append(crossing(p, points[i - 1]))
            current.append(p)
        elif current:
            current.append(crossing(points[i - 1], p))
            pieces.append(current)
            current = []
    if current:
        pieces.append(current)
    return [piece for piece in pieces if len(piece) > 1]


def main():
    source = json.loads(Path(sys.argv[1]).read_text())
    path = Path(__file__).resolve().parents[1] / "data/map_nl.json"
    data = json.loads(path.read_text())
    box = data["bounds"]
    rivers = []
    for name in NAMES:
        found = [f for f in source["features"] if f["properties"].get("name") == name]
        if not found:
            sys.exit(f"{name} not found in the source")
        for feature in found:
            geometry = feature["geometry"]
            lines = geometry["coordinates"] if geometry["type"] == "MultiLineString" else [geometry["coordinates"]]
            for line in lines:
                for piece in clip([[float(x), float(y)] for x, y, *_ in line], box):
                    rivers.append([[round(x, 6), round(y, 6)] for x, y in simplify(piece, TOLERANCE)])
    data["rivers"] = rivers
    path.write_text(json.dumps(data, separators=(",", ":")) + "\n")
    print(f"Imported {len(rivers)} river lines, {sum(len(r) for r in rivers)} points")


if __name__ == "__main__":
    main()
