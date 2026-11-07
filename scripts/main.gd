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
var clock_select: OptionButton
var timed: bool = false
var time_limit: float = 0.0
var timed_out: bool = false
var content_http: HTTPRequest
var content_status: Label
var content_url: LineEdit
var content_list: ItemList
var content_dialog: AcceptDialog
var online_packs: Array = []
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
var ocr_retry_after_msec: int = 0
# Test/capture harness is only reachable from debug (editor/CI) builds, never from release exports.
var is_test_mode: bool = OS.is_debug_build() and OS.get_cmdline_user_args().has("--smoke-test")
var is_capture_mode: bool = OS.is_debug_build() and OS.get_cmdline_user_args().has("--capture")
# Smoke tests exercise the real save path against a separate file, never the player's profile.
var save_path: String = "user://smoke-progress.json" if is_test_mode else "user://progress.json"
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
var camera_level: int = 0
var height_label: Label
var lower_button: Button
var higher_button: Button
const FLIGHT_ZOOMS = [22.0,38.0,64.0]
const FLIGHT_ALTITUDES = [9.0,14.0,23.0]
const HEIGHT_NAMES = ["Laag","Midden","Hoog"]
var best_label: Label
var custom_mission: bool = false
var progress_readonly: bool = false

var nl_bounds: Array = TopoWorld.map_bounds("nl")

const SPAWN = Vector2(5.1214,52.0907) # Utrecht (lon, lat)
const INK = Color("143740")
const CREAM = Color("f5efdc")
const GOLD = Color("ffc35c")

func _ready() -> void:
	if not is_test_mode and not is_capture_mode:
		load_save()
	build_environment()
	build_ui()
	load_world("nl")
	state="menu"
	if is_test_mode:
		call_deferred("smoke_test")
	if is_capture_mode:
		call_deferred("capture_preview")

func build_environment() -> void:
	var env = WorldEnvironment.new()
	var e = Environment.new()
	e.background_mode=Environment.BG_COLOR
	e.background_color=Color("286375")
	e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color=Color("d6e8df")
	e.ambient_light_energy=.55
	e.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	env.environment=e
	add_child(env)
	var sun=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-48,-28,0)
	sun.light_color=Color("fff2d2")
	sun.light_energy=.9
	sun.shadow_enabled=true
	sun.directional_shadow_max_distance=450
	sun.shadow_bias=.03
	sun.light_specular=.25
	sun.directional_shadow_mode=DirectionalLight3D.SHADOW_ORTHOGONAL
	add_child(sun)
	camera=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.far=2000
	add_child(camera)
	camera.current=true
	helicopter=RotorHelicopter.new()
	helicopter.scale=Vector3.ONE*1.25
	add_child(helicopter)
	helicopter.position=Vector3(0,9.0 if region=="nl" else 3.3,0)
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
	# Only touch index 0 is emulated as mouse input; handle extra fingers (e.g. while steering) here.
	b.gui_input.connect(func(event: InputEvent):
		if event is InputEventScreenTouch and event.pressed and event.index>0 and not b.disabled:
			b.accept_event()
			action.call()
	)
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
	var menu_scroll=ScrollContainer.new()
	menu_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	menu.add_child(menu_scroll)
	var col=VBoxContainer.new()
	col.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation",8)
	menu_scroll.add_child(col)
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
	clock_select=OptionButton.new()
	clock_select.add_item("Vrij vliegen · zonder tijdslimiet")
	clock_select.add_item("Tijdrit · 90 seconden per locatie")
	clock_select.custom_minimum_size.y=44
	col.add_child(clock_select)
	col.add_child(button("Online missies",open_online_content))
	col.add_child(button("Start vliegmissie  →",func(): start_mission(),true))
	col.add_child(button("Foto / eigen topo-opdrachten",open_photo_dialog))
	var hint=label("Foto toevoegen, locaties controleren en vliegen.\nJe kunt ook een eigen lijst typen.",14,Color("b1c9c1"))
	col.add_child(hint)
	mute_button=button("Geluid: uit" if saved.mute else "Geluid: aan",toggle_sound)
	col.add_child(mute_button)
	best_label=label("Klaar voor vertrek, piloot?",15,Color("b1c9c1"))
	best_label.name="Best"
	col.add_child(best_label)
	var credits=LinkButton.new()
	credits.text="Bronnen en licenties"
	credits.add_theme_font_size_override("font_size",13)
	credits.pressed.connect(show_credits)
	col.add_child(credits)
	hud=Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter=Control.MOUSE_FILTER_IGNORE
	ui.add_child(hud)
	var top=PanelContainer.new()
	top.position=Vector2(24,20)
	top.size=Vector2(470,112)
	top.add_theme_stylebox_override("panel",style(Color(.035,.12,.16,.94),18))
	hud.add_child(top)
	var topcol=VBoxContainer.new()
	top.add_child(topcol)
	progress_label=label("MISSIE 01 / 12",13,Color("a8c8bf"))
	topcol.add_child(progress_label)
	title_label=label("Vlieg naar Utrecht",26,GOLD)
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
	minimap.position=Vector2(-284,88)
	minimap.size=Vector2(260,230)
	minimap.mouse_filter=Control.MOUSE_FILTER_STOP
	hud.add_child(minimap)
	var height_panel=PanelContainer.new()
	height_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	height_panel.position=Vector2(-234,330)
	height_panel.size=Vector2(210,108)
	height_panel.add_theme_stylebox_override("panel",style(Color(.035,.12,.16,.94),14))
	hud.add_child(height_panel)
	var height_col=VBoxContainer.new()
	height_panel.add_child(height_col)
	height_label=label("Vlieghoogte · Laag",15,GOLD)
	height_col.add_child(height_label)
	var height_row=HBoxContainer.new()
	height_col.add_child(height_row)
	lower_button=button("Lager −",func(): change_height(-1))
	higher_button=button("Hoger +",func(): change_height(1))
	for control in [lower_button,higher_button]:
		control.custom_minimum_size=Vector2(82,42)
		control.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		control.add_theme_font_size_override("font_size",15)
		for visual in ["normal","hover","pressed"]:
			var compact=style(Color("28505a"),10)
			compact.content_margin_left=8
			compact.content_margin_right=8
			compact.content_margin_top=8
			compact.content_margin_bottom=8
			control.add_theme_stylebox_override(visual,compact)
		height_row.add_child(control)
	update_height_controls()
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
	var status_panel=PanelContainer.new()
	status_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	status_panel.position=Vector2(235,-86)
	status_panel.size=Vector2(485,64)
	status_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	status_panel.add_theme_stylebox_override("panel",style(Color(.035,.12,.16,.9),14))
	hud.add_child(status_panel)
	status_label=label("",16,CREAM)
	status_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	status_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	status_panel.add_child(status_label)
	hud.hide()
	build_photo_dialog()

