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
var locator: LocatorCard
var map_turn_button: Button
var menu_turn_button: Button
var mode_tiles: Array = []
var menu_shade: TextureRect
var menu_flight_time: float = 0.0
const MENU_HELI_SCALE = 8.5
const FLIGHT_HELI_SCALE = 1.25
var title_label: Label
var detail_label: Label
var progress_label: Label
var status_label: Label
var region_select: OptionButton
enum GameMode { LEARN, PRACTICE, RECORDS }
var game_mode: int = GameMode.LEARN
var record_result: String = ""
const MODE_NAMES = ["LEREN", "OEFENEN", "RECORDS"]
var content_http: HTTPRequest
var content_status: Label
var content_url: LineEdit
var content_list: ItemList
var content_dialog: AcceptDialog
var online_packs: Array = []
var europe_route_select: OptionButton
var nl_route_select: OptionButton
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
var is_capture_mode: bool = OS.is_debug_build() and (OS.get_cmdline_user_args().has("--capture") or OS.get_cmdline_user_args().has("--capture-fx") or OS.get_cmdline_user_args().has("--capture-learn"))
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
var goal_mistakes: int = 0
var pause_panel: PanelContainer
var pause_backdrop: ColorRect
var hints_used: bool = false
var state: String = "menu"
var region: String = "nl"
var exam: bool = false
var show_hints: bool = true
var flight_time: float = 0.0
var velocity: Vector2 = Vector2.ZERO
var saved: Dictionary = {"version":ProgressStore.VERSION,"best":{},"records":{},"custom":[],"endpoint":"","mute":false}
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
# Every level sits one step higher than in 0.4: the old Midden is now Laag,
# the old Hoog is Midden, and Hoog shows a wider area around the helicopter.
const FLIGHT_ZOOMS = [38.0,64.0,100.0]
const FLIGHT_ALTITUDES = [14.0,23.0,32.0]
# Effects (sight, beacon, fireworks) were sized for this zoom; they scale from it.
const FX_REFERENCE_ZOOM = 22.0
const HEIGHT_NAMES = ["Laag","Midden","Hoog"]
const TURN_RATE = 2.1 # rad/s at full stick
const REVERSE_FACTOR = .45
const CAMERA_FOLLOW = 7.0
const CAMERA_TURN = 4.5
const LOOK_AHEAD = .16
const AIM_HEIGHT = .3
var heading: float = 0.0
var camera_yaw: float = 0.0
var compass: FlightCompass
var paint_button: Button
var paint_panel: PanelContainer
var paint_backdrop: ColorRect
var paint_pickers: Dictionary = {}
var preview_heli: RotorHelicopter
var paint_open: bool = false
# Name, body, trim, dark. The first entry is the factory paint.
const PAINT_SCHEMES = [
	["Reddingsoranje","e67b34","dce4dc","263845"],
	["Traumageel","f4c51c","2a3035","1f2428"],
	["Politie","f1f3f5","1e4fa3","23344a"],
	["Marinegrijs","6f7b80","d9dfe0","2d3a40"],
	["Racerood","c62f2f","f2f2f2","1d1f22"],
	["Junglegroen","4f7a3a","d7c48b","2d3a2a"],
	["Nachtzwart","25292c","f0b93a","111315"],
	["Oceaanblauw","2f7fb8","f4efe0","1d3346"],
	["Flamingoroze","e57fa8","fff1f6","3b2b3a"],
]
const PAINT_PARTS = [["body","Romp"],["trim","Strepen"],["dark","Rotor en ski's"]]
var fx: FlightFx
var hud_fx: HudFx
var sfx: SfxBank
var found_button: Button
var shake: float = 0.0
var in_zone: bool = false
var best_label: Label
var custom_mission: bool = false
var progress_readonly: bool = false

var nl_bounds: Array = TopoWorld.map_bounds("nl")

const SPAWN = Vector2(5.1214,52.0907) # Utrecht (lon, lat)
const INK = Color("143740")
const CREAM = Color("f5efdc")
const GOLD = Color("ffc35c")
const TEAL = Color("28505a")
const MUTED = Color("9fc5bc")
const PANEL = Color(.035,.115,.15,.94)
const PANEL_SOLID = Color(.04,.13,.17,.98)
const EDGE = Color(.55,.8,.78,.18)
const PHOTO_SIZE = Vector2(1140,640)

func _ready() -> void:
	if not is_test_mode and not is_capture_mode:
		load_save()
	build_environment()
	helicopter.apply_paint(saved.get("paint",{}))
	build_ui()
	load_world("nl")
	state="menu"
	get_tree().quit_on_go_back=false
	if is_test_mode:
		call_deferred("smoke_test")
	if is_capture_mode:
		var args=OS.get_cmdline_user_args()
		call_deferred("capture_effects_only" if args.has("--capture-fx") else "capture_learning_only" if args.has("--capture-learn") else "capture_preview")

func build_environment() -> void:
	var env = WorldEnvironment.new()
	var e = Environment.new()
	e.background_mode=Environment.BG_COLOR
	e.background_color=Color("286375")
	e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color=Color("d6e8df")
	e.ambient_light_energy=.65
	e.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	# Soft bloom makes beacons, fireworks and lights glow; a touch more
	# saturation and contrast gives the miniature world more punch.
	e.glow_enabled=true
	e.glow_intensity=.7
	e.glow_strength=1.05
	e.glow_bloom=.04
	e.glow_hdr_threshold=.92
	e.glow_blend_mode=Environment.GLOW_BLEND_MODE_SCREEN
	e.adjustment_enabled=true
	e.adjustment_saturation=1.07
	e.adjustment_contrast=1.06
	e.adjustment_brightness=1.02
	env.environment=e
	add_child(env)
	var sun=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-52,-32,0)
	sun.light_color=Color("fff2d2")
	sun.light_energy=1.05
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
	sfx=SfxBank.new()
	add_child(sfx)
	fx=FlightFx.new()
	fx.sfx=sfx
	add_child(fx)

func style(color: Color,radius: int=18,border: Color=Color.TRANSPARENT,border_width: int=1) -> StyleBoxFlat:
	var s=StyleBoxFlat.new()
	s.bg_color=color
	s.set_corner_radius_all(radius)
	s.content_margin_left=20
	s.content_margin_right=20
	s.content_margin_top=14
	s.content_margin_bottom=14
	s.border_color=border
	if border.a>0:
		s.set_border_width_all(border_width)
	s.anti_aliasing=true
	return s

# Floating cards: dark glass with a soft drop shadow and an optional gold edge
# on the left that marks the most important panel on screen.
func card(color: Color=PANEL,radius: int=20,accent: bool=false) -> StyleBoxFlat:
	var s=style(color,radius,EDGE)
	s.shadow_color=Color(0,0,0,.38)
	s.shadow_size=14
	s.shadow_offset=Vector2(0,5)
	if accent:
		s.border_color=GOLD
		s.border_width_left=5
		s.border_width_top=0
		s.border_width_right=0
		s.border_width_bottom=0
	return s

# Raised button face: a darker bottom edge that flattens when pressed.
func face(color: Color,edge: Color,pressed: bool=false,radius: int=14,margin: int=16) -> StyleBoxFlat:
	var s=style(color,radius)
	s.content_margin_left=margin
	s.content_margin_right=margin
	s.content_margin_top=8+(3 if pressed else 0)
	s.content_margin_bottom=8+(0 if pressed else 3)
	s.border_color=edge
	s.border_width_bottom=0 if pressed else 4
	s.border_width_top=3 if pressed else 0
	return s

func focus_ring(radius: int=14) -> StyleBoxFlat:
	var s=style(Color.TRANSPARENT,radius,GOLD,2)
	s.draw_center=false
	s.expand_margin_left=3
	s.expand_margin_right=3
	s.expand_margin_top=3
	s.expand_margin_bottom=3
	return s

func label(text: String,size_px: int=20,color: Color=CREAM) -> Label:
	var l=Label.new()
	l.text=text
	l.add_theme_font_size_override("font_size",size_px)
	l.add_theme_color_override("font_color",color)
	return l

func kicker(text: String) -> Label:
	var l=label(text,13,MUTED)
	l.add_theme_constant_override("line_spacing",0)
	return l

func button(text: String,action: Callable,gold: bool=false) -> Button:
	var b=Button.new()
	b.text=text
	b.custom_minimum_size.y=52
	b.add_theme_font_size_override("font_size",20)
	style_button(b,gold)
	b.pressed.connect(action)
	# Only touch index 0 is emulated as mouse input; handle extra fingers (e.g. while steering) here.
	b.gui_input.connect(func(event: InputEvent):
		if event is InputEventScreenTouch and event.pressed and event.index>0 and not b.disabled:
			b.accept_event()
			action.call()
	)
	return b

func style_button(b: Control,gold: bool=false,radius: int=14,margin: int=16) -> void:
	var base=GOLD if gold else TEAL
	var edge=Color("c27f2b") if gold else Color("143a43")
	b.add_theme_stylebox_override("normal",face(base,edge,false,radius,margin))
	b.add_theme_stylebox_override("hover",face(Color("ffd47e") if gold else Color("357080"),edge,false,radius,margin))
	b.add_theme_stylebox_override("pressed",face(Color("e6a548") if gold else Color("1b4651"),edge,true,radius,margin))
	b.add_theme_stylebox_override("hover_pressed",face(Color("e6a548") if gold else Color("1b4651"),edge,true,radius,margin))
	b.add_theme_stylebox_override("disabled",face(Color(.12,.25,.29,.75),Color(.06,.15,.18,.75),false,radius,margin))
	b.add_theme_stylebox_override("focus",focus_ring(radius))
	for key in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_hover_pressed_color"]:
		b.add_theme_color_override(key,INK if gold else CREAM)
	b.add_theme_color_override("font_disabled_color",Color(CREAM,.4))

