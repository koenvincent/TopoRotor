class_name PilotFigure
extends Node3D

# The player's pilot as a small procedural figure: body, skin, hair, headwear,
# glasses, facial hair and outfit. Every profile stores one look; the hangar
# and the pilot screen show it standing next to the helicopter.
#
# The figure faces -z (the helicopter's nose direction). Units: the feet stand
# on y=0 and the top of the head is at about y=2.2.

const BODIES = [["man","Man"],["vrouw","Vrouw"]]
const SKINS = [["f6d7c3","Licht"],["eac0a0","Lichtgetint"],["d39b72","Getint"],["b07650","Bruin"],["8a5636","Donkerbruin"],["5e3a24","Donker"]]
const HAIR = [["kort","Kort"],["stekels","Stekels"],["krullen","Krullen"],["lang","Lang"],["staart","Paardenstaart"],["knot","Knot"],["vlechten","Vlechten"],["kaal","Kaal"]]
const HAIR_COLOURS = [["2b1d14","Zwart"],["5a3a22","Donkerbruin"],["8b5a2b","Bruin"],["d8b25c","Blond"],["b5502a","Rood"],["b9b4ab","Grijs"],["3b7dd8","Blauw"],["e06aa8","Roze"]]
const HEADWEAR = [["geen","Geen"],["pet","Pet"],["helm","Vlieghelm"],["koptelefoon","Koptelefoon"],["muts","Muts"],["hoed","Cowboyhoed"]]
const GLASSES = [["geen","Geen"],["rond","Ronde bril"],["zonnebril","Zonnebril"],["vliegbril","Vliegbril"]]
const FACE = [["geen","Geen"],["snor","Snor"],["baard","Baard"],["sik","Sik"],["sproeten","Sproeten"]]
const OUTFITS = [["vliegpak","Vliegpak"],["jack","Bomberjack"],["hoodie","Hoodie"],["uniform","Uniform"],["reddingsvest","Reddingsvest"]]
const OUTFIT_COLOURS = [["e67b34","Oranje"],["2f6f4f","Groen"],["264a7a","Blauw"],["7a2f3b","Rood"],["3a3f47","Antraciet"],["8a6a3c","Bruin"],["c9c2b0","Zand"],["6a3f8f","Paars"]]
# Attribute id, Dutch label and the option list, in the order of the editor.
const ATTRIBUTES = [["figuur","Figuur",BODIES],["huid","Huidskleur",SKINS],["haar","Kapsel",HAIR],["haarkleur","Haarkleur",HAIR_COLOURS],["hoofd","Op je hoofd",HEADWEAR],["bril","Bril",GLASSES],["gezicht","Gezicht",FACE],["outfit","Outfit",OUTFITS],["kleur","Outfitkleur",OUTFIT_COLOURS]]
const DEFAULT_LOOK = {"figuur":"man","huid":"f6d7c3","haar":"kort","haarkleur":"8b5a2b","hoofd":"koptelefoon","bril":"geen","gezicht":"geen","outfit":"vliegpak","kleur":"e67b34"}

var look: Dictionary = DEFAULT_LOOK.duplicate()
var sphere: SphereMesh
var materials: Dictionary = {}
var root: Node3D

static func options(attribute: String) -> Array:
	for entry in ATTRIBUTES:
		if entry[0]==attribute:
			return entry[2]
	return []

static func option_ids(attribute: String) -> Array:
	var ids: Array=[]
	for option in options(attribute):
		ids.append(option[0])
	return ids

static func option_name(attribute: String,id: String) -> String:
	for option in options(attribute):
		if option[0]==id:
			return option[1]
	return id

# Unknown attributes and values fall back to the default look, so a saved
# profile from another version can never break the figure.
static func clean(raw: Variant) -> Dictionary:
	var result: Dictionary=DEFAULT_LOOK.duplicate()
	if not raw is Dictionary:
		return result
	for attribute in DEFAULT_LOOK:
		var value: Variant=raw.get(attribute)
		if value is String and value in option_ids(attribute):
			result[attribute]=value
	return result

