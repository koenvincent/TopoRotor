class_name RotorHelicopter
extends Node3D

# A procedural aircraft: helicopters, propeller aeroplanes and jets, with
# accessories and upgrades from the hangar. Every part takes its colour from
# one of seven paint slots, so a scheme or a colour picker recolours the whole
# model at once. The nose points to -z.

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
const DEFAULT_PAINT = {"body":"e67b34","tail":"e67b34","trim":"dce4dc","rotor":"263845","gear":"263845","glass":"1d3446","accent":"f2c14e"}
const PAINT_PARTS = [["body","Romp"],["tail","Staart"],["trim","Strepen"],["rotor","Rotor en motor"],["gear","Onderstel"],["glass","Ramen"],["accent","Accessoires"]]
var paint_materials: Dictionary = {}
var rotor_disc: MeshInstance3D
var beacon_light: MeshInstance3D
var strobes: Array[MeshInstance3D] = []
var exhausts: Array[MeshInstance3D] = []
var swing: Node3D
var flag: Node3D
# Animated accessory parts: hanging loads, waving flags, a turning radar,
# bobbing balloons, alternating police lights and twinkling bulbs.
var swings: Array[Node3D] = []
var flags: Array[Node3D] = []
var spinners: Array[Node3D] = []
var bobbers: Array[Node3D] = []
var flashers: Array[MeshInstance3D] = []
var twinkles: Array[MeshInstance3D] = []
# Aeroplane propellers turn about the nose axis.
var propellers: Array[Node3D] = []
var kind: String = "heli"
var config: Dictionary = HangarCatalog.DEFAULT_GARAGE.duplicate(true)
var sphere: SphereMesh
var built: bool = false

func glow_material(color: Color) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	return m

# Lacquered model paint (see ToyLook). gloss 0 is matte, 1 tinted glass.
func material(color: Color, gloss: float = .55) -> StandardMaterial3D:
	return ToyLook.material(color, gloss)

# A plain box becomes a rounded block at its real size, so edges catch the
# light like a scale model; every other mesh is scaled to size.
func part(mesh: Mesh, at: Vector3, size: Vector3, mat: Material, parent: Node3D) -> MeshInstance3D:
	var p = MeshInstance3D.new()
	if mesh is BoxMesh and (mesh as BoxMesh).size == Vector3.ONE:
		p.mesh = ToyLook.rounded_box(size)
	else:
		p.mesh = mesh
		p.scale = size
	p.material_override = mat
	p.position = at
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

# A tapered tube from one point to another: tail booms that slim down
# towards the tail, plane tails and skid legs.
func taper(from: Vector3, to: Vector3, r_from: float, r_to: float, slot: String) -> MeshInstance3D:
	var mesh = CylinderMesh.new()
	mesh.bottom_radius = r_from
	mesh.top_radius = r_to
	mesh.height = from.distance_to(to)
	mesh.radial_segments = 32
	mesh.rings = 1
	var p = part(mesh, (from + to) * .5, Vector3.ONE, paint_materials[slot], body)
	var axis = (to - from).normalized()
	if absf(axis.dot(Vector3.UP)) < .9999:
		p.basis = Basis(Quaternion(Vector3.UP, axis))
	elif axis.y < 0:
		p.rotation.x = PI
	return p

func _ready() -> void:
	sphere = ToyLook.sphere()
	# Lacquered body and accessories, satin trim and mechanics, shiny glass.
	var gloss = {"body":.75,"tail":.75,"trim":.6,"rotor":.4,"gear":.4,"glass":1.0,"accent":.75}
	for slot in DEFAULT_PAINT:
		paint_materials[slot] = material(Color(DEFAULT_PAINT[slot]), gloss[slot])
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
	propellers.clear()
	for list in [swings,flags,spinners,bobbers,flashers,twinkles]:
		list.clear()
	swing = null
	flag = null
	body = Node3D.new()
	add_child(body)
	kind = HangarCatalog.model_kind(config.model)
	var builders = {"redder":build_redder,"libel":build_libel,"molen":build_molen,"pijl":build_pijl,"tandem":build_tandem,"wesp":build_wesp,
		"kraan":build_kraan,"coax":build_coax,"sport":build_sport,"dubbel":build_dubbel,"zee":build_zee,"dakota":build_dakota,
		"valk":build_valk,"delta":build_delta,"schaduw":build_schaduw}
	var anchors: Dictionary = fill_anchors(builders.get(config.model, build_redder).call())
	rotor = rotors[0] if not rotors.is_empty() else null
	tail_rotor = tail_rotors[0] if not tail_rotors.is_empty() else null
	rotor_disc = body.get_node_or_null("RotorDisc0")
	for id in config.accessories:
		build_accessory(id, anchors)
	swing = swings[0] if not swings.is_empty() else null
	flag = flags[0] if not flags.is_empty() else null
	build_lights(anchors)
	# Jets always show their afterburner; the motor and rotor upgrades make
	# it longer and bluer. Other types only glow with a motor upgrade.
	var motor = int(config.motor)
	if motor > 0 or kind == "jet":
		var flame = Color("ffb347") if motor <= 1 else Color("7fd8ff")
		var length = (1.0 + .25 * motor) * (2.6 + .7 * int(config.rotor) if kind == "jet" else 1.0)
		for at in anchors.exhaust:
			var glow = part(sphere, at, Vector3(.2,.2,.3) * Vector3(1.0 + .25 * motor, 1.0 + .25 * motor, length), glow_material(flame), body)
			glow.set_meta("length", .3 * length)
			exhausts.append(glow)
	ground_shadow.mesh.size = anchors.get("shadow", Vector2(5.5, 7.0))

# Jets sound higher than propellers, propellers higher than rotors.
func sound_pitch() -> float:
	return {"heli":1.0,"vliegtuig":1.2,"jet":1.55}.get(kind, 1.0)

# A propeller about the z axis at the nose (or the back for a pusher), with a
# spinner and a motion-blur disc. The rotor upgrade adds blades here too.
func add_propeller(at: Vector3, span: float, blades: int, slot: String = "rotor") -> Node3D:
	var p = Node3D.new()
	p.position = at
	body.add_child(p)
	var count = blades + int(config.rotor)
	for i in count:
		var arm = Node3D.new()
		arm.rotation.z = i * TAU / count
		p.add_child(arm)
		var blade = part(BoxMesh.new(), Vector3(0, span * .25, 0), Vector3(.16, span * .5, .05), paint_materials[slot], arm)
		blade.rotation.y = .35
	var cone = CylinderMesh.new()
	cone.top_radius = .02
	cone.bottom_radius = .16
	cone.height = .32
	var spinner = part(cone, Vector3(0,0,-.12), Vector3.ONE, paint_materials.trim, p)
	spinner.rotation.x = -PI / 2
	propellers.append(p)
	var disc_mesh = PlaneMesh.new()
	disc_mesh.size = Vector2.ONE * (span + .1)
	var disc_mat = ShaderMaterial.new()
	disc_mat.shader = load("res://assets/shaders/rotor_disc.gdshader")
	var disc = part(disc_mesh, at + Vector3(0,0,-.03), Vector3.ONE, disc_mat, body)
	disc.rotation.x = PI / 2
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p

