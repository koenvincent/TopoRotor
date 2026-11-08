class_name ProgressStore
extends RefCounted

# Schema version of progress.json. Files without a version field are treated as version 1.
# Version 2 adds "quiz": the best Overhoren mark per homework card (or set of cards).
const VERSION := 2
const KNOWN_KEYS = ["version","best","records","custom","endpoint","mute","paint","minimap_rotate","calm","points","medals","garage","boards","pilot","look","profiles","homework","quiz"]
const DEFAULT_PILOT = "Niek"
# Pilot profiles on one device. Each keeps its own points, medals, hangar,
# paint, stars, record times and pilot look; the leaderboard is shared, so
# the pilots compete on the same lists. The active profile also lives at the
# top level of the save, which is what the rest of the game reads.
# A new per-pilot field must be added to PROFILE_KEYS and bump VERSION: an older build refuses
# (read-only) a file with a higher version, so it never drops the field of a stored pilot.
const PROFILE_KEYS = ["points","medals","garage","paint","best","records","look","homework","quiz"]
const MAX_PROFILES = 8
# Caps of the saved lists. Past a cap the oldest entries go; the newest are the ones just earned.
const MAX_HOMEWORK = 40
const MAX_QUIZ = 40
const MAX_RECORDS = 1000
const MAX_CUSTOM = 200
# Bounds of the Dutch map, read once: the map file is large and only four numbers are needed.
static var _nl_bounds: Array = []

static func nl_bounds() -> Array:
	if _nl_bounds.is_empty():
		_nl_bounds=TopoWorld.map_bounds("nl")
	return _nl_bounds

# Writes text to path through path+".tmp". The old file is only replaced once the whole text
# was written and reads back intact; on any failure it stays untouched.
# Returns "" on success, else the step that failed ("open", "write" or "rename").
static func write_atomic(path: String,text: String) -> String:
	var tmp=path+".tmp"
	var f=FileAccess.open(tmp,FileAccess.WRITE)
	if f==null:
		return "open"
	f.store_string(text)
	f.flush()
	var err=f.get_error()
	f.close()
	if err!=OK or FileAccess.get_file_as_string(tmp)!=text:
		DirAccess.remove_absolute(tmp)
		return "write"
	if DirAccess.rename_absolute(tmp,path)!=OK:
		DirAccess.remove_absolute(tmp)
		return "rename"
	return ""

# Keeps the better of the stored and the new Overhoren mark, as the newest entry.
static func remember_quiz(quiz: Dictionary,key: String,mark: float) -> float:
	var best=maxf(float(quiz.get(key,0.0)),snappedf(mark,.1))
	quiz.erase(key)
	quiz[key]=best
	while quiz.size()>MAX_QUIZ:
		quiz.erase(quiz.keys()[0])
	return best

# Stores a record as the newest entry and drops the oldest ones past the cap.
static func remember_record(records: Dictionary,key: String,score: float) -> void:
	records.erase(key)
	records[key]=score
	while records.size()>MAX_RECORDS:
		records.erase(records.keys()[0])

# Only an https address with a host is a leaderboard/OCR target.
static func valid_endpoint(url: String) -> bool:
	if url.length()>2048 or not url.begins_with("https://"):
		return false
	for c in url:
		if c.unicode_at(0)<=32 or c.unicode_at(0)==127:
			return false
	var host: String=url.substr(8).get_slice("/",0).get_slice("?",0).get_slice("#",0)
	return not host.is_empty() and not host.begins_with("@") and not host.begins_with(":")

# True when the file was written by a newer app with a schema this build does not understand.
static func is_newer(raw: Variant) -> bool:
	if not raw is Dictionary:
		return false
	var v: Variant=raw.get("version")
	return typeof(v) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(v)) and float(v)>VERSION

static func defaults() -> Dictionary:
	var data: Dictionary={"version":VERSION,"best":{},"records":{},"custom":[],"endpoint":"","mute":false,"points":0,"medals":[],"garage":HangarCatalog.DEFAULT_GARAGE.duplicate(true),"boards":{},"pilot":DEFAULT_PILOT,"look":PilotFigure.DEFAULT_LOOK.duplicate(),"homework":[],"quiz":{}}
	data.profiles={DEFAULT_PILOT:snapshot(data)}
	return data

