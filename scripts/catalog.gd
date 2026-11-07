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
# Data problems found while loading (unknown route names, unreadable files).
var load_errors: Array = []
# Same fold as ocr-service/app.py normalized(); tests/name_vectors.json checks both.
# What Unicode NFKD (minus combining marks) turns a lower-case character into, grouped by result.
const FOLDS = {
	" ": "¨¯´¸‗‾", "!!": "‼", "!?": "⁉", ".": "․", "..": "‥", "...": "…", "1": "¹", "1⁄2": "½", "1⁄4": "¼", "2": "²", "3": "³",
	"3⁄4": "¾", "?!": "⁈", "??": "⁇", "a": "ªàáâãäåāăąǎǟǡǻȁȃȧḁạảấầẩẫậắằẳẵặ", "aʾ": "ẚ", "b": "ḃḅḇ", "c": "çćĉċčḉ", "d": "ďḋḍḏḑḓ",
	"dz": "ǆǳ", "e": "èéêëēĕėęěȅȇȩḕḗḙḛḝẹẻẽếềểễệ", "f": "ḟ", "g": "ĝğġģǧǵḡ", "h": "ĥȟḣḥḧḩḫẖ", "i": "ìíîïĩīĭįǐȉȋḭḯỉị", "ij": "ĳ",
	"j": "ĵǰ", "k": "ķǩḱḳḵ", "l": "ĺļľḷḹḻḽ", "lj": "ǉ", "l·": "ŀ", "m": "ḿṁṃ", "n": "ñńņňǹṅṇṉṋ", "nj": "ǌ",
	"o": "ºòóôõöōŏőơǒǫǭȍȏȫȭȯȱṍṏṑṓọỏốồổỗộớờởỡợ", "p": "ṕṗ", "r": "ŕŗřȑȓṙṛṝṟ", "s": "śŝşšſșṡṣṥṧṩẛ", "ss": "ß", "t": "ţťțṫṭṯṱẗ",
	"u": "ùúûüũūŭůűųưǔǖǘǚǜȕȗṳṵṷṹṻụủứừửữự", "v": "ṽṿ", "w": "ŵẁẃẅẇẉẘ", "x": "ẋẍ", "y": "ýÿŷȳẏẙỳỵỷỹ", "z": "źżžẑẓẕ", "æ": "ǣǽ",
	"ø": "ǿ", "ʒ": "ǯ", "ʼn": "ŉ", "μ": "µ", "‐": "‑", "′′": "″", "′′′": "‴", "′′′′": "⁗", "‵‵": "‶", "‵‵‵": "‷",
}
# Whitespace that Python's \s matches; all of it separates words.
const SPACES = "\t\n\u000b\u000c\r\u001c\u001d\u001e\u001f\u0085\u00a0\u1680\u2000\u2001\u2002\u2003\u2004\u2005\u2006\u2007\u2008\u2009\u200a\u2028\u2029\u202f\u205f\u3000"
static var fold_map: Dictionary = {}

func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/places.json"))
	if parsed is Array:
		places = parsed
	else:
		report("data/places.json is unreadable or not a list")
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
	var errors: Array = []
	var result := build_routes(JSON.parse_string(FileAccess.get_file_as_string("res://data/routes_%s.json" % region)),region,errors)
	for message in errors:
		report(message)
	return result

# Routes from parsed routes JSON. A place name that is not in the catalogue is
# left out and described in errors (route title and name) instead of aborting.
func build_routes(data: Variant,region: String,errors: Array) -> Array:
	var result: Array = []
	if not data is Dictionary or not data.get("routes") is Array:
		errors.append("data/routes_%s.json is unreadable or has no routes list" % region)
		return result
	for route in data.routes:
		var resolved: Array = []
		for name in route.places:
			var place := resolve(name,region)
			if place.is_empty():
				errors.append("route '%s' (%s): unknown place '%s', not in data/places.json" % [route.title,region,name])
			else:
				resolved.append(place)
		result.append({"title":route.title,"theme":String(route.get("theme","")),"homework":String(route.get("homework","")),
			"source":String(route.get("source","")),"about":String(route.get("about","")),"places":resolved})
	return result

func report(message: String) -> void:
	load_errors.append(message)
	push_error("TopoCatalog: "+message)

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
# An unknown name gives an empty Dictionary.
func resolve(name: String, region: String) -> Dictionary:
	var key := normalize(name)
	var table: Dictionary = region_lookup.get(region,{})
	return table[key] if table.has(key) else lookup.get(key,{})

func routes(region: String) -> Array:
	return eu_routes if region == "eu" else nl_routes

static func normalize(value: String) -> String:
	if fold_map.is_empty():
		for base in FOLDS:
			for ch in FOLDS[base]:
				fold_map[ch] = base
		for ch in SPACES:
			fold_map[ch] = " "
		fold_map["-"] = " "
		for ch in "'’‘`":
			fold_map[ch] = ""
	var folded := ""
	for ch in value.to_lower():
		folded += fold_map.get(ch,ch)
	return " ".join(folded.split(" ",false))

# Worksheet text to places. With region "eu" names that exist in both regions
# (the Noordzee, the Rijn) take the Europe entry. Otherwise the shared lookup
# applies, and a list that names any Europe-only place counts as a Europe list.
func parse_list(text: String, region: String="") -> Dictionary:
	var result := parse_names(text,region)
	if region != "eu" and result.found.any(func(p): return p.region == "eu"):
		return parse_names(text,"eu")
	return result

func parse_names(text: String, region: String) -> Dictionary:
	var found: Array = []
	var unknown: Array = []
	var seen: Dictionary = {}
	var number := RegEx.new()
	number.compile("^\\s*[0-9]+[.):\\s-]+")
	for raw in text.replace(";", "\n").replace(",", "\n").split("\n"):
		# Remove an optional worksheet number, e.g. '1. Arnhem'.
		var name: String = number.sub(raw.strip_edges(),"",true).strip_edges()
		if name.is_empty():
			continue
		var place := resolve(name,region)
		if place.is_empty():
			unknown.append(name)
		elif not seen.has(place.name):
			found.append(place)
			seen[place.name] = true
	return {"found":found,"unknown":unknown}

func presets(region: String, scope: int=0) -> Array:
	var list := routes(region)
	return list[clampi(scope,0,list.size()-1)].places.duplicate()
