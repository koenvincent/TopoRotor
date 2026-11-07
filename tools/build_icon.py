"""Build the app icon (assets/icon.svg) and the Android adaptive icon layers
from the bundled Dutch outline: a rescue helicopter flying off a gold pin in
Brabant over the Netherlands, inside a compass ring.

    python3 tools/build_icon.py
"""
import json
import math
from pathlib import Path

root = Path(__file__).resolve().parents[1]
data = json.loads((root / "data/map_nl.json").read_text())
nld = next(c for c in data["countries"] if c["code"] == "NLD")
ring = max(nld["polygons"], key=len)
shrink = math.cos(math.radians(52.2))
points = [(lon * shrink, -lat) for lon, lat in ring]


def simplify(path, eps):
    """Douglas-Peucker on an open path."""
    if len(path) < 3:
        return path
    (x1, y1), (x2, y2) = path[0], path[-1]
    length = math.hypot(x2 - x1, y2 - y1) or 1e-9

    def dist(p):
        return abs((y2 - y1) * p[0] - (x2 - x1) * p[1] + x2 * y1 - y2 * x1) / length

    index = max(range(1, len(path) - 1), key=lambda i: dist(path[i]))
    if dist(path[index]) > eps:
        return simplify(path[: index + 1], eps)[:-1] + simplify(path[index:], eps)
    return [path[0], path[-1]]


half = len(points) // 2
outline = simplify(points[: half + 1], 0.02)[:-1] + simplify(points[half:] + [points[0]], 0.02)[:-1]
xs = [p[0] for p in outline]
ys = [p[1] for p in outline]
min_x, max_x, min_y, max_y = min(xs), max(xs), min(ys), max(ys)
box_x, box_y, box_w, box_h = 58, 138, 250, 300
scale = min(box_w / (max_x - min_x), box_h / (max_y - min_y))
off_x = box_x + (box_w - (max_x - min_x) * scale) / 2
off_y = box_y + (box_h - (max_y - min_y) * scale) / 2


def place(p):
    return ((p[0] - min_x) * scale + off_x, (p[1] - min_y) * scale + off_y)


land_path = "M" + " L".join(f"{x:.1f} {y:.1f}" for x, y in map(place, outline)) + " Z"
pin_x, pin_y = place((5.40 * shrink, -51.55))

DEFS = """<defs>
  <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#14566a"/><stop offset=".55" stop-color="#0b3340"/><stop offset="1" stop-color="#061a21"/></linearGradient>
  <radialGradient id="glow" cx=".62" cy=".38" r=".55"><stop offset="0" stop-color="#ffc35c" stop-opacity=".38"/><stop offset="1" stop-color="#ffc35c" stop-opacity="0"/></radialGradient>
  <linearGradient id="land" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#b9e07a"/><stop offset="1" stop-color="#5f9e4a"/></linearGradient>
  <linearGradient id="body" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ff9a4d"/><stop offset="1" stop-color="#d9531e"/></linearGradient>
  <linearGradient id="glass" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#e8fbff"/><stop offset="1" stop-color="#6fc3dc"/></linearGradient>
</defs>"""

HELI = """<ellipse cx="340" cy="398" rx="92" ry="16" fill="#06161c" fill-opacity=".4"/>
<g transform="translate(346 236) rotate(-10) scale(.84)" stroke="#071a21" stroke-width="9" stroke-linejoin="round" stroke-linecap="round">
  <ellipse cx="-10" cy="-84" rx="190" ry="26" fill="#ffffff" fill-opacity=".2" stroke="none"/>
  <path d="M-60 -22 L-196 -38 L-196 -6 L-60 28 Z" fill="url(#body)"/>
  <path d="M-188 -32 L-226 -106 L-192 -106 L-162 -30 Z" fill="url(#body)"/>
  <circle cx="-196" cy="-26" r="30" fill="#ffffff" fill-opacity=".28" stroke="#ffffff" stroke-opacity=".9" stroke-width="5"/>
  <path d="M-30 52 L-42 82 M66 52 L76 82" fill="none"/>
  <path d="M-96 84 L134 84 Q158 84 166 64" fill="none" stroke-width="11"/>
  <rect x="-8" y="-78" width="24" height="26" rx="6" fill="#2a3640"/>
  <path d="M-78 -2 Q-78 -58 10 -60 Q96 -60 118 -6 Q124 30 92 50 L-40 52 Q-78 48 -78 -2 Z" fill="url(#body)"/>
  <path d="M-74 14 L120 14 L116 30 L-70 32 Z" fill="#f4efe0" stroke="none"/>
  <path d="M34 -50 Q92 -50 112 -6 L40 -6 Z" fill="url(#glass)"/>
  <path d="M48 -42 Q76 -40 88 -22" fill="none" stroke="#ffffff" stroke-opacity=".85" stroke-width="6"/>
  <path d="M-78 -2 Q-78 -58 10 -60 Q96 -60 118 -6 Q124 30 92 50 L-40 52 Q-78 48 -78 -2 Z" fill="none"/>
  <circle cx="-10" cy="-60" r="9" fill="#ff3b30" stroke-width="5"/>
  <path d="M-196 -82 L176 -88" fill="none" stroke="#1d262c" stroke-width="18"/>
  <path d="M-196 -82 L176 -88" fill="none" stroke="#4a5b66" stroke-width="5"/>
</g>"""


