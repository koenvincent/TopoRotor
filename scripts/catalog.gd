class_name TopoCatalog
extends RefCounted

var places: Array = []
var lookup: Dictionary = {}

func _init() -> void:
	places = JSON.parse_string(FileAccess.get_file_as_string("res://data/places.json"))
	for p in places:
		lookup[normalize(p.name)] = p
		for alias in p.aliases:
			lookup[normalize(alias)] = p

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

func presets(region: String) -> Array:
	var names = ["Utrecht","Amsterdam","Den Haag","Rotterdam","Middelburg","Den Bosch","Maastricht","Arnhem","Zwolle","Assen","Groningen","Leeuwarden"] if region == "nl" else ["Brussel","Parijs","Londen","Madrid","Rome","Wenen","Berlijn","Warschau","Kopenhagen","Stockholm"]
	var result: Array = []
	for name in names:
		result.append(lookup[normalize(name)])
	return result