# A flat triangle (a prism lying down) with its point to the front: delta
# wings, tail planes and canards. width is across, length along z.
func delta_wing(at: Vector3, width: float, length: float, thick: float, slot: String, skew: float = .5) -> MeshInstance3D:
	var prism = PrismMesh.new()
	prism.left_to_right = skew
	var w = part(prism, at, Vector3(width, length, thick), paint_materials[slot], body)
	w.rotation.x = -PI / 2
	return w

# An upright triangle along z: swept fins. lean tilts it outwards.
func fin(at: Vector3, height: float, length: float, slot: String, lean: float = 0.0) -> MeshInstance3D:
	var prism = PrismMesh.new()
	prism.left_to_right = 1.0
	var f = part(prism, at, Vector3(length, height, .08), paint_materials[slot], body)
	f.rotation = Vector3(0, -PI / 2, lean)
	return f

func wheel(at: Vector3, radius: float) -> void:
	tube(at, radius, radius * .7, "gear", "x")
	tube(at, radius * .45, radius * .74, "trim", "x")

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
		part(BoxMesh.new(), Vector3(span * .22, 0, 0), Vector3(span * .44, .045, .22), paint_materials.rotor, arm)
		# Painted tips, as on real rotor blades, so the spin shows.
		part(BoxMesh.new(), Vector3(span * .47, 0, 0), Vector3(span * .06, .047, .222), paint_materials.accent, arm)
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

# Skids like the real thing: round tubes with an upturned nose, on curved
# cross tubes that run from the belly out to the skid.
func skids(x: float, y: float, z: float, length: float, leg_z: Array, leg_top: float) -> void:
	for side in [-1,1]:
		var back = Vector3(side * x, y, z + length * .5)
		var front = Vector3(side * x, y, z - length * .42)
		taper(back, front, .06, .06, "gear")
		taper(front, front + Vector3(0, .2, -.22), .06, .05, "gear")
		ball(back, Vector3(.12,.12,.12), "gear")
		ball(front, Vector3(.12,.12,.12), "gear")
		for lz in leg_z:
			var top = Vector3(side * (x - .45), leg_top, lz)
			var knee = Vector3(side * x, lerpf(y, leg_top, .25), lz)
			taper(top, knee, .05, .05, "gear")
			taper(knee, Vector3(side * x, y, lz), .05, .055, "gear")
			ball(knee, Vector3(.1,.1,.1), "gear")

# Airframes modelled in Blender (tools/blender/models.py) replace the
# procedural body where they exist. Their faces carry paint-slot names as
# material names, so the hangar's colours land on the right parts; rotors
# stay procedural, because the rotor upgrade adds blades.
const MODEL_DIR = "res://assets/models/"

func airframe(id: String) -> bool:
	var path = MODEL_DIR + id + ".glb"
	if not ResourceLoader.exists(path):
		return false
	var frame: Node3D = (load(path) as PackedScene).instantiate()
	frame.name = "Airframe"
	body.add_child(frame)
	for mesh_node in frame.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance = mesh_node as MeshInstance3D
		for surface in mesh_instance.mesh.get_surface_count():
			var source = mesh_instance.mesh.surface_get_material(surface)
			var slot = source.resource_name if source != null else "body"
			mesh_instance.set_surface_override_material(surface, paint_materials.get(slot, paint_materials.body))
	return true

func build_redder() -> Dictionary:
	if airframe("redder"):
		add_rotor(Vector3(0,1.42,.12),8.0,4)
		add_tail_rotor(Vector3(.2,.95,3.95),1.5,4)
		return {"nose":Vector3(0,-.55,-1.3),"side":Vector3(.95,.45,-.2),"belly":Vector3(0,-.75,.2),"top":Vector3(0,1.0,.5),"tail":Vector3(0,1.6,4.05),
			"skid":[1.1,-.9,0.0,3.3],"wing":[1.0,-.1,.6],"exhaust":[Vector3(-.32,.9,1.66),Vector3(.32,.9,1.66)],
			"beacon":Vector3(0,1.0,1.15),"strobes":[Vector3(0,1.62,4.0),Vector3(-.9,.64,3.2),Vector3(.9,.64,3.2)],"nav":[Vector3(-.94,-.15,.3),Vector3(.94,-.15,.3)],"landing":Vector3(0,-.6,-1.25),
			"eyes":Vector3(0,.32,-1.42)}
	ball(Vector3(0,0,0),Vector3(1.9,1.45,2.5),"body")
	ball(Vector3(0,.22,-.65),Vector3(1.78,1.15,1.65),"glass")
	box(Vector3(0,.16,-.9),Vector3(.07,1.35,1.25),"rotor")
	box(Vector3(0,-.1,-1),Vector3(1.6,.08,.06),"rotor")
	taper(Vector3(0,-.08,.3),Vector3(0,.18,3.9),.3,.11,"tail")
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
	taper(Vector3(0,.12,1.25),Vector3(0,.37,4.25),.26,.13,"tail")
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
	taper(Vector3(0,.65,2.3),Vector3(0,.79,4.9),.21,.1,"tail")
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

# Where the stripe eyes sit on the first five helicopters (front of the glass).
const OLD_EYES = {"redder":Vector3(0,.45,-1.33),"libel":Vector3(0,.45,-1.1),"pijl":Vector3(0,.35,-1.55),"tandem":Vector3(0,.4,-4.0),"kraan":Vector3(0,.45,-2.35)}

# Anchors the newer accessories need, derived when a builder leaves them out:
# eyes on the glass, the rear for smoke and a banner, a nose tip for the
# measuring probe and a place on the roof for the crown.
func fill_anchors(a: Dictionary) -> Dictionary:
	if not a.has("eyes"):
		a.eyes = OLD_EYES.get(config.model, a.nose + Vector3(0,.9,-.3))
	if not a.has("rear"):
		a.rear = a.tail + Vector3(0,-.9,.4)
	if not a.has("tip"):
		a.tip = a.nose + Vector3(0,.45,-.35)
	if not a.has("crown"):
		a.crown = a.beacon + Vector3(0,.12,-.45)
	if not a.has("eye_gap"):
		a.eye_gap = .3
	return a

