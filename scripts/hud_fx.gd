class_name HudFx
extends Control

# Screen-space effects on top of the HUD: a big red cross for a miss, a gold
# banner for a hit, coloured edge flashes, confetti for a finished mission
# and a cinematic vignette. Nothing here takes mouse or touch input.
const RED = Color("ff2d3d")
const GOLD = Color("ffc35c")
const GREEN = Color("5cff8f")

class BigCross:
	extends Control
	var thickness: float = 30.0
	func _draw() -> void:
		var c = size * .5
		var arm = minf(size.x, size.y) * .42
		for layer in [[Color(.18, 0, .02, .75), thickness + 16.0], [Color("8f0010"), thickness + 6.0], [Color("ff2d3d"), thickness], [Color(1, .62, .6, .9), thickness * .28]]:
			for d in [Vector2(1, 1), Vector2(1, -1)]:
				var a = c - d * arm
				var b = c + d * arm
				draw_line(a, b, layer[0], layer[1], true)
				draw_circle(a, layer[1] * .5, layer[0])
				draw_circle(b, layer[1] * .5, layer[0])

# Rotating sunburst behind the hit banner.
class Burst:
	extends Control
	var color: Color = Color(1, .79, .29, .5)
	func _draw() -> void:
		var c = size * .5
		var reach = maxf(size.x, size.y) * .5
		for i in 16:
			var a0 = TAU * i / 16.0
			var a1 = a0 + TAU / 32.0
			var tone = Color(color.r, color.g, color.b, color.a * (1.0 if i % 2 == 0 else .55))
			draw_colored_polygon(PackedVector2Array([c, c + Vector2(cos(a0), sin(a0)) * reach, c + Vector2(cos(a1), sin(a1)) * reach]), tone)
		draw_circle(c, reach * .22, Color(1, .95, .75, color.a * .6))

var vignette: ColorRect
var vignette_material: ShaderMaterial
var cross: BigCross
var cross_label: Label
var banner: VBoxContainer
var banner_title: Label
var banner_detail: Label
var confetti: CPUParticles2D
var font: Font
var burst: Burst
var streak_label: Label
var burst_tween: Tween
var flash_tween: Tween
var cross_tween: Tween
var banner_tween: Tween
var crosses_shown: int = 0
var banners_shown: int = 0
# 'Rustige beelden': no flashes, shake, spinning, confetti or bouncy tweens.
# The cross, banner and text still show, just without the motion.
var calm: bool = false