# One theme for every built-in control, so dropdowns, popups, text fields,
# lists, scrollbars and dialogs match the cards instead of Godot's grey default.
func build_theme() -> Theme:
	var theme=Theme.new()
	theme.default_font=load("res://assets/interface.ttf")
	theme.default_font_size=18
	theme.set_color("font_color","Label",CREAM)
	for type in ["Button","OptionButton"]:
		theme.set_stylebox("normal",type,face(TEAL,Color("143a43")))
		theme.set_stylebox("hover",type,face(Color("357080"),Color("143a43")))
		theme.set_stylebox("pressed",type,face(Color("1b4651"),Color("143a43"),true))
		theme.set_stylebox("hover_pressed",type,face(Color("1b4651"),Color("143a43"),true))
		theme.set_stylebox("disabled",type,face(Color(.12,.25,.29,.75),Color(.06,.15,.18,.75)))
		theme.set_stylebox("focus",type,focus_ring())
		for key in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_hover_pressed_color"]:
			theme.set_color(key,type,CREAM)
		theme.set_color("font_disabled_color",type,Color(CREAM,.4))
	theme.set_color("icon_normal_color","OptionButton",GOLD)
	theme.set_color("icon_hover_color","OptionButton",GOLD)
	theme.set_constant("arrow_margin","OptionButton",14)
	var popup=style(Color("0b232a"),14,EDGE)
	popup.content_margin_top=8
	popup.content_margin_bottom=8
	popup.content_margin_left=8
	popup.content_margin_right=8
	popup.shadow_color=Color(0,0,0,.45)
	popup.shadow_size=12
	theme.set_stylebox("panel","PopupMenu",popup)
	var popup_hover=style(Color("2f6874"),10)
	popup_hover.content_margin_left=10
	popup_hover.content_margin_right=10
	theme.set_stylebox("hover","PopupMenu",popup_hover)
	theme.set_color("font_color","PopupMenu",CREAM)
	theme.set_color("font_hover_color","PopupMenu",GOLD)
	theme.set_color("font_disabled_color","PopupMenu",Color(CREAM,.4))
	theme.set_constant("v_separation","PopupMenu",14)
	theme.set_constant("item_start_padding","PopupMenu",12)
	theme.set_constant("item_end_padding","PopupMenu",12)
	theme.set_font_size("font_size","PopupMenu",18)
	for type in ["LineEdit","TextEdit"]:
		var field=style(Color("0a2026"),10,Color("2a5660"))
		field.content_margin_left=12
		field.content_margin_right=12
		field.content_margin_top=8
		field.content_margin_bottom=8
		theme.set_stylebox("normal",type,field)
		var focused=field.duplicate()
		focused.border_color=GOLD
		theme.set_stylebox("focus",type,focused)
		theme.set_stylebox("read_only",type,field)
		theme.set_color("font_color",type,CREAM)
		theme.set_color("font_placeholder_color",type,Color("7f9f98"))
		theme.set_color("caret_color",type,GOLD)
		theme.set_color("selection_color",type,Color(1,.76,.36,.35))
	var list=style(Color("0a2026"),12,Color("2a5660"))
	list.content_margin_left=6
	list.content_margin_right=6
	list.content_margin_top=6
	list.content_margin_bottom=6
	theme.set_stylebox("panel","ItemList",list)
	theme.set_stylebox("focus","ItemList",StyleBoxEmpty.new())
	var picked=style(Color(1,.76,.36,.22),8,GOLD)
	theme.set_stylebox("selected","ItemList",picked)
	theme.set_stylebox("selected_focus","ItemList",picked)
	theme.set_stylebox("hovered","ItemList",style(Color(1,1,1,.06),8))
	theme.set_color("font_color","ItemList",CREAM)
	theme.set_color("font_selected_color","ItemList",GOLD)
	theme.set_color("font_hovered_color","ItemList",CREAM)
	theme.set_constant("v_separation","ItemList",10)
	# Slim, rounded scrollbars that only show up where content really overflows.
	for type in ["VScrollBar","HScrollBar"]:
		var track=style(Color(1,1,1,.05),4)
		for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]:
			track.set_content_margin(side,3)
		theme.set_stylebox("scroll",type,track)
		theme.set_stylebox("scroll_focus",type,track)
		for state_name in ["grabber","grabber_highlight","grabber_pressed"]:
			var grab=style(Color("4f8b92") if state_name=="grabber" else Color("6fb0b5") if state_name=="grabber_highlight" else GOLD,4)
			for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]:
				grab.set_content_margin(side,3)
			theme.set_stylebox(state_name,type,grab)
	var window=card(Color("0d2930"),18)
	window.expand_margin_top=36
	window.content_margin_top=10
	theme.set_stylebox("embedded_border","Window",window)
	theme.set_stylebox("embedded_unfocused_border","Window",window)
	theme.set_color("title_color","Window",GOLD)
	theme.set_font_size("title_font_size","Window",18)
	theme.set_constant("title_height","Window",36)
	theme.set_stylebox("panel","AcceptDialog",StyleBoxEmpty.new())
	theme.set_color("font_color","LinkButton",MUTED)
	theme.set_color("font_hover_color","LinkButton",GOLD)
	theme.set_color("font_pressed_color","LinkButton",GOLD)
	theme.set_color("font_focus_color","LinkButton",GOLD)
	var rule=StyleBoxLine.new()
	rule.color=Color(1,1,1,.1)
	rule.thickness=1
	theme.set_stylebox("separator","HSeparator",rule)
	theme.set_constant("separation","HSeparator",10)
	return theme

# Anchor a control and set its margins in one go, so layouts stay put when the
# viewport is wider (phones) or taller (4:3 tablets) than the 1280x720 base.
func pin(c: Control,anchors: Rect2,left: float,top: float,right: float,bottom: float) -> void:
	c.anchor_left=anchors.position.x
	c.anchor_top=anchors.position.y
	c.anchor_right=anchors.position.x+anchors.size.x
	c.anchor_bottom=anchors.position.y+anchors.size.y
	c.offset_left=left
	c.offset_top=top
	c.offset_right=right
	c.offset_bottom=bottom

func center_panel(c: Control,panel_size: Vector2) -> void:
	pin(c,Rect2(.5,.5,0,0),-panel_size.x*.5,-panel_size.y*.5,panel_size.x*.5,panel_size.y*.5)
	c.grow_horizontal=Control.GROW_DIRECTION_BOTH
	c.grow_vertical=Control.GROW_DIRECTION_BOTH

func build_ui() -> void:
	var canvas=CanvasLayer.new()
	add_child(canvas)
	ui=Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter=Control.MOUSE_FILTER_IGNORE
	canvas.add_child(ui)
	ui.theme=build_theme()
	hud_fx=HudFx.new()
	ui.add_child(hud_fx.vignette) # Below every panel.
	build_menu()
	build_hud()
	ui.add_child(hud_fx) # Above the HUD, below pause and dialogs.
	pause_backdrop=ColorRect.new()
	pause_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_backdrop.color=Color(.015,.055,.07,.7)
	ui.add_child(pause_backdrop)
	pause_backdrop.hide()
	pause_panel=PanelContainer.new()
	pause_panel.add_theme_stylebox_override("panel",card(PANEL_SOLID,24))
	ui.add_child(pause_panel)
	center_panel(pause_panel,Vector2(420,300))
	var pausecol=VBoxContainer.new()
	pausecol.add_theme_constant_override("separation",14)
	pause_panel.add_child(pausecol)
	pausecol.add_child(kicker("PAUZE"))
	pausecol.add_child(title("Je missie staat stil.",30))
	pausecol.add_child(button("Verder vliegen  →",resume_flight,true))
	pausecol.add_child(button("Stoppen · terug naar de hangar",return_menu))
	pause_panel.hide()
	build_photo_dialog()
	build_paint_shop()

func title(text: String,size_px: int) -> Label:
	var l=label(text,size_px,GOLD)
	l.add_theme_color_override("font_outline_color",Color("0a1d22"))
	l.add_theme_constant_override("outline_size",max(4,size_px/6))
	l.add_theme_color_override("font_shadow_color",Color(0,0,0,.45))
	l.add_theme_constant_override("shadow_offset_y",3)
	l.add_theme_constant_override("shadow_offset_x",0)
	return l

func build_menu() -> void:
	# A soft dark gradient behind the panel keeps it readable over the bright
	# map and gives the hangar some depth.
	menu_shade=TextureRect.new()
	var shade=GradientTexture2D.new()
	var ramp=Gradient.new()
	ramp.set_color(0,Color(.01,.05,.07,.82))
	ramp.set_color(1,Color(.01,.05,.07,0))
	ramp.add_point(.45,Color(.01,.05,.07,.45))
	shade.gradient=ramp
	shade.fill_from=Vector2(0,.5)
	shade.fill_to=Vector2(1,.5)
	shade.width=256
	shade.height=4
	menu_shade.texture=shade
	menu_shade.stretch_mode=TextureRect.STRETCH_SCALE
	menu_shade.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	menu_shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	ui.add_child(menu_shade)
	pin(menu_shade,Rect2(0,0,.62,1),0,0,0,0)
	menu=PanelContainer.new()
	menu.visibility_changed.connect(func(): menu_shade.visible=menu.visible)
	var menu_style=card(PANEL,26)
	menu_style.content_margin_left=28
	menu_style.content_margin_right=28
	menu_style.content_margin_top=24
	menu_style.content_margin_bottom=22
	menu.add_theme_stylebox_override("panel",menu_style)
	ui.add_child(menu)
	# Sized by its content and vertically centred. With the "expand" stretch
	# aspect the viewport is never shorter than 720 px, and the smoke test checks
	# the tallest variant (Europe route picker visible) still fits, so no
	# scrollbar is needed on phones, tablets or desktop.
	pin(menu,Rect2(0,.5,0,0),32,-300,500,300)
	menu.grow_vertical=Control.GROW_DIRECTION_BOTH
	var col=VBoxContainer.new()
	col.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation",8)
	menu.add_child(col)
	# Brand row: the app icon as logo, then badge, name and tagline.
	var brand=HBoxContainer.new()
	brand.add_theme_constant_override("separation",14)
	col.add_child(brand)
	var logo=TextureRect.new()
	logo.texture=load("res://assets/icon.svg")
	logo.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size=Vector2(84,84)
	logo.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	brand.add_child(logo)
	var brand_text=VBoxContainer.new()
	brand_text.add_theme_constant_override("separation",0)
	brand_text.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	brand.add_child(brand_text)
	var badge=label("VLIEGAVONTUUR",11,INK)
	badge.add_theme_stylebox_override("normal",chip(GOLD))
	badge.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	brand_text.add_child(badge)
	var name_label=title("Nieks TopoRotor",38)
	name_label.add_theme_color_override("font_shadow_color",Color(0,0,0,.45))
	name_label.add_theme_constant_override("shadow_offset_y",3)
	brand_text.add_child(name_label)
	var intro=label("Vlieg je topografie-huiswerk tegemoet.",15,Color("cfe0d9"))
	intro.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	brand_text.add_child(intro)
	var rule=ColorRect.new()
	rule.color=Color(1,.76,.36,.35)
	rule.custom_minimum_size=Vector2(0,1)
	col.add_child(rule)
	col.add_child(kicker("VLUCHTGEBIED"))
	region_select=OptionButton.new()
	region_select.add_item("Nederland · steden en wateren")
	region_select.add_item("Europa · landen en hoofdsteden")
	region_select.custom_minimum_size.y=50
	region_select.item_selected.connect(func(index): load_world("nl" if index==0 else "eu"))
	col.add_child(region_select)
	# Same slot and height as the Europe picker; only one of the two is visible.
	nl_route_select=OptionButton.new()
	for route in catalog.nl_routes:
		nl_route_select.add_item("%s (%d)" % [route.title,route.places.size()])
	nl_route_select.custom_minimum_size.y=46
	nl_route_select.visible=region=="nl"
	nl_route_select.item_selected.connect(func(_index): update_best_label())
	col.add_child(nl_route_select)
	europe_route_select=OptionButton.new()
	europe_route_select.add_item("Europa · kort rondje")
	europe_route_select.add_item("Europa · hoofdsteden (43)")
	europe_route_select.add_item("Europa · landen (50)")
	europe_route_select.custom_minimum_size.y=46
	europe_route_select.visible=false
	europe_route_select.item_selected.connect(func(_index): update_best_label())
	col.add_child(europe_route_select)
	col.add_child(kicker("SPELMODUS"))
	mode_select=OptionButton.new()
	mode_select.add_item("Leren · alle aanwijzingen")
	mode_select.add_item("Oefenen · hulp als je dichtbij bent")
	mode_select.add_item("Records · zonder hints, op snelheid")
	mode_select.item_selected.connect(func(_index): update_best_label())
	# The dropdown stays the model for the chosen mode; three tiles drive it.
	mode_select.visible=false
	col.add_child(mode_select)
	var tiles=HBoxContainer.new()
	tiles.add_theme_constant_override("separation",8)
	col.add_child(tiles)
	for entry in [["Leren","alle hints","Leren: namen, afstand en richting in beeld."],["Oefenen","hulp dichtbij","Oefenen: richting en hulp als je dichtbij bent."],["Records","op snelheid","Records: geen hints, op tijd en elke fout kost 10 seconden."]]:
		var tile=MenuWidgets.ModeTile.new(mode_tiles.size(),entry[0],entry[1],entry[2])
		tile.pressed.connect(choose_mode.bind(mode_tiles.size()))
		tiles.add_child(tile)
		mode_tiles.append(tile)
	refresh_mode_tiles()
	col.add_child(spacer(2))
	var start=button("START VLIEGMISSIE  →",func(): start_mission(),true)
	start.custom_minimum_size.y=64
	start.add_theme_font_size_override("font_size",23)
	col.add_child(start)
	var extras=HBoxContainer.new()
	extras.add_theme_constant_override("separation",10)
	col.add_child(extras)
	for entry in [["Online missies",open_online_content],["Foto / eigen lijst",open_photo_dialog]]:
		var b=button(entry[0],entry[1])
		b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		b.size_flags_stretch_ratio=1.0
		b.custom_minimum_size=Vector2(0,48)
		b.add_theme_font_size_override("font_size",17)
		b.clip_text=true
		extras.add_child(b)
	var stats=PanelContainer.new()
	var stats_style=style(Color(.08,.21,.25,.85),14,EDGE)
	stats_style.content_margin_top=10
	stats_style.content_margin_bottom=10
	stats_style.content_margin_left=16
	stats_style.content_margin_right=16
	stats.add_theme_stylebox_override("panel",stats_style)
	col.add_child(stats)
	best_label=label("Klaar voor vertrek, piloot?",16,CREAM)
	best_label.name="Best"
	best_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	stats.add_child(best_label)
	var footer=HBoxContainer.new()
	footer.add_theme_constant_override("separation",12)
	col.add_child(footer)
	paint_button=button("Helikopter spuiten",open_paint_shop)
	paint_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	paint_button.custom_minimum_size=Vector2(0,40)
	paint_button.add_theme_font_size_override("font_size",15)
	style_button(paint_button,false,12,12)
	footer.add_child(paint_button)
	mute_button=button("Geluid: uit" if saved.mute else "Geluid: aan",toggle_sound)
	mute_button.custom_minimum_size=Vector2(0,40)
	mute_button.add_theme_font_size_override("font_size",15)
	style_button(mute_button,false,12,12)
	footer.add_child(mute_button)
	# Same setting as the button under the flight heights: compass and minimap
	# stay north-up, or turn with the helicopter.
	menu_turn_button=button("",toggle_compass_mode)
	menu_turn_button.custom_minimum_size=Vector2(0,40)
	menu_turn_button.add_theme_font_size_override("font_size",15)
	menu_turn_button.tooltip_text="Vast: noord blijft boven. Draait mee: je neus wijst altijd omhoog. Geldt voor kompasrand en minikaart; tijdens het vliegen ook met toets R."
	style_button(menu_turn_button,false,12,12)
	footer.add_child(menu_turn_button)
	var credits=LinkButton.new()
	credits.text="Bronnen en licenties"
	credits.add_theme_font_size_override("font_size",14)
	credits.size_flags_horizontal=Control.SIZE_SHRINK_END
	credits.pressed.connect(show_credits)
	col.add_child(credits)

