extends RefCounted

# Regression checks for progress persistence: profile caps, atomic saves, player notices,
# leaderboard keys, stable record keys, lesson-pack cache and Retry-After.
const TEST_SAVE = "user://ws1-progress.json"

static func run(main: Node) -> void:
	profiles()
	limits()
	endpoint_and_points()
	write_atomic()
	save_notices(main)
	leaderboard()
	route_keys(main)
	retry_after(main)
	lesson_packs(main)

static func profile_save(names: Array,active: String) -> Dictionary:
	var profiles: Dictionary={}
	for name in names:
		profiles[name]={"points":names.find(name)}
	return {"pilot":active,"profiles":profiles}

static func profiles() -> void:
	var names: Array=["Niek","A","B","C","D","E","F","G"]
	for active in ["Niek","G"]:
		var loaded=ProgressStore.clean(JSON.parse_string(JSON.stringify(profile_save(names,active))))
		assert(loaded.profiles.size()==8 and loaded.pilot==active,"A save with eight pilots loads all eight, active pilot first or last")
		for name in names:
			assert(loaded.profiles.has(name),"Pilot kept after load: "+name)
	var crowded=ProgressStore.clean(JSON.parse_string(JSON.stringify(profile_save(names+["H","I"],"Niek"))))
	assert(crowded.profiles.size()==8 and crowded.profiles.has("Niek"),"More than eight pilots stop at eight and keep the active one")
	var late=ProgressStore.clean(JSON.parse_string(JSON.stringify(profile_save(["A","B","C","D","E","F","G","H","Niek"],"Niek"))))
	assert(late.profiles.size()==8 and late.profiles.has("Niek"),"The active pilot keeps a slot when listed last")

static func limits() -> void:
	var ids: Array=[]
	for i in 45:
		ids.append("hw%d" % i)
	var homework=ProgressStore.clean({"homework":ids}).homework
	assert(homework.size()==ProgressStore.MAX_HOMEWORK and homework.has("hw44") and not homework.has("hw0"),"Homework keeps the newest ids")
	var records: Dictionary={}
	for i in 1100:
		records["r%d" % i]=10.0+i
	var kept=ProgressStore.clean({"records":records}).records
	assert(kept.size()==ProgressStore.MAX_RECORDS and kept.has("r1099") and not kept.has("r0"),"Records keep the newest times")
	var live: Dictionary={}
	for i in ProgressStore.MAX_RECORDS:
		live["k%d" % i]=1.0
	ProgressStore.remember_record(live,"k0",5.0)
	ProgressStore.remember_record(live,"new",6.0)
	assert(live.size()==ProgressStore.MAX_RECORDS and live.has("k0") and live.has("new") and not live.has("k1"),"A record write refreshes its key and evicts the oldest")
	var custom: Array=[]
	for i in 205:
		custom.append({"name":"Punt %d" % i,"lat":52.0,"lon":5.0,"kind":"eigen punt","code":""})
	var places=ProgressStore.clean({"custom":custom}).custom
	assert(places.size()==ProgressStore.MAX_CUSTOM and places[-1].name=="Punt 204" and places[0].name=="Punt 5","Custom places keep the newest")
	var bounds=ProgressStore.nl_bounds()
	assert(bounds.size()==4 and bounds==TopoWorld.map_bounds("nl") and not ProgressStore._nl_bounds.is_empty(),"Dutch map bounds are read once and cached")
	assert(ProgressStore.clean({"custom":[]}).custom.is_empty(),"An empty custom list needs no catalog")