# The vignette exists before _ready so the owner can place it below the HUD.
func _init() -> void:
	vignette = ColorRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette_material = ShaderMaterial.new()
	vignette_material.shader = load("res://assets/shaders/vignette.gdshader")
	vignette.material = vignette_material

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = UiFonts.font("display")
	burst = Burst.new()
	burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(burst)
	burst.set_anchors_preset(Control.PRESET_CENTER_TOP)
	burst.offset_left = -260
	burst.offset_right = 260
	burst.offset_top = -62
	burst.offset_bottom = 458
	burst.pivot_offset = Vector2(260, 260)
	burst.hide()
	# The holder is anchored; the cross inside it can shake around x=0.
	var holder = Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	holder.set_anchors_preset(Control.PRESET_CENTER)
	holder.offset_left = -150
	holder.offset_top = -190
	holder.offset_right = 150
	holder.offset_bottom = 110
	cross = BigCross.new()
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cross.size = Vector2(300, 300)
	cross.pivot_offset = Vector2(150, 150)
	holder.add_child(cross)
	cross.hide()
	cross_label = big_label("MIS!", 76, RED, Color("5c0010"))
	add_child(cross_label)
	cross_label.set_anchors_preset(Control.PRESET_CENTER)
	cross_label.offset_left = -300
	cross_label.offset_right = 300
	cross_label.offset_top = 112
	cross_label.offset_bottom = 182
	cross_label.pivot_offset = Vector2(300, 35)
	cross_label.hide()
	banner = VBoxContainer.new()
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(banner)
	banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner.offset_left = -360
	banner.offset_right = 360
	banner.offset_top = 128
	banner.offset_bottom = 318
	banner.pivot_offset = Vector2(360, 70)
	banner_title = big_label("GOED ZO!", 92, GOLD, Color("8a3205"))
	banner.add_child(banner_title)
	banner_detail = big_label("", 30, Color("fff6dc"))
	banner_detail.add_theme_font_override("font", UiFonts.font("black"))
	var plate = StyleBoxFlat.new()
	plate.bg_color = Color(.02, .08, .11, .82)
	plate.set_corner_radius_all(14)
	plate.border_color = Color(GOLD, .7)
	plate.set_border_width_all(2)
	plate.content_margin_left = 22
	plate.content_margin_right = 22
	plate.content_margin_top = 2
	plate.content_margin_bottom = 4
	banner_detail.add_theme_stylebox_override("normal", plate)
	banner_detail.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	banner.add_child(banner_detail)
	streak_label = big_label("", 26, Color("0b2530"), Color(0, 0, 0, 0))
	streak_label.add_theme_font_override("font", UiFonts.font("black"))
	streak_label.add_theme_constant_override("outline_size", 0)
	var streak_plate = plate.duplicate()
	streak_plate.bg_color = GREEN
	streak_plate.border_color = Color("1f8a4c")
	streak_plate.border_width_bottom = 4
	streak_label.add_theme_stylebox_override("normal", streak_plate)
	streak_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	banner.add_child(streak_label)
	banner.hide()
	confetti = CPUParticles2D.new()
	confetti.emitting = false
	confetti.one_shot = true
	confetti.amount = 220
	confetti.lifetime = 3.2
	confetti.explosiveness = .85
	confetti.direction = Vector2(0, 1)
	confetti.spread = 80
	confetti.initial_velocity_min = 180
	confetti.initial_velocity_max = 520
	confetti.gravity = Vector2(0, 380)
	confetti.damping_min = 30
	confetti.damping_max = 60
	confetti.angular_velocity_min = -540
	confetti.angular_velocity_max = 540
	confetti.angle_min = 0
	confetti.angle_max = 360
	confetti.scale_amount_min = 6
	confetti.scale_amount_max = 11
	confetti.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	confetti.emission_rect_extents = Vector2(640, 10)
	var colors = FlightFx.gradient([0.0, .15, .32, .49, .66, .83], [Color("ffd166"), Color("ef476f"), Color("06d6a0"), Color("f72585"), Color("ffffff"), Color("4cc9f0")])
	colors.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	confetti.color_initial_ramp = colors
	var fade = FlightFx.gradient([0.0, .8, 1.0], [Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	confetti.color_ramp = fade
	add_child(confetti)
	resized.connect(place_confetti)

func place_confetti() -> void:
	confetti.position = Vector2(size.x * .5, -20)
	confetti.emission_rect_extents = Vector2(size.x * .5, 10)

# Arcade lettering: thick dark outline plus a solid extruded shadow in a deep
# shade of the text colour, so GOED ZO! and MIS! read like stickers.
func big_label(text: String, size_px: int, color: Color, extrude: Color = Color(0, 0, 0, .5)) -> Label:
	var l = Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color("06161c"))
	l.add_theme_constant_override("outline_size", maxi(6, size_px / 5))
	l.add_theme_color_override("font_shadow_color", extrude)
	l.add_theme_constant_override("shadow_offset_y", maxi(4, size_px / 11))
	l.add_theme_constant_override("shadow_outline_size", maxi(6, size_px / 5))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func flash(color: Color, amount: float = .55, seconds: float = .7) -> void:
	if flash_tween:
		flash_tween.kill()
	if calm:
		vignette_material.set_shader_parameter("flash_color", Color(color.r, color.g, color.b, 0.0))
		return
	vignette_material.set_shader_parameter("flash_color", Color(color.r, color.g, color.b, amount))
	flash_tween = create_tween()
	flash_tween.tween_method(func(a: float): vignette_material.set_shader_parameter("flash_color", Color(color.r, color.g, color.b, a)), amount, 0.0, seconds).set_ease(Tween.EASE_IN)

func show_miss(message: String = "MIS!") -> void:
	crosses_shown += 1
	if cross_tween:
		cross_tween.kill()
	cross_label.text = message
	cross.show()
	cross_label.show()
	cross.queue_redraw()
	if calm:
		# Plain fade in and out: no pop, spin or shake.
		cross.scale = Vector2.ONE
		cross.rotation = 0.0
		cross.position.x = 0.0
		cross_label.scale = Vector2.ONE
		cross.modulate.a = 0.0
		cross_label.modulate.a = 0.0
		cross_tween = create_tween().set_parallel(true)
		cross_tween.tween_property(cross, "modulate:a", 1.0, .2)
		cross_tween.tween_property(cross_label, "modulate:a", 1.0, .2)
		cross_tween.chain().tween_interval(.9)
		cross_tween.chain().tween_property(cross, "modulate:a", 0.0, .35)
		cross_tween.parallel().tween_property(cross_label, "modulate:a", 0.0, .35)
		cross_tween.chain().tween_callback(hide_miss)
		return
	cross.scale = Vector2.ONE * 1.9
	cross.rotation = -.35
	cross.modulate.a = 0.0
	cross_label.modulate.a = 0.0
	cross_label.scale = Vector2.ONE * .6
	flash(RED, .7, .8)
	cross_tween = create_tween().set_parallel(true)
	cross_tween.tween_property(cross, "scale", Vector2.ONE, .28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	cross_tween.tween_property(cross, "rotation", 0.0, .28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	cross_tween.tween_property(cross, "modulate:a", 1.0, .12)
	cross_tween.tween_property(cross_label, "modulate:a", 1.0, .15).set_delay(.08)
	cross_tween.tween_property(cross_label, "scale", Vector2.ONE, .3).set_delay(.08).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	# A short horizontal shake sells the "no!" before it fades.
	cross.position.x = 0.0
	var shake = create_tween()
	shake.tween_interval(.28)
	for i in 6:
		shake.tween_property(cross, "position:x", (14.0 if i % 2 == 0 else -14.0) * (1.0 - i / 6.0), .04)
	shake.tween_property(cross, "position:x", 0.0, .04)
	cross_tween.chain().tween_interval(.75)
	cross_tween.chain().tween_property(cross, "modulate:a", 0.0, .35)
	cross_tween.parallel().tween_property(cross_label, "modulate:a", 0.0, .35)
	cross_tween.chain().tween_callback(hide_miss)

func hide_miss() -> void:
	cross.hide()
	cross_label.hide()

func show_hit(title_text: String, detail: String, streak: int = 0) -> void:
	banners_shown += 1
	if banner_tween:
		banner_tween.kill()
	if burst_tween:
		burst_tween.kill()
	banner_title.text = title_text
	banner_detail.text = detail
	streak_label.text = "%d× OP RIJ!" % streak if streak >= 2 else ""
	streak_label.visible = streak >= 2
	banner.show()
	if calm:
		burst.hide()
		banner.scale = Vector2.ONE
		banner.modulate.a = 0.0
		banner_tween = create_tween()
		banner_tween.tween_property(banner, "modulate:a", 1.0, .2)
		banner_tween.tween_interval(1.1)
		banner_tween.tween_property(banner, "modulate:a", 0.0, .4)
		banner_tween.tween_callback(banner.hide)
		return
	burst.show()
	burst.queue_redraw()
	burst.modulate.a = 0.0
	burst.scale = Vector2.ONE * .3
	burst_tween = create_tween().set_parallel(true)
	burst_tween.tween_property(burst, "modulate:a", 1.0, .12)
	burst_tween.tween_property(burst, "scale", Vector2.ONE, .4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	burst_tween.tween_property(burst, "rotation", burst.rotation + .9, 1.7)
	burst_tween.chain().tween_property(burst, "modulate:a", 0.0, .35)
	burst_tween.chain().tween_callback(burst.hide)
	banner.modulate.a = 0.0
	banner.scale = Vector2.ONE * .4
	flash(GOLD, .45, .9)
	banner_tween = create_tween().set_parallel(true)
	banner_tween.tween_property(banner, "scale", Vector2.ONE, .45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	banner_tween.tween_property(banner, "modulate:a", 1.0, .15)
	banner_tween.chain().tween_interval(1.1)
	banner_tween.chain().tween_property(banner, "modulate:a", 0.0, .4)
	banner_tween.parallel().tween_property(banner, "scale", Vector2.ONE * 1.15, .4)
	banner_tween.chain().tween_callback(banner.hide)

func celebrate() -> void:
	move_to_front()
	if calm:
		return
	place_confetti()
	confetti.restart()
	confetti.emitting = true
	flash(GREEN, .4, 1.2)

func clear() -> void:
	for t in [flash_tween, cross_tween, banner_tween, burst_tween]:
		if t:
			t.kill()
	burst.hide()
	vignette_material.set_shader_parameter("flash_color", Color(1, 0, 0, 0))
	cross.hide()
	cross_label.hide()
	banner.hide()