# A cone pointing forward (-z): jet noses and engine cowls.
func nose_cone(at: Vector3, radius: float, length: float, slot: String) -> MeshInstance3D:
	var cone = CylinderMesh.new()
	cone.top_radius = .02
	cone.bottom_radius = radius
	cone.height = length
	var c = part(cone, at, Vector3.ONE, paint_materials[slot], body)
	c.rotation.x = -PI / 2
	return c

# Gyrocopter: an open cabin, a free-turning rotor on a mast and a pusher
# propeller behind the pilot.
func build_molen() -> Dictionary:
	ball(Vector3(0,0,-.3),Vector3(1.2,1.2,2.0),"body")
	ball(Vector3(0,.2,-.7),Vector3(1.0,.8,1.0),"glass")
	box(Vector3(0,.2,.75),Vector3(.6,.6,.6),"rotor")
	box(Vector3(0,-.05,-.3),Vector3(1.22,.08,1.4),"trim")
	tube(Vector3(0,1.0,.2),.07,1.4,"rotor","y")
	add_rotor(Vector3(0,1.75,.2),7.4,2,.55)
	add_propeller(Vector3(0,.2,1.15),1.6,3)
	tube(Vector3(0,-.15,2.0),.06,2.6,"tail")
	box(Vector3(0,.45,3.2),Vector3(.08,1.0,.6),"tail")
	box(Vector3(0,-.1,3.1),Vector3(1.3,.06,.35),"trim")
	for side in [-1,1]:
		box(Vector3(side*.65,.25,3.1),Vector3(.06,.7,.4),"tail")
		var leg = box(Vector3(side*.42,-.5,0),Vector3(.5,.07,.07),"gear")
		leg.rotation.z = side*.5
		wheel(Vector3(side*.65,-.72,0),.22)
	box(Vector3(0,-.6,-1.0),Vector3(.07,.3,.07),"gear")
	wheel(Vector3(0,-.78,-1.05),.16)
	return {"nose":Vector3(0,-.5,-1.2),"side":Vector3(.62,.3,-.3),"belly":Vector3(0,-.6,0),"top":Vector3(0,.62,-.2),"tail":Vector3(0,.95,3.2),
		"skid":[.65,-.95,-.3,2.0],"wing":[.6,0.0,-.2],"exhaust":[Vector3(0,.25,.4)],
		"beacon":Vector3(0,.62,-.3),"strobes":[Vector3(0,.97,3.25),Vector3(-.65,-.1,3.1),Vector3(.65,-.1,3.1)],"nav":[Vector3(-.6,0,-.3),Vector3(.6,0,-.3)],"landing":Vector3(0,-.55,-1.2),
		"eyes":Vector3(0,.35,-1.15),"rear":Vector3(0,.2,1.5),"shadow":Vector2(4.0,5.5)}

# Gunship: a slim body with two cockpits behind each other, stub wings with
# pods and a chin turret.
func build_wesp() -> Dictionary:
	ball(Vector3(0,0,0),Vector3(1.0,1.3,3.4),"body")
	ball(Vector3(0,.35,-1.0),Vector3(.8,.75,1.0),"glass")
	ball(Vector3(0,.55,-.2),Vector3(.8,.8,1.0),"glass")
	box(Vector3(0,.62,-.6),Vector3(.82,.08,.1),"rotor")
	for side in [-1,1]:
		ball(Vector3(side*.55,.55,.5),Vector3(.45,.45,1.4),"rotor")
		box(Vector3(side*.95,0,.2),Vector3(1.2,.08,.6),"body")
		tube(Vector3(side*1.25,-.25,.2),.14,1.0,"trim")
		ball(Vector3(side*1.25,-.25,-.32),Vector3(.26,.26,.2),"rotor")
		box(Vector3(side*.6,-.7,-.6),Vector3(.07,.4,.07),"gear")
		wheel(Vector3(side*.62,-.92,-.6),.2)
	box(Vector3(0,-.6,-1.1),Vector3(.25,.2,.25),"rotor")
	tube(Vector3(0,-.65,-1.5),.04,.7,"rotor")
	taper(Vector3(0,.17,1.0),Vector3(0,.33,4.2),.2,.09,"tail")
	box(Vector3(0,.85,4.1),Vector3(.12,1.1,.6),"tail")
	box(Vector3(0,.3,3.9),Vector3(1.6,.07,.35),"trim")
	wheel(Vector3(0,-.2,3.9),.12)
	tube(Vector3(0,.95,0),.07,.4,"rotor","y")
	add_rotor(Vector3(0,1.2,0),8.2,4)
	add_tail_rotor(Vector3(.16,1.0,4.2),1.4,4)
	return {"nose":Vector3(0,-.4,-1.4),"side":Vector3(.52,.2,-.4),"belly":Vector3(0,-.65,.3),"top":Vector3(0,.9,.9),"tail":Vector3(0,1.45,4.15),
		"skid":[.75,-1.0,-.1,2.6],"wing":[1.0,0.0,.2],"exhaust":[Vector3(-.55,.6,1.22),Vector3(.55,.6,1.22)],
		"beacon":Vector3(0,.95,.75),"strobes":[Vector3(0,1.42,4.15),Vector3(-.8,.3,3.9),Vector3(.8,.3,3.9)],"nav":[Vector3(-1.58,0,.2),Vector3(1.58,0,.2)],"landing":Vector3(0,-.55,-1.25),
		"eyes":Vector3(0,.45,-1.42),"eye_gap":.22,"shadow":Vector2(5.0,7.0)}