static func endpoint_and_points() -> void:
	assert(ProgressStore.clean({"points":1e30}).points==HangarCatalog.MAX_POINTS,"A huge points value clamps to the maximum")
	assert(ProgressStore.clean({"points":120}).points==120,"Normal points are kept")
	assert(ProgressStore.clean({"endpoint":"http://scores.example/api"}).endpoint=="","Cleartext endpoint is dropped")
	assert(ProgressStore.clean({"endpoint":"file:///etc/passwd"}).endpoint=="" and ProgressStore.clean({"endpoint":"https://"}).endpoint=="","Endpoint without https host is dropped")
	assert(ProgressStore.clean({"endpoint":"https://a b.example"}).endpoint=="","Endpoint with a space is dropped")
	assert(ProgressStore.clean({"endpoint":" https://ocr.example/extract "}).endpoint=="https://ocr.example/extract","An https endpoint is kept")

static func write_atomic() -> void:
	var path="user://ws1-atomic.json"
	assert(ProgressStore.write_atomic(path,"old").is_empty() and FileAccess.get_file_as_string(path)=="old","Atomic write creates the file")
	assert(ProgressStore.write_atomic(path,"new text").is_empty() and FileAccess.get_file_as_string(path)=="new text" and not FileAccess.file_exists(path+".tmp"),"Atomic write replaces the file and leaves no temp file")
	DirAccess.make_dir_absolute(path+".tmp")
	assert(ProgressStore.write_atomic(path,"lost")=="open" and FileAccess.get_file_as_string(path)=="new text","A failed open keeps the old file")
	DirAccess.remove_absolute(path+".tmp")
	var blocked="user://ws1-blocked"
	DirAccess.make_dir_absolute(blocked)
	assert(ProgressStore.write_atomic(blocked,"x")=="rename" and not FileAccess.file_exists(blocked+".tmp"),"A failed rename removes the temp file")
	DirAccess.remove_absolute(blocked)
	DirAccess.remove_absolute(path)

static func save_notices(main: Node) -> void:
	var prior_saved: Dictionary=main.saved.duplicate(true)
	var prior_path: String=main.save_path
	var prior_custom: Array=main.custom_places
	main.save_path=TEST_SAVE
	main.progress_readonly=false
	main.save_notice=""
	main.saved.points=77
	main.save_data()
	assert(JSON.parse_string(FileAccess.get_file_as_string(TEST_SAVE)).points==77 and main.save_notice.is_empty(),"A save writes the progress without a notice")
	# Leaving the app saves choices that are only in memory.
	main.saved.points=88
	main._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert(JSON.parse_string(FileAccess.get_file_as_string(TEST_SAVE)).points==88,"Pausing the app saves the progress")
	# A write that cannot start keeps the old file and tells the player.
	var good=FileAccess.get_file_as_string(TEST_SAVE)
	DirAccess.make_dir_absolute(TEST_SAVE+".tmp")
	main.saved.points=99
	main.save_data()
	assert(FileAccess.get_file_as_string(TEST_SAVE)==good,"A failed save keeps the previous progress file")
	assert(main.save_notice.contains("Opslaan") and is_instance_valid(main.save_notice_label) and main.save_notice_label.visible and main.save_notice_label.text==main.save_notice,"A failed save shows a Dutch notice")
	DirAccess.remove_absolute(TEST_SAVE+".tmp")
	main.save_notice_label.hide()
	main.save_data()
	assert(JSON.parse_string(FileAccess.get_file_as_string(TEST_SAVE)).points==99 and main.save_notice.is_empty(),"The next save works again and clears the notice")
	# A save from a newer version is never overwritten, and the player is told.
	var future=JSON.stringify({"version":ProgressStore.VERSION+1,"points":5})
	var file=FileAccess.open(TEST_SAVE,FileAccess.WRITE)
	file.store_string(future)
	file.close()
	main.load_save()
	assert(main.progress_readonly and main.save_notice.contains("nieuwere versie") and main.save_notice_label.visible,"A newer save switches to read-only and says so")
	main.save_notice_label.hide()
	main.saved.points=1
	main.save_data()
	assert(FileAccess.get_file_as_string(TEST_SAVE)==future,"A read-only session leaves the newer file alone")
	assert(main.save_notice_label.visible and main.save_notice_label.text.contains("niet bewaard"),"Each save attempt in read-only mode repeats the notice")
	# An unreadable file is backed up, and the reset is announced.
	var broken=FileAccess.open(TEST_SAVE,FileAccess.WRITE)
	broken.store_string("{kapot")
	broken.close()
	main.progress_readonly=false
	main.save_notice_label.hide()
	main.load_save()
	assert(not main.progress_readonly and main.save_notice.contains("onleesbaar") and main.save_notice_label.visible,"An unreadable save is announced")
	for leftover in DirAccess.get_files_at("user://"):
		if leftover.begins_with("ws1-progress"):
			DirAccess.remove_absolute("user://"+leftover)
	main.save_path=prior_path
	main.saved=prior_saved
	main.custom_places=prior_custom
	main.progress_readonly=false
	main.save_notice=""
	main.save_notice_label.hide()