# Progress of one pilot, validated. Paint is only present when it was set.
static func clean_profile(raw: Variant) -> Dictionary:
	var data: Dictionary={"points":0,"medals":[],"garage":HangarCatalog.DEFAULT_GARAGE.duplicate(true),"best":{},"records":{},"look":PilotFigure.DEFAULT_LOOK.duplicate(),"homework":[],"quiz":{}}
	if not raw is Dictionary:
		return data
	if raw.get("paint") is Dictionary:
		var paint: Dictionary={}
		# "dark" is the pre-0.5 rotor/skid slot; the helicopter migrates it.
		for part in RotorHelicopter.DEFAULT_PAINT.keys()+["dark"]:
			if RotorHelicopter.valid_hex(raw.paint.get(part)):
				paint[part]=String(raw.paint[part]).to_lower()
		if not paint.is_empty():
			data.paint=paint
	var points: Variant=raw.get("points")
	if typeof(points) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(points)) and float(points)>=0:
		# Clamp as a float first: int() of a value beyond int64 wraps to a negative number.
		data.points=int(minf(float(points),float(HangarCatalog.MAX_POINTS)))
	if raw.get("medals") is Array:
		for medal in raw.medals:
			if medal is String and HangarCatalog.MEDALS.has(medal) and not medal in data.medals:
				data.medals.append(medal)
	# Ids of the homework assignments this pilot has flown, each once.
	if raw.get("homework") is Array:
		for id in raw.homework.slice(maxi(0,raw.homework.size()-MAX_HOMEWORK*10)):
			if id is String and id.length()<=40 and not id.is_empty() and not id in data.homework:
				data.homework.append(id)
		if data.homework.size()>MAX_HOMEWORK:
			push_warning("Voortgang: %d oudste huiswerk-ids weggelaten (maximaal %d)." % [data.homework.size()-MAX_HOMEWORK,MAX_HOMEWORK])
			data.homework=data.homework.slice(data.homework.size()-MAX_HOMEWORK)
	# Best Overhoren mark (1 to 10) per card key such as "water" or "noord+west"; the newest keys stay.
	if raw.get("quiz") is Dictionary:
		var quiz_keys: Array=raw.quiz.keys()
		for key in quiz_keys.slice(maxi(0,quiz_keys.size()-MAX_QUIZ)):
			var mark: Variant=raw.quiz[key]
			if key is String and not key.is_empty() and key.length()<=80 and typeof(mark) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(mark)) and float(mark)>=1.0 and float(mark)<=10.0:
				data.quiz[key]=snappedf(float(mark),.1)
	data.garage=HangarCatalog.clean_garage(raw.get("garage"))
	data.look=PilotFigure.clean(raw.get("look"))
	if raw.get("best") is Dictionary:
		for key in ["nl_test","nl_oefenen","eu_test","eu_oefenen"]:
			var score: Variant=raw.best.get(key)
			if typeof(score) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(score)) and score>=0 and score<=3 and float(score)==floor(float(score)):
				data.best[key]=int(score)
	if raw.get("records") is Dictionary:
		# Walk from the newest entry back, so the cap drops the oldest records.
		var keys: Array=raw.records.keys()
		var picked: Array=[]
		for i in range(keys.size()-1,-1,-1):
			var key: Variant=keys[i]
			var value: Variant=raw.records[key]
			if key is String and key.length()<=80 and typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)>0 and float(value)<604800:
				picked.append(key)
				if picked.size()>=MAX_RECORDS:
					break
		picked.reverse()
		for key in picked:
			data.records[key]=float(raw.records[key])
	return data

# The per-pilot part of the save, as a deep copy.
static func snapshot(data: Dictionary) -> Dictionary:
	var copy: Dictionary={}
	for key in PROFILE_KEYS:
		if data.has(key):
			copy[key]=data[key].duplicate(true) if data[key] is Dictionary or data[key] is Array else data[key]
	return copy

static func profile_names(data: Dictionary) -> Array:
	var names: Array=data.get("profiles",{}).keys()
	names.sort_custom(func(a,b): return String(a).naturalnocasecmp_to(String(b))<0)
	return names

# Same name with other capitals counts as the same pilot.
static func find_profile(data: Dictionary,name: String) -> String:
	for existing in data.get("profiles",{}):
		if String(existing).to_lower()==name.to_lower():
			return existing
	return ""