# Next or previous option of one attribute, wrapping round.
static func step(current: Dictionary,attribute: String,direction: int) -> Dictionary:
	var result: Dictionary=clean(current)
	var ids: Array=option_ids(attribute)
	var index: int=maxi(ids.find(result[attribute]),0)
	result[attribute]=ids[posmod(index+direction,ids.size())]
	return result

func _init() -> void:
	sphere=SphereMesh.new()
	sphere.radial_segments=14
	sphere.rings=7

func _ready() -> void:
	if not is_instance_valid(root):
		rebuild()

func configure(new_look: Dictionary) -> void:
	look=clean(new_look)
	rebuild()

func mat(hex: String) -> StandardMaterial3D:
	if not materials.has(hex):
		var m=StandardMaterial3D.new()
		m.albedo_color=Color(hex)
		m.roughness=.75
		materials[hex]=m
	return materials[hex]

func piece(mesh: Mesh,at: Vector3,size: Vector3,hex: String,rotation_deg: Vector3=Vector3.ZERO) -> MeshInstance3D:
	var p=MeshInstance3D.new()
	p.mesh=mesh
	p.material_override=mat(hex)
	p.position=at
	p.scale=size
	p.rotation_degrees=rotation_deg
	root.add_child(p)
	return p

func box(at: Vector3,size: Vector3,hex: String,rotation_deg: Vector3=Vector3.ZERO) -> MeshInstance3D:
	return piece(BoxMesh.new(),at,size,hex,rotation_deg)

func ball(at: Vector3,size: Vector3,hex: String) -> MeshInstance3D:
	return piece(sphere,at,size,hex)

func cylinder(at: Vector3,radius: float,height: float,hex: String,rotation_deg: Vector3=Vector3.ZERO,top: float=-1.0) -> MeshInstance3D:
	var mesh=CylinderMesh.new()
	mesh.radial_segments=14
	mesh.top_radius=radius if top<0 else top
	mesh.bottom_radius=radius
	mesh.height=height
	return piece(mesh,at,Vector3.ONE,hex,rotation_deg)

static func shade(hex: String,amount: float) -> String:
	var c=Color(hex)
	return (c.darkened(amount) if amount>0 else c.lightened(-amount)).to_html(false)

func rebuild() -> void:
	if is_instance_valid(root):
		remove_child(root)
		root.queue_free()
	root=Node3D.new()
	root.name="Figure"
	add_child(root)
	var woman: bool=look.figuur=="vrouw"
	var skin: String=look.huid
	var hair: String=look.haarkleur
	var cloth: String=look.kleur
	var pants: String=shade(cloth,.35) if look.outfit in ["vliegpak","uniform"] else "2f3a4a"
	var shoulder: float=.29 if woman else .34
	# Legs and shoes.
	for side in [-1,1]:
		box(Vector3(side*.12,.47,0),Vector3(.19,.86,.22),pants)
		box(Vector3(side*.12,.06,-.04),Vector3(.21,.12,.32),"2a2522")
	# Torso: a woman's figure is narrower at the shoulders with a wider hip.
	box(Vector3(0,1.25,0),Vector3(shoulder*2,.74,.32),cloth)
	if woman:
		box(Vector3(0,.95,0),Vector3(.56,.18,.31),cloth)
	# Arms with hands.
	for side in [-1,1]:
		box(Vector3(side*(shoulder+.08),1.24,0),Vector3(.15,.66,.17),cloth,Vector3(0,0,side*6))
		ball(Vector3(side*(shoulder+.11),.86,0),Vector3(.15,.15,.15),skin)
	build_outfit(shoulder,cloth)
	# Neck and head.
	cylinder(Vector3(0,1.67,0),.08,.14,skin)
	ball(Vector3(0,1.92,0),Vector3(.44,.5,.44),skin)
	for side in [-1,1]:
		ball(Vector3(side*.22,1.9,0),Vector3(.08,.12,.08),skin)
		ball(Vector3(side*.09,1.95,-.2),Vector3(.065,.07,.04),"1b1b1b")
	ball(Vector3(0,1.88,-.225),Vector3(.07,.08,.06),shade(skin,.1))
	box(Vector3(0,1.8,-.205),Vector3(.12,.025,.02),"9c4a4a")
	if woman:
		for side in [-1,1]:
			box(Vector3(side*.09,1.995,-.205),Vector3(.08,.012,.01),"1b1b1b")
	build_face(skin,hair)
	build_hair(hair,look.hoofd!="geen" and look.hoofd!="koptelefoon")
	build_headwear(cloth)
	build_glasses()