func choose_mode(index: int) -> void:
	mode_select.select(index)
	update_best_label()
	sfx.play("whoosh",1.3)

func refresh_mode_tiles() -> void:
	for tile in mode_tiles:
		tile.selected=tile.mode_index==mode_select.selected

func chip(color: Color) -> StyleBoxFlat:
	var s=style(color,8)
	s.content_margin_left=8
	s.content_margin_right=8
	s.content_margin_top=3
	s.content_margin_bottom=3
	return s

func spacer(height: float) -> Control:
	var c=Control.new()
	c.custom_minimum_size.y=height
	c.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return c

func build_hud() -> void:
	hud=Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter=Control.MOUSE_FILTER_IGNORE
	ui.add_child(hud)
	var top_left=Rect2(0,0,0,0)
	var top_right=Rect2(1,0,0,0)
	var bottom_left=Rect2(0,1,0,0)
	var bottom_right=Rect2(1,1,0,0)
	var top=PanelContainer.new()
	var top_style=card(PANEL,18,true)
	top_style.content_margin_left=20
	top_style.content_margin_top=12
	top_style.content_margin_bottom=12
	top.add_theme_stylebox_override("panel",top_style)
	top.mouse_filter=Control.MOUSE_FILTER_IGNORE
	hud.add_child(top)
	pin(top,top_left,24,20,464,120)
	var topcol=VBoxContainer.new()
	topcol.add_theme_constant_override("separation",2)
	top.add_child(topcol)
	progress_label=kicker("MISSIE 01 / 12")
	topcol.add_child(progress_label)
	title_label=title("Vlieg naar Utrecht",27)
	title_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.clip_text=true
	topcol.add_child(title_label)
	detail_label=label("",15,Color("d9e6df"))
	detail_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	detail_label.clip_text=true
	topcol.add_child(detail_label)
	compass=FlightCompass.new()
	hud.add_child(compass)
	pin(compass,Rect2(.5,0,0,0),-150,20,150,66)
	compass.grow_horizontal=Control.GROW_DIRECTION_BOTH
	var pause=button("Pauze",pause_flight)
	pause.add_theme_font_size_override("font_size",17)
	hud.add_child(pause)
	pin(pause,top_right,-157,20,-24,70)
	minimap=FlightMinimap.new()
	hud.add_child(minimap)
	pin(minimap,top_right,-284,84,-24,314)
	minimap.mouse_filter=Control.MOUSE_FILTER_STOP
	minimap.rotate_with_heading=saved.get("minimap_rotate",false)==true
	minimap.rotation_mode_changed.connect(minimap_rotation_changed)
	var height_panel=PanelContainer.new()
	height_panel.add_theme_stylebox_override("panel",compact_card())
	hud.add_child(height_panel)
	pin(height_panel,top_right,-284,326,-24,474)
	var height_col=VBoxContainer.new()
	height_col.add_theme_constant_override("separation",8)
	height_panel.add_child(height_col)
	height_label=label("Vlieghoogte · Laag",15,GOLD)
	height_col.add_child(height_label)
	var height_row=HBoxContainer.new()
	height_row.add_theme_constant_override("separation",8)
	height_col.add_child(height_row)
	lower_button=button("Lager −",func(): change_height(-1))
	higher_button=button("Hoger +",func(): change_height(1))
	for control in [lower_button,higher_button]:
		control.custom_minimum_size=Vector2(0,42)
		control.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		control.add_theme_font_size_override("font_size",15)
		style_button(control,false,10,8)
		height_row.add_child(control)
	map_turn_button=button("",toggle_compass_mode)
	map_turn_button.custom_minimum_size=Vector2(0,36)
	map_turn_button.add_theme_font_size_override("font_size",14)
	map_turn_button.tooltip_text="Vast: noord blijft boven. Draait mee: je neus wijst altijd omhoog. Geldt voor kompasrand en minikaart. Toets R."
	style_button(map_turn_button,false,10,8)
	height_col.add_child(map_turn_button)
	update_map_turn_button()
	update_height_controls()
	joystick=FlightJoystick.new()
	hud.add_child(joystick)
	pin(joystick,bottom_left,28,-210,208,-30)
	var movement=label("↑ VOORUIT   ← → DRAAIEN",11,CREAM)
	movement.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	movement.add_theme_color_override("font_outline_color",Color("0a1d22"))
	movement.add_theme_constant_override("outline_size",4)
	movement.mouse_filter=Control.MOUSE_FILTER_IGNORE
	joystick.add_child(movement)
	pin(movement,Rect2(0,0,1,0),-20,-22,20,-4)
	var actions=VBoxContainer.new()
	actions.add_theme_constant_override("separation",10)
	actions.alignment=BoxContainer.ALIGNMENT_END
	hud.add_child(actions)
	pin(actions,bottom_right,-284,-236,-24,-24)
	found_button=button("Hier is het!  ✓",answer,true)
	found_button.custom_minimum_size.y=60
	found_button.add_theme_font_size_override("font_size",22)
	actions.add_child(found_button)
	hint_button=button("Hint / kaartnamen",toggle_hint)
	actions.add_child(hint_button)
	actions.add_child(button("Overzichtskaart",toggle_overview))
	var status_panel=PanelContainer.new()
	status_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var status_style=card(Color(.03,.1,.13,.88),14)
	status_style.content_margin_top=10
	status_style.content_margin_bottom=10
	status_panel.add_theme_stylebox_override("panel",status_style)
	hud.add_child(status_panel)
	pin(status_panel,Rect2(0,1,1,0),232,-84,-308,-24)
	status_panel.grow_vertical=Control.GROW_DIRECTION_BEGIN
	status_label=label("",16,CREAM)
	status_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	status_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	status_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	status_panel.add_child(status_label)
	locator=LocatorCard.new()
	for place in catalog.places:
		if place.kind=="land" and not String(place.code).is_empty():
			locator.country_names[place.code]=LocatorCard.display_name(place)
	minimap.country_names=locator.country_names
	hud.add_child(locator)
	pin(locator,top_left,24,132,324,132)
	hud.hide()

func toggle_compass_mode() -> void:
	minimap.toggle_rotation()

func update_map_turn_button() -> void:
	if is_instance_valid(map_turn_button):
		map_turn_button.text="Kompas: draait mee" if minimap.rotate_with_heading else "Kompas: vast"
	# Shorter in the hangar so the footer keeps the menu at its usual width.
	if is_instance_valid(menu_turn_button):
		menu_turn_button.text="Kompas: draait" if minimap.rotate_with_heading else "Kompas: vast"

func minimap_rotation_changed(rotating: bool) -> void:
	update_map_turn_button()
	saved.minimap_rotate=rotating
	save_data()

func compact_card() -> StyleBoxFlat:
	var s=card(PANEL,14)
	s.content_margin_left=12
	s.content_margin_right=12
	s.content_margin_top=10
	s.content_margin_bottom=12
	return s

func show_credits() -> AcceptDialog:
	var dialog=AcceptDialog.new()
	dialog.title="Nieks TopoRotor · bronnen en licenties"
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
	if is_instance_valid(europe_route_select):
		europe_route_select.visible=region=="eu"
	if is_instance_valid(nl_route_select):
		nl_route_select.visible=region=="nl"
	if is_instance_valid(world):
		fx.detach_zone()
		remove_child(world)
		world.queue_free()
	world=TopoWorld.new()
	add_child(world)
	world.build(region,catalog)
	fx.attach_target(world.target)
	minimap.world=world
	if is_instance_valid(locator):
		locator.world=world
		locator.dismiss()
	helicopter.position=world.project(SPAWN.x,SPAWN.y)+Vector3(0,flight_altitude(),0)
	position_menu_camera()
	world.set_hints(false)
	update_best_label()

func selected_presets() -> Array:
	var picker: OptionButton=europe_route_select if region=="eu" else nl_route_select
	return catalog.presets(region,maxi(picker.selected,0) if is_instance_valid(picker) else 0)

func update_best_label() -> void:
	refresh_mode_tiles()
	var best=float(saved.get("records",{}).get(record_key(selected_presets()),0.0))
	var practice=clampi(int(saved.best.get(region+"_oefenen",0)),0,3)
	var records=clampi(int(saved.best.get(region+"_test",0)),0,3)
	best_label.text="Oefenen %s   ·   Records %s\n" % ["★".repeat(practice)+"☆".repeat(3-practice),"★".repeat(records)+"☆".repeat(3-records)]
	best_label.text+="Beste tijd gekozen route: %.1f sec" % best if best>0 else "Zet je eerste recordtijd neer!"

func record_key(places: Array) -> String:
	var route: Array=[]
	for place in places:
		route.append([place.name,place.lat,place.lon])
	route.sort_custom(func(a,b): return JSON.stringify(a)<JSON.stringify(b))
	return region+"_"+JSON.stringify(route).sha256_text()


func start_mission(custom: Array = [],as_custom: bool = true) -> void:
	if is_instance_valid(summary):
		summary.queue_free()
	custom_mission=as_custom and not custom.is_empty()
	mission=custom.duplicate() if not custom.is_empty() else selected_presets()
	game_mode=mode_select.selected
	sfx.muted=saved.mute
	fx.clear_effects()
	hud_fx.clear()
	locator.dismiss()
	shake=0.0
	in_zone=false
	if game_mode==GameMode.RECORDS:
		# Same start and route order make repeat record attempts comparable.
		mission.sort_custom(func(a,b): return a.name<b.name)
	else:
		mission.shuffle()
	world.ensure_mission_markers(mission)
	mission_index=0
	completed=[]
	mistakes=0
	flight_time=0
	record_result=""
	exam=game_mode==GameMode.RECORDS
	show_hints=game_mode==GameMode.LEARN
	hint_button.visible=game_mode==GameMode.LEARN
	# Learning and practice point the way on the minimap; records never do.
	minimap.show_direction=game_mode!=GameMode.RECORDS
	minimap.show_place_names=game_mode!=GameMode.RECORDS
	hint_button.text="Alle aanwijzingen aan"
	hint_button.disabled=true
	hints_used=false
	show_overview=false
	camera_level=0
	update_height_controls()
	state="flight"
	menu.hide()
	hud.show()
	velocity=Vector2.ZERO
	joystick.reset()
	helicopter.scale=Vector3.ONE*FLIGHT_HELI_SCALE
	helicopter.position=world.project(SPAWN.x,SPAWN.y)+Vector3(0,flight_altitude(),0)
	heading=0.0
	helicopter.rotation.y=heading
	if not saved.mute:
		rotor_audio.play()
	camera.size=flight_zoom()
	update_flight_camera(0.0,true)
	compass.heading=heading
	minimap.heading=heading
	minimap.aircraft=helicopter.position
	update_goal()

