class_name RotorHelicopter
extends Node3D

var rotor: Node3D
var tail_rotor: Node3D
var body: Node3D
var ground_shadow: MeshInstance3D
var running: bool = true
var time: float = 0.0

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

func _ready() -> void:
	body = Node3D.new()
	add_child(body)
	var amber = material(Color("e67b34"),.15)
	var dark = material(Color("263845"),.3)
	var glass = material(Color("234c68"),.25)
	var cream = material(Color("dce4dc"),.2)
	var sphere = SphereMesh.new()
	sphere.radial_segments = 16
	sphere.rings = 8
	part(sphere,Vector3(0,0,0),Vector3(1.9,1.45,2.5),amber,body)
	part(sphere,Vector3(0,.22,-.65),Vector3(1.78,1.15,1.65),glass,body)
	part(BoxMesh.new(),Vector3(0,.16,-.9),Vector3(.07,1.35,1.25),dark,body)
	part(BoxMesh.new(),Vector3(0,-.1,-1),Vector3(1.6,.08,.06),dark,body)
	var boom = part(BoxMesh.new(),Vector3(0,.05,2.1),Vector3(.3,.3,3.6),amber,body)
	boom.rotation.x = -.07
	part(BoxMesh.new(),Vector3(0,.6,3.75),Vector3(.16,1.4,.8),amber,body)
	part(BoxMesh.new(),Vector3(0,.15,3.0),Vector3(1.7,.1,.5),cream,body)
	for side in [-1,1]:
		part(BoxMesh.new(),Vector3(side*1.1,-.83,0),Vector3(.12,.12,3.5),dark,body)
		for z in [-.65,.75]:
			var leg = part(BoxMesh.new(),Vector3(side*.83,-.45,z),Vector3(.1,.8,.1),cream,body)
			leg.rotation.z = -side*.5
	part(CylinderMesh.new(),Vector3(0,1.1,.12),Vector3(.15,.5,.15),dark,body)
	rotor = Node3D.new()
	rotor.position = Vector3(0,1.42,.12)
	body.add_child(rotor)
	for angle in [0.0,PI/2]:
		var blade = part(BoxMesh.new(),Vector3.ZERO,Vector3(8.0,.045,.22),dark,rotor)
		blade.rotation.y = angle
	part(sphere,Vector3.ZERO,Vector3(.48,.19,.48),cream,rotor)
	tail_rotor = Node3D.new()
	tail_rotor.position = Vector3(.21,.7,3.8)
	body.add_child(tail_rotor)
	for angle in [0.0,PI/2]:
		var blade = part(BoxMesh.new(),Vector3.ZERO,Vector3(.055,1.55,.12),dark,tail_rotor)
		blade.rotation.x = angle
	# Engine housing, side doors and navigation lights read well from above.
	part(sphere,Vector3(0,.8,.55),Vector3(.8,.4,.9),cream,body)
	for side in [-1,1]:
		part(BoxMesh.new(),Vector3(side*.91,.0,.25),Vector3(.035,.62,.85),cream,body)
		part(BoxMesh.new(),Vector3(side*.94,.15,.25),Vector3(.04,.3,.55),glass,body)
		part(sphere,Vector3(side*.95,.15,-.35),Vector3(.13,.13,.13),material(Color("e8654a") if side<0 else Color("9ed9a4")),body)
	# Rescue explorer: twin turbines, reinforced nose, outriggers and hazard stripes.
	for side in [-1,1]:
		part(sphere,Vector3(side*.52,.85,.8),Vector3(.58,.48,1.6),dark,body)
		part(CylinderMesh.new(),Vector3(side*.52,.96,1.45),Vector3(.22,.2,.22),cream,body)
		part(BoxMesh.new(),Vector3(side*1.1,-.05,.7),Vector3(.65,.15,1.2),dark,body)
		part(BoxMesh.new(),Vector3(side*.98,-.25,.1),Vector3(.04,.15,1.3),dark,body)
		for i in 3:
			var stripe=part(BoxMesh.new(),Vector3(side*.975,.05,-.05+i*.22),Vector3(.045,.36,.09),cream,body)
			stripe.rotation.x=-.4
		part(sphere,Vector3(side*.45,-.25,-1.08),Vector3(.21,.21,.13),cream,body)
	part(BoxMesh.new(),Vector3(0,-.58,-1.02),Vector3(.5,.28,.35),dark,body)
	part(CylinderMesh.new(),Vector3(0,1.06,1.4),Vector3(.055,.8,.055),dark,body)
	part(BoxMesh.new(),Vector3(0,.25,3.6),Vector3(1.8,.08,.35),cream,body)
	# Alpha falloff avoids a hard disc and needs no screen-space effects.
	var shadow_mat = ShaderMaterial.new()
	shadow_mat.shader = load("res://assets/shaders/aircraft_shadow.gdshader")
	var shadow = PlaneMesh.new()
	shadow.size = Vector2(5.5,7.0)
	ground_shadow = part(shadow,Vector3(.5,-3.15/scale.y,.4),Vector3.ONE,shadow_mat,self)
	ground_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _process(delta: float) -> void:
	ground_shadow.global_position.y=.09
	time += delta
	rotor.rotation.y += delta * (32.0 if running else 3.0)
	tail_rotor.rotation.x += delta * 44.0
	body.position.y = sin(time * 3.0) * .1

func lean(direction: Vector2, delta: float) -> void:
	body.rotation.z = lerp(body.rotation.z,-direction.x*.14,1.0-exp(-7.0*delta))
	body.rotation.x = lerp(body.rotation.x,-direction.y*.12,1.0-exp(-7.0*delta))
