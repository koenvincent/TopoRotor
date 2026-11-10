"""Validate the game data in data/*.json and content/missions.json. No third-party dependencies (Python 3.9+).

    python3 tools/check_data.py

Exit status 0 means every check passed; otherwise each failure is printed and the status is 1.
CI step to add (after checkout, before the Godot job; not wired in here):
    - name: Check game data
      run: python3 tools/check_data.py
"""
import hashlib
import json
import math
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EU_BOUNDS = [-25, 34, 45, 72]
# ISO 3166-1 alpha-3 codes that may appear in map_eu.json, plus the one user-assigned code.
ISO_CODES = set((
    "ALB AND ARM AUT AZE BEL BGR BIH BLR CHE CYP CZE DEU DNK DZA ESP EST FIN FRA FRO GBR GEO GGY GRC GRL HRV HUN IMN "
    "IRL IRN IRQ ISL ITA JEY LBN LIE LTU LUX LVA MAR MCO MDA MKD MLT MNE NLD NOR POL PRT ROU RUS SMR SRB SVK SVN SWE "
    "SYR TUN TUR UKR VAT").split())
USER_ASSIGNED_CODES = {"XKX"}  # Kosovo
PROVINCE_NAMES = {"Friesland": "Fryslân"}  # same table as TopoWorld.PROVINCE_NAMES in scripts/world.gd
PLACE_KINDS = {"stad", "land", "provincie", "water", "eiland", "gebied", "plek", "eigen punt"}
failures = []


def check(condition, message):
    if not condition:
        failures.append(message)
    return condition


def load(relative):
    return json.loads((ROOT / relative).read_text(encoding="utf-8"))


def signed_area(ring):
    return sum(ring[i][0] * ring[i + 1][1] - ring[i + 1][0] * ring[i][1] for i in range(len(ring) - 1)) / 2


def inside(ring, lon, lat):
    result = False
    for i in range(len(ring) - 1):
        (x1, y1), (x2, y2) = ring[i], ring[i + 1]
        if (y1 > lat) != (y2 > lat) and lon < (x2 - x1) * (lat - y1) / (y2 - y1) + x1:
            result = not result
    return result


def orientation(a, b, c):
    value = (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])
    return (value > 1e-15) - (value < -1e-15)


def crosses(p1, p2, p3, p4):
    return orientation(p1, p2, p3) * orientation(p1, p2, p4) < 0 and orientation(p3, p4, p1) * orientation(p3, p4, p2) < 0


def is_simple(ring):
    """True when no two edges of the closed ring properly cross (touching vertices are allowed)."""
    edges = [(ring[i], ring[i + 1]) for i in range(len(ring) - 1)]
    edges.sort(key=lambda e: min(e[0][0], e[1][0]))
    for i, (a, b) in enumerate(edges):
        right = max(a[0], b[0])
        for c, d in edges[i + 1:]:
            if min(c[0], d[0]) > right:
                break
            if min(a[1], b[1]) > max(c[1], d[1]) or min(c[1], d[1]) > max(a[1], b[1]):
                continue
            if crosses(a, b, c, d):
                return False
    return True


def check_ring(label, ring, bounds=None, min_area=1e-5, rounded=True):
    if not check(isinstance(ring, list) and len(ring) >= 4, label + ": a ring needs at least 4 points"):
        return
    check(ring[0] == ring[-1], label + ": ring is not closed")
    check(all(len(p) == 2 and all(isinstance(v, (int, float)) for v in p) for p in ring), label + ": points must be [lon, lat] numbers")
    check(all(ring[i] != ring[i + 1] for i in range(len(ring) - 1)), label + ": repeated consecutive point")
    if rounded:
        check(all(round(v, 6) == v for p in ring for v in p), label + ": coordinates are not rounded to 6 decimals")
    if bounds:
        check(all(bounds[0] <= p[0] <= bounds[2] and bounds[1] <= p[1] <= bounds[3] for p in ring), label + ": point outside bounds")
    area = signed_area(ring)
    check(area < 0, label + ": ring must be clockwise")
    check(abs(area) >= min_area, label + ": ring area %.7f deg2 is a sliver (< %g)" % (abs(area), min_area))
    check(is_simple(ring), label + ": ring crosses itself")