func build_outfit(shoulder: float,cloth: String) -> void:
	match look.outfit:
		"vliegpak":
			box(Vector3(0,1.27,-.165),Vector3(.035,.66,.01),shade(cloth,-.35))
			box(Vector3(-.16,1.43,-.165),Vector3(.13,.07,.01),"f2f0e6")
			for side in [-1,1]:
				box(Vector3(side*.12,.62,-.115),Vector3(.13,.13,.01),shade(cloth,.15))
		"jack":
			box(Vector3(0,1.6,0),Vector3(shoulder*2-.06,.1,.34),"e9dcc0")
			box(Vector3(0,.9,0),Vector3(shoulder*2,.08,.33),shade(cloth,.25))
			box(Vector3(0,1.25,-.165),Vector3(.03,.7,.01),"c9a24a")
		"hoodie":
			ball(Vector3(0,1.62,.14),Vector3(.42,.22,.24),cloth)
			box(Vector3(0,1.06,-.165),Vector3(.32,.16,.01),shade(cloth,.18))
			for side in [-1,1]:
				box(Vector3(side*.06,1.45,-.17),Vector3(.015,.2,.01),"f2f0e6")
		"uniform":
			box(Vector3(0,1.47,-.165),Vector3(.16,.26,.01),"f4f4f0")
			box(Vector3(0,1.4,-.175),Vector3(.045,.24,.01),"c23b3b")
			for side in [-1,1]:
				box(Vector3(side*(shoulder-.05),1.61,0),Vector3(.13,.04,.2),"e3b341")
			box(Vector3(.15,1.38,-.17),Vector3(.1,.04,.01),"e3b341")
		"reddingsvest":
			box(Vector3(0,1.22,0),Vector3(shoulder*2+.05,.6,.36),"ff7a1a")
			for y in [1.05,1.3]:
				box(Vector3(0,y,-.185),Vector3(shoulder*2+.05,.05,.01),"e8f0f0")
			box(Vector3(0,1.22,.185),Vector3(shoulder*2+.05,.05,.01),"e8f0f0")

func build_face(skin: String,hair: String) -> void:
	match look.gezicht:
		"snor":
			box(Vector3(0,1.835,-.215),Vector3(.18,.045,.04),hair)
		"baard":
			ball(Vector3(0,1.76,-.08),Vector3(.4,.3,.34),hair)
			box(Vector3(0,1.835,-.215),Vector3(.18,.045,.04),hair)
			box(Vector3(0,1.8,-.23),Vector3(.1,.025,.02),"9c4a4a")
		"sik":
			ball(Vector3(0,1.71,-.17),Vector3(.11,.13,.08),hair)
		"sproeten":
			for at in [Vector2(-.12,1.89),Vector2(-.08,1.87),Vector2(-.14,1.86),Vector2(.12,1.89),Vector2(.08,1.87),Vector2(.14,1.86)]:
				ball(Vector3(at.x,at.y,-.205),Vector3(.018,.018,.01),shade(skin,.3))

# Under a cap, helmet, beanie or hat only the hair that sticks out is drawn.
func build_hair(hair: String,covered: bool) -> void:
	if look.haar=="kaal":
		return
	if not covered:
		ball(Vector3(0,2.04,.03),Vector3(.47,.3,.47),hair)
	match look.haar:
		"stekels":
			if not covered:
				for i in 5:
					var a=(i-2)*.09
					cylinder(Vector3(a,2.2,.02+absf(a)*.3),.045,.16,hair,Vector3(-15,0,-a*120),0.0)
		"krullen":
			for i in 8:
				var angle=TAU*i/8.0
				ball(Vector3(cos(angle)*.21,1.98+(.08 if not covered else 0.0),sin(angle)*.21+.02),Vector3(.15,.15,.15),hair)
		"lang":
			box(Vector3(0,1.8,.15),Vector3(.46,.5,.12),hair)
			for side in [-1,1]:
				box(Vector3(side*.21,1.82,-.02),Vector3(.06,.36,.2),hair)
		"staart":
			ball(Vector3(0,1.9,.27),Vector3(.13,.13,.13),hair)
			ball(Vector3(0,1.72,.33),Vector3(.13,.36,.13),hair)
		"knot":
			if not covered:
				ball(Vector3(0,2.24,.1),Vector3(.2,.18,.2),hair)
			else:
				ball(Vector3(0,1.95,.25),Vector3(.18,.18,.16),hair)
		"vlechten":
			for side in [-1,1]:
				for i in 3:
					ball(Vector3(side*.2,1.8-i*.11,.08),Vector3(.09,.11,.09),hair)

