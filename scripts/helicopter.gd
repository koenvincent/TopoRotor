class_name RotorHelicopter
extends Node3D

# A procedural helicopter in five types, with accessories and upgrades from
# the hangar. Every part takes its colour from one of seven paint slots, so a
# scheme or a colour picker recolours the whole model at once.

var rotor: Node3D
var tail_rotor: Node3D
var rotors: Array[Node3D] = []
var tail_rotors: Array[Node3D] = []
var rotor_spin: Array[float] = []
var body: Node3D
var ground_shadow: MeshInstance3D
var running: bool = true
var time: float = 0.0
# Hex strings without '#'. "dark" was the single rotor/skid slot before 0.5;
# saved paint that still has it fills rotor and gear from it.
const DEFAULT_PAINT = {"body":"e67b34","tail":"e67b34","trim":"dce4dc","rotor":"263845","gear":"263845","glass":"234c68","accent":"f2c14e"}
const PAINT_PARTS = [["body","Romp"],["tail","Staart"],["trim","Strepen"],["rotor","Rotor en motor"],["gear","Onderstel"],["glass","Ramen"],["accent","Accessoires"]]
var paint_materials: Dictionary = {}
var rotor_disc: MeshInstance3D
var beacon_light: MeshInstance3D
var strobes: Array[MeshInstance3D] = []
var exhausts: Array[MeshInstance3D] = []
var swing: Node3D
var flag: Node3D
var config: Dictionary = HangarCatalog.DEFAULT_GARAGE.duplicate(true)
var sphere: SphereMesh
var built: bool = false

func glow_material(color: Color) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	return m

func material(color: Color, metal: float = 0.0) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metal
	m.roughness = 0.65
	m.metallic_specular = .3
	return m

func part(mesh: Mesh, at: Vector3, size: Vector3, mat: Material, parent: Node3D) -> MeshInstance3D:
	var p = MeshInstance3D.new()
	p.mesh = mesh
	p.material_override = mat
	p.position = at
	p.scale = size
	parent.add_child(p)
	return p

func box(at: Vector3, size: Vector3, slot: String) -> MeshInstance3D:
	return part(BoxMesh.new(), at, size, paint_materials[slot], body)

func ball(at: Vector3, size: Vector3, slot: String) -> MeshInstance3D:
	return part(sphere, at, size, paint_materials[slot], body)

# A cylinder lying along the z axis (booms, pods, wheels turned by the caller).
func tube(at: Vector3, radius: float, length: float, slot: String, axis: String = "z") -> MeshInstance3D:
	var p = part(CylinderMesh.new(), at, Vector3(radius * 2, length * .5, radius * 2), paint_materials[slot], body)
	if axis == "z":
		p.rotation.x = PI / 2
	elif axis == "x":
		p.rotation.z = PI / 2
	return p

func _ready() -> void:
	sphere = SphereMesh.new()
	sphere.radial_segments = 16
	sphere.rings = 8
	var metal = {"body":.15,"tail":.15,"trim":.2,"rotor":.3,"gear":.3,"glass":.25,"accent":.2}
	for slot in DEFAULT_PAINT:
		paint_materials[slot] = material(Color(DEFAULT_PAINT[slot]), metal[slot])
	# Alpha falloff avoids a hard disc and needs no screen-space effects.
	var shadow_mat = ShaderMaterial.new()
	shadow_mat.shader = load("res://assets/shaders/aircraft_shadow.gdshader")
	var shadow = PlaneMesh.new()
	shadow.size = Vector2(5.5,7.0)
	ground_shadow = part(shadow,Vector3(.5,-3.15/scale.y,.4),Vector3.ONE,shadow_mat,self)
	ground_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	built = true
	rebuild()

# Applies a garage choice (type, accessories, upgrade levels). The caller
# decides what is unlocked; this only builds what it is given.
func configure(garage: Dictionary) -> void:
	config = HangarCatalog.clean_garage(garage)
	if built:
		rebuild()