func update_goal() -> void:
	if mission_index>=mission.size():
		finish_mission()
		return
	var p: Dictionary=mission[mission_index]
	world.target.position=world.project(p.lon,p.lat)
	minimap.goal=world.target.position
	# The ring is the real answer range. Countries are checked against their
	# outline instead, so they get the beacon without a circle.
	minimap.goal_radius=zone_radius_units(p) if p.kind!="land" else 0.0
	fx.set_zone(zone_radius_units(p),p.kind!="land",cos(deg_to_rad(world.origin.y))/maxf(cos(deg_to_rad(p.lat)),.1))
	in_zone=false
	refresh_mode_hints()
	progress_label.text="%s  ·  MISSIE %02d / %02d" % [MODE_NAMES[game_mode],mission_index+1,mission.size()]
	title_label.text=("Vlieg boven " if p.kind=="land" else "Vlieg naar ")+p.name
	status_label.text="Zoek %s. Druk op ‘Hier is het!’ als je er bent." % p.name
	if mission_index==0:
		status_label.text+=" Omhoog vliegt vooruit, links/rechts draait de heli."
	goal_mistakes=0
	answer_cooldown=0.0

func _process(delta: float) -> void:
	if paint_open and is_instance_valid(preview_heli):
		preview_heli.rotate_y(delta*.6)
	if state=="menu":
		fly_menu_helicopter(delta)
	if state!="flight" or photo_open:
		return
	flight_time+=delta
	answer_cooldown=max(0,answer_cooldown-delta)
	keyboard=Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	steer((keyboard+joystick.value).limit_length(),delta)
	update_flight_camera(delta)
	refresh_mode_hints()
	minimap.aircraft=helicopter.position
	minimap.heading=heading
	compass.heading=heading
	minimap.refresh_navigation()
	world.refresh_labels(helicopter.position,show_overview,camera.size)
	world.set_boundary_detail(camera.size)
	update_effects(delta)
	if mission_index<mission.size():
		var p: Dictionary=mission[mission_index]
		var km=distance_km(p)
		var nav="%d km %s" % [km,goal_heading_word()] if game_mode==GameMode.LEARN else "Je bent dichtbij!" if show_hints else "Richting: %s" % goal_heading_word() if game_mode==GameMode.PRACTICE else "Zoek zelf de juiste plek."
		detail_label.text="%s  ·  %s %.1f sec  ·  %d gevonden" % [nav,"Recordtijd" if exam else "Vliegtijd",flight_time+mistakes*10.0 if exam else flight_time,completed.size()]

# Eight-wind direction from the helicopter to the current goal.
func goal_heading_word() -> String:
	var target=world.project(mission[mission_index].lon,mission[mission_index].lat)
	return CompassWords.HEADING[CompassWords.index_for_map_delta(Vector2(target.x-helicopter.position.x,target.z-helicopter.position.z))]

func flight_speed() -> float:
	return 10.0 if region=="nl" else 42.0

# Zone highlight, downwash, rotor pitch and the answer button pulse. The
# "in de zone" state is only computed while the mode already shows the goal,
# so it can never give away a hidden target.
func update_effects(delta: float) -> void:
	fx.view_scale=camera.size/FX_REFERENCE_ZOOM if not show_overview else 1.0
	var speed_fraction=clampf(velocity.length()/flight_speed(),0.0,1.0)
	fx.update_downwash(helicopter.position,camera_level,speed_fraction,not show_overview)
	rotor_audio.pitch_scale=.94+speed_fraction*.22
	shake=move_toward(shake,0.0,delta*2.6)
	var now_inside=false
	if mission_index<mission.size() and world.target.visible:
		now_inside=at_goal(mission[mission_index])
	if now_inside and not in_zone:
		status_label.text="In de zone! Druk nu op ‘Hier is het!’"
		sfx.play("star",.75)
	in_zone=now_inside
	fx.set_inside(in_zone)
	fx.update_sight(helicopter.position,not show_overview)
	var pulse=.5+.5*sin(flight_time*9.0) if in_zone else 0.0
	found_button.modulate=Color(1,1,1).lerp(Color(1.35,1.3,1.0),pulse)
	found_button.scale=Vector2.ONE*(1.0+pulse*.04)
	found_button.pivot_offset=found_button.size*.5

# Pilot-relative controls: x turns the helicopter, -y flies along the nose.
# Reversing is slower so the chase camera never has to swing round.
func steer(direction: Vector2,delta: float) -> void:
	var turn=direction.x
	var throttle=-direction.y
	heading=wrapf(heading-turn*TURN_RATE*delta,-PI,PI)
	helicopter.rotation.y=heading
	var thrust=throttle if throttle>0 else throttle*REVERSE_FACTOR
	var speed=flight_speed()
	# Exponential smoothing keeps steering consistent across frame rates.
	var response=9.0 if is_zero_approx(throttle) else 6.0
	velocity=velocity.lerp(nose_direction(heading)*thrust*speed,1.0-exp(-response*delta))
	helicopter.position.x=clamp(helicopter.position.x+velocity.x*delta,world.bounds.position.x+1,world.bounds.end.x-1)
	helicopter.position.z=clamp(helicopter.position.z+velocity.y*delta,world.bounds.position.y+1,world.bounds.end.y-1)
	helicopter.lean(Vector2(turn,throttle),delta)
	helicopter.position.y=lerp(helicopter.position.y,flight_altitude(),min(delta*2.5,1.0))

# World (x,z) direction of the nose. rotation.y 0 points north (-z).
static func nose_direction(yaw: float) -> Vector2:
	return Vector2(-sin(yaw),-cos(yaw))

# Chase view: behind and above the helicopter, turning with it. The overview
# stays north-up so the whole map keeps its familiar orientation.
func update_flight_camera(delta: float,snap: bool=false) -> void:
	var blend=1.0 if snap else 1.0-exp(-CAMERA_FOLLOW*delta)
	if show_overview:
		camera.h_offset=0.0
		camera.v_offset=0.0
		var center=world.bounds.get_center()
		camera.position=camera.position.lerp(Vector3(center.x,600,center.y+400),1.0 if snap else min(delta*3,1.0))
		camera.look_at(Vector3(center.x,0,center.y),Vector3.UP)
		camera.size=lerp(camera.size,max(world.bounds.size.x,world.bounds.size.y)*1.03,1.0 if snap else min(delta*3,1.0))
		return
	camera_yaw=lerp_angle(camera_yaw,heading,1.0 if snap else 1.0-exp(-CAMERA_TURN*delta))
	var nose=nose_direction(camera_yaw)
	var ahead=Vector3(nose.x,0,nose.y)
	var height=38.0 if region=="nl" else 95.0
	var back=44.0 if region=="nl" else 72.0
	camera.position=camera.position.lerp(helicopter.position+Vector3(0,height,0)-ahead*back,blend)
	camera.size=lerp(camera.size,flight_zoom(),1.0 if snap else min(delta*3,1.0))
	# Aim slightly ahead so more of the route is visible than what lies behind.
	# The aim point sits below the helicopter, between it and the ground, so the
	# ground sight (the point the answer check uses) stays well inside the view.
	var aim=Vector3(helicopter.position.x,helicopter.position.y*AIM_HEIGHT,helicopter.position.z)
	camera.look_at(aim+ahead*camera.size*LOOK_AHEAD,Vector3.UP)
	# Screen shake after a wrong answer uses the lens offset, so the camera's
	# position (and the chase geometry) stays exact.
	var jolt=shake*shake*camera.size*.03
	camera.h_offset=sin(flight_time*71.0)*jolt
	camera.v_offset=cos(flight_time*53.0)*jolt

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
			elif event.physical_keycode==KEY_R:
				toggle_compass_mode()
			elif event.physical_keycode in [KEY_Q,KEY_EQUAL,KEY_KP_ADD]:
				change_height(-1)
			elif event.physical_keycode in [KEY_E,KEY_MINUS,KEY_KP_SUBTRACT]:
				change_height(1)

func go_back(allow_quit: bool) -> void:
	if paint_open:
		close_paint_shop()
	elif photo_open:
		close_photo_dialog()
	elif state=="flight":
		pause_flight()
	elif state=="paused":
		resume_flight()
	elif state=="summary":
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

func hit_radius_km(place: Dictionary) -> float:
	var custom_radius=place.get("radius_km",0)
	if (custom_radius is float or custom_radius is int) and is_finite(float(custom_radius)) and custom_radius>0:
		return float(custom_radius)
	var nl=place.get("region",region)=="nl"
	match place.get("kind",""):
		"provincie":
			return 25.0
		"water":
			return 25.0 if nl else 40.0
		"eiland":
			return 10.0 if nl else 25.0
		"stad":
			return city_radius_km(place) if nl else EU_CITY_KM
	return 6.0 if nl else 25.0

const NL_CITY_KM = 6.0
const EU_CITY_KM = 45.0
const CITY_MARGIN_KM = .8

# A Dutch city counts as found anywhere over its visible neighbourhoods: its
# plan radius (plus a small margin) when that is larger than the 6 km floor.
# European cities get 45 km, which covers the house grid of their model town
# and still keeps the closest capitals (Wenen, Bratislava: 55 km) apart.
func city_radius_km(place: Dictionary) -> float:
	if not is_instance_valid(world) or world.region!="nl" or world.dutch_scenery==null:
		return NL_CITY_KM
	var plan: Dictionary=world.dutch_scenery.city_plans.get(place.get("name",""),{})
	var plan_radius=float(plan.get("radius",0.0))
	return maxf(NL_CITY_KM,plan_radius/units_per_km()+CITY_MARGIN_KM) if plan_radius>0 else NL_CITY_KM

func units_per_km() -> float:
	return world.geo_scale/111.195

func zone_radius_units(place: Dictionary) -> float:
	return hit_radius_km(place)*units_per_km()

# Countries without usable map geometry fall back to the catalog reference point.
func at_goal(p: Dictionary) -> bool:
	if p.kind=="land":
		return world.country_contains(p.code,helicopter.position) if world.has_country(p.code) else distance_km(p)<(1.5 if p.code=="VAT" else 25)
	return distance_km(p)<hit_radius_km(p)

func answer() -> void:
	if state!="flight" or answer_cooldown>0 or photo_open:
		return
	var p: Dictionary=mission[mission_index]
	sfx.muted=saved.mute
	var ground=Vector3(helicopter.position.x,0,helicopter.position.z)
	if at_goal(p):
		completed.append({"name":p.name,"hints":show_hints,"mistakes":goal_mistakes})
		if not saved.mute:
			feedback_audio.play()
		sfx.play("chime")
		fx.celebrate(world.target.position if p.kind!="land" else ground)
		var first_try=goal_mistakes==0
		mission_index+=1
		update_goal()
		# The last goal opens the summary, which has its own celebration.
		if state=="flight":
			hud_fx.show_hit("GOED ZO!" if first_try else "GEVONDEN!",p.name)
			status_label.text="Goed gevonden! Op naar %s." % mission[mission_index].name
			# Leren and Oefenen show where the place lies in the whole country.
			if game_mode!=GameMode.RECORDS:
				locator.present(p,mission.slice(0,mission_index-1))
		answer_cooldown=.6
	else:
		mistakes+=1
		goal_mistakes+=1
		status_label.text="Nog niet op de juiste plek. Kijk nog eens naar de kaart."
		sfx.play("buzzer")
		fx.miss_mark(ground)
		hud_fx.show_miss("MIS!" if goal_mistakes<3 else "NOG NIET!")
		shake=1.0
		answer_cooldown=1.0

func refresh_mode_hints() -> void:
	if mission_index>=mission.size():
		return
	var place: Dictionary=mission[mission_index]
	var nearby=distance_km(place)<(18.0 if region=="nl" else 75.0)
	if place.kind=="land":
		nearby=world.country_contains(place.code,helicopter.position) if world.has_country(place.code) else distance_km(place)<5.0
	show_hints=game_mode==GameMode.LEARN or (game_mode==GameMode.PRACTICE and nearby)
	# Only learning reveals map names. Practice reveals just the nearby goal.
	world.set_hints(game_mode==GameMode.LEARN)
	world.target.visible=show_hints
	minimap.show_goal=show_hints