func show_credits() -> AcceptDialog:
	var dialog=AcceptDialog.new()
	dialog.title="TopoRotor · bronnen en licenties"
	dialog.dialog_text="Grensgegevens: Kadaster NL / PDOK, Bestuurlijke Gebieden 2026.\nCC BY 4.0: https://creativecommons.org/licenses/by/4.0/\nBron: https://api.pdok.nl/kadaster/brk-bestuurlijke-gebieden/ogc/v1\nGebundeld op 7 november 2026; uitgesneden en vereenvoudigd.\n\nLand-, water- en stadscontouren: Natural Earth, public domain.\nDe buurten en gebouwen zijn gestileerde modellen, geen echte stratenkaart.\nEigen code en modellen: MIT. Godot: MIT. DejaVu: fontlicentie.\nZie THIRD-PARTY.md voor bronverwijzingen en overige licenties."
	ui.add_child(dialog)
	dialog.get_label().autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	dialog.get_label().custom_minimum_size.x=600
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(660,360))
	return dialog

func load_world(new_region: String) -> void:
	region=new_region
	if is_instance_valid(world):
		remove_child(world)
		world.queue_free()
	world=TopoWorld.new()
	add_child(world)
	world.build(region,catalog)
	minimap.world=world
	helicopter.position=world.project(SPAWN.x,SPAWN.y)+Vector3(0,flight_altitude(),0)
	position_menu_camera()
	world.set_hints(false)
	update_best_label()

func update_best_label() -> void:
	var practice=clampi(int(saved.best.get(region+"_oefenen",0)),0,3)
	var test=clampi(int(saved.best.get(region+"_test",0)),0,3)
	if practice==0 and test==0:
		best_label.text="Klaar voor vertrek, piloot?"
		return
	best_label.text="Beste: oefenen %s · test %s" % ["★".repeat(practice)+"☆".repeat(3-practice),"★".repeat(test)+"☆".repeat(3-test)]

func start_mission(custom: Array = [],as_custom: bool = true) -> void:
	if is_instance_valid(summary):
		summary.queue_free()
	custom_mission=as_custom and not custom.is_empty()
	mission=custom.duplicate() if not custom.is_empty() else catalog.presets(region)
	mission.shuffle()
	world.ensure_mission_markers(mission)
	mission_index=0
	completed=[]
	mistakes=0
	flight_time=0
	timed=clock_select.selected==1
	time_limit=90.0*mission.size()
	timed_out=false
	exam=mode_select.selected==1
	show_hints=not exam
	hint_button.text="Hints verbergen" if show_hints else "Hint / kaartnamen"
	hints_used=false
	show_overview=false
	camera_level=0
	update_height_controls()
	state="flight"
	menu.hide()
	hud.show()
	velocity=Vector2.ZERO
	joystick.reset()
	helicopter.position=world.project(SPAWN.x,SPAWN.y)+Vector3(0,flight_altitude(),0)
	if not saved.mute:
		rotor_audio.play()
	camera.size=flight_zoom()
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
	if timed and flight_time>=time_limit:
		flight_time=time_limit
		timed_out=true
		finish_mission()
		return
	answer_cooldown=max(0,answer_cooldown-delta)
	keyboard=Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	var direction=(keyboard+joystick.value).limit_length()
	var speed=10.0 if region=="nl" else 42.0
	# Exponential smoothing keeps steering consistent across frame rates.
	var response=9.0 if direction.is_zero_approx() else 6.0
	velocity=velocity.lerp(direction*speed,1.0-exp(-response*delta))
	helicopter.position.x=clamp(helicopter.position.x+velocity.x*delta,world.bounds.position.x+1,world.bounds.end.x-1)
	helicopter.position.z=clamp(helicopter.position.z+velocity.y*delta,world.bounds.position.y+1,world.bounds.end.y-1)
	if velocity.length()>1:
		helicopter.rotation.y=lerp_angle(helicopter.rotation.y,atan2(-velocity.x,-velocity.y),1.0-exp(-8.0*delta))
	helicopter.lean(direction,delta)
	helicopter.position.y=lerp(helicopter.position.y,flight_altitude(),min(delta*2.5,1.0))
	var cam_goal=helicopter.position+(Vector3(0,38,44) if region=="nl" else Vector3(0,95,72))
	if show_overview:
		cam_goal=Vector3(world.bounds.get_center().x,600,world.bounds.get_center().y+400)
	camera.position=camera.position.lerp(cam_goal,min(delta*3,1.0))
	camera.look_at(Vector3(world.bounds.get_center().x,0,world.bounds.get_center().y) if show_overview else helicopter.position,Vector3.UP)
	camera.size=lerp(camera.size,(max(world.bounds.size.x,world.bounds.size.y)*1.03 if show_overview else flight_zoom()),min(delta*3,1.0))
	minimap.aircraft=helicopter.position
	minimap.refresh_navigation()
	world.refresh_labels(helicopter.position,show_overview,camera.size)
	world.set_boundary_detail(camera.size)
	if mission_index<mission.size():
		var p: Dictionary=mission[mission_index]
		var km=distance_km(p)
		var nav="Afstand: %d km" % km if show_hints else "Gebruik de kustlijnen, rivieren en grenzen."
		var clock_seconds=int(ceil(max(0.0,time_limit-flight_time))) if timed else int(flight_time)
		detail_label.text="%s  ·  %s %02d:%02d  ·  %d gevonden" % [nav,"Nog" if timed else "Vliegtijd",clock_seconds/60,clock_seconds%60,completed.size()]

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_ESCAPE:
			go_back(false)
		elif state=="flight" and not photo_open:
			if event.physical_keycode==KEY_SPACE:
				answer()
			elif event.physical_keycode==KEY_H:
				toggle_hint()
			elif event.physical_keycode==KEY_M:
				toggle_overview()
			elif event.physical_keycode in [KEY_Q,KEY_EQUAL,KEY_KP_ADD]:
				change_height(-1)
			elif event.physical_keycode in [KEY_E,KEY_MINUS,KEY_KP_SUBTRACT]:
				change_height(1)