# Coaxial helicopter: two rotors on one mast that turn opposite ways, so it
# needs no tail rotor; two fins on the tail plane instead.
func build_coax() -> Dictionary:
	box(Vector3(0,0,0),Vector3(1.6,1.5,2.6),"body")
	ball(Vector3(0,-.05,-1.3),Vector3(1.6,1.4,1.2),"body")
	ball(Vector3(0,.25,-1.45),Vector3(1.4,.8,.9),"glass")
	ball(Vector3(0,.95,.4),Vector3(1.0,.5,1.4),"rotor")
	taper(Vector3(0,.15,1.1),Vector3(0,.25,3.7),.24,.12,"tail")
	box(Vector3(0,.25,3.6),Vector3(2.0,.08,.5),"trim")
	for side in [-1,1]:
		box(Vector3(side*1.0,.6,3.6),Vector3(.08,.9,.6),"tail")
		for i in 2:
			box(Vector3(side*.81,.25,-.5+i*.7),Vector3(.03,.35,.45),"glass")
		for wz in [-.9,.8]:
			box(Vector3(side*.75,-.8,wz),Vector3(.08,.3,.08),"gear")
			wheel(Vector3(side*.78,-.95,wz),.2)
	tube(Vector3(0,1.3,0),.09,1.2,"rotor","y")
	box(Vector3(0,1.5,0),Vector3(.3,.2,.3),"trim")
	add_rotor(Vector3(0,1.15,0),7.6,3)
	add_rotor(Vector3(0,1.85,0),7.6,3,-1.0)
	return {"nose":Vector3(0,-.6,-1.6),"side":Vector3(.82,.4,-.2),"belly":Vector3(0,-.75,.2),"top":Vector3(0,.8,1.1),"tail":Vector3(0,.35,3.85),
		"skid":[.78,-1.05,0.0,2.6],"wing":[.85,-.2,.1],"exhaust":[Vector3(-.35,1.0,1.12),Vector3(.35,1.0,1.12)],
		"beacon":Vector3(0,.78,1.3),"strobes":[Vector3(-1.0,1.08,3.6),Vector3(1.0,1.08,3.6),Vector3(0,.3,3.9)],"nav":[Vector3(-.82,-.2,-.6),Vector3(.82,-.2,-.6)],"landing":Vector3(0,-.7,-1.5),
		"eyes":Vector3(0,.45,-1.85),"crown":Vector3(0,.82,-.6),"shadow":Vector2(5.0,6.5)}

# Light aeroplane: a high wing on struts, a nose propeller and a tail. Also
# the base of the seaplane, which swaps the wheels for floats.
func plane_body(floats: bool) -> void:
	ball(Vector3(0,0,-.3),Vector3(1.2,1.3,3.2),"body")
	ball(Vector3(0,-.1,-1.7),Vector3(.95,.95,1.0),"trim")
	taper(Vector3(0,.05,.5),Vector3(0,.25,3.25),.5,.14,"body")
	ball(Vector3(0,.45,-.6),Vector3(1.05,.7,1.4),"glass")
	box(Vector3(0,.78,-.4),Vector3(9.0,.12,1.3),"body")
	box(Vector3(0,.2,3.1),Vector3(3.0,.08,.75),"tail")
	fin(Vector3(0,.85,3.05),1.2,1.1,"tail")
	add_propeller(Vector3(0,-.1,-2.25),1.9,2)
	for side in [-1,1]:
		box(Vector3(side*4.3,.78,-.4),Vector3(.5,.13,1.32),"trim")
		box(Vector3(side*.64,.05,-.4),Vector3(.03,.6,.5),"trim")
		var strut = box(Vector3(side*1.25,.15,-.4),Vector3(.06,1.5,.12),"gear")
		strut.rotation.z = side*.95
		box(Vector3(side*1.2,.05,3.1),Vector3(.5,.09,.76),"trim")
		if not floats:
			var leg = box(Vector3(side*.55,-.62,-.3),Vector3(.08,.6,.08),"gear")
			leg.rotation.z = -side*.6
			wheel(Vector3(side*.8,-.9,-.3),.25)
	if not floats:
		box(Vector3(0,-.65,-1.6),Vector3(.07,.5,.07),"gear")
		wheel(Vector3(0,-.95,-1.6),.18)

func plane_anchors() -> Dictionary:
	return {"nose":Vector3(0,-.55,-1.7),"side":Vector3(.62,.1,-.4),"belly":Vector3(0,-.65,0),"top":Vector3(0,.9,.5),"tail":Vector3(0,1.48,3.5),
		"skid":[.85,-1.15,-.5,2.6],"wing":[2.0,.65,-.4],"exhaust":[Vector3(.42,-.35,-1.35)],
		"beacon":Vector3(0,.86,-.1),"strobes":[Vector3(-4.55,.78,-.4),Vector3(4.55,.78,-.4),Vector3(0,1.46,3.62)],"nav":[Vector3(-4.56,.78,-.9),Vector3(4.56,.78,-.9)],"landing":Vector3(-2.0,.72,-1.07),
		"eyes":Vector3(0,.5,-1.28),"tip":Vector3(-3.6,.8,-1.05),"rear":Vector3(0,.3,3.7),"crown":Vector3(0,.86,-.6),"shadow":Vector2(9.5,6.5)}

func build_sport() -> Dictionary:
	plane_body(false)
	return plane_anchors()

func build_zee() -> Dictionary:
	plane_body(true)
	for side in [-1,1]:
		var float_mesh = CapsuleMesh.new()
		float_mesh.radius = .3
		float_mesh.height = 3.6
		var pontoon = part(float_mesh, Vector3(side*.95,-1.25,-.4), Vector3.ONE, paint_materials.trim, body)
		pontoon.rotation.x = PI / 2
		box(Vector3(side*.95,-1.0,-.4),Vector3(.25,.06,2.6),"body")
		for z in [-1.2,.4]:
			var strut = box(Vector3(side*.6,-.62,z),Vector3(.07,.9,.07),"gear")
			strut.rotation.z = -side*.45
		box(Vector3(side*4.1,.45,-.4),Vector3(.12,.6,.12),"gear")
		ball(Vector3(side*4.1,.12,-.4),Vector3(.25,.22,.7),"trim")
	var a = plane_anchors()
	a.skid = [.95,-1.55,-.4,3.2]
	a.belly = Vector3(0,-.6,.6)
	return a