func toggle_hint() -> void:
	# Keyboard shortcuts cannot bypass the selected mode's rules.
	if state=="flight":
		refresh_mode_hints()

func flight_altitude() -> float:
	return FLIGHT_ALTITUDES[camera_level] if region=="nl" else FLIGHT_ALTITUDES[camera_level]*1.35

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
	var previous=camera_level
	camera_level=clampi(camera_level+direction,0,FLIGHT_ZOOMS.size()-1)
	show_overview=false
	update_height_controls()
	if camera_level!=previous:
		sfx.play("whoosh",1.15 if direction<0 else .85)

func _unhandled_input(event: InputEvent) -> void:
	if state=="flight" and not photo_open and event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP:
			change_height(-1)
		elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN:
			change_height(1)

func toggle_overview() -> void:
	show_overview=not show_overview
	joystick.reset()
	sfx.play("whoosh",.7 if show_overview else 1.0)

func mission_stars(first_try: int) -> int:
	if mistakes==0 and exam and not hints_used:
		return 3
	return 2 if not completed.is_empty() and first_try*5>=completed.size()*4 else 1

func finish_mission() -> void:
	state="summary"
	hud.hide()
	world.target.hide()
	rotor_audio.stop()
	fx.idle()
	sfx.play("fanfare")
	var first_try=0
	var missed=PackedStringArray()
	for c in completed:
		if int(c.mistakes)==0:
			first_try+=1
		else:
			missed.append("%s (%d×)" % [c.name,c.mistakes])
	var stars=mission_stars(first_try)
	if not custom_mission:
		var key=region+("_test" if exam else "_oefenen")
		saved.best[key]=max(int(saved.best.get(key,0)),stars)
		save_data()
	if game_mode==GameMode.RECORDS:
		var score=flight_time+mistakes*10.0
		var key=record_key(mission)
		if not saved.has("records"):
			saved.records={}
		var previous=float(saved.records.get(key,0.0))
		if previous<=0 or score<previous:
			saved.records[key]=score
			record_result="Nieuw record: %.1f sec (+%d sec straf)!" % [score,mistakes*10]
			save_data()
		else:
			record_result="Tijd %.1f sec · record %.1f sec" % [score,previous]
	summary=PanelContainer.new()
	var summary_style=card(PANEL_SOLID,26)
	summary_style.content_margin_left=32
	summary_style.content_margin_right=32
	summary_style.content_margin_top=26
	summary_style.content_margin_bottom=26
	summary.add_theme_stylebox_override("panel",summary_style)
	ui.add_child(summary)
	center_panel(summary,Vector2(600,0))
	var col=VBoxContainer.new()
	col.add_theme_constant_override("separation",14)
	summary.add_child(col)
	col.add_child(kicker("MISSIE VOLTOOID"))
	col.add_child(title("Goed gevlogen, piloot!",34))
	col.add_child(star_row(stars))
	col.add_child(label("%d locaties gevonden · %d pogingen mis\nVliegtijd %02d:%02d" % [completed.size(),mistakes,int(flight_time)/60,int(flight_time)%60],21))
	if not missed.is_empty():
		var shown=PackedStringArray()
		for entry in missed.slice(0,3):
			shown.append(entry if entry.length()<=40 else entry.left(39)+"…")
		var extra=" … +%d meer" % (missed.size()-shown.size()) if missed.size()>shown.size() else ""
		var missed_label=label("Nog oefenen: "+", ".join(shown)+extra,17,CREAM)
		missed_label.tooltip_text="\n".join(missed)
		missed_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		col.add_child(missed_label)
	var tip=label(record_result if exam else "Drie sterren: foutloze Records-vlucht. Twee: minstens 80% in één keer goed.",16,Color("b5cec4"))
	tip.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	col.add_child(tip)
	col.add_child(button("Dezelfde locaties opnieuw",func(): start_mission(mission,custom_mission),true))
	col.add_child(button("Terug naar de hangar",return_menu))
	hud_fx.celebrate()
	# A last volley over the helicopter while the summary pops up.
	fx.celebrate(Vector3(helicopter.position.x,0,helicopter.position.z))

# Stars pop in one by one with a ping per earned star.
func star_row(stars: int) -> HBoxContainer:
	var row=HBoxContainer.new()
	row.alignment=BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation",10)
	for i in 3:
		var star=title("★" if i<stars else "☆",58)
		star.resized.connect(func(): star.pivot_offset=star.size*.5)
		star.scale=Vector2.ZERO
		row.add_child(star)
		var tween=star.create_tween()
		tween.tween_interval(.35+i*.28)
		if i<stars:
			tween.tween_callback(func(): sfx.play("star",1.0+i*.12))
		tween.tween_property(star,"scale",Vector2.ONE,.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	return row

func pause_flight() -> void:
	if state!="flight":
		return
	paused_from=state
	state="paused"
	velocity=Vector2.ZERO
	joystick.reset()
	rotor_audio.stop()
	fx.idle()
	pause_backdrop.show()
	pause_panel.show()

func resume_flight() -> void:
	if state!="paused":
		return
	state=paused_from
	pause_backdrop.hide()
	pause_panel.hide()
	velocity=Vector2.ZERO
	joystick.reset()
	if not saved.mute:
		rotor_audio.play()

func return_menu() -> void:
	pause_backdrop.hide()
	pause_panel.hide()
	state="menu"
	rotor_audio.stop()
	fx.idle()
	fx.clear_effects()
	hud_fx.clear()
	hud.hide()
	menu.show()
	joystick.reset()
	if is_instance_valid(summary):
		summary.queue_free()
	world.target.hide()
	world.set_hints(false)
	position_menu_camera()
	update_best_label()

# In the hangar a big helicopter circles over the map, banking into the turn.
func fly_menu_helicopter(delta: float) -> void:
	menu_flight_time+=delta
	var nl=region=="nl"
	var centre=world.bounds.get_center()+(Vector2(20,-10) if nl else Vector2(40,-30))
	var radius=58.0 if nl else 130.0
	var angle=menu_flight_time*.16
	var at=centre+Vector2(cos(angle),sin(angle))*radius
	var direction=Vector2(-sin(angle),cos(angle))
	helicopter.scale=Vector3.ONE*MENU_HELI_SCALE*(1.0 if nl else 1.9)
	helicopter.position=Vector3(at.x,(60.0 if nl else 110.0)+sin(menu_flight_time*.7)*3.0,at.y)
	helicopter.rotation.y=atan2(-direction.x,-direction.y)
	helicopter.lean(Vector2(.55,1.0),delta)

func position_menu_camera() -> void:
	var center=world.bounds.get_center()
	var shift=95.0 if region=="nl" else 190.0
	var view_target=Vector3(center.x-shift,0,center.y)
	camera.size=330 if region=="nl" else 650
	camera.h_offset=0.0
	camera.v_offset=0.0
	camera.position=view_target+Vector3(0,600,450)
	camera.look_at(view_target,Vector3.UP)
	world.set_boundary_detail(camera.size)

func toggle_sound() -> void:
	saved.mute=not saved.mute
	sfx.muted=saved.mute
	if saved.mute:
		sfx.stop_all()
	mute_button.text="Geluid: uit" if saved.mute else "Geluid: aan"
	save_data()

func load_save() -> void:
	if FileAccess.file_exists(save_path):
		var json=JSON.new()
		var raw: Variant=json.data if json.parse(FileAccess.get_file_as_string(save_path))==OK else null
		if not raw is Dictionary:
			var backup=save_path+".bak"
			if FileAccess.file_exists(backup):
				backup+=".%d" % Time.get_ticks_usec()
			if DirAccess.rename_absolute(save_path,backup)!=OK:
				progress_readonly=true
				push_warning("Kon onleesbare voortgang niet veiligstellen; opslaan uitgeschakeld.")
			else:
				progress_readonly=false
				push_warning("Onleesbare voortgang bewaard als "+backup+".")
		else:
			progress_readonly=ProgressStore.is_newer(raw)
		if ProgressStore.is_newer(raw):
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

# Paint shop: preset schemes plus three free colour pickers, with a live,
# slowly turning 3D preview rendered in its own little world.
func build_paint_shop() -> void:
	paint_backdrop=ColorRect.new()
	paint_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paint_backdrop.color=Color(.015,.055,.07,.78)
	ui.add_child(paint_backdrop)
	paint_backdrop.hide()
	paint_panel=PanelContainer.new()
	var panel_style=card(PANEL_SOLID,26)
	for side in [SIDE_LEFT,SIDE_RIGHT]:
		panel_style.set_content_margin(side,28)
	for side in [SIDE_TOP,SIDE_BOTTOM]:
		panel_style.set_content_margin(side,22)
	paint_panel.add_theme_stylebox_override("panel",panel_style)
	ui.add_child(paint_panel)
	center_panel(paint_panel,Vector2(860,0))
	paint_panel.hide()
	var col=VBoxContainer.new()
	col.add_theme_constant_override("separation",12)
	paint_panel.add_child(col)
	col.add_child(kicker("HANGAR · SPUITCABINE"))
	col.add_child(title("Spuit je helikopter",34))
	var row=HBoxContainer.new()
	row.add_theme_constant_override("separation",24)
	col.add_child(row)
	var stage=PanelContainer.new()
	var stage_style=style(Color("0b2228"),18,EDGE)
	for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]:
		stage_style.set_content_margin(side,0)
	stage.add_theme_stylebox_override("panel",stage_style)
	row.add_child(stage)
	var view_box=SubViewportContainer.new()
	view_box.stretch=true
	view_box.custom_minimum_size=Vector2(320,300)
	view_box.mouse_filter=Control.MOUSE_FILTER_IGNORE
	stage.add_child(view_box)
	var viewport=SubViewport.new()
	viewport.own_world_3d=true
	viewport.transparent_bg=true
	viewport.msaa_3d=Viewport.MSAA_4X
	view_box.add_child(viewport)
	var preview_camera=Camera3D.new()
	preview_camera.fov=34
	preview_camera.position=Vector3(0,6.6,12.0)
	var look=Environment.new()
	look.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	look.ambient_light_color=Color("d6e8df")
	look.ambient_light_energy=.7
	look.background_mode=Environment.BG_CLEAR_COLOR
	preview_camera.environment=look
	viewport.add_child(preview_camera)
	preview_camera.look_at(Vector3(0,1.8,0),Vector3.UP)
	var sun=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-48,-30,0)
	sun.light_energy=1.1
	viewport.add_child(sun)
	var pad=MeshInstance3D.new()
	var pad_mesh=CylinderMesh.new()
	pad_mesh.top_radius=3.1
	pad_mesh.bottom_radius=3.1
	pad_mesh.height=.12
	pad.mesh=pad_mesh
	var pad_mat=StandardMaterial3D.new()
	pad_mat.albedo_color=Color("2c4a50")
	pad.material_override=pad_mat
	pad.position.y=-.02
	viewport.add_child(pad)
	preview_heli=RotorHelicopter.new()
	viewport.add_child(preview_heli)
	preview_heli.rotation.y=-.7
	preview_heli.position.y=2.4
	var right=VBoxContainer.new()
	right.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation",10)
	row.add_child(right)
	right.add_child(kicker("KLEURSCHEMA'S"))
	var grid=GridContainer.new()
	grid.columns=3
	grid.add_theme_constant_override("h_separation",10)
	grid.add_theme_constant_override("v_separation",10)
	right.add_child(grid)
	for scheme in PAINT_SCHEMES:
		var swatch=button(scheme[0],func(): set_paint({"body":scheme[1],"trim":scheme[2],"dark":scheme[3]}))
		swatch.name="Scheme_"+scheme[0]
		swatch.custom_minimum_size=Vector2(150,46)
		swatch.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		swatch.add_theme_font_size_override("font_size",15)
		var body=Color(scheme[1])
		var ink=INK if body.get_luminance()>.55 else CREAM
		for state_name in ["normal","hover","pressed","hover_pressed"]:
			var face_style=face(body.lightened(.12) if state_name=="hover" else body,Color(scheme[2]),state_name.contains("pressed"),12,8)
			face_style.border_width_bottom=0 if state_name.contains("pressed") else 6
			swatch.add_theme_stylebox_override(state_name,face_style)
		for key in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_hover_pressed_color"]:
			swatch.add_theme_color_override(key,ink)
		grid.add_child(swatch)
	right.add_child(kicker("EIGEN KLEUREN"))
	var custom=HBoxContainer.new()
	custom.add_theme_constant_override("separation",10)
	right.add_child(custom)
	for part in PAINT_PARTS:
		var cell=VBoxContainer.new()
		cell.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation",4)
		custom.add_child(cell)
		cell.add_child(label(part[1],14,MUTED))
		var picker=ColorPickerButton.new()
		picker.edit_alpha=false
		picker.custom_minimum_size=Vector2(0,42)
		picker.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var colour_picker=picker.get_picker()
		colour_picker.presets_visible=false
		colour_picker.can_add_swatches=false
		colour_picker.sampler_visible=false
		picker.color_changed.connect(func(colour: Color):
			var paint=current_paint()
			paint[part[0]]=colour.to_html(false)
			set_paint(paint,false))
		paint_pickers[part[0]]=picker
		cell.add_child(picker)
	var footer=HBoxContainer.new()
	footer.add_theme_constant_override("separation",12)
	col.add_child(footer)
	var reset=button("Fabriekskleuren",func(): set_paint(RotorHelicopter.DEFAULT_PAINT.duplicate()))
	reset.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	footer.add_child(reset)
	var done=button("Klaar · naar de hangar  →",close_paint_shop,true)
	done.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	footer.add_child(done)

