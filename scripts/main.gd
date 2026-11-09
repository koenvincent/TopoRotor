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
var credits_dialog: AcceptDialog
var online_packs: Array = []
var europe_route_select: OptionButton
var nl_route_select: OptionButton
var mode_select: OptionButton
var mute_button: Button
var calm_button: Button
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
var is_capture_mode: bool = OS.is_debug_build() and (OS.get_cmdline_user_args().has("--capture") or OS.get_cmdline_user_args().has("--capture-fx") or OS.get_cmdline_user_args().has("--capture-learn") or OS.get_cmdline_user_args().has("--capture-ui") or OS.get_cmdline_user_args().has("--capture-hangar") or OS.get_cmdline_user_args().has("--capture-quiz"))
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
var saved: Dictionary = ProgressStore.defaults()
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
# Hangar: tabs with type, colours, accessories and upgrades.
var hangar_pages: Dictionary = {}
var hangar_tabs: Dictionary = {}
var hangar_page: String = "type"
var hangar_rank: Label
var hangar_next: Label
var hangar_progress: ProgressBar
var model_buttons: Dictionary = {}
var scheme_buttons: Dictionary = {}
var accessory_buttons: Dictionary = {}
var upgrade_buttons: Dictionary = {}
# A locked item tapped in the hangar shows on the preview only:
# {"kind": "model"|"scheme"|"accessory"|"upgrade", "id", "level", "item", "name"}.
var hangar_peek: Dictionary = {}
var hangar_peek_note: PanelContainer
var hangar_peek_text: Label
var lock_texture: ImageTexture
var unlock_label: Label
# Ranglijst: local high scores per route and mode.
var board_panel: PanelContainer
var board_backdrop: ColorRect
var board_open: bool = false
var board_mode: int = GameMode.RECORDS
var board_title: Label
var board_rows: VBoxContainer
var board_tabs: Array = []
var board_pilot: Label
var board_switch: Button
# Pilot screen: profiles on this device and the look of the active pilot.
var pilots_panel: PanelContainer
var pilots_backdrop: ColorRect
var pilots_open: bool = false
var pilot_list: VBoxContainer
var pilot_new: LineEdit
var pilot_status: Label
var pilot_delete: Button
var pilot_delete_armed: bool = false
var pilot_unlocks: Label
var pilot_values: Dictionary = {}
# Locked looks stepped to on the pilot screen, per attribute: shown on the
# preview figure only, never worn or saved.
var pilot_trial: Dictionary = {}
var pilot_preview: PilotFigure
var hangar_pilot: PilotFigure
var pilot_button: Button
# Theme screen: provinces, rivers, areas, islands and the European themes.
var themes_panel: PanelContainer
var themes_backdrop: ColorRect
var themes_open: bool = false
var themes_grid: GridContainer
var themes_mode: Label
var homework_panel: PanelContainer
var homework_backdrop: ColorRect
var homework_open: bool = false
var homework_grid: GridContainer
var homework_status: Label
var homework_start: Button
var homework_quiz: Button
var homework_selected: Array = []
# Overhoren: drag the names of the chosen cards onto the numbered dots.
var quiz_panel: PanelContainer
var quiz_backdrop: ColorRect
var quiz_open: bool = false
var quiz_board: QuizBoard
var quiz_tray: QuizBoard.Tray
var quiz_names: HFlowContainer
var quiz_kicker: Label
var quiz_status: Label
var quiz_check: Button
var quiz_retry: Button
var quiz_places: Array = []
var quiz_tray_order: PackedStringArray = PackedStringArray()
var quiz_result: Dictionary = {}
# Save key of the cards under test ("water", "noord+west"); only a first marking counts as the mark.
var quiz_key: String = ""
var quiz_first_try: bool = true
var quiz_best: float = 0.0
# Mission order: an own generator, seeded fresh at start, so every flight
# (Leren, Oefenen and Records) visits the places in a new order.
var order_rng := RandomNumberGenerator.new()
var last_order: PackedStringArray = PackedStringArray()
var board_button: Button
var last_board_key: String = ""
var last_board_place: int = 0
# Records radar: places whose range circle may appear under the helicopter.
var radar_places: Array = []
var radar_active: bool = false
const RADAR_MAX_RINGS = 4
const MOTOR_BOOST = .12
var fx: FlightFx
var hud_fx: HudFx
var sfx: SfxBank
var found_button: Button
var shake: float = 0.0
var in_zone: bool = false
var best_label: Label
var rank_label: Label
var custom_mission: bool = false
var progress_readonly: bool = false
# Dutch notice about progress that is not (or could not be) saved; shown as a pill for a few seconds.
var save_notice: String = ""
var save_notice_label: Label
var save_notice_serial: int = 0

var nl_bounds: Array = TopoWorld.map_bounds("nl")

const SPAWN = Vector2(5.1214,52.0907) # Utrecht (lon, lat)
const INK = Color("0b2530")
const CREAM = Color("fff7e6")
const GOLD = Color("ffc94a")
const TEAL = Color("1d6577")
const MUTED = Color("9fd3d6")
# Text on locked or disabled controls: about 7:1 on the dark faces, still clearly dimmer than live text.
const DIM_INK = Color(CREAM,.7)
const SKY = Color("4fd8ff")
const PANEL = Color(.02,.085,.12,.93)
const PANEL_SOLID = Color(.025,.1,.14,.98)
const EDGE = Color(.31,.85,1.0,.26)
# Leren is green, Oefenen blue, Records red: the colour follows you into the flight.
const MODE_COLORS = [Color("4cd97b"),Color("3cb9ff"),Color("ff5470")]
const BUTTON_TONES = {
	"gold":{"base":Color("ffc94a"),"hover":Color("ffdb7a"),"pressed":Color("f0a92c"),"edge":Color("b8640f"),"ink":Color("0b2530"),"glow":Color(1,.79,.29,.5)},
	"teal":{"base":Color("1d6577"),"hover":Color("27839a"),"pressed":Color("164f5d"),"edge":Color("082a33"),"ink":Color("fff7e6"),"glow":Color(.31,.85,1,.4)},
	"ghost":{"base":Color(1,1,1,.08),"hover":Color(.31,.85,1,.18),"pressed":Color(1,1,1,.04),"edge":Color(0,0,0,.35),"ink":Color("fff7e6"),"glow":Color(.31,.85,1,.3)},
	# Locked items: dim glass and faded text, but still tappable for a preview.
	"locked":{"base":Color(1,1,1,.04),"hover":Color(1,1,1,.09),"pressed":Color(1,1,1,.02),"edge":Color(0,0,0,.3),"ink":Color(1,.97,.9,.7),"glow":Color(1,1,1,.12)},
	# The locked item shown in the preview right now: a faint gold plate.
	"peek":{"base":Color(1,.79,.29,.14),"hover":Color(1,.79,.29,.2),"pressed":Color(1,.79,.29,.08),"edge":Color(.72,.39,.06,.65),"ink":Color("ffdb7a"),"glow":Color(1,.79,.29,.3)},
}
var region_tiles: Array = []
var stars_label: Label
var hud_card_style: StyleBoxFlat
var streak: int = 0
const PHOTO_SIZE = Vector2(1140,640)

func _ready() -> void:
	get_tree().node_added.connect(touch_friendly)
	# Tests and captures need a repeatable order; a real game gets a fresh one every launch.
	if is_test_mode or is_capture_mode:
		order_rng.seed=1206
	else:
		order_rng.randomize()
	if not is_test_mode and not is_capture_mode:
		load_save()
	build_environment()
	helicopter.configure(equipped())
	helicopter.apply_paint(saved.get("paint",{}))
	build_ui()
	show_save_notice(save_notice)
	apply_calm()
	load_world("nl")
	state="menu"
	get_tree().quit_on_go_back=false
	if is_test_mode:
		call_deferred("smoke_test")
	if is_capture_mode:
		var args=OS.get_cmdline_user_args()
		call_deferred("capture_effects_only" if args.has("--capture-fx") else "capture_learning_only" if args.has("--capture-learn") else "capture_ui" if args.has("--capture-ui") else "capture_hangar" if args.has("--capture-hangar") else "capture_quiz" if args.has("--capture-quiz") else "capture_preview")

func build_environment() -> void:
	var env = WorldEnvironment.new()
	var e = Environment.new()
	e.background_mode=Environment.BG_COLOR
	e.background_color=Color("286375")
	e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color=Color("d6e8df")
	e.ambient_light_energy=.65
	# The aircraft's lacquer and glass mirror a soft sky; the map itself is
	# matte, so this only adds shine to the models.
	e.sky=ToyLook.studio_sky()
	e.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
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
	s.corner_detail=10
	return s

# Floating cards: deep glass with a thin neon rim, a soft drop shadow and an
# optional accent bar on the left that marks the most important panel on screen.
func card(color: Color=PANEL,radius: int=20,accent: bool=false,accent_color: Color=GOLD) -> StyleBoxFlat:
	var s=style(color,radius,EDGE,2)
	s.shadow_color=Color(0,0,0,.45)
	s.shadow_size=18
	s.shadow_offset=Vector2(0,8)
	if accent:
		s.border_color=accent_color
		s.border_width_left=6
		s.border_width_top=0
		s.border_width_right=0
		s.border_width_bottom=0
	return s

# Chunky arcade button face: a thick darker lip that flattens when pressed,
# an optional skew for primary actions and a coloured glow on hover.
func face(color: Color,edge: Color,pressed: bool=false,radius: int=14,margin: int=16,skew: float=0.0,glow: Color=Color.TRANSPARENT) -> StyleBoxFlat:
	var s=style(color,radius)
	s.content_margin_left=margin
	s.content_margin_right=margin
	s.content_margin_top=8+(4 if pressed else 0)
	s.content_margin_bottom=8+(0 if pressed else 4)
	s.border_color=edge
	s.border_width_bottom=0 if pressed else 5
	s.border_width_top=3 if pressed else 0
	s.skew=Vector2(skew,0)
	if glow.a>0:
		s.shadow_color=glow
		s.shadow_size=16
		s.shadow_offset=Vector2.ZERO
	else:
		s.shadow_color=Color(0,0,0,.32)
		s.shadow_size=2 if pressed else 6
		s.shadow_offset=Vector2(0,1 if pressed else 4)
	return s

func focus_ring(radius: int=14,skew: float=0.0) -> StyleBoxFlat:
	var s=style(Color.TRANSPARENT,radius,SKY,3)
	s.draw_center=false
	s.skew=Vector2(skew,0)
	s.expand_margin_left=4
	s.expand_margin_right=4
	s.expand_margin_top=4
	s.expand_margin_bottom=4
	return s

func label(text: String,size_px: int=20,color: Color=CREAM) -> Label:
	var l=Label.new()
	l.text=text
	l.add_theme_font_size_override("font_size",size_px)
	l.add_theme_color_override("font_color",color)
	return l

# Small letter-spaced capitals above a section.
func kicker(text: String,color: Color=SKY) -> Label:
	var l=label(text,13,color)
	l.add_theme_font_override("font",UiFonts.spaced("black",2))
	l.add_theme_constant_override("line_spacing",0)
	return l

func button(text: String,action: Callable,gold: bool=false) -> Button:
	var b=Button.new()
	b.text=text
	b.custom_minimum_size.y=52
	b.add_theme_font_size_override("font_size",20)
	style_button(b,gold)
	b.pressed.connect(action)
	add_press_juice(b)
	# Only touch index 0 is emulated as mouse input; handle extra fingers (e.g. while steering) here.
	b.gui_input.connect(func(event: InputEvent):
		if event is InputEventScreenTouch and event.pressed and event.index>0 and not b.disabled:
			b.accept_event()
			action.call()
	)
	return b

# A quick squash on press and a springy release: buttons feel physical.
# Swiping through a list of buttons on a tablet: a finger that lands on a
# button must still scroll the list. A button normally stops the touch, so
# its ScrollContainer never sees the drag; inside a list it passes the touch
# on instead, and the list cancels the tap once the finger really moves.
# The dead zone keeps a slightly wobbly tap a tap.
const SCROLL_DEADZONE = 14

func touch_friendly(node: Node) -> void:
	if node is ScrollContainer:
		(node as ScrollContainer).scroll_deadzone=SCROLL_DEADZONE
	elif node is BaseButton and in_scroll_list(node):
		(node as BaseButton).mouse_filter=Control.MOUSE_FILTER_PASS

static func in_scroll_list(node: Node) -> bool:
	var up=node.get_parent()
	while up!=null:
		if up is ScrollContainer:
			return true
		up=up.get_parent()
	return false

func add_press_juice(b: BaseButton) -> void:
	b.resized.connect(func(): b.pivot_offset=b.size*.5)
	b.button_down.connect(func():
		var t=b.create_tween()
		t.tween_property(b,"scale",Vector2.ONE*.94,.06).set_ease(Tween.EASE_OUT)
	)
	b.button_up.connect(func():
		var t=b.create_tween()
		t.tween_property(b,"scale",Vector2.ONE,.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)

func style_button(b: Control,gold: bool=false,radius: int=14,margin: int=16) -> void:
	tone_button(b,"gold" if gold else "teal",radius,margin)

func tone_button(b: Control,tone: String,radius: int=14,margin: int=16,skew: float=0.0) -> void:
	var t: Dictionary=BUTTON_TONES[tone]
	b.add_theme_stylebox_override("normal",face(t.base,t.edge,false,radius,margin,skew))
	b.add_theme_stylebox_override("hover",face(t.hover,t.edge,false,radius,margin,skew,t.glow))
	b.add_theme_stylebox_override("pressed",face(t.pressed,t.edge,true,radius,margin,skew))
	b.add_theme_stylebox_override("hover_pressed",face(t.pressed,t.edge,true,radius,margin,skew,t.glow))
	b.add_theme_stylebox_override("disabled",face(Color(.1,.2,.24,.7),Color(.04,.12,.15,.7),false,radius,margin,skew))
	b.add_theme_stylebox_override("focus",focus_ring(radius,skew))
	for key in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_hover_pressed_color"]:
		b.add_theme_color_override(key,t.ink)
	b.add_theme_color_override("font_disabled_color",DIM_INK)

# A small padlock drawn in code (the bundled fonts have no lock glyph): a
# shackle over a rounded body with a keyhole, edges smoothed by distance.
func lock_icon() -> Texture2D:
	if lock_texture!=null:
		return lock_texture
	var img=Image.create(16,20,false,Image.FORMAT_RGBA8)
	for y in 20:
		for x in 16:
			var p=Vector2(x+.5,y+.5)
			var q=(p-Vector2(8,14.5)).abs()-Vector2(5.5,3.5)
			var body=Vector2(maxf(q.x,0),maxf(q.y,0)).length()+minf(maxf(q.x,q.y),0)-2.0
			var shackle=absf(p.distance_to(Vector2(8,8))-4.0)-1.3 if p.y<=8 else minf(absf(p.x-4.0),absf(p.x-12.0))-1.3
			var hole=minf(p.distance_to(Vector2(8,13.6))-1.6,maxf(absf(p.x-8)-.75,absf(p.y-15.8)-1.6))
			var shape=maxf(minf(body,shackle),-hole)
			img.set_pixel(x,y,Color(CREAM,.8*clampf(.5-shape,0,1)))
	lock_texture=ImageTexture.create_from_image(img)
	return lock_texture

# Locked hangar buttons stay tappable: a padlock, dim glass and faded text,
# or a gold plate while that item is on the preview stage.
func lock_style(b: Button,open: bool,chosen: bool,peeking: bool) -> void:
	b.icon=null if open else lock_icon()
	if open:
		style_button(b,chosen,12,10)
	else:
		tone_button(b,"peek" if peeking else "locked",12,10)

# Toggle tile/segment: dim glass when off, a solid colour plate when chosen.
func toggle_style(b: Button,color: Color,radius: int=14,skew: float=0.0) -> void:
	var off=face(Color(1,1,1,.06),Color(0,0,0,.3),false,radius,10,skew)
	off.border_color=Color(color,.55)
	off.border_width_left=2
	off.border_width_right=2
	off.border_width_top=2
	off.border_width_bottom=5
	var off_hover=off.duplicate()
	off_hover.bg_color=Color(color,.18)
	off_hover.shadow_color=Color(color,.35)
	off_hover.shadow_size=12
	off_hover.shadow_offset=Vector2.ZERO
	var on=face(color,color.darkened(.45),false,radius,10,skew,Color(color,.45))
	b.add_theme_stylebox_override("normal",off)
	b.add_theme_stylebox_override("hover",off_hover)
	b.add_theme_stylebox_override("pressed",on)
	b.add_theme_stylebox_override("hover_pressed",on)
	b.add_theme_stylebox_override("focus",focus_ring(radius,skew))
	b.add_theme_color_override("font_color",color.lightened(.25))
	b.add_theme_color_override("font_hover_color",CREAM)
	b.add_theme_color_override("font_focus_color",color.lightened(.25))
	b.add_theme_color_override("font_pressed_color",INK)
	b.add_theme_color_override("font_hover_pressed_color",INK)

# One theme for every built-in control, so dropdowns, popups, text fields,
# lists, scrollbars and dialogs match the cards instead of Godot's grey default.
func build_theme() -> Theme:
	var theme=Theme.new()
	theme.default_font=UiFonts.font("bold")
	theme.default_font_size=18
	theme.set_color("font_color","Label",CREAM)
	var teal: Dictionary=BUTTON_TONES.teal
	for type in ["Button","OptionButton"]:
		theme.set_font("font",type,UiFonts.font("black"))
		theme.set_stylebox("normal",type,face(teal.base,teal.edge))
		theme.set_stylebox("hover",type,face(teal.hover,teal.edge,false,14,16,0.0,teal.glow))
		theme.set_stylebox("pressed",type,face(teal.pressed,teal.edge,true))
		theme.set_stylebox("hover_pressed",type,face(teal.pressed,teal.edge,true))
		theme.set_stylebox("disabled",type,face(Color(.1,.2,.24,.7),Color(.04,.12,.15,.7)))
		theme.set_stylebox("focus",type,focus_ring())
		for key in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_hover_pressed_color"]:
			theme.set_color(key,type,CREAM)
		theme.set_color("font_disabled_color",type,DIM_INK)
	# Dropdowns read as fields: dark inset with a gold arrow.
	var field_face=face(Color("0b2a35"),Color("061a21"),false,14,16)
	field_face.border_color=Color(SKY,.35)
	field_face.border_width_left=2
	field_face.border_width_right=2
	field_face.border_width_top=2
	var field_hover=field_face.duplicate()
	field_hover.border_color=SKY
	field_hover.shadow_color=Color(SKY,.3)
	field_hover.shadow_size=12
	field_hover.shadow_offset=Vector2.ZERO
	theme.set_stylebox("normal","OptionButton",field_face)
	theme.set_stylebox("hover","OptionButton",field_hover)
	theme.set_stylebox("pressed","OptionButton",field_hover)
	theme.set_stylebox("hover_pressed","OptionButton",field_hover)
	theme.set_font("font","OptionButton",UiFonts.font("bold"))
	theme.set_color("icon_normal_color","OptionButton",GOLD)
	theme.set_color("icon_hover_color","OptionButton",GOLD)
	theme.set_color("icon_pressed_color","OptionButton",GOLD)
	theme.set_constant("arrow_margin","OptionButton",16)
	var popup=style(Color("08202a"),16,Color(SKY,.4),2)
	popup.content_margin_top=10
	popup.content_margin_bottom=10
	popup.content_margin_left=8
	popup.content_margin_right=8
	popup.shadow_color=Color(0,0,0,.55)
	popup.shadow_size=18
	theme.set_stylebox("panel","PopupMenu",popup)
	var popup_hover=style(Color("1d6577"),10,GOLD,0)
	popup_hover.content_margin_left=10
	popup_hover.content_margin_right=10
	popup_hover.border_width_left=4
	popup_hover.border_color=GOLD
	theme.set_stylebox("hover","PopupMenu",popup_hover)
	theme.set_font("font","PopupMenu",UiFonts.font("bold"))
	theme.set_color("font_color","PopupMenu",CREAM)
	theme.set_color("font_hover_color","PopupMenu",GOLD)
	theme.set_color("font_disabled_color","PopupMenu",DIM_INK)
	theme.set_color("font_accelerator_color","PopupMenu",MUTED)
	theme.set_constant("v_separation","PopupMenu",16)
	theme.set_constant("item_start_padding","PopupMenu",14)
	theme.set_constant("item_end_padding","PopupMenu",14)
	theme.set_font_size("font_size","PopupMenu",18)
	for type in ["LineEdit","TextEdit"]:
		var field=style(Color("071d25"),12,Color(SKY,.3),2)
		field.content_margin_left=12
		field.content_margin_right=12
		field.content_margin_top=8
		field.content_margin_bottom=8
		theme.set_stylebox("normal",type,field)
		var focused=field.duplicate()
		focused.border_color=GOLD
		focused.shadow_color=Color(GOLD,.25)
		focused.shadow_size=10
		theme.set_stylebox("focus",type,focused)
		theme.set_stylebox("read_only",type,field)
		theme.set_color("font_color",type,CREAM)
		theme.set_color("font_placeholder_color",type,Color("7fa7a4"))
		theme.set_color("caret_color",type,GOLD)
		theme.set_color("selection_color",type,Color(1,.79,.29,.35))
	var list=style(Color("071d25"),14,Color(SKY,.3),2)
	list.content_margin_left=6
	list.content_margin_right=6
	list.content_margin_top=6
	list.content_margin_bottom=6
	theme.set_stylebox("panel","ItemList",list)
	theme.set_stylebox("focus","ItemList",StyleBoxEmpty.new())
	var picked=style(Color(1,.79,.29,.22),10,GOLD,2)
	theme.set_stylebox("selected","ItemList",picked)
	theme.set_stylebox("selected_focus","ItemList",picked)
	theme.set_stylebox("hovered","ItemList",style(Color(SKY,.1),10))
	theme.set_color("font_color","ItemList",CREAM)
	theme.set_color("font_selected_color","ItemList",GOLD)
	theme.set_color("font_hovered_color","ItemList",CREAM)
	theme.set_constant("v_separation","ItemList",10)
	# Slim, rounded scrollbars that only show up where content really overflows.
	for type in ["VScrollBar","HScrollBar"]:
		var track=style(Color(1,1,1,.05),5)
		for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]:
			track.set_content_margin(side,3)
		theme.set_stylebox("scroll",type,track)
		theme.set_stylebox("scroll_focus",type,track)
		for state_name in ["grabber","grabber_highlight","grabber_pressed"]:
			var grab=style(Color("3f8c99") if state_name=="grabber" else SKY if state_name=="grabber_highlight" else GOLD,5)
			for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]:
				grab.set_content_margin(side,3)
			theme.set_stylebox(state_name,type,grab)
	var window=card(Color("0a2530"),20)
	window.expand_margin_top=40
	window.content_margin_top=10
	theme.set_stylebox("embedded_border","Window",window)
	theme.set_stylebox("embedded_unfocused_border","Window",window)
	theme.set_color("title_color","Window",GOLD)
	theme.set_font("title_font","Window",UiFonts.font("display"))
	theme.set_font_size("title_font_size","Window",22)
	theme.set_constant("title_height","Window",40)
	theme.set_stylebox("panel","AcceptDialog",StyleBoxEmpty.new())
	theme.set_color("font_color","LinkButton",MUTED)
	theme.set_color("font_hover_color","LinkButton",GOLD)
	theme.set_color("font_pressed_color","LinkButton",GOLD)
	theme.set_color("font_focus_color","LinkButton",GOLD)
	theme.set_color("font_color","CheckBox",CREAM)
	var rule=StyleBoxLine.new()
	rule.color=Color(SKY,.18)
	rule.thickness=2
	theme.set_stylebox("separator","HSeparator",rule)
	theme.set_constant("separation","HSeparator",12)
	theme.set_color("font_color","TooltipLabel",CREAM)
	theme.set_stylebox("panel","TooltipPanel",style(Color("08202a"),10,Color(SKY,.4),1))
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
	# Custom-drawn widgets (minimap, compass) use the fallback font: give them Nunito too.
	ThemeDB.fallback_font=UiFonts.font("bold")
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
	var pause_style=card(PANEL_SOLID,26)
	pause_style.border_width_top=4
	pause_style.border_color=Color(SKY,.45)
	pause_style.content_margin_left=28
	pause_style.content_margin_right=28
	pause_style.content_margin_top=22
	pause_style.content_margin_bottom=24
	pause_panel.add_theme_stylebox_override("panel",pause_style)
	ui.add_child(pause_panel)
	center_panel(pause_panel,Vector2(440,0))
	var pausecol=VBoxContainer.new()
	pausecol.add_theme_constant_override("separation",14)
	pause_panel.add_child(pausecol)
	pausecol.add_child(pill("PAUZE",SKY))
	pausecol.add_child(title("Je missie staat stil.",36))
	var resume=button("VERDER VLIEGEN  ▶",resume_flight,true)
	resume.custom_minimum_size.y=60
	resume.add_theme_font_size_override("font_size",22)
	tone_button(resume,"gold",16,18,.14)
	pausecol.add_child(resume)
	pausecol.add_child(button("Stoppen · terug naar de hangar",return_menu))
	pause_panel.hide()
	build_photo_dialog()
	build_paint_shop()
	build_leaderboard()
	build_themes()
	build_homework()
	build_quiz()
	build_pilots()

