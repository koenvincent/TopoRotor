class_name PilotFigure
extends Node3D

# The player's pilot as a small procedural figure: body, skin, hair, headwear,
# glasses, facial hair and outfit. Every profile stores one look; the hangar
# and the pilot screen show it standing next to the helicopter.
#
# The figure faces -z (the helicopter's nose direction). Units: the feet stand
# on y=0 and the top of the head is at about y=2.2.

# Options are [id, name] and free, or [id, name, requirement] and earned with
# flight points or a medal, like the hangar items (see HangarCatalog.unlocked).
const BODIES = [["man","Man"],["vrouw","Vrouw"]]
const SKINS = [["f6d7c3","Licht"],["eac0a0","Lichtgetint"],["d39b72","Getint"],["b07650","Bruin"],["8a5636","Donkerbruin"],["5e3a24","Donker"],
	["8fd16a","Alien groen",{"points":900}],["7db8f0","Ruimteblauw",{"points":1700}],["b9c2cc","Robotzilver",{"medal":"europa"}]]
const HAIR = [["kort","Kort"],["stekels","Stekels"],["krullen","Krullen"],["lang","Lang"],["staart","Paardenstaart"],["knot","Knot"],["vlechten","Vlechten"],["kaal","Kaal"],
	["kuif","Kuif",{"points":70}],["bob","Bob",{"points":130}],["afro","Afro",{"points":260}],["knotjes","Twee knotjes",{"points":380}],
	["hanenkam","Hanenkam",{"points":560}],["dreads","Dreadlocks",{"points":820}],["wild","Wilde manen",{"points":1150}]]
const HAIR_COLOURS = [["2b1d14","Zwart"],["5a3a22","Donkerbruin"],["8b5a2b","Bruin"],["d8b25c","Blond"],["b5502a","Rood"],["b9b4ab","Grijs"],["3b7dd8","Blauw"],["e06aa8","Roze"],
	["f2f0ea","Wit",{"points":90}],["3fbf6a","Groen",{"points":200}],["8a4fd8","Paars",{"points":330}],["ff8a1f","Oranje",{"points":470}],["2ad1d1","Turquoise",{"points":680}],["e8c33a","Goud",{"medal":"foutloos"}]]
const HEADWEAR = [["geen","Geen"],["pet","Pet"],["helm","Vlieghelm"],["koptelefoon","Koptelefoon"],["muts","Muts"],["hoed","Cowboyhoed"],
	["baret","Baret",{"points":110}],["bandana","Bandana",{"points":240}],["propellerpet","Propellerpet",{"points":420}],["brandweer","Brandweerhelm",{"points":700}],
	["piraat","Piratenhoed",{"points":1000}],["astronaut","Ruimtehelm",{"points":2200}],["kroon","Kroon",{"medal":"huiswerk"}]]
const GLASSES = [["geen","Geen"],["rond","Ronde bril"],["zonnebril","Zonnebril"],["vliegbril","Vliegbril"],
	["sterren","Sterrenbril",{"points":170}],["hartjes","Hartjesbril",{"points":350}],["skibril","Skibril",{"points":620}],["ooglap","Ooglap",{"points":960}]]
const FACE = [["geen","Geen"],["snor","Snor"],["baard","Baard"],["sik","Sik"],["sproeten","Sproeten"],
	["blosjes","Blosjes",{"points":50}],["krulsnor","Krulsnor",{"points":300}],["schmink","Wangstrepen",{"points":520}],["kerstbaard","Witte baard",{"points":1300}]]
const OUTFITS = [["vliegpak","Vliegpak"],["jack","Bomberjack"],["hoodie","Hoodie"],["uniform","Uniform"],["reddingsvest","Reddingsvest"],
	["voetbal","Voetbalshirt",{"points":160}],["piraat","Piratenshirt",{"points":400}],["brandweer","Brandweerpak",{"points":740}],["smoking","Smoking",{"points":1100}],
	["superheld","Superheld met cape",{"points":1600}],["astronaut","Ruimtepak",{"points":2600}],["ridder","Ridderharnas",{"medal":"combi"}]]
