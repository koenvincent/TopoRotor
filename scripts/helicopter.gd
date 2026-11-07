class_name RotorHelicopter
extends Node3D

var rotor: Node3D
var tail_rotor: Node3D
var body: Node3D
var running: bool = true
var time: float = 0.0

func material(color: Color, metal: float = 0.0) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metal
	m.roughness = 0.45
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
	var amber = material(Color("ffbf57"),.15)
	var dark = material(Color("183947"),.3)
	var glass = material(Color("69b9c6"),.55)
	var cream = material(Color("f4edcf"),.2)
	var sphere = SphereMesh.new()
	sphere.radial_segments = 16
	sphere.rings = 8
	part(sphere,Vector3(0,0,0),Vector3(2.7,1.1,1.6),amber,body)
	part(sphere,Vector3(0,.23,-.86),Vector3(2.42,.8,.95),glass,body)
	part(BoxMesh.new(),Vector3(0,.16,-.9),Vector3(.08,1.2,.65),dark,body)
	part(BoxMesh.new(),Vector3(0,-.1,-1),Vector3(2.05,.1,.05),dark,body)
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
	# Soft circular shadow moves with the aircraft; cheap on phones.
	var shadow_mat = material(Color(0.03,.1,.12,.22))
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var disc = CylinderMesh.new()
	disc.top_radius = 1.6
	disc.bottom_radius = 1.6
	disc.height = .012
	part(disc,Vector3(0,-3.15/scale.y,0),Vector3.ONE,shadow_mat,self)

func _process(delta: float) -> void:
	time += delta
	rotor.rotation.y += delta * (32.0 if running else 3.0)
	tail_rotor.rotation.x += delta * 44.0
	body.position.y = sin(time * 3.0) * .1

func lean(direction: Vector2, delta: float) -> void:
	body.rotation.z = lerp(body.rotation.z,-direction.x*.14,delta*5)
	body.rotation.x = lerp(body.rotation.x,-direction.y*.12,delta*5)
