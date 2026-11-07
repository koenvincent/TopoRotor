class_name FlightFx
extends Node3D

# 3D effects layer: the goal zone (answer range as a circle plus a beacon),
# fireworks for a correct answer, a red cross on the ground for a miss and
# rotor downwash. It lives beside the world so a region reload keeps it.
const ZONE_EXTENT = 1.3
const FIREWORK_COLORS = [Color("ffd166"), Color("ef476f"), Color("06d6a0"), Color("4cc9f0"), Color("f72585"), Color("ffffff"), Color("ff9f1c")]

var sfx: SfxBank
var zone: Node3D
var zone_disc: MeshInstance3D
var zone_material: ShaderMaterial
var beacon: MeshInstance3D
var beacon_material: ShaderMaterial
var marker: MeshInstance3D
var marker_material: StandardMaterial3D
var zone_radius: float = 4.0
var zone_has_ring: bool = true
var inside_amount: float = 0.0
var inside: bool = false
var view_scale: float = 1.0
var time: float = 0.0
var downwash: CPUParticles3D
var sight: MeshInstance3D
var sight_material: ShaderMaterial
var plumb: MeshInstance3D
var plumb_material: StandardMaterial3D
var spark_texture: GradientTexture2D
var spark_material: StandardMaterial3D
var bursts_started: int = 0
var misses_shown: int = 0
var rng = RandomNumberGenerator.new()
const RADAR_COLOR = Color("5ce1ff")
var radar_rings: Array = []
var radar_shown: int = 0
# 'Rustige beelden': shaders hold still, the beacon and marker stop pulsing and
# bobbing, and a correct answer skips the rockets and the light flash.
var calm: bool = false

func _ready() -> void:
	rng.randomize()
	spark_texture = soft_dot()
	spark_material = particle_material()
	build_zone()
	build_downwash()
	build_sight()
	set_calm(calm)

# The chase camera looks down at an angle, so the helicopter appears north of
# the ground point the game checks. A sight on the ground plus a plumb line
# shows exactly where "here" is.
func build_sight() -> void:
	sight = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2.ONE * 2.0
	sight.mesh = plane
	sight_material = ShaderMaterial.new()
	sight_material.shader = load("res://assets/shaders/reticle.gdshader")
	sight.material_override = sight_material
	sight.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sight.visible = false
	add_child(sight)
	plumb = MeshInstance3D.new()
	var line = CylinderMesh.new()
	line.top_radius = .05
	line.bottom_radius = .05
	line.height = 1.0
	line.radial_segments = 6
	line.cap_top = false
	line.cap_bottom = false
	plumb.mesh = line
	plumb_material = StandardMaterial3D.new()
	plumb_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	plumb_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	plumb_material.albedo_color = Color(1, 1, .9, .45)
	plumb.material_override = plumb_material
	plumb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	plumb.visible = false
	add_child(plumb)

# 1.0 lets the overlay shaders animate, 0.0 freezes them.
func motion_amount() -> float:
	return 0.0 if calm else 1.0

func set_calm(value: bool) -> void:
	calm = value
	for m in [zone_material, beacon_material, sight_material]:
		if m:
			m.set_shader_parameter("motion", motion_amount())
	for ring in radar_rings:
		ring.material_override.set_shader_parameter("motion", motion_amount())

# The sight turns green over the goal only while the goal is on show. With the
# neutral radar rings out, or the target hidden by the mode, the colour stays
# the same over every place, so the sight can never give the answer away.
func sight_tint() -> float:
	if radar_shown > 0 or not zone.is_visible_in_tree():
		return 0.0
	return inside_amount