def on_frame_edge(a, b, bounds):
    return any(a[0] == b[0] == bounds[i] for i in (0, 2)) or any(a[1] == b[1] == bounds[i] for i in (1, 3))


def countries_at(countries, lon, lat):
    return {c["code"] for c in countries if any(inside(r, lon, lat) for r in c["polygons"])}


def lakes_sha(lakes):
    return hashlib.sha1(json.dumps(lakes, separators=(",", ":")).encode()).hexdigest()[:12]


def check_map_eu():
    data = load("data/map_eu.json")
    meta = data.get("meta", {})
    check(meta.get("format_version") == 1, "map_eu: meta.format_version must be 1")
    check(meta.get("pov") in ("NLD", "UKR"), "map_eu: meta.pov must name the Natural Earth point of view (NLD or UKR)")
    for key in ("source", "source_url", "source_sha256", "license", "crs", "coord_order", "generator"):
        check(meta.get(key), "map_eu: meta." + key + " is missing")
    check(data.get("bounds") == EU_BOUNDS, "map_eu: bounds must be %s" % EU_BOUNDS)
    countries = data["countries"]
    codes = [c["code"] for c in countries]
    check(len(codes) == len(set(codes)), "map_eu: duplicate country code")
    for country in countries:
        code = country["code"]
        label = "map_eu " + code
        check(re.fullmatch(r"[A-Z]{3}", code) is not None, label + ": code is not three capital letters")
        check(code in ISO_CODES or code in USER_ASSIGNED_CODES, label + ": code is not in the ISO allow-list")
        check(country.get("polygons"), label + ": every country needs at least one ring")
        check(len(country.get("polygons", [])) <= 100, label + ": suspiciously many rings")
        marker = bool(country.get("marker"))
        cut = False
        for number, ring in enumerate(country.get("polygons", [])):
            check_ring("%s ring %d" % (label, number), ring, EU_BOUNDS, 1e-4 if marker else 1e-3 if code != "MCO" else 5e-4)
            cut = cut or any(on_frame_edge(ring[i], ring[i + 1], EU_BOUNDS) for i in range(len(ring) - 1))
        check(bool(country.get("clipped")) == cut, label + ": clipped flag must match rings with edges on the bounds (found edges: %s)" % cut)
        if "part_of" in country:
            check(country["part_of"] in ISO_CODES, label + ": part_of is not an ISO code")
    for forbidden in ("KOS", "ALD", "CYN"):
        check(forbidden not in codes, "map_eu: non-ISO code " + forbidden + " is back")
    # Point-in-country: the internationally recognised borders (Dutch and EU position).
    expectations = [
        ("Sevastopol", 33.52, 44.6, "UKR"), ("Simferopol", 34.1, 44.95, "UKR"), ("Yalta", 34.17, 44.5, "UKR"),
        ("Kerch", 36.47, 45.36, "UKR"), ("Kyiv", 30.52, 50.45, "UKR"), ("Amsterdam", 4.9, 52.37, "NLD"),
        ("Moskou", 37.62, 55.76, "RUS"), ("Kaliningrad", 20.5, 54.71, "RUS"), ("Parijs", 2.35, 48.85, "FRA"),
        ("Mariehamn (Aland)", 19.95, 60.1, "FIN"), ("Kyrenia (Noord-Cyprus)", 33.32, 35.34, "CYP"),
        ("Pristina", 21.17, 42.67, "XKX"), ("Minsk", 27.56, 53.9, "BLR"),
    ]
    for name, lon, lat, expected in expectations:
        found = countries_at(countries, lon, lat)
        check(expected in found, "map_eu: %s (%s, %s) must be in %s, found %s" % (name, lon, lat, expected, sorted(found)))
        if expected == "UKR":
            check("RUS" not in found, "map_eu: %s must not be in RUS" % name)
    check(countries_at(countries, 4.9, 52.37) == {"NLD"}, "map_eu: Amsterdam must resolve to NLD only")
    ukraine = next(c for c in countries if c["code"] == "UKR")
    check(any(inside(r, 34.1, 44.95) and inside(r, 30.52, 50.45) for r in ukraine["polygons"]),
          "map_eu: Crimea must be joined to the Ukrainian mainland in one ring")
    return {c["code"]: c for c in countries}