func current_paint() -> Dictionary:
	var paint: Dictionary={}
	for part in RotorHelicopter.DEFAULT_PAINT:
		paint[part]=helicopter.paint_hex(part)
	return paint

func set_paint(paint: Dictionary,sync_pickers: bool=true) -> void:
	helicopter.apply_paint(paint)
	if is_instance_valid(preview_heli) and not preview_heli.paint_materials.is_empty():
		preview_heli.apply_paint(paint)
	saved.paint=current_paint()
	if sync_pickers:
		for part in paint_pickers:
			paint_pickers[part].color=Color(saved.paint[part])

func open_paint_shop() -> void:
	if state!="menu":
		return
	paint_open=true
	set_paint(current_paint())
	paint_backdrop.show()
	paint_panel.show()

func close_paint_shop() -> void:
	if not paint_open:
		return
	paint_open=false
	for picker in paint_pickers.values():
		picker.get_popup().hide()
	paint_panel.hide()
	paint_backdrop.hide()
	save_data()

func build_photo_dialog() -> void:
	photo_backdrop=ColorRect.new()
	photo_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	photo_backdrop.color=Color(.015,.055,.07,.82)
	ui.add_child(photo_backdrop)
	photo_backdrop.hide()
	photo_dialog=PanelContainer.new()
	photo_dialog.add_theme_stylebox_override("panel",card(Color("0f2a33"),24))
	ui.add_child(photo_dialog)
	center_panel(photo_dialog,PHOTO_SIZE)
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
	var help=label("Eén naam per regel, of gescheiden met komma's.\nEigen punt: naam | breedtegraad | lengtegraad (WGS84, bv. 52.123 | 5.456)",14)
	right.add_child(help)
	mission_text=TextEdit.new()
	mission_text.custom_minimum_size=Vector2(650,180)
	mission_text.size_flags_vertical=Control.SIZE_EXPAND_FILL
	mission_text.placeholder_text="Amsterdam\nArnhem\nIJsselmeer\nOf: Mijn dorp | 52.123 | 5.456"
	right.add_child(mission_text)
	mission_text.text_changed.connect(validate_custom)
	import_status=label("Voer eerst de locaties in.",14,GOLD)
	# clip_text plus autowrap collapses a Label to zero height, which hid this
	# status line entirely; reserve two lines instead.
	import_status.custom_minimum_size.y=44
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
	center_panel(photo_dialog,PHOTO_SIZE)
	photo_backdrop.show()
	photo_dialog.show()
	call_deferred("fit_photo_panel")

func fit_photo_panel() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	center_panel(photo_dialog,PHOTO_SIZE)

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
	var image_size=WorksheetImage.dimensions(bytes)
	if not WorksheetImage.allowed_size(image_size):
		import_status.text="Kan deze foto niet lezen. Kies een andere JPG of PNG." if image_size.x<=0 or image_size.y<=0 else "Foto is %.1f MP; maximaal %d MP. Kies een lagere camera-resolutie." % [float(image_size.x)*float(image_size.y)/1000000.0,WorksheetImage.MAX_PIXELS/1000000]
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
		import_status.text="Voer eerst de locaties in." if result.found.is_empty() else "%d locaties herkend. Klaar om te vliegen." % result.found.size()
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
	start_mission(custom_places,true)

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
			pause_flight()

func key_event(code: Key) -> InputEventKey:
	var event=InputEventKey.new()
	event.physical_keycode=code
	event.pressed=true
	return event