func rebuild() -> void:
	if is_instance_valid(body):
		remove_child(body)
		body.queue_free()
	rotors.clear()
	tail_rotors.clear()
	rotor_spin.clear()
	strobes.clear()
	exhausts.clear()
	swing = null
	flag = null
	body = Node3D.new()
	add_child(body)
	var anchors: Dictionary
	match config.model:
		"libel":
			anchors = build_libel()
		"pijl":
			anchors = build_pijl()
		"tandem":
			anchors = build_tandem()
		"kraan":
			anchors = build_kraan()
		_:
			anchors = build_redder()
	rotor = rotors[0]
	tail_rotor = tail_rotors[0] if not tail_rotors.is_empty() else null
	rotor_disc = body.get_node_or_null("RotorDisc0")
	for id in config.accessories:
		build_accessory(id, anchors)
	build_lights(anchors)
	if int(config.motor) > 0:
		var flame = Color("ffb347") if int(config.motor) == 1 else Color("7fd8ff")
		for at in anchors.exhaust:
			var glow = part(sphere, at, Vector3(.2,.2,.3) * (1.0 + .25 * int(config.motor)), glow_material(flame), body)
			exhausts.append(glow)
	ground_shadow.mesh.size = anchors.get("shadow", Vector2(5.5, 7.0))

# Main rotor with n blades from the hub, a hub cap and a motion-blur disc.
func add_rotor(at: Vector3, span: float, blades: int, spin: float = 1.0) -> void:
	var r = Node3D.new()
	r.position = at
	body.add_child(r)
	var count = blades + int(config.rotor)
	for i in count:
		var arm = Node3D.new()
		arm.rotation.y = i * TAU / count
		r.add_child(arm)
		part(BoxMesh.new(), Vector3(span * .25, 0, 0), Vector3(span * .5, .045, .22), paint_materials.rotor, arm)
	part(sphere, Vector3.ZERO, Vector3(.48,.19,.48), paint_materials.trim, r)
	rotors.append(r)
	rotor_spin.append(spin)
	# Motion-blur disc makes the rotor read as fast-spinning from the chase cam.
	var disc_mesh = PlaneMesh.new()
	disc_mesh.size = Vector2.ONE * (span + .2)
	var disc_mat = ShaderMaterial.new()
	disc_mat.shader = load("res://assets/shaders/rotor_disc.gdshader")
	var disc = part(disc_mesh, at - Vector3(0,.02,0), Vector3.ONE, disc_mat, body)
	disc.name = "RotorDisc%d" % (rotors.size() - 1)
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func add_tail_rotor(at: Vector3, span: float, blades: int) -> void:
	var t = Node3D.new()
	t.position = at
	body.add_child(t)
	for i in blades:
		var arm = Node3D.new()
		arm.rotation.x = i * TAU / blades
		t.add_child(arm)
		part(BoxMesh.new(), Vector3(0, span * .25, 0), Vector3(.055, span * .5, .12), paint_materials.rotor, arm)
	tail_rotors.append(t)

func skids(x: float, y: float, z: float, length: float, leg_z: Array, leg_top: float) -> void:
	for side in [-1,1]:
		box(Vector3(side * x, y, z), Vector3(.12,.12,length), "gear")
		for lz in leg_z:
			var leg = box(Vector3(side * (x - .27), (y + leg_top) * .5, lz), Vector3(.1, absf(leg_top - y) + .1, .1), "trim")
			leg.rotation.z = -side * .5