func update_sight(aircraft: Vector3, active: bool) -> void:
	sight.visible = active
	plumb.visible = active
	if not active:
		return
	sight.global_position = Vector3(aircraft.x, .34, aircraft.z)
	sight.scale = Vector3.ONE * view_scale * 1.1
	var color = (RADAR_COLOR if radar_shown > 0 else Color("fffbe8")).lerp(HudFx.GREEN, sight_tint())
	sight_material.set_shader_parameter("sight_color", Vector3(color.r, color.g, color.b))
	plumb_material.albedo_color = Color(color.r, color.g, color.b, .5)
	var top = maxf(aircraft.y - 1.0 * view_scale, .5)
	plumb.global_position = Vector3(aircraft.x, top * .5, aircraft.z)
	plumb.scale = Vector3(view_scale, top, view_scale)

# Explicit offsets and colours: Gradient.set_color(index) after add_point
# addresses insertion order, not offset order, which is easy to get wrong.
static func gradient(offsets: Array, colors: Array) -> Gradient:
	var g = Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	return g

static func soft_dot() -> GradientTexture2D:
	var g = gradient([0.0, .25, 1.0], [Color(1, 1, 1, 1), Color(1, 1, 1, .85), Color(1, 1, 1, 0)])
	var t = GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(.5, .5)
	t.fill_to = Vector2(1, .5)
	t.width = 64
	t.height = 64
	return t

func particle_material(additive: bool = true) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = spark_texture
	m.no_depth_test = additive
	return m

func quad(size: float, material: Material) -> QuadMesh:
	var q = QuadMesh.new()
	q.size = Vector2.ONE * size
	q.material = material
	return q

func build_zone() -> void:
	zone = Node3D.new()
	zone_disc = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2.ONE * 2.0
	zone_disc.mesh = plane
	zone_material = ShaderMaterial.new()
	zone_material.shader = load("res://assets/shaders/target_zone.gdshader")
	zone_material.set_shader_parameter("extent", ZONE_EXTENT)
	zone_disc.material_override = zone_material
	zone_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	zone_disc.position.y = .3
	zone.add_child(zone_disc)
	beacon = MeshInstance3D.new()
	var tube = CylinderMesh.new()
	tube.top_radius = .55
	tube.bottom_radius = .9
	tube.height = 1.0
	tube.cap_top = false
	tube.cap_bottom = false
	tube.radial_segments = 20
	beacon.mesh = tube
	beacon_material = ShaderMaterial.new()
	beacon_material.shader = load("res://assets/shaders/beacon.gdshader")
	beacon.material_override = beacon_material
	beacon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	zone.add_child(beacon)
	marker = MeshInstance3D.new()
	var cone = CylinderMesh.new()
	cone.top_radius = .85
	cone.bottom_radius = 0.0
	cone.height = 1.5
	cone.radial_segments = 4
	cone.rings = 1
	marker.mesh = cone
	marker_material = StandardMaterial3D.new()
	marker_material.albedo_color = HudFx.GOLD
	marker_material.emission_enabled = true
	marker_material.emission = Color("ffb340")
	marker_material.emission_energy_multiplier = 1.4
	marker_material.metallic = .4
	marker_material.roughness = .3
	marker.material_override = marker_material
	zone.add_child(marker)

# Re-parented onto the world's target node, so the target's visibility (the
# mode rules decide that) also hides or shows the zone.
func attach_target(target: Node3D) -> void:
	if zone.get_parent():
		zone.get_parent().remove_child(zone)
	target.add_child(zone)

# Called before the world (and with it the target node) is freed.
func detach_zone() -> void:
	if zone.get_parent():
		zone.get_parent().remove_child(zone)

# east_stretch widens the circle east-west where the flat map projection
# squeezes longitude, so the ring traces the real great-circle range.
func set_zone(radius_units: float, with_ring: bool, east_stretch: float = 1.0) -> void:
	zone_radius = maxf(radius_units, .2)
	zone_has_ring = with_ring
	zone_disc.visible = with_ring
	zone_disc.scale = Vector3(zone_radius * ZONE_EXTENT * east_stretch, 1.0, zone_radius * ZONE_EXTENT)
	inside_amount = 0.0
	inside = false

func set_inside(value: bool) -> void:
	inside = value