const OUTFIT_COLOURS = [["e67b34","Oranje"],["2f6f4f","Groen"],["264a7a","Blauw"],["7a2f3b","Rood"],["3a3f47","Antraciet"],["8a6a3c","Bruin"],["c9c2b0","Zand"],["6a3f8f","Paars"],
	["f4c51c","Geel",{"points":60}],["e57fa8","Roze",{"points":120}],["2ab5b5","Turquoise",{"points":190}],["f2f2ee","Wit",{"points":280}],["17191c","Zwart",{"points":360}],
	["9bd13b","Limoen",{"points":450}],["7fc4f0","Hemelsblauw",{"points":580}],["5c1428","Bordeaux",{"points":760}],["b9c2cc","Zilver",{"points":1400}],["d4a017","Goud",{"medal":"foutloos"}]]
const EXTRAS = [["geen","Geen"],["sjaal","Sjaal",{"points":100}],["rugzak","Rugzak",{"points":230}],["landkaart","Landkaart",{"points":310}],
	["verrekijker","Verrekijker",{"points":490}],["parachute","Parachute",{"points":800}],["teddybeer","Teddybeer",{"points":1000}],
	["papegaai","Papegaai",{"points":1500}],["medaille","Vliegmedaille",{"medal":"eerste_record"}],["vlag","Vlag",{"medal":"europa"}]]
# Attribute id, Dutch label and the option list, in the order of the editor.
const ATTRIBUTES = [["figuur","Figuur",BODIES],["huid","Huidskleur",SKINS],["haar","Kapsel",HAIR],["haarkleur","Haarkleur",HAIR_COLOURS],["hoofd","Op je hoofd",HEADWEAR],["bril","Bril",GLASSES],["gezicht","Gezicht",FACE],["outfit","Outfit",OUTFITS],["kleur","Outfitkleur",OUTFIT_COLOURS],["extra","Extra",EXTRAS]]
const DEFAULT_LOOK = {"figuur":"man","huid":"f6d7c3","haar":"kort","haarkleur":"8b5a2b","hoofd":"koptelefoon","bril":"geen","gezicht":"geen","outfit":"vliegpak","kleur":"e67b34","extra":"geen"}

# The body shrinks round the feet; the head is drawn round HEAD_PIVOT,
# enlarged and set on the shortened neck at HEAD_AT (see rebuild).
const BODY_SCALE = .9
const HEAD_PIVOT = Vector3(0,1.92,0)
const HEAD_SCALE = 1.32
const HEAD_AT = Vector3(0,1.9,0)
const SATIN = .4
const GLOSSY = .95

# Headwear that hides the top of the hair.
const COVERING = ["pet","helm","muts","hoed","baret","propellerpet","brandweer","piraat"]

var look: Dictionary = DEFAULT_LOOK.duplicate()
var spinners: Array[Node3D] = []
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

static func find_option(attribute: String,id: String) -> Array:
	for option in options(attribute):
		if option[0]==id:
			return option
	return []

# The free options have no requirement and are always open.
static func option_open(option: Array,points: int,medals: Array) -> bool:
	return option.size()<3 or HangarCatalog.unlocked(option[2],points,medals)

static func open_ids(attribute: String,points: int,medals: Array) -> Array:
	var ids: Array=[]
	for option in options(attribute):
		if option_open(option,points,medals):
			ids.append(option[0])
	return ids

# What the pilot really wears: a choice still locked (an edited save, or a
# profile that lost points) falls back to the default for that attribute.
static func effective(raw: Variant,points: int,medals: Array) -> Dictionary:
	var result: Dictionary=clean(raw)
	for attribute in result:
		if not option_open(find_option(attribute,result[attribute]),points,medals):
			result[attribute]=DEFAULT_LOOK[attribute]
	return result