func go_back(allow_quit: bool) -> void:
	if photo_open:
		close_photo_dialog()
	elif state=="flight" or state=="paused" or state=="summary":
		return_menu()
	elif allow_quit:
		get_tree().quit()

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
	# Countries without usable map geometry fall back to the catalog reference point.
	var hit=(world.country_contains(p.code,helicopter.position) if world.has_country(p.code) else distance_km(p)<25) if p.kind=="land" else distance_km(p)<(6 if region=="nl" else 25)
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

func flight_altitude() -> float:
	return FLIGHT_ALTITUDES[camera_level] if region=="nl" else FLIGHT_ALTITUDES[camera_level]*.6

func flight_zoom() -> float:
	return FLIGHT_ZOOMS[camera_level] if region=="nl" else FLIGHT_ZOOMS[camera_level]*2.5

func update_height_controls() -> void:
	if not is_instance_valid(height_label):
		return
	height_label.text="Vlieghoogte · "+HEIGHT_NAMES[camera_level]
	lower_button.disabled=camera_level==0
	higher_button.disabled=camera_level==FLIGHT_ZOOMS.size()-1

func change_height(direction: int) -> void:
	if state!="flight" or photo_open:
		return
	camera_level=clampi(camera_level+direction,0,FLIGHT_ZOOMS.size()-1)
	show_overview=false
	update_height_controls()

func _unhandled_input(event: InputEvent) -> void:
	if state=="flight" and not photo_open and event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP:
			change_height(-1)
		elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN:
			change_height(1)

func toggle_overview() -> void:
	show_overview=not show_overview
	joystick.reset()

func finish_mission() -> void:
	state="summary"
	hud.hide()
	world.target.hide()
	rotor_audio.stop()
	var stars=3 if mistakes==0 and exam and not hints_used else 2 if mistakes<=2 else 1
	if not custom_mission and not timed_out:
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
	col.add_child(label("TIJD IS OM" if timed_out else "MISSIE VOLTOOID",16,Color("a8c8bf")))
	col.add_child(label("Probeer het nog eens, piloot!" if timed_out else "Goed gevlogen, piloot!",32,GOLD))
	col.add_child(label("%d / %d gevonden" % [completed.size(),mission.size()] if timed_out else "★".repeat(stars)+"☆".repeat(3-stars),52,GOLD))
	col.add_child(label("%d locaties gevonden · %d pogingen mis\nVliegtijd %02d:%02d" % [completed.size(),mistakes,int(flight_time)/60,int(flight_time)%60],21))
	var tip=label("Drie sterren: een foutloze testvlucht zonder hints.",16,Color("b5cec4"))
	tip.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	col.add_child(tip)
	col.add_child(button("Dezelfde locaties opnieuw",func(): start_mission(mission,custom_mission),true))
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
	update_best_label()

func position_menu_camera() -> void:
	var center=world.bounds.get_center()
	var shift=95.0 if region=="nl" else 190.0
	var view_target=Vector3(center.x-shift,0,center.y)
	camera.size=330 if region=="nl" else 650
	camera.position=view_target+Vector3(0,600,450)
	camera.look_at(view_target,Vector3.UP)
	world.set_boundary_detail(camera.size)

func toggle_sound() -> void:
	saved.mute=not saved.mute
	mute_button.text="Geluid: uit" if saved.mute else "Geluid: aan"
	save_data()

func load_save() -> void:
	if FileAccess.file_exists(save_path):
		var raw: Variant=JSON.parse_string(FileAccess.get_file_as_string(save_path))
		progress_readonly=ProgressStore.is_newer(raw)
		if progress_readonly:
			push_warning("Voortgang komt uit een nieuwere app-versie; het bestand wordt niet overschreven.")
		saved=ProgressStore.clean(raw)
	custom_places=saved.custom

