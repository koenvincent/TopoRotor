extends Node3D

var catalog = TopoCatalog.new()
var world: TopoWorld
var helicopter: RotorHelicopter
var camera: Camera3D
var ui: Control
var menu: PanelContainer
var hud: Control
var summary: PanelContainer
var joystick: FlightJoystick
var minimap: FlightMinimap
var title_label: Label
var detail_label: Label
var progress_label: Label
var status_label: Label
var region_select: OptionButton
var mode_select: OptionButton
var mute_button: Button
var hint_button: Button
var photo_dialog: PanelContainer
var photo_backdrop: ColorRect
var launch_button: Button
var file_picker: FileDialog
var photo_preview: TextureRect
var mission_text: TextEdit
var import_status: Label
var endpoint: LineEdit
var ocr_token: LineEdit
var ocr_in_flight: bool = false
var ocr_input_snapshot: String = ""
var is_test_mode: bool = OS.get_cmdline_user_args().has("--smoke-test")
var http: HTTPRequest
var photo_bytes: PackedByteArray
var photo_image: Image
var custom_places: Array = []
var mission: Array = []
var mission_index: int = 0
var completed: Array = []
var mistakes: int = 0
var hints_used: bool = false
var state: String = "menu"
var region: String = "nl"
var exam: bool = false
var show_hints: bool = true
var flight_time: float = 0.0
var velocity: Vector2 = Vector2.ZERO
var saved: Dictionary = {"best":{},"custom":[],"endpoint":"","mute":false}
var rotor_audio: AudioStreamPlayer
var feedback_audio: AudioStreamPlayer
var paused_from: String = "menu"
var photo_open: bool = false
var answer_cooldown: float = 0.0
var keyboard: Vector2 = Vector2.ZERO
var show_overview: bool = false

const INK = Color("143740")
const CREAM = Color("f5efdc")
const GOLD = Color("ffc35c")

func _ready() -> void:
	if not is_test_mode:
		load_save()
	build_environment()
	build_ui()
	load_world("nl")
	state="menu"
	if OS.get_cmdline_user_args().has("--smoke-test"):
		call_deferred("smoke_test")
	if OS.get_cmdline_user_args().has("--capture"):
		call_deferred("capture_preview")

func build_environment() -> void:
	var env = WorldEnvironment.new()
	var e = Environment.new()
	e.background_mode=Environment.BG_COLOR
	e.background_color=Color("286375")
	e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color=Color("d6e8df")
	e.ambient_light_energy=.65
	e.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	env.environment=e
	add_child(env)
	var sun=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-65,-32,0)
	sun.light_color=Color("fff2d2")
	sun.light_energy=1.05
	sun.shadow_enabled=true
	sun.directional_shadow_max_distance=300
	add_child(sun)
	camera=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.far=2000
	add_child(camera)
	camera.current=true
	helicopter=RotorHelicopter.new()
	helicopter.scale=Vector3.ONE*1.55
	add_child(helicopter)
	helicopter.position=Vector3(0,3.3,0)
	rotor_audio=AudioStreamPlayer.new()
	rotor_audio.stream=load("res://assets/rotor.wav")
	rotor_audio.volume_db=-24
	add_child(rotor_audio)
	feedback_audio=AudioStreamPlayer.new()
	feedback_audio.stream=load("res://assets/success.wav")
	feedback_audio.volume_db=-12
	add_child(feedback_audio)

func style(color: Color,radius: int=18,border: Color=Color.TRANSPARENT) -> StyleBoxFlat:
	var s=StyleBoxFlat.new()
	s.bg_color=color
	s.set_corner_radius_all(radius)
	s.content_margin_left=20
	s.content_margin_right=20
	s.content_margin_top=14
	s.content_margin_bottom=14
	s.border_color=border
	if border.a>0:
		s.set_border_width_all(1)
	return s

func label(text: String,size_px: int=20,color: Color=CREAM) -> Label:
	var l=Label.new()
	l.text=text
	l.add_theme_font_size_override("font_size",size_px)
	l.add_theme_color_override("font_color",color)
	return l

func button(text: String,action: Callable,gold: bool=false) -> Button:
	var b=Button.new()
	b.text=text
	b.custom_minimum_size.y=52
	b.add_theme_font_size_override("font_size",20)
	b.add_theme_stylebox_override("normal",style(GOLD if gold else Color("28505a"),12))
	b.add_theme_stylebox_override("hover",style(Color("ffda84") if gold else Color("376875"),12))
	b.add_theme_stylebox_override("pressed",style(Color("d8a044") if gold else Color("14353e"),12))
	b.add_theme_color_override("font_color",INK if gold else CREAM)
	b.add_theme_color_override("font_hover_color",INK if gold else CREAM)
	b.add_theme_color_override("font_pressed_color",INK if gold else CREAM)
	b.pressed.connect(action)
	return b