# Records radar: the range circle of every candidate place the pilot is over,
# all in the same neutral colour, so it confirms "you are inside this place's
# range" without telling whether that place is the goal.
func show_radar(rings: Array) -> void:
	while radar_rings.size() < rings.size():
		var ring = MeshInstance3D.new()
		var plane = PlaneMesh.new()
		plane.size = Vector2.ONE * 2.0
		ring.mesh = plane
		var m = ShaderMaterial.new()
		m.shader = load("res://assets/shaders/target_zone.gdshader")
		m.set_shader_parameter("extent", ZONE_EXTENT)
		m.set_shader_parameter("zone_color", Vector3(RADAR_COLOR.r, RADAR_COLOR.g, RADAR_COLOR.b))
		m.set_shader_parameter("inside", 0.0)
		m.set_shader_parameter("motion", motion_amount())
		ring.material_override = m
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)
		radar_rings.append(ring)
	for i in radar_rings.size():
		var ring = radar_rings[i]
		ring.visible = i < rings.size()
		if ring.visible:
			var r = maxf(float(rings[i].radius), .2)
			ring.position = Vector3(rings[i].at.x, .31, rings[i].at.z)
			ring.scale = Vector3(r * ZONE_EXTENT * float(rings[i].get("stretch", 1.0)), 1.0, r * ZONE_EXTENT)
			ring.set_meta("radius", r)
	radar_shown = rings.size()

func _process(delta: float) -> void:
	time += delta
	inside_amount = move_toward(inside_amount, 1.0 if inside else 0.0, delta * 4.0)
	zone_material.set_shader_parameter("inside", inside_amount)
	# Keep the edge line a few pixels wide however large the ring is on screen.
	zone_material.set_shader_parameter("edge_width", clampf(.24 * pow(view_scale, .8) / maxf(zone_radius, .1), .018, .2))
	for ring in radar_rings:
		if ring.visible:
			ring.material_override.set_shader_parameter("edge_width", clampf(.24 * pow(view_scale, .8) / float(ring.get_meta("radius", 1.0)), .018, .2))
	var tall = 26.0 * view_scale
	beacon.scale = Vector3(view_scale * .9, tall, view_scale * .9)
	beacon.position.y = tall * .5
	var glow = HudFx.GOLD.lerp(HudFx.GREEN, inside_amount)
	beacon_material.set_shader_parameter("beam_color", Vector3(glow.r, glow.g, glow.b))
	beacon_material.set_shader_parameter("strength", .75 if calm else .75 + .35 * sin(time * 4.0))
	marker.scale = Vector3.ONE * view_scale * 1.25
	marker.position.y = (6.5 if calm else 6.5 + sin(time * 2.6) * .7) * view_scale
	marker.rotation.y = 0.0 if calm else time * 1.8
	marker_material.albedo_color = glow
	marker_material.emission = glow

func build_downwash() -> void:
	downwash = CPUParticles3D.new()
	downwash.amount = 46
	downwash.lifetime = 1.1
	downwash.local_coords = false
	downwash.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	downwash.emission_ring_axis = Vector3.UP
	downwash.emission_ring_radius = 1.4
	downwash.emission_ring_inner_radius = .6
	downwash.emission_ring_height = .05
	downwash.direction = Vector3(1, .15, 0)
	downwash.spread = 180
	downwash.flatness = .85
	downwash.initial_velocity_min = 2.5
	downwash.initial_velocity_max = 4.5
	downwash.radial_accel_min = 2.0
	downwash.radial_accel_max = 4.0
	downwash.gravity = Vector3.ZERO
	downwash.damping_min = 1.5
	downwash.damping_max = 2.5
	downwash.scale_amount_min = .8
	downwash.scale_amount_max = 1.6
	var curve = Curve.new()
	curve.add_point(Vector2(0, .4))
	curve.add_point(Vector2(1, 1.6))
	downwash.scale_amount_curve = curve
	var ramp = gradient([0.0, .15, 1.0], [Color(.95, .93, .82, .0), Color(.95, .93, .82, .32), Color(.95, .93, .82, 0)])
	downwash.color_ramp = ramp
	downwash.mesh = quad(1.1, particle_material(false))
	downwash.emitting = false
	add_child(downwash)