func save_data() -> void:
	if is_capture_mode or progress_readonly:
		return
	saved.version=ProgressStore.VERSION
	var f=FileAccess.open(save_path+".tmp",FileAccess.WRITE)
	if f==null:
		push_warning("Kon de voortgang niet opslaan.")
		return
	f.store_string(JSON.stringify(saved,"\t"))
	f.close()
	if DirAccess.rename_absolute(save_path+".tmp",save_path)!=OK:
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
	import_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	import_status.max_lines_visible=2
	import_status.mouse_filter=Control.MOUSE_FILTER_PASS
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
	var close=button("Terug",close_photo_dialog)
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
	# Must exceed the server worst case (upload 20 s + decode + Tesseract 30 s in ocr-service/app.py).
	http.timeout=60
	http.max_redirects=0
	http.body_size_limit=1024*1024
	http.request_completed.connect(ocr_response)
	add_child(http)

func close_photo_dialog() -> void:
	http.cancel_request()
	ocr_in_flight=false
	photo_dialog.hide()
	photo_backdrop.hide()
	photo_open=false

func open_photo_dialog() -> void:
	photo_open=true
	if mission_text.text.is_empty() and not custom_places.is_empty():
		var names=PackedStringArray()
		for p in custom_places:
			if p.kind!="eigen punt" and catalog.lookup.has(catalog.normalize(p.name)):
				names.append(p.name)
			else:
				names.append("%s | %s | %s" % [p.name,p.lat,p.lon])
		mission_text.text="\n".join(names)
	if not is_test_mode and not is_capture_mode and FileAccess.file_exists("user://worksheet.png"):
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
	# The PNG re-encode below drops EXIF, so apply the phone's Orientation tag here.
	apply_exif_orientation(img,exif_orientation(bytes))
	if max(img.get_width(),img.get_height())>1800:
		var factor=1800.0/max(img.get_width(),img.get_height())
		img.resize(max(1,int(img.get_width()*factor)),max(1,int(img.get_height()*factor)),Image.INTERPOLATE_LANCZOS)
	http.cancel_request()
	ocr_in_flight=false
	photo_image=img
	photo_bytes=img.save_png_to_buffer()
	if not is_test_mode and not is_capture_mode and img.save_png("user://worksheet.png")!=OK:
		push_warning("De foto is geladen, maar kon niet lokaal worden bewaard.")
	photo_preview.texture=ImageTexture.create_from_image(img)
	photo_dialog.size=Vector2(1140,640)
	call_deferred("fit_photo_panel")
	import_status.text="Foto toegevoegd. Typ de namen over of gebruik tekstherkenning."

func exif_orientation(bytes: PackedByteArray) -> int:
	if bytes.size()<4 or bytes[0]!=0xFF or bytes[1]!=0xD8:
		return 1
	var i=2
	while i+4<=bytes.size():
		if bytes[i]!=0xFF:
			return 1
		var marker=bytes[i+1]
		if marker==0xFF:
			i+=1
			continue
		if marker==0xD9 or marker==0xDA:
			return 1
		var length=(bytes[i+2]<<8)|bytes[i+3]
		if length<2 or i+2+length>bytes.size():
			return 1
		if marker==0xE1 and length>=16 and bytes.slice(i+4,i+10)==PackedByteArray([69,120,105,102,0,0]):
			return tiff_orientation(bytes.slice(i+10,i+2+length))
		i+=2+length
	return 1

func tiff_orientation(tiff: PackedByteArray) -> int:
	if tiff.size()<8:
		return 1
	var le=tiff[0]==0x49 and tiff[1]==0x49
	if not le and not (tiff[0]==0x4D and tiff[1]==0x4D):
		return 1
	var ifd=exif_uint(tiff,4,4,le)
	if ifd<8 or ifd+2>tiff.size():
		return 1
	var count=exif_uint(tiff,ifd,2,le)
	for k in range(count):
		var entry=ifd+2+12*k
		if entry+12>tiff.size():
			return 1
		if exif_uint(tiff,entry,2,le)==0x0112:
			var value=exif_uint(tiff,entry+8,2,le)
			return value if value>=1 and value<=8 else 1
	return 1

func exif_uint(data: PackedByteArray,offset: int,width: int,le: bool) -> int:
	var v=0
	for b in range(width):
		v|=data[offset+(b if le else width-1-b)]<<(8*b)
	return v

func apply_exif_orientation(img: Image,orientation: int) -> void:
	match orientation:
		2:
			img.flip_x()
		3:
			img.rotate_180()
		4:
			img.flip_y()
		5:
			img.rotate_90(CLOCKWISE)
			img.flip_x()
		6:
			img.rotate_90(CLOCKWISE)
		7:
			img.rotate_90(CLOCKWISE)
			img.flip_y()
		8:
			img.rotate_90(COUNTERCLOCKWISE)

func parse_custom() -> Dictionary:
	var ordinary: Array = []
	var manual: Array = []
	var errors: Array = []
	for raw in mission_text.text.replace(";","\n").split("\n"):
		if raw.contains("|"):
			var parts=raw.split("|")
			if parts.size()==3:
				# Accept a Dutch decimal comma (52,123) in the coordinate fields.
				parts[1]=parts[1].strip_edges().replace(",",".")
				parts[2]=parts[2].strip_edges().replace(",",".")
			if parts.size()!=3 or not parts[1].is_valid_float() or not parts[2].is_valid_float() or parts[0].strip_edges().is_empty() or parts[0].strip_edges().length()>120:
				errors.append(raw.strip_edges()+" (gebruik: naam | 52.12 | 5.45)")
				continue
			var lat=float(parts[1])
			var lon=float(parts[2])
			if not is_finite(lat) or not is_finite(lon) or lon < -25 or lon > 45 or lat < 34 or lat > 72:
				errors.append(raw+" (buiten de Europakaart)")
				continue
			manual.append({"name":parts[0].strip_edges(),"lat":lat,"lon":lon,"region":"nl" if TopoWorld.in_bounds(nl_bounds,lat,lon) else "eu","kind":"eigen punt","code":""})
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
		elif catalog.lookup.has(name):
			result.unknown.append(place.name+" (naam bestaat al in de kaart; kies een andere naam)")
		else:
			names[name]=true
			result.found.append(place)
	result.unknown.append_array(errors)
	if result.found.size()>200:
		result.unknown.insert(0,"Gebruik maximaal 200 locaties per missie")
	return result