func build_ui() -> void:
	var canvas=CanvasLayer.new()
	add_child(canvas)
	ui=Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter=Control.MOUSE_FILTER_IGNORE
	canvas.add_child(ui)
	var theme=Theme.new()
	theme.default_font=load("res://assets/interface.ttf")
	theme.default_font_size=18
	ui.theme=theme
	menu=PanelContainer.new()
	menu.position=Vector2(36,36)
	menu.size=Vector2(450,648)
	menu.add_theme_stylebox_override("panel",style(Color(.045,.13,.17,.96),24))
	ui.add_child(menu)
	var col=VBoxContainer.new()
	col.add_theme_constant_override("separation",13)
	menu.add_child(col)
	col.add_child(label("TOPOGRAFIE · VLIEGAVONTUUR",14,Color("9fc5bc")))
	col.add_child(label("TopoRotor",52,GOLD))
	var intro=label("De wereld is je speelveld.\nVlieg je huiswerk tegemoet.",22)
	col.add_child(intro)
	col.add_child(HSeparator.new())
	col.add_child(label("KIES JE VLUCHTGEBIED",13,Color("9fc5bc")))
	region_select=OptionButton.new()
	region_select.add_item("Nederland · steden en wateren")
	region_select.add_item("Europa · landen en hoofdsteden")
	region_select.custom_minimum_size.y=48
	region_select.item_selected.connect(func(index): load_world("nl" if index==0 else "eu"))
	col.add_child(region_select)
	mode_select=OptionButton.new()
	mode_select.add_item("Oefenen · kaartnamen en hints")
	mode_select.add_item("Testvlucht · zonder kaartnamen")
	mode_select.custom_minimum_size.y=48
	col.add_child(mode_select)
	col.add_child(button("Start vliegmissie  →",func(): start_mission(),true))
	col.add_child(button("Foto / eigen topo-opdrachten",open_photo_dialog))
	var hint=label("Foto toevoegen, locaties controleren en vliegen.\nJe kunt ook een eigen lijst typen.",14,Color("b1c9c1"))
	col.add_child(hint)
	mute_button=button("Geluid: uit" if saved.mute else "Geluid: aan",toggle_sound)
	col.add_child(mute_button)
	var best=label("Klaar voor vertrek, piloot?",15,Color("b1c9c1"))
	best.name="Best"
	col.add_child(best)
	var tag=label("ECHTE KAART. EIGEN MISSIES.",15,Color("f1ecd1"))
	tag.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	tag.position=Vector2(-380,-42)
	ui.add_child(tag)
	hud=Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter=Control.MOUSE_FILTER_IGNORE
	ui.add_child(hud)
	var top=PanelContainer.new()
	top.position=Vector2(24,20)
	top.size=Vector2(630,128)
	top.add_theme_stylebox_override("panel",style(Color(.035,.12,.16,.94),18))
	hud.add_child(top)
	var topcol=VBoxContainer.new()
	top.add_child(topcol)
	progress_label=label("MISSIE 01 / 12",13,Color("a8c8bf"))
	topcol.add_child(progress_label)
	title_label=label("Vlieg naar Utrecht",28,GOLD)
	topcol.add_child(title_label)
	detail_label=label("",15)
	topcol.add_child(detail_label)
	var pause=button("Hangar",return_menu)
	pause.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	pause.position=Vector2(-157,20)
	pause.size=Vector2(133,52)
	hud.add_child(pause)
	minimap=FlightMinimap.new()
	minimap.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	minimap.position=Vector2(-234,88)
	minimap.size=Vector2(210,180)
	minimap.mouse_filter=Control.MOUSE_FILTER_IGNORE
	hud.add_child(minimap)
	joystick=FlightJoystick.new()
	joystick.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	joystick.position=Vector2(28,-205)
	joystick.size=Vector2(180,180)
	hud.add_child(joystick)
	var movement=label("STUREN",12,CREAM)
	movement.position=Vector2(90,-26)
	joystick.add_child(movement)
	var actions=VBoxContainer.new()
	actions.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	actions.position=Vector2(-270,-225)
	actions.size=Vector2(246,200)
	actions.add_theme_constant_override("separation",10)
	hud.add_child(actions)
	actions.add_child(button("Hier is het!  ✓",answer,true))
	hint_button=button("Hint / kaartnamen",toggle_hint)
	actions.add_child(hint_button)
	actions.add_child(button("Overzichtskaart",toggle_overview))
	status_label=label("",19,CREAM)
	status_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	status_label.position=Vector2(250,-98)
	status_label.size=Vector2(720,60)
	status_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	status_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	hud.add_child(status_label)
	hud.hide()
	build_photo_dialog()