# Biplane: two wings with struts and bracing wires, a round engine cowl and
# an open cockpit.
func build_dubbel() -> Dictionary:
	box(Vector3(0,0,0),Vector3(1.0,1.0,4.6),"body")
	box(Vector3(0,.1,2.6),Vector3(.6,.6,1.4),"body")
	tube(Vector3(0,0,-2.35),.55,.5,"trim")
	box(Vector3(0,1.15,-.6),Vector3(8.0,.1,1.2),"body")
	box(Vector3(0,-.45,-.4),Vector3(7.4,.1,1.1),"body")
	box(Vector3(0,.52,.2),Vector3(.6,.04,.7),"rotor")
	box(Vector3(0,.66,-.18),Vector3(.5,.25,.04),"glass")
	box(Vector3(0,.1,3.1),Vector3(2.6,.07,.7),"tail")
	fin(Vector3(0,.6,3.15),1.0,.9,"tail")
	add_propeller(Vector3(0,0,-2.68),2.3,2)
	for side in [-1,1]:
		box(Vector3(side*3.8,1.15,-.6),Vector3(.45,.11,1.22),"trim")
		box(Vector3(side*3.5,-.45,-.4),Vector3(.45,.11,1.12),"trim")
		for x in [1.1,3.0]:
			box(Vector3(side*x,.35,-.5),Vector3(.07,1.55,.07),"trim")
		var wire = box(Vector3(side*2.05,.35,-.5),Vector3(.02,2.2,.02),"rotor")
		wire.rotation.z = side*.98
		box(Vector3(side*.35,.8,-.6),Vector3(.06,.65,.06),"trim")
		var leg = box(Vector3(side*.45,-.75,-1.0),Vector3(.07,.7,.07),"gear")
		leg.rotation.z = -side*.45
		wheel(Vector3(side*.72,-1.05,-1.0),.3)
		box(Vector3(side*.5,.4,-1.6),Vector3(.04,.1,.5),"rotor")
	box(Vector3(0,-.42,3.0),Vector3(.06,.4,.06),"gear")
	return {"nose":Vector3(0,-.45,-2.3),"side":Vector3(.52,.2,-.6),"belly":Vector3(0,-.6,.6),"top":Vector3(0,1.25,.4),"tail":Vector3(0,1.12,3.55),
		"skid":[.75,-1.4,-.4,2.4],"wing":[2.0,-.5,-.4],"exhaust":[Vector3(.52,.15,-1.8),Vector3(-.52,.15,-1.8)],
		"beacon":Vector3(0,1.24,-.6),"strobes":[Vector3(-4.05,1.15,-.6),Vector3(4.05,1.15,-.6),Vector3(0,1.1,3.62)],"nav":[Vector3(-3.75,-.45,-.4),Vector3(3.75,-.45,-.4)],"landing":Vector3(0,-.52,-.98),
		"eyes":Vector3(0,.55,-1.95),"tip":Vector3(-3.0,1.15,-1.3),"rear":Vector3(0,.2,3.6),"crown":Vector3(0,1.24,-.2),"shadow":Vector2(8.5,6.0)}

# Twin-engined transport: a long round body with a row of windows, a low wing
# with two engines and a tail wheel.
func build_dakota() -> Dictionary:
	ball(Vector3(0,0,-.5),Vector3(1.5,1.6,7.0),"body")
	ball(Vector3(0,.35,-3.5),Vector3(1.0,.5,.7),"glass")
	taper(Vector3(0,.18,2.0),Vector3(0,.42,4.25),.68,.2,"body")
	box(Vector3(0,-.45,-.8),Vector3(11.0,.14,1.6),"body")
	box(Vector3(0,.4,3.9),Vector3(3.8,.08,.9),"tail")
	fin(Vector3(0,1.2,3.8),1.7,1.5,"tail")
	box(Vector3(0,-.15,-.5),Vector3(1.52,.1,5.5),"trim")
	for side in [-1,1]:
		for i in 6:
			box(Vector3(side*.74,.25,-2.0+i*.65),Vector3(.03,.25,.3),"glass")
		box(Vector3(side*5.25,-.45,-.8),Vector3(.5,.15,1.62),"trim")
		ball(Vector3(side*2.2,-.3,-1.4),Vector3(.75,.75,2.0),"trim")
		add_propeller(Vector3(side*2.2,-.3,-2.45),2.3,3)
		box(Vector3(side*2.2,-.8,-1.1),Vector3(.1,.6,.1),"gear")
		wheel(Vector3(side*2.2,-1.1,-1.1),.35)
	wheel(Vector3(0,-.32,3.8),.15)
	return {"nose":Vector3(0,-.55,-3.3),"side":Vector3(.78,.2,-1.0),"belly":Vector3(0,-.8,-.3),"top":Vector3(0,.85,0),"tail":Vector3(0,2.05,4.5),
		"skid":[2.2,-1.5,-1.3,2.4],"wing":[3.6,-.5,-.6],"exhaust":[Vector3(-2.2,-.1,-.5),Vector3(2.2,-.1,-.5)],
		"beacon":Vector3(0,.82,.5),"strobes":[Vector3(-5.55,-.45,-.8),Vector3(5.55,-.45,-.8),Vector3(0,2.05,4.62)],"nav":[Vector3(-5.56,-.45,-1.35),Vector3(5.56,-.45,-1.35)],"landing":Vector3(0,-.75,-3.0),
		"eyes":Vector3(0,.55,-3.38),"tip":Vector3(-4.5,-.45,-1.6),"rear":Vector3(0,.4,4.5),"crown":Vector3(0,.85,-2.0),"shadow":Vector2(11.5,9.0)}

# Shared jet parts: a long body with a pointed nose, a bubble canopy, a
# nozzle with the afterburner, and a light tricycle undercarriage.
func jet_body(length: float, radius: float) -> void:
	tube(Vector3(0,0,.2),radius,length,"body")
	nose_cone(Vector3(0,0,.2-length*.5-.6),radius,1.2,"body")
	ball(Vector3(0,radius*.92,-length*.3),Vector3(.55,.5,1.5),"glass")
	tube(Vector3(0,0,.2+length*.5+.2),radius*.82,.5,"rotor")
	for side in [-1,1]:
		box(Vector3(side*.55,-.62,.3),Vector3(.06,.45,.06),"gear")
		wheel(Vector3(side*.6,-.8,.3),.18)
	box(Vector3(0,-.6,-length*.32),Vector3(.06,.45,.06),"gear")
	wheel(Vector3(0,-.82,-length*.32),.14)

# Single-engined fighter: swept wings with missiles on the tips and a belly
# intake.
func build_valk() -> Dictionary:
	jet_body(6.4,.45)
	box(Vector3(0,-.45,-.6),Vector3(.6,.4,1.6),"rotor")
	for side in [-1,1]:
		var skew = 0.0 if side > 0 else 1.0
		delta_wing(Vector3(side*1.65,-.05,.6),2.7,2.6,.1,"body",skew)
		delta_wing(Vector3(side*.95,0,3.0),1.3,1.2,.08,"tail",skew)
		tube(Vector3(side*3.05,-.05,1.4),.06,1.8,"trim")
		nose_cone(Vector3(side*3.05,-.05,.35),.06,.3,"accent")
		delta_wing(Vector3(side*1.4,-.05,1.65),.6,.6,.11,"trim",skew)
	fin(Vector3(0,.95,2.6),1.5,1.6,"tail")
	return {"nose":Vector3(0,-.45,-2.4),"side":Vector3(.46,0,-1.0),"belly":Vector3(0,-.7,.4),"top":Vector3(0,.48,-.4),"tail":Vector3(0,1.75,3.35),
		"skid":[.7,-.95,0.0,3.0],"wing":[1.6,-.15,.9],"exhaust":[Vector3(0,0,3.9)],
		"beacon":Vector3(0,.47,.2),"strobes":[Vector3(0,1.72,3.42),Vector3(-3.05,-.05,.42),Vector3(3.05,-.05,.42)],"nav":[Vector3(-3.05,.08,2.2),Vector3(3.05,.08,2.2)],"landing":Vector3(0,-.6,-1.9),
		"eyes":Vector3(0,.42,-2.6),"eye_gap":.2,"tip":Vector3(0,0,-4.15),"rear":Vector3(0,.1,4.4),"crown":Vector3(0,.95,-1.9),"shadow":Vector2(6.5,8.0)}