# Next or previous option of one attribute, wrapping round. With points
# given, locked options are skipped.
static func step(current: Dictionary,attribute: String,direction: int,points: int=-1,medals: Array=[]) -> Dictionary:
	var result: Dictionary=clean(current)
	var ids: Array=option_ids(attribute) if points<0 else open_ids(attribute,points,medals)
	var index: int=ids.find(result[attribute])
	result[attribute]=ids[0] if index<0 else ids[posmod(index+direction,ids.size())]
	return result

# How many options of every attribute are still locked, for the editor.
static func locked_count(points: int,medals: Array) -> int:
	var count=0
	for entry in ATTRIBUTES:
		for option in entry[2]:
			if not option_open(option,points,medals):
				count+=1
	return count

func _init() -> void:
	sphere=ToyLook.sphere()

func _ready() -> void:
	if not is_instance_valid(root):
		rebuild()

func configure(new_look: Dictionary) -> void:
	look=clean(new_look)
	rebuild()

# Vinyl toy paint: satin by default, glossy for the eyes and shiny gear.
func mat(hex: String,gloss: float=SATIN) -> StandardMaterial3D:
	var key="%s@%.2f" % [hex,gloss]
	if not materials.has(key):
		materials[key]=ToyLook.material(Color(hex),gloss)
	return materials[key]

# A plain box becomes a rounded block at its real size; other meshes scale.
func piece(mesh: Mesh,at: Vector3,size: Vector3,hex: String,rotation_deg: Vector3=Vector3.ZERO,gloss: float=SATIN) -> MeshInstance3D:
	var p=MeshInstance3D.new()
	if mesh is BoxMesh and (mesh as BoxMesh).size==Vector3.ONE:
		p.mesh=ToyLook.rounded_box(size,.45)
	else:
		p.mesh=mesh
		p.scale=size
	p.material_override=mat(hex,gloss)
	p.position=at
	p.rotation_degrees=rotation_deg
	root.add_child(p)
	return p

func box(at: Vector3,size: Vector3,hex: String,rotation_deg: Vector3=Vector3.ZERO,gloss: float=SATIN) -> MeshInstance3D:
	return piece(BoxMesh.new(),at,size,hex,rotation_deg,gloss)

func ball(at: Vector3,size: Vector3,hex: String,gloss: float=SATIN) -> MeshInstance3D:
	return piece(sphere,at,size,hex,Vector3.ZERO,gloss)