func load_world(new_region: String) -> void:
	region=new_region
	if is_instance_valid(world):
		remove_child(world)
		world.queue_free()
	world=TopoWorld.new()
	add_child(world)
	world.build(region,catalog)
	minimap.world=world
	helicopter.position=world.project(5.1214,52.0907)+Vector3(0,3.3,0)
	position_menu_camera()
	world.set_hints(false)

func start_mission(custom: Array = []) -> void:
	if is_instance_valid(summary):
		summary.queue_free()
	mission=custom.duplicate() if not custom.is_empty() else catalog.presets(region)
	mission.shuffle()
	world.ensure_mission_markers(mission)
	mission_index=0
	completed=[]
	mistakes=0
	flight_time=0
	exam=mode_select.selected==1
	show_hints=not exam
	hint_button.text="Hints verbergen" if show_hints else "Hint / kaartnamen"
	hints_used=false
	show_overview=false
	state="flight"
	menu.hide()
	hud.show()
	velocity=Vector2.ZERO
	joystick.reset()
	helicopter.position=world.project(5.1214,52.0907)+Vector3(0,3.3,0)
	if not saved.mute:
		rotor_audio.play()
	camera.size=92 if region=="nl" else 130
	update_goal()

func update_goal() -> void:
	if mission_index>=mission.size():
		finish_mission()
		return
	var p: Dictionary=mission[mission_index]
	world.target.position=world.project(p.lon,p.lat)
	world.target.visible=show_hints
	world.set_hints(show_hints)
	minimap.goal=world.target.position
	minimap.show_goal=show_hints
	progress_label.text="%s  ·  MISSIE %02d / %02d" % ["TESTVLUCHT" if exam else "OEFENVLUCHT",mission_index+1,mission.size()]
	title_label.text=("Vlieg boven " if p.kind=="land" else "Vlieg naar ")+p.name
	status_label.text="Zoek %s. Druk op ‘Hier is het!’ als je er bent." % p.name
	answer_cooldown=0.0

func _process(delta: float) -> void:
	if state!="flight" or photo_open:
		return
	flight_time+=delta
	answer_cooldown=max(0,answer_cooldown-delta)
	keyboard=Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	var direction=(keyboard+joystick.value).limit_length()
	direction *= direction.length()
	var speed=18.0 if region=="nl" else 24.0
	velocity=velocity.lerp(direction*speed,min(delta*4,1.0))
	helicopter.position.x=clamp(helicopter.position.x+velocity.x*delta,world.bounds.position.x+1,world.bounds.end.x-1)
	helicopter.position.z=clamp(helicopter.position.z+velocity.y*delta,world.bounds.position.y+1,world.bounds.end.y-1)
	if velocity.length()>1:
		helicopter.rotation.y=lerp_angle(helicopter.rotation.y,atan2(-velocity.x,-velocity.y),min(delta*5,1.0))
	helicopter.lean(direction,delta)
	var cam_goal=helicopter.position+Vector3(0,95,72)
	if show_overview:
		cam_goal=Vector3(world.bounds.get_center().x,600,world.bounds.get_center().y+400)
	camera.position=camera.position.lerp(cam_goal,min(delta*3,1.0))
	camera.look_at(Vector3(world.bounds.get_center().x,0,world.bounds.get_center().y) if show_overview else helicopter.position,Vector3.UP)
	camera.size=lerp(camera.size,(max(world.bounds.size.x,world.bounds.size.y)*1.03 if show_overview else (92.0 if region=="nl" else 130.0)),min(delta*3,1.0))
	minimap.aircraft=helicopter.position
	minimap.refresh_navigation()
	if mission_index<mission.size():
		var p: Dictionary=mission[mission_index]
		var km=distance_km(p)
		var nav="Afstand: %d km" % km if show_hints else "Gebruik de kustlijnen, rivieren en grenzen."
		detail_label.text="%s  ·  %02d:%02d  ·  %d gevonden" % [nav,int(flight_time)/60,int(flight_time)%60,completed.size()]

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if state=="flight" and not photo_open:
			if event.physical_keycode==KEY_SPACE:
				answer()
			elif event.physical_keycode==KEY_H:
				toggle_hint()
			elif event.physical_keycode==KEY_M:
				toggle_overview()
			elif event.physical_keycode==KEY_ESCAPE:
				return_menu()