# Delta fighter: one big triangular wing with small canards at the front.
func build_delta() -> Dictionary:
	jet_body(6.0,.45)
	delta_wing(Vector3(0,-.05,1.2),6.4,4.2,.1,"body")
	delta_wing(Vector3(0,-.03,2.1),4.2,2.4,.11,"trim")
	delta_wing(Vector3(0,.08,-1.15),2.2,.9,.06,"trim")
	for side in [-1,1]:
		box(Vector3(side*.55,-.05,-.8),Vector3(.3,.5,1.2),"rotor")
	fin(Vector3(0,1.0,2.4),1.7,2.0,"tail")
	return {"nose":Vector3(0,-.45,-2.3),"side":Vector3(.6,0,-1.0),"belly":Vector3(0,-.7,.6),"top":Vector3(0,.48,-.3),"tail":Vector3(0,1.85,3.35),
		"skid":[.7,-.95,0.2,3.0],"wing":[1.6,-.15,1.6],"exhaust":[Vector3(0,0,3.75)],
		"beacon":Vector3(0,.47,.3),"strobes":[Vector3(0,1.82,3.42),Vector3(-3.15,-.05,3.25),Vector3(3.15,-.05,3.25)],"nav":[Vector3(-3.0,.05,3.05),Vector3(3.0,.05,3.05)],"landing":Vector3(0,-.6,-1.8),
		"eyes":Vector3(0,.42,-2.4),"eye_gap":.2,"tip":Vector3(0,0,-3.95),"rear":Vector3(0,.1,4.2),"crown":Vector3(0,.95,-1.8),"shadow":Vector2(7.0,8.0)}

# Stealth jet: a flat, faceted flying wing with a raised middle, a dark
# canopy, two outward-leaning fins and slot exhausts.
func build_schaduw() -> Dictionary:
	delta_wing(Vector3(0,0,.6),7.0,5.5,.18,"body")
	delta_wing(Vector3(0,.2,.2),2.4,4.4,.35,"body")
	delta_wing(Vector3(0,.02,2.6),5.4,1.4,.2,"trim")
	ball(Vector3(0,.42,-.9),Vector3(.55,.32,1.3),"glass")
	for side in [-1,1]:
		fin(Vector3(side*.75,.65,2.45),1.1,1.4,"tail",side*.5)
		box(Vector3(side*.5,.12,2.95),Vector3(.6,.1,.18),"rotor")
		box(Vector3(side*.9,-.35,.6),Vector3(.06,.35,.06),"gear")
		wheel(Vector3(side*.9,-.48,.6),.18)
	box(Vector3(0,-.35,-1.2),Vector3(.06,.35,.06),"gear")
	wheel(Vector3(0,-.5,-1.2),.14)
	return {"nose":Vector3(0,-.2,-1.6),"side":Vector3(.95,.1,-.2),"belly":Vector3(0,-.3,.6),"top":Vector3(0,.42,.5),"tail":Vector3(0,.5,2.8),
		"skid":[.9,-.65,.4,2.6],"wing":[1.8,-.1,1.5],"exhaust":[Vector3(-.5,.12,3.25),Vector3(.5,.12,3.25)],
		"beacon":Vector3(0,.43,.7),"strobes":[Vector3(-3.45,0,3.32),Vector3(3.45,0,3.32),Vector3(0,.5,3.15)],"nav":[Vector3(-3.25,.05,3.1),Vector3(3.25,.05,3.1)],"landing":Vector3(0,-.15,-1.45),
		"eyes":Vector3(0,.5,-1.5),"eye_gap":.22,"tip":Vector3(0,.15,-2.1),"rear":Vector3(0,.2,3.5),"crown":Vector3(0,.7,-.9),"shadow":Vector2(7.5,6.5)}

# Smoke out of the back, drawn in the aircraft's own space so it streams
# behind at any size. Rainbow smoke picks a colour per puff.
func smoke_trail(at: Vector3, rainbow: bool) -> void:
	var puff = CPUParticles3D.new()
	puff.position = at
	puff.amount = 36
	puff.lifetime = 1.4
	puff.local_coords = true
	puff.direction = Vector3(0,0,1)
	puff.spread = 8.0
	puff.gravity = Vector3(0,.3,0)
	puff.initial_velocity_min = 3.2
	puff.initial_velocity_max = 4.0
	puff.scale_amount_min = .6
	puff.scale_amount_max = 1.0
	var grow = Curve.new()
	grow.add_point(Vector2(0,.5))
	grow.add_point(Vector2(1,1.8))
	puff.scale_amount_curve = grow
	var mesh = SphereMesh.new()
	mesh.radius = .22
	mesh.height = .44
	mesh.radial_segments = 8
	mesh.rings = 4
	puff.mesh = mesh
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff.material_override = m
	var fade = Gradient.new()
	fade.set_color(0, Color(1,1,1,.75))
	fade.set_color(1, Color(1,1,1,0))
	puff.color_ramp = fade
	if rainbow:
		var colours = Gradient.new()
		colours.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
		var bands = ["e8453a","ff9a3c","f4c51c","3fbf6a","3b7dd8","8a4fd8"]
		colours.set_color(0, Color(bands[0]))
		colours.set_color(1, Color(bands[5]))
		for i in range(1,5):
			colours.add_point(i / 6.0, Color(bands[i]))
		colours.set_offset(1, 5.0 / 6.0)
		puff.color_initial_ramp = colours
	else:
		puff.color = ToyLook.color_of(paint_materials.accent).lightened(.35)
		puff.set_meta("tint", true)
	puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(puff)