func build_redder() -> Dictionary:
	ball(Vector3(0,0,0),Vector3(1.9,1.45,2.5),"body")
	ball(Vector3(0,.22,-.65),Vector3(1.78,1.15,1.65),"glass")
	box(Vector3(0,.16,-.9),Vector3(.07,1.35,1.25),"rotor")
	box(Vector3(0,-.1,-1),Vector3(1.6,.08,.06),"rotor")
	var boom = box(Vector3(0,.05,2.1),Vector3(.3,.3,3.6),"tail")
	boom.rotation.x = -.07
	box(Vector3(0,.6,3.75),Vector3(.16,1.4,.8),"tail")
	box(Vector3(0,.15,3.0),Vector3(1.7,.1,.5),"trim")
	skids(1.1,-.83,0,3.5,[-.65,.75],-.07)
	tube(Vector3(0,1.1,.12),.075,1.0,"rotor","y")
	add_rotor(Vector3(0,1.42,.12),8.0,4)
	add_tail_rotor(Vector3(.21,.7,3.8),1.55,4)
	# Engine housing, side doors and window strips read well from above.
	ball(Vector3(0,.8,.55),Vector3(.8,.4,.9),"trim")
	for side in [-1,1]:
		box(Vector3(side*.91,.0,.25),Vector3(.035,.62,.85),"trim")
		box(Vector3(side*.94,.15,.25),Vector3(.04,.3,.55),"glass")
	# Rescue explorer: twin turbines, reinforced nose, outriggers and hazard stripes.
	for side in [-1,1]:
		ball(Vector3(side*.52,.85,.8),Vector3(.58,.48,1.6),"rotor")
		tube(Vector3(side*.52,.96,1.45),.11,.4,"trim","y")
		box(Vector3(side*1.1,-.05,.7),Vector3(.65,.15,1.2),"rotor")
		box(Vector3(side*.98,-.25,.1),Vector3(.04,.15,1.3),"gear")
		for i in 3:
			var stripe = box(Vector3(side*.975,.05,-.05+i*.22),Vector3(.045,.36,.09),"trim")
			stripe.rotation.x = -.4
		ball(Vector3(side*.45,-.25,-1.08),Vector3(.21,.21,.13),"trim")
	box(Vector3(0,-.58,-1.02),Vector3(.5,.28,.35),"rotor")
	tube(Vector3(0,1.06,1.4),.028,1.6,"rotor","y")
	box(Vector3(0,.25,3.6),Vector3(1.8,.08,.35),"trim")
	return {"nose":Vector3(0,-.7,-.85),"side":Vector3(.95,.55,-.2),"belly":Vector3(0,-.75,.2),"top":Vector3(0,.95,1.7),"tail":Vector3(0,1.3,4.0),
		"skid":[1.1,-.83,0.0,3.5],"wing":[1.25,-.05,.7],"exhaust":[Vector3(-.52,.9,1.62),Vector3(.52,.9,1.62)],
		"beacon":Vector3(0,1.02,1.15),"strobes":[Vector3(0,1.32,4.1),Vector3(-.92,.3,3.6),Vector3(.92,.3,3.6)],"nav":[Vector3(-1.43,-.05,.7),Vector3(1.43,-.05,.7)],"landing":Vector3(0,-.62,-1.18)}

func build_libel() -> Dictionary:
	ball(Vector3(0,.2,-.35),Vector3(1.55,1.45,1.7),"glass")
	ball(Vector3(0,-.25,.05),Vector3(1.5,.9,1.9),"body")
	box(Vector3(0,-.05,.05),Vector3(1.53,.12,1.2),"trim")
	box(Vector3(0,.25,.85),Vector3(.9,.8,.9),"body")
	box(Vector3(0,.12,.12),Vector3(.06,1.1,1.0),"rotor")
	tube(Vector3(0,1.05,.4),.06,.7,"rotor","y")
	var boom = tube(Vector3(0,.4,2.55),.09,3.6,"tail")
	boom.rotation.x = PI / 2 - .06
	box(Vector3(0,.8,4.35),Vector3(.08,1.0,.5),"tail")
	box(Vector3(0,.3,4.25),Vector3(1.1,.06,.3),"trim")
	skids(.85,-.95,.1,2.8,[-.5,.6],-.4)
	add_rotor(Vector3(0,1.45,.4),7.2,2)
	add_tail_rotor(Vector3(.16,.7,4.45),1.3,2)
	return {"nose":Vector3(0,-.75,-.75),"side":Vector3(.78,.45,-.2),"belly":Vector3(0,-.7,.2),"top":Vector3(0,.7,1.2),"tail":Vector3(0,1.3,4.4),
		"skid":[.85,-.95,.1,2.8],"wing":[.75,-.1,.55],"exhaust":[Vector3(0,.45,1.35)],
		"beacon":Vector3(0,.7,1.05),"strobes":[Vector3(0,1.32,4.45),Vector3(-.55,.3,4.25),Vector3(.55,.3,4.25)],"nav":[Vector3(-.78,-.15,.1),Vector3(.78,-.15,.1)],"landing":Vector3(0,-.62,-.9),
		"shadow":Vector2(4.6,6.2)}