def check_map_nl():
    data = load("data/map_nl.json")
    bounds = data["bounds"]
    check(bounds == [3.1, 50.5, 7.5, 54.0], "map_nl: unexpected bounds %s" % bounds)
    codes = [c["code"] for c in data["countries"]]
    check(set(codes) == {"NLD", "DEU", "FRA", "BEL"} and len(codes) == len(set(codes)), "map_nl: unexpected country codes %s" % codes)
    for country in data["countries"]:
        for number, ring in enumerate(country["polygons"]):
            check_ring("map_nl %s ring %d" % (country["code"], number), ring, bounds, 1e-5, rounded=False)
    check(any(inside(r, 4.9, 52.37) for c in data["countries"] if c["code"] == "NLD" for r in c["polygons"]), "map_nl: Amsterdam must be in NLD")
    check(all(len(lake) >= 4 and lake[0] == lake[-1] for lake in data["lakes"]), "map_nl: lake rings must be closed")
    check(len(data["fields"]) > 0, "map_nl: no fields")
    check(data.get("fields_lakes_sha") == lakes_sha(data["lakes"]),
          "map_nl: fields were built against other lakes (fields_lakes_sha); run tools/build_nl_fields.py")
    return data


def check_boundaries(lakes_hash):
    data = load("data/boundaries_nl.json")
    check(data.get("format_version") == 1, "boundaries_nl: format_version must be 1")
    check(data.get("crs") == "EPSG:4326" and data.get("coord_order") == "lon,lat", "boundaries_nl: crs/coord_order missing")
    check(data.get("generator") == "tools/build_admin_boundaries.py", "boundaries_nl: generator missing")
    check(re.fullmatch(r"\d{4}-\d{2}-\d{2}", str(data.get("retrieved"))) and re.fullmatch(r"\d{4}-\d{2}-\d{2}", str(data.get("source_updated"))),
          "boundaries_nl: retrieved/source_updated must be YYYY-MM-DD")
    check(data.get("lakes_sha") == lakes_hash, "boundaries_nl: built against other lakes (lakes_sha); run tools/build_admin_boundaries.py")
    provinces = data["provinces"]
    check(len(provinces) == data["province_count"] == 12, "boundaries_nl: expected 12 provinces")
    check(len({p["code"] for p in provinces}) == len(provinces), "boundaries_nl: duplicate province code")
    for province in provinces:
        label = "boundaries_nl " + province["name"]
        rings = province["polygons"]
        check(1 <= len(rings) <= 8, label + ": %d rings; a province is a few islands at most" % len(rings))
        for number, ring in enumerate(rings):
            check_ring("%s ring %d" % (label, number), ring, None, 1e-5)
        # Horizontal edges at one latitude in several rings are the signature of the old strip-cutting.
        edges = {}
        for number, ring in enumerate(rings):
            for i in range(len(ring) - 1):
                if ring[i][1] == ring[i + 1][1] and abs(ring[i][0] - ring[i + 1][0]) > .01:
                    edges.setdefault(ring[i][1], set()).add(number)
        check(not any(len(owners) > 1 for owners in edges.values()), label + ": rings share a horizontal cut line (strip artefact)")
        areas = sorted((abs(signed_area(r)) for r in rings), reverse=True)
        check(areas[0] >= .5 * sum(areas) or len(rings) > 1, label + ": largest ring should dominate")
    brabant = next(p for p in provinces if p["name"] == "Noord-Brabant")
    check(len(brabant["polygons"]) == 1, "boundaries_nl: Noord-Brabant must be one ring, found %d" % len(brabant["polygons"]))
    for name, lon, lat, expected in [("Eindhoven", 5.4697, 51.4416, "Noord-Brabant"), ("Breda", 4.7759, 51.5719, "Noord-Brabant"),
                                     ("Tilburg", 5.0913, 51.5555, "Noord-Brabant"), ("'s-Hertogenbosch", 5.3049, 51.6998, "Noord-Brabant"),
                                     ("Baarle (enclave filled)", 4.93, 51.44, "Noord-Brabant"), ("Utrecht", 5.1214, 52.0907, "Utrecht"),
                                     ("Maastricht", 5.6909, 50.8514, "Limburg"), ("Groningen", 6.5665, 53.2194, "Groningen")]:
        found = [p["name"] for p in provinces if any(inside(r, lon, lat) for r in p["polygons"])]
        check(found == [expected], "boundaries_nl: %s must be in %s only, found %s" % (name, expected, found))
    # Line ends must meet the coarser line on a shared vertex, not 1e-6 degrees beside it.
    lines = data["lines"]
    for fine, coarse in (("provincial", ["national"]), ("municipal", ["provincial", "national"])):
        grid = {}
        for level in coarse:
            for path in lines[level]:
                for v in path:
                    grid.setdefault((round(v[0] / 1e-4), round(v[1] / 1e-4)), set()).add(tuple(v))
        misses = 0
        for path in lines[fine]:
            for end in (path[0], path[-1]):
                key = (round(end[0] / 1e-4), round(end[1] / 1e-4))
                near = [v for dx in (-1, 0, 1) for dy in (-1, 0, 1) for v in grid.get((key[0] + dx, key[1] + dy), ())
                        if math.hypot(v[0] - end[0], v[1] - end[1]) < 5e-5]
                if near and tuple(end) not in near:
                    misses += 1
        check(misses == 0, "boundaries_nl: %d %s line ends lie beside, not on, a vertex of the coarser line" % (misses, fine))
    return provinces