func build_accessory(id: String, a: Dictionary) -> void:
	var white = material(Color("f6f6f2"))
	match id:
		"vlag":
			tube(a.tail + Vector3(0,.4,-.2), .025, .8, "rotor", "y")
			var f = Node3D.new()
			f.position = a.tail + Vector3(0,.66,-.2)
			body.add_child(f)
			for i in 3:
				part(BoxMesh.new(), Vector3(0,.12-i*.12,.4), Vector3(.02,.12,.8), material(Color(["ae1c28","f4f4f0","21468b"][i])), f)
			flags.append(f)
		"ogen":
			for side in [-1,1]:
				var at: Vector3 = a.eyes + Vector3(side * float(a.eye_gap), 0, 0)
				part(sphere, at, Vector3(.34,.36,.2), white, body)
				part(sphere, at + Vector3(0,-.02,-.09), Vector3(.15,.17,.06), material(Color("15181c")), body)
				part(sphere, at + Vector3(.03,.03,-.115), Vector3(.05,.05,.02), glow_material(Color.WHITE), body)
		"haaienbek":
			var mouth: Vector3 = a.eyes + Vector3(0,-.4,.02)
			part(sphere, mouth, Vector3(.62,.16,.1), material(Color("b8212f")), body)
			for i in 6:
				var tooth = PrismMesh.new()
				var t = part(tooth, mouth + Vector3(-.25 + i * .1, .02, -.05), Vector3(.08,.1,.03), white, body)
				t.rotation.z = PI
				t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		"zwaailichten":
			box(a.top + Vector3(0,.08,0), Vector3(.75,.08,.2), "rotor")
			for i in 2:
				var lamp = part(sphere, a.top + Vector3(-.25 + i * .5,.17,0), Vector3(.2,.14,.16), glow_material(Color("2a6bff") if i == 0 else Color("ff3b30")), body)
				flashers.append(lamp)
		"wielen":
			var k: Array = a.skid
			for side in [-1,1]:
				for dz in [-.35,.35]:
					wheel(Vector3(side * float(k[0]), float(k[1]) - .05, float(k[2]) + dz * float(k[3])), .22)
		"skis":
			var k: Array = a.skid
			for side in [-1,1]:
				box(Vector3(side * float(k[0]), float(k[1]) - .14, float(k[2])), Vector3(.28,.05,float(k[3]) * .95), "accent")
				var tip = box(Vector3(side * float(k[0]), float(k[1]) - .05, float(k[2]) - float(k[3]) * .5), Vector3(.28,.05,.35), "accent")
				tip.rotation.x = .6
		"megafoon":
			var horn = CylinderMesh.new()
			horn.top_radius = .06
			horn.bottom_radius = .2
			horn.height = .45
			var h = part(horn, a.side + Vector3(.22,.3,-.25), Vector3.ONE, paint_materials.accent, body)
			h.rotation.x = PI / 2
			box(a.side + Vector3(.1,.3,0), Vector3(.2,.06,.06), "rotor")
		"radar":
			tube(a.top + Vector3(0,.2,0), .04, .4, "rotor", "y")
			var spin = Node3D.new()
			spin.position = a.top + Vector3(0,.42,0)
			body.add_child(spin)
			var dish = CylinderMesh.new()
			dish.top_radius = .5
			dish.bottom_radius = .32
			dish.height = .07
			var d = part(dish, Vector3(0,.12,-.05), Vector3.ONE, paint_materials.accent, spin)
			d.rotation.x = .9
			part(BoxMesh.new(), Vector3(0,.04,0), Vector3(.12,.12,.12), paint_materials.trim, spin)
			spinners.append(spin)
		"ballonnen":
			var colours = ["e8453a","f4c51c","3b7dd8"]
			for i in 3:
				var bob = Node3D.new()
				var lift = 1.4 + i * .25
				bob.position = a.top + Vector3(-.35 + i * .35, lift, .35)
				bob.set_meta("y", bob.position.y)
				body.add_child(bob)
				var balloon = material(Color(colours[i]), .95)
				part(sphere, Vector3.ZERO, Vector3(.45,.55,.45), balloon, bob)
				part(CylinderMesh.new(), Vector3(0,-lift * .5 - .1,0), Vector3(.012,lift * .5,.012), white, bob)
				bobbers.append(bob)
		"tanks":
			var w: Array = a.wing
			for side in [-1,1]:
				var tank = CapsuleMesh.new()
				tank.radius = .17
				tank.height = 1.5
				var t = part(tank, Vector3(side * (float(w[0]) + .1), float(w[1]) - .38, float(w[2])), Vector3.ONE, paint_materials.accent, body)
				t.rotation.x = PI / 2
				box(Vector3(side * (float(w[0]) + .1), float(w[1]) - .18, float(w[2])), Vector3(.05,.2,.5), "rotor")
		"lichtslinger":
			var colours = [Color("ff3b30"),Color("f4c51c"),Color("3fbf6a"),Color("3b8bff")]
			for side in [-1,1]:
				var from = Vector3(side * a.side.x, a.side.y + .35, a.side.z - .5)
				var to = Vector3(side * a.side.x * .5, a.side.y + .45, a.tail.z - .6)
				for i in 8:
					var bulb = part(sphere, from.lerp(to, i / 7.0), Vector3(.1,.12,.1), glow_material(colours[(i + (1 if side > 0 else 0)) % 4]), body)
					twinkles.append(bulb)
		"koffer":
			var case_mesh = CapsuleMesh.new()
			case_mesh.radius = .28
			case_mesh.height = 1.6
			var c = part(case_mesh, a.belly + Vector3(0,-.34,-.2), Vector3(1.0,1.0,.85), paint_materials.accent, body)
			c.rotation.x = PI / 2
			for dz in [-.4,.3]:
				box(a.belly + Vector3(0,-.34,-.2 + dz), Vector3(.58,.5,.06), "trim")
		"rookspoor":
			smoke_trail(a.rear, false)
		"regenboog":
			smoke_trail(a.rear + Vector3(0,-.1,0), true)
		"meetneus":
			var tip: Vector3 = a.tip
			tube(tip + Vector3(0,0,-.8), .035, 1.6, "rotor")
			for i in 3:
				tube(tip + Vector3(0,0,-.35 - i * .45), .05, .18, "accent")
			box(tip + Vector3(0,.08,-1.25), Vector3(.02,.16,.12), "accent")
		"bluskorf":
			var hang = Node3D.new()
			hang.position = a.belly
			body.add_child(hang)
			var line = 2.2
			part(CylinderMesh.new(), Vector3(0,-line * .5,0), Vector3(.03,line * .5,.03), paint_materials.rotor, hang)
			var bucket = CylinderMesh.new()
			bucket.top_radius = .42
			bucket.bottom_radius = .28
			bucket.height = .55
			part(bucket, Vector3(0,-line - .28,0), Vector3.ONE, paint_materials.accent, hang)
			var rim = part(TorusMesh.new(), Vector3(0,-line - .02,0), Vector3(.45,.6,.45), paint_materials.trim, hang)
			(rim.mesh as TorusMesh).inner_radius = .9
			(rim.mesh as TorusMesh).outer_radius = 1.0
			swings.append(hang)
		"zonnepaneel":
			var panel = material(Color("1c3a6a"), .95)
			part(BoxMesh.new(), a.top + Vector3(0,.12,.15), Vector3(1.0,.04,.7), panel, body)
			for i in 3:
				box(a.top + Vector3(-.25 + i * .25,.145,.15), Vector3(.015,.01,.7), "trim")
			box(a.top + Vector3(0,.145,.15), Vector3(1.0,.01,.015), "trim")
		"banner":
			var at: Vector3 = a.rear
			var tow = tube(at + Vector3(0,-.15,1.1), .015, 2.2, "rotor")
			tow.rotation.x = PI / 2 - .1
			var b = Node3D.new()
			b.position = at + Vector3(0,-.35,2.2)
			body.add_child(b)
			part(BoxMesh.new(), Vector3(0,0,1.7), Vector3(.03,.6,3.4), white, b)
			part(BoxMesh.new(), Vector3(0,.31,1.7), Vector3(.035,.05,3.4), paint_materials.accent, b)
			part(BoxMesh.new(), Vector3(0,-.31,1.7), Vector3(.035,.05,3.4), paint_materials.accent, b)
			for side in [-1,1]:
				var text = Label3D.new()
				text.text = "NIEKS TOPORADAR"
				text.font_size = 72
				text.pixel_size = .0042
				text.outline_size = 0
				text.modulate = Color("c8211d")
				text.position = Vector3(side * .025,0,1.7)
				text.rotation.y = side * PI / 2
				text.double_sided = false
				b.add_child(text)
			flags.append(b)
		"vuurwerk":
			var w: Array = a.wing
			var colours = [Color("ff3b30"),Color("3fbf6a"),Color("f4c51c")]
			for side in [-1,1]:
				for i in 3:
					var at = Vector3(side * (float(w[0]) + .25 + i * .14), float(w[1]) - .2 - (i % 2) * .1, float(w[2]))
					tube(at, .06, .8, "accent")
					var spark = part(sphere, at + Vector3(0,0,-.42), Vector3(.1,.1,.1), glow_material(colours[i]), body)
					twinkles.append(spark)
		"kroon":
			var gold = material(Color("e8c33a"), 1.0)
			var at: Vector3 = a.crown
			var ring = CylinderMesh.new()
			ring.top_radius = .3
			ring.bottom_radius = .27
			ring.height = .2
			part(ring, at, Vector3.ONE, gold, body)
			for i in 7:
				var angle = TAU * i / 7.0
				var point = CylinderMesh.new()
				point.top_radius = 0.0
				point.bottom_radius = .07
				point.height = .2
				part(point, at + Vector3(cos(angle) * .27,.2,sin(angle) * .27), Vector3.ONE, gold, body)
			for i in 3:
				part(sphere, at + Vector3(-.12 + i * .12,0,-.29), Vector3(.07,.07,.03), glow_material(Color(["e8453a","3b7dd8","3fbf6a"][i])), body)
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
			var load_line = Node3D.new()
			load_line.position = a.belly
			body.add_child(load_line)
			swings.append(load_line)
			var line = 1.0 if config.model == "kraan" else 1.6
			part(CylinderMesh.new(), Vector3(0,-line * .5,0), Vector3(.03,line * .5,.03), paint_materials.rotor, load_line)
			part(BoxMesh.new(), Vector3(0,-line - .42,0), Vector3(1.0,.8,.8), paint_materials.accent, load_line)
			for y in [-.22,.22]:
				part(BoxMesh.new(), Vector3(0,-line - .42 + y,0), Vector3(1.03,.08,.83), paint_materials.trim, load_line)
		"wimpel":
			tube(a.tail + Vector3(0,.35,0), .025, .7, "rotor", "y")
			var pennant = Node3D.new()
			pennant.position = a.tail + Vector3(0,.58,0)
			body.add_child(pennant)
			part(BoxMesh.new(), Vector3(0,0,.35), Vector3(.02,.3,.7), paint_materials.accent, pennant)
			flags.append(pennant)

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
		ToyLook.recolor(paint_materials[slot], Color(full[slot]))
	# Plain smoke has the accessory colour, a little lighter.
	if is_instance_valid(body):
		for child in body.get_children():
			if child is CPUParticles3D and child.has_meta("tint"):
				child.color = Color(full.accent).lightened(.35)