# Big game titles: Lilita One with a thick outline and an extruded, warm
# shadow that reads like a sticker on any map colour.
func title(text: String,size_px: int,color: Color=GOLD) -> Label:
	var l=label(text,size_px,color)
	l.add_theme_font_override("font",UiFonts.font("display"))
	l.add_theme_color_override("font_outline_color",Color("06161c"))
	l.add_theme_constant_override("outline_size",maxi(5,size_px/5))
	l.add_theme_color_override("font_shadow_color",Color("7a2e05") if color==GOLD else Color(0,0,0,.55))
	l.add_theme_constant_override("shadow_offset_y",maxi(3,size_px/12))
	l.add_theme_constant_override("shadow_offset_x",0)
	l.add_theme_constant_override("shadow_outline_size",maxi(5,size_px/5))
	return l

func pill(text: String,background: Color,ink: Color=INK,size_px: int=12) -> Label:
	var l=label(text,size_px,ink)
	l.add_theme_font_override("font",UiFonts.spaced("black",2))
	l.add_theme_stylebox_override("normal",chip(background))
	l.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
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
	var menu_style=card(PANEL,28)
	menu_style.content_margin_left=28
	menu_style.content_margin_right=28
	menu_style.content_margin_top=22
	menu_style.content_margin_bottom=20
	menu_style.border_width_top=4
	menu_style.border_color=Color(SKY,.45)
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
	# Brand row: the app icon as logo, then badges, the two-tone name and tagline.
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
	var badges=HBoxContainer.new()
	badges.add_theme_constant_override("separation",6)
	badges.add_child(pill("VLIEGAVONTUUR",GOLD,INK,11))
	# Rank and flight points, next to the badge so the menu keeps its height.
	rank_label=pill("",Color(SKY,.85),INK,11)
	rank_label.name="Rank"
	badges.add_child(rank_label)
	brand_text.add_child(badges)
	var name_row=HBoxContainer.new()
	name_row.add_theme_constant_override("separation",9)
	name_row.add_child(title("Nieks",40,CREAM))
	name_row.add_child(title("TopoRadar",40))
	brand_text.add_child(name_row)
	var intro=label("Vlieg je topografie-huiswerk tegemoet.",15,Color("cfe6e2"))
	intro.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	brand_text.add_child(intro)
	col.add_child(kicker("VLUCHTGEBIED"))
	# Region tiles drive the hidden picker that the rest of the game reads.
	region_select=OptionButton.new()
	region_select.add_item("Nederland · steden en wateren")
	region_select.add_item("Europa · landen, zeeën en hoofdsteden")
	region_select.visible=false
	region_select.item_selected.connect(func(index): load_world("nl" if index==0 else "eu"))
	col.add_child(region_select)
	var tiles=HBoxContainer.new()
	tiles.add_theme_constant_override("separation",10)
	col.add_child(tiles)
	var region_group=ButtonGroup.new()
	region_tiles=[]
	for entry in [["NEDERLAND","steden · water · provincies"],["EUROPA","landen · zeeën · bergen"]]:
		var tile=Button.new()
		tile.toggle_mode=true
		tile.button_group=region_group
		tile.custom_minimum_size=Vector2(0,60)
		tile.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		tile.name="Region_"+entry[0]
		toggle_style(tile,SKY,16)
		var stack=VBoxContainer.new()
		stack.alignment=BoxContainer.ALIGNMENT_CENTER
		stack.add_theme_constant_override("separation",-2)
		stack.mouse_filter=Control.MOUSE_FILTER_IGNORE
		stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var head=title(entry[0],22,CREAM)
		head.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		head.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var sub=label(entry[1],12,MUTED)
		sub.name="Sub"
		sub.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		sub.mouse_filter=Control.MOUSE_FILTER_IGNORE
		stack.add_child(head)
		stack.add_child(sub)
		tile.add_child(stack)
		var index=region_tiles.size()
		tile.pressed.connect(func():
			sfx.play("whoosh",1.2)
			if (index==0)!=(region=="nl"):
				region_select.select(index)
				load_world("nl" if index==0 else "eu")
		)
		add_press_juice(tile)
		tiles.add_child(tile)
		region_tiles.append(tile)
	# Same slot and height as the Europe picker; only one of the two is visible.
	nl_route_select=OptionButton.new()
	for route in catalog.nl_routes:
		nl_route_select.add_item("%s (%d)" % [route.title,route.places.size()])
	nl_route_select.custom_minimum_size.y=48
	nl_route_select.visible=region=="nl"
	nl_route_select.item_selected.connect(func(_index): update_best_label())
	col.add_child(nl_route_select)
	europe_route_select=OptionButton.new()
	for route in catalog.eu_routes:
		europe_route_select.add_item("%s (%d)" % [route.title,route.places.size()])
	europe_route_select.custom_minimum_size.y=48
	europe_route_select.visible=false
	europe_route_select.item_selected.connect(func(_index): update_best_label())
	col.add_child(europe_route_select)
	# Game mode: a colour-coded segmented control over the (hidden) picker.
	mode_select=OptionButton.new()
	mode_select.add_item("Leren · alle aanwijzingen")
	mode_select.add_item("Oefenen · hulp als je dichtbij bent")
	mode_select.add_item("Records · zonder hints, op snelheid")
	mode_select.item_selected.connect(func(_index): update_best_label())
	# The dropdown stays the model for the chosen mode; three tiles drive it.
	mode_select.visible=false
	col.add_child(mode_select)
	var mode_row=HBoxContainer.new()
	mode_row.add_theme_constant_override("separation",8)
	col.add_child(mode_row)
	for entry in [["Leren","alle hints","Leren: namen, afstand en richting in beeld."],["Oefenen","hulp dichtbij","Oefenen: richting en hulp als je dichtbij bent."],["Records","op snelheid","Records: geen hints, op tijd en elke fout kost 10 seconden. De radar toont de cirkel van de stad waar je boven vliegt."]]:
		var tile=MenuWidgets.ModeTile.new(mode_tiles.size(),entry[0],entry[1],entry[2])
		tile.name="Mode_"+entry[0]
		tile.pressed.connect(choose_mode.bind(mode_tiles.size()))
		add_press_juice(tile)
		mode_row.add_child(tile)
		mode_tiles.append(tile)
	refresh_mode_tiles()
	var start=button("START VLIEGMISSIE  ▶",func(): start_mission(),true)
	start.name="Start"
	start.custom_minimum_size.y=66
	start.add_theme_font_size_override("font_size",25)
	tone_button(start,"gold",16,18,.16)
	col.add_child(start)
	var extras=HBoxContainer.new()
	extras.add_theme_constant_override("separation",10)
	col.add_child(extras)
	# Thema's: provinces, rivers, areas and islands as their own practice.
	for entry in [["Huiswerk",open_homework,"Homework"],["Thema's",open_themes,"Themes"],["Online",open_online_content,"Online"],["Foto / lijst",open_photo_dialog,"Photo"]]:
		var b=button(entry[0],entry[1])
		b.name=entry[2]
		b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		b.size_flags_stretch_ratio=1.0
		b.custom_minimum_size=Vector2(0,46)
		b.add_theme_font_size_override("font_size",16)
		b.clip_text=true
		if entry[2]=="Themes":
			b.tooltip_text="Oefen alleen provincies, rivieren en water, gebieden of eilanden."
			tone_button(b,"teal",14,16)
		elif entry[2]=="Homework":
			b.tooltip_text="Kaart A tot en met F uit je werkbladen: vliegen of overhoren, één kaart of meer tegelijk."
			tone_button(b,"teal",14,16)
		elif entry[2]=="Online":
			b.tooltip_text="Online missies"
		elif entry[2]=="Photo":
			b.tooltip_text="Foto of eigen lijst"
		extras.add_child(b)
	var stats=PanelContainer.new()
	var stats_style=style(Color(0,0,0,.28),14,Color(GOLD,.35),2)
	stats_style.content_margin_top=8
	stats_style.content_margin_bottom=8
	stats_style.content_margin_left=14
	stats_style.content_margin_right=14
	stats.add_theme_stylebox_override("panel",stats_style)
	col.add_child(stats)
	var stats_row=HBoxContainer.new()
	stats_row.add_theme_constant_override("separation",10)
	stats.add_child(stats_row)
	var stats_col=VBoxContainer.new()
	stats_col.add_theme_constant_override("separation",0)
	stats_col.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	stats_row.add_child(stats_col)
	stars_label=label("",17,GOLD)
	stars_label.add_theme_font_override("font",UiFonts.font("black"))
	stats_col.add_child(stars_label)
	best_label=label("Klaar voor vertrek, piloot?",15,CREAM)
	best_label.name="Best"
	best_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	stats_col.add_child(best_label)
	# The active pilot: opens profiles and the character editor.
	pilot_button=button("",open_pilots)
	pilot_button.name="Pilots"
	pilot_button.custom_minimum_size=Vector2(120,40)
	pilot_button.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	pilot_button.add_theme_font_size_override("font_size",15)
	pilot_button.clip_text=true
	pilot_button.tooltip_text="Kies je piloot, maak een nieuwe aan of verander hoe je piloot eruitziet."
	tone_button(pilot_button,"ghost",12,10)
	stats_row.add_child(pilot_button)
	board_button=button("Ranglijst",open_leaderboard)
	board_button.custom_minimum_size=Vector2(0,40)
	board_button.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	board_button.add_theme_font_size_override("font_size",15)
	tone_button(board_button,"teal",12,10)
	stats_row.add_child(board_button)
	var footer=HBoxContainer.new()
	footer.add_theme_constant_override("separation",10)
	col.add_child(footer)
	paint_button=button("Hangar en upgrades",open_paint_shop)
	paint_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	paint_button.custom_minimum_size=Vector2(0,40)
	paint_button.add_theme_font_size_override("font_size",15)
	tone_button(paint_button,"ghost",12,12)
	footer.add_child(paint_button)
	mute_button=button("Geluid: uit" if saved.mute else "Geluid: aan",toggle_sound)
	mute_button.custom_minimum_size=Vector2(0,40)
	mute_button.add_theme_font_size_override("font_size",15)
	tone_button(mute_button,"ghost",12,12)
	footer.add_child(mute_button)
	# Same setting as the button under the flight heights: compass and minimap
	# stay north-up, or turn with the helicopter.
	menu_turn_button=button("",toggle_compass_mode)
	menu_turn_button.custom_minimum_size=Vector2(0,40)
	menu_turn_button.add_theme_font_size_override("font_size",15)
	menu_turn_button.tooltip_text="Vast: noord blijft boven. Draait mee: je neus wijst altijd omhoog. Geldt voor kompasrand en minikaart; tijdens het vliegen ook met toets R."
	tone_button(menu_turn_button,"ghost",12,12)
	footer.add_child(menu_turn_button)
	var credits=LinkButton.new()
	credits.text="Bronnen"
	credits.tooltip_text="Bronnen en licenties"
	credits.add_theme_font_size_override("font_size",14)
	credits.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	credits.pressed.connect(show_credits)
	footer.add_child(credits)
	# Reduced motion and flashes; a row of its own keeps the footer (and menu) width as it was.
	calm_button=button("",toggle_calm)
	calm_button.custom_minimum_size=Vector2(0,40)
	calm_button.add_theme_font_size_override("font_size",15)
	calm_button.tooltip_text="Zet schudden, felle flitsen, confetti en pulserende effecten uit. Het goed- of fout-signaal blijft staan."
	tone_button(calm_button,"ghost",12,12)
	col.add_child(calm_button)
	update_calm_button()

# Keeps the region tiles in step with the picker they drive.
func sync_menu_controls() -> void:
	if region_tiles.size()==2:
		region_tiles[0].set_pressed_no_signal(region=="nl")
		region_tiles[1].set_pressed_no_signal(region=="eu")
		for tile in region_tiles:
			var sub: Label=tile.find_child("Sub",true,false)
			sub.add_theme_color_override("font_color",INK if tile.button_pressed else MUTED)

# Panels pop in instead of appearing: a short fade and a slight scale-up.
func reveal(c: Control,delay: float=0.0) -> void:
	if calm_on():
		c.modulate.a=1.0
		c.scale=Vector2.ONE
		return
	c.pivot_offset=c.size*.5
	c.modulate.a=0.0
	c.scale=Vector2.ONE*.96
	var t=c.create_tween().set_parallel(true)
	t.tween_property(c,"modulate:a",1.0,.18).set_delay(delay)
	t.tween_property(c,"scale",Vector2.ONE,.26).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func choose_mode(index: int) -> void:
	mode_select.select(index)
	update_best_label()
	sfx.play("whoosh",1.3)

func refresh_mode_tiles() -> void:
	for tile in mode_tiles:
		tile.selected=tile.mode_index==mode_select.selected

func chip(color: Color) -> StyleBoxFlat:
	var s=style(color,9)
	s.content_margin_left=9
	s.content_margin_right=9
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
	hud_card_style=card(PANEL,18,true,MODE_COLORS[0])
	hud_card_style.content_margin_left=20
	hud_card_style.content_margin_top=10
	hud_card_style.content_margin_bottom=12
	top.add_theme_stylebox_override("panel",hud_card_style)
	top.mouse_filter=Control.MOUSE_FILTER_IGNORE
	hud.add_child(top)
	pin(top,top_left,24,20,464,124)
	var topcol=VBoxContainer.new()
	topcol.add_theme_constant_override("separation",0)
	top.add_child(topcol)
	progress_label=kicker("MISSIE 01 / 12")
	topcol.add_child(progress_label)
	title_label=title("Vlieg naar Utrecht",30)
	title_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.clip_text=true
	topcol.add_child(title_label)
	detail_label=label("",14,Color("cfe6e2"))
	detail_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	detail_label.clip_text=true
	topcol.add_child(detail_label)
	compass=FlightCompass.new()
	hud.add_child(compass)
	pin(compass,Rect2(.5,0,0,0),-150,20,150,66)
	compass.grow_horizontal=Control.GROW_DIRECTION_BOTH
	var pause=button("❚❚  Pauze",pause_flight)
	pause.add_theme_font_size_override("font_size",17)
	tone_button(pause,"ghost",14,14)
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
	height_label=kicker("VLIEGHOOGTE · LAAG")
	height_col.add_child(height_label)
	var height_row=HBoxContainer.new()
	height_row.add_theme_constant_override("separation",8)
	height_col.add_child(height_row)
	lower_button=button("Lager  ▼",func(): change_height(-1))
	higher_button=button("Hoger  ▲",func(): change_height(1))
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
	movement.add_theme_font_override("font",UiFonts.spaced("black",1))
	movement.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	movement.add_theme_color_override("font_outline_color",Color("06161c"))
	movement.add_theme_constant_override("outline_size",5)
	movement.mouse_filter=Control.MOUSE_FILTER_IGNORE
	joystick.add_child(movement)
	pin(movement,Rect2(0,0,1,0),-20,-22,20,-4)
	var actions=VBoxContainer.new()
	actions.add_theme_constant_override("separation",10)
	actions.alignment=BoxContainer.ALIGNMENT_END
	hud.add_child(actions)
	pin(actions,bottom_right,-284,-236,-24,-24)
	found_button=button("HIER IS HET!  ✓",answer,true)
	found_button.custom_minimum_size.y=64
	found_button.add_theme_font_size_override("font_size",24)
	tone_button(found_button,"gold",16,16,.14)
	actions.add_child(found_button)
	hint_button=button("Hint / kaartnamen",toggle_hint)
	hint_button.add_theme_font_size_override("font_size",17)
	actions.add_child(hint_button)
	var overview=button("Overzichtskaart",toggle_overview)
	overview.add_theme_font_size_override("font_size",17)
	actions.add_child(overview)
	var status_panel=PanelContainer.new()
	status_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var status_style=card(Color(.02,.08,.11,.9),16,true,SKY)
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
	var s=card(PANEL,16)
	s.content_margin_left=12
	s.content_margin_right=12
	s.content_margin_top=10
	s.content_margin_bottom=12
	return s

func show_credits() -> AcceptDialog:
	var dialog=AcceptDialog.new()
	dialog.title="Nieks TopoRadar · bronnen en licenties"
	dialog.dialog_text="Grensgegevens: Kadaster NL / PDOK, Bestuurlijke Gebieden 2026.\nCC BY 4.0: https://creativecommons.org/licenses/by/4.0/\nBron: https://api.pdok.nl/kadaster/brk-bestuurlijke-gebieden/ogc/v1\nGebundeld op 7 november 2026; uitgesneden en vereenvoudigd.\n\nLand-, water- en stadscontouren: Natural Earth, public domain.\nDe buurten en gebouwen zijn gestileerde modellen, geen echte stratenkaart.\nEigen code en modellen: MIT. Godot: MIT. Lilita One en Nunito: SIL OFL 1.1. DejaVu: fontlicentie.\nZie THIRD-PARTY.md voor bronverwijzingen en overige licenties."
	ui.add_child(dialog)
	credits_dialog=dialog
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
	stars_label.text="OEFENEN %s     RECORDS %s" % ["★".repeat(practice)+"☆".repeat(3-practice),"★".repeat(records)+"☆".repeat(3-records)]
	best_label.text="Beste tijd op deze route: %.1f sec" % best if best>0 else "Zet je eerste recordtijd neer!"
	rank_label.text="%s · %d PUNTEN" % [HangarCatalog.rank(points()).to_upper(),points()]
	if is_instance_valid(pilot_button):
		pilot_button.text="Piloot: "+pilot_name()
	sync_menu_controls()

# Best times and boards are keyed on the place names of a route. Coordinates only count for a
# player's own points, which have no other identity, so a data fix in places.json keeps old records.
func record_key(places: Array) -> String:
	var key=route_hash(places,false)
	migrate_route_key(route_hash(places,true),key)
	return key

func route_hash(places: Array,with_coordinates: bool) -> String:
	var route: Array=[]
	for place in places:
		route.append([place.name,place.lat,place.lon] if with_coordinates or place.get("kind")=="eigen punt" else [place.name])
	route.sort_custom(func(a,b): return JSON.stringify(a)<JSON.stringify(b))
	return region+"_"+JSON.stringify(route).sha256_text()

# Saves from before name-based keys hold the record and boards of a route under the key that also
# hashed its coordinates. They move to the current key the first time the route is used.
func migrate_route_key(legacy: String,key: String) -> void:
	if legacy==key:
		return
	var records: Variant=saved.get("records")
	if records is Dictionary and records.has(legacy):
		if not records.has(key) or float(records[legacy])<float(records[key]):
			records[key]=records[legacy]
		records.erase(legacy)
	var boards: Variant=saved.get("boards")
	if boards is Dictionary:
		for mode in Leaderboard.MODE_IDS.size():
			var old_board=Leaderboard.key(legacy,mode)
			if not boards.has(old_board):
				continue
			var entries: Array=boards[old_board]
			boards.erase(old_board)
			for entry in entries:
				Leaderboard.add(boards,Leaderboard.key(key,mode),entry)


# A fresh order of the places (Fisher-Yates on order_rng). With three or more
# places it never repeats the previous order or its first place, so a retry
# of the same route visibly starts somewhere else.
func shuffled_order(places: Array) -> Array:
	var list=places.duplicate()
	if list.size()<2:
		return list
	var names=PackedStringArray()
	for _attempt in 8:
		for i in range(list.size()-1,0,-1):
			var j=order_rng.randi_range(0,i)
			var keep=list[i]
			list[i]=list[j]
			list[j]=keep
		names=PackedStringArray(list.map(func(p): return String(p.name)))
		var same_set=last_order.size()==names.size() and Array(last_order).all(func(n): return names.has(n))
		if not same_set or (names!=last_order and (list.size()<3 or names[0]!=last_order[0])):
			break
	last_order=names
	return list

func start_mission(custom: Array = [],as_custom: bool = true) -> void:
	if is_instance_valid(summary):
		summary.queue_free()
	custom_mission=as_custom and not custom.is_empty()
	mission=custom.duplicate() if not custom.is_empty() else selected_presets()
	game_mode=mode_select.selected
	streak=0
	if hud_card_style:
		hud_card_style.border_color=MODE_COLORS[game_mode]
		progress_label.add_theme_color_override("font_color",MODE_COLORS[game_mode])
	sfx.muted=saved.mute
	apply_calm()
	fx.clear_effects()
	hud_fx.clear()
	locator.dismiss()
	shake=0.0
	in_zone=false
	# Every mode flies the places in a new order, so the route cannot be learnt by heart.
	# Record times stay comparable: the record key is the set of places, not their order.
	mission=shuffled_order(mission)
	world.ensure_mission_markers(mission)
	radar_places=build_radar_places() if game_mode==GameMode.RECORDS else []
	radar_active=false
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
	reveal(hud)
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
	var area=area_goal(p)
	minimap.goal_radius=zone_radius_units(p) if not area else 0.0
	fx.set_zone(zone_radius_units(p),not area,cos(deg_to_rad(world.origin.y))/maxf(cos(deg_to_rad(p.lat)),.1))
	in_zone=false
	refresh_mode_hints()
	progress_label.text="%s  ·  MISSIE %02d / %02d" % [MODE_NAMES[game_mode],mission_index+1,mission.size()]
	title_label.text="Vlieg boven de provincie "+LocatorCard.display_name(p) if p.kind=="provincie" else ("Vlieg boven " if area else "Vlieg naar ")+p.name
	status_label.text="Zoek %s. Druk op ‘Hier is het!’ als je er bent." % p.name
	if mission_index==0:
		status_label.text+=" Omhoog vliegt vooruit, links/rechts draait %s." % ["de heli","het vliegtuig","de straaljager"][["heli","vliegtuig","jet"].find(helicopter.kind)]
	goal_mistakes=0
	answer_cooldown=0.0

func _process(delta: float) -> void:
	if paint_open and is_instance_valid(preview_heli):
		preview_heli.rotate_y(delta*.6)
	# The pilot turns slowly to and fro so the back and the face are both seen.
	if pilots_open and is_instance_valid(pilot_preview):
		pilot_preview.rotation.y=PI+sin(Time.get_ticks_msec()*.0008)*.9
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
	update_radar()
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
	var base=10.0 if region=="nl" else 42.0
	# The motor upgrade helps in Leren and Oefenen; Records stays equal for everyone.
	if game_mode==GameMode.RECORDS:
		return base
	return base*(1.0+MOTOR_BOOST*int(equipped().motor))

# Records radar candidates: every place on this map of a kind the mission asks
# for, plus the mission's own places (custom points included). Showing the
# ring of whichever candidate the pilot is over confirms the range without
# telling which candidate is the goal.
func build_radar_places() -> Array:
	var kinds: Array=[]
	for p in mission:
		if not area_goal(p) and not p.kind in kinds:
			kinds.append(p.kind)
	var places: Array=[]
	var names: Dictionary={}
	for p in catalog.places+mission:
		if p.kind in kinds and not names.has(p.name) and (p.get("region",region)==region or p in mission):
			names[p.name]=true
			places.append(p)
	return places

func update_radar() -> void:
	var rings: Array=[]
	if game_mode==GameMode.RECORDS and state=="flight" and not show_overview and mission_index<mission.size():
		var kind: String=mission[mission_index].kind
		var hits: Array=[]
		for p in radar_places:
			if p.kind!=kind:
				continue
			var km=distance_km(p)
			if km<hit_radius_km(p):
				hits.append([km,p])
		hits.sort_custom(func(a,b): return a[0]<b[0])
		for hit in hits.slice(0,RADAR_MAX_RINGS):
			var p: Dictionary=hit[1]
			rings.append({"at":world.project(p.lon,p.lat),"radius":zone_radius_units(p),"stretch":cos(deg_to_rad(world.origin.y))/maxf(cos(deg_to_rad(p.lat)),.1)})
	fx.show_radar(rings)
	var now_active=not rings.is_empty()
	if now_active and not radar_active:
		status_label.text="Radar: je bent binnen de cirkel van %s. Is dit de goede? Druk op ‘Hier is het!’" % RADAR_WORDS.get(mission[mission_index].kind,"een plek")
		sfx.play("star",.55)
	elif radar_active and not now_active and state=="flight":
		status_label.text="Buiten de radarcirkel. Zoek verder."
	radar_active=now_active

const RADAR_WORDS = {"stad":"een stad","water":"een water","eiland":"een eiland","gebied":"een gebied","plek":"een plek","provincie":"een provincie","eigen punt":"een eigen punt"}

# Zone highlight, downwash, rotor pitch and the answer button pulse. The
# "in de zone" state is only computed while the mode already shows the goal,
# so it can never give away a hidden target.
func update_effects(delta: float) -> void:
	fx.view_scale=camera.size/FX_REFERENCE_ZOOM if not show_overview else 1.0
	var speed_fraction=clampf(velocity.length()/flight_speed(),0.0,1.0)
	fx.update_downwash(helicopter.position,camera_level,speed_fraction,not show_overview)
	rotor_audio.pitch_scale=(.94+speed_fraction*.22)*helicopter.sound_pitch()
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
	# Calm mode holds the button at its bright, enlarged pulse peak instead of pulsing.
	var pulse=(1.0 if calm_on() else .5+.5*sin(flight_time*9.0)) if in_zone else 0.0
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