def check_city_plans(lakes_hash, nl_map, places):
    data = load("data/city_plans_nl.json")
    check(data.get("format_version") == 1, "city_plans: format_version must be 1")
    check(data.get("plot_fields") == ["x", "z", "width", "depth", "height", "angle", "roof_style"], "city_plans: plot_fields legend missing")
    check(set(data.get("roof_styles", {})) == {"0", "1", "2", "3"}, "city_plans: roof_styles legend missing")
    check(data.get("lakes_sha") == lakes_hash, "city_plans: built against other lakes (lakes_sha); run tools/build_city_plans.py --keep-existing")
    cities = {p["name"] for p in places if p["region"] == "nl" and p["kind"] == "stad"}
    check(set(data["cities"]) <= cities, "city_plans: unknown cities %s" % sorted(set(data["cities"]) - cities))
    for name, plan in data["cities"].items():
        check(plan["plots"], "city_plans %s: no plots" % name)
        for plot in plan["plots"]:
            check(len(plot) == 7 and int(plot[6]) in (0, 1, 2, 3), "city_plans %s: malformed plot %s" % (name, plot))
    return data


def normalize(value):
    """Python port of TopoCatalog.normalize in scripts/catalog.gd."""
    folds = {"a": "àáâãäåăąā", "c": "çćčĉċ", "d": "ď", "e": "èéêëęěēė", "g": "ğ", "i": "ìíîïīį", "l": "ĺľ", "n": "ñńňņ",
             "o": "òóôõöőō", "r": "ŕř", "s": "śšşșŝ", "t": "ťţț", "u": "ùúûüůűūų", "y": "ýÿ", "z": "źżž"}
    text = value.strip().lower()
    for base, chars in folds.items():
        for ch in chars:
            text = text.replace(ch, base)
    for old, new in (("-", " "), ("'", ""), ("’", ""), ("‘", ""), ("`", "")):
        text = text.replace(old, new)
    return " ".join(text.split())


def check_places(eu, provinces, nl_map):
    places = load("data/places.json")
    bounds = {"nl": nl_map["bounds"], "eu": EU_BOUNDS}
    tables = {"nl": {}, "eu": {}}
    for place in places:
        label = "places %s/%s" % (place.get("region"), place.get("name"))
        check(place.get("region") in bounds and place.get("kind") in PLACE_KINDS, label + ": unknown region or kind")
        lat, lon = place["lat"], place["lon"]
        b = bounds.get(place.get("region"), EU_BOUNDS)
        check(b[0] <= lon <= b[2] and b[1] <= lat <= b[3], label + ": coordinates outside the %s map" % place.get("region"))
        for key in [place["name"]] + list(place.get("aliases", [])):
            normal = normalize(key)
            owner = tables[place["region"]].get(normal)
            check(owner is None or owner is place, label + ": name or alias '%s' already used by %s" % (key, owner and owner["name"]))
            tables[place["region"]][normal] = place
        if "code" in place:
            check(place["code"] == "" or place["code"] in ISO_CODES or place["code"] in USER_ASSIGNED_CODES, label + ": code %s not in the allow-list" % place["code"])
        if place.get("kind") == "land":
            country = eu.get(place["code"])
            if check(country is not None, label + ": country code %s is not in map_eu.json" % place["code"]):
                check(any(inside(r, lon, lat) for r in country["polygons"]), label + ": catalog point lies outside its own country outline")
        if place.get("kind") == "provincie":
            name = place["name"].removesuffix(" provincie") if hasattr(str, "removesuffix") else re.sub(r" provincie$", "", place["name"])
            name = PROVINCE_NAMES.get(name, name)
            check(any(p["name"] == name for p in provinces), label + ": no province '%s' in boundaries_nl.json" % name)
    return places, tables