# Dust rings stronger the lower the helicopter flies.
func update_downwash(aircraft: Vector3, altitude_level: int, speed_fraction: float, active: bool) -> void:
	# Only the lowest flight level is close enough to the ground to stir up dust.
	downwash.emitting = active and altitude_level == 0
	downwash.global_position = Vector3(aircraft.x, .25, aircraft.z)
	downwash.scale = Vector3.ONE * view_scale * 1.35
	downwash.speed_scale = .8 + speed_fraction * .6

# Three to five rockets around the goal, each with trail, burst, glitter,
# a flash of light and a shock ring on the ground.
func celebrate(at: Vector3) -> void:
	var s = view_scale
	shockwave(Vector3(at.x, .35, at.z), zone_radius * 1.6 if zone_has_ring else 8.0 * s)
	if calm:
		return
	var rockets = rng.randi_range(3, 5)
	for i in rockets:
		var offset = Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(-6, 6)) * s
		var apex = Vector3(at.x, 0, at.z) + offset + Vector3(0, rng.randf_range(10, 15) * s, 0)
		launch_rocket(Vector3(at.x, .5, at.z) + offset * .3, apex, FIREWORK_COLORS[rng.randi() % FIREWORK_COLORS.size()], i * .22)

func launch_rocket(from: Vector3, apex: Vector3, color: Color, delay: float) -> void:
	bursts_started += 1
	var trail = CPUParticles3D.new()
	trail.amount = 40
	trail.lifetime = .5
	trail.local_coords = false
	trail.direction = Vector3.DOWN
	trail.spread = 20
	trail.initial_velocity_min = 1.0
	trail.initial_velocity_max = 2.5
	trail.gravity = Vector3(0, -3, 0)
	trail.scale_amount_min = .5
	trail.scale_amount_max = .9
	var ramp = gradient([0.0, 1.0], [Color(1, .95, .8, 1), Color(color.r, color.g, color.b, 0)])
	trail.color_ramp = ramp
	trail.mesh = quad(.45 * view_scale, spark_material)
	trail.position = from
	trail.emitting = false
	add_child(trail)
	# Tweens bound to the node die with it when effects are cleared.
	var tween = trail.create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(func():
		trail.emitting = true
		if sfx:
			sfx.play("whistle", rng.randf_range(.9, 1.15)))
	tween.tween_property(trail, "position", apex, .65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		trail.emitting = false
		explode(apex, color))
	tween.tween_interval(1.0)
	tween.tween_callback(trail.queue_free)

func explode(at: Vector3, color: Color) -> void:
	var s = view_scale
	var main_burst = sparks(at, color, 120, 1.8, 10.0 * s, 14.0 * s, .5 * s, .08)
	main_burst.gravity = Vector3(0, -5.0 * s, 0)
	var second = color.lerp(FIREWORK_COLORS[rng.randi() % FIREWORK_COLORS.size()], .7)
	var ring_burst = sparks(at, second, 70, 1.4, 5.0 * s, 6.5 * s, .4 * s, .08)
	ring_burst.gravity = Vector3(0, -3.0 * s, 0)
	var core = sparks(at, Color.WHITE, 14, .35, 1.5 * s, 3.0 * s, .9 * s, .0)
	core.gravity = Vector3.ZERO
	var glitter = sparks(at, Color("fff3c4"), 60, 1.2, 4.0 * s, 7.0 * s, .25 * s, .3)
	glitter.gravity = Vector3(0, -3.0 * s, 0)
	glitter.emitting = false
	var flash = OmniLight3D.new()
	flash.light_color = color
	flash.light_energy = 6.0
	flash.omni_range = 22.0 * s
	flash.shadow_enabled = false
	flash.position = at
	add_child(flash)
	var tween = flash.create_tween()
	tween.tween_property(flash, "light_energy", 0.0, .6)
	tween.tween_callback(flash.queue_free)
	var later = glitter.create_tween()
	later.tween_interval(.3)
	later.tween_callback(func():
		glitter.emitting = true
		if sfx:
			sfx.play("crackle", rng.randf_range(.9, 1.1)))
	if sfx:
		sfx.play("boom", rng.randf_range(.85, 1.15))