# Overlay registry: every screen or dialog that sits on top of the menu, in
# Back priority (topmost first). The open_* guards and go_back share it, so a
# new overlay is added here and in the two helpers below, nowhere else.
const OVERLAYS = ["credits","content","quiz","board","pilots","themes","homework","paint","photo"]

func overlay_is_open(overlay: String) -> bool:
	match overlay:
		"credits":
			return is_instance_valid(credits_dialog) and credits_dialog.visible
		"content":
			return is_instance_valid(content_dialog) and content_dialog.visible
	return get(overlay+"_open")==true

# Name of the topmost open overlay, or "" when none is open.
func top_overlay() -> String:
	for overlay in OVERLAYS:
		if overlay_is_open(overlay):
			return overlay
	return ""

func close_overlay(overlay: String) -> void:
	match overlay:
		"credits":
			credits_dialog.hide()
			credits_dialog.queue_free()
		"content":
			content_dialog.hide()
		"board":
			close_leaderboard()
		"pilots":
			close_pilots()
		"themes":
			close_themes()
		"homework":
			close_homework()
		"quiz":
			close_quiz()
		"paint":
			close_paint_shop()
		"photo":
			close_photo_dialog()

func go_back(allow_quit: bool) -> void:
	var overlay=top_overlay()
	if not overlay.is_empty():
		close_overlay(overlay)
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

# Countries, and Dutch provinces on the Dutch map, count anywhere inside
# their outline instead of within a circle around one point.
func area_goal(p: Dictionary) -> bool:
	return p.kind=="land" or (is_instance_valid(world) and world.has_province(p))

# Countries without usable map geometry fall back to the catalog reference point.
func at_goal(p: Dictionary) -> bool:
	if p.kind=="land":
		return world.country_contains(p.code,helicopter.position) if world.has_country(p.code) else distance_km(p)<(1.5 if p.code=="VAT" else 25)
	if world.has_province(p):
		return world.province_contains(p,helicopter.position)
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
		fx.celebrate(world.target.position if not area_goal(p) else ground)
		var first_try=goal_mistakes==0
		streak=streak+1 if first_try else 0
		mission_index+=1
		update_goal()
		# The last goal opens the summary, which has its own celebration.
		if state=="flight":
			hud_fx.show_hit(hit_word(first_try),p.name,streak)
			status_label.text="Goed gevonden! Op naar %s." % mission[mission_index].name
			# Leren and Oefenen show where the place lies in the whole country.
			if game_mode!=GameMode.RECORDS:
				locator.present(p,mission.slice(0,mission_index-1))
		answer_cooldown=.6
	else:
		mistakes+=1
		goal_mistakes+=1
		streak=0
		status_label.text="Nog niet op de juiste plek. Kijk nog eens naar de kaart."
		sfx.play("buzzer")
		fx.miss_mark(ground)
		hud_fx.show_miss("MIS!" if goal_mistakes<3 else "NOG NIET!")
		shake=0.0 if calm_on() else 1.0
		answer_cooldown=1.0

# The praise grows with a run of first-try answers.
func hit_word(first_try: bool) -> String:
	if not first_try:
		return "GEVONDEN!"
	if streak>=6:
		return "ONSTUITBAAR!"
	if streak>=4:
		return "TOPPER!"
	if streak>=2:
		return "RAAK!"
	return "GOED ZO!"

func refresh_mode_hints() -> void:
	if mission_index>=mission.size():
		return
	var place: Dictionary=mission[mission_index]
	# Seas and mountain ranges answer from far away; their hint follows that range.
	var nearby=distance_km(place)<maxf(18.0 if region=="nl" else 75.0,hit_radius_km(place))
	if place.kind=="land":
		nearby=world.country_contains(place.code,helicopter.position) if world.has_country(place.code) else distance_km(place)<5.0
	elif world.has_province(place):
		nearby=world.province_contains(place,helicopter.position)
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
	height_label.text="VLIEGHOOGTE · "+HEIGHT_NAMES[camera_level].to_upper()
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
	fx.show_radar([])
	var stars=mission_stars(first_try)
	# Leren shows every hint, so only Oefenen and Records feed the stars on the menu.
	if not custom_mission and game_mode!=GameMode.LEARN:
		var key=region+("_test" if exam else "_oefenen")
		saved.best[key]=max(int(saved.best.get(key,0)),stars)
		save_data()
	var new_record=false
	var score=flight_time+mistakes*10.0
	if game_mode==GameMode.RECORDS:
		var key=record_key(mission)
		if not saved.has("records"):
			saved.records={}
		var previous=float(saved.records.get(key,0.0))
		if previous<=0 or score<previous:
			ProgressStore.remember_record(saved.records,key,score)
			new_record=true
			record_result="Nieuw record: %.1f sec (+%d sec straf)!" % [score,mistakes*10]
			save_data()
		else:
			record_result="Tijd %.1f sec · record %.1f sec" % [score,previous]
	# Flight points, medals and the leaderboard.
	var points_before=points()
	var medals_before: Array=saved.medals.duplicate()
	var earned=HangarCatalog.mission_points(game_mode,completed.size(),first_try,stars,new_record,mission.size())
	saved.points=mini(points_before+earned,HangarCatalog.MAX_POINTS)
	if new_record:
		award_medal("eerste_record")
	if stars==3:
		award_medal("foutloos")
	if region=="eu":
		award_medal("europa")
	var homework_done=record_homework(mission)
	var fresh=HangarCatalog.newly_unlocked(points_before,medals_before,points(),saved.medals)
	last_board_key=Leaderboard.key(record_key(mission),game_mode)
	last_board_place=Leaderboard.add(saved.boards,last_board_key,{"pilot":pilot_name(),"points":earned,"time":snappedf(score if exam else flight_time,.1),"mistakes":mistakes,"date":Time.get_date_string_from_system()})
	save_data()
	summary=PanelContainer.new()
	var summary_style=card(PANEL_SOLID,28)
	summary_style.content_margin_left=32
	summary_style.content_margin_right=32
	summary_style.content_margin_top=24
	summary_style.content_margin_bottom=26
	summary_style.border_width_top=5
	summary_style.border_color=MODE_COLORS[game_mode]
	summary.add_theme_stylebox_override("panel",summary_style)
	ui.add_child(summary)
	center_panel(summary,Vector2(620,0))
	var col=VBoxContainer.new()
	col.add_theme_constant_override("separation",12)
	summary.add_child(col)
	var badges=HBoxContainer.new()
	badges.add_theme_constant_override("separation",8)
	badges.alignment=BoxContainer.ALIGNMENT_CENTER
	badges.add_child(pill("MISSIE VOLTOOID",GOLD))
	badges.add_child(pill(MODE_NAMES[game_mode],MODE_COLORS[game_mode]))
	col.add_child(badges)
	var heading=title("Goed gevlogen, piloot!" if stars>=2 else "Missie gehaald, piloot!",40)
	heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(heading)
	col.add_child(star_row(stars))
	# Three score tiles instead of a sentence.
	var tiles=HBoxContainer.new()
	tiles.add_theme_constant_override("separation",10)
	col.add_child(tiles)
	for entry in [["GEVONDEN",str(completed.size()),Color("4cd97b")],["MIS",str(mistakes),Color("ff5470") if mistakes>0 else MUTED],["VLIEGTIJD","%02d:%02d" % [int(flight_time)/60,int(flight_time)%60],SKY]]:
		var tile=PanelContainer.new()
		tile.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var tile_style=style(Color(0,0,0,.3),14,Color(entry[2],.55),2)
		tile_style.content_margin_top=8
		tile_style.content_margin_bottom=10
		tile.add_theme_stylebox_override("panel",tile_style)
		var stack=VBoxContainer.new()
		stack.add_theme_constant_override("separation",0)
		var caption=kicker(entry[0],entry[2])
		caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		stack.add_child(caption)
		var value=title(entry[1],36,CREAM)
		value.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		stack.add_child(value)
		tile.add_child(stack)
		tiles.add_child(tile)
	if not missed.is_empty():
		var shown=PackedStringArray()
		for entry in missed.slice(0,3):
			shown.append(entry if entry.length()<=40 else entry.left(39)+"…")
		var extra=" … +%d meer" % (missed.size()-shown.size()) if missed.size()>shown.size() else ""
		var missed_label=label("Nog oefenen: "+", ".join(shown)+extra,16,Color("ffd0d6"))
		missed_label.tooltip_text="\n".join(missed)
		missed_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		missed_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(missed_label)
	if not homework_done.is_empty():
		var done_label=label("Huiswerk gevlogen: "+", ".join(homework_done),16,Color("5cff8f"))
		done_label.name="HomeworkDone"
		done_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		done_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(done_label)
	var tip=label(record_result if exam else "Drie sterren: foutloze Records-vlucht. Twee: minstens 80% in één keer goed.",15,GOLD if exam else MUTED)
	tip.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	tip.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(tip)
	var reward="+%d vliegpunten · totaal %d · %s" % [earned,points(),HangarCatalog.rank(points())]
	if last_board_place>0:
		reward+="\nPlek %d op de ranglijst van deze route" % last_board_place
	var reward_label=label(reward,17,GOLD)
	reward_label.add_theme_font_override("font",UiFonts.font("black"))
	reward_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	reward_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(reward_label)
	unlock_label=label("",16,Color("5cff8f"))
	unlock_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	unlock_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	unlock_label.visible=not fresh.is_empty()
	if not fresh.is_empty():
		var shown_names=fresh.slice(0,4)
		unlock_label.text="Nieuw in de hangar: "+", ".join(shown_names)+(" en %d meer" % (fresh.size()-shown_names.size()) if fresh.size()>shown_names.size() else "")
	col.add_child(unlock_label)
	var again=button("NOG EEN KEER  ↻",func(): start_mission(mission,custom_mission),true)
	again.custom_minimum_size.y=60
	again.add_theme_font_size_override("font_size",22)
	tone_button(again,"gold",16,18,.14)
	again.tooltip_text="Dezelfde locaties opnieuw"
	col.add_child(again)
	var after=HBoxContainer.new()
	after.add_theme_constant_override("separation",12)
	col.add_child(after)
	for entry in [["Ranglijst",open_leaderboard],["Terug naar de hangar",return_menu]]:
		var b=button(entry[0],entry[1])
		b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		after.add_child(b)
	summary.resized.connect(func(): summary.pivot_offset=summary.size*.5, CONNECT_ONE_SHOT)
	reveal(summary,.05)
	hud_fx.celebrate()
	# A last volley over the helicopter while the summary pops up.
	fx.celebrate(Vector3(helicopter.position.x,0,helicopter.position.z))

# Stars pop in one by one with a ping per earned star.
func star_row(stars: int) -> HBoxContainer:
	var row=HBoxContainer.new()
	row.alignment=BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation",10)
	for i in 3:
		var star=title("★" if i<stars else "☆",66,GOLD if i<stars else Color("5d7f86"))
		star.resized.connect(func(): star.pivot_offset=star.size*.5)
		star.scale=Vector2.ONE if calm_on() else Vector2.ZERO
		row.add_child(star)
		var tween=star.create_tween()
		tween.tween_interval(.35+i*.28)
		if i<stars:
			tween.tween_callback(func(): sfx.play("star",1.0+i*.12))
		if not calm_on():
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
	reveal(menu)
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

# 'Rustige beelden': no screen shake, full-screen flashes, confetti or pulsing.
# Feedback stays readable through the cross, banner and text.
func calm_on() -> bool:
	return saved.get("calm",false)==true

func apply_calm() -> void:
	if is_instance_valid(hud_fx):
		hud_fx.calm=calm_on()
	if is_instance_valid(fx):
		fx.set_calm(calm_on())
	if calm_on():
		shake=0.0

func update_calm_button() -> void:
	if is_instance_valid(calm_button):
		calm_button.text="Rustige beelden: aan" if calm_on() else "Rustige beelden: uit"

func toggle_calm() -> void:
	saved.calm=not calm_on()
	apply_calm()
	update_calm_button()
	save_data()

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
				show_save_notice("Je voortgang wordt niet bewaard: het oude bestand is onleesbaar en kon niet veiliggesteld worden.")
			else:
				progress_readonly=false
				push_warning("Onleesbare voortgang bewaard als "+backup+".")
				show_save_notice("Je voortgangsbestand was onleesbaar. Je begint opnieuw; het oude bestand is bewaard.")
		else:
			progress_readonly=ProgressStore.is_newer(raw)
		if ProgressStore.is_newer(raw):
			push_warning("Voortgang komt uit een nieuwere app-versie; het bestand wordt niet overschreven.")
			show_save_notice("Je voortgang wordt niet bewaard: het bestand komt uit een nieuwere versie van de app.")
		saved=ProgressStore.clean(raw)
	custom_places=saved.custom

func save_data() -> void:
	if is_capture_mode:
		return
	if progress_readonly:
		show_save_notice(save_notice)
		return
	saved.version=ProgressStore.VERSION
	sync_profile()
	# The old file is only replaced after the new one was written and read back intact.
	var failed=ProgressStore.write_atomic(save_path,JSON.stringify(saved,"\t"))
	if failed.is_empty():
		save_notice=""
		return
	push_warning("Kon de voortgang niet opslaan (%s)." % failed)
	show_save_notice("Opslaan van je voortgang is niet gelukt. Is de opslagruimte vol? Je oude voortgang blijft bewaard.")

# Tells the player, in a short pill, that progress is not (or could not be) saved.
func show_save_notice(text: String) -> void:
	save_notice=text
	if text.is_empty() or not is_instance_valid(ui) or is_capture_mode:
		return
	if not is_instance_valid(save_notice_label):
		save_notice_label=pill("",GOLD,INK,16)
		save_notice_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		save_notice_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		save_notice_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
		save_notice_label.custom_minimum_size=Vector2(620,0)
		save_notice_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP,Control.PRESET_MODE_MINSIZE,14)
		save_notice_label.grow_horizontal=Control.GROW_DIRECTION_BOTH
		ui.add_child(save_notice_label)
	save_notice_label.text=text
	save_notice_label.show()
	save_notice_serial+=1
	var serial=save_notice_serial
	get_tree().create_timer(9.0).timeout.connect(func(): if serial==save_notice_serial and is_instance_valid(save_notice_label): save_notice_label.hide())

# Hangar: a live, slowly turning 3D preview (rendered in its own little world)
# beside four tabs: type, colours, accessories and upgrades. Locked items say
# what they still need. Every choice applies at once to the real helicopter
# and is saved when the hangar closes.
func build_paint_shop() -> void:
	paint_backdrop=ColorRect.new()
	paint_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paint_backdrop.color=Color(.015,.055,.07,.78)
	ui.add_child(paint_backdrop)
	paint_backdrop.hide()
	paint_panel=PanelContainer.new()
	var panel_style=card(PANEL_SOLID,26)
	for side in [SIDE_LEFT,SIDE_RIGHT]:
		panel_style.set_content_margin(side,26)
	for side in [SIDE_TOP,SIDE_BOTTOM]:
		panel_style.set_content_margin(side,18)
	paint_panel.add_theme_stylebox_override("panel",panel_style)
	ui.add_child(paint_panel)
	center_panel(paint_panel,Vector2(1010,0))
	paint_panel.hide()
	var col=VBoxContainer.new()
	col.add_theme_constant_override("separation",10)
	paint_panel.add_child(col)
	col.add_child(kicker("HANGAR · TYPE, KLEUR, ACCESSOIRES EN UPGRADES"))
	col.add_child(title("Jouw toestel",32))
	var row=HBoxContainer.new()
	row.add_theme_constant_override("separation",22)
	col.add_child(row)
	var left=VBoxContainer.new()
	left.add_theme_constant_override("separation",8)
	left.custom_minimum_size.x=330
	row.add_child(left)
	var stage=PanelContainer.new()
	var stage_style=style(Color("0b2228"),18,EDGE)
	for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]:
		stage_style.set_content_margin(side,0)
	stage.add_theme_stylebox_override("panel",stage_style)
	left.add_child(stage)
	var viewport=preview_stage(stage,Vector2(330,280),38,Vector3(0,6.0,11.0),Vector3(0,1.7,0),3.6,true)
	preview_heli=RotorHelicopter.new()
	viewport.add_child(preview_heli)
	preview_heli.rotation.y=-.7
	preview_heli.position.y=2.4
	# The active pilot waits on the pad, in front of the helicopter.
	hangar_pilot=PilotFigure.new()
	hangar_pilot.name="HangarPilot"
	viewport.add_child(hangar_pilot)
	hangar_pilot.position=Vector3(2.5,.05,2.1)
	hangar_pilot.rotation.y=PI-.45
	hangar_pilot.configure(pilot_look())
	# A chip at the bottom of the stage says when a locked item is on show.
	var overlay=VBoxContainer.new()
	overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
	stage.add_child(overlay)
	var spacer=Control.new()
	spacer.size_flags_vertical=Control.SIZE_EXPAND_FILL
	spacer.mouse_filter=Control.MOUSE_FILTER_IGNORE
	overlay.add_child(spacer)
	hangar_peek_note=PanelContainer.new()
	hangar_peek_note.name="PeekNote"
	var chip=style(Color(.015,.055,.07,.86),12,Color(GOLD,.6),2)
	for side in [SIDE_LEFT,SIDE_RIGHT]:
		chip.set_content_margin(side,10)
	for side in [SIDE_TOP,SIDE_BOTTOM]:
		chip.set_content_margin(side,6)
	hangar_peek_note.add_theme_stylebox_override("panel",chip)
	hangar_peek_note.mouse_filter=Control.MOUSE_FILTER_IGNORE
	overlay.add_child(hangar_peek_note)
	var chip_row=HBoxContainer.new()
	chip_row.add_theme_constant_override("separation",8)
	hangar_peek_note.add_child(chip_row)
	var padlock=TextureRect.new()
	padlock.texture=lock_icon()
	padlock.stretch_mode=TextureRect.STRETCH_KEEP_CENTERED
	chip_row.add_child(padlock)
	hangar_peek_text=label("",13,GOLD)
	hangar_peek_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	hangar_peek_text.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	chip_row.add_child(hangar_peek_text)
	hangar_peek_note.hide()
	hangar_rank=label("",19,GOLD)
	left.add_child(hangar_rank)
	hangar_progress=ProgressBar.new()
	hangar_progress.show_percentage=false
	hangar_progress.custom_minimum_size=Vector2(0,14)
	hangar_progress.add_theme_stylebox_override("background",style(Color("0b2228"),7,EDGE))
	hangar_progress.add_theme_stylebox_override("fill",style(GOLD,7))
	left.add_child(hangar_progress)
	hangar_next=label("",14,MUTED)
	hangar_next.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	hangar_next.custom_minimum_size.x=330
	left.add_child(hangar_next)
	var right=VBoxContainer.new()
	right.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation",10)
	row.add_child(right)
	var tabs=HBoxContainer.new()
	tabs.add_theme_constant_override("separation",8)
	right.add_child(tabs)
	for entry in [["type","Type"],["kleuren","Kleuren"],["accessoires","Accessoires"],["upgrades","Upgrades"]]:
		var tab=button(entry[1],show_hangar_page.bind(entry[0]))
		tab.name="Tab_"+entry[0]
		tab.custom_minimum_size=Vector2(0,44)
		tab.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		tab.add_theme_font_size_override("font_size",16)
		tabs.add_child(tab)
		hangar_tabs[entry[0]]=tab
		var page=VBoxContainer.new()
		page.add_theme_constant_override("separation",8)
		page.custom_minimum_size.y=372
		right.add_child(page)
		hangar_pages[entry[0]]=page
	build_type_page(hangar_pages.type)
	build_colour_page(hangar_pages.kleuren)
	build_accessory_page(hangar_pages.accessoires)
	build_upgrade_page(hangar_pages.upgrades)
	var footer=HBoxContainer.new()
	footer.add_theme_constant_override("separation",12)
	col.add_child(footer)
	var reset=button("Fabriekskleuren",func(): set_paint(RotorHelicopter.DEFAULT_PAINT.duplicate()))
	reset.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	footer.add_child(reset)
	var done=button("Klaar · naar de hangar  →",close_paint_shop,true)
	done.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	footer.add_child(done)
	show_hangar_page("type")

# A lit 3D stage for the hangar and pilot previews: a soft glow behind the
# model, a warm key light with shadows, a cool back light that draws bright
# edges, and a pad with a glowing ring (with a helipad H for the aircraft).
func preview_stage(stage: PanelContainer,min_size: Vector2,fov: float,eye: Vector3,target: Vector3,radius: float,helipad: bool) -> SubViewport:
	var glow=TextureRect.new()
	glow.name="StageGlow"
	var shine=GradientTexture2D.new()
	shine.fill=GradientTexture2D.FILL_RADIAL
	shine.fill_from=Vector2(.5,.42)
	shine.fill_to=Vector2(1.0,.42)
	var fade=Gradient.new()
	fade.set_color(0,Color(SKY.r,SKY.g,SKY.b,.3))
	fade.set_color(1,Color(SKY.r,SKY.g,SKY.b,0))
	shine.gradient=fade
	glow.texture=shine
	glow.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode=TextureRect.STRETCH_SCALE
	glow.mouse_filter=Control.MOUSE_FILTER_IGNORE
	stage.add_child(glow)
	var view_box=SubViewportContainer.new()
	view_box.stretch=true
	view_box.custom_minimum_size=min_size
	view_box.mouse_filter=Control.MOUSE_FILTER_IGNORE
	stage.add_child(view_box)
	var viewport=SubViewport.new()
	viewport.own_world_3d=true
	viewport.transparent_bg=true
	viewport.msaa_3d=Viewport.MSAA_4X
	view_box.add_child(viewport)
	var preview_camera=Camera3D.new()
	preview_camera.fov=fov
	preview_camera.position=eye
	# A studio sky lights the model from all sides and shows in the lacquer;
	# the background stays clear so the panel's glow shows through.
	var look=Environment.new()
	look.background_mode=Environment.BG_CLEAR_COLOR
	look.sky=ToyLook.studio_sky()
	look.ambient_light_source=Environment.AMBIENT_SOURCE_SKY
	look.ambient_light_energy=.5
	look.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
	look.adjustment_enabled=true
	look.adjustment_saturation=1.15
	look.adjustment_contrast=1.05
	preview_camera.environment=look
	viewport.add_child(preview_camera)
	preview_camera.look_at(target,Vector3.UP)
	var sun=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-50,-35,0)
	sun.light_color=Color("fff1d8")
	sun.light_energy=1.0
	sun.shadow_enabled=true
	sun.shadow_bias=.04
	sun.shadow_blur=2.5
	sun.directional_shadow_max_distance=40.0
	viewport.add_child(sun)
	# A soft fill from the other side and a cool back light along the edges.
	var fill=DirectionalLight3D.new()
	fill.rotation_degrees=Vector3(-25,60,0)
	fill.light_color=Color("cfe2ff")
	fill.light_energy=.25
	fill.light_specular=.2
	viewport.add_child(fill)
	var back=DirectionalLight3D.new()
	back.rotation_degrees=Vector3(-20,165,0)
	back.light_color=Color("9fe3ff")
	back.light_energy=.45
	viewport.add_child(back)
	var pad=MeshInstance3D.new()
	var pad_mesh=CylinderMesh.new()
	pad_mesh.top_radius=radius
	pad_mesh.bottom_radius=radius*1.04
	pad_mesh.height=radius*.035
	pad_mesh.radial_segments=64
	pad.mesh=pad_mesh
	pad.material_override=ToyLook.material(Color("1d343a"),.55)
	pad.position.y=-pad_mesh.height*.5
	viewport.add_child(pad)
	var lamp=StandardMaterial3D.new()
	lamp.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	lamp.albedo_color=SKY
	var ring=MeshInstance3D.new()
	var ring_mesh=TorusMesh.new()
	ring_mesh.inner_radius=radius*.93
	ring_mesh.outer_radius=radius*.97
	ring_mesh.rings=64
	ring.mesh=ring_mesh
	ring.material_override=lamp
	ring.scale.y=.25
	ring.position.y=.005
	ring.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	viewport.add_child(ring)
	if helipad:
		var paint=StandardMaterial3D.new()
		paint.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		paint.albedo_color=Color(GOLD,.85)
		paint.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		for bar in [[Vector3(-.7,0,0),Vector3(.32,.01,2.2)],[Vector3(.7,0,0),Vector3(.32,.01,2.2)],[Vector3.ZERO,Vector3(1.1,.01,.3)]]:
			var stroke=MeshInstance3D.new()
			stroke.mesh=BoxMesh.new()
			stroke.scale=bar[1]
			stroke.position=bar[0]+Vector3(0,.01,0)
			stroke.material_override=paint
			stroke.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			viewport.add_child(stroke)
	return viewport

func hangar_button(text: String,action: Callable,height: float,font_px: int) -> Button:
	var b=button(text,action)
	b.custom_minimum_size=Vector2(0,height)
	b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size",font_px)
	b.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	style_button(b,false,12,10)
	return b

func hangar_grid(columns: int) -> GridContainer:
	var grid=GridContainer.new()
	grid.columns=columns
	grid.add_theme_constant_override("h_separation",8)
	grid.add_theme_constant_override("v_separation",8)
	return grid