func validate_custom() -> void:
	var result=parse_custom()
	if not result.unknown.is_empty():
		var shown=PackedStringArray()
		for entry in result.unknown.slice(0,3):
			var s=str(entry).strip_edges()
			shown.append(s if s.length()<=40 else s.left(39)+"…")
		var more=result.unknown.size()-shown.size()
		import_status.text="Controleer %d regel%s: " % [result.unknown.size(),"" if result.unknown.size()==1 else "s"]+", ".join(shown)+(" (+%d meer)" % more if more>0 else "")
		import_status.tooltip_text="\n".join(PackedStringArray(result.unknown))
	else:
		import_status.text="%d locaties herkend. Klaar om te vliegen." % result.found.size()
		import_status.tooltip_text=""
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
	if Time.get_ticks_msec()<ocr_retry_after_msec:
		import_status.text="De OCR-service is bezet. Probeer het over %d seconden opnieuw." % ceili((ocr_retry_after_msec-Time.get_ticks_msec())/1000.0)
		return
	import_status.text="Foto wordt naar jouw OCR-service verstuurd…"
	ocr_in_flight=true
	ocr_input_snapshot=mission_text.text
	var error=http.request_raw(url,PackedStringArray(["Content-Type: image/png","Authorization: Bearer "+ocr_token.text]),HTTPClient.METHOD_POST,photo_bytes)
	if error!=OK:
		ocr_in_flight=false
		import_status.text="Kan de OCR-service niet bereiken. Je kunt de namen zelf typen."
	elif saved.endpoint!=url:
		# Persist the (non-secret) endpoint so OCR-only sessions keep it; the token stays in memory.
		saved.endpoint=url
		save_data()

func ocr_error_message(result: int,code: int,headers: PackedStringArray) -> String:
	match result:
		HTTPRequest.RESULT_TIMEOUT:
			return "De herkenning duurde te lang. Probeer het opnieuw of typ de namen."
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "Beveiligde verbinding mislukt (certificaat). Controleer de HTTPS-instelling van je service."
		HTTPRequest.RESULT_CANT_RESOLVE, HTTPRequest.RESULT_CANT_CONNECT, HTTPRequest.RESULT_CONNECTION_ERROR, HTTPRequest.RESULT_NO_RESPONSE:
			return "De OCR-service is niet bereikbaar. Controleer het adres en je internet, of typ de namen."
		HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED:
			return "De OCR-service stuurt door naar een ander adres. Gebruik het exacte HTTPS-adres."
		HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED:
			return "Onverwacht antwoord van de OCR-service."
	if result!=HTTPRequest.RESULT_SUCCESS:
		return "Verbinding met de OCR-service mislukt. Controleer het adres of typ de namen."
	match code:
		401, 403:
			return "Het OCR-toegangstoken klopt niet. Controleer het token."
		413:
			return "De foto is te groot voor de OCR-service. Kies een kleinere foto."
		429:
			var wait=5
			for h in headers:
				if h.to_lower().begins_with("retry-after:"):
					var v=h.substr(12).strip_edges()
					if v.is_valid_int():
						wait=clampi(int(v),1,300)
			ocr_retry_after_msec=Time.get_ticks_msec()+wait*1000
			return "De OCR-service is bezet. Probeer het over %d seconden opnieuw." % wait
		503:
			return "De OCR-service is niet ingesteld. Zie README."
		504:
			return "De herkenning duurde te lang. Probeer het opnieuw of typ de namen."
	return "Tekstherkenning niet gelukt (%d). Controleer het adres of typ de namen." % code

func ocr_response(result: int,code: int,headers: PackedStringArray,body: PackedByteArray) -> void:
	ocr_in_flight=false
	if not photo_open:
		return
	if result!=HTTPRequest.RESULT_SUCCESS or code!=200:
		import_status.text=ocr_error_message(result,code,headers)
		return
	if mission_text.text!=ocr_input_snapshot:
		import_status.text="Herkenning klaar; je aangepaste lijst blijft bewaard. Herhaal indien gewenst."
		return
	var data=JSON.parse_string(body.get_string_from_utf8())
	if not data is Dictionary or not data.get("candidates") is Array or data.candidates.size()>200:
		import_status.text="Onverwacht antwoord van de OCR-service."
		return
	if data.get("api_version") is float and int(data.api_version)!=1:
		import_status.text="De OCR-service gebruikt een andere API-versie (%d). Werk app of service bij." % int(data.api_version)
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
	# Merge: keep existing lines (incl. custom coordinate points) and only append new names.
	var existing: Dictionary={}
	for raw in mission_text.text.replace(";","\n").split("\n"):
		if raw.contains("|"):
			existing[catalog.normalize(raw.split("|")[0].strip_edges())]=true
		else:
			for part in raw.split(","):
				existing[catalog.normalize(part.strip_edges())]=true
	var added=PackedStringArray()
	for name in names:
		var key=catalog.normalize(name)
		if not existing.has(key):
			existing[key]=true
			added.append(name)
	if added.is_empty():
		validate_custom()
		import_status.text="Herkenning klaar; geen nieuwe locaties gevonden. Je lijst blijft ongewijzigd."
		return
	var note=""
	if data.get("catalog_version") is String and data.catalog_version!=FileAccess.get_sha256("res://data/places.json").left(16):
		for name in added:
			if not catalog.lookup.has(catalog.normalize(name)):
				note=" De OCR-service gebruikt een andere plaatsenlijst dan deze app; werk app en service bij naar dezelfde versie."
				break
	var current=mission_text.text.strip_edges(false,true)
	mission_text.text=(current+"\n" if not current.is_empty() else "")+"\n".join(added)
	validate_custom()
	import_status.text+=" Controleer of er namen missen of onterecht zijn toegevoegd."+note

