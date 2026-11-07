class_name ProgressStore
extends RefCounted

# Schema version of progress.json. Files without a version field are treated as version 1.
const VERSION := 1
const KNOWN_KEYS = ["version","best","records","custom","endpoint","mute","paint"]

# True when the file was written by a newer app with a schema this build does not understand.
static func is_newer(raw: Variant) -> bool:
	if not raw is Dictionary:
		return false
	var v: Variant=raw.get("version")
	return typeof(v) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(v)) and float(v)>VERSION

static func clean(raw: Variant) -> Dictionary:
	var data: Dictionary = {"version":VERSION,"best":{},"records":{},"custom":[],"endpoint":"","mute":false}
	if not raw is Dictionary:
		return data
	for key in raw:
		if not key in KNOWN_KEYS:
			data[key]=raw[key]
	if raw.get("mute") is bool:
		data.mute=raw.mute
	if raw.get("paint") is Dictionary:
		var paint: Dictionary={}
		for part in RotorHelicopter.DEFAULT_PAINT:
			if RotorHelicopter.valid_hex(raw.paint.get(part)):
				paint[part]=String(raw.paint[part]).to_lower()
		if not paint.is_empty():
			data.paint=paint
	if raw.get("endpoint") is String and raw.endpoint.length()<=2048:
		data.endpoint=raw.endpoint
	if raw.get("best") is Dictionary:
		for key in ["nl_test","nl_oefenen","eu_test","eu_oefenen"]:
			var score: Variant=raw.best.get(key)
			if typeof(score) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(score)) and score>=0 and score<=3 and float(score)==floor(float(score)):
				data.best[key]=int(score)
	if raw.get("records") is Dictionary:
		var count=0
		for key in raw.records:
			if count>=1000:
				break
			var value: Variant=raw.records[key]
			if key is String and key.length()<=80 and typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)>0 and float(value)<604800:
				data.records[key]=float(value)
				count+=1
	if raw.get("custom") is Array:
		var valid_codes: Array=[]
		var catalog=TopoCatalog.new()
		for p in catalog.places:
			if p.kind=="land":
				valid_codes.append(p.code)
		var nl_bounds: Array=TopoWorld.map_bounds("nl")
		for p in raw.custom.slice(0,200):
			if not p is Dictionary or not p.get("name") is String or p.name.strip_edges().is_empty() or p.name.length()>120:
				continue
			# Catalog places are resolved against the current catalog so data fixes in places.json reach saved missions.
			if p.get("kind")!="eigen punt":
				var key=catalog.normalize(p.name)
				if catalog.lookup.has(key):
					data.custom.append(catalog.lookup[key].duplicate())
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
			var region: String="nl" if TopoWorld.in_bounds(nl_bounds,lat,lon) and p.kind!="land" else "eu"
			data.custom.append({"name":p.name,"lat":lat,"lon":lon,"kind":p.kind,"region":region,"code":code})
	return data