def compass(cx, cy, r):
    out = [f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="none" stroke="#ffc35c" stroke-opacity=".45" stroke-width="7"/>']
    for k in range(24):
        a = math.radians(k * 15)
        big = k % 6 == 0
        r1, r2 = r - (22 if big else 12), r - 4
        out.append(
            f'<line x1="{cx + math.sin(a) * r1:.1f}" y1="{cy - math.cos(a) * r1:.1f}" '
            f'x2="{cx + math.sin(a) * r2:.1f}" y2="{cy - math.cos(a) * r2:.1f}" stroke="#f5efdc" '
            f'stroke-opacity="{.8 if big else .35}" stroke-width="{6 if big else 3}" stroke-linecap="round"/>'
        )
    out.append(f'<path d="M{cx - 20} {cy - r - 10} L{cx + 20} {cy - r - 10} L{cx} {cy - r + 26} Z" fill="#ffc35c" stroke="#071a21" stroke-width="5" stroke-linejoin="round"/>')
    return "\n".join(out)


LAND = f"""<path d="{land_path}" fill="#06161c" fill-opacity=".45" transform="translate(8 12)"/>
<path d="{land_path}" fill="url(#land)" stroke="#ffc35c" stroke-width="9" stroke-linejoin="round"/>
<path d="M{pin_x + 14:.1f} {pin_y - 52:.1f} C {pin_x + 50:.1f} {pin_y - 110:.1f} 250 330 292 292" fill="none" stroke="#f5efdc" stroke-width="6" stroke-dasharray="4 14" stroke-linecap="round" stroke-opacity=".9"/>
<g transform="translate({pin_x:.1f} {pin_y:.1f})"><path d="M0 0 C-6 -14 -20 -22 -20 -36 A20 20 0 1 1 20 -36 C20 -22 6 -14 0 0 Z" fill="#ffc35c" stroke="#071a21" stroke-width="6" stroke-linejoin="round"/><circle cx="0" cy="-36" r="7" fill="#071a21"/></g>"""

ART = f"{compass(256, 262, 214)}\n{LAND}\n{HELI}"
(root / "assets/icon.svg").write_text(f"""<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">
{DEFS}
<rect width="512" height="512" rx="112" fill="url(#bg)"/>
<rect width="512" height="512" rx="112" fill="url(#glow)"/>
{ART}
<rect x="6" y="6" width="500" height="500" rx="106" fill="none" stroke="#ffc35c" stroke-opacity=".55" stroke-width="6"/>
</svg>
""")
# Android crops adaptive icons to a circle or squircle: keep the art inside the safe zone.
(root / "assets/icon_foreground.svg").write_text(f"""<svg xmlns="http://www.w3.org/2000/svg" width="432" height="432" viewBox="0 0 512 512">
{DEFS}
<g transform="translate(256 262) scale(.66) translate(-256 -262)">
{ART}
</g>
</svg>
""")
(root / "assets/icon_background.svg").write_text(f"""<svg xmlns="http://www.w3.org/2000/svg" width="432" height="432" viewBox="0 0 512 512">
{DEFS}
<rect width="512" height="512" fill="url(#bg)"/>
<rect width="512" height="512" fill="url(#glow)"/>
</svg>
""")
print(f"outline points: {len(outline)}")