func distance_km(place: Dictionary) -> float:
	var pos=world.unproject(helicopter.position)
	var lat1=deg_to_rad(pos.y)
	var lat2=deg_to_rad(place.lat)
	var dlat=lat2-lat1
	var dlon=deg_to_rad(place.lon-pos.x)
	var a=sin(dlat/2)*sin(dlat/2)+cos(lat1)*cos(lat2)*sin(dlon/2)*sin(dlon/2)
	return 6371*2*atan2(sqrt(a),sqrt(max(0,1-a)))

func answer() -> void:
	if state!="flight" or answer_cooldown>0 or photo_open:
		return
	var p: Dictionary=mission[mission_index]
	var hit=world.country_contains(p.code,helicopter.position) if p.kind=="land" else distance_km(p)<(6 if region=="nl" else 25)
	if hit:
		completed.append({"name":p.name,"hints":show_hints,"mistakes":mistakes})
		if not saved.mute:
			feedback_audio.play()
		mission_index+=1
		update_goal()
		if state=="flight":
			status_label.text="Goed gevonden! Op naar %s." % mission[mission_index].name
		answer_cooldown=.6
	else:
		mistakes+=1
		status_label.text="Nog niet op de juiste plek. Kijk nog eens naar de kaart."
		answer_cooldown=1.0

func toggle_hint() -> void:
	if state!="flight":
		return
	show_hints=not show_hints
	if show_hints:
		hints_used=true
	world.set_hints(show_hints)
	world.target.visible=show_hints
	minimap.show_goal=show_hints
	hint_button.text="Hints verbergen" if show_hints else "Hint / kaartnamen"

func toggle_overview() -> void:
	show_overview=not show_overview
	joystick.reset()

func finish_mission() -> void:
	state="summary"
	hud.hide()
	world.target.hide()
	rotor_audio.stop()
	var stars=3 if mistakes==0 and exam and not hints_used else 2 if mistakes<=2 else 1
	var key=region+("_test" if exam else "_oefenen")
	saved.best[key]=max(int(saved.best.get(key,0)),stars)
	save_data()
	summary=PanelContainer.new()
	summary.position=Vector2(340,110)
	summary.size=Vector2(600,500)
	summary.add_theme_stylebox_override("panel",style(Color(.04,.13,.17,.97),24))
	ui.add_child(summary)
	var col=VBoxContainer.new()
	col.add_theme_constant_override("separation",18)
	summary.add_child(col)
	col.add_child(label("MISSIE VOLTOOID",16,Color("a8c8bf")))
	col.add_child(label("Goed gevlogen, piloot!",32,GOLD))
	col.add_child(label("★".repeat(stars)+"☆".repeat(3-stars),52,GOLD))
	col.add_child(label("%d locaties gevonden · %d pogingen mis\nVliegtijd %02d:%02d" % [completed.size(),mistakes,int(flight_time)/60,int(flight_time)%60],21))
	var tip=label("Drie sterren: een foutloze testvlucht zonder hints.",16,Color("b5cec4"))
	tip.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	col.add_child(tip)
	col.add_child(button("Dezelfde locaties opnieuw",func(): start_mission(mission),true))
	col.add_child(button("Terug naar de hangar",return_menu))

func return_menu() -> void:
	state="menu"
	rotor_audio.stop()
	hud.hide()
	menu.show()
	joystick.reset()
	if is_instance_valid(summary):
		summary.queue_free()
	world.target.hide()
	world.set_hints(false)
	position_menu_camera()

func position_menu_camera() -> void:
	var center=world.bounds.get_center()
	var shift=95.0 if region=="nl" else 190.0
	var view_target=Vector3(center.x-shift,0,center.y)
	camera.size=330 if region=="nl" else 650
	camera.position=view_target+Vector3(0,600,450)
	camera.look_at(view_target,Vector3.UP)

func toggle_sound() -> void:
	saved.mute=not saved.mute
	mute_button.text="Geluid: uit" if saved.mute else "Geluid: aan"
	save_data()

func load_save() -> void:
	if FileAccess.file_exists("user://progress.json"):
		saved=ProgressStore.clean(JSON.parse_string(FileAccess.get_file_as_string("user://progress.json")))
	custom_places=saved.custom

func save_data() -> void:
	if is_test_mode:
		return
	var f=FileAccess.open("user://progress.json.tmp",FileAccess.WRITE)
	if f==null:
		push_warning("Kon de voortgang niet opslaan.")
		return
	f.store_string(JSON.stringify(saved,"\t"))
	f.close()
	if DirAccess.rename_absolute("user://progress.json.tmp","user://progress.json")!=OK:
		push_warning("Kon het voortgangsbestand niet vervangen.")