func _notification(what: int) -> void:
	if is_test_mode or is_capture_mode:
		return
	if what==NOTIFICATION_WM_GO_BACK_REQUEST:
		go_back(true)
	elif what==NOTIFICATION_APPLICATION_FOCUS_OUT and not is_test_mode and not is_capture_mode:
		if is_instance_valid(joystick):
			joystick.reset()
		velocity=Vector2.ZERO
		if state=="flight":
			state="paused"
			rotor_audio.stop()
			status_label.text="Vlucht gepauzeerd."
	elif what==NOTIFICATION_APPLICATION_FOCUS_IN:
		if state=="paused":
			state="flight"
			if not saved.mute:
				rotor_audio.play()
			status_label.text="Welkom terug, piloot! Je vlucht gaat verder."

func smoke_test() -> void:
	assert(world.province_regions.size()==12,"All Dutch provinces are bundled")
	assert(world.boundary_data.municipality_count==342,"Official municipality layer is complete")
	for level in ["national","provincial","municipal"]:
		assert(not world.boundary_paths[level].is_empty(),"Boundary level has usable geometry: "+level)
	var layouts: Dictionary={}
	for place in catalog.places:
		if place.kind=="stad" and place.region=="nl":
			assert(world.dutch_scenery.city_stats.has(place.name),"Every Dutch city receives a city plan")
			var stats: Dictionary=world.dutch_scenery.city_stats[place.name]
			assert(stats.plots>0,"City plan is not empty: "+place.name)
			layouts[stats.layout]=true
	assert(layouts.size()==50,"Dutch cities do not repeat the same layout")
	minimap.toggle_detail()
	assert(minimap.local_view,"Minimap can show local municipality boundaries")
	minimap.toggle_detail()
	assert(not minimap.local_view,"Minimap can return to the country overview")
	assert(world.dutch_scenery.landmarks.has("Amsterdam") and world.dutch_scenery.landmarks.has("Rotterdam") and world.dutch_scenery.landmarks.has("Utrecht"),"Dutch landmarks built at catalog anchors")
	world.set_hints(true)
	world.refresh_labels(helicopter.position,false)
	var visible_names=0
	for marker in world.labels:
		if marker.visible:
			visible_names+=1
	assert(visible_names>0 and visible_names<world.labels.size(),"Nearby names remain readable without showing the whole catalog")
	world.set_hints(false)
	world.refresh_labels(helicopter.position,false)
	for marker in world.labels:
		assert(not marker.visible,"Test mode cannot leak place names")
	var progress_existed=FileAccess.file_exists("user://progress.json")
	var progress_before=FileAccess.get_file_as_bytes("user://progress.json") if progress_existed else PackedByteArray()
	for leftover in [save_path,save_path+".tmp"]:
		if FileAccess.file_exists(leftover):
			DirAccess.remove_absolute(leftover)
	saved.mute=true # Headless tests have no audio output device.
	var parsed=catalog.parse_list("1. Arnhem\nDen Haag, Parijs\nOnbekenddorp")
	assert(parsed.found.size()==3,"Catalog parser: number prefixes and comma lists")
	assert(parsed.unknown==["Onbekenddorp"],"Unknown names must not disappear")
	var p=world.project(5.8987,51.9851)
	var geo=world.unproject(p)
	assert(abs(geo.x-5.8987)<.001 and abs(geo.y-51.9851)<.001,"Coordinate round trip")
	assert(world.country_contains("NLD",world.project(5.1214,52.0907)),"Utrecht in Netherlands")
	assert(not world.country_contains("NLD",world.project(3.4,53.0)),"North Sea not Netherlands")
	assert(not world.lake_contains(world.project(5.2647,52.3508)),"Almere is on Flevoland, not in the lake")
	assert(not world.lake_contains(world.project(5.4714,52.5185)),"Lelystad remains on land")
	assert(world.lake_contains(world.project(5.33,52.8)),"IJsselmeer remains water")
	assert(world.lake_contains(world.project(5.18,52.55)),"Markermeer remains water")
	start_mission([catalog.lookup.arnhem])
	var flight_start=helicopter.position
	var close_zoom=flight_zoom()
	var low_altitude=flight_altitude()
	change_height(1)
	change_height(1)
	assert(flight_zoom()>close_zoom and flight_altitude()>low_altitude,"Higher flight provides a wider view")
	assert(helicopter.position==flight_start and mission_index==0 and state=="flight","Height changes do not teleport or restart the mission")
	toggle_overview()
	change_height(-1)
	assert(not show_overview and camera_level==1,"Height control exits the overview into the chosen flight view")
	change_height(-1)
	assert(flight_zoom()==close_zoom,"Pilot can return to low search flight")
	helicopter.position=world.project(5.8987,51.9851)+Vector3(0,9.0 if region=="nl" else 3.3,0)
	assert(distance_km(mission[0])<.01,"Distance at target")
	answer()
	assert(state=="summary" and completed.size()==1,"Mission completes on correct answer")
	return_menu()
	load_world("eu")
	for place in catalog.places:
		if place.kind=="land":
			assert(world.has_country(place.code),"Country %s has map polygons" % place.code)
	assert(world.country_contains("FRA",world.project(2.3522,48.8566)),"Paris in France")
	assert(not world.country_contains("FRA",world.project(13.405,52.52)),"Berlin not France")
	assert(world.country_contains("UKR",world.project(34.1,44.95)) and not world.country_contains("RUS",world.project(34.1,44.95)),"Crimea counts as Ukraine")
	assert(world.country_contains("CYP",world.project(33.9,35.3)),"Northern Cyprus counts as Cyprus")
	assert(world.country_contains("FIN",world.project(19.95,60.2)),"Aland counts as Finland")
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
	var exif_segment=PackedByteArray([0xFF,0xE1,0,34,69,120,105,102,0,0,0x4D,0x4D,0,0x2A,0,0,0,8,0,1,0x01,0x12,0,3,0,0,0,1,0,6,0,0,0,0,0,0])
	var rotated_jpeg=jpeg.slice(0,2)+exif_segment+jpeg.slice(2)
	assert(exif_orientation(rotated_jpeg)==6 and exif_orientation(png)==1,"EXIF orientation parsed")
	var oriented=Image.new()
	assert(oriented.load_jpg_from_buffer(rotated_jpeg)==OK,"EXIF JPEG decodes")
	apply_exif_orientation(oriented,exif_orientation(rotated_jpeg))
	assert(oriented.get_width()==8 and oriented.get_height()==12,"Orientation-6 photo is rotated upright")
	assert(not WorksheetImage.allowed_size(Vector2i(5000,5000)),"Oversized pixel buffers rejected")
	assert(WorksheetImage.dimensions(png.slice(0,12))==Vector2i.ZERO,"Truncated image rejected")
	saved.best["nl_oefenen"]=2
	var old_best=JSON.stringify(saved.best)
	var old_custom=saved.custom.size()
	save_data()
	save_data()
	assert(FileAccess.file_exists(save_path) and not FileAccess.file_exists(save_path+".tmp"),"Second save replaces the existing progress file")
	load_save()
	assert(JSON.stringify(saved.best)==old_best and saved.mute==true and saved.custom.size()==old_custom,"Saved progress round-trips through load_save")
	DirAccess.remove_absolute(save_path)
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
	clock_select.select(1)
	start_mission([catalog.lookup.amsterdam])
	var scores_before_timeout=JSON.stringify(saved.best)
	flight_time=time_limit-.01
	_process(.02)
	assert(state=="summary" and timed_out and completed.is_empty(),"Expired time trial ends without awarding completion")
	assert(JSON.stringify(saved.best)==scores_before_timeout,"Timeout does not award stars")
	clock_select.select(0)
	start_mission([catalog.lookup.amsterdam])
	_process(100.0)
	assert(state=="flight" and not timed_out,"Untimed flight has no deadline")
	return_menu()
	open_online_content()
	assert(apply_online_content(FileAccess.get_file_as_string("res://content/missions.json")),"Online lesson example validates")
	var pack_count=online_packs.size()
	assert(not apply_online_content('{"version":1,"missions":[{"title":"Bad","places":["Unknown place"]}]}'),"Unknown online places rejected")
	assert(online_packs.size()==pack_count,"Invalid download preserves previous lessons")
	start_online_mission()
	assert(state=="flight" and custom_mission and mission.size()==4,"Downloaded lesson starts as a custom mission")
	content_dialog.hide()
	return_menu()
	feedback_audio.stop()
	print("SMOKE TEST PASSED: parsing, coordinates, land boundaries, flight scoring, custom missions")
	await get_tree().process_frame
	get_tree().quit()