func build_pijl() -> Dictionary:
	ball(Vector3(0,0,.2),Vector3(1.7,1.35,3.4),"body")
	ball(Vector3(0,.2,-.85),Vector3(1.5,1.0,1.6),"glass")
	ball(Vector3(0,.8,.7),Vector3(1.0,.5,1.8),"trim")
	var boom = box(Vector3(0,.25,2.75),Vector3(.45,.42,3.0),"tail")
	boom.rotation.x = -.08
	for side in [-1,1]:
		box(Vector3(side*.83,.0,.35),Vector3(.04,.18,2.2),"trim")
		box(Vector3(side*.8,.2,-.1),Vector3(.04,.36,.7),"glass")
	# Fenestron: the tail rotor spins inside a ring in the fin.
	var duct = part(TorusMesh.new(),Vector3(0,.75,4.4),Vector3(1.0,1.6,1.0),paint_materials.tail,body)
	(duct.mesh as TorusMesh).inner_radius = .45
	(duct.mesh as TorusMesh).outer_radius = .7
	duct.rotation.z = PI / 2
	box(Vector3(0,1.45,4.55),Vector3(.1,.8,.6),"tail")
	box(Vector3(0,.32,3.85),Vector3(1.6,.07,.35),"trim")
	for side in [-1,1]:
		box(Vector3(side*.8,.45,3.85),Vector3(.05,.35,.35),"tail")
	skids(1.0,-.95,.1,3.0,[-.6,.7],-.45)
	tube(Vector3(0,1.1,.3),.08,.4,"rotor","y")
	add_rotor(Vector3(0,1.35,.3),8.4,5)
	add_tail_rotor(Vector3(0,.75,4.4),.85,8)
	return {"nose":Vector3(0,-.62,-1.25),"side":Vector3(.88,.5,-.1),"belly":Vector3(0,-.72,.4),"top":Vector3(0,1.05,1.45),"tail":Vector3(0,1.85,4.6),
		"skid":[1.0,-.95,.1,3.0],"wing":[.85,0.0,.5],"exhaust":[Vector3(-.35,.9,1.6),Vector3(.35,.9,1.6)],
		"beacon":Vector3(0,1.05,1.25),"strobes":[Vector3(0,1.88,4.6),Vector3(-.82,.66,3.85),Vector3(.82,.66,3.85)],"nav":[Vector3(-.86,-.1,.6),Vector3(.86,-.1,.6)],"landing":Vector3(0,-.55,-1.35)}