func smoke_test() -> void:
	assert(world.province_regions.size()==12,"All Dutch provinces are bundled")
	assert(world.neighbour_polys.has("DEU") and world.neighbour_polys.has("BEL") and not world.neighbour_polys.has("NLD"),"2D maps get whole neighbour countries")
	assert(world.boundary_data.municipality_count==342,"Official municipality layer is complete")
	for level in ["national","provincial","municipal"]:
		assert(not world.boundary_paths[level].is_empty(),"Boundary level has usable geometry: "+level)
	var layouts: Dictionary={}
	var dutch_cities=0
	for place in catalog.places:
		if place.kind=="stad" and place.region=="nl":
			dutch_cities+=1
			assert(world.dutch_scenery.city_stats.has(place.name),"Every Dutch city receives a city plan")
			var stats: Dictionary=world.dutch_scenery.city_stats[place.name]
			assert(stats.plots>0,"City plan is not empty: "+place.name)
			layouts[stats.layout]=true
	assert(dutch_cities==65 and layouts.size()==dutch_cities,"Dutch cities do not repeat the same layout")
	# Worksheet routes: overview map, learning map and maps A-D of the textbook.
	assert(catalog.nl_routes.size()==7,"All Dutch worksheet routes are bundled")
	assert(catalog.presets("nl",0)==[catalog.lookup.utrecht,catalog.lookup.amsterdam,catalog.lookup["den haag"],catalog.lookup.rotterdam,catalog.lookup.middelburg,catalog.lookup["den bosch"],catalog.lookup.maastricht,catalog.lookup.arnhem,catalog.lookup.zwolle,catalog.lookup.assen,catalog.lookup.groningen,catalog.lookup.leeuwarden],"Short Dutch route is unchanged, so its best time stays")
	assert(catalog.presets("nl",1).size()==34,"Overview map lists all 34 numbered places")
	for route in catalog.nl_routes:
		for place in route.places:
			assert(place.region=="nl" and TopoWorld.in_bounds(TopoWorld.map_bounds("nl"),place.lat,place.lon),"Route place lies on the Dutch map: "+place.name)
	for name in ["Biesbos","Randstad","Twente","Veluwe","Schiphol","Afsluitdijk","Vaalserberg","Lek","Neder-Rijn","Fryslân","Groningen (provincie)","Utrecht (stad)","Zaandam","Alphen aan den Rijn"]:
		assert(catalog.lookup.has(catalog.normalize(name)),"Worksheet name is known: "+name)
	assert(catalog.lookup[catalog.normalize("Groningen (provincie)")].kind=="provincie" and catalog.lookup[catalog.normalize("Groningen (stad)")].kind=="stad","Province and city with the same name stay apart")
	assert(hit_radius_km(catalog.lookup.biesbos)==7.0 and hit_radius_km(catalog.lookup.randstad)==30.0,"Areas use their own answer range")
	var builtin_cities=["Amsterdam","Rotterdam","Utrecht","Den Haag","Groningen","Arnhem","Nijmegen","Maastricht","Almere","Lelystad","Leeuwarden","Zwolle","Breda","Delft","Middelburg","Sneek","Eindhoven"]
	var real_landmarks=0
	for place in catalog.places:
		if place.kind=="stad" and place.region=="nl":
			var entries: Array=world.dutch_scenery.landmark_data.get(place.name,[])
			assert(entries.size()>=1 and entries.size()<=3,"1-3 real landmarks per Dutch city: "+place.name)
			var built=0
			for entry in entries:
				assert(LandmarkKit.known(entry.get("type","")),"Known landmark type for "+place.name)
				assert(entry.get("type")!="builtin" or place.name in builtin_cities,"Builtin landmark exists for "+place.name)
				if entry.get("type")!="builtin":
					built+=1
					assert(Vector2(entry.at[0],entry.at[1]).length()<8.0,"Landmark stays inside its city: "+entry.name)
			assert(world.dutch_scenery.landmark_built.get(place.name,-1)==built,"Every listed landmark is built in "+place.name)
			real_landmarks+=entries.size()
	assert(real_landmarks>=100,"Dutch cities share at least 100 recognisable landmarks")
	for name in world.dutch_scenery.landmark_data:
		assert(catalog.lookup.has(catalog.normalize(name)),"Landmark city exists in the catalog: "+name)
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
	assert(world.mat(Color.WHITE)==world.mat(Color.WHITE),"Materials are reused")
	assert(world.mat(Color.WHITE)!=world.mat(Color.WHITE,false,true),"Cull variants stay separate")
	assert(not world.mat(Color.WHITE).vertex_color_use_as_albedo,"Field vertex colors do not leak into shared materials")
	# Chase camera: pilot-relative steering and a view that turns with the nose.
	assert(is_zero_approx(heading) and camera.position.z>helicopter.position.z,"Mission starts nose north with the camera behind")
	var steer_start=helicopter.position
	for i in 30:
		steer(Vector2(0,-1),1.0/30.0)
	assert(helicopter.position.z<steer_start.z-1.0 and absf(helicopter.position.x-steer_start.x)<.01,"Forward flies along the nose (north)")
	for i in 60:
		steer(Vector2(1,0),1.0/60.0)
	assert(heading<-1.5 and heading>-2.6,"Right stick turns clockwise seen from above")
	assert(FlightCompass.bearing(heading)>85 and FlightCompass.bearing(heading)<150,"Compass reads an easterly bearing after turning right")
	velocity=Vector2.ZERO
	var turn_start=helicopter.position
	for i in 30:
		steer(Vector2(0,-1),1.0/30.0)
	assert(helicopter.position.x>turn_start.x+1.0,"After turning right, forward flies east")
	update_flight_camera(0.0,true)
	var behind=Vector2(camera.position.x-helicopter.position.x,camera.position.z-helicopter.position.z).normalized()
	assert(behind.dot(-nose_direction(heading))>.99,"Camera sits behind the nose after a turn")
	for i in 30:
		steer(Vector2(0,1),1.0/30.0)
	assert(velocity.length()<(10.0 if region=="nl" else 42.0)*REVERSE_FACTOR+.01,"Reversing is slower than forward flight")
	start_mission([catalog.lookup.arnhem])
	assert(is_zero_approx(heading),"New mission resets the heading")
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
	assert(close_zoom==38.0 and low_altitude==14.0 and FLIGHT_ZOOMS[2]>64.0,"Every level is one step higher: Laag is the former Midden")
	# Minimap: north-up by default, heading-up on request; turning is a node
	# rotation, so the country geometry is never redrawn for it.
	minimap.aircraft=helicopter.position
	minimap.heading=PI*.5 # nose west
	minimap.rotate_with_heading=true
	minimap.refresh_navigation()
	assert(minimap.screen_direction(nose_direction(PI*.5)).distance_to(Vector2.UP)<.01,"Heading-up minimap turns the nose up")
	assert(is_equal_approx(minimap.map_layer.rotation,PI*.5),"Map layer turns as a node")
	assert(minimap.screen_direction(CompassWords.map_direction(0)).distance_to(Vector2.RIGHT)<.01,"Flying west, north lies to the right on a heading-up map")
	assert(minimap.screen_point(minimap.view_center).distance_to(minimap.circle_center())<1.0,"Turning country map turns around its centre")
	assert(saved.minimap_rotate==true and map_turn_button.text.contains("draait mee") and menu_turn_button.text=="Kompas: draait","Rotation choice is stored and shown in flight and in the hangar")
	_unhandled_key_input(key_event(KEY_R))
	minimap.refresh_navigation()
	assert(not minimap.rotate_with_heading and is_zero_approx(minimap.map_layer.rotation) and saved.minimap_rotate==false,"R returns to a still north-up map")
	assert(minimap.screen_direction(Vector2.UP)==Vector2.UP and map_turn_button.text=="Kompas: vast","North-up map shows north at the top")
	assert(ProgressStore.clean({"minimap_rotate":true}).minimap_rotate==true and not ProgressStore.clean({"minimap_rotate":"ja"}).has("minimap_rotate"),"Rotation setting is validated")
	minimap.heading=heading
	helicopter.position=world.project(5.8987,51.9851)+Vector3(0,9.0 if region=="nl" else 3.3,0)
	assert(distance_km(mission[0])<.01,"Distance at target")
	# Answer range covers the visible city: every Dutch city plan fits inside it.
	for place in catalog.places:
		if place.kind=="stad" and place.region=="nl":
			var plan_units=float(world.dutch_scenery.city_plans.get(place.name,{}).get("radius",0.0))
			assert(hit_radius_km(place)>=NL_CITY_KM and zone_radius_units(place)>=plan_units,"Visible city lies inside its answer range: "+place.name)
	var arnhem_plan=float(world.dutch_scenery.city_plans.Arnhem.radius)
	assert(is_equal_approx(hit_radius_km(catalog.lookup.arnhem),arnhem_plan/units_per_km()+CITY_MARGIN_KM),"Arnhem range follows its city plan")
	var arnhem_center=world.project(catalog.lookup.arnhem.lon,catalog.lookup.arnhem.lat)
	helicopter.position=arnhem_center+Vector3(arnhem_plan*.95,9.0,0)
	assert(at_goal(catalog.lookup.arnhem),"Outer neighbourhood of the city counts as found")
	helicopter.position=arnhem_center+Vector3(zone_radius_units(catalog.lookup.arnhem)*1.15,9.0,0)
	assert(not at_goal(catalog.lookup.arnhem),"Just outside the drawn ring is not found")
	helicopter.position=world.project(5.8987,51.9851)+Vector3(0,9.0 if region=="nl" else 3.3,0)
	assert(fx.zone.get_parent()==world.target and fx.zone_disc.visible,"Goal shows its answer range as a circle")
	assert(is_equal_approx(fx.zone_radius,zone_radius_units(mission[0])),"Drawn circle equals the answer range")
	assert(is_equal_approx(minimap.goal_radius,fx.zone_radius),"Minimap ring uses the same range")
	_process(1.0/60.0)
	assert(in_zone and fx.inside,"Being inside the visible range lights up the zone")
	assert(hit_radius_km({"kind":"provincie","region":"nl"})==25.0,"Province tolerance")
	assert(hit_radius_km({"kind":"eiland","region":"nl"})==10.0,"Island tolerance")
	assert(hit_radius_km({"radius_km":INF,"region":"nl","kind":"stad"})==6.0,"Nonfinite radius ignored")
	var before_pause=flight_time
	go_back(false)
	_process(10.0)
	assert(state=="paused" and pause_panel.visible and flight_time==before_pause,"Back pauses flight and stopwatch")
	go_back(false)
	assert(state=="flight" and not pause_panel.visible,"Back resumes paused flight")
	answer()
	assert(state=="summary" and completed.size()==1,"Mission completes on correct answer")
	return_menu()
	mode_select.select(GameMode.PRACTICE)
	var stars_before=JSON.stringify(saved.best)
	start_mission([catalog.lookup.amsterdam,catalog.lookup.arnhem])
	helicopter.position=world.project(-20,35)
	var crosses_before=hud_fx.crosses_shown
	answer()
	assert(goal_mistakes==1,"Wrong answer belongs to current goal")
	assert(hud_fx.crosses_shown==crosses_before+1 and hud_fx.cross.visible and fx.misses_shown>0 and shake>0,"Wrong answer shows a big red cross and shakes the view")
	_process(1.0/60.0)
	assert(not in_zone and not fx.inside,"Distant practice goal never reports the zone")
	var bursts_before=fx.bursts_started
	var banners_before=hud_fx.banners_shown
	for index in 2:
		var target_place: Dictionary=mission[mission_index]
		helicopter.position=world.project(target_place.lon,target_place.lat)
		answer_cooldown=0
		answer()
		assert(fx.bursts_started>bursts_before,"Correct answer launches fireworks")
		bursts_before=fx.bursts_started
	assert(hud_fx.banners_shown==banners_before+1,"Hit banner for the first goal; the last goal opens the summary instead")
	assert(completed[0].mistakes==1 and completed[1].mistakes==0,"Mistakes reset between goals")
	assert(mission_stars(1)==1,"Half correct on first try earns one star")
	assert(JSON.stringify(saved.best)==stars_before,"Custom missions preserve preset stars")
	mode_select.select(GameMode.LEARN)
	return_menu()
	load_world("eu")
	for place in catalog.places:
		if place.kind=="land":
			assert(world.has_country(place.code) or place.code=="VAT","Country %s has map polygons or documented point fallback" % place.code)
	assert(world.country_contains("FRA",world.project(2.3522,48.8566)),"Paris in France")
	assert(not world.country_contains("FRA",world.project(13.405,52.52)),"Berlin not France")
	assert(world.country_contains("UKR",world.project(34.1,44.95)) and not world.country_contains("RUS",world.project(34.1,44.95)),"Crimea counts as Ukraine")
	assert(world.country_contains("CYP",world.project(33.9,35.3)),"Northern Cyprus counts as Cyprus")
	assert(world.country_contains("FIN",world.project(19.95,60.2)),"Aland counts as Finland")
	for pair in [["rome","Rome ligt in Italië, ten zuidoosten van Nederland."],["londen","Londen ligt in het Verenigd Koninkrijk, ten westen van Nederland."],["duitsland","Duitsland ligt ten oosten van Nederland."]]:
		if catalog.lookup.has(pair[0]):
			var sentence=locator.describe(catalog.lookup[pair[0]])
			assert(sentence==pair[1],"European locator sentence: "+sentence)
	mission_text.text="Mijn dorp | 52.123 | 5.456\nAmsterdam"
	var custom=parse_custom()
	assert(custom.found.size()==2 and custom.unknown.is_empty(),"Custom coordinate import")
	mission_text.text="Opa | 52,08 | 5,12"
	assert(parse_custom().unknown.is_empty(),"Decimal comma coordinates accepted")
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
	assert(not world.helipads.has("Arnhem"),"Europe base map omits Arnhem scenery")
	world.ensure_mission_markers([catalog.lookup.arnhem])
	assert(world.label_names.has("Arnhem") and not world.helipads.has("Arnhem"),"Mission-only markers do not reveal targets with new scenery")
	assert(hit_radius_km(catalog.lookup.arnhem)==NL_CITY_KM,"Dutch city keeps its 6 km floor on Europe map")
	assert(hit_radius_km(catalog.lookup.parijs)==EU_CITY_KM and hit_radius_km({"kind":"eigen punt","region":"eu"})==25.0,"European city range covers its model town")
	assert(fx.zone.get_parent()==world.target,"Range circle survives a region reload")
	assert(sfx.players.size()==8,"All synthesised effect sounds are built")
	for sound in sfx.players.values():
		assert(sound.stream.data.size()>1000,"Effect sound has audio data")
	assert(WorksheetImage.allowed_size(Vector2i(6000,4000)),"24 MP photos accepted")
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
	var extra=ProgressStore.clean({"future_option":{"enabled":true}})
	assert(extra.get("future_option",{}).get("enabled",false),"Unknown progress fields survive validation")
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
	var prior_saved=saved.duplicate(true)
	var broken=FileAccess.open(save_path,FileAccess.WRITE)
	broken.store_string("{broken progress")
	broken.close()
	load_save()
	assert(not FileAccess.file_exists(save_path) and FileAccess.get_file_as_string(save_path+".bak")=="{broken progress","Corrupt progress is backed up before replacement")
	DirAccess.remove_absolute(save_path+".bak")
	saved=prior_saved
	custom_places=saved.custom
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
	load_world("nl")
	mode_select.select(GameMode.LEARN)
	start_mission([catalog.lookup.amsterdam])
	assert(minimap.show_goal and world.target.visible,"Learning reveals the target")
	minimap.refresh_navigation()
	assert(minimap.direction_index==-1,"A goal visible on the minimap needs no arrow")
	assert(goal_heading_word()=="noordwest","Learning names the direction: Amsterdam lies north-west of Utrecht")
	# Locator card: after a correct answer the whole country shows where it lies.
	start_mission([catalog.lookup.assen,catalog.lookup.maastricht])
	assert(not locator.visible,"A new mission starts without a locator card")
	var first_goal: Dictionary=mission[0]
	helicopter.position=world.project(first_goal.lon,first_goal.lat)
	answer_cooldown=0
	answer()
	assert(locator.visible and locator.place.name==first_goal.name and locator.found_before.is_empty(),"Learning shows where the found place lies")
	assert(locator.body_label.text==locator.describe(first_goal),"Card explains the position in words")
	helicopter.position=world.project(mission[1].lon,mission[1].lat)
	answer_cooldown=0
	answer()
	assert(state=="summary" and not locator.is_visible_in_tree(),"The last goal opens the summary instead of a card")
	var expected_sentences={
		"assen":"Assen ligt in het noordoosten van Nederland, in de provincie Drenthe.",
		"maastricht":"Maastricht ligt in het zuiden van Nederland, in de provincie Limburg.",
		"utrecht":"Utrecht ligt in het midden van Nederland, in de provincie Utrecht.",
		"middelburg":"Middelburg ligt in het zuidwesten van Nederland, in de provincie Zeeland.",
		"groningen provincie":"Groningen is een provincie in het noordoosten van Nederland.",
	}
	for key in expected_sentences:
		var sentence=locator.describe(catalog.lookup[key])
		assert(sentence==expected_sentences[key],"Locator sentence for %s: %s" % [key,sentence])
	for place in catalog.places:
		if place.region=="nl":
			assert(locator.describe(place).ends_with(".") and not locator.describe(place).contains("  "),"Every Dutch place gets a sentence: "+place.name)
	mode_select.select(GameMode.PRACTICE)
	start_mission([catalog.lookup.amsterdam])
	assert(not minimap.show_goal and not world.target.visible,"Practice hides distant target")
	minimap.refresh_navigation()
	assert(minimap.direction_index==7,"Practice arrow points north-west towards Amsterdam")
	_process(1.0/60.0)
	assert(detail_label.text.begins_with("Richting: noordwest"),"Practice names the direction in words")
	var cards_before=locator.shown_count
	start_mission([catalog.lookup.amsterdam,catalog.lookup.arnhem])
	helicopter.position=world.project(mission[0].lon,mission[0].lat)
	answer()
	assert(locator.shown_count==cards_before+1 and locator.visible,"Practice also shows the locator card")
	start_mission([catalog.lookup.amsterdam])
	toggle_hint()
	assert(not minimap.show_goal,"H cannot reveal distant practice target")
	helicopter.position=world.project(catalog.lookup.amsterdam.lon,catalog.lookup.amsterdam.lat)
	refresh_mode_hints()
	assert(minimap.show_goal and world.target.visible,"Practice reveals nearby target")
	helicopter.position=world.project(SPAWN.x,SPAWN.y)
	refresh_mode_hints()
	assert(not minimap.show_goal,"Practice hides target again when leaving range")
	mode_select.select(GameMode.RECORDS)
	start_mission([catalog.lookup.amsterdam])
	helicopter.position=world.project(catalog.lookup.amsterdam.lon,catalog.lookup.amsterdam.lat)
	refresh_mode_hints()
	toggle_hint()
	assert(not minimap.show_goal and not world.target.visible,"Records never reveals target, even nearby or via H")
	minimap.refresh_navigation()
	assert(minimap.direction_index==-1 and not minimap.show_direction,"Records never points the way")
	minimap.current_area="Noord-Holland"
	assert(minimap.caption_text().begins_with("Nederland"),"Records keeps the minimap caption neutral")
	update_effects(1.0/60.0)
	assert(not in_zone and not fx.inside and found_button.modulate==Color.WHITE,"Records never hints the zone, even at the goal")
	for marker in world.labels:
		assert(not marker.visible,"Records hides all map names")
	flight_time=12.5
	mistakes=1
	var record_cards=locator.shown_count
	answer()
	assert(locator.shown_count==record_cards,"Records shows no locator card")
	var race_key=record_key(mission)
	assert(state=="summary" and saved.records[race_key]==22.5,"Record adds ten seconds per wrong answer")
	start_mission([catalog.lookup.amsterdam])
	helicopter.position=world.project(catalog.lookup.amsterdam.lon,catalog.lookup.amsterdam.lat)
	flight_time=30
	answer()
	assert(saved.records[race_key]==22.5,"Slower attempt cannot overwrite record")
	var cleaned=ProgressStore.clean({"records":{race_key:22.5,"bad":-1}})
	assert(cleaned.records.get(race_key)==22.5 and not cleaned.records.has("bad"),"Record validation preserves only valid results")
	mode_select.select(GameMode.LEARN)
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
	load_world("eu")
	assert(world.europe_scenery.landmarks.size()>=40,"European capitals have detailed city scenery")
	assert(world.europe_scenery.peak_count>20 and world.europe_scenery.terrain_patches>100,"Europe has terrain and mountain variety")
	assert(catalog.presets("eu",1).size()>40 and catalog.presets("eu",2).size()>35,"Full-European capital and country routes exist")
	mode_select.select(GameMode.PRACTICE)
	start_mission([catalog.lookup.parijs])
	assert(not minimap.show_goal,"European practice hides a distant city")
	helicopter.position=world.project(catalog.lookup.parijs.lon,catalog.lookup.parijs.lat)
	refresh_mode_hints()
	assert(minimap.show_goal,"European practice reveals nearby city")
	start_mission([catalog.lookup["frankrijk"]])
	refresh_mode_hints()
	assert(not minimap.show_goal,"Country goal stays hidden outside country")
	helicopter.position=world.project(2.3,48.8)
	refresh_mode_hints()
	assert(minimap.show_goal,"European country practice reveals goal inside country")
	mode_select.select(GameMode.RECORDS)
	start_mission([catalog.lookup.parijs])
	helicopter.position=world.project(catalog.lookup.parijs.lon,catalog.lookup.parijs.lat)
	toggle_hint()
	toggle_overview()
	world.refresh_labels(helicopter.position,true)
	assert(not minimap.show_goal and not world.target.visible,"European records hides markers even in overview")
	for marker in world.labels:
		assert(not marker.visible,"European records overview does not reveal labels")
	var vatican: Dictionary=catalog.lookup.vaticaanstad
	mode_select.select(GameMode.PRACTICE)
	start_mission([vatican])
	helicopter.position=world.project(vatican.lon,vatican.lat)
	refresh_mode_hints()
	assert(minimap.show_goal,"Vatican point fallback reveals nearby goal")
	answer()
	assert(state=="summary","Vatican fallback accepts its reference point")
	mode_select.select(GameMode.LEARN)
	return_menu()
	# Paint shop: presets and pickers recolour the real helicopter and persist.
	var paint_before=current_paint()
	open_paint_shop()
	assert(paint_open and paint_panel.visible,"Paint shop opens from the hangar")
	var police: Button=paint_panel.find_child("Scheme_Politie",true,false)
	police.pressed.emit()
	assert(helicopter.paint_hex("body")=="f1f3f5" and helicopter.paint_hex("trim")=="1e4fa3","Preset recolours the helicopter")
	assert(preview_heli.paint_hex("body")=="f1f3f5","Preview follows the chosen preset")
	assert(paint_pickers.body.color.to_html(false)=="f1f3f5","Pickers follow the chosen preset")
	paint_pickers.trim.color_changed.emit(Color("12ab34"))
	assert(helicopter.paint_hex("trim")=="12ab34" and saved.paint.trim=="12ab34","Custom colour applies and is remembered")
	go_back(false)
	assert(not paint_open and not paint_panel.visible and state=="menu","Back closes the paint shop")
	var cleaned_paint=ProgressStore.clean({"paint":{"body":"ABCDEF","trim":"zzzzzz","dark":42}})
	assert(cleaned_paint.paint=={"body":"abcdef"},"Saved paint keeps only valid colours")
	assert(not ProgressStore.clean({"paint":"red"}).has("paint"),"Malformed paint is dropped")
	set_paint(paint_before)
	# Layout must fit the base viewport without a scrollbar in the hangar menu.
	await get_tree().process_frame
	await get_tree().process_frame
	assert(europe_route_select.visible and not nl_route_select.visible,"Layout check covers the tallest menu variant")
	print("Hangar menu width: %d px" % menu.get_global_rect().size.x)
	assert(menu.get_global_rect().size.x<=640,"Route pickers do not widen the hangar menu past half the screen")
	var screen=get_viewport().get_visible_rect()
	assert(screen.encloses(menu.get_global_rect()),"Hangar menu fits on screen without scrolling")
	assert(menu.get_global_rect().size.y<=screen.size.y-32,"Hangar menu keeps a margin")
	print("Hangar menu height: %d px" % menu.get_global_rect().size.y)
	assert(mode_tiles.size()==3 and mode_tiles[mode_select.selected].selected,"Mode tiles mirror the chosen mode")
	choose_mode(GameMode.PRACTICE)
	assert(mode_select.selected==GameMode.PRACTICE and mode_tiles[1].selected and not mode_tiles[0].selected,"Tapping a tile picks the mode")
	choose_mode(GameMode.LEARN)
	fly_menu_helicopter(1.0)
	assert(helicopter.scale.x>FLIGHT_HELI_SCALE*2,"The hangar shows a big circling helicopter")
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
	open_paint_shop()
	paint_panel.find_child("Scheme_Politie",true,false).pressed.emit()
	await get_tree().create_timer(.6).timeout
	get_viewport().get_texture().get_image().save_png("res://build/preview-paint.png")
	set_paint(RotorHelicopter.DEFAULT_PAINT.duplicate())
	close_paint_shop()
	for city in ["amsterdam","utrecht","rotterdam","den haag","groningen","arnhem","nijmegen","almere","maastricht","zwolle","sneek","haarlem","gouda","delft","leiden","eindhoven","heerlen","den helder","emmen","den bosch","alkmaar","heerenveen"]:
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
	await capture_effects()
	await capture_learning()
	# Shared camera/UI/helicopter changes also get a visual check in Europe.
	load_world("eu")
	start_mission([catalog.lookup.parijs])
	helicopter.position=world.project(2.35,48.85)+Vector3(0,3.3,0)
	await get_tree().create_timer(2).timeout
	get_viewport().get_texture().get_image().save_png("res://build/preview-europe.png")
	rotor_audio.stop()
	feedback_audio.stop()
	await get_tree().process_frame
	for city in ["parijs","londen","rome","stockholm","athene","bern","oslo"]:
		var place: Dictionary=catalog.lookup[city]
		mode_select.select(GameMode.LEARN)
		start_mission([place])
		helicopter.position=world.project(place.lon,place.lat)+Vector3(0,flight_altitude(),0)
		camera_level=0
		camera.size=flight_zoom()
		await get_tree().create_timer(2).timeout
		get_viewport().get_texture().get_image().save_png("res://build/preview-europe-"+city+".png")
	return_menu()
	await get_tree().create_timer(.2).timeout
	get_viewport().get_texture().get_image().save_png("res://build/preview-europe-hangar.png")
	print("VISUAL CHECK PASSED")
	get_tree().quit()