func capture_preview() -> void:
	saved.mute=true
	seed(1206)
	DirAccess.make_dir_recursive_absolute("res://build")
	start_mission([catalog.lookup.amsterdam,catalog.lookup.rotterdam])
	helicopter.position=world.project(5.0,52.23)+Vector3(0,9.0 if region=="nl" else 3.3,0)
	camera.position=helicopter.position+Vector3(0,38,44)
	camera.look_at(helicopter.position)
	await get_tree().create_timer(2).timeout
	var background_count=minimap.background_draws
	await get_tree().create_timer(.2).timeout
	assert(minimap.background_draws==background_count,"Moving navigation does not redraw country geometry")
	assert(state=="flight","Flight screenshot must show actual gameplay")
	var image=get_viewport().get_texture().get_image()
	image.save_png("res://build/preview-flight.png")
	image=null
	change_height(1)
	await get_tree().create_timer(1).timeout
	get_viewport().get_texture().get_image().save_png("res://build/preview-flight-middle.png")
	change_height(1)
	await get_tree().create_timer(1).timeout
	get_viewport().get_texture().get_image().save_png("res://build/preview-flight-high.png")
	minimap.toggle_detail()
	await get_tree().create_timer(.3).timeout
	get_viewport().get_texture().get_image().save_png("res://build/preview-boundaries-local.png")
	minimap.toggle_detail()
	return_menu()
	await get_tree().create_timer(.5).timeout
	get_viewport().get_texture().get_image().save_png("res://build/preview-hangar.png")
	var credits=show_credits()
	await get_tree().create_timer(.2).timeout
	get_viewport().get_texture().get_image().save_png("res://build/preview-credits.png")
	credits.hide()
	credits.queue_free()
	await get_tree().process_frame
	open_photo_dialog()
	import_photo("res://examples/demo-werkblad.png")
	mission_text.text="Amsterdam\nRotterdam\nDen Haag\nUtrecht\nArnhem"
	validate_custom()
	await get_tree().create_timer(.5).timeout
	assert(photo_dialog.size.y<=641,"Photo panel fits landscape screen")
	assert(not launch_button.disabled,"Valid photo mission can be launched")
	get_viewport().get_texture().get_image().save_png("res://build/preview-photo.png")
	photo_open=false
	photo_dialog.hide()
	photo_backdrop.hide()
	for city in ["amsterdam","utrecht","rotterdam","den haag","groningen","arnhem","nijmegen","almere","maastricht","zwolle","sneek"]:
		var place: Dictionary=catalog.lookup[city]
		start_mission([place])
		state="preview" # Freeze flight while photographing a detail view.
		var center=world.project(place.lon,place.lat)
		helicopter.position=center+Vector3(7,9,8)
		camera.size=29
		camera.position=center+Vector3(0,34,38)
		camera.look_at(center)
		detail_label.text="Nederland · herkenningspunten van dichtbij"
		world.refresh_labels(center,false,camera.size)
		world.set_boundary_detail(camera.size)
		minimap.aircraft=helicopter.position
		minimap.refresh_navigation()
		await get_tree().create_timer(.4).timeout
		get_viewport().get_texture().get_image().save_png("res://build/preview-"+city.replace(" ","-")+".png")
	# Shared camera/UI/helicopter changes also get a visual check in Europe.
	load_world("eu")
	start_mission([catalog.lookup.parijs])
	helicopter.position=world.project(2.35,48.85)+Vector3(0,3.3,0)
	await get_tree().create_timer(2).timeout
	get_viewport().get_texture().get_image().save_png("res://build/preview-europe.png")
	rotor_audio.stop()
	feedback_audio.stop()
	await get_tree().process_frame
	print("VISUAL CHECK PASSED")
	get_tree().quit()

