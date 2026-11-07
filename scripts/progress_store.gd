class_name ProgressStore
extends RefCounted

static func clean(raw: Variant) -> Dictionary:
	var data: Dictionary = {"best":{},"custom":[],"endpoint":"","mute":false}
	if not raw is Dictionary:
		return data
	if raw.get("mute") is bool:
		data.mute=raw.mute
	if raw.get("endpoint") is String and raw.endpoint.length()<=2048:
		data.endpoint=raw.endpoint
	if raw.get("best") is Dictionary:
		for key in ["nl_test","nl_oefenen","eu_test","eu_oefenen"]:
			var score: Variant=raw.best.get(key)
			if typeof(score) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(score)) and score>=0 and score<=3 and float(score)==floor(float(score)):
				data.best[key]=int(score)
	if raw.get("custom") is Array:
		var valid_codes: Array=[]
		for p in TopoCatalog.new().places:
			if p.kind=="land":
				valid_codes.append(p.code)
		for p in raw.custom.slice(0,200):
			if not p is Dictionary or not p.get("name") is String or p.name.strip_edges().is_empty() or p.name.length()>120:
				continue
			if not typeof(p.get("lat")) in [TYPE_FLOAT,TYPE_INT] or not typeof(p.get("lon")) in [TYPE_FLOAT,TYPE_INT]:
				continue
			var lat: float=float(p.lat)
			var lon: float=float(p.lon)
			if not is_finite(lat) or not is_finite(lon) or lat<34 or lat>72 or lon < -25 or lon>45:
				continue
			if not p.get("kind") in ["stad","land","provincie","water","eiland","eigen punt"]:
				continue
			var code: String=p.get("code","") if p.get("code","") is String else ""
			if p.kind=="land" and code not in valid_codes:
				continue
			var region: String="nl" if lat>=50.5 and lat<=54 and lon>=3.1 and lon<=7.5 and p.kind!="land" else "eu"
			data.custom.append({"name":p.name,"lat":lat,"lon":lon,"kind":p.kind,"region":region,"code":code})
	return data