func build_tandem() -> Dictionary:
	box(Vector3(0,0,0),Vector3(1.8,1.7,6.8),"body")
	ball(Vector3(0,-.05,-3.4),Vector3(1.8,1.6,1.4),"body")
	ball(Vector3(0,.3,-3.6),Vector3(1.5,.8,1.0),"glass")
	box(Vector3(0,1.0,2.9),Vector3(1.0,1.4,1.6),"tail")
	box(Vector3(0,.95,-2.6),Vector3(.8,.4,.9),"trim")
	box(Vector3(0,.95,0),Vector3(.6,.3,4.6),"trim")
	for side in [-1,1]:
		box(Vector3(side*1.0,-.55,.3),Vector3(.4,.5,4.0),"trim")
		for i in 4:
			box(Vector3(side*.91,.35,-2.0+i*.9),Vector3(.04,.3,.45),"glass")
		for wz in [-2.2,2.0]:
			tube(Vector3(side*1.0,-1.05,wz),.28,.18,"gear","x")
			box(Vector3(side*1.0,-.85,wz),Vector3(.1,.4,.1),"gear")
		ball(Vector3(side*.7,1.3,2.6),Vector3(.45,.45,1.4),"rotor")
	add_rotor(Vector3(0,1.35,-2.6),7.4,3)
	add_rotor(Vector3(0,2.0,2.9),7.4,3,-1.0)
	return {"nose":Vector3(0,-.8,-3.55),"side":Vector3(.95,.6,-1.6),"belly":Vector3(0,-.9,0),"top":Vector3(0,1.1,-.6),"tail":Vector3(0,1.7,3.7),
		"skid":[1.05,-.95,0.0,5.0],"wing":[1.2,-.35,-.6],"exhaust":[Vector3(-.7,1.3,3.35),Vector3(.7,1.3,3.35)],
		"beacon":Vector3(0,1.15,.6),"strobes":[Vector3(0,1.75,3.75),Vector3(-.92,.6,3.4),Vector3(.92,.6,3.4)],"nav":[Vector3(-1.22,-.4,-1.6),Vector3(1.22,-.4,-1.6)],"landing":Vector3(0,-.78,-3.2),
		"shadow":Vector2(5.0,10.0)}

func build_kraan() -> Dictionary:
	ball(Vector3(0,.2,-1.6),Vector3(1.4,1.3,1.6),"body")
	ball(Vector3(0,.35,-1.95),Vector3(1.25,.9,1.0),"glass")
	box(Vector3(0,.55,.6),Vector3(.7,.6,3.8),"body")
	box(Vector3(0,1.0,.5),Vector3(1.1,.5,1.8),"trim")
	for side in [-1,1]:
		box(Vector3(side*.36,.55,.6),Vector3(.02,.14,3.6),"trim")
	var boom = box(Vector3(0,.72,3.6),Vector3(.35,.4,2.6),"tail")
	boom.rotation.x = -.05
	box(Vector3(0,1.3,4.8),Vector3(.12,1.4,.7),"tail")
	box(Vector3(0,.9,4.6),Vector3(1.4,.07,.3),"trim")
	for side in [-1,1]:
		var front = box(Vector3(side*.85,-.55,-1.3),Vector3(.1,1.6,.1),"gear")
		front.rotation.z = -side*.3
		var rear = box(Vector3(side*1.15,-.55,1.4),Vector3(.12,1.8,.12),"gear")
		rear.rotation.z = -side*.4
		tube(Vector3(side*1.1,-1.35,-1.3),.2,.14,"gear","x")
		tube(Vector3(side*1.5,-1.4,1.4),.24,.16,"gear","x")
	tube(Vector3(0,1.35,.4),.08,.4,"rotor","y")
	add_rotor(Vector3(0,1.55,.4),9.0,6)
	add_tail_rotor(Vector3(.22,1.4,4.95),1.7,4)
	return {"nose":Vector3(0,-.55,-2.05),"side":Vector3(.7,.6,-.3),"belly":Vector3(0,.2,.6),"top":Vector3(0,1.25,1.2),"tail":Vector3(0,2.0,4.95),
		"skid":[1.25,-1.45,0.0,3.6],"wing":[.5,.45,.4],"exhaust":[Vector3(-.45,1.15,1.45),Vector3(.45,1.15,1.45)],
		"beacon":Vector3(0,1.3,1.3),"strobes":[Vector3(0,2.02,5.0),Vector3(-.7,.95,4.6),Vector3(.7,.95,4.6)],"nav":[Vector3(-.72,.15,-1.5),Vector3(.72,.15,-1.5)],"landing":Vector3(0,-.4,-2.0),
		"shadow":Vector2(5.5,8.0)}