func build_photo_dialog() -> void:
	photo_backdrop=ColorRect.new()
	photo_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	photo_backdrop.color=Color(.015,.055,.07,.82)
	ui.add_child(photo_backdrop)
	photo_backdrop.hide()
	photo_dialog=PanelContainer.new()
	photo_dialog.position=Vector2(70,40)
	photo_dialog.size=Vector2(1140,640)
	photo_dialog.add_theme_stylebox_override("panel",style(Color("102c36"),22))
	ui.add_child(photo_dialog)
	photo_dialog.hide()
	var layout=VBoxContainer.new()
	layout.add_theme_constant_override("separation",8)
	photo_dialog.add_child(layout)
	layout.add_child(label("MIJN TOPO-OPDRACHTEN",14,GOLD))
	var row=HBoxContainer.new()
	row.add_theme_constant_override("separation",22)
	layout.add_child(row)
	row.size_flags_vertical=Control.SIZE_EXPAND_FILL
	var left=VBoxContainer.new()
	left.custom_minimum_size=Vector2(320,470)
	row.add_child(left)
	left.add_child(label("1. Voeg je schoolwerk toe",21))
	photo_preview=TextureRect.new()
	photo_preview.custom_minimum_size=Vector2(320,325)
	photo_preview.size_flags_vertical=Control.SIZE_EXPAND_FILL
	photo_preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	photo_preview.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	left.add_child(photo_preview)
	left.add_child(button("Kies foto (JPG / PNG)",func(): file_picker.popup_centered_ratio(.8)))
	var privacy=label("De foto blijft op dit apparaat.\nTekstherkenning verstuurt hem alleen\nals je zelf op die knop drukt.",14)
	left.add_child(privacy)
	var right=VBoxContainer.new()
	right.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation",9)
	row.add_child(right)
	right.add_child(label("2. Controleer de locaties",21))
	var help=label("Eén naam per regel, of gescheiden met komma's.\nEigen punt: naam | breedtegraad | lengtegraad",14)
	right.add_child(help)
	mission_text=TextEdit.new()
	mission_text.custom_minimum_size=Vector2(650,180)
	mission_text.size_flags_vertical=Control.SIZE_EXPAND_FILL
	mission_text.placeholder_text="Amsterdam\nArnhem\nIJsselmeer\nOf: Mijn dorp | 52.123 | 5.456"
	right.add_child(mission_text)
	mission_text.text_changed.connect(validate_custom)
	import_status=label("Voer eerst de locaties in.",14,GOLD)
	import_status.clip_text=true
	import_status.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	right.add_child(import_status)
	right.add_child(label("Optioneel: tekstherkenning via eigen OCR-service",14))
	endpoint=LineEdit.new()
	endpoint.placeholder_text="https://jouw-service.example/extract"
	endpoint.text=saved.endpoint
	endpoint.custom_minimum_size.y=40
	right.add_child(endpoint)
	ocr_token=LineEdit.new()
	ocr_token.placeholder_text="OCR-toegangstoken (blijft alleen in geheugen)"
	ocr_token.secret=true
	ocr_token.custom_minimum_size.y=40
	right.add_child(ocr_token)
	right.add_child(button("Herken tekst uit foto",request_ocr))
	var footer=HBoxContainer.new()
	footer.add_theme_constant_override("separation",14)
	layout.add_child(footer)
	var close=button("Terug",func():
		http.cancel_request()
		ocr_in_flight=false
		photo_dialog.hide()
		photo_backdrop.hide()
		photo_open=false
	)
	close.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	footer.add_child(close)
	launch_button=button("Vlieg deze locaties  →",launch_custom,true)
	launch_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	footer.add_child(launch_button)
	file_picker=FileDialog.new()
	file_picker.file_mode=FileDialog.FILE_MODE_OPEN_FILE
	file_picker.access=FileDialog.ACCESS_FILESYSTEM
	file_picker.use_native_dialog=true
	file_picker.filters=PackedStringArray(["*.png, *.jpg, *.jpeg ; Foto's"])
	file_picker.file_selected.connect(import_photo)
	ui.add_child(file_picker)
	http=HTTPRequest.new()
	http.timeout=45
	http.max_redirects=0
	http.body_size_limit=1024*1024
	http.request_completed.connect(ocr_response)
	add_child(http)

