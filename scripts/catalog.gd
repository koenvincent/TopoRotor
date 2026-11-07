class_name TopoCatalog
extends RefCounted

var places: Array = []
# Name lookup for worksheets and OCR. A name that exists in both regions (the
# Noordzee, the Rijn) resolves to the Dutch entry here; use resolve() for a region.
var lookup: Dictionary = {}
var region_lookup: Dictionary = {"nl":{},"eu":{}}
# Worksheet routes per region: [{title, places: [Dictionary]}].
var nl_routes: Array = []
var eu_routes: Array = []

func _init() -> void:
	places = JSON.parse_string(FileAccess.get_file_as_string("res://data/places.json"))
	for p in places:
		var table: Dictionary = region_lookup.get(p.region,{})
		for key in [p.name] + Array(p.aliases):
			var normal := normalize(key)
			table[normal] = p
			if not lookup.has(normal) or p.region == "nl":
				lookup[normal] = p
	nl_routes = load_routes("nl")
	eu_routes = load_routes("eu")

func load_routes(region: String) -> Array:
	var routes: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/routes_%s.json" % region))
	var result: Array = []
	for route in routes.routes:
		var resolved: Array = []
		for name in route.places:
			resolved.append(resolve(name,region))
		result.append({"title":route.title,"theme":String(route.get("theme","")),"homework":String(route.get("homework","")),
			"source":String(route.get("source","")),"about":String(route.get("about","")),"places":resolved})
	return result

# Homework: the assignments from the worksheet photos, as their own routes.
# name is the title without the "Huiswerk · " prefix the route picker shows.
func homework(region: String) -> Array:
	var list: Array=[]
	var all := routes(region)
	for i in all.size():
		if not String(all[i].homework).is_empty():
			list.append({"index":i,"id":all[i].homework,"name":String(all[i].title).trim_prefix("Huiswerk · "),"source":all[i].source,
				"about":all[i].about,"count":all[i].places.size(),"places":all[i].places})
	return list

# Places of several routes in one list, each place once, in route order.
static func merge_places(lists: Array) -> Array:
	var seen: Dictionary={}
	var merged: Array=[]
	for places in lists:
		for place in places:
			if not seen.has(place.name):
				seen[place.name]=true
				merged.append(place)
	return merged

# Homework assignments of which every place is in this list: what a finished
# mission counts as done.
func homework_covered(region: String,places: Array) -> Array:
	var names: Dictionary={}
	for place in places:
		names[place.name]=true
	var covered: Array=[]
	for item in homework(region):
		if item.places.all(func(p): return names.has(p.name)):
			covered.append(item)
	return covered

# Theme routes (provinces, rivers, areas, islands, ...) with their index in
# the region's route list, so the menu can select them in the route picker.
func themes(region: String) -> Array:
	var list: Array=[]
	var all := routes(region)
	for i in all.size():
		if not String(all[i].theme).is_empty():
			list.append({"index":i,"theme":all[i].theme,"title":all[i].title,"count":all[i].places.size()})
	return list

# Region first, then the shared lookup (Amsterdam is the Dutch capital in Europe).
func resolve(name: String, region: String) -> Dictionary:
	var key := normalize(name)
	return region_lookup.get(region,{}).get(key,lookup[key])

func routes(region: String) -> Array:
	return eu_routes if region == "eu" else nl_routes

func normalize(value: String) -> String:
	var s = value.strip_edges().to_lower()
	# Mirrors the OCR service (NFKD + strip combining marks) for the Latin letters we expect.
	var folds := {
		"a": "àáâãäåăąā", "c": "çćčĉċ", "d": "ď", "e": "èéêëęěēė",
		"g": "ğ", "i": "ìíîïīį", "l": "ĺľ", "n": "ñńňņ", "o": "òóôõöőō",
		"r": "ŕř", "s": "śšşșŝ", "t": "ťţț", "u": "ùúûüůűūų",
		"y": "ýÿ", "z": "źżž",
	}
	for base in folds:
		for ch in folds[base]:
			s = s.replace(ch, base)
	for pair in [["-"," "],["'",""],["’",""],["‘",""],["`",""]]:
		s = s.replace(pair[0],pair[1])
	return " ".join(s.split(" ",false))

func parse_list(text: String) -> Dictionary:
	var found: Array = []
	var unknown: Array = []
	var seen: Dictionary = {}
	for raw in text.replace(";", "\n").replace(",", "\n").split("\n"):
		var name = raw.strip_edges()
		# Remove an optional worksheet number, e.g. '1. Arnhem'.
		var re = RegEx.new()
		re.compile("^\\s*[0-9]+[.):\\s-]+")
		name = re.sub(name,"",true).strip_edges()
		if name.is_empty():
			continue
		var key = normalize(name)
		if lookup.has(key):
			var place: Dictionary = lookup[key]
			if not seen.has(place.name):
				found.append(place)
				seen[place.name] = true
		else:
			unknown.append(name)
	return {"found":found,"unknown":unknown}

func presets(region: String, scope: int=0) -> Array:
	var list := routes(region)
	return list[clampi(scope,0,list.size()-1)].places.duplicate()
