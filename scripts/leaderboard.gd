class_name Leaderboard
extends RefCounted

# Local high-score lists, one per route and game mode. Records ranks on time
# (lower is better, penalties included); Leren and Oefenen rank on the flight
# points of that mission, with time as the tie-breaker.
const MAX_ENTRIES = 10
const MAX_BOARDS = 300
const MODE_IDS = ["leren","oefenen","records"]
const MAX_PILOT = 20

static func key(route_key: String,mode: int) -> String:
	return route_key+"|"+MODE_IDS[clampi(mode,0,2)]

static func mode_of(board_key: String) -> int:
	return maxi(MODE_IDS.find(board_key.get_slice("|",1)),0)

static func clean_pilot(raw: Variant) -> String:
	if not raw is String:
		return ""
	var name: String=""
	for c in raw.strip_edges():
		# Printable characters only, so a name can never break the list layout.
		if c.unicode_at(0)>=32 and c.unicode_at(0)!=127:
			name+=c
	return name.left(MAX_PILOT).strip_edges()

static func better(a: Dictionary,b: Dictionary,mode: int) -> bool:
	if mode==2:
		return a.time<b.time if a.time!=b.time else a.mistakes<b.mistakes
	return a.points>b.points if a.points!=b.points else a.time<b.time

static func sort(entries: Array,mode: int) -> void:
	entries.sort_custom(func(a,b): return better(a,b,mode))

# Adds an entry and returns its 1-based place, or 0 when it did not make the list.
static func add(boards: Dictionary,board_key: String,entry: Dictionary) -> int:
	var mode=mode_of(board_key)
	if not boards.has(board_key):
		while boards.size()>=MAX_BOARDS:
			boards.erase(boards.keys()[0])
		boards[board_key]=[]
	var entries: Array=boards[board_key]
	entries.append(entry)
	sort(entries,mode)
	var place=entries.find(entry)+1
	if entries.size()>MAX_ENTRIES:
		entries.resize(MAX_ENTRIES)
	return place if place<=MAX_ENTRIES else 0

static func clean_entry(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {}
	var points: Variant=raw.get("points")
	var time: Variant=raw.get("time")
	var mistakes: Variant=raw.get("mistakes")
	for value in [points,time,mistakes]:
		if not typeof(value) in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)) or float(value)<0:
			return {}
	if float(time)>=604800 or float(points)>HangarCatalog.MAX_POINTS or float(mistakes)>100000:
		return {}
	var date: String=raw.get("date","") if raw.get("date","") is String else ""
	if not date.length()==10:
		date=""
	return {"pilot":clean_pilot(raw.get("pilot")),"points":int(points),"time":float(time),"mistakes":int(mistakes),"date":date}

static func clean(raw: Variant) -> Dictionary:
	var boards: Dictionary={}
	if not raw is Dictionary:
		return boards
	for board_key in raw:
		if boards.size()>=MAX_BOARDS:
			break
		if not board_key is String or board_key.length()>100 or not board_key.get_slice("|",1) in MODE_IDS or not raw[board_key] is Array:
			continue
		var entries: Array=[]
		for item in raw[board_key].slice(0,MAX_ENTRIES):
			var entry=clean_entry(item)
			if not entry.is_empty():
				entries.append(entry)
		if not entries.is_empty():
			sort(entries,mode_of(board_key))
			boards[board_key]=entries
	return boards