func build_accessory(id: String, a: Dictionary) -> void:
	match id:
		"zoeklicht":
			ball(a.nose + Vector3(.3,0,0), Vector3(.34,.28,.4), "accent")
			part(sphere, a.nose + Vector3(.3,-.04,-.18), Vector3(.24,.2,.08), glow_material(Color("fff1b8")), body)
			# A faint cone shows where the light shines, forward and down.
			var beam = Node3D.new()
			beam.position = a.nose + Vector3(.3,-.05,-.2)
			beam.rotation.x = .5
			body.add_child(beam)
			var cone = CylinderMesh.new()
			cone.top_radius = .08
			cone.bottom_radius = 1.1
			cone.height = 4.0
			cone.cap_top = false
			cone.cap_bottom = false
			var light = StandardMaterial3D.new()
			light.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			light.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			light.cull_mode = BaseMaterial3D.CULL_DISABLED
			light.albedo_color = Color(1,.95,.7,.13)
			var shine = part(cone, Vector3(0,-2.0,0), Vector3.ONE, light, beam)
			shine.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		"camera":
			ball(a.nose + Vector3(-.3,-.02,.3), Vector3(.42,.42,.42), "accent")
			part(sphere, a.nose + Vector3(-.3,-.02,.1), Vector3(.2,.2,.06), paint_materials.glass, body)
		"lier":
			var s: Vector3 = a.side
			box(s + Vector3(.3,0,0), Vector3(.7,.12,.12), "accent")
			tube(s + Vector3(.6,-.02,0), .1, .22, "rotor", "z")
			tube(s + Vector3(.62,-.75,0), .015, 1.4, "rotor", "y")
			box(s + Vector3(.62,-1.48,0), Vector3(.16,.2,.1), "trim")
		"drijvers":
			var k: Array = a.skid
			for side in [-1,1]:
				var float_mesh = CapsuleMesh.new()
				float_mesh.radius = .27
				float_mesh.height = float(k[3]) + .2
				var pontoon = part(float_mesh, Vector3(side * float(k[0]), float(k[1]) - .12, float(k[2])), Vector3.ONE, paint_materials.accent, body)
				pontoon.rotation.x = PI / 2
				box(Vector3(side * float(k[0]), float(k[1]) + .02, float(k[2])), Vector3(.56,.05,float(k[3]) * .7), "trim")
		"vleugels":
			var w: Array = a.wing
			for side in [-1,1]:
				box(Vector3(side * (float(w[0]) + .4), float(w[1]), float(w[2])), Vector3(.9,.08,.55), "accent")
				tube(Vector3(side * (float(w[0]) + .65), float(w[1]) - .2, float(w[2])), .14, .9, "trim")
				ball(Vector3(side * (float(w[0]) + .65), float(w[1]) - .2, float(w[2]) - .45), Vector3(.28,.28,.3), "rotor")
		"antennes":
			var whip = tube(a.top + Vector3(0,.35,0), .02, .7, "rotor", "y")
			whip.rotation.x = .35
			ball(a.top + Vector3(0,.68,.13), Vector3(.08,.08,.08), "accent")
			tube(a.top + Vector3(.28,.2,.35), .02, .4, "rotor", "y")
			box(a.belly + Vector3(0,-.12,-.5), Vector3(.04,.25,.22), "accent")
		"krat":
			swing = Node3D.new()
			swing.position = a.belly
			body.add_child(swing)
			var line = 1.0 if config.model == "kraan" else 1.6
			part(CylinderMesh.new(), Vector3(0,-line * .5,0), Vector3(.03,line * .5,.03), paint_materials.rotor, swing)
			part(BoxMesh.new(), Vector3(0,-line - .42,0), Vector3(1.0,.8,.8), paint_materials.accent, swing)
			for y in [-.22,.22]:
				part(BoxMesh.new(), Vector3(0,-line - .42 + y,0), Vector3(1.03,.08,.83), paint_materials.trim, swing)
		"wimpel":
			tube(a.tail + Vector3(0,.35,0), .025, .7, "rotor", "y")
			flag = Node3D.new()
			flag.position = a.tail + Vector3(0,.58,0)
			body.add_child(flag)
			part(BoxMesh.new(), Vector3(0,0,.35), Vector3(.02,.3,.7), paint_materials.accent, flag)