func cylinder(at: Vector3,radius: float,height: float,hex: String,rotation_deg: Vector3=Vector3.ZERO,top: float=-1.0) -> MeshInstance3D:
	var mesh=CylinderMesh.new()
	mesh.radial_segments=24
	mesh.rings=1
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
	spinners.clear()
	var woman: bool=look.figuur=="vrouw"
	var skin: String=look.huid
	var hair: String=look.haarkleur
	var cloth: String=look.kleur
	# Suits get trousers of their own colour; the rest wears jeans.
	var pants: String={"vliegpak":shade(cloth,.35),"uniform":shade(cloth,.35),"brandweer":shade(cloth,.2),"smoking":"17191c","astronaut":"eef0ea","ridder":"b9c2cc","superheld":shade(cloth,.25),"voetbal":"f2f2ee"}.get(look.outfit,"2f3a4a")
	if look.outfit=="astronaut":
		cloth="eef0ea"
	elif look.outfit=="ridder":
		cloth="b9c2cc"
	elif look.outfit=="smoking":
		cloth="17191c"
	var shoulder: float=.29 if woman else .34
	# Toy proportions: the body is drawn at its usual size and then shrunk
	# round the feet, the head is drawn at its usual place and enlarged
	# round its middle. Outfits, hair, hats and glasses keep fitting, and
	# the pilot gets the big friendly head of a modern toy figure.
	var figure_root=root
	var body=Node3D.new()
	body.name="Body"
	body.scale=Vector3.ONE*BODY_SCALE
	root.add_child(body)
	root=body
	# Legs and chunky sneakers with a pale sole.
	for side in [-1,1]:
		box(Vector3(side*.12,.5,0),Vector3(.2,.82,.23),pants)
		box(Vector3(side*.125,.085,-.05),Vector3(.25,.15,.38),"2a2522")
		box(Vector3(side*.125,.025,-.05),Vector3(.26,.05,.39),"f2f0ea")
	# Torso: a woman's figure is narrower at the shoulders with a wider hip.
	box(Vector3(0,1.25,0),Vector3(shoulder*2,.74,.34),cloth)
	if woman:
		box(Vector3(0,.95,0),Vector3(.56,.18,.33),cloth)
	# Arms a little away from the body, with round mitten hands.
	for side in [-1,1]:
		box(Vector3(side*(shoulder+.09),1.24,0),Vector3(.16,.66,.18),cloth,Vector3(0,0,side*9))
		ball(Vector3(side*(shoulder+.15),.87,0),Vector3(.19,.19,.19),skin)
	build_outfit(shoulder,cloth)
	cylinder(Vector3(0,1.67,0),.09,.14,skin)
	build_extra(shoulder)
	root=figure_root
	var head=Node3D.new()
	head.name="Head"
	head.position=HEAD_AT
	head.scale=Vector3.ONE*HEAD_SCALE
	root.add_child(head)
	var offset=Node3D.new()
	offset.position=-HEAD_PIVOT
	head.add_child(offset)
	root=offset
	ball(Vector3(0,1.92,0),Vector3(.44,.5,.44),skin)
	for side in [-1,1]:
		ball(Vector3(side*.22,1.9,0),Vector3(.08,.12,.08),skin)
		# Glossy button eyes with a glint, like a vinyl toy figure.
		ball(Vector3(side*.085,1.94,-.2),Vector3(.058,.078,.03),"1d1714",GLOSSY)
		ball(Vector3(side*.085+.012,1.957,-.214),Vector3(.018,.018,.008),"ffffff",GLOSSY)
		# Eyebrows in the hair colour, a soft blush on the cheeks.
		box(Vector3(side*.088,2.012,-.207),Vector3(.07,.018,.016),hair if look.haar!="kaal" else shade(skin,.45),Vector3(0,0,-side*7))
		ball(Vector3(side*.13,1.872,-.172),Vector3(.07,.04,.014),"f5a3a8")
		if woman:
			box(Vector3(side*.125,1.975,-.19),Vector3(.04,.014,.012),"1b1b1b",Vector3(0,side*-30,side*30))
	ball(Vector3(0,1.885,-.222),Vector3(.05,.048,.04),shade(skin,.06))
	# A small closed smile: a dark curve whose top is hidden by the upper lip.
	ball(Vector3(0,1.818,-.197),Vector3(.085,.04,.024),"6e2a2a")
	ball(Vector3(0,1.83,-.203),Vector3(.095,.032,.024),skin)
	build_face(skin,hair)
	build_hair(hair,look.hoofd in COVERING)
	build_headwear(look.kleur)
	build_glasses()
	root=figure_root

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
		"voetbal":
			box(Vector3(0,1.58,-.16),Vector3(.2,.06,.02),"f2f2ee")
			for side in [-1,1]:
				box(Vector3(side*(shoulder+.08),1.45,0),Vector3(.165,.12,.185),"f2f2ee",Vector3(0,0,side*6))
			# Label3D faces +z: the back as is, the chest turned round.
			number("10",Vector3(0,1.27,.165),0.0,"f2f2ee")
			number("10",Vector3(.13,1.42,-.165),PI,"f2f2ee",.0018)
		"piraat":
			for i in 4:
				box(Vector3(0,.98+i*.17,0),Vector3(shoulder*2+.01,.06,.325),"f2f0e6")
			for side in [-1,1]:
				box(Vector3(side*(shoulder-.08),1.25,-.005),Vector3(.18,.72,.33),"2a2522")
			box(Vector3(0,.93,0),Vector3(shoulder*2+.02,.09,.335),"c8211d")
		"brandweer":
			for y in [1.05,1.38]:
				box(Vector3(0,y,0),Vector3(shoulder*2+.01,.07,.33),"e8e26a")
				box(Vector3(0,y,0),Vector3(shoulder*2+.02,.025,.335),"d9dde0")
			for side in [-1,1]:
				box(Vector3(side*(shoulder+.09),1.05,0),Vector3(.16,.06,.18),"e8e26a",Vector3(0,0,side*6))
				box(Vector3(side*.12,.3,0),Vector3(.2,.06,.23),"e8e26a")
		"smoking":
			box(Vector3(0,1.4,-.163),Vector3(.18,.4,.01),"f4f4f0")
			box(Vector3(0,1.57,-.175),Vector3(.16,.06,.02),look.kleur)
			ball(Vector3(0,1.57,-.18),Vector3(.05,.05,.03),shade(look.kleur,.2))
			for i in 2:
				ball(Vector3(0,1.38-i*.1,-.172),Vector3(.025,.025,.01),"17191c")
		"superheld":
			box(Vector3(0,.95,0),Vector3(shoulder*2+.02,.08,.335),"e8c33a")
			var emblem=box(Vector3(0,1.38,-.166),Vector3(.16,.16,.01),"e8c33a",Vector3(0,0,45))
			emblem.name="Emblem"
			# The cape hangs from the shoulders down the back.
			var cape=box(Vector3(0,1.08,.22),Vector3(shoulder*2+.12,1.05,.03),"c8211d" if Color(look.kleur).r<.6 else "264a7a",Vector3(8,0,0))
			cape.name="Cape"
		"astronaut":
			box(Vector3(0,1.25,.26),Vector3(.5,.62,.22),"cfd4d8")
			box(Vector3(0,1.32,-.168),Vector3(.24,.16,.02),"3a3f47")
			for i in 3:
				ball(Vector3(-.07+i*.07,1.32,-.18),Vector3(.035,.035,.02),["e8453a","f4c51c","3fbf6a"][i])
			box(Vector3(-.17,1.5,-.166),Vector3(.1,.07,.01),look.kleur)
			for side in [-1,1]:
				box(Vector3(side*.12,.12,0),Vector3(.24,.08,.26),"cfd4d8")
		"ridder":
			box(Vector3(0,1.2,-.166),Vector3(.3,.6,.01),look.kleur)
			# A gold shield on the tabard.
			box(Vector3(0,1.3,-.172),Vector3(.16,.14,.01),"e8c33a")
			box(Vector3(0,1.22,-.172),Vector3(.113,.113,.01),"e8c33a",Vector3(0,0,45))
			for side in [-1,1]:
				ball(Vector3(side*(shoulder+.03),1.56,0),Vector3(.24,.16,.26),shade(cloth,.1))