static func leaderboard() -> void:
	var route="Huiswerk | week 3"
	var key=Leaderboard.key(route,2)
	assert(Leaderboard.valid_key(key) and Leaderboard.mode_of(key)==2 and Leaderboard.mode_name(key)=="records","A route key with a pipe still gives a records board")
	var long_key=Leaderboard.key("x".repeat(120),0)
	assert(long_key.length()<=Leaderboard.MAX_KEY and Leaderboard.valid_key(long_key),"A long route key is shortened to a loadable key")
	var entry={"pilot":"A","points":0,"time":30.0,"mistakes":1,"date":"2026-11-07"}
	var boards: Dictionary={}
	assert(Leaderboard.add(boards,key,entry)==1 and Leaderboard.add(boards,long_key,entry)==1,"Such boards accept scores")
	assert(Leaderboard.clean(JSON.parse_string(JSON.stringify(boards))).size()==2,"Boards with a pipe or a long route survive a reload")
	assert(Leaderboard.add(boards,"zonder modus",entry)==0 and Leaderboard.add(boards,key,{"time":-1})==0,"Add refuses what a reload would drop")
	assert(Leaderboard.mode_of(Leaderboard.key("a|b",2))==2 and Leaderboard.valid_key("a|b|leren") and not Leaderboard.valid_key("leren"),"The mode is the last segment")
	# Eviction takes the least recently used board; after a reload the newest score date says which.
	var many: Dictionary={}
	for i in Leaderboard.MAX_BOARDS:
		Leaderboard.add(many,"r%d|leren" % i,dated(entry,"2026-01-01"))
	Leaderboard.add(many,"r0|leren",dated(entry,"2026-11-07"))
	Leaderboard.add(many,"nieuw|leren",dated(entry,"2026-11-06"))
	assert(many.size()==Leaderboard.MAX_BOARDS and many.has("r0|leren") and not many.has("r1|leren"),"The board that was just played outlives older ones")
	var order=Leaderboard.clean(JSON.parse_string(JSON.stringify(many)))
	assert(order.size()==Leaderboard.MAX_BOARDS and order.keys()[-1]=="r0|leren" and order.keys()[-2]=="nieuw|leren","Boards reload with the most recently scored last")
	var overfull: Dictionary={}
	for i in Leaderboard.MAX_BOARDS+5:
		overfull["b%d|leren" % i]=[dated(entry,"%04d-01-01" % (1000+i))]
	var trimmed=Leaderboard.clean(overfull)
	assert(trimmed.size()==Leaderboard.MAX_BOARDS and trimmed.has("b304|leren") and not trimmed.has("b0|leren"),"A reload over the cap drops the least recently scored boards")

static func dated(entry: Dictionary,date: String) -> Dictionary:
	var copy=entry.duplicate()
	copy.date=date
	return copy