# Anti-collision beacon, white strobes, port/starboard lights and a landing
# light. The light pack upgrade adds two landing lights and wing-tip strobes.
func build_lights(a: Dictionary) -> void:
	beacon_light = part(sphere,a.beacon,Vector3(.22,.16,.22),glow_material(Color("ff3b30")),body)
	for at in a.strobes:
		strobes.append(part(sphere,at,Vector3(.14,.14,.14),glow_material(Color("ffffff")),body))
	for i in 2:
		part(sphere,a.nav[i],Vector3(.12,.12,.12),glow_material(Color("ff4d3d") if i==0 else Color("4dff88")),body)
	part(sphere,a.landing,Vector3(.2,.12,.12),glow_material(Color("fff4c8")),body)
	if int(config.lights) > 0:
		for side in [-1,1]:
			part(sphere,a.landing + Vector3(side*.32,.02,.15),Vector3(.18,.12,.12),glow_material(Color("fffbe8")),body)
			strobes.append(part(sphere,a.nav[0 if side < 0 else 1] + Vector3(side*.08,.12,.1),Vector3(.12,.12,.12),glow_material(Color("ffffff")),body))

static func valid_hex(value: Variant) -> bool:
	return value is String and value.length()==6 and value.is_valid_hex_number(false)

# Fills every paint slot: valid saved colours first, the legacy "dark" slot
# for rotor and gear, the body colour for the tail, then the factory colour.
static func normalize_paint(paint: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for slot in DEFAULT_PAINT:
		var hex: Variant = paint.get(slot)
		if not valid_hex(hex):
			if slot in ["rotor","gear"] and valid_hex(paint.get("dark")):
				hex = paint.dark
			elif slot == "tail" and valid_hex(paint.get("body")):
				hex = paint.body
			else:
				hex = DEFAULT_PAINT[slot]
		out[slot] = String(hex).to_lower()
	return out

func apply_paint(paint: Dictionary) -> void:
	var full = normalize_paint(paint)
	for slot in full:
		paint_materials[slot].albedo_color = Color(full[slot])

func paint_hex(slot: String) -> String:
	return paint_materials[slot].albedo_color.to_html(false)

func _process(delta: float) -> void:
	ground_shadow.global_position.y=.09
	time += delta
	for i in rotors.size():
		rotors[i].rotation.y += delta * (32.0 if running else 3.0) * rotor_spin[i]
	for t in tail_rotors:
		t.rotation.x += delta * 44.0
	body.position.y = sin(time * 3.0) * .1
	# Beacon pulses once a second; strobes give a quick double flash.
	beacon_light.visible = fmod(time, 1.0) < .45
	var strobe_phase = fmod(time + .5, 1.3)
	for strobe in strobes:
		strobe.visible = strobe_phase < .06 or (strobe_phase > .14 and strobe_phase < .2)
	for glow in exhausts:
		glow.scale.z = .3 * (1.0 + .25 * int(config.motor)) * (.85 + .3 * absf(sin(time * 23.0 + glow.position.x)))
	if swing:
		swing.rotation.x = sin(time * 1.7) * .07
		swing.rotation.z = sin(time * 1.1) * .04
	if flag:
		flag.rotation.y = sin(time * 6.0) * .25

func lean(direction: Vector2, delta: float) -> void:
	body.rotation.z = lerp(body.rotation.z,-direction.x*.14,1.0-exp(-7.0*delta))
	body.rotation.x = lerp(body.rotation.x,-direction.y*.12,1.0-exp(-7.0*delta))