# A number on a shirt, as flat text that faces outwards.
func number(text: String,at: Vector3,turn: float,hex: String,size: float=.004) -> void:
	var l=Label3D.new()
	l.text=text
	l.pixel_size=size
	l.font_size=64
	l.outline_size=0
	l.modulate=Color(hex)
	l.position=at
	l.rotation.y=turn
	l.double_sided=false
	root.add_child(l)

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
		"blosjes":
			for side in [-1,1]:
				ball(Vector3(side*.13,1.87,-.19),Vector3(.08,.05,.03),"f08a9a")
		"krulsnor":
			box(Vector3(0,1.835,-.215),Vector3(.16,.04,.04),hair)
			for side in [-1,1]:
				ball(Vector3(side*.1,1.85,-.21),Vector3(.06,.06,.04),hair)
				ball(Vector3(side*.12,1.88,-.205),Vector3(.035,.035,.03),hair)
		"schmink":
			for side in [-1,1]:
				for i in 2:
					box(Vector3(side*.13,1.89-i*.045,-.19),Vector3(.09,.02,.02),look.kleur if i==0 else "f2f2ee",Vector3(0,side*-30,0))
		"kerstbaard":
			ball(Vector3(0,1.72,-.09),Vector3(.44,.42,.36),"f4f4f0")
			ball(Vector3(0,1.6,-.1),Vector3(.26,.24,.22),"f4f4f0")
			box(Vector3(0,1.835,-.22),Vector3(.22,.055,.05),"f4f4f0")
			box(Vector3(0,1.8,-.25),Vector3(.1,.025,.02),"9c4a4a")