# Helicopters, aeroplanes and jets, each under its own heading in one
# scrolling list so the page keeps the hangar's height.
func build_type_page(page: VBoxContainer) -> void:
	var scroll=ScrollContainer.new()
	scroll.name="TypeScroll"
	scroll.custom_minimum_size.y=366
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var list=VBoxContainer.new()
	list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",8)
	scroll.add_child(list)
	for entry in HangarCatalog.KINDS:
		list.add_child(kicker(entry[1]))
		var grid=hangar_grid(2)
		grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		list.add_child(grid)
		for model in HangarCatalog.models_of(entry[0]):
			var b=hangar_button(model.name,func(): choose_model(model.id),62,15)
			b.name="Model_"+model.id
			grid.add_child(b)
			model_buttons[model.id]=b

func build_colour_page(page: VBoxContainer) -> void:
	page.add_child(kicker("KLEURSCHEMA'S"))
	var scroll=ScrollContainer.new()
	scroll.custom_minimum_size.y=168
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var grid=hangar_grid(4)
	grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	for scheme in HangarCatalog.SCHEMES:
		var swatch=button(scheme.name,func(): choose_scheme(scheme))
		swatch.name="Scheme_"+scheme.name
		swatch.custom_minimum_size=Vector2(0,44)
		swatch.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		swatch.add_theme_font_size_override("font_size",13)
		swatch.clip_text=true
		style_swatch(swatch,scheme,"open")
		grid.add_child(swatch)
		scheme_buttons[scheme.name]=swatch
	page.add_child(kicker("EIGEN KLEUR PER ONDERDEEL"))
	var custom=hangar_grid(4)
	page.add_child(custom)
	for part in RotorHelicopter.PAINT_PARTS:
		var cell=VBoxContainer.new()
		cell.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation",3)
		custom.add_child(cell)
		cell.add_child(label(part[1],13,MUTED))
		var picker=ColorPickerButton.new()
		picker.edit_alpha=false
		picker.custom_minimum_size=Vector2(0,36)
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

# A colour scheme button wears its own colours: full when earned, faded
# behind a padlock when locked, and with a gold rim while it is previewed.
func style_swatch(swatch: Button,scheme: Dictionary,mode: String) -> void:
	var body=Color(scheme.body)
	var trim=Color(scheme.trim)
	var open=mode=="open"
	var ink=(INK if body.get_luminance()>.55 else CREAM) if open else DIM_INK
	for state_name in ["normal","hover","pressed","hover_pressed","disabled"]:
		var face_style=face(body.lightened(.12) if state_name=="hover" else body,trim,state_name.contains("pressed"),12,6)
		face_style.border_width_bottom=0 if state_name.contains("pressed") else 6
		if not open:
			face_style.bg_color=Color(face_style.bg_color,.28)
			face_style.border_color=Color(GOLD,.75) if mode=="peek" else Color(trim,.28)
			if mode=="peek":
				face_style.set_border_width_all(2)
				face_style.border_width_bottom=6
		swatch.add_theme_stylebox_override(state_name,face_style)
	for key in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_hover_pressed_color"]:
		swatch.add_theme_color_override(key,ink)
	swatch.add_theme_color_override("font_disabled_color",DIM_INK)
	swatch.icon=null if open else lock_icon()

func build_accessory_page(page: VBoxContainer) -> void:
	page.add_child(kicker("ACCESSOIRES"))
	var hint=label("Tik om aan of uit te zetten. Ze krijgen de kleur ‘Accessoires’ uit Kleuren.",14,MUTED)
	hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	page.add_child(hint)
	var scroll=ScrollContainer.new()
	scroll.name="AccessoryScroll"
	scroll.custom_minimum_size.y=318
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var grid=hangar_grid(3)
	grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	for item in HangarCatalog.ACCESSORIES:
		var b=hangar_button(item.name,func(): toggle_accessory(item.id),56,14)
		b.name="Accessory_"+item.id
		grid.add_child(b)
		accessory_buttons[item.id]=b

func build_upgrade_page(page: VBoxContainer) -> void:
	page.add_theme_constant_override("separation",6)
	for upgrade in HangarCatalog.UPGRADES:
		page.add_child(label(upgrade.name,18,GOLD))
		var about=label(upgrade.about,13,MUTED)
		about.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		page.add_child(about)
		var levels=HBoxContainer.new()
		levels.add_theme_constant_override("separation",8)
		page.add_child(levels)
		upgrade_buttons[upgrade.id]=[]
		for level in upgrade.levels.size():
			var b=hangar_button(upgrade.levels[level].name,func(): set_upgrade(upgrade.id,level),46,14)
			b.name="Upgrade_%s_%d" % [upgrade.id,level]
			levels.add_child(b)
			upgrade_buttons[upgrade.id].append(b)

func show_hangar_page(id: String) -> void:
	end_peek()
	hangar_page=id
	for key in hangar_pages:
		hangar_pages[key].visible=key==id
		style_button(hangar_tabs[key],key==id,12,10)
	if is_instance_valid(sfx) and paint_open:
		sfx.play("whoosh",1.4)

func points() -> int:
	return int(saved.get("points",0))

func medals() -> Array:
	return saved.get("medals",[])

func award_medal(id: String) -> void:
	if not id in saved.medals:
		saved.medals.append(id)

func pilot_name() -> String:
	var name=Leaderboard.clean_pilot(saved.get("pilot",""))
	return name if not name.is_empty() else ProgressStore.DEFAULT_PILOT

# The active pilot's progress is kept in its profile as well, so switching
# and saving never lose a flight.
func sync_profile() -> void:
	if not saved.has("profiles"):
		saved.profiles={}
	saved.profiles[pilot_name()]=ProgressStore.snapshot(saved)

func pilot_look() -> Dictionary:
	return PilotFigure.effective(saved.get("look",{}),points(),medals())

func is_unlocked(item: Dictionary) -> bool:
	return HangarCatalog.unlocked(item,points(),medals())

# What the helicopter carries now; locked choices fall back to the factory ones.
func equipped() -> Dictionary:
	return HangarCatalog.effective(saved.get("garage",{}),points(),medals())

func apply_garage() -> void:
	var was_scheme=hangar_peek.get("kind","")=="scheme"
	hangar_peek={}
	var garage=equipped()
	helicopter.configure(garage)
	show_on_stage(garage)
	if was_scheme and is_instance_valid(preview_heli) and not preview_heli.paint_materials.is_empty():
		preview_heli.apply_paint(current_paint())
	refresh_hangar()

func show_on_stage(garage: Dictionary) -> void:
	if is_instance_valid(preview_heli):
		preview_heli.configure(garage)
		# Long and wide types need a step back to fit the preview stage.
		preview_heli.scale=Vector3.ONE*float(HangarCatalog.find(HangarCatalog.MODELS,garage.model).get("preview",1.0))

# Tapping a locked item shows it on the preview stage only: the real
# helicopter, the save and the equipped choices stay as they are. Tapping
# the same item again, an earned item, another tab or Klaar ends the peek.
func peek_item(kind: String,id: String,level: int,item: Dictionary,name: String) -> void:
	if hangar_peek.get("kind","")==kind and hangar_peek.get("id","")==id and int(hangar_peek.get("level",-1))==level:
		end_peek()
		return
	var was_scheme=hangar_peek.get("kind","")=="scheme"
	var trial=equipped()
	match kind:
		"model":
			trial.model=id
		"accessory":
			trial.accessories.append(id)
		"upgrade":
			trial[id]=level
	show_on_stage(trial)
	if is_instance_valid(preview_heli) and not preview_heli.paint_materials.is_empty():
		if kind=="scheme":
			preview_heli.apply_paint(HangarCatalog.scheme_paint(item))
		elif was_scheme:
			preview_heli.apply_paint(current_paint())
	hangar_peek={"kind":kind,"id":id,"level":level,"item":item,"name":name}
	if is_instance_valid(sfx):
		sfx.play("whoosh",1.6)
	refresh_hangar()

func end_peek() -> void:
	if hangar_peek.is_empty():
		return
	apply_garage()

func is_peeking(kind: String,id: String,level: int=-1) -> bool:
	return hangar_peek.get("kind","")==kind and hangar_peek.get("id","")==id and int(hangar_peek.get("level",-1))==level

func choose_model(id: String) -> void:
	var model=HangarCatalog.find(HangarCatalog.MODELS,id)
	if not is_unlocked(model):
		if not model.is_empty():
			peek_item("model",id,-1,model,model.name)
		return
	saved.garage.model=id
	sfx.play("whoosh",1.0)
	apply_garage()

func toggle_accessory(id: String) -> void:
	var item=HangarCatalog.find(HangarCatalog.ACCESSORIES,id)
	if not is_unlocked(item):
		if not item.is_empty():
			peek_item("accessory",id,-1,item,item.name)
		return
	if id in saved.garage.accessories:
		saved.garage.accessories.erase(id)
	else:
		saved.garage.accessories.append(id)
	sfx.play("star",1.2)
	apply_garage()

func set_upgrade(id: String,level: int) -> void:
	var upgrade=HangarCatalog.find(HangarCatalog.UPGRADES,id)
	var levels: Array=upgrade.levels
	if level<0 or level>=levels.size():
		return
	if not is_unlocked(levels[level]):
		peek_item("upgrade",id,level,levels[level],"%s %s" % [upgrade.name,levels[level].name])
		return
	saved.garage[id]=level
	sfx.play("star",1.0+level*.15)
	apply_garage()

func choose_scheme(scheme: Dictionary) -> void:
	if is_unlocked(scheme):
		set_paint(HangarCatalog.scheme_paint(scheme))
	else:
		peek_item("scheme",scheme.name,-1,scheme,"kleur "+scheme.name)

# Texts, locks and selection of every hangar control.
func refresh_hangar() -> void:
	if not is_instance_valid(paint_panel):
		return
	var pts=points()
	var garage=equipped()
	hangar_rank.text="%s · %d vliegpunten" % [HangarCatalog.rank(pts),pts]
	var next=HangarCatalog.next_unlock(pts)
	var previous=0
	for item in HangarCatalog.all_items():
		var need=int(item[1].get("points",0))
		if need<=pts and need>previous and not item[1].has("medal"):
			previous=need
	hangar_progress.min_value=previous
	hangar_progress.max_value=next.get("points",pts)
	hangar_progress.value=pts
	hangar_progress.visible=not next.is_empty()
	hangar_next.text=("Volgende: %s bij %d punten (nog %d)." % [next.name,next.points,next.points-pts] if not next.is_empty() else "Alles met punten is verdiend!")+" Punten verdien je met elke missie: meer bij Oefenen en Records, extra voor in één keer goed, sterren en records."
	# Locked items stay tappable so they can be previewed; they never equip.
	for model in HangarCatalog.MODELS:
		var b: Button=model_buttons[model.id]
		var open=is_unlocked(model)
		var peeking=is_peeking("model",model.id)
		b.text=("%s%s\n%s" % [model.name,"  ✓" if garage.model==model.id else "",model.about]) if open else "%s · %s\n%s" % [model.name,"voorproefje" if peeking else "op slot",HangarCatalog.requirement(model,pts)]
		lock_style(b,open,garage.model==model.id,peeking)
	for scheme in HangarCatalog.SCHEMES:
		var swatch: Button=scheme_buttons[scheme.name]
		var open=is_unlocked(scheme)
		swatch.text=scheme.name if open else "%s · %s" % [scheme.name,str(scheme.points) if scheme.has("points") else "medaille"]
		swatch.tooltip_text="" if open else HangarCatalog.requirement(scheme,pts)+". Tik voor een voorproefje."
		style_swatch(swatch,scheme,"open" if open else "peek" if is_peeking("scheme",scheme.name) else "locked")
	for item in HangarCatalog.ACCESSORIES:
		var b: Button=accessory_buttons[item.id]
		var open=is_unlocked(item)
		var on=item.id in garage.accessories
		var peeking=is_peeking("accessory",item.id)
		b.text=("%s\n%s" % [item.name,"aan ✓" if on else "uit"]) if open else "%s · %s\n%s" % [item.name,"voorproefje" if peeking else "op slot",HangarCatalog.requirement(item,pts)]
		lock_style(b,open,on,peeking)
	for upgrade in HangarCatalog.UPGRADES:
		for level in upgrade.levels.size():
			var b: Button=upgrade_buttons[upgrade.id][level]
			var step: Dictionary=upgrade.levels[level]
			var open=is_unlocked(step)
			b.text=step.name if open else "%s · %s" % [step.name,str(step.points) if step.has("points") else "medaille"]
			b.tooltip_text="" if open else HangarCatalog.requirement(step,pts)+". Tik voor een voorproefje."
			lock_style(b,open,int(garage[upgrade.id])==level,is_peeking("upgrade",upgrade.id,level))
	if not is_instance_valid(hangar_peek_note):
		return
	hangar_peek_note.visible=not hangar_peek.is_empty()
	if not hangar_peek.is_empty():
		hangar_peek_text.text="Voorproefje: %s. %s" % [hangar_peek.name,earn_text(hangar_peek.item,pts)]

# What a locked item still needs, as one sentence for the preview notes.
func earn_text(item: Dictionary,pts: int) -> String:
	if item.has("medal"):
		return "Verdien het met de medaille ‘%s’." % String(HangarCatalog.MEDALS.get(item.medal,item.medal)).to_lower()
	return "Nog %d vliegpunten om te verdienen." % maxi(int(item.get("points",0))-pts,0)

func current_paint() -> Dictionary:
	var paint: Dictionary={}
	for part in RotorHelicopter.DEFAULT_PAINT:
		paint[part]=helicopter.paint_hex(part)
	return paint

func set_paint(paint: Dictionary,sync_pickers: bool=true) -> void:
	end_peek()
	helicopter.apply_paint(paint)
	if is_instance_valid(preview_heli) and not preview_heli.paint_materials.is_empty():
		preview_heli.apply_paint(paint)
	saved.paint=current_paint()
	if sync_pickers:
		for part in paint_pickers:
			paint_pickers[part].color=Color(saved.paint[part])

func open_paint_shop() -> void:
	if state!="menu" or not top_overlay().is_empty():
		return
	paint_open=true
	apply_garage()
	set_paint(current_paint())
	hangar_pilot.configure(pilot_look())
	paint_backdrop.show()
	paint_panel.show()

func close_paint_shop() -> void:
	if not paint_open:
		return
	paint_open=false
	end_peek()
	for picker in paint_pickers.values():
		picker.get_popup().hide()
	paint_panel.hide()
	paint_backdrop.hide()
	update_best_label()
	save_data()

# Ranglijst: the ten best flights per route and mode, kept on this device.
func build_leaderboard() -> void:
	board_backdrop=ColorRect.new()
	board_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board_backdrop.color=Color(.015,.055,.07,.78)
	ui.add_child(board_backdrop)
	board_backdrop.hide()
	board_panel=PanelContainer.new()
	var panel_style=card(PANEL_SOLID,26)
	for side in [SIDE_LEFT,SIDE_RIGHT]:
		panel_style.set_content_margin(side,28)
	for side in [SIDE_TOP,SIDE_BOTTOM]:
		panel_style.set_content_margin(side,20)
	board_panel.add_theme_stylebox_override("panel",panel_style)
	ui.add_child(board_panel)
	center_panel(board_panel,Vector2(660,0))
	board_panel.hide()
	var col=VBoxContainer.new()
	col.add_theme_constant_override("separation",10)
	board_panel.add_child(col)
	col.add_child(kicker("RANGLIJST · BESTE VLUCHTEN OP DIT APPARAAT"))
	board_title=title("",26)
	board_title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	board_title.clip_text=true
	col.add_child(board_title)
	var tabs=HBoxContainer.new()
	tabs.add_theme_constant_override("separation",8)
	col.add_child(tabs)
	for mode in 3:
		var tab=button(["Leren","Oefenen","Records"][mode],func(): show_board(mode))
		tab.custom_minimum_size=Vector2(0,42)
		tab.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		tab.add_theme_font_size_override("font_size",16)
		tabs.add_child(tab)
		board_tabs.append(tab)
	var list=PanelContainer.new()
	var list_style=style(Color(.08,.21,.25,.85),14,EDGE)
	for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]:
		list_style.set_content_margin(side,12)
	list.add_theme_stylebox_override("panel",list_style)
	col.add_child(list)
	board_rows=VBoxContainer.new()
	board_rows.add_theme_constant_override("separation",4)
	board_rows.custom_minimum_size.y=300
	list.add_child(board_rows)
	var pilot_row=HBoxContainer.new()
	pilot_row.add_theme_constant_override("separation",10)
	col.add_child(pilot_row)
	# All pilots on this device share the lists; new flights go under the
	# active pilot. Switching opens the pilot screen.
	board_pilot=label("",16,MUTED)
	board_pilot.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	board_pilot.clip_text=true
	pilot_row.add_child(board_pilot)
	var switch_button=button("Andere piloot",func():
		close_leaderboard()
		open_pilots())
	switch_button.name="BoardPilots"
	switch_button.custom_minimum_size=Vector2(170,44)
	switch_button.add_theme_font_size_override("font_size",15)
	tone_button(switch_button,"teal",12,10)
	switch_button.visible=false
	board_switch=switch_button
	pilot_row.add_child(switch_button)
	col.add_child(button("Sluiten",close_leaderboard,true))

func board_route() -> Array:
	return mission if state=="summary" else selected_presets()

func board_route_title() -> String:
	if state=="summary" and custom_mission:
		return "Eigen missie · %d plekken" % mission.size()
	if state=="summary":
		var combined=homework_title(mission)
		if not combined.is_empty():
			return combined
	var picker: OptionButton=europe_route_select if region=="eu" else nl_route_select
	return picker.get_item_text(maxi(picker.selected,0))

func open_leaderboard() -> void:
	if state not in ["menu","summary"] or not top_overlay().is_empty():
		return
	board_open=true
	board_pilot.text="Je vliegt als %s. Alle piloten op dit apparaat staan op dezelfde lijst." % pilot_name()
	# Switching pilots is a hangar action, not something for mid-summary.
	board_switch.visible=state=="menu"
	board_backdrop.move_to_front()
	board_panel.move_to_front()
	board_backdrop.show()
	board_panel.show()
	show_board(game_mode if state=="summary" else mode_select.selected)

func close_leaderboard() -> void:
	if not board_open:
		return
	board_open=false
	board_panel.hide()
	board_backdrop.hide()
	save_data()

func show_board(mode: int) -> void:
	board_mode=mode
	for i in board_tabs.size():
		style_button(board_tabs[i],i==mode,12,10)
	board_title.text=board_route_title()
	for child in board_rows.get_children():
		child.queue_free()
	var key=Leaderboard.key(record_key(board_route()),mode)
	var entries: Array=saved.boards.get(key,[])
	if entries.is_empty():
		var empty=label("Nog geen vluchten bij %s op deze route. Vlieg er een en kom op de lijst!" % ["Leren","Oefenen","Records"][mode],16,MUTED)
		empty.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		board_rows.add_child(empty)
		return
	for i in entries.size():
		var entry: Dictionary=entries[i]
		var mine=key==last_board_key and i+1==last_board_place
		var ink=GOLD if mine or i==0 else CREAM
		var line=HBoxContainer.new()
		line.add_theme_constant_override("separation",12)
		line.name="Entry%d" % (i+1)
		board_rows.add_child(line)
		var place=label("%d." % (i+1),17,ink)
		place.custom_minimum_size.x=36
		line.add_child(place)
		var who=label(entry.pilot if not entry.pilot.is_empty() else ProgressStore.DEFAULT_PILOT,17,ink)
		who.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		who.clip_text=true
		line.add_child(who)
		var score=label("%.1f sec" % entry.time if mode==GameMode.RECORDS else "%d punten" % entry.points,17,ink)
		score.custom_minimum_size.x=120
		score.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
		line.add_child(score)
		var extra="%d fout" % entry.mistakes if mode==GameMode.RECORDS else "%d sec" % int(entry.time)
		var detail=label("%s · %s" % [extra,format_date(entry.date)] if not entry.date.is_empty() else extra,14,MUTED)
		detail.custom_minimum_size.x=150
		detail.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
		line.add_child(detail)

func overlay_panel(width: float) -> Array:
	var backdrop=ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color=Color(.015,.055,.07,.78)
	ui.add_child(backdrop)
	backdrop.hide()
	var panel=PanelContainer.new()
	var panel_style=card(PANEL_SOLID,26)
	for side in [SIDE_LEFT,SIDE_RIGHT]:
		panel_style.set_content_margin(side,26)
	for side in [SIDE_TOP,SIDE_BOTTOM]:
		panel_style.set_content_margin(side,18)
	panel.add_theme_stylebox_override("panel",panel_style)
	ui.add_child(panel)
	center_panel(panel,Vector2(width,0))
	panel.hide()
	var col=VBoxContainer.new()
	col.add_theme_constant_override("separation",10)
	panel.add_child(col)
	return [backdrop,panel,col]

# Thema's: one kind of topography per mission, such as only the provinces.
# A theme is a route in the picker, so best times and the leaderboard work
# the same as for the worksheet routes.
const THEME_ABOUT = {
	"Provincies":"Vlieg boven de provincie: overal binnen de provinciegrens telt.",
	"Rivieren en water":"Rivieren, zeearmen, meren en kanalen.",
	"Gebieden":"Landstreken zoals de Veluwe, de Achterhoek en de Betuwe.",
	"Eilanden":"De Waddeneilanden en de Zeeuwse en Zuid-Hollandse eilanden.",
}

func build_themes() -> void:
	var parts=overlay_panel(640)
	themes_backdrop=parts[0]
	themes_panel=parts[1]
	var col: VBoxContainer=parts[2]
	col.add_child(kicker("THEMA'S · OEFEN ÉÉN SOORT TOPOGRAFIE"))
	col.add_child(title("Wat wil je oefenen?",30))
	themes_mode=label("",15,MUTED)
	themes_mode.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	col.add_child(themes_mode)
	themes_grid=hangar_grid(2)
	col.add_child(themes_grid)
	col.add_child(button("Sluiten",close_themes))

func open_themes() -> void:
	if state!="menu" or not top_overlay().is_empty():
		return
	themes_open=true
	for child in themes_grid.get_children():
		themes_grid.remove_child(child)
		child.queue_free()
	for theme in catalog.themes(region):
		var about: String=THEME_ABOUT.get(theme.theme,"")
		var b=hangar_button("%s · %d\n%s" % [theme.theme,theme.count,about if not about.is_empty() else theme.title],start_theme.bind(theme.index),72,15)
		b.name="Theme_"+String(theme.theme).replace(" ","_")
		themes_grid.add_child(b)
	themes_mode.text="Je vliegt in de modus %s. Een andere modus kies je met de tegels in het menu." % ["Leren","Oefenen","Records"][mode_select.selected]
	themes_backdrop.move_to_front()
	themes_panel.move_to_front()
	themes_backdrop.show()
	themes_panel.show()
	reveal(themes_panel)

func close_themes() -> void:
	if not themes_open:
		return
	themes_open=false
	themes_panel.hide()
	themes_backdrop.hide()

func start_theme(index: int) -> void:
	var picker: OptionButton=europe_route_select if region=="eu" else nl_route_select
	picker.select(index)
	update_best_label()
	close_themes()
	sfx.play("whoosh",1.2)
	start_mission()

# Huiswerk: the worksheet cards Kaart A to F, one tile each. Tap several to
# fly them in one mission (every place comes once), or to overhoren them:
# drag the names onto the dots of a blank map.
func build_homework() -> void:
	var parts=overlay_panel(760)
	homework_backdrop=parts[0]
	homework_panel=parts[1]
	var col: VBoxContainer=parts[2]
	col.add_child(kicker("HUISWERK · KAART A TOT EN MET F"))
	col.add_child(title("Welke kaart moet je leren?",30))
	var hint=label("Tik op één kaart of op meer tegelijk. Vliegen oefent alleen wat op die kaart staat; Overhoren is de toets: sleep de namen naar de stippen. Een ✓ betekent dat je de kaart al hebt gevlogen.",15,MUTED)
	hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	col.add_child(hint)
	homework_grid=hangar_grid(2)
	col.add_child(homework_grid)
	homework_status=label("",15,CREAM)
	homework_status.name="HomeworkStatus"
	homework_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	col.add_child(homework_status)
	var row=HBoxContainer.new()
	row.add_theme_constant_override("separation",10)
	col.add_child(row)
	var all=button("Alles kiezen",func(): select_all_homework(true))
	all.name="HomeworkAll"
	all.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(all)
	var none=button("Niets",func(): select_all_homework(false))
	none.name="HomeworkNone"
	none.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(none)
	var close=button("Sluiten",close_homework)
	close.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(close)
	var go_row=HBoxContainer.new()
	go_row.add_theme_constant_override("separation",10)
	col.add_child(go_row)
	homework_start=button("VLIEGEN  ▶",start_homework,true)
	homework_start.name="HomeworkStart"
	homework_start.custom_minimum_size.y=56
	homework_start.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	homework_start.add_theme_font_size_override("font_size",21)
	tone_button(homework_start,"gold",16,16,.14)
	go_row.add_child(homework_start)
	homework_quiz=button("OVERHOREN  ✎",start_homework_quiz,true)
	homework_quiz.name="HomeworkQuiz"
	homework_quiz.tooltip_text="De toets zonder vliegen: sleep elke naam naar de juiste stip op de kaart."
	homework_quiz.custom_minimum_size.y=56
	homework_quiz.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	homework_quiz.add_theme_font_size_override("font_size",21)
	go_row.add_child(homework_quiz)

