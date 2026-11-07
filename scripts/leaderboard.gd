class_name Leaderboard
extends RefCounted

# Local high-score lists, one per route and game mode. Records ranks on time
# (lower is better, penalties included); Leren and Oefenen rank on the flight
# points of that mission, with time as the tie-breaker.
const MAX_ENTRIES = 10
const MAX_BOARDS = 300
const MODE_IDS = ["leren","oefenen","records"]
const MAX_PILOT = 20

# Longest route part that still leaves room for "|oefenen" within MAX_KEY.
const MAX_KEY = 100
const MAX_ROUTE_KEY = 92

# Route keys with a "|" or that are too long are hashed, so a stored key always loads again.
static func key(route_key: String,mode: int) -> String:
	if "|" in route_key or route_key.length()>MAX_ROUTE_KEY:
		route_key="h_"+route_key.sha256_text()
	return route_key+"|"+MODE_IDS[clampi(mode,0,2)]

# The mode is whatever follows the last "|".
static func mode_name(board_key: String) -> String:
	var parts: PackedStringArray=board_key.rsplit("|",true,1)
	return parts[parts.size()-1] if parts.size()==2 else ""

static func valid_key(board_key: Variant) -> bool:
	return board_key is String and board_key.length()<=MAX_KEY and mode_name(board_key) in MODE_IDS

static func mode_of(board_key: String) -> int:
	return maxi(MODE_IDS.find(mode_name(board_key)),0)

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
# The key and entry obey the same rules as on load, so nothing is stored that a restart would drop.
# The board moves to the end of the dictionary, so the first one is always the least recently used.
static func add(boards: Dictionary,board_key: String,raw_entry: Dictionary) -> int:
	var entry=clean_entry(raw_entry)
	if not valid_key(board_key) or entry.is_empty():
		return 0
	var mode=mode_of(board_key)
	var entries: Array=boards.get(board_key,[])
	if boards.has(board_key):
		boards.erase(board_key)
	else:
		while boards.size()>=MAX_BOARDS:
			boards.erase(boards.keys()[0])
	boards[board_key]=entries
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
	var dropped_boards=0
	var dropped_entries=0
	for board_key in raw:
		if not valid_key(board_key) or not raw[board_key] is Array:
			dropped_boards+=1
			continue
		var entries: Array=[]
		for item in raw[board_key].slice(0,MAX_ENTRIES):
			var entry=clean_entry(item)
			if not entry.is_empty():
				entries.append(entry)
		dropped_entries+=raw[board_key].size()-entries.size()
		if not entries.is_empty():
			sort(entries,mode_of(board_key))
			boards[board_key]=entries
	# JSON.stringify sorts keys, so the file order says nothing about use. The newest score date
	# stands in for it: oldest first, and past the cap those go.
	var latest: Dictionary={}
	for board_key in boards:
		latest[board_key]=boards[board_key].map(func(e): return e.date).max()
	var ordered: Array=boards.keys()
	ordered.sort_custom(func(a,b): return latest[a]<latest[b] if latest[a]!=latest[b] else a<b)
	var by_use: Dictionary={}
	for board_key in ordered:
		by_use[board_key]=boards[board_key]
	boards=by_use
	while boards.size()>MAX_BOARDS:
		boards.erase(boards.keys()[0])
		dropped_boards+=1
	if dropped_boards>0 or dropped_entries>0:
		push_warning("Ranglijst: %d lijsten en %d scores weggelaten bij het laden." % [dropped_boards,dropped_entries])
	return boards