# Under a cap, helmet, beanie or hat only the hair that sticks out is drawn.
func build_hair(hair: String,covered: bool) -> void:
	if look.haar=="kaal":
		return
	# A mohawk has shaved sides: no cap of hair, only the crest.
	if not covered and look.haar!="hanenkam":
		ball(Vector3(0,2.04,.03),Vector3(.47,.3,.47),hair)
	match look.haar:
		"kuif":
			if not covered:
				ball(Vector3(0,2.17,-.1),Vector3(.32,.2,.26),hair)
		"bob":
			# Back and sides down to the chin; the face stays free.
			box(Vector3(0,1.9,.13),Vector3(.5,.34,.26),hair)
			for side in [-1,1]:
				box(Vector3(side*.225,1.88,-.03),Vector3(.07,.3,.3),hair)
			if not covered:
				box(Vector3(0,2.06,-.19),Vector3(.4,.08,.07),hair)
		"afro":
			if not covered:
				ball(Vector3(0,2.08,.1),Vector3(.68,.55,.56),hair)
			else:
				for i in 7:
					var a=PI*.15+PI*.7*i/6.0
					ball(Vector3(cos(a)*.24,1.92,sin(a)*.22),Vector3(.2,.2,.2),hair)
		"knotjes":
			if not covered:
				for side in [-1,1]:
					ball(Vector3(side*.16,2.2,.03),Vector3(.18,.17,.18),hair)
		"hanenkam":
			if not covered:
				for i in 5:
					cylinder(Vector3(0,2.2,-.14+i*.08),.035,.2+.04*(2-absf(i-2)),hair,Vector3(-12+i*6,0,0),0.0)
				box(Vector3(0,2.12,.0),Vector3(.06,.1,.4),hair)
		"dreads":
			for i in 9:
				var a=PI*.05+PI*.9*i/8.0
				cylinder(Vector3(cos(a)*.2,1.78,sin(a)*.17+.03),.035,.42,hair,Vector3(sin(a)*-10,0,cos(a)*12))
		"wild":
			for i in 9:
				var a=TAU*i/9.0
				ball(Vector3(cos(a)*.22,2.02+sin(a*3.0)*.05,sin(a)*.2+.06),Vector3(.2,.18,.2),hair)
			box(Vector3(0,1.78,.17),Vector3(.5,.46,.12),hair)
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
		"baret":
			var beret=ball(Vector3(.05,2.12,.03),Vector3(.54,.16,.52),shade(cloth,.2))
			beret.rotation_degrees.z=-10
			cylinder(Vector3(.05,2.21,.03),.02,.05,shade(cloth,.35))
		"bandana":
			cylinder(Vector3(0,2.03,0),.237,.09,"c8211d")
			for i in 2:
				box(Vector3(-.05+i*.1,1.98,.25),Vector3(.06,.14,.03),"c8211d",Vector3(0,0,-25+i*50))
			for at in [Vector3(-.1,2.04,-.232),Vector3(.08,2.02,-.232)]:
				ball(at,Vector3(.03,.03,.01),"f2f0e6")
		"propellerpet":
			ball(Vector3(0,2.08,.02),Vector3(.48,.25,.48),cloth)
			box(Vector3(0,2.06,-.27),Vector3(.32,.03,.2),shade(cloth,.25))
			cylinder(Vector3(0,2.24,.02),.015,.1,"3a3f47")
			var prop=Node3D.new()
			prop.position=Vector3(0,2.29,.02)
			prop.name="Propeller"
			root.add_child(prop)
			var keep=root
			root=prop
			box(Vector3.ZERO,Vector3(.36,.012,.06),"e8453a")
			box(Vector3.ZERO,Vector3(.06,.014,.36),"3b7dd8")
			ball(Vector3.ZERO,Vector3(.04,.03,.04),"f4c51c")
			root=keep
			spinners.append(prop)
		"brandweer":
			ball(Vector3(0,2.03,.02),Vector3(.52,.4,.52),"c8211d")
			cylinder(Vector3(0,1.97,.05),.31,.03,"c8211d")
			box(Vector3(0,2.24,.02),Vector3(.05,.06,.42),shade("c8211d",.2))
			box(Vector3(0,2.08,-.255),Vector3(.1,.1,.02),"e8c33a")
		"piraat":
			cylinder(Vector3(0,2.1,0),.33,.04,"1b1b1b")
			cylinder(Vector3(0,2.2,0),.21,.18,"1b1b1b",Vector3.ZERO,.17)
			for side in [-1,1]:
				box(Vector3(side*.2,2.18,-.12),Vector3(.2,.16,.02),"1b1b1b",Vector3(0,side*35,0))
			ball(Vector3(0,2.2,-.215),Vector3(.06,.06,.02),"f2f0e6")
		"astronaut":
			# A see-through bubble over the head and a collar ring.
			var bubble=MeshInstance3D.new()
			bubble.mesh=sphere
			var glass=StandardMaterial3D.new()
			glass.albedo_color=Color(.75,.9,1.0,.22)
			glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
			glass.roughness=.1
			glass.metallic_specular=.9
			bubble.material_override=glass
			bubble.position=Vector3(0,1.95,0)
			bubble.scale=Vector3(.7,.7,.7)
			bubble.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(bubble)
			cylinder(Vector3(0,1.64,0),.25,.08,"cfd4d8")
		"kroon":
			cylinder(Vector3(0,2.2,0),.17,.1,"e8c33a",Vector3.ZERO,.19)
			for i in 6:
				var a=TAU*i/6.0
				cylinder(Vector3(cos(a)*.17,2.3,sin(a)*.17),.035,.1,"e8c33a",Vector3.ZERO,0.0)
			for i in 3:
				ball(Vector3(-.08+i*.08,2.2,-.18+absf(i-1)*.02),Vector3(.04,.04,.02),["e8453a","3b7dd8","3fbf6a"][i])

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
		"sterren":
			for side in [-1,1]:
				for turn in [0,45]:
					box(Vector3(side*.1,1.95,-.228),Vector3(.11,.11,.015),"f4c51c",Vector3(0,0,turn))
			box(Vector3(0,1.955,-.228),Vector3(.32,.02,.02),"f4c51c")
		"hartjes":
			for side in [-1,1]:
				for dx in [-.025,.025]:
					ball(Vector3(side*.1+dx,1.965,-.228),Vector3(.06,.06,.02),"e8457a")
				box(Vector3(side*.1,1.94,-.228),Vector3(.065,.065,.018),"e8457a",Vector3(0,0,45))
			box(Vector3(0,1.96,-.228),Vector3(.32,.018,.02),"e8457a")
		"skibril":
			box(Vector3(0,1.96,-.02),Vector3(.48,.07,.44),"1b1b1b")
			box(Vector3(0,1.96,-.235),Vector3(.32,.1,.03),"3a3f47")
			box(Vector3(0,1.96,-.25),Vector3(.28,.075,.01),"ff9a3c")
		"ooglap":
			ball(Vector3(.095,1.95,-.215),Vector3(.1,.09,.03),"1b1b1b")
			box(Vector3(0,2.0,-.13),Vector3(.5,.02,.22),"1b1b1b",Vector3(0,0,-18))