func open_photo_dialog() -> void:
	photo_open=true
	if mission_text.text.is_empty() and not custom_places.is_empty():
		var names=PackedStringArray()
		for p in custom_places:
			if catalog.lookup.has(catalog.normalize(p.name)):
				names.append(p.name)
			else:
				names.append("%s | %s | %s" % [p.name,p.lat,p.lon])
		mission_text.text="\n".join(names)
	if FileAccess.file_exists("user://worksheet.png"):
		var img=Image.load_from_file("user://worksheet.png")
		if img:
			photo_image=img
			photo_bytes=img.save_png_to_buffer()
			photo_preview.texture=ImageTexture.create_from_image(img)
	validate_custom()
	photo_dialog.size=Vector2(1140,640)
	photo_backdrop.show()
	photo_dialog.show()
	call_deferred("fit_photo_panel")

func fit_photo_panel() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	photo_dialog.size=Vector2(1140,640)
	photo_dialog.position=Vector2(70,40)

func import_photo(path: String) -> void:
	var file=FileAccess.open(path,FileAccess.READ)
	if file==null:
		import_status.text="Kan deze foto niet openen. Kies een JPG of PNG."
		return
	if file.get_length()>WorksheetImage.MAX_BYTES:
		import_status.text="Foto te groot. Kies een foto kleiner dan 25 MB."
		return
	var bytes=file.get_buffer(file.get_length())
	file.close()
	if not WorksheetImage.allowed_size(WorksheetImage.dimensions(bytes)):
		import_status.text="Gebruik een JPG/PNG van maximaal 12 megapixel."
		return
	var img=Image.new()
	var error=img.load_png_from_buffer(bytes) if bytes[0]==137 else img.load_jpg_from_buffer(bytes)
	if error!=OK or img.is_empty():
		import_status.text="Deze foto is beschadigd. Kies een andere JPG of PNG."
		return
	if max(img.get_width(),img.get_height())>1800:
		var factor=1800.0/max(img.get_width(),img.get_height())
		img.resize(max(1,int(img.get_width()*factor)),max(1,int(img.get_height()*factor)),Image.INTERPOLATE_LANCZOS)
	http.cancel_request()
	ocr_in_flight=false
	photo_image=img
	photo_bytes=img.save_png_to_buffer()
	if img.save_png("user://worksheet.png")!=OK:
		push_warning("De foto is geladen, maar kon niet lokaal worden bewaard.")
	photo_preview.texture=ImageTexture.create_from_image(img)
	photo_dialog.size=Vector2(1140,640)
	call_deferred("fit_photo_panel")
	import_status.text="Foto toegevoegd. Typ de namen over of gebruik tekstherkenning."

func parse_custom() -> Dictionary:
	var ordinary: Array = []
	var manual: Array = []
	var errors: Array = []
	for raw in mission_text.text.replace(";","\n").split("\n"):
		if raw.contains("|"):
			var parts=raw.split("|")
			if parts.size()!=3 or not parts[1].strip_edges().is_valid_float() or not parts[2].strip_edges().is_valid_float() or parts[0].strip_edges().is_empty():
				errors.append(raw)
				continue
			var lat=float(parts[1])
			var lon=float(parts[2])
			if not is_finite(lat) or not is_finite(lon) or lon < -25 or lon > 45 or lat < 34 or lat > 72:
				errors.append(raw+" (buiten de Europakaart)")
				continue
			manual.append({"name":parts[0].strip_edges(),"lat":lat,"lon":lon,"region":"nl" if lat>=50.5 and lat<=54 and lon>=3.1 and lon<=7.5 else "eu","kind":"eigen punt","code":""})
		else:
			ordinary.append(raw)
	var result=catalog.parse_list("\n".join(ordinary))
	var names: Dictionary={}
	for place in result.found:
		names[catalog.normalize(place.name)]=true
	for place in manual:
		var name=catalog.normalize(place.name)
		if names.has(name):
			result.unknown.append(place.name+" (dubbele naam)")
		else:
			names[name]=true
			result.found.append(place)
	result.unknown.append_array(errors)
	if result.found.size()>200:
		result.unknown.append("Gebruik maximaal 200 locaties per missie")
	return result

func validate_custom() -> void:
	var result=parse_custom()
	if not result.unknown.is_empty():
		import_status.text="Controleer onbekende namen: "+", ".join(result.unknown)
	else:
		import_status.text="%d locaties herkend. Klaar om te vliegen." % result.found.size()
	launch_button.disabled=result.found.is_empty() or not result.unknown.is_empty()

func launch_custom() -> void:
	http.cancel_request()
	ocr_in_flight=false
	var result=parse_custom()
	if result.found.is_empty() or not result.unknown.is_empty():
		validate_custom()
		return
	custom_places=result.found
	saved.custom=custom_places
	saved.endpoint=endpoint.text.strip_edges()
	save_data()
	var needed="nl"
	for p in custom_places:
		if p.region=="eu":
			needed="eu"
	if needed!=region:
		load_world(needed)
		region_select.select(1 if needed=="eu" else 0)
	photo_dialog.hide()
	photo_backdrop.hide()
	photo_open=false
	start_mission(custom_places)