# Lesson packs contain catalog names, never executable resources.
func open_online_content() -> void:
	if not is_instance_valid(content_dialog):
		content_dialog=AcceptDialog.new()
		content_dialog.title="Online missiepakketten"
		content_dialog.min_size=Vector2i(650,430)
		content_dialog.ok_button_text="Sluiten"
		ui.add_child(content_dialog)
		var col=VBoxContainer.new()
		content_dialog.add_child(col)
		col.add_child(label("Plak de HTTPS-link naar je missiepakketten:",18))
		content_url=LineEdit.new()
		content_url.placeholder_text="https://…/missions.json"
		col.add_child(content_url)
		col.add_child(button("Missies ophalen",download_content))
		content_status=label("Eerder geladen missies werken ook zonder internet.",16)
		content_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		col.add_child(content_status)
		content_list=ItemList.new()
		content_list.custom_minimum_size=Vector2(600,170)
		col.add_child(content_list)
		col.add_child(button("Start geselecteerde missie",start_online_mission,true))
		content_http=HTTPRequest.new()
		content_http.timeout=20
		content_http.body_size_limit=262144
		content_http.max_redirects=0
		add_child(content_http)
		content_http.request_completed.connect(online_content_received)
		if FileAccess.file_exists("user://missions.json"):
			apply_online_content(FileAccess.get_file_as_string("user://missions.json"))
	content_dialog.popup_centered()

func download_content() -> void:
	var url=content_url.text.strip_edges()
	if not url.begins_with("https://"):
		content_status.text="Gebruik een HTTPS-link naar een JSON-bestand."
		return
	content_http.cancel_request()
	content_status.text="Missies worden geladen…"
	if content_http.request(url)!=OK:
		content_status.text="Download kon niet starten. Eerdere missies blijven beschikbaar."

func online_content_received(result: int,code: int,_headers: PackedStringArray,body: PackedByteArray) -> void:
	if result!=HTTPRequest.RESULT_SUCCESS or code!=200:
		content_status.text="Ophalen mislukt (%d). Eerdere missies blijven beschikbaar." % code
		return
	var text=body.get_string_from_utf8()
	if apply_online_content(text):
		var file=FileAccess.open("user://missions.json",FileAccess.WRITE)
		if file:
			file.store_string(text)
		else:
			content_status.text="Missies geladen; offline bewaren is niet gelukt."

func apply_online_content(text: String) -> bool:
	var raw: Variant=JSON.parse_string(text)
	if not raw is Dictionary or raw.get("version")!=1 or not raw.get("missions") is Array or raw.missions.is_empty() or raw.missions.size()>100:
		content_status.text="Ongeldig missiepakket. Verwacht versie 1 met maximaal 100 missies."
		return false
	var packs: Array=[]
	for pack in raw.missions:
		if not pack is Dictionary or not pack.get("title") is String or pack.title.strip_edges().is_empty() or pack.title.length()>100 or not pack.get("places") is Array or pack.places.is_empty() or pack.places.size()>100:
			content_status.text="Een missie heeft een ongeldige titel of locatielijst."
			return false
		var names=PackedStringArray()
		for place in pack.places:
			if not place is String or place.length()>120:
				content_status.text="Een locatie is ongeldig."
				return false
			names.append(place)
		var parsed=catalog.parse_list("\n".join(names))
		if not parsed.unknown.is_empty() or parsed.found.is_empty():
			content_status.text="Onbekende locaties in %s: %s" % [pack.title,", ".join(parsed.unknown)]
			return false
		packs.append({"title":pack.title,"places":parsed.found})
	online_packs=packs
	content_list.clear()
	for pack in packs:
		content_list.add_item("%s · %d locaties" % [pack.title,pack.places.size()])
	content_list.select(0)
	content_status.text="%d missies beschikbaar. Kies een missie en vertrek!" % packs.size()
	return true

func start_online_mission() -> void:
	var selected=content_list.get_selected_items()
	if selected.is_empty():
		return
	var places: Array=online_packs[selected[0]].places
	var target_region="nl"
	for place in places:
		if place.region!="nl":
			target_region="eu"
	region_select.select(0 if target_region=="nl" else 1)
	load_world(target_region)
	content_dialog.hide()
	start_mission(places)