static func route_keys(main: Node) -> void:
	var prior: Dictionary=main.saved.duplicate(true)
	var utrecht: Dictionary=main.catalog.lookup.utrecht
	var arnhem: Dictionary=main.catalog.lookup.arnhem
	var route=[utrecht,arnhem]
	var moved=utrecht.duplicate()
	moved.lat=float(moved.lat)+0.01
	assert(main.route_hash([moved,arnhem],false)==main.route_hash(route,false),"A coordinate fix in the catalog keeps the route key")
	assert(main.route_hash([moved,arnhem],true)!=main.route_hash(route,true),"The old key did change with coordinates")
	var own_a={"name":"Eigen","lat":52.0,"lon":5.0,"kind":"eigen punt","region":"nl","code":""}
	var own_b=own_a.duplicate()
	own_b.lat=52.5
	assert(main.route_hash([own_a],false)!=main.route_hash([own_b],false),"Own points are still told apart by coordinates")
	# Records and boards saved under the old key move to the new one.
	var legacy: String=main.route_hash(route,true)
	var key: String=main.route_hash(route,false)
	assert(legacy!=key,"Catalog routes have a different old and new key")
	main.saved.records={legacy:184.0}
	main.saved.boards={Leaderboard.key(legacy,2):[{"pilot":"Sara","points":10,"time":184.0,"mistakes":0,"date":"2026-11-07"}]}
	assert(main.record_key(route)==key,"record_key returns the name-based key")
	assert(main.saved.records.get(key)==184.0 and not main.saved.records.has(legacy),"A saved best time follows the route to its new key")
	var board: Array=main.saved.boards.get(Leaderboard.key(key,2),[])
	assert(board.size()==1 and board[0].pilot=="Sara" and not main.saved.boards.has(Leaderboard.key(legacy,2)),"The leaderboard follows the route to its new key")
	main.saved=prior

static func retry_after(main: Node) -> void:
	var now=Time.get_unix_time_from_datetime_string("2026-10-21T07:27:18")
	assert(main.retry_after_seconds("12",now)==12 and main.retry_after_seconds(" 900 ",now)==300 and main.retry_after_seconds("0",now)==1,"Retry-After seconds are clamped")
	assert(main.retry_after_seconds("Wed, 21 Oct 2026 07:28:00 GMT",now)==42,"Retry-After accepts an HTTP date")
	assert(main.retry_after_seconds("Wed, 21 Oct 2026 07:20:00 GMT",now)==1 and main.retry_after_seconds("Wed, 21 Oct 2026 09:00:00 GMT",now)==300,"An HTTP date in the past or far ahead is clamped")
	assert(main.retry_after_seconds("soon",now)==5 and main.retry_after_seconds("Wed, 21 Foo 2026 07:28:00 GMT",now)==5,"Unreadable Retry-After waits five seconds")

static func lesson_packs(main: Node) -> void:
	var redirect: String=main.online_error_message(HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED,0)
	assert(redirect.contains("directe") and not redirect.contains("(0)") and main.online_error_message(HTTPRequest.RESULT_SUCCESS,302).contains("directe"),"A redirect tells the teacher to use the direct link")
	assert(main.online_error_message(HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED,0).contains("256 KB") and main.online_error_message(HTTPRequest.RESULT_TIMEOUT,0).contains("te lang"),"Size and timeout failures are explained")
	assert(main.online_error_message(HTTPRequest.RESULT_CANT_RESOLVE,0).contains("verbinding") and main.online_error_message(HTTPRequest.RESULT_SUCCESS,404).contains("404"),"Offline and HTTP errors are told apart")
	var prior_packs: Array=main.online_packs
	var mixed='{"version":1,"missions":[{"title":"Goed","places":["Utrecht","Arnhem"]},{"title":"Verouderd","places":["Bestaat niet meer"]}]}'
	assert(not main.apply_online_content(mixed),"A fresh download with an unknown place is refused as a whole")
	assert(main.apply_online_content(mixed,true) and main.online_packs.size()==1 and main.online_packs[0].title=="Goed" and main.content_status.text.contains("1 overgeslagen"),"The offline copy keeps the valid missions")
	assert(not main.apply_online_content('{"version":1,"missions":[{"title":"Verouderd","places":["Bestaat niet meer"]}]}',true),"An offline copy without a valid mission is refused")
	main.online_packs=prior_packs