func request_ocr() -> void:
	if photo_bytes.is_empty():
		import_status.text="Voeg eerst een foto toe."
		return
	var url=endpoint.text.strip_edges()
	if not url.begins_with("https://"):
		import_status.text="Gebruik een HTTPS-adres voor je OCR-service. Zie README."
		return
	if ocr_token.text.to_utf8_buffer().size()<32 or "\n" in ocr_token.text or "\r" in ocr_token.text:
		import_status.text="Vul het OCR-toegangstoken van je eigen service in (minimaal 32 bytes)."
		return
	if ocr_in_flight:
		import_status.text="De herkenning is al bezig."
		return
	import_status.text="Foto wordt naar jouw OCR-service verstuurd…"
	ocr_in_flight=true
	ocr_input_snapshot=mission_text.text
	var error=http.request_raw(url,PackedStringArray(["Content-Type: image/png","Authorization: Bearer "+ocr_token.text]),HTTPClient.METHOD_POST,photo_bytes)
	if error!=OK:
		ocr_in_flight=false
		import_status.text="Kan de OCR-service niet bereiken. Je kunt de namen zelf typen."

func ocr_response(result: int,code: int,_headers: PackedStringArray,body: PackedByteArray) -> void:
	ocr_in_flight=false
	if not photo_open:
		return
	if mission_text.text!=ocr_input_snapshot:
		import_status.text="Herkenning klaar; je aangepaste lijst blijft bewaard. Herhaal indien gewenst."
		return
	if result!=HTTPRequest.RESULT_SUCCESS or code!=200:
		import_status.text="Tekstherkenning niet gelukt (%d). Controleer het adres of typ de namen." % code
		return
	var data=JSON.parse_string(body.get_string_from_utf8())
	if not data is Dictionary or not data.get("candidates") is Array or data.candidates.size()>200:
		import_status.text="Onverwacht antwoord van de OCR-service."
		return
	var names=PackedStringArray()
	for name in data.candidates:
		if not name is String or name.length()>120 or "\n" in name or "|" in name:
			import_status.text="Onverwacht antwoord van de OCR-service."
			return
		names.append(name)
	if names.is_empty():
		import_status.text="Geen bekende locaties gevonden. Typ ze over van de foto."
		return
	mission_text.text="\n".join(names)
	validate_custom()
	import_status.text+=" Controleer of er namen missen of onterecht zijn toegevoegd."

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
		if is_instance_valid(joystick):
			joystick.reset()
		velocity=Vector2.ZERO
		if state=="flight":
			return_menu()