# Homework is Dutch topography: from the Europe map it switches to Nederland.
func open_homework() -> void:
	if state!="menu" or not top_overlay().is_empty():
		return
	if region!="nl":
		region_select.select(0)
		load_world("nl")
	homework_open=true
	for child in homework_grid.get_children():
		homework_grid.remove_child(child)
		child.queue_free()
	var done: Array=saved.get("homework",[])
	for item in catalog.homework(region):
		var b=hangar_button("",toggle_homework.bind(item.id),78,15)
		b.name="Homework_"+item.id
		b.set_meta("item",item)
		b.tooltip_text=item.about
		var mark: Variant=saved.get("quiz",{}).get(item.id)
		b.text="%s%s%s\n%s · %d plekken" % [item.name,"  ✓" if item.id in done else "","  · toets "+("%.1f" % float(mark)).replace(".",",") if mark!=null else "",item.subject,item.count]
		homework_grid.add_child(b)
	refresh_homework()
	homework_backdrop.move_to_front()
	homework_panel.move_to_front()
	homework_backdrop.show()
	homework_panel.show()
	reveal(homework_panel)

func close_homework() -> void:
	if not homework_open:
		return
	homework_open=false
	homework_panel.hide()
	homework_backdrop.hide()

func toggle_homework(id: String) -> void:
	if id in homework_selected:
		homework_selected.erase(id)
	else:
		homework_selected.append(id)
	sfx.play("star",1.1+homework_selected.size()*.06)
	refresh_homework()

func select_all_homework(on: bool) -> void:
	homework_selected=[]
	if on:
		for item in catalog.homework("nl"):
			homework_selected.append(item.id)
	sfx.play("whoosh",1.2)
	refresh_homework()

func chosen_homework() -> Array:
	return catalog.homework("nl").filter(func(item): return item.id in homework_selected)

func refresh_homework() -> void:
	var chosen=chosen_homework()
	for b in homework_grid.get_children():
		style_button(b,b.get_meta("item").id in homework_selected,12,10)
	var places=TopoCatalog.merge_places(chosen.map(func(item): return item.places))
	homework_start.disabled=chosen.is_empty()
	homework_quiz.disabled=chosen.is_empty()
	homework_start.text="VLIEGEN  ▶" if chosen.size()<=1 else "VLIEG %d KAARTEN  ▶" % chosen.size()
	var mode="Je vliegt in de modus %s." % ["Leren","Oefenen","Records"][mode_select.selected]
	if chosen.is_empty():
		homework_status.text="Nog niets gekozen. "+mode
	elif chosen.size()==1:
		homework_status.text="%s · %s · %d plekken. %s" % [chosen[0].name,chosen[0].subject,places.size(),mode]
	else:
		homework_status.text="%d kaarten samen · %d plekken (dubbele plekken één keer). %s" % [chosen.size(),places.size(),mode]

# One assignment is just its route in the picker, so best times and the
# leaderboard match. Several fly as one merged mission.
func start_homework() -> void:
	var chosen=chosen_homework()
	if chosen.is_empty():
		return
	close_homework()
	sfx.play("whoosh",1.2)
	if chosen.size()==1:
		nl_route_select.select(chosen[0].index)
		update_best_label()
		start_mission()
	else:
		start_mission(TopoCatalog.merge_places(chosen.map(func(item): return item.places)),false)

# Overhoren: a full-screen test on the chosen cards. The map with numbered dots
# fills the left, the names to place sit on the right. No helicopter, no hints.
func build_quiz() -> void:
	quiz_backdrop=ColorRect.new()
	quiz_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	quiz_backdrop.color=Color(.015,.055,.07,.96)
	ui.add_child(quiz_backdrop)
	quiz_backdrop.hide()
	quiz_panel=PanelContainer.new()
	quiz_panel.name="QuizPanel"
	var panel_style=card(PANEL_SOLID,22)
	for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]:
		panel_style.set_content_margin(side,14)
	quiz_panel.add_theme_stylebox_override("panel",panel_style)
	ui.add_child(quiz_panel)
	pin(quiz_panel,Rect2(0,0,1,1),12,12,-12,-12)
	quiz_panel.hide()
	var row=HBoxContainer.new()
	row.add_theme_constant_override("separation",14)
	quiz_panel.add_child(row)
	quiz_board=QuizBoard.new()
	quiz_board.name="QuizBoard"
	quiz_board.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	quiz_board.size_flags_vertical=Control.SIZE_EXPAND_FILL
	quiz_board.changed.connect(refresh_quiz)
	row.add_child(quiz_board)
	var side=VBoxContainer.new()
	side.custom_minimum_size.x=350
	side.add_theme_constant_override("separation",8)
	row.add_child(side)
	quiz_kicker=kicker("OVERHOREN")
	side.add_child(quiz_kicker)
	side.add_child(title("Sleep de namen naar de stippen",24))
	quiz_status=label("",15,CREAM)
	quiz_status.name="QuizStatus"
	quiz_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	side.add_child(quiz_status)
	quiz_tray=QuizBoard.Tray.new()
	quiz_tray.board=quiz_board
	quiz_board.tray=quiz_tray
	quiz_board.float_layer=ui
	quiz_tray.size_flags_vertical=Control.SIZE_EXPAND_FILL
	var tray_style=style(Color(.02,.07,.1,.9),14,EDGE)
	for tray_side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]:
		tray_style.set_content_margin(tray_side,8)
	quiz_tray.add_theme_stylebox_override("panel",tray_style)
	side.add_child(quiz_tray)
	var scroll=ScrollContainer.new()
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	quiz_tray.add_child(scroll)
	quiz_names=HFlowContainer.new()
	quiz_names.name="QuizNames"
	quiz_names.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	quiz_names.add_theme_constant_override("h_separation",6)
	quiz_names.add_theme_constant_override("v_separation",6)
	scroll.add_child(quiz_names)
	quiz_check=button("NAKIJKEN  ✓",check_quiz,true)
	quiz_check.name="QuizCheck"
	quiz_check.custom_minimum_size.y=54
	tone_button(quiz_check,"gold",16,16,.14)
	side.add_child(quiz_check)
	var buttons=HBoxContainer.new()
	buttons.add_theme_constant_override("separation",8)
	side.add_child(buttons)
	quiz_retry=button("Fouten over",retry_quiz)
	quiz_retry.name="QuizRetry"
	quiz_retry.tooltip_text="Wat goed was blijft staan; de rest sleep je opnieuw."
	var again=button("Nieuwe toets",new_quiz_round)
	again.name="QuizAgain"
	var stop=button("Stoppen",close_quiz)
	for b in [quiz_retry,again,stop]:
		b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size",16)
		b.custom_minimum_size.y=46
		buttons.add_child(b)

func start_homework_quiz() -> void:
	var chosen=chosen_homework()
	if chosen.is_empty():
		return
	close_homework()
	var ids: Array=chosen.map(func(item): return String(item.id))
	ids.sort()
	quiz_key="+".join(ids)
	open_quiz(TopoCatalog.merge_places(chosen.map(func(item): return item.places)),"OVERHOREN · "+" + ".join(chosen.map(func(item): return String(item.name).to_upper())))

func open_quiz(places: Array,heading: String) -> void:
	if state!="menu" or places.is_empty() or region!="nl":
		return
	quiz_places=places.duplicate()
	quiz_kicker.text=heading
	quiz_open=true
	new_quiz_round()
	quiz_backdrop.move_to_front()
	quiz_panel.move_to_front()
	quiz_backdrop.show()
	quiz_panel.show()
	reveal(quiz_panel)
	# The test covers the whole screen: the 3D world behind it would only cost frames, so it pauses.
	get_viewport().disable_3d=true
	sfx.play("whoosh",1.1)

func close_quiz() -> void:
	if not quiz_open:
		return
	quiz_open=false
	quiz_board.cancel_drag()
	quiz_panel.hide()
	quiz_backdrop.hide()
	get_viewport().disable_3d=false

# New numbering and a new order of the names: the test cannot be done from memory of the last one.
func new_quiz_round() -> void:
	quiz_result={}
	quiz_first_try=true
	quiz_board.setup(world,shuffled_order(quiz_places))
	shuffle_quiz_tray()
	refresh_quiz()

func shuffle_quiz_tray() -> void:
	quiz_tray_order=PackedStringArray(shuffled_order(quiz_places).map(func(p): return String(p.name)))

func check_quiz() -> void:
	if quiz_board.checked:
		return
	quiz_result=quiz_board.grade()
	# Only the first marking of a test is its mark: after Fouten over the right answers are already given.
	if quiz_first_try and not quiz_key.is_empty():
		if not saved.get("quiz") is Dictionary:
			saved.quiz={}
		var mark=1.0+9.0*float(quiz_result.right)/float(maxi(1,quiz_result.total))
		var before=float(saved.quiz.get(quiz_key,0.0))
		quiz_best=ProgressStore.remember_quiz(saved.quiz,quiz_key,mark)
		quiz_result.record=quiz_best>before
		save_data()
	quiz_first_try=false
	sfx.play("fanfare" if quiz_result.right==quiz_result.total else "chime" if quiz_result.right*10>=quiz_result.total*6 else "buzzer")
	refresh_quiz()

func retry_quiz() -> void:
	if not quiz_board.checked:
		return
	quiz_board.retry_wrong()
	quiz_result={}
	quiz_first_try=false
	shuffle_quiz_tray()
	refresh_quiz()

# School mark from 1 to 10 for right answers out of total, with a decimal comma.
static func quiz_mark(right: int,total: int) -> String:
	if total<=0:
		return "1,0"
	return ("%.1f" % (1.0+9.0*float(right)/float(total))).replace(".",",")

func refresh_quiz() -> void:
	if not is_instance_valid(quiz_board):
		return
	for child in quiz_names.get_children():
		quiz_names.remove_child(child)
		child.queue_free()
	var left=quiz_board.names_left()
	if not quiz_board.checked:
		for name_text in quiz_tray_order:
			if left.has(name_text):
				var chip=QuizBoard.NameChip.new(quiz_board,name_text)
				quiz_names.add_child(chip)
	var total=quiz_board.places.size()
	if quiz_board.checked:
		var right=int(quiz_result.get("right",0))
		var best_text=""
		if quiz_result.has("record"):
			best_text=" Nieuw beste cijfer!" if quiz_result.record else " Je beste cijfer is %s." % ("%.1f" % quiz_best).replace(".",",")
		else:
			best_text=" Na Fouten over telt het cijfer niet mee."
		quiz_status.text="%d van %d goed · cijfer %s.%s %s" % [right,total,quiz_mark(right,total),best_text,"Alles goed, knap!" if right==total else "Rood is fout: de gouden naam is het goede antwoord."]
	else:
		var fixed=quiz_board.locked.count(true)
		var hint="Sleep een naam naar een stip, of tik een naam en daarna de stip. Zoom in met twee vingers, het scrollwiel of +."
		if not quiz_board.selected_name.is_empty():
			hint="Tik nu op de stip van %s." % quiz_board.selected_name
		quiz_status.text="%d van %d geplaatst%s. %s" % [quiz_board.placed_count(),total," (%d al goed)" % fixed if fixed>0 else "",hint]
	quiz_check.disabled=quiz_board.checked
	quiz_retry.disabled=not quiz_board.checked or int(quiz_result.get("right",0))==total

# "Huiswerk · A + B" when a mission is exactly some homework assignments.
func homework_title(places: Array) -> String:
	if region!="nl":
		return ""
	var covered=catalog.homework_covered(region,places)
	if covered.size()<2 or TopoCatalog.merge_places(covered.map(func(item): return item.places)).size()!=places.size():
		return ""
	return "Huiswerk · "+" + ".join(covered.map(func(item): return item.name))

# Marks the assignments a finished mission covered and awards the homework
# medals. Returns the names flown, for the summary.
func record_homework(places: Array) -> PackedStringArray:
	var names=PackedStringArray()
	if region!="nl":
		return names
	var covered=catalog.homework_covered(region,places)
	if not saved.has("homework"):
		saved.homework=[]
	for item in covered:
		names.append(item.name)
		if not item.id in saved.homework:
			saved.homework.append(item.id)
	if covered.size()>=2:
		award_medal("combi")
	if catalog.homework(region).all(func(item): return item.id in saved.homework):
		award_medal("huiswerk")
	return names

# Pilots: every player on this device gets a profile with its own points,
# hangar and look. The leaderboard is shared, so they compete on one list.
const LOOK_COLOURS = ["huid","haarkleur","kleur"]

func build_pilots() -> void:
	var parts=overlay_panel(1010)
	pilots_backdrop=parts[0]
	pilots_panel=parts[1]
	var col: VBoxContainer=parts[2]
	col.add_child(kicker("PILOTEN · IEDER EEN EIGEN PROFIEL, SAMEN OP DE RANGLIJST"))
	col.add_child(title("Jouw piloot",32))
	var row=HBoxContainer.new()
	row.add_theme_constant_override("separation",22)
	col.add_child(row)
	var left=VBoxContainer.new()
	left.add_theme_constant_override("separation",8)
	left.custom_minimum_size.x=340
	row.add_child(left)
	var stage=PanelContainer.new()
	var stage_style=style(Color("0b2228"),18,EDGE)
	for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]:
		stage_style.set_content_margin(side,0)
	stage.add_theme_stylebox_override("panel",stage_style)
	left.add_child(stage)
	var viewport=preview_stage(stage,Vector2(340,190),30,Vector3(0,1.7,5.2),Vector3(0,1.25,0),1.1,false)
	pilot_preview=PilotFigure.new()
	pilot_preview.name="PilotPreview"
	viewport.add_child(pilot_preview)
	pilot_preview.rotation.y=PI
	left.add_child(kicker("WIE VLIEGT ER?"))
	var scroll=ScrollContainer.new()
	scroll.custom_minimum_size.y=132
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	pilot_list=VBoxContainer.new()
	pilot_list.add_theme_constant_override("separation",6)
	pilot_list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scroll.add_child(pilot_list)
	var add_row=HBoxContainer.new()
	add_row.add_theme_constant_override("separation",8)
	left.add_child(add_row)
	pilot_new=LineEdit.new()
	pilot_new.name="NewPilot"
	pilot_new.max_length=Leaderboard.MAX_PILOT
	pilot_new.custom_minimum_size=Vector2(0,44)
	pilot_new.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	pilot_new.placeholder_text="Naam nieuwe piloot"
	pilot_new.text_submitted.connect(func(_text): add_pilot())
	add_row.add_child(pilot_new)
	var add=button("Nieuw",add_pilot)
	add.name="AddPilot"
	add.custom_minimum_size=Vector2(78,44)
	add.add_theme_font_size_override("font_size",15)
	tone_button(add,"teal",12,10)
	add_row.add_child(add)
	pilot_delete=button("Verwijder",delete_pilot)
	pilot_delete.name="DeletePilot"
	pilot_delete.custom_minimum_size=Vector2(96,44)
	pilot_delete.add_theme_font_size_override("font_size",14)
	pilot_delete.clip_text=true
	tone_button(pilot_delete,"ghost",12,10)
	add_row.add_child(pilot_delete)
	pilot_status=label("",14,MUTED)
	pilot_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	pilot_status.custom_minimum_size.x=340
	left.add_child(pilot_status)
	var right=VBoxContainer.new()
	right.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation",6)
	row.add_child(right)
	right.add_child(kicker("ZO ZIET JE PILOOT ERUIT"))
	# Two columns of steppers keep the screen within a 720 px phone height.
	var looks=hangar_grid(2)
	looks.add_theme_constant_override("h_separation",16)
	looks.add_theme_constant_override("v_separation",4)
	right.add_child(looks)
	for entry in PilotFigure.ATTRIBUTES:
		var attribute: String=entry[0]
		var cell=VBoxContainer.new()
		cell.add_theme_constant_override("separation",0)
		cell.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		looks.add_child(cell)
		# The caption shows how many options of this part are earned.
		var caption=HBoxContainer.new()
		cell.add_child(caption)
		var caption_text=label(entry[1],13,MUTED)
		caption_text.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		caption.add_child(caption_text)
		var count=label("",12,Color(GOLD,.8))
		count.name="Count_"+attribute
		caption.add_child(count)
		var line=HBoxContainer.new()
		line.add_theme_constant_override("separation",6)
		cell.add_child(line)
		var back=button("◀",step_look.bind(attribute,-1))
		back.name="Prev_"+attribute
		back.custom_minimum_size=Vector2(44,38)
		tone_button(back,"ghost",10,6)
		line.add_child(back)
		var swatch: ColorRect=null
		if attribute in LOOK_COLOURS:
			swatch=ColorRect.new()
			swatch.custom_minimum_size=Vector2(22,22)
			swatch.size_flags_vertical=Control.SIZE_SHRINK_CENTER
			line.add_child(swatch)
		# A locked look can be stepped to and tried on the preview; it then
		# shows a padlock and faded text and is not worn.
		var padlock=TextureRect.new()
		padlock.name="Lock_"+attribute
		padlock.texture=lock_icon()
		padlock.stretch_mode=TextureRect.STRETCH_KEEP_CENTERED
		padlock.size_flags_vertical=Control.SIZE_SHRINK_CENTER
		padlock.hide()
		line.add_child(padlock)
		var value=label("",15,CREAM)
		value.name="Value_"+attribute
		value.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		value.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		value.clip_text=true
		line.add_child(value)
		var next=button("▶",step_look.bind(attribute,1))
		next.name="Next_"+attribute
		next.custom_minimum_size=Vector2(44,38)
		tone_button(next,"ghost",10,6)
		line.add_child(next)
		pilot_values[attribute]={"label":value,"swatch":swatch,"count":count,"lock":padlock}
	# New looks are earned with flight points and medals, like the hangar.
	pilot_unlocks=label("",13,GOLD)
	pilot_unlocks.name="PilotUnlocks"
	pilot_unlocks.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	right.add_child(pilot_unlocks)
	var footer=HBoxContainer.new()
	footer.add_theme_constant_override("separation",12)
	col.add_child(footer)
	var surprise=button("Verras me · alles tegelijk",random_look)
	surprise.name="RandomLook"
	surprise.custom_minimum_size=Vector2(0,50)
	surprise.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	tone_button(surprise,"teal",12,10)
	footer.add_child(surprise)
	var done=button("Klaar · naar de hangar  →",close_pilots,true)
	done.custom_minimum_size.y=50
	done.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	done.size_flags_stretch_ratio=1.4
	footer.add_child(done)

func open_pilots() -> void:
	if state!="menu" or not top_overlay().is_empty():
		return
	pilots_open=true
	pilot_delete_armed=false
	pilot_trial.clear()
	pilot_status.text="Elke piloot heeft eigen punten, hangar en sterren. De ranglijst is van iedereen samen."
	refresh_pilots()
	pilots_backdrop.move_to_front()
	pilots_panel.move_to_front()
	pilots_backdrop.show()
	pilots_panel.show()
	reveal(pilots_panel)

func close_pilots() -> void:
	if not pilots_open:
		return
	pilots_open=false
	pilot_trial.clear()
	pilot_new.release_focus()
	pilots_panel.hide()
	pilots_backdrop.hide()
	save_data()
	update_best_label()

func refresh_pilots() -> void:
	if not is_instance_valid(pilot_list):
		return
	for child in pilot_list.get_children():
		pilot_list.remove_child(child)
		child.queue_free()
	var active=pilot_name()
	for name in ProgressStore.profile_names(saved):
		var profile: Dictionary=saved.profiles[name]
		var pts=int(profile.get("points",0)) if name!=active else points()
		var b=hangar_button("%s%s · %s · %d punten" % [name,"  ✓" if name==active else "",HangarCatalog.rank(pts),pts],choose_pilot.bind(name),40,15)
		b.name="Pilot_"+name
		b.autowrap_mode=TextServer.AUTOWRAP_OFF
		b.clip_text=true
		style_button(b,name==active,12,10)
		pilot_list.add_child(b)
	pilot_delete.disabled=saved.profiles.size()<=1
	pilot_delete.text="Zeker?" if pilot_delete_armed else "Verwijder"
	pilot_delete.tooltip_text="Verwijdert %s en de eigen punten en hangar. Vluchten op de ranglijst blijven staan." % active
	var look=pilot_look()
	# The preview shows the worn look with any locked look being tried on.
	var shown=look.duplicate()
	var tried: Array=[]
	for attribute in pilot_trial:
		shown[attribute]=pilot_trial[attribute]
	for attribute in pilot_values:
		var cell: Dictionary=pilot_values[attribute]
		var open=PilotFigure.open_ids(attribute,points(),medals())
		var trying=pilot_trial.has(attribute)
		var option=PilotFigure.find_option(attribute,shown[attribute])
		cell.label.text=PilotFigure.option_name(attribute,shown[attribute])+(" · %s" % (str(option[2].points) if option[2].has("points") else "medaille") if trying else "")
		cell.label.add_theme_color_override("font_color",DIM_INK if trying else CREAM)
		cell.label.tooltip_text="%d van %d vrijgespeeld" % [open.size(),PilotFigure.options(attribute).size()]
		cell.lock.visible=trying
		cell.count.text="%d/%d" % [open.size(),PilotFigure.options(attribute).size()]
		if cell.swatch!=null:
			cell.swatch.color=Color(shown[attribute])
		if trying:
			var part_name=""
			for entry in PilotFigure.ATTRIBUTES:
				if entry[0]==attribute:
					part_name=String(entry[1]).to_lower()
			var need=earn_text(option[2],points()).trim_suffix(".")
			tried.append("%s (%s): %s" % [option[1],part_name,need[0].to_lower()+need.substr(1)])
	var left=PilotFigure.locked_count(points(),medals())
	var next=next_look_unlock()
	pilot_unlocks.text=("Nog %d looks op slot. Volgende: %s bij %d punten (nog %d)." % [left,next.name,next.points,next.points-points()] if not next.is_empty() else "Nog %d looks op slot, die verdien je met medailles." % left) if left>0 else "Alle looks zijn vrijgespeeld!"
	if not tried.is_empty():
		pilot_unlocks.text="Voorproefje · "+"; ".join(tried)+". Wat op slot zit draag je pas als je het verdiend hebt."
	pilot_preview.configure(shown)
	if is_instance_valid(hangar_pilot):
		hangar_pilot.configure(look)

# Puts the active profile on the helicopter, hangar and menu.
func apply_profile() -> void:
	pilot_trial.clear()
	helicopter.apply_paint(saved.get("paint",RotorHelicopter.DEFAULT_PAINT))
	if is_instance_valid(preview_heli) and not preview_heli.paint_materials.is_empty():
		preview_heli.apply_paint(saved.get("paint",RotorHelicopter.DEFAULT_PAINT))
	apply_garage()
	update_best_label()

func choose_pilot(name: String) -> void:
	pilot_delete_armed=false
	if name==pilot_name():
		refresh_pilots()
		return
	sync_profile()
	if ProgressStore.switch_profile(saved,name):
		apply_profile()
		save_data()
		sfx.play("whoosh",1.25)
		pilot_status.text="Je vliegt nu als %s." % pilot_name()
	refresh_pilots()

func add_pilot() -> void:
	pilot_delete_armed=false
	var name=Leaderboard.clean_pilot(pilot_new.text)
	if name.is_empty():
		pilot_status.text="Typ eerst een naam voor de nieuwe piloot."
	elif not ProgressStore.find_profile(saved,name).is_empty():
		pilot_status.text="%s bestaat al. Tik op de naam om te wisselen." % ProgressStore.find_profile(saved,name)
	elif saved.profiles.size()>=ProgressStore.MAX_PROFILES:
		pilot_status.text="Er passen %d piloten op dit apparaat. Verwijder er eerst een." % ProgressStore.MAX_PROFILES
	else:
		sync_profile()
		ProgressStore.add_profile(saved,name)
		apply_profile()
		save_data()
		pilot_new.text=""
		sfx.play("star",1.1)
		pilot_status.text="Welkom, %s! Kies rechts hoe je piloot eruitziet." % pilot_name()
	refresh_pilots()

# Two taps: the first asks, the second removes the active pilot.
func delete_pilot() -> void:
	if saved.profiles.size()<=1:
		return
	if not pilot_delete_armed:
		pilot_delete_armed=true
		pilot_status.text="Weet je het zeker? Tik nog eens op ‘Zeker?’ om %s te verwijderen." % pilot_name()
		refresh_pilots()
		return
	pilot_delete_armed=false
	var removed=pilot_name()
	if ProgressStore.remove_profile(saved,removed):
		apply_profile()
		save_data()
		pilot_status.text="%s is verwijderd. Je vliegt nu als %s; de vluchten op de ranglijst blijven staan." % [removed,pilot_name()]
	refresh_pilots()