func paint_hex(slot: String) -> String:
	return ToyLook.color_of(paint_materials[slot]).to_html(false)

func _process(delta: float) -> void:
	ground_shadow.global_position.y=.09
	time += delta
	for i in rotors.size():
		rotors[i].rotation.y += delta * (32.0 if running else 3.0) * rotor_spin[i]
	for t in tail_rotors:
		t.rotation.x += delta * 44.0
	for p in propellers:
		p.rotation.z += delta * (40.0 if running else 4.0)
	for s in spinners:
		s.rotation.y += delta * 2.2
	for i in bobbers.size():
		bobbers[i].position.y = float(bobbers[i].get_meta("y")) + sin(time * 2.1 + i * 1.7) * .08
		bobbers[i].rotation.z = sin(time * 1.3 + i) * .12
	# Police lights take turns; the light string runs a colour chase.
	for i in flashers.size():
		flashers[i].visible = (int(time * 5.0) + i) % 2 == 0
	for i in twinkles.size():
		twinkles[i].visible = (int(time * 4.0) + i) % 3 != 0
	# Planes and jets do not bob like a hovering helicopter.
	body.position.y = sin(time * 3.0) * (.1 if kind == "heli" else .04)
	# Beacon pulses once a second; strobes give a quick double flash.
	beacon_light.visible = fmod(time, 1.0) < .45
	var strobe_phase = fmod(time + .5, 1.3)
	for strobe in strobes:
		strobe.visible = strobe_phase < .06 or (strobe_phase > .14 and strobe_phase < .2)
	for glow in exhausts:
		glow.scale.z = float(glow.get_meta("length", .3)) * (.85 + .3 * absf(sin(time * 23.0 + glow.position.x)))
	for i in swings.size():
		swings[i].rotation.x = sin(time * 1.7 + i) * .07
		swings[i].rotation.z = sin(time * 1.1 + i) * .04
	for i in flags.size():
		flags[i].rotation.y = sin(time * 6.0 + i) * .25

# Helicopters tip into the direction they fly; planes and jets bank harder
# into a turn and barely pitch.
func lean(direction: Vector2, delta: float) -> void:
	var bank = .14 if kind == "heli" else .42
	var pitch = .12 if kind == "heli" else .04
	body.rotation.z = lerp(body.rotation.z,-direction.x*bank,1.0-exp(-7.0*delta))
	body.rotation.x = lerp(body.rotation.x,-direction.y*pitch,1.0-exp(-7.0*delta))