func build_headwear(cloth: String) -> void:
	match look.hoofd:
		"pet":
			ball(Vector3(0,2.08,.02),Vector3(.48,.25,.48),cloth)
			box(Vector3(0,2.06,-.27),Vector3(.32,.03,.2),shade(cloth,.25))
			ball(Vector3(0,2.2,.02),Vector3(.05,.04,.05),"f2f0e6")
		"helm":
			ball(Vector3(0,1.98,.01),Vector3(.53,.52,.53),"eef0ea")
			box(Vector3(0,2.0,-.235),Vector3(.32,.12,.04),"1f3340")
			box(Vector3(0,2.2,0),Vector3(.06,.03,.5),shade(cloth,0.0))
			for side in [-1,1]:
				ball(Vector3(side*.26,1.9,0),Vector3(.06,.14,.14),"cfd4cc")
		"koptelefoon":
			# A ring in the x-y plane, over the head from ear to ear.
			var band=piece(TorusMesh.new(),Vector3(0,1.93,0),Vector3(.5,.3,.5),"263845",Vector3(90,0,0))
			(band.mesh as TorusMesh).inner_radius=.46
			(band.mesh as TorusMesh).outer_radius=.52
			for side in [-1,1]:
				cylinder(Vector3(side*.245,1.9,0),.085,.07,"263845",Vector3(0,0,90))
			box(Vector3(-.2,1.8,-.12),Vector3(.02,.02,.2),"263845",Vector3(0,-25,0))
			ball(Vector3(-.15,1.8,-.22),Vector3(.04,.04,.04),"1b1b1b")
		"muts":
			ball(Vector3(0,2.06,.02),Vector3(.49,.36,.49),cloth)
			box(Vector3(0,1.98,.02),Vector3(.5,.06,.5),shade(cloth,-.25))
			ball(Vector3(0,2.27,.02),Vector3(.12,.12,.12),"f2f0e6")
		"hoed":
			cylinder(Vector3(0,2.07,0),.42,.03,"7a5230")
			cylinder(Vector3(0,2.18,0),.22,.2,"7a5230",Vector3.ZERO,.19)
			cylinder(Vector3(0,2.1,0),.225,.035,"3b2716")

func build_glasses() -> void:
	match look.bril:
		"rond":
			for side in [-1,1]:
				var ring=piece(TorusMesh.new(),Vector3(side*.095,1.95,-.225),Vector3(.12,.12,.12),"1b1b1b",Vector3(90,0,0))
				(ring.mesh as TorusMesh).inner_radius=.38
				(ring.mesh as TorusMesh).outer_radius=.5
			box(Vector3(0,1.95,-.225),Vector3(.06,.012,.01),"1b1b1b")
		"zonnebril":
			for side in [-1,1]:
				box(Vector3(side*.095,1.95,-.225),Vector3(.13,.075,.02),"121a22")
			box(Vector3(0,1.965,-.225),Vector3(.32,.02,.02),"121a22")
		"vliegbril":
			box(Vector3(0,1.96,-.02),Vector3(.47,.05,.44),"5a3a22")
			for side in [-1,1]:
				cylinder(Vector3(side*.1,1.96,-.225),.075,.06,"b8862f",Vector3(90,0,0))
				cylinder(Vector3(side*.1,1.96,-.258),.055,.01,"7fc4e0",Vector3(90,0,0))