# The cheapest pilot look still locked behind points.
func next_look_unlock() -> Dictionary:
	var best: Dictionary={}
	for entry in PilotFigure.ATTRIBUTES:
		for option in entry[2]:
			if option.size()>2 and option[2].has("points") and int(option[2].points)>points() and (best.is_empty() or int(option[2].points)<best.points):
				best={"name":"%s (%s)" % [option[1],String(entry[1]).to_lower()],"points":int(option[2].points)}
	return best

# The arrows walk past every option, locked ones too: a locked option is
# only tried on the preview, the worn look keeps the last earned one.
func step_look(attribute: String,direction: int) -> void:
	var shown=pilot_look()
	if pilot_trial.has(attribute):
		shown[attribute]=pilot_trial[attribute]
	var stepped: String=PilotFigure.step(shown,attribute,direction)[attribute]
	sfx.play("star",1.15)
	if not PilotFigure.option_open(PilotFigure.find_option(attribute,stepped),points(),medals()):
		pilot_trial[attribute]=stepped
		refresh_pilots()
		return
	pilot_trial.erase(attribute)
	var look=pilot_look()
	look[attribute]=stepped
	# A new figure starts with a matching haircut; every part stays changeable.
	if attribute=="figuur":
		if look.figuur=="vrouw" and look.haar=="kort":
			look.haar="staart"
		elif look.figuur=="man" and look.haar=="staart":
			look.haar="kort"
	saved.look=look
	refresh_pilots()

func random_look() -> void:
	pilot_trial.clear()
	var look: Dictionary={}
	for entry in PilotFigure.ATTRIBUTES:
		var ids=PilotFigure.open_ids(entry[0],points(),medals())
		look[entry[0]]=ids[randi()%ids.size()]
	saved.look=PilotFigure.clean(look)
	sfx.play("whoosh",1.3)
	refresh_pilots()

static func format_date(iso: String) -> String:
	var parts=iso.split("-")
	if parts.size()!=3:
		return iso
	var months=["jan","feb","mrt","apr","mei","jun","jul","aug","sep","okt","nov","dec"]
	return "%d %s" % [int(parts[2]),months[clampi(int(parts[1])-1,0,11)]]

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
	if not top_overlay().is_empty():
		return
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
	var result=catalog.parse_list("\n".join(ordinary),region)
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