func smoke_test() -> void:
	var progress_existed=FileAccess.file_exists("user://progress.json")
	var progress_before=FileAccess.get_file_as_bytes("user://progress.json") if progress_existed else PackedByteArray()
	saved.mute=true # Headless tests have no audio output device.
	var parsed=catalog.parse_list("1. Arnhem\nDen Haag, Parijs\nOnbekenddorp")
	assert(parsed.found.size()==3,"Catalog parser: number prefixes and comma lists")
	assert(parsed.unknown==["Onbekenddorp"],"Unknown names must not disappear")
	var p=world.project(5.8987,51.9851)
	var geo=world.unproject(p)
	assert(abs(geo.x-5.8987)<.001 and abs(geo.y-51.9851)<.001,"Coordinate round trip")
	assert(world.country_contains("NLD",world.project(5.1214,52.0907)),"Utrecht in Netherlands")
	assert(not world.country_contains("NLD",world.project(3.4,53.0)),"North Sea not Netherlands")
	start_mission([catalog.lookup.arnhem])
	helicopter.position=world.project(5.8987,51.9851)+Vector3(0,3.3,0)
	assert(distance_km(mission[0])<.01,"Distance at target")
	answer()
	assert(state=="summary" and completed.size()==1,"Mission completes on correct answer")
	return_menu()
	load_world("eu")
	assert(world.country_contains("FRA",world.project(2.3522,48.8566)),"Paris in France")
	assert(not world.country_contains("FRA",world.project(13.405,52.52)),"Berlin not France")
	mission_text.text="Mijn dorp | 52.123 | 5.456\nAmsterdam"
	var custom=parse_custom()
	assert(custom.found.size()==2 and custom.unknown.is_empty(),"Custom coordinate import")
	mission_text.text="Buiten | 90 | 100"
	assert(not parse_custom().unknown.is_empty(),"Out of bounds coordinate rejected")
	# Regression checks added during the 0.2 source review.
	var restored=ProgressStore.clean({"best":[],"mute":"yes","custom":[false,{"name":"broken"}],"endpoint":42})
	assert(restored.best is Dictionary and restored.custom.is_empty() and restored.mute==false,"Corrupt progress is sanitized")
	var valid_saved=ProgressStore.clean(JSON.parse_string(JSON.stringify({"best":{"nl_test":3,"eu_test":99},"custom":[{"name":"Eigen dorp","lat":52.1,"lon":5.4,"kind":"eigen punt","code":""}]})))
	assert(valid_saved.best.nl_test==3 and not valid_saved.best.has("eu_test") and valid_saved.custom.size()==1,"Valid progress is retained")
	mission_text.text="Amsterdam\nAmsterdam | 52.1 | 5.2"
	assert(not parse_custom().unknown.is_empty(),"Ambiguous duplicate custom names are rejected")
	mission_text.text="Eigen dorp | 52.1 | 5.4\nParijs"
	launch_custom()
	assert(state=="flight" and region=="eu" and world.label_names.has("Eigen dorp"),"Mixed custom missions get visible map markers")
	assert(world.label_names.has("Parijs"),"Known mission locations keep their marker")
	var img=Image.create(12,8,false,Image.FORMAT_RGB8)
	var png=img.save_png_to_buffer()
	assert(WorksheetImage.dimensions(png)==Vector2i(12,8),"PNG header validation")
	var jpeg=img.save_jpg_to_buffer()
	assert(WorksheetImage.dimensions(jpeg)==Vector2i(12,8),"JPEG header validation")
	assert(not WorksheetImage.allowed_size(Vector2i(5000,5000)),"Oversized pixel buffers rejected")
	assert(WorksheetImage.dimensions(png.slice(0,12))==Vector2i.ZERO,"Truncated image rejected")
	var old_best=JSON.stringify(saved.best)
	save_data()
	assert(FileAccess.file_exists("user://progress.json")==progress_existed,"Smoke mode does not create or delete progress")
	if progress_existed:
		assert(FileAccess.get_file_as_bytes("user://progress.json")==progress_before,"Smoke mode preserves existing progress bytes")
	assert(JSON.stringify(saved.best)==old_best,"Saving does not mutate score values")
	photo_open=true
	mission_text.text="Arnhem"
	ocr_input_snapshot="Amsterdam"
	ocr_response(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),JSON.stringify({"candidates":["Parijs"]}).to_utf8_buffer())
	assert(mission_text.text=="Arnhem","Late OCR does not overwrite edits")
	ocr_input_snapshot=mission_text.text
	ocr_response(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),JSON.stringify({"candidates":[42]}).to_utf8_buffer())
	assert(mission_text.text=="Arnhem","Malformed OCR candidates rejected")
	assert(http.max_redirects==0,"OCR credentials cannot follow redirects")
	photo_open=false
	return_menu()
	feedback_audio.stop()
	print("SMOKE TEST PASSED: parsing, coordinates, land boundaries, flight scoring, custom missions")
	await get_tree().process_frame
	get_tree().quit()

func capture_preview() -> void:
	DirAccess.make_dir_recursive_absolute("res://build")
	start_mission([catalog.lookup.amsterdam,catalog.lookup.rotterdam])
	helicopter.position=world.project(5.0,52.23)+Vector3(0,3.3,0)
	camera.position=helicopter.position+Vector3(0,95,72)
	camera.look_at(helicopter.position)
	await get_tree().create_timer(2).timeout
	var background_count=minimap.background_draws
	await get_tree().create_timer(.2).timeout
	assert(minimap.background_draws==background_count,"Moving navigation does not redraw country geometry")
	var image=get_viewport().get_texture().get_image()
	image.save_png("res://build/preview-flight.png")
	return_menu()
	await get_tree().create_timer(.5).timeout
	get_viewport().get_texture().get_image().save_png("res://build/preview-hangar.png")
	open_photo_dialog()
	import_photo("res://examples/demo-werkblad.png")
	mission_text.text="Amsterdam\nRotterdam\nDen Haag\nUtrecht\nArnhem"
	validate_custom()
	await get_tree().create_timer(.5).timeout
	assert(photo_dialog.size.y<=641,"Photo panel fits landscape screen")
	assert(not launch_button.disabled,"Valid photo mission can be launched")
	get_viewport().get_texture().get_image().save_png("res://build/preview-photo.png")
	print("VISUAL CHECK PASSED")
	get_tree().quit()