# Something the pilot carries: on the back, round the neck, on the chest, in
# one of the hands (at +x and -x) or on the shoulder.
func build_extra(shoulder: float) -> void:
	var hand=Vector3(shoulder+.11,.86,0)
	match look.extra:
		"sjaal":
			var scarf=piece(TorusMesh.new(),Vector3(0,1.62,0),Vector3(.3,.3,.3),"d23b3b")
			(scarf.mesh as TorusMesh).inner_radius=.5
			(scarf.mesh as TorusMesh).outer_radius=.75
			box(Vector3(.1,1.45,-.17),Vector3(.09,.3,.03),"d23b3b",Vector3(0,0,8))
			box(Vector3(.1,1.36,-.172),Vector3(.092,.04,.03),"f2f0e6",Vector3(0,0,8))
		"rugzak":
			box(Vector3(0,1.22,.25),Vector3(.44,.5,.2),"4f7a3a")
			box(Vector3(0,1.08,.36),Vector3(.32,.18,.06),shade("4f7a3a",.2))
			for side in [-1,1]:
				box(Vector3(side*.15,1.3,-.165),Vector3(.05,.5,.01),"2d3a2a")
		"landkaart":
			box(hand+Vector3(.02,.08,-.16),Vector3(.02,.3,.4),"f4efe0")
			box(hand+Vector3(.033,.12,-.2),Vector3(.005,.14,.16),"8fc26a")
			box(hand+Vector3(.033,.02,-.08),Vector3(.005,.08,.12),"5aa6d8")
		"verrekijker":
			for side in [-1,1]:
				cylinder(Vector3(side*.055,1.28,-.2),.045,.14,"2a2522",Vector3(90,0,0))
			box(Vector3(0,1.47,-.17),Vector3(.24,.02,.01),"5a3a22",Vector3(0,0,0))
		"parachute":
			box(Vector3(0,1.2,.26),Vector3(.5,.62,.22),"556b3a")
			box(Vector3(0,1.42,.375),Vector3(.38,.14,.02),"3e4f2c")
			ball(Vector3(-.12,1.2,-.18),Vector3(.07,.07,.04),"e8453a")
			for side in [-1,1]:
				box(Vector3(side*.13,1.25,-.165),Vector3(.06,.6,.01),"2d3a2a")
			box(Vector3(0,1.0,-.165),Vector3(shoulder*2,.05,.01),"2d3a2a")
		"teddybeer":
			var at=Vector3(-hand.x,hand.y+.08,-.12)
			ball(at,Vector3(.16,.18,.12),"9a6a3c")
			ball(at+Vector3(0,.15,0),Vector3(.13,.12,.11),"9a6a3c")
			for side in [-1,1]:
				ball(at+Vector3(side*.05,.22,0),Vector3(.05,.05,.03),"9a6a3c")
			ball(at+Vector3(0,.14,-.055),Vector3(.04,.03,.02),"2a2522")
		"papegaai":
			var at=Vector3(-shoulder-.04,1.68,.04)
			ball(at,Vector3(.13,.2,.13),"3fbf6a")
			ball(at+Vector3(0,.14,-.02),Vector3(.1,.1,.1),"e8453a")
			ball(at+Vector3(0,.14,-.07),Vector3(.04,.04,.05),"f4c51c")
			box(at+Vector3(0,-.08,.1),Vector3(.05,.04,.2),"3b7dd8",Vector3(-35,0,0))
			for side in [-1,1]:
				ball(at+Vector3(side*.065,.0,0),Vector3(.04,.14,.1),"2f9e4f")
		"medaille":
			box(Vector3(-.12,1.42,-.168),Vector3(.07,.14,.01),"2f6fd1")
			cylinder(Vector3(-.12,1.32,-.175),.05,.015,"e8c33a",Vector3(90,0,0))
		"vlag":
			cylinder(hand+Vector3(0,.25,0),.015,.75,"7a5230")
			# The flag flies outwards, so it shows from the front.
			for i in 3:
				box(hand+Vector3(.17,.55-i*.07,0),Vector3(.3,.07,.01),["ae1c28","f4f4f0","21468b"][i])

func _process(delta: float) -> void:
	for s in spinners:
		s.rotation.y+=delta*9.0