# Effects: answer range, in-zone highlight, fireworks, red cross, summary.
func capture_effects() -> void:
	mode_select.select(GameMode.LEARN)
	start_mission([catalog.lookup.amsterdam,catalog.lookup.utrecht])
	var goal_place: Dictionary=mission[0]
	var goal_center=world.project(goal_place.lon,goal_place.lat)
	var reach=zone_radius_units(goal_place)
	helicopter.position=goal_center+Vector3(reach*1.15,flight_altitude(),reach*1.1)
	update_flight_camera(0.0,true)
	await get_tree().create_timer(1.2).timeout
	get_viewport().get_texture().get_image().save_png("res://build/preview-fx-zone.png")
	helicopter.position=goal_center+Vector3(reach*.35,flight_altitude(),reach*.3)
	await get_tree().create_timer(1.0).timeout
	assert(in_zone,"Capture shows the in-zone highlight")
	get_viewport().get_texture().get_image().save_png("res://build/preview-fx-inzone.png")
	answer()
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png("res://build/preview-fx-fireworks.png")
	await get_tree().create_timer(1.6).timeout
	helicopter.position=world.project(4.75,52.75)+Vector3(0,flight_altitude(),0)
	answer_cooldown=0
	answer()
	await get_tree().create_timer(.42).timeout
	get_viewport().get_texture().get_image().save_png("res://build/preview-fx-miss.png")
	await get_tree().create_timer(1.6).timeout
	var last_place: Dictionary=mission[mission_index]
	helicopter.position=world.project(last_place.lon,last_place.lat)+Vector3(0,flight_altitude(),0)
	answer_cooldown=0
	answer()
	await get_tree().create_timer(1.4).timeout
	assert(state=="summary","Capture reaches the mission summary")
	get_viewport().get_texture().get_image().save_png("res://build/preview-fx-summary.png")
	return_menu()

# Learning aids: the locator card after a hit, the practice direction arrow
# and the heading-up minimap, in the Netherlands and in Europe.
func capture_learning() -> void:
	var previous_region=region
	if region!="nl":
		load_world("nl")
	mode_select.select(GameMode.LEARN)
	seed(7)
	start_mission([catalog.lookup.zwolle,catalog.lookup.assen,catalog.lookup.middelburg])
	for index in 2:
		var found: Dictionary=mission[mission_index]
		helicopter.position=world.project(found.lon,found.lat)+Vector3(0,flight_altitude(),0)
		answer_cooldown=0
		answer()
	locator.time_left=60.0
	await get_tree().create_timer(1.6).timeout
	assert(locator.visible,"Locator card stays up for the screenshot")
	get_viewport().get_texture().get_image().save_png("res://build/preview-learn-locator.png")
	mode_select.select(GameMode.PRACTICE)
	start_mission([catalog.lookup.groningen])
	helicopter.position=world.project(5.6,52.4)+Vector3(0,flight_altitude(),0)
	heading=deg_to_rad(40.0) # nose north-west
	helicopter.rotation.y=heading
	camera_yaw=heading
	minimap.rotate_with_heading=true
	await get_tree().create_timer(1.2).timeout
	assert(minimap.direction_index>=0,"Practice arrow is drawn")
	get_viewport().get_texture().get_image().save_png("res://build/preview-practice-direction.png")
	minimap.toggle_detail()
	await get_tree().create_timer(.4).timeout
	get_viewport().get_texture().get_image().save_png("res://build/preview-minimap-heading-up.png")
	minimap.toggle_detail()
	minimap.rotate_with_heading=false
	load_world("eu")
	mode_select.select(GameMode.LEARN)
	start_mission([catalog.lookup.rome,catalog.lookup.oslo])
	var found_eu: Dictionary=mission[0]
	helicopter.position=world.project(found_eu.lon,found_eu.lat)+Vector3(0,flight_altitude(),0)
	answer_cooldown=0
	answer()
	locator.time_left=60.0
	await get_tree().create_timer(1.6).timeout
	get_viewport().get_texture().get_image().save_png("res://build/preview-learn-locator-europe.png")
	locator.dismiss()
	mode_select.select(GameMode.LEARN)
	return_menu()
	if previous_region!=region:
		load_world(previous_region)

func capture_learning_only() -> void:
	saved.mute=true
	DirAccess.make_dir_recursive_absolute("res://build")
	await capture_learning()
	print("LEARN CAPTURE PASSED")
	get_tree().quit()

func capture_effects_only() -> void:
	saved.mute=true
	DirAccess.make_dir_recursive_absolute("res://build")
	await capture_effects()
	print("FX CAPTURE PASSED")
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