# white_until: share of the lifetime a spark stays white-hot before it takes
# on the burst colour; short keeps the colours rich instead of washed out.
func sparks(at: Vector3, color: Color, count: int, life: float, speed_min: float, speed_max: float, size: float, white_until: float = .1) -> CPUParticles3D:
	var p = CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = .96
	p.amount = count
	p.lifetime = life
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 180
	p.initial_velocity_min = speed_min
	p.initial_velocity_max = speed_max
	p.damping_min = 2.0
	p.damping_max = 3.5
	var curve = Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, .15))
	p.scale_amount_curve = curve
	var ramp = gradient([0.0, maxf(white_until, .02), .75, 1.0], [Color(1, 1, 1, 1) if white_until > 0 else color, color, Color(color.r, color.g, color.b, .8), Color(color.r * .6, color.g * .6, color.b * .6, 0)])
	p.color_ramp = ramp
	p.mesh = quad(size, spark_material)
	p.position = at
	p.emitting = true
	add_child(p)
	var cleanup = p.create_tween()
	cleanup.tween_interval(life + .8)
	cleanup.tween_callback(p.queue_free)
	return p

func shockwave(at: Vector3, radius: float) -> void:
	var ring = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2.ONE * 2.0
	ring.mesh = plane
	var m = ShaderMaterial.new()
	m.shader = load("res://assets/shaders/shockwave.gdshader")
	ring.material_override = m
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position = at
	ring.scale = Vector3.ONE * radius
	add_child(ring)
	var tween = ring.create_tween()
	tween.tween_method(func(v: float): m.set_shader_parameter("progress", v), 0.0, 1.0, .9).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(ring.queue_free)

# A big red X pressed into the ground where the pilot answered wrongly.
func miss_mark(at: Vector3) -> void:
	misses_shown += 1
	var mark = Node3D.new()
	mark.position = Vector3(at.x, .32, at.z)
	add_child(mark)
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	m.albedo_color = Color(1, .16, .16, .92)
	var outline = StandardMaterial3D.new()
	outline.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outline.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	outline.no_depth_test = true
	outline.albedo_color = Color(.25, 0, 0, .7)
	outline.render_priority = -1
	for angle in [PI / 4, -PI / 4]:
		for layer in [[outline, 1.25, -.01], [m, 1.0, 0.0]]:
			var bar = MeshInstance3D.new()
			var box = BoxMesh.new()
			box.size = Vector3(7.0, .05, 1.1) * Vector3(layer[1], 1, layer[1])
			bar.mesh = box
			bar.material_override = layer[0]
			bar.rotation.y = angle
			bar.position.y = layer[2]
			bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mark.add_child(bar)
	mark.scale = Vector3.ONE * view_scale * (1.0 if calm else 1.8)
	var tween = mark.create_tween()
	if not calm:
		tween.tween_property(mark, "scale", Vector3.ONE * view_scale, .25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(.9)
	tween.tween_method(func(a: float):
		m.albedo_color.a = a * .92
		outline.albedo_color.a = a * .7, 1.0, 0.0, .6)
	tween.tween_callback(mark.queue_free)

# Outside active flight (pause, summary, hangar): no dust, no ground sight.
func idle() -> void:
	downwash.emitting = false
	update_sight(Vector3.ZERO, false)

func clear_effects() -> void:
	show_radar([])
	for child in get_children():
		if child not in [downwash, sight, plumb] and not child in radar_rings:
			child.queue_free()