# Places the drawn rivers must pass, in km: the river questions themselves and the towns on their banks.
# Without this check the Maas and IJssel were missing from the map for months.
ON_RIVER_KM = {"Maas": 1.5, "Waal": 1.5, "Rijn": 1.5, "Neder-Rijn": 1.5, "Lek": 1.5, "IJssel": 2.5, "Merwede": 2.5,
               "Maastricht": 1.5, "Roermond": 1.5, "Venlo": 1.5, "Arnhem": 1.5, "Deventer": 2.0, "Zutphen": 1.5, "Kampen": 1.5}


def km_to_line(lon, lat, line):
    scale = math.cos(math.radians(52))
    best = float("inf")
    for (ax, ay), (bx, by) in zip(line, line[1:]):
        ax, bx, px = ax * scale, bx * scale, lon * scale
        dx, dy = bx - ax, by - ay
        length = dx * dx + dy * dy
        t = 0.0 if length == 0 else max(0.0, min(1.0, ((px - ax) * dx + (lat - ay) * dy) / length))
        best = min(best, math.hypot((px - ax - t * dx) * 111.32, (lat - ay - t * dy) * 110.57))
    return best


def check_rivers(nl_map, places):
    bounds = nl_map["bounds"]
    rivers = nl_map["rivers"]
    check(len(rivers) > 0, "map_nl: no rivers")
    for number, line in enumerate(rivers):
        check(len(line) >= 2 and all(bounds[0] - 1e-6 <= x <= bounds[2] + 1e-6 and bounds[1] - 1e-6 <= y <= bounds[3] + 1e-6 for x, y in line),
              "map_nl river %d: needs two or more points inside the bounds" % number)
    for name, reach in ON_RIVER_KM.items():
        place = next((p for p in places if p["name"] == name and p["region"] == "nl"), None)
        check(place is not None, "rivers: place %s missing" % name)
        if place:
            distance = min(km_to_line(place["lon"], place["lat"], line) for line in rivers)
            check(distance <= reach, "rivers: %s lies %.1f km from the nearest drawn river (at most %.1f)" % (name, distance, reach))


def check_routes(places, tables):
    everything = {}
    for region in ("eu", "nl"):  # the Dutch entry wins for names that exist in both regions
        everything.update(tables[region])
    for region in ("nl", "eu"):
        for route in load("data/routes_%s.json" % region)["routes"]:
            for name in route["places"]:
                key = normalize(name)
                check(key in tables[region] or key in everything, "routes_%s '%s': place '%s' is not in places.json" % (region, route["title"], name))
    for mission in load("content/missions.json")["missions"]:
        for name in mission["places"]:
            check(normalize(name) in everything, "missions '%s': place '%s' is not in places.json" % (mission["title"], name))


def main():
    eu = check_map_eu()
    nl_map = check_map_nl()
    lakes_hash = lakes_sha(nl_map["lakes"])
    provinces = check_boundaries(lakes_hash)
    places, tables = check_places(eu, provinces, nl_map)
    check_city_plans(lakes_hash, nl_map, places)
    check_routes(places, tables)
    check_rivers(nl_map, places)
    for path in sorted((ROOT / "data").glob("*.json")):
        check(isinstance(json.loads(path.read_text(encoding="utf-8")), dict) or path.name == "places.json", str(path) + ": unexpected top level")
    if failures:
        print("\n".join("FAIL " + message for message in failures))
        print("%d data check(s) failed" % len(failures))
        return 1
    print("DATA CHECK PASSED: %d countries, %d provinces, %d places" % (len(eu), len(provinces), len(places)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