# Retry-After is delta-seconds or an HTTP date ("Wed, 21 Oct 2026 07:28:00 GMT"). Anything else waits 5 s.
static func retry_after_seconds(value: String,now_unix: float) -> int:
	var v=value.strip_edges()
	if v.is_valid_int():
		return clampi(int(v),1,300)
	var parts=v.replace(","," ").split(" ",false)
	if parts.size()==6 and parts[5]=="GMT" and parts[1].is_valid_int() and parts[3].is_valid_int() and parts[4].count(":")==2:
		var month=["jan","feb","mar","apr","may","jun","jul","aug","sep","oct","nov","dec"].find(parts[2].to_lower())+1
		var clock=parts[4].split(":")
		if month>0 and clock[0].is_valid_int() and clock[1].is_valid_int() and clock[2].is_valid_int():
			var at=Time.get_unix_time_from_datetime_dict({"year":int(parts[3]),"month":month,"day":int(parts[1]),"hour":int(clock[0]),"minute":int(clock[1]),"second":int(clock[2])})
			return clampi(ceili(at-now_unix),1,300)
	return 5

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
					wait=retry_after_seconds(h.substr(12),Time.get_unix_time_from_system())
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
	# Hangar and pilot choices live in memory until their panel closes: save when the app is
	# backgrounded or closed, since the OS may end it without another chance.
	if what in [NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_WM_CLOSE_REQUEST] and not is_capture_mode and is_instance_valid(ui):
		save_data()
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
	# Worksheet routes: Kaart A to E of the textbook and F, the numbered test map with the total.
	assert(catalog.nl_routes.size()==11,"All Dutch worksheet routes and the four themes are bundled")
	assert(catalog.presets("nl",0)==[catalog.lookup.utrecht,catalog.lookup.amsterdam,catalog.lookup["den haag"],catalog.lookup.rotterdam,catalog.lookup.middelburg,catalog.lookup["den bosch"],catalog.lookup.maastricht,catalog.lookup.arnhem,catalog.lookup.zwolle,catalog.lookup.assen,catalog.lookup.groningen,catalog.lookup.leeuwarden],"Short Dutch route is unchanged, so its best time stays")
	assert(catalog.presets("nl",1).size()==42 and catalog.presets("nl",6).size()==34,"Kaart A has its 42 places; Kaart F, the test map, all 34 numbered places")
	for route in catalog.nl_routes:
		for place in route.places:
			assert(place.region=="nl" and TopoWorld.in_bounds(TopoWorld.map_bounds("nl"),place.lat,place.lon),"Route place lies on the Dutch map: "+place.name)
	for name in ["Biesbos","Randstad","Twente","Veluwe","Schiphol","Afsluitdijk","Vaalserberg","Lek","Neder-Rijn","Fryslân","Groningen (provincie)","Utrecht (stad)","Zaandam","Alphen aan den Rijn"]:
		assert(catalog.lookup.has(catalog.normalize(name)),"Worksheet name is known: "+name)
	assert(catalog.lookup[catalog.normalize("Groningen (provincie)")].kind=="provincie" and catalog.lookup[catalog.normalize("Groningen (stad)")].kind=="stad","Province and city with the same name stay apart")
	assert(hit_radius_km(catalog.lookup.biesbos)==7.0 and hit_radius_km(catalog.lookup.randstad)==30.0,"Areas use their own answer range")
	# Thema's: provinces, rivers and water, areas and islands as their own practice.
	var nl_themes: Dictionary={}
	for theme in catalog.themes("nl"):
		nl_themes[theme.theme]=catalog.routes("nl")[theme.index].places
	assert(nl_themes.keys()==["Provincies","Rivieren en water","Gebieden","Eilanden"] and catalog.themes("eu").size()==6,"Theme routes on both maps")
	assert(nl_themes.Provincies.size()==12 and nl_themes.Eilanden.size()>=15 and nl_themes.Gebieden.size()>=20 and nl_themes["Rivieren en water"].size()>=25,"Every province, island, area and water of the lesson is in a theme")
	for theme_name in nl_themes:
		for place in nl_themes[theme_name]:
			assert(float(place.get("radius_km",hit_radius_km(place)))>0 and TopoWorld.in_bounds(TopoWorld.map_bounds("nl"),place.lat,place.lon),"Theme place lies on the Dutch map: "+place.name)
	for name in ["Walcheren","Goeree-Overflakkee","Schouwen-Duiveland","Achterhoek","Betuwe","Peel","Heuvelland","Hollands Diep","Haringvliet","Lauwersmeer","Merwede"]:
		assert(catalog.lookup.has(catalog.normalize(name)),"Lesson name is known: "+name)
	# Provinces count anywhere inside their outline, not in a circle.
	var gelderland: Dictionary=catalog.lookup.gelderland
	assert(area_goal(gelderland) and world.has_province(catalog.lookup.friesland) and not area_goal(catalog.lookup.veluwe),"Dutch provinces are area goals, Friesland included")
	var province_probe=helicopter.position
	helicopter.position=world.project(6.6,52.1)
	assert(distance_km(gelderland)>25.0 and at_goal(gelderland),"Anywhere in Gelderland counts, also far from its reference point")
	helicopter.position=world.project(5.12,52.09)
	assert(not at_goal(gelderland) and at_goal(catalog.lookup["utrecht provincie"]),"The neighbouring province does not count")
	helicopter.position=world.project(5.8,53.1)
	assert(at_goal(catalog.lookup.friesland),"Friesland matches the official name Fryslân")
	helicopter.position=province_probe
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
	assert(world.lake_contains(world.project(catalog.lookup.houtribdijk.lon,catalog.lookup.houtribdijk.lat)),"Houtribdijk lies between IJsselmeer and Markermeer")
	assert(catalog.lookup.houtribdijk in catalog.presets("nl",1),"Kaart A includes the Houtribdijk drawn on the worksheet")
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
	assert(world.country_contains("FIN",world.project(19.95,60.1)),"Aland counts as Finland")
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
	# Records radar: over a city its own range circle appears, for the goal and
	# for any other city alike, so the pilot sees "I am inside" without a hint.
	update_radar()
	assert(fx.radar_shown==1 and radar_active and fx.radar_rings[0].visible,"Records radar shows the circle of the city you are over")
	assert(is_equal_approx(float(fx.radar_rings[0].get_meta("radius")),zone_radius_units(catalog.lookup.amsterdam)),"Radar circle is the real answer range")
	assert(not world.target.visible and not minimap.show_goal,"Radar does not reveal the goal marker")
	var amsterdam_center=world.project(catalog.lookup.amsterdam.lon,catalog.lookup.amsterdam.lat)
	helicopter.position=amsterdam_center+Vector3(zone_radius_units(catalog.lookup.amsterdam)*.95,9.0,0)
	update_radar()
	assert(fx.radar_shown>=1 and at_goal(mission[0]),"Radar circle still shows at the edge of the range")
	helicopter.position=amsterdam_center+Vector3(zone_radius_units(catalog.lookup.amsterdam)*1.1,9.0,0)
	update_radar()
	assert(not at_goal(mission[0]),"Just outside the range does not count")
	for i in fx.radar_shown:
		assert(Vector2(fx.radar_rings[i].position.x-amsterdam_center.x,fx.radar_rings[i].position.z-amsterdam_center.z).length()>.5,"Leaving the range drops the goal circle")
	helicopter.position=world.project(catalog.lookup.utrecht.lon,catalog.lookup.utrecht.lat)
	update_radar()
	assert(fx.radar_shown==1 and not at_goal(mission[0]),"Radar also rings a city that is not the goal, so it never gives the answer away")
	assert(is_equal_approx(float(fx.radar_rings[0].get_meta("radius")),zone_radius_units(catalog.lookup.utrecht)),"Every city gets its own range circle")
	helicopter.position=world.project(3.2,53.4)
	update_radar()
	assert(fx.radar_shown==0 and not radar_active,"Over open water the radar shows no city circle")
	helicopter.position=amsterdam_center
	update_radar()
	flight_time=12.5
	mistakes=1
	var record_cards=locator.shown_count
	var points_start=points()
	answer()
	assert(locator.shown_count==record_cards,"Records shows no locator card")
	assert(fx.radar_shown==0,"The summary clears the radar circle")
	var race_key=record_key(mission)
	assert(state=="summary" and saved.records[race_key]==22.5,"Record adds ten seconds per wrong answer")
	assert(points()>points_start and "eerste_record" in saved.medals,"A finished mission earns flight points and the first record a medal")
	assert(last_board_place==1 and saved.boards[last_board_key][0].time==22.5,"The record run lands on the leaderboard")
	open_leaderboard()
	assert(board_open and board_panel.visible and board_mode==GameMode.RECORDS and board_rows.get_child_count()>=1,"The summary opens this route's leaderboard")
	go_back(false)
	assert(not board_open and state=="summary","Back closes the leaderboard first")
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
	var europe_started=Time.get_ticks_msec()
	load_world("eu")
	print("Europe world build: %d ms" % (Time.get_ticks_msec()-europe_started))
	assert(world.europe_scenery.landmarks.size()>=60,"European capitals and big cities have detailed city scenery")
	# Europe gets the same depth as the Netherlands: real landmarks per city,
	# seas, rivers, mountains, islands and themed routes.
	var eu_landmarks=0
	for place in catalog.places:
		if place.kind=="stad" and (place.region=="eu" or place.name=="Amsterdam"):
			var entries: Array=world.europe_scenery.landmark_data.get(place.name,[])
			assert(entries.size()>=1 and entries.size()<=3,"1-3 landmarks per European city: "+place.name)
			for entry in entries:
				assert(EuropeScenery.known(entry.get("type","")),"Known European landmark type for "+place.name)
			assert(world.europe_scenery.landmark_built.get(place.name,-1)==entries.size(),"Every listed landmark is built in "+place.name)
			eu_landmarks+=entries.size()
	assert(eu_landmarks>=120,"European cities share at least 120 recognisable landmarks")
	var eu_kinds={}
	for place in catalog.places:
		if place.region=="eu":
			eu_kinds[place.kind]=int(eu_kinds.get(place.kind,0))+1
	assert(int(eu_kinds.get("water",0))>=30 and int(eu_kinds.get("gebied",0))>=12 and int(eu_kinds.get("eiland",0))>=6,"Europe has seas, rivers, lakes, mountains and islands")
	assert(catalog.eu_routes.size()>=12 and europe_route_select.item_count==catalog.eu_routes.size(),"Every Europe route is in the picker")
	for route in catalog.eu_routes:
		for place in route.places:
			assert(place.region=="eu" or place.name=="Amsterdam","Europe route uses Europe entries: "+place.name)
	assert(catalog.lookup.noordzee.region=="nl" and catalog.resolve("Noordzee","eu").region=="eu","Shared names resolve per region")
	var scenery: EuropeScenery=world.europe_scenery
	print("Europe scenery: %d ships, %d lighthouses, %d turbines, %d taiga trees, %d grove rows, %d peaks, %d flipped landmarks" % [scenery.ships_built,scenery.lighthouses_built,scenery.turbines_built,scenery.taiga_trees,scenery.grove_rows,scenery.peak_count,scenery.flipped_landmarks])
	assert(scenery.ships_built>=12 and scenery.lighthouses_built>=6 and scenery.turbines_built>=12 and scenery.taiga_trees>=300 and scenery.grove_rows>=30,"Europe has ships, lighthouses, wind farms, taiga and groves")
	assert(world.country_contains("FRA",world.project(2.35,48.85)) and not world.country_contains("FRA",world.project(-.5,52.5)),"Bounding-box shortcut keeps country checks exact")
	mode_select.select(GameMode.LEARN)
	var med: Dictionary=catalog.resolve("Middellandse Zee","eu")
	start_mission([med])
	helicopter.position=world.project(19.5,35.2)
	answer()
	assert(state=="summary","A sea counts anywhere in its wide answer range")
	return_menu()
	region_tiles[0].pressed.emit()
	assert(region=="nl" and region_select.selected==0,"Region tile switches to the Netherlands")
	region_tiles[1].pressed.emit()
	assert(region=="eu" and europe_route_select.visible,"Region tile switches to Europe")
	choose_mode(GameMode.LEARN)
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
	var legacy=RotorHelicopter.normalize_paint(ProgressStore.clean({"paint":{"body":"112233","trim":"aabbcc","dark":"445566"}}).paint)
	assert(legacy.tail=="112233" and legacy.rotor=="445566" and legacy.gear=="445566" and legacy.trim=="aabbcc","Paint from older versions keeps its colours")
	set_paint(paint_before)
	# Hangar: types, accessories and upgrades unlock with flight points and medals.
	var progress_snapshot=saved.duplicate(true)
	saved.points=0
	saved.medals=[]
	saved.garage=HangarCatalog.DEFAULT_GARAGE.duplicate(true)
	open_paint_shop()
	var libel_button: Button=paint_panel.find_child("Model_libel",true,false)
	var ambulance_button: Button=paint_panel.find_child("Scheme_Ambulance",true,false)
	assert(libel_button.icon!=null and ambulance_button.icon!=null and not libel_button.disabled and not ambulance_button.disabled,"New types and schemes start locked, with a padlock, but stay tappable")
	# Tapping a locked item previews it on the stage without equipping it.
	choose_model("libel")
	assert(equipped().model=="redder" and helicopter.config.model=="redder" and saved.garage.model=="redder","A locked type cannot be chosen")
	assert(preview_heli.config.model=="libel" and hangar_peek_note.visible and hangar_peek_text.text.contains("Libel") and libel_button.text.contains("voorproefje"),"A locked type shows on the preview stage")
	choose_model("libel")
	assert(hangar_peek.is_empty() and preview_heli.config.model=="redder" and not hangar_peek_note.visible,"Tapping it again ends the preview")
	var ambulance=HangarCatalog.SCHEMES.filter(func(s): return s.name=="Ambulance")[0]
	var body_before=helicopter.paint_hex("body")
	choose_scheme(ambulance)
	assert(preview_heli.paint_hex("body")==String(ambulance.body).to_lower() and helicopter.paint_hex("body")==body_before and saved.paint.body==body_before,"A locked scheme paints only the preview")
	toggle_accessory("wimpel")
	assert(hangar_peek.kind=="accessory" and "wimpel" in preview_heli.config.accessories and not "wimpel" in equipped().accessories and preview_heli.paint_hex("body")==body_before,"A locked accessory is tried on the preview; the scheme preview ends")
	set_upgrade("rotor",2)
	assert(int(preview_heli.config.rotor)==2 and int(equipped().rotor)==0 and hangar_peek_text.text.contains("vliegpunten"),"A locked upgrade shows on the preview")
	show_hangar_page("upgrades")
	assert(hangar_pages.upgrades.visible and not hangar_pages.type.visible,"Hangar tabs switch pages")
	assert(hangar_peek.is_empty() and int(preview_heli.config.rotor)==0,"Switching tabs ends the preview")
	saved.points=HangarCatalog.MAX_POINTS
	refresh_hangar()
	assert(libel_button.icon==null and ambulance_button.icon==null,"Points unlock types and schemes")
	assert(HangarCatalog.models_of("vliegtuig").size()>=4 and HangarCatalog.models_of("jet").size()>=3 and HangarCatalog.models_of("heli").size()>=8,"The hangar has helicopters, aeroplanes and jets")
	var rotor_counts={"tandem":2,"coax":2}
	for model in HangarCatalog.MODELS:
		choose_model(model.id)
		var rotors_expected: int=rotor_counts.get(model.id,1) if model.kind=="heli" else 0
		assert(helicopter.config.model==model.id and preview_heli.config.model==model.id and helicopter.rotors.size()==rotors_expected,"Every type builds: "+model.id)
		assert(helicopter.kind==model.kind and (model.kind!="vliegtuig" or not helicopter.propellers.is_empty()) and (model.kind!="jet" or not helicopter.exhausts.is_empty()),"Planes get propellers and jets an afterburner: "+model.id)
		assert(paint_panel.find_child("Model_"+model.id,true,false)!=null,"The type page lists "+model.id)
	choose_model("redder")
	var medal_items=HangarCatalog.ACCESSORIES.filter(func(item): return item.has("medal"))
	for item in HangarCatalog.ACCESSORIES:
		toggle_accessory(item.id)
	assert(equipped().accessories.size()==HangarCatalog.ACCESSORIES.size()-medal_items.size() and not "wimpel" in equipped().accessories,"A medal accessory needs its medal")
	assert(HangarCatalog.ACCESSORIES.size()>=24,"Many accessories to earn")
	award_medal("eerste_record")
	toggle_accessory("wimpel")
	assert("wimpel" in equipped().accessories and helicopter.flag!=null and helicopter.swing!=null,"Accessories are built on the helicopter")
	assert(helicopter.spinners.size()==1 and helicopter.bobbers.size()==3 and helicopter.flashers.size()==2 and not helicopter.twinkles.is_empty(),"Radar, balloons, police lights and the light string animate")
	# Every accessory on every type, so no anchor is missing anywhere.
	for medal in HangarCatalog.MEDALS:
		award_medal(medal)
	for model in HangarCatalog.MODELS:
		var test_garage: Dictionary=HangarCatalog.DEFAULT_GARAGE.duplicate(true)
		test_garage.model=model.id
		test_garage.accessories=HangarCatalog.ACCESSORIES.map(func(item): return item.id)
		var test_heli=RotorHelicopter.new()
		add_child(test_heli)
		test_heli.configure(test_garage)
		assert(test_heli.config.accessories.size()==HangarCatalog.ACCESSORIES.size() and test_heli.flags.size()==3 and test_heli.swings.size()==2,"All accessories fit on "+model.id)
		test_heli.queue_free()
	saved.medals=["eerste_record"]
	var blades_before=helicopter.rotors[0].get_child_count()
	set_upgrade("rotor",2)
	assert(helicopter.rotors[0].get_child_count()==blades_before+2,"Rotor upgrade adds blades")
	choose_model("sport")
	assert(helicopter.propellers[0].get_child_count()==2+2+1,"Rotor upgrade adds propeller blades (plus the spinner)")
	choose_model("redder")
	set_upgrade("motor",2)
	var base_speed=10.0 if region=="nl" else 42.0
	game_mode=GameMode.LEARN
	assert(is_equal_approx(flight_speed(),base_speed*(1.0+2*MOTOR_BOOST)),"Motor upgrade flies faster in Leren")
	game_mode=GameMode.RECORDS
	assert(is_equal_approx(flight_speed(),base_speed),"Records ignores the motor upgrade so times stay fair")
	game_mode=GameMode.LEARN
	set_upgrade("lights",1)
	assert(equipped().lights==0,"Light pack needs the flawless medal")
	saved.points=0
	assert(equipped().model=="redder" and equipped().accessories==["wimpel"] and equipped().rotor==0 and equipped().motor==0,"Locked choices in a save fall back to the factory helicopter")
	go_back(false)
	assert(not paint_open and state=="menu","Back closes the hangar")
	var cleaned_hangar=ProgressStore.clean({"garage":{"model":"ufo","accessories":["krat","krat","raket"],"rotor":9,"motor":1.5},"points":-5,"medals":["eerste_record","nep"],"pilot":"  Niek\n "})
	assert(cleaned_hangar.garage=={"model":"redder","accessories":["krat"],"rotor":2,"motor":0,"lights":0} and cleaned_hangar.points==0 and cleaned_hangar.medals==["eerste_record"] and cleaned_hangar.pilot=="Niek","Hangar progress is validated")
	assert(HangarCatalog.mission_points(GameMode.RECORDS,12,12,3,true,12)==385 and HangarCatalog.mission_points(GameMode.LEARN,1,1,2,false,1)==19,"Mission points follow mode, first tries, stars and records")
	assert(HangarCatalog.newly_unlocked(140,[],150,[])==PackedStringArray(["heli Libel"]),"The summary names what just unlocked")
	assert("Rookspoor" in HangarCatalog.newly_unlocked(899,[],900,[]) and "kapsel Afro" in HangarCatalog.newly_unlocked(259,[],260,[]),"Accessories and pilot looks are named when they unlock")
	assert(HangarCatalog.next_unlock(0).points==40 and HangarCatalog.rank(500)=="Gezagvoerder" and HangarCatalog.rank(5000)=="Luchtvaartlegende","Next unlock and rank follow the points")
	saved=progress_snapshot
	apply_garage()
	set_paint(paint_before)
	# Ranglijst: ten best per route and mode, records on time, the rest on points.
	var boards: Dictionary={}
	var race_board=Leaderboard.key("nl_x",GameMode.RECORDS)
	for t in [30.0,20.0,25.0]:
		Leaderboard.add(boards,race_board,{"pilot":"A","points":0,"time":t,"mistakes":0,"date":"2026-11-07"})
	assert(boards[race_board][0].time==20.0,"Fastest record first")
	assert(Leaderboard.add(boards,race_board,{"pilot":"B","points":0,"time":10.0,"mistakes":2,"date":"2026-11-07"})==1,"A faster run takes first place")
	for i in 12:
		Leaderboard.add(boards,race_board,{"pilot":"C","points":0,"time":100.0+i,"mistakes":0,"date":""})
	assert(boards[race_board].size()==Leaderboard.MAX_ENTRIES and Leaderboard.add(boards,race_board,{"pilot":"D","points":0,"time":999.0,"mistakes":0,"date":""})==0,"The list keeps the ten best")
	var learn_board=Leaderboard.key("nl_x",GameMode.LEARN)
	Leaderboard.add(boards,learn_board,{"pilot":"A","points":50,"time":40.0,"mistakes":0,"date":""})
	assert(Leaderboard.add(boards,learn_board,{"pilot":"B","points":80,"time":90.0,"mistakes":0,"date":""})==1,"Leren ranks on points")
	var cleaned_boards=Leaderboard.clean({race_board:[{"pilot":"X\u0007","points":1,"time":5,"mistakes":0,"date":"2026-11-07"},{"time":-1}],"zonder modus":[]})
	assert(cleaned_boards.size()==1 and cleaned_boards[race_board].size()==1 and cleaned_boards[race_board][0].pilot=="X","Leaderboard entries are validated")
	assert(Leaderboard.clean_pilot("Niek de Piloot met een hele lange naam").length()==Leaderboard.MAX_PILOT,"Pilot names are short")
	open_leaderboard()
	assert(board_open and board_title.text==board_route_title(),"Leaderboard opens from the hangar for the chosen route")
	go_back(false)
	assert(not board_open and state=="menu","Back closes the leaderboard")
	# Layout must fit the base viewport without a scrollbar in the hangar menu.
	await get_tree().process_frame
	await get_tree().process_frame
	assert(europe_route_select.visible and not nl_route_select.visible,"Layout check covers the tallest menu variant")
	print("Hangar menu width: %d px" % menu.get_global_rect().size.x)
	assert(menu.get_global_rect().size.x<=640,"Route pickers do not widen the hangar menu past half the screen")
	var screen=get_viewport().get_visible_rect()
	assert(screen.encloses(menu.get_global_rect()),"Hangar menu fits on screen without scrolling")
	assert(menu.get_global_rect().size.y<=screen.size.y-32,"Hangar menu keeps a margin")
	print("Hangar menu height: %d px of %d px" % [menu.get_global_rect().size.y,screen.size.y])
	for page in hangar_pages:
		open_paint_shop()
		show_hangar_page(page)
		await get_tree().process_frame
		await get_tree().process_frame
		print("Hangar panel %s: %s" % [page,paint_panel.get_global_rect().size])
		assert(screen.encloses(paint_panel.get_global_rect()),"Hangar panel fits on screen: "+page)
		close_paint_shop()
	show_hangar_page("type")
	open_leaderboard()
	await get_tree().process_frame
	await get_tree().process_frame
	print("Leaderboard panel: %s" % board_panel.get_global_rect().size)
	assert(screen.encloses(board_panel.get_global_rect()),"Leaderboard fits on screen")
	assert(board_switch.visible and board_pilot.text.contains(pilot_name()),"The leaderboard names the active pilot and offers to switch")
	close_leaderboard()
	# Pilot profiles: own progress and look per pilot, one shared leaderboard.
	var profile_data=ProgressStore.defaults()
	profile_data.points=300
	assert(ProgressStore.add_profile(profile_data,"Sara")=="Sara" and profile_data.pilot=="Sara" and profile_data.points==0,"A new pilot starts at zero")
	assert(ProgressStore.add_profile(profile_data,"sara").is_empty() and ProgressStore.add_profile(profile_data,"  ").is_empty(),"Pilot names are unique and not empty")
	profile_data.points=40
	profile_data.look=PilotFigure.step(profile_data.look,"bril",1)
	assert(ProgressStore.switch_profile(profile_data,"niek") and profile_data.pilot=="Niek" and profile_data.points==300 and profile_data.look.bril=="geen","Switching restores the other pilot")
	assert(ProgressStore.switch_profile(profile_data,"Sara") and profile_data.points==40 and profile_data.look.bril=="rond","Each pilot keeps its own points and look")
	var reloaded=ProgressStore.clean(JSON.parse_string(JSON.stringify(profile_data)))
	assert(reloaded.pilot=="Sara" and reloaded.profiles.size()==2 and reloaded.profiles.Niek.points==300 and reloaded.points==40 and reloaded.look.bril=="rond","Profiles survive saving and loading")
	var legacy_profile=ProgressStore.clean({"pilot":"Bram","points":120,"garage":{"model":"libel"}})
	assert(legacy_profile.profiles.keys()==["Bram"] and legacy_profile.profiles.Bram.points==120,"A save from before profiles becomes its pilot's profile")
	assert(ProgressStore.remove_profile(reloaded,"Sara") and reloaded.pilot=="Niek" and reloaded.points==300 and not ProgressStore.remove_profile(reloaded,"Niek"),"Removing a pilot switches to another; the last one stays")
	for i in 20:
		ProgressStore.add_profile(reloaded,"Piloot %d" % i)
	assert(reloaded.profiles.size()==ProgressStore.MAX_PROFILES,"At most eight pilots per device")
	var odd_look=PilotFigure.clean({"haar":"paars","bril":"zonnebril","onbekend":1,"extra":7})
	assert(odd_look.haar==PilotFigure.DEFAULT_LOOK.haar and odd_look.bril=="zonnebril" and not odd_look.has("onbekend") and odd_look.extra=="geen","Pilot looks are validated")
	assert(PilotFigure.step(PilotFigure.DEFAULT_LOOK,"bril",-1,0,[]).bril=="vliegbril","Look choices wrap round over the free options")
	# New looks are earned: locked ones are skipped and fall back when worn.
	assert(PilotFigure.step({"haar":"kaal"},"haar",1,0,[]).haar=="kort" and PilotFigure.step({"haar":"kaal"},"haar",1,70,[]).haar=="kuif","Locked hairstyles are skipped until earned")
	var earned_look={"haar":"afro","hoofd":"kroon","outfit":"ridder","kleur":"d4a017","extra":"papegaai","huid":"8fd16a"}
	var worn=PilotFigure.effective(earned_look,0,[])
	assert(worn.haar=="kort" and worn.hoofd=="koptelefoon" and worn.outfit=="vliegpak" and worn.kleur=="e67b34" and worn.extra=="geen" and worn.huid=="f6d7c3","Locked looks fall back to the default")
	worn=PilotFigure.effective(earned_look,HangarCatalog.MAX_POINTS,["huiswerk","combi","foutloos"])
	assert(worn.haar=="afro" and worn.hoofd=="kroon" and worn.outfit=="ridder" and worn.kleur=="d4a017" and worn.extra=="papegaai","Earned looks are worn")
	var look_total=0
	for entry in PilotFigure.ATTRIBUTES:
		look_total+=entry[2].filter(func(option): return option.size()>2).size()
	assert(look_total>=55 and PilotFigure.locked_count(0,[])==look_total and PilotFigure.locked_count(HangarCatalog.MAX_POINTS,HangarCatalog.MEDALS.keys())==0,"Many pilot looks to earn, all reachable")
	for entry in PilotFigure.ATTRIBUTES:
		for option in entry[2]:
			var figure_look=PilotFigure.DEFAULT_LOOK.duplicate()
			figure_look[entry[0]]=option[0]
			var figure=PilotFigure.new()
			add_child(figure)
			figure.configure(figure_look)
			var head: Node3D=figure.root.get_node_or_null("Head")
			assert(head!=null and head.scale.x>1.0 and figure.root.find_children("*","MeshInstance3D",true,false).size()>20,"Pilot figure builds with %s %s" % [entry[0],option[0]])
			figure.queue_free()
	var pilots_before: Dictionary=saved.duplicate(true)
	open_pilots()
	assert(pilots_open and pilots_panel.visible and pilot_list.get_child_count()==saved.profiles.size(),"The pilot screen lists every pilot")
	# Tablet swipes: every button in a scrolling list lets the drag through,
	# and every list has a dead zone so a tap stays a tap.
	var list_buttons=0
	for panel in [paint_panel,pilots_panel]:
		for scroll in panel.find_children("*","ScrollContainer",true,false):
			assert((scroll as ScrollContainer).scroll_deadzone==SCROLL_DEADZONE,"Scroll list %s has a touch dead zone" % scroll.name)
			for b in scroll.find_children("*","BaseButton",true,false):
				assert((b as Control).mouse_filter==Control.MOUSE_FILTER_PASS,"Button %s passes swipes to its list" % b.name)
				list_buttons+=1
	assert(list_buttons>=HangarCatalog.MODELS.size()+HangarCatalog.ACCESSORIES.size()+saved.profiles.size(),"The swipe check saw the type, accessory and pilot lists")
	pilot_new.text="Sara"
	add_pilot()
	assert(pilot_name()=="Sara" and points()==0 and saved.profiles.size()==pilots_before.profiles.size()+1 and pilot_button.text=="Piloot: Sara","A new pilot becomes the active one")
	step_look("hoofd",1)
	assert(saved.look.hoofd!=PilotFigure.DEFAULT_LOOK.hoofd and pilot_preview.look.hoofd==saved.look.hoofd and hangar_pilot.look.hoofd==saved.look.hoofd,"A new look reaches the preview and the hangar pilot")
	# The arrows also reach locked looks: tried on the preview, never worn.
	var worn_hair=pilot_look().haar
	step_look("haar",-1)
	var tried_hair=PilotFigure.HAIR[-1]
	assert(pilot_trial.get("haar","")==tried_hair[0] and pilot_preview.look.haar==tried_hair[0] and pilot_look().haar==worn_hair and hangar_pilot.look.haar==worn_hair,"A locked hairstyle shows on the pilot preview only")
	assert(pilot_values.haar.lock.visible and pilot_values.haar.label.text.begins_with(tried_hair[1]) and pilot_unlocks.text.begins_with("Voorproefje"),"A tried look carries a padlock and says what it needs")
	step_look("haar",1)
	assert(not pilot_trial.has("haar") and pilot_look().haar==worn_hair and pilot_preview.look.haar==worn_hair and not pilot_values.haar.lock.visible,"Stepping back to an earned look ends the try-on")
	step_look("haar",-1)
	close_pilots()
	open_pilots()
	assert(pilot_trial.is_empty() and pilot_preview.look.haar==worn_hair,"Closing the pilot screen drops the try-on")
	choose_pilot(pilots_before.pilot)
	assert(pilot_name()==pilots_before.pilot and points()==int(pilots_before.points) and saved.look.hoofd==PilotFigure.DEFAULT_LOOK.hoofd,"Switching back restores points and look")
	delete_pilot()
	assert(saved.profiles.size()==pilots_before.profiles.size()+1 and pilot_delete_armed,"Removing a pilot asks first")
	choose_pilot("Sara")
	delete_pilot()
	delete_pilot()
	assert(saved.profiles.size()==pilots_before.profiles.size() and pilot_name()==pilots_before.pilot,"The second tap removes the pilot")
	await get_tree().process_frame
	await get_tree().process_frame
	print("Pilot panel: %s" % pilots_panel.get_global_rect().size)
	assert(screen.encloses(pilots_panel.get_global_rect()),"Pilot screen fits on screen")
	# The stretch aspect never makes the viewport shorter than 720 px.
	assert(pilots_panel.get_global_rect().size.y<=720-32 and pilots_panel.get_global_rect().size.x<=1280-32,"Pilot screen fits a 720 px landscape phone")
	go_back(false)
	assert(not pilots_open and state=="menu","Back closes the pilot screen")
	saved=pilots_before
	apply_profile()
	# The theme screen starts a theme route in the chosen mode.
	open_themes()
	assert(themes_open and themes_grid.get_child_count()==catalog.themes(region).size(),"The theme screen lists this map's themes")
	await get_tree().process_frame
	await get_tree().process_frame
	print("Theme panel: %s" % themes_panel.get_global_rect().size)
	assert(screen.encloses(themes_panel.get_global_rect()),"Theme screen fits on screen")
	var picked_route=europe_route_select.selected
	var first_theme: Dictionary=catalog.themes(region)[0]
	start_theme(first_theme.index)
	assert(not themes_open and state=="flight" and mission.size()==first_theme.count,"A theme starts its own mission")
	return_menu()
	europe_route_select.select(picked_route)
	update_best_label()
	# Huiswerk: the worksheet cards Kaart A to F, alone or several at once.
	var homework_before: Dictionary=saved.duplicate(true)
	saved.homework=[]
	saved.medals=[]
	open_homework()
	var cards: Array=catalog.homework("nl")
	assert(homework_open and region=="nl" and homework_grid.get_child_count()==6,"Huiswerk lists the six worksheet cards")
	assert(cards.map(func(item): return item.name)==["Kaart A","Kaart B","Kaart C","Kaart D","Kaart E","Kaart F"],"The cards come in worksheet order, A to F")
	for item in cards:
		assert(not item.subject.is_empty() and not item.subject.begins_with("Kaart") and item.source==item.name,"Each card says what it covers: "+item.name)
		assert(homework_grid.get_child(cards.find(item)).text.begins_with(item.name),"The tile leads with the card: "+item.name)
	var card_of=func(id: String) -> Dictionary: return cards.filter(func(item): return item.id==id)[0]
	var kaart_a: Dictionary=card_of.call("water")
	assert(kaart_a.name=="Kaart A" and kaart_a.count==42 and kaart_a.places.any(func(p): return p.name=="Biesbos") and not kaart_a.places.any(func(p): return p.name=="Rotterdam"),"Kaart A is the overview map with the Biesbos, without Rotterdam")
	assert(card_of.call("west").name=="Kaart E" and card_of.call("overzicht").name=="Kaart F" and card_of.call("overzicht").count==34,"Kaart E is the Randstad and Zeeland; Kaart F the numbered total of 34")
	await get_tree().process_frame
	await get_tree().process_frame
	print("Homework panel: %s" % homework_panel.get_global_rect().size)
	assert(screen.encloses(homework_panel.get_global_rect()),"Homework screen fits on screen")
	select_all_homework(false)
	assert(homework_start.disabled and homework_quiz.disabled,"Nothing chosen, nothing to start")
	toggle_homework("west")
	toggle_homework("noord")
	var west_north=TopoCatalog.merge_places([card_of.call("west").places,card_of.call("noord").places])
	assert(not homework_start.disabled and not homework_quiz.disabled and homework_status.text.contains("2 kaarten") and homework_status.text.contains("%d plekken" % west_north.size()),"Two cards merge, every place once")
	assert(west_north.size()<card_of.call("west").count+card_of.call("noord").count,"Shared places (the Afsluitdijk, the IJsselmeer) are flown once")
	start_homework()
	assert(not homework_open and state=="flight" and mission.size()==west_north.size() and not custom_mission,"Several cards fly as one mission")
	assert(homework_title(mission)=="Huiswerk · Kaart B + Kaart E","The combined mission is named after its cards")
	var flown=record_homework(mission)
	assert(flown.size()==2 and "west" in saved.homework and "noord" in saved.homework and "combi" in saved.medals and not "huiswerk" in saved.medals,"Flown cards are remembered; two at once earns a medal")
	return_menu()
	homework_selected=["zuid"]
	start_homework()
	assert(state=="flight" and nl_route_select.selected==card_of.call("zuid").index and mission.size()==card_of.call("zuid").count,"One card flies its own route, and only its own places")
	var card_names: Array=card_of.call("zuid").places.map(func(p): return p.name)
	assert(mission.all(func(p): return p.name in card_names),"A card's mission asks nothing that is not on the card")
	return_menu()
	# Every mode flies a new order: a retry of the same route starts elsewhere.
	for mode in [GameMode.LEARN,GameMode.PRACTICE,GameMode.RECORDS]:
		mode_select.select(mode)
		var firsts: Dictionary={}
		var previous: Array=[]
		for _attempt in 4:
			start_mission(card_of.call("noord").places,false)
			var order: Array=mission.map(func(p): return p.name)
			assert(order!=previous and (previous.is_empty() or order[0]!=previous[0]),"%s: each new flight starts at another place" % MODE_NAMES[mode])
			firsts[order[0]]=true
			previous=order
			return_menu()
		assert(firsts.size()>=3,"%s: the first place varies" % MODE_NAMES[mode])
	assert(record_key(shuffled_order(card_of.call("noord").places))==record_key(card_of.call("noord").places),"The record key ignores the order, so records stay comparable")
	mode_select.select(GameMode.LEARN)
	update_best_label()
	record_homework(TopoCatalog.merge_places(cards.map(func(item): return item.places)))
	assert(saved.homework.size()==6 and "huiswerk" in saved.medals,"All six flown earns the homework medal")
	open_homework()
	assert(homework_grid.get_child(0).text.contains("✓"),"Flown cards get a tick")
	# Overhoren: drag the names of the chosen cards onto the numbered dots.
	homework_selected=["west"]
	refresh_homework()
	start_homework_quiz()
	assert(quiz_open and not homework_open and state=="menu" and top_overlay()=="quiz","Overhoren opens the test, without flying")
	await get_tree().process_frame
	await get_tree().process_frame
	print("Quiz board: %s, tray: %s" % [quiz_board.get_global_rect().size,quiz_tray.get_global_rect().size])
	assert(screen.encloses(quiz_panel.get_global_rect()) and quiz_board.size.x>500 and quiz_board.size.y>400,"The quiz map fills most of the screen")
	var kaart_e: Dictionary=card_of.call("west")
	assert(quiz_board.places.size()==kaart_e.count and quiz_names.get_child_count()==kaart_e.count and quiz_kicker.text.contains("KAART E"),"Every place of Kaart E is a dot, every name a chip")
	quiz_board.layout()
	var board_box=Rect2(Vector2.ZERO,quiz_board.size)
	for i in quiz_board.dot_at.size():
		assert(board_box.has_point(quiz_board.dot_at[i]),"Dot %d lies on the map" % (i+1))
		for j in range(i+1,quiz_board.dot_at.size()):
			assert(quiz_board.dot_at[i].distance_to(quiz_board.dot_at[j])>=QuizBoard.MIN_GAP-1.0,"Dots %d and %d do not overlap" % [i+1,j+1])
	var tray_chips=quiz_names.get_children()
	var tray_before=tray_chips.map(func(c): return c.place_name)
	assert(tray_before!=quiz_board.places.map(func(p): return p.name),"The names are not listed in dot order")
	assert(get_viewport().disable_3d,"The 3D world pauses behind the test")
	# Dragging: the game's own drag starts on the press and follows every move.
	var first: Dictionary=quiz_board.places[0]
	var canvas_of=func(local: Vector2) -> Vector2: return quiz_board.get_global_transform_with_canvas()*local
	var chip_of=func(name_text: String) -> Control: return quiz_names.get_children().filter(func(c): return c.place_name==name_text and not c.is_queued_for_deletion())[0]
	var chip0: Control=chip_of.call(first.name)
	var chip_at: Vector2=chip0.get_global_rect().get_center()
	var map_draws: int=quiz_board.map_layer.draws
	var press=InputEventMouseButton.new()
	press.button_index=MOUSE_BUTTON_LEFT
	press.pressed=true
	press.global_position=chip_at
	chip0._gui_input(press)
	assert(quiz_board.dragging() and quiz_board.drag_name==first.name and not quiz_board.drag_moved and not quiz_board.ghost.visible,"A press on a name starts the drag at once")
	var drop_at: Vector2=quiz_board.dot_at[0]+Vector2(8,-6)
	var motion=InputEventMouseMotion.new()
	motion.position=canvas_of.call(drop_at)
	quiz_board._input(motion)
	assert(quiz_board.drag_moved and quiz_board.ghost.visible and quiz_board.ghost.get_parent()==ui and chip0.modulate.a<1.0 and quiz_board.hover==0,"The name follows the pointer and the dot under it lights up")
	await get_tree().process_frame
	assert(quiz_board.map_layer.draws==map_draws and quiz_board.dot_layer.draws>0,"A drag repaints only the dots, never the map")
	var release=InputEventMouseButton.new()
	release.button_index=MOUSE_BUTTON_LEFT
	release.pressed=false
	release.position=canvas_of.call(drop_at)
	quiz_board._input(release)
	assert(not quiz_board.dragging() and not quiz_board.ghost.visible and quiz_board.placed[0]==first.name and not quiz_board.names_left().has(first.name) and quiz_names.get_child_count()==kaart_e.count-1,"Let go near the dot: the name moves from the tray to the dot")
	# With a finger the aim sits above the touch, so the finger does not cover the dot.
	quiz_board.begin_drag(first.name,0,canvas_of.call(quiz_board.dot_at[0]),true)
	quiz_board.move_drag(canvas_of.call(quiz_board.dot_at[1]-QuizBoard.TOUCH_LIFT))
	assert(quiz_board.hover==1 and quiz_board.aim.distance_to(quiz_board.dot_at[1])<1.0,"A finger below a dot aims at that dot")
	quiz_board.cancel_drag()
	# Let go on the map but away from every dot: the name stays where it was.
	var empty_spot=Vector2(6,6)
	assert(quiz_board.nearest_dot(empty_spot)<0,"The map corner is free of dots")
	quiz_board.begin_drag(first.name,0,canvas_of.call(quiz_board.dot_at[0]),false)
	quiz_board.end_drag(canvas_of.call(empty_spot))
	assert(quiz_board.placed[0]==first.name,"A miss on the map keeps the name on its dot")
	# Dragged from its dot onto the tray: back in the tray.
	var on_dot=InputEventMouseButton.new()
	on_dot.button_index=MOUSE_BUTTON_LEFT
	on_dot.pressed=true
	on_dot.position=quiz_board.dot_at[0]
	on_dot.global_position=canvas_of.call(quiz_board.dot_at[0])
	quiz_board._gui_input(on_dot)
	assert(quiz_board.dragging() and quiz_board.drag_from==0,"A placed name can be picked up again")
	quiz_board.end_drag(quiz_tray.get_global_rect().get_center())
	assert(quiz_board.placed[0].is_empty() and quiz_board.names_left().has(first.name),"Back in the tray")
	# Tap a name, then tap the dot.
	await get_tree().process_frame
	var chip1: Control=chip_of.call(first.name)
	quiz_board.begin_drag(first.name,-1,chip1.get_global_rect().get_center(),true,chip1)
	quiz_board.end_drag(chip1.get_global_rect().get_center())
	assert(quiz_board.selected_name==first.name and not quiz_board.dragging(),"A tap on a name selects it")
	quiz_board._gui_input(on_dot)
	assert(quiz_board.tap_pending,"A tap on an empty dot waits for the release")
	release.position=canvas_of.call(quiz_board.dot_at[0])
	quiz_board._input(release)
	assert(quiz_board.placed[0]==first.name and quiz_board.selected_name.is_empty(),"Tap a name, then a dot, also places it")
	# Zoom: + and − step about the middle, the wheel zooms about the pointer, a drag moves the map.
	assert(Rect2(Vector2.ZERO,quiz_board.size).encloses(quiz_board.zoom_bar.get_rect()) and quiz_board.zoom_bar.get_rect().position.x>quiz_board.size.x*.5 and quiz_board.zoom_in_button.size.y>=48,"The zoom buttons sit in the bottom right corner of the map, big enough for a finger")
	assert(quiz_board.zoom==1.0 and quiz_board.zoom_out_button.disabled and quiz_board.zoom_fit_button.disabled and not quiz_board.zoom_in_button.disabled,"A test starts zoomed out, showing every dot")
	quiz_board.pan_by(Vector2(50,30))
	assert(quiz_board.pan==Vector2.ZERO,"Zoomed out the map does not move")
	quiz_board.zoom_in_button.pressed.emit()
	assert(is_equal_approx(quiz_board.zoom,QuizBoard.ZOOM_STEP) and quiz_board.view_zoom==quiz_board.zoom and quiz_board.map_layer.scale==Vector2.ONE and not quiz_board.zoom_out_button.disabled,"+ zooms in and draws the map at once")
	quiz_board.zoom_out_button.pressed.emit()
	assert(is_equal_approx(quiz_board.zoom,1.0) and quiz_board.pan.length()<.001,"− zooms back out")
	quiz_board.layout()
	var aim_at: Vector2=quiz_board.true_at[3]
	var wheel=InputEventMouseButton.new()
	wheel.button_index=MOUSE_BUTTON_WHEEL_UP
	wheel.pressed=true
	wheel.factor=1.0
	wheel.position=aim_at
	for _notch in 6:
		quiz_board._gui_input(wheel)
	assert(quiz_board.zoom>2.0 and quiz_board.previewing() and quiz_board.map_layer.scale.x>1.0 and quiz_board.view_zoom==1.0,"The wheel zooms in; while it turns the drawn map is only scaled, not drawn again")
	quiz_board.settle_view()
	quiz_board.layout()
	assert(not quiz_board.previewing() and quiz_board.true_at[3].distance_to(aim_at)<1.0,"The place under the pointer stays under it")
	for i in quiz_board.dot_at.size():
		if Rect2(Vector2.ZERO,quiz_board.size).has_point(quiz_board.dot_at[i]):
			for j in range(i+1,quiz_board.dot_at.size()):
				assert(quiz_board.dot_at[i].distance_to(quiz_board.dot_at[j])>=QuizBoard.MIN_GAP-1.0,"Zoomed in, dots %d and %d still do not overlap" % [i+1,j+1])
	for _notch in 40:
		quiz_board._gui_input(wheel)
	assert(is_equal_approx(quiz_board.zoom,QuizBoard.ZOOM_MAX) and quiz_board.zoom_in_button.disabled,"Zooming in stops at the closest step")
	quiz_board.reset_zoom()
	assert(quiz_board.zoom==1.0 and quiz_board.pan==Vector2.ZERO and quiz_board.view_zoom==1.0,"Alles shows the whole test again")
	# Two fingers pinch: further apart zooms in about their middle, the middle drags the map along.
	var mid: Vector2=quiz_board.size*.5
	var finger=func(index: int,at: Vector2,down: bool) -> void:
		var touch=InputEventScreenTouch.new()
		touch.index=index
		touch.pressed=down
		touch.position=canvas_of.call(at)
		quiz_board._input(touch)
	var slide=func(index: int,at: Vector2) -> void:
		var move=InputEventScreenDrag.new()
		move.index=index
		move.position=canvas_of.call(at)
		quiz_board._input(move)
	finger.call(0,mid-Vector2(50,0),true)
	assert(not quiz_board.pinching(),"One finger is no pinch")
	finger.call(1,mid+Vector2(50,0),true)
	assert(quiz_board.pinching() and not quiz_board.press_pending and not quiz_board.dragging(),"Two fingers on the map start a pinch")
	slide.call(1,mid+Vector2(100,0))
	assert(is_equal_approx(quiz_board.zoom,1.5),"Fingers 1.5 times as far apart zoom in 1.5 times")
	slide.call(0,mid-Vector2(150,0))
	slide.call(1,mid+Vector2(150,0))
	assert(is_equal_approx(quiz_board.zoom,3.0),"Spreading further zooms in further")
	finger.call(1,mid+Vector2(150,0),false)
	finger.call(0,mid-Vector2(150,0),false)
	assert(not quiz_board.pinching() and not quiz_board.previewing() and quiz_board.touches.is_empty(),"Lifting the fingers ends the pinch and draws the map sharp")
	# Zoomed in, a drag on the empty map moves it; a short press is still a tap.
	quiz_board.layout()
	var free_spot=Vector2(-1,-1)
	var probe=Vector2(30,30)
	while free_spot.x<0 and probe.y<quiz_board.size.y-30:
		if quiz_board.nearest_dot(probe,QuizBoard.DOT_RADIUS+12,false)<0 and quiz_board.nearest_dot(probe+Vector2(80,40),QuizBoard.DOT_RADIUS+12,false)<0:
			free_spot=probe
		probe.x+=17
		if probe.x>quiz_board.size.x*.6:
			probe=Vector2(30,probe.y+17)
	assert(free_spot.x>=0,"Some of the zoomed map is free of dots")
	var place_before: Vector2=quiz_board.true_at[3]
	var pan_press=InputEventMouseButton.new()
	pan_press.button_index=MOUSE_BUTTON_LEFT
	pan_press.pressed=true
	pan_press.position=free_spot
	pan_press.global_position=canvas_of.call(free_spot)
	quiz_board._gui_input(pan_press)
	assert(quiz_board.press_pending and not quiz_board.dragging(),"A press on the empty map waits to see a tap or a drag")
	var pan_move=InputEventMouseMotion.new()
	pan_move.position=canvas_of.call(free_spot+Vector2(80,40))
	quiz_board._input(pan_move)
	assert(quiz_board.panning,"Moving the press moves the map")
	release.position=canvas_of.call(free_spot+Vector2(80,40))
	quiz_board._input(release)
	quiz_board.layout()
	assert(not quiz_board.panning and not quiz_board.press_pending and quiz_board.true_at[3].distance_to(place_before+Vector2(80,40))<1.0 and quiz_board.placed[0]==first.name,"The map follows the drag and nothing was placed")
	quiz_board.pan_by(Vector2(1e6,1e6))
	quiz_board.settle_view()
	quiz_board.layout()
	assert(Rect2(Vector2.ZERO,quiz_board.size).grow(8).intersects(Rect2(quiz_board.to_screen(quiz_board.view.position),quiz_board.view.size*quiz_board.fit_scale()*quiz_board.zoom)),"The map cannot be dragged out of sight")
	quiz_board.reset_zoom()
	# Fill in everything right except two swapped names, then mark it.
	for i in quiz_board.places.size():
		quiz_board.assign(i,quiz_board.places[i].name)
	quiz_board.assign(1,quiz_board.places[2].name)
	quiz_board.assign(2,quiz_board.places[1].name)
	assert(quiz_board.placed_count()==kaart_e.count and quiz_board.names_left().is_empty(),"A name moved to another dot leaves its old dot empty")
	quiz_board.assign(1,quiz_board.places[1].name)
	check_quiz()
	var total: int=kaart_e.count
	assert(quiz_board.checked and quiz_result.right==total-1 and quiz_status.text.contains("%d van %d goed" % [total-1,total]) and quiz_status.text.contains("cijfer "+quiz_mark(total-1,total)),"Nakijken counts the right dots and gives a mark")
	quiz_board.begin_drag(quiz_board.places[3].name,3,canvas_of.call(quiz_board.dot_at[3]),false)
	assert(not quiz_board.dragging() and quiz_check.disabled and not quiz_retry.disabled,"After marking the map is closed until a retry")
	var first_mark: float=snappedf(1.0+9.0*float(total-1)/float(total),.1)
	assert(quiz_key=="west" and is_equal_approx(float(saved.quiz.west),first_mark) and quiz_result.record and quiz_status.text.contains("Nieuw beste cijfer"),"The first marking is saved as the best mark of Kaart E")
	assert(quiz_mark(10,10)=="10,0" and quiz_mark(0,10)=="1,0" and quiz_mark(5,10)=="5,5","Marks run from 1 to 10 with a decimal comma")
	retry_quiz()
	assert(not quiz_board.checked and quiz_board.locked.count(true)==total-1 and quiz_board.names_left().size()==1 and quiz_names.get_child_count()==1,"Fouten over keeps the right answers and asks only the mistake again")
	quiz_board.assign(0,quiz_board.places[2].name)
	assert(quiz_board.placed[0]==quiz_board.places[0].name,"Fixed answers cannot be overwritten")
	quiz_board.assign(2,quiz_board.places[2].name)
	check_quiz()
	assert(quiz_result.right==total and quiz_retry.disabled,"All right: nothing to retry")
	assert(is_equal_approx(float(saved.quiz.west),first_mark) and quiz_status.text.contains("telt het cijfer niet mee"),"A mark after Fouten over does not count")
	saved.quiz.west=6.0
	new_quiz_round()
	for i in quiz_board.places.size():
		quiz_board.assign(i,quiz_board.places[(i+1)%total].name)
	check_quiz()
	assert(quiz_result.right==0 and not quiz_result.record and is_equal_approx(float(saved.quiz.west),6.0) and quiz_status.text.contains("beste cijfer is 6,0"),"A lower mark keeps the best one")
	var numbered: Array=quiz_board.places.map(func(p): return p.name)
	new_quiz_round()
	assert(quiz_board.placed_count()==0 and quiz_board.locked.count(true)==0 and quiz_board.places.map(func(p): return p.name)!=numbered,"A new test renumbers the dots and starts empty")
	go_back(false)
	assert(not quiz_open and state=="menu" and not get_viewport().disable_3d,"Back closes the test and the 3D world runs again")
	open_homework()
	assert(homework_grid.get_child(4).text.contains("toets 6,0") and not homework_grid.get_child(0).text.contains("toets"),"The card tile shows its best test mark")
	assert(ProgressStore.clean({"quiz":{"water":8.46,"oost":11,"zuid":"8","":5,"noord+west":1}}).quiz=={"water":8.5,"noord+west":1.0},"Saved test marks are validated")
	assert("quiz" in ProgressStore.PROFILE_KEYS and ProgressStore.VERSION==2,"Test marks belong to a pilot and bump the save version")
	go_back(false)
	assert(not homework_open,"Back closes the homework screen")
	assert(ProgressStore.clean({"homework":["west","west",5,"noord"]}).homework==["west","noord"],"Homework progress is validated")
	saved=homework_before
	homework_selected=[]
	apply_profile()
	region_select.select(1)
	load_world("eu")
	europe_route_select.select(picked_route)
	update_best_label()
	assert(mode_tiles.size()==3 and mode_tiles[mode_select.selected].selected,"Mode tiles mirror the chosen mode")
	choose_mode(GameMode.PRACTICE)
	assert(mode_select.selected==GameMode.PRACTICE and mode_tiles[1].selected and not mode_tiles[0].selected,"Tapping a tile picks the mode")
	choose_mode(GameMode.LEARN)
	fly_menu_helicopter(1.0)
	assert(helicopter.scale.x>FLIGHT_HELI_SCALE*2,"The hangar shows a big circling helicopter")
	preload("res://scripts/smoke/ws1.gd").run(self)
	preload("res://scripts/smoke/ws5b.gd").run(self)
	preload("res://scripts/smoke/ws4.gd").run(self)
	preload("res://scripts/smoke/ws5a.gd").run(self)
	print("SMOKE TEST PASSED: parsing, coordinates, land boundaries, flight scoring, custom missions")
	await get_tree().process_frame
	get_tree().quit()