# Stores the active pilot and puts the chosen one at the top level.
static func switch_profile(data: Dictionary,name: String) -> bool:
	var target=find_profile(data,name)
	if target.is_empty():
		return false
	data.profiles[data.pilot]=snapshot(data)
	var profile: Dictionary=clean_profile(data.profiles[target])
	for key in PROFILE_KEYS:
		if profile.has(key):
			data[key]=profile[key]
		else:
			data.erase(key)
	data.pilot=target
	data.profiles[target]=snapshot(data)
	return true

# A fresh pilot starts at zero with the factory helicopter, and becomes active.
static func add_profile(data: Dictionary,raw_name: Variant) -> String:
	var name=Leaderboard.clean_pilot(raw_name)
	if name.is_empty():
		return ""
	if not find_profile(data,name).is_empty() or data.profiles.size()>=MAX_PROFILES:
		return ""
	data.profiles[data.pilot]=snapshot(data)
	data.profiles[name]=clean_profile({})
	switch_profile(data,name)
	return name

# The last pilot cannot be removed. Removing the active one switches to the next.
static func remove_profile(data: Dictionary,name: String) -> bool:
	var target=find_profile(data,name)
	if target.is_empty() or data.profiles.size()<=1:
		return false
	if target==data.pilot:
		for other in profile_names(data):
			if other!=target:
				switch_profile(data,other)
				break
	data.profiles.erase(target)
	return true

static func clean(raw: Variant) -> Dictionary:
	var data: Dictionary = defaults()
	if not raw is Dictionary:
		return data
	for key in raw:
		if not key in KNOWN_KEYS:
			data[key]=raw[key]
	if raw.get("mute") is bool:
		data.mute=raw.mute
	if raw.get("minimap_rotate") is bool:
		data.minimap_rotate=raw.minimap_rotate
	if raw.get("calm") is bool:
		data.calm=raw.calm
	data.merge(clean_profile(raw),true)
	data.boards=Leaderboard.clean(raw.get("boards"))
	var pilot=Leaderboard.clean_pilot(raw.get("pilot"))
	if not pilot.is_empty():
		data.pilot=pilot
	# Saves from before profiles hold one pilot: the top level becomes that profile.
	data.profiles={}
	if raw.get("profiles") is Dictionary:
		for key in raw.profiles:
			var name=Leaderboard.clean_pilot(key)
			if name.is_empty() or not raw.profiles[key] is Dictionary or not find_profile(data,name).is_empty():
				continue
			# One slot stays free for the active pilot until that pilot has been read.
			var is_active=name.to_lower()==String(data.pilot).to_lower()
			var reserved=0 if find_profile(data,data.pilot) != "" else 1
			if not is_active and data.profiles.size()>=MAX_PROFILES-reserved:
				push_warning("Voortgang: piloot %s past niet meer op dit apparaat en is weggelaten." % name)
				continue
			data.profiles[name]=clean_profile(raw.profiles[key])
	# The top level is the latest state of the active pilot.
	var active=find_profile(data,data.pilot)
	if not active.is_empty():
		data.pilot=active
	data.profiles[data.pilot]=snapshot(data)
	if raw.get("endpoint") is String and valid_endpoint(raw.endpoint.strip_edges()):
		data.endpoint=raw.endpoint.strip_edges()
	# The catalog and map bounds are only loaded when there is something to check.
	if raw.get("custom") is Array and not raw.custom.is_empty():
		var valid_codes: Array=[]
		var catalog=TopoCatalog.new()
		for p in catalog.places:
			if p.kind=="land":
				valid_codes.append(p.code)
		var map_bounds: Array=nl_bounds()
		if raw.custom.size()>MAX_CUSTOM:
			push_warning("Voortgang: %d oudste eigen plaatsen weggelaten (maximaal %d)." % [raw.custom.size()-MAX_CUSTOM,MAX_CUSTOM])
		for p in raw.custom.slice(maxi(0,raw.custom.size()-MAX_CUSTOM)):
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
			var region: String="nl" if TopoWorld.in_bounds(map_bounds,lat,lon) and p.kind!="land" else "eu"
			data.custom.append({"name":p.name,"lat":lat,"lon":lon,"kind":p.kind,"region":region,"code":code})
	return data