func capture_preview() -> void:
	saved.mute=true
	seed(1206)
	order_rng.seed=1206
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
	# Unlocked hangar: every type, accessory and upgrade in turn.
	saved.points=5000
	saved.medals=HangarCatalog.MEDALS.keys()
	saved.garage={"model":"redder","accessories":["zoeklicht","lier","antennes","wimpel"],"rotor":1,"motor":2,"lights":1}
	show_hangar_page("type")
	for model in HangarCatalog.MODELS:
		choose_model(model.id)
		if model.id=="tandem":
			saved.garage.accessories=["krat","vleugels","camera"]
			apply_garage()
		elif model.id=="kraan":
			saved.garage.accessories=["krat","antennes"]
			apply_garage()
		elif model.id=="pijl":
			saved.garage.accessories=["drijvers","zoeklicht","wimpel"]
			apply_garage()
		var showcase=["Kustwacht","Neonracer","Middernacht","Camouflage","Brandweer","Junglegroen","Traumageel","Robijn","Racerood","Oceaanblauw","Woestijn","Ambulance","Europa","Marinegrijs","Nachtzwart"]
		paint_panel.find_child("Scheme_"+showcase[HangarCatalog.MODELS.find(model)%showcase.size()],true,false).pressed.emit()
		await get_tree().create_timer(.6).timeout
		get_viewport().get_texture().get_image().save_png("res://build/preview-hangar-"+model.id+".png")
	for page in ["kleuren","accessoires","upgrades"]:
		show_hangar_page(page)
		await get_tree().create_timer(.3).timeout
		get_viewport().get_texture().get_image().save_png("res://build/preview-hangar-tab-"+page+".png")
	show_hangar_page("type")
	saved.garage=HangarCatalog.DEFAULT_GARAGE.duplicate(true)
	apply_garage()
	set_paint(RotorHelicopter.DEFAULT_PAINT.duplicate())
	close_paint_shop()
	var demo_key=Leaderboard.key(record_key(selected_presets()),GameMode.RECORDS)
	for entry in [["Niek",184.3,1],["Papa",201.8,0],["Niek",215.0,3],["Oma",298.4,2]]:
		Leaderboard.add(saved.boards,demo_key,{"pilot":entry[0],"points":0,"time":entry[1],"mistakes":entry[2],"date":"2026-11-07"})
	mode_select.select(GameMode.RECORDS)
	open_leaderboard()
	await get_tree().create_timer(.3).timeout
	get_viewport().get_texture().get_image().save_png("res://build/preview-ranglijst.png")
	close_leaderboard()
	mode_select.select(GameMode.LEARN)
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
	# Records radar: the circle of the city under the helicopter.
	mode_select.select(GameMode.RECORDS)
	start_mission([catalog.lookup.utrecht,catalog.lookup.amsterdam])
	var over: Dictionary=catalog.lookup.amsterdam
	var over_center=world.project(over.lon,over.lat)
	helicopter.position=over_center+Vector3(zone_radius_units(over)*.55,flight_altitude(),zone_radius_units(over)*.35)
	update_flight_camera(0.0,true)
	await get_tree().create_timer(1.2).timeout
	assert(fx.radar_shown>0,"Capture shows the records radar circle")
	get_viewport().get_texture().get_image().save_png("res://build/preview-radar.png")
	mode_select.select(GameMode.LEARN)
	return_menu()

# Quick visual pass over the interface and Europe: hangar, flight, feedback and cities.
# The homework screen, every aircraft with accessories, the accessory list
# and a few earned pilot looks, plus a jet and a plane in flight.
# Overhoren: Kaart A half filled in, then Kaart E marked with a few mistakes.
func capture_quiz() -> void:
	saved.mute=true
	seed(1206)
	order_rng.seed=1206
	DirAccess.make_dir_recursive_absolute("res://build")
	await get_tree().create_timer(.5).timeout
	saved.homework=["overzicht","west"]
	open_homework()
	homework_selected=["water"]
	refresh_homework()
	await get_tree().create_timer(.5).timeout
	get_viewport().get_texture().get_image().save_png("res://build/preview-huiswerk.png")
	start_homework_quiz()
	await get_tree().create_timer(.4).timeout
	for i in quiz_board.places.size()/2:
		quiz_board.assign(i,quiz_board.places[i].name)
	await get_tree().create_timer(.3).timeout
	# A finger dragging the next name: the ring aims above the finger at its dot.
	var next: int=quiz_board.places.size()/2
	var to_canvas: Transform2D=quiz_board.get_global_transform_with_canvas()
	# The capture window's own mouse would move the drag; only the scripted moves count here.
	quiz_board.set_process_input(false)
	var next_chip: Control=quiz_names.get_children().filter(func(c): return c.place_name==quiz_board.places[next].name)[0]
	quiz_board.begin_drag(quiz_board.places[next].name,-1,next_chip.get_global_rect().get_center(),true,next_chip)
	quiz_board.move_drag(to_canvas*(quiz_board.dot_at[next]+Vector2(6,4))-QuizBoard.TOUCH_LIFT)
	await get_tree().create_timer(.4).timeout
	get_viewport().get_texture().get_image().save_png("res://build/preview-overhoren.png")
	quiz_board.cancel_drag()
	quiz_board.set_process_input(true)
	close_quiz()
	open_homework()
	homework_selected=["west"]
	refresh_homework()
	start_homework_quiz()
	await get_tree().create_timer(.4).timeout
	for i in quiz_board.places.size():
		quiz_board.assign(i,quiz_board.places[i].name)
	quiz_board.assign(3,quiz_board.places[7].name)
	quiz_board.assign(7,quiz_board.places[3].name)
	quiz_board.unassign(quiz_board.places[11].name)
	check_quiz()
	await get_tree().create_timer(.4).timeout
	get_viewport().get_texture().get_image().save_png("res://build/preview-overhoren-nakijken.png")
	print("QUIZ CAPTURE PASSED")
	get_tree().quit()

func capture_hangar() -> void:
	saved.mute=true
	seed(1206)
	order_rng.seed=1206
	DirAccess.make_dir_recursive_absolute("res://build")
	saved.points=HangarCatalog.MAX_POINTS
	saved.medals=HangarCatalog.MEDALS.keys()
	saved.homework=["overzicht","west"]
	update_best_label()
	await get_tree().create_timer(.6).timeout
	get_viewport().get_texture().get_image().save_png("res://build/preview-menu-huiswerk.png")
	open_homework()
	toggle_homework("west")
	toggle_homework("noord")
	await get_tree().create_timer(.5).timeout
	get_viewport().get_texture().get_image().save_png("res://build/preview-huiswerk.png")
	close_homework()
	var sets={"molen":["ogen","ballonnen","wielen"],"wesp":["haaienbek","tanks","zwaailichten"],"coax":["radar","bluskorf","vlag"],
		"sport":["ogen","banner","rookspoor"],"dubbel":["haaienbek","regenboog","kroon"],"zee":["lichtslinger","koffer","vlag"],"dakota":["zonnepaneel","radar","wimpel"],
		"valk":["haaienbek","vuurwerk","meetneus"],"delta":["ogen","tanks","regenboog"],"schaduw":["kroon","rookspoor","zwaailichten"]}
	var showcase={"molen":"Traumageel","wesp":"Camouflage","coax":"Kustwacht","sport":"Racerood","dubbel":"Robijn","zee":"Oceaanblauw","dakota":"Woestijn","valk":"Marinegrijs","delta":"Europa","schaduw":"Nachtzwart"}
	open_paint_shop()
	show_hangar_page("type")
	for id in sets:
		saved.garage={"model":id,"accessories":sets[id],"rotor":1,"motor":2,"lights":1}
		apply_garage()
		paint_panel.find_child("Scheme_"+showcase[id],true,false).pressed.emit()
		await get_tree().create_timer(.7).timeout
		get_viewport().get_texture().get_image().save_png("res://build/preview-hangar-"+id+".png")
	var scroll: ScrollContainer=paint_panel.find_child("TypeScroll",true,false)
	scroll.scroll_vertical=10000
	await get_tree().create_timer(.3).timeout
	get_viewport().get_texture().get_image().save_png("res://build/preview-hangar-types-jets.png")
	show_hangar_page("accessoires")
	await get_tree().create_timer(.3).timeout
	get_viewport().get_texture().get_image().save_png("res://build/preview-hangar-accessoires-lijst.png")
	close_paint_shop()
	var looks=[{"figuur":"vrouw","haar":"afro","haarkleur":"8a4fd8","hoofd":"kroon","outfit":"superheld","kleur":"264a7a","extra":"papegaai","bril":"hartjes"},
		{"figuur":"man","huid":"8fd16a","haar":"hanenkam","haarkleur":"3fbf6a","hoofd":"geen","outfit":"astronaut","kleur":"e8453a","extra":"vlag","gezicht":"blosjes"},
		{"figuur":"man","haar":"dreads","hoofd":"piraat","bril":"ooglap","outfit":"piraat","gezicht":"krulsnor","extra":"landkaart"},
		{"figuur":"vrouw","haar":"knotjes","haarkleur":"e8c33a","hoofd":"propellerpet","outfit":"voetbal","kleur":"e67b34","bril":"sterren","extra":"rugzak"},
		{"figuur":"man","haar":"kuif","hoofd":"baret","outfit":"smoking","kleur":"c8211d","gezicht":"kerstbaard","extra":"teddybeer"},
		{"figuur":"vrouw","haar":"bob","hoofd":"astronaut","outfit":"ridder","kleur":"5c1428","bril":"skibril","extra":"parachute"}]
	open_pilots()
	for i in looks.size():
		saved.look=PilotFigure.clean(looks[i])
		refresh_pilots()
		pilot_preview.rotation.y=PI
		await get_tree().create_timer(.5).timeout
		get_viewport().get_texture().get_image().save_png("res://build/preview-piloot-%d.png" % (i+1))
	close_pilots()
	for id in ["valk","sport"]:
		saved.garage={"model":id,"accessories":["regenboog"] if id=="valk" else ["banner","rookspoor"],"rotor":1,"motor":2,"lights":1}
		apply_garage()
		start_mission([catalog.lookup.amsterdam,catalog.lookup.rotterdam])
		helicopter.position=world.project(5.0,52.23)+Vector3(0,flight_altitude(),0)
		for i in 40:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("res://build/preview-flight-"+id+".png")
		return_menu()
	# Locked items behind a padlock, one of them tried on the preview stage.
	saved.points=120
	saved.medals=[]
	saved.garage=HangarCatalog.DEFAULT_GARAGE.duplicate(true)
	open_paint_shop()
	show_hangar_page("type")
	choose_model("valk")
	await get_tree().create_timer(.7).timeout
	get_viewport().get_texture().get_image().save_png("res://build/preview-hangar-voorproefje.png")
	show_hangar_page("kleuren")
	choose_scheme(HangarCatalog.SCHEMES[-1])
	await get_tree().create_timer(.5).timeout
	get_viewport().get_texture().get_image().save_png("res://build/preview-hangar-voorproefje-kleur.png")
	close_paint_shop()
	saved.look=PilotFigure.DEFAULT_LOOK.duplicate()
	open_pilots()
	step_look("haar",-1)
	step_look("hoofd",-1)
	pilot_preview.rotation.y=PI
	await get_tree().create_timer(.5).timeout
	get_viewport().get_texture().get_image().save_png("res://build/preview-piloot-voorproefje.png")
	close_pilots()
	print("HANGAR CAPTURE PASSED")
	get_tree().quit()

func capture_ui() -> void:
	saved.mute=true
	DirAccess.make_dir_recursive_absolute("res://build")
	await get_tree().create_timer(.6).timeout
	get_viewport().get_texture().get_image().save_png("res://build/ui-hangar.png")
	await capture_effects()
	load_world("eu")
	region_select.select(1)
	europe_route_select.select(3)
	update_best_label()
	await get_tree().create_timer(.5).timeout
	get_viewport().get_texture().get_image().save_png("res://build/ui-hangar-europe.png")
	for city in ["londen","parijs","barcelona","istanbul","moskou","wenen","napels","venetie","keulen","boedapest","kopenhagen"]:
		var place: Dictionary=catalog.resolve(city,"eu")
		mode_select.select(GameMode.LEARN)
		start_mission([place])
		helicopter.position=world.project(place.lon,place.lat)+Vector3(0,flight_altitude(),0)
		camera_level=0
		camera.size=flight_zoom()
		await get_tree().create_timer(1.2).timeout
		get_viewport().get_texture().get_image().save_png("res://build/ui-europe-"+city+".png")
	start_mission([catalog.resolve("Alpen","eu")])
	helicopter.position=world.project(9.0,47.2)+Vector3(0,flight_altitude(),0)
	change_height(1)
	change_height(1)
	await get_tree().create_timer(1.5).timeout
	get_viewport().get_texture().get_image().save_png("res://build/ui-europe-alpen.png")
	toggle_overview()
	await get_tree().create_timer(1.5).timeout
	get_viewport().get_texture().get_image().save_png("res://build/ui-europe-overview.png")
	print("UI CAPTURE PASSED")
	get_tree().quit()

# Learning aids: the locator card after a hit, the practice direction arrow
# and the heading-up minimap, in the Netherlands and in Europe.
func capture_learning() -> void:
	var previous_region=region
	if region!="nl":
		load_world("nl")
	mode_select.select(GameMode.LEARN)
	seed(7)
	order_rng.seed=7
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
	if not top_overlay().is_empty():
		return
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
			apply_online_content(FileAccess.get_file_as_string("user://missions.json"),true)
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

# Says why a lesson-pack download failed. The HTTP code is 0 for every transport failure.
func online_error_message(result: int,code: int) -> String:
	var keep=" Eerdere missies blijven beschikbaar."
	match result:
		HTTPRequest.RESULT_TIMEOUT:
			return "Het ophalen duurde te lang."+keep
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "Beveiligde verbinding mislukt (certificaat). Controleer de HTTPS-link."+keep
		HTTPRequest.RESULT_CANT_RESOLVE, HTTPRequest.RESULT_CANT_CONNECT, HTTPRequest.RESULT_CONNECTION_ERROR, HTTPRequest.RESULT_NO_RESPONSE:
			return "Geen verbinding. Controleer je internet en de link."+keep
		HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED:
			return "De link stuurt door naar een ander adres. Gebruik de directe HTTPS-link naar het JSON-bestand."+keep
		HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED:
			return "Het missiepakket is groter dan 256 KB."+keep
	if result!=HTTPRequest.RESULT_SUCCESS:
		return "Ophalen mislukt."+keep
	if code>=300 and code<400:
		return "De link stuurt door naar een ander adres. Gebruik de directe HTTPS-link naar het JSON-bestand."+keep
	return "Ophalen mislukt (%d)." % code+keep

func online_content_received(result: int,code: int,_headers: PackedStringArray,body: PackedByteArray) -> void:
	if result!=HTTPRequest.RESULT_SUCCESS or code!=200:
		push_warning("Missies ophalen mislukt: resultaat %d, status %d." % [result,code])
		content_status.text=online_error_message(result,code)
		return
	var text=body.get_string_from_utf8()
	# The cache is replaced atomically, so an interrupted write keeps the previous packs.
	if apply_online_content(text) and not ProgressStore.write_atomic("user://missions.json",text).is_empty():
		content_status.text="Missies geladen; offline bewaren is niet gelukt."

# A downloaded pack must be valid as a whole. The offline copy (from_cache) skips the missions that
# no longer validate, for instance after a catalog rename, and keeps the rest.
func apply_online_content(text: String,from_cache: bool=false) -> bool:
	var raw: Variant=JSON.parse_string(text)
	if not raw is Dictionary or raw.get("version")!=1 or not raw.get("missions") is Array or raw.missions.is_empty() or raw.missions.size()>100:
		content_status.text="Ongeldig missiepakket. Verwacht versie 1 met maximaal 100 missies."
		return false
	var packs: Array=[]
	var skipped=0
	var problem=""
	for pack in raw.missions:
		var parsed=parse_online_pack(pack)
		if parsed.error.is_empty():
			packs.append(parsed.pack)
			continue
		problem=parsed.error
		if not from_cache:
			content_status.text=problem
			return false
		skipped+=1
	if packs.is_empty():
		content_status.text=problem
		return false
	online_packs=packs
	content_list.clear()
	for pack in packs:
		content_list.add_item("%s · %d locaties" % [pack.title,pack.places.size()])
	content_list.select(0)
	content_status.text="%d missies beschikbaar. Kies een missie en vertrek!" % packs.size()
	if skipped>0:
		content_status.text+=" %d overgeslagen: niet meer geldig." % skipped
	return true

# One mission of a lesson pack: {"pack": {title, places, region}} or {"error": Dutch reason}.
func parse_online_pack(pack: Variant) -> Dictionary:
	if not pack is Dictionary or not pack.get("title") is String or pack.title.strip_edges().is_empty() or pack.title.length()>100 or not pack.get("places") is Array or pack.places.is_empty() or pack.places.size()>100:
		return {"error":"Een missie heeft een ongeldige titel of locatielijst."}
	var names=PackedStringArray()
	for place in pack.places:
		if not place is String or place.length()>120:
			return {"error":"Een locatie is ongeldig."}
		names.append(place)
	# Optional "region": "nl" or "eu" picks the map for names both maps have (Noordzee, Rijn).
	var pack_region: String=String(pack.get("region","")) if pack.get("region","") is String else "?"
	if pack_region not in ["","nl","eu"]:
		return {"error":"Missie %s: region moet \"nl\" of \"eu\" zijn." % pack.title}
	var parsed=catalog.parse_list("\n".join(names),pack_region)
	if not parsed.unknown.is_empty() or parsed.found.is_empty():
		return {"error":"Onbekende locaties in %s: %s" % [pack.title,", ".join(parsed.unknown)]}
	return {"error":"","pack":{"title":pack.title,"places":parsed.found,"region":pack_region}}

func start_online_mission() -> void:
	var selected=content_list.get_selected_items()
	if selected.is_empty():
		return
	var places: Array=online_packs[selected[0]].places
	var target_region="eu" if online_packs[selected[0]].region=="eu" else "nl"
	for place in places:
		if place.region!="nl":
			target_region="eu"
	region_select.select(0 if target_region=="nl" else 1)
	load_world(target_region)
	content_dialog.hide()
	start_mission(places)
