class_name EuropeScenery
extends DutchScenery

# Exaggerated, deterministic miniatures. Geographic anchors use the catalogue;
# regional scenery is decorative, not an elevation or land-use dataset.
# Landmarks come from data/landmarks_eu.json: Europe-only silhouettes are built
# here, and the shared Dutch kit types are reused at Europe's larger scale.
const KIT_SCALE = 1.8
const EU_FOOTPRINTS = {
	"eiffel":3.0,"big_ben":3.2,"brandenburg":4.2,"colosseum":4.2,"parthenon":3.6,"onion_domes":3.0,
	"nordic_hall":3.4,"fortress":3.6,"atomium":2.8,"triumph_arch":2.8,"tower_bridge":4.6,
	"ferris_wheel":3.4,"suspension_bridge":5.6,"stone_bridge":4.4,"basilica_dome":2.8,"red_dome":3.0,
	"mosque":3.4,"kremlin":4.4,"opera":3.8,"hallgrims":2.8,"sagrada":3.0,"duomo":3.6,"twin_domes":2.8,
	"elbphilharmonie":3.4,"cathedral_twin":3.2,"spire_tower":2.4,"crystal":2.4,"temple_front":3.0,
	"volcano":4.8,"castle_hill":3.6,"canal_houses":3.8,"parliament":4.8,
}
const SEA_LANES = [[3.0,55.5],[4.5,58.0],[-1.0,50.0],[-6.5,47.0],[-12.0,45.0],[-10.0,40.0],[5.0,38.0],[12.0,37.5],
	[18.0,35.0],[24.5,37.0],[15.5,43.0],[30.0,43.0],[35.0,44.0],[18.5,56.5],[20.0,58.5],[22.0,63.0],[3.0,64.0],
	[-5.5,53.8],[-15.0,52.0],[8.5,40.0],[27.5,34.5],[0.0,57.0]]
const LIGHTHOUSE_POINTS = [[-9.3,43.0],[-5.0,48.4],[-5.7,50.06],[10.6,57.74],[-5.6,36.0],[-9.5,38.7],[15.65,38.25],
	[3.2,51.35],[-4.5,58.6],[23.9,59.85],[13.4,54.68],[28.95,41.2],[-8.0,55.2],[5.5,62.0]]
const WIND_FARMS = [[3.6,53.5],[6.4,54.2],[2.4,51.7],[1.8,53.9],[11.8,54.9]]
const BELTS = [
	# [lon0, lat0, lon1, lat1, peaks]
	[-5.0,43.0,3.0,42.6,14],[6.0,45.5,15.0,47.0,26],[5.0,58.0,19.0,68.0,24],[18.0,49.0,26.0,46.0,16],
	[17.0,43.5,24.0,39.5,12],[9.5,44.2,16.0,40.4,12],[14.5,45.6,20.0,42.0,12],[38.5,44.0,45.0,41.8,16],
	[-6.2,56.4,-3.4,58.2,7],[22.5,43.0,27.0,42.7,8],[2.2,45.8,3.6,44.6,5],[-4.2,37.2,-2.8,37.0,5],
]

var city_styles: Dictionary = {}
var terrain_patches: int = 0
var peak_count: int = 0
var ships_built: int = 0
var lighthouses_built: int = 0
var turbines_built: int = 0
var taiga_trees: int = 0
var grove_rows: int = 0
var landmark_names: Dictionary = {}
# Every city anchor on the map. Neighbouring capitals (Wenen and Bratislava,
# Tallinn and Helsinki) split the ground between them instead of overlapping.
var city_anchors: Array = []
var flipped_landmarks: int = 0
var ball = SphereMesh.new()
var half_ball = SphereMesh.new()
var taper = CylinderMesh.new()
var drum = CylinderMesh.new()
# Kit landmarks are modelled for the Dutch map; scale them about their own base.
var k_scale: float = 1.0
var k_pivot: Vector3 = Vector3.ZERO

func _init(parent: Node3D) -> void:
	super(parent)
	landmark_data=landmark_cities(JSON.parse_string(FileAccess.get_file_as_string("res://data/landmarks_eu.json")),"landmarks_eu.json")
	ball.radius=.5
	ball.height=1
	ball.radial_segments=12
	ball.rings=6
	half_ball.radius=.5
	half_ball.height=.5
	half_ball.is_hemisphere=true
	half_ball.radial_segments=14
	half_ball.rings=4
	taper.top_radius=.12
	taper.bottom_radius=.5
	taper.height=1
	taper.radial_segments=8
	drum.top_radius=.5
	drum.bottom_radius=.5
	drum.height=1
	drum.radial_segments=12
	# Smoother Blender column and orb, same unit size.
	var pieces: Dictionary=DutchScenery.scenery_kit()
	if pieces.has("Column"):
		drum=pieces.Column
	if pieces.has("Orb"):
		ball=pieces.Orb

static func known(type: String) -> bool:
	return EU_FOOTPRINTS.has(type) or LandmarkKit.FOOTPRINTS.has(type)

static func footprint(entry: Dictionary) -> float:
	var type: String=entry.get("type","")
	if EU_FOOTPRINTS.has(type):
		return EU_FOOTPRINTS[type]
	return LandmarkKit.footprint(entry)*KIT_SCALE

func xf(p: Vector3) -> Vector3:
	return k_pivot+(p-k_pivot)*k_scale

func piece(mesh: Mesh, pos: Vector3, dimensions: Vector3, color: String, angle: float=0) -> void:
	super.piece(mesh,xf(pos),dimensions*k_scale,color,angle)

func beam(a: Vector3,b: Vector3,width: float,color: String) -> void:
	super.beam(xf(a),xf(b),width*k_scale,color)

func put_mesh(mesh: Mesh,origin: Vector3,basis: Basis,color: String) -> void:
	super.put_mesh(mesh,xf(origin),basis.scaled(Vector3.ONE*k_scale),color)

# Relief without the Dutch shoreline check; the caller already stands on land.
func mound(center: Vector3,radius: Vector2,height: float,color: String) -> void:
	var st: SurfaceTool=surface(color)
	for i in 9:
		var a=TAU*float(i)/9
		var b=TAU*float(i+1)/9
		var p=xf(center+Vector3(cos(a)*radius.x,.04,sin(a)*radius.y))
		var q=xf(center+Vector3(cos(b)*radius.x,.04,sin(b)*radius.y))
		var top=xf(center+Vector3(radius.x*.12,height,-radius.y*.08))
		var normal=(q-p).cross(top-p).normalized()
		var vertices=[p,q,top]
		if normal.y<0:
			normal=-normal
			vertices=[p,top,q]
		for vertex in vertices:
			st.set_normal(normal)
			st.add_vertex(vertex)

func town(pos: Vector3,place_name: String) -> void:
	var geo=world.unproject(pos)
	var north=geo.y>55
	var south=geo.y<44
	rng.seed=hash(place_name)
	var walls=["e3c891","d4a46e","eadbb3","bb7656","f0e2c4"] if south else ["ccd2c5","bd9b7a","dbcfb0","9baead","e3d6bd"]
	var roofs=["ae593e","cb8050","8a5143"] if south else ["3e5662","596975","934c41"]
	if north:
		walls=["b2523f","d9b45a","e7e2d2","4f6e7c","c98a4a"]
	city_styles[place_name]="mediterranean" if south else "nordic" if north else "continental"
	var entries: Array=[]
	for entry in landmark_data.get(place_name,[]):
		var placed: Dictionary=entry.duplicate()
		var offset=Vector2(entry.at[0],entry.at[1])
		if not own_ground(pos,offset) and own_ground(pos,-offset):
			placed.at=[-offset.x,-offset.y]
			flipped_landmarks+=1
		entries.append(placed)
	var clear: Array=[[Vector2.ZERO,2.6]]
	for entry in entries:
		clear.append([Vector2(entry.at[0],entry.at[1]),footprint(entry)])
	# Paved old town, a ring boulevard and two avenues; the centre keeps the helipad.
	# Coastal capitals (Valletta, Monaco, Lissabon) get a smaller square.
	var full=true
	for corner in [Vector3(-8.5,0,-7.5),Vector3(8.5,0,-7.5),Vector3(8.5,0,7.5),Vector3(-8.5,0,7.5)]:
		full=full and land_at(pos+corner) and own_ground(pos,Vector2(corner.x,corner.z))
	var half=Vector2(8.5,7.5) if full else Vector2(4.6,4.0)
	block(pos+Vector3(0,.045,0),Vector3(half.x*2,.04,half.y*2),"9d9883" if not south else "b2a47f")
	block(pos+Vector3(0,.06,0),Vector3(half.x*2,.06,.7),"7d7a6c")
	block(pos+Vector3(0,.07,0),Vector3(.7,.06,half.y*2),"7d7a6c")
	if full:
		for side in [[0,-7.2,17,.5],[0,7.2,17,.5],[-8.2,0,.5,15],[8.2,0,.5,15]]:
			block(pos+Vector3(side[0],.065,side[1]),Vector3(side[2],.05,side[3]),"85816f")
	var houses=0
	for i in 48:
		var x=(float(i%8)-3.5)*1.95+rng.randf_range(-.2,.2)
		var z=(float(i/8)-2.5)*2.35+rng.randf_range(-.2,.2)
		if covers(clear,Vector2(x,z),.9) or abs(x)<.8 or abs(z)<.8:
			continue
		if not own_ground(pos,Vector2(x,z)) or not land_at(pos+Vector3(x,0,z)):
			continue
		var height=rng.randf_range(.9,2.2) if south else rng.randf_range(1.2,3.2)
		if Vector2(x,z).length()>6.5:
			height*=.75
		house(pos+Vector3(x,0,z),Vector3(1.25,height,1.5),walls[i%walls.size()],roofs[i%roofs.size()],0,2 if south and i%3==0 else -1)
		houses+=1
	# Boulevard trees and a small park with a fountain.
	for i in 9:
		var at=Vector2(-7.6+i*1.9,-6.6)
		if full and own_ground(pos,at):
			tree(pos+Vector3(at.x,0,at.y),.55 if south else .75)
	var park=pos+Vector3(-6.0,0,5.2)
	if full and own_ground(pos,Vector2(-6.0,5.2)) and not covers(clear,Vector2(-6.0,5.2),.5):
		block(park+Vector3(0,.07,0),Vector3(3.6,.05,2.6),"7fa56a")
		piece(drum,park+Vector3(0,.15,0),Vector3(1.1,.12,1.1),"5aa7c0")
		for i in 5:
			tree(park+Vector3(cos(i*1.3)*1.4,0,sin(i*1.3)*.95),.6)
	var built=0
	var names: Array=[]
	for entry in entries:
		if build_landmark(pos+Vector3(entry.at[0],0,entry.at[1]),entry):
			names.append(entry.get("name",""))
			built+=1
	if entries.is_empty():
		palace(pos+Vector3(6,0,-6))
	landmark_built[place_name]=built
	landmark_names[place_name]=names
	landmarks[place_name]=true
	city_stats[place_name]={"plots":houses,"layout":hash(place_name),"kind":city_styles[place_name]}

# True when offset (from this city's anchor) lies closer to this city than to any other.
func own_ground(anchor: Vector3,offset: Vector2) -> bool:
	var at=Vector2(anchor.x+offset.x,anchor.z+offset.y)
	var own=offset.length()
	for other in city_anchors:
		if other.distance_to(at)+.01<own:
			return false
	return true

# False when the type is unknown and nothing was drawn.
func build_landmark(p: Vector3,entry: Dictionary) -> bool:
	var type: String=entry.get("type","")
	match type:
		"eiffel": eiffel(p)
		"big_ben": clock_tower(p)
		"brandenburg": brandenburg(p)
		"colosseum": arena(p)
		"parthenon": temple(p)
		"onion_domes": domes(p)
		"nordic_hall": nordic_hall(p)
		"fortress": fortress(p)
		"atomium": atomium(p)
		"triumph_arch": triumph_arch(p)
		"tower_bridge": tower_bridge(p)
		"ferris_wheel": ferris_wheel(p)
		"suspension_bridge": suspension_bridge(p)
		"stone_bridge": stone_bridge(p)
		"basilica_dome": basilica_dome(p,"e6dfcc","7f9c96")
		"red_dome": red_dome(p)
		"mosque": mosque(p,int(entry.get("minarets",4)))
		"kremlin": kremlin(p)
		"opera": opera(p)
		"hallgrims": hallgrims(p)
		"sagrada": sagrada(p)
		"duomo": duomo(p)
		"twin_domes": twin_domes(p)
		"elbphilharmonie": elbphilharmonie(p)
		"cathedral_twin": cathedral_twin(p)
		"spire_tower": spire_tower(p)
		"crystal": crystal(p)
		"temple_front": temple_front(p)
		"volcano": volcano(p,entry.get("snow",false))
		"castle_hill": castle_hill(p)
		"canal_houses": canal_houses(p)
		"parliament": parliament(p)
		_:
			return at_kit_scale(p,func(): return kit.build(p,entry))
	return true

# Runs a kit call at Europe scale about p and always restores the scale after it.
func at_kit_scale(p: Vector3,build: Callable) -> Variant:
	k_pivot=p
	k_scale=KIT_SCALE
	var result: Variant=build.call()
	k_scale=1.0
	return result

# --- Europe-only silhouettes, modelled at Europe scale --------------------

func eiffel(p: Vector3) -> void:
	for x in [-1,1]:
		for z in [-1,1]:
			beam(p+Vector3(x*2.0,0,z*2.0),p+Vector3(x*.55,5,z*.55),.3,"635c4e")
			beam(p+Vector3(x*.55,5,z*.55),p+Vector3(0,10,0),.2,"635c4e")
	block(p+Vector3(0,3,0),Vector3(3.1,.35,3.1),"b29869")
	block(p+Vector3(0,5.2,0),Vector3(1.8,.25,1.8),"b29869")
	beam(p+Vector3(0,9,0),p+Vector3(0,11,0),.13,"e5d0a0")

func clock_tower(p: Vector3) -> void:
	block(p+Vector3(2,1.3,0),Vector3(5,2.6,2.2),"bda77e")
	tower(p,"c7ad79",7.0)
	block(p+Vector3(0,4.7,.7),Vector3(.65,.65,.08),"f8edc6")
	block(p+Vector3(0,4.75,.76),Vector3(.07,.38,.04),"30424c")
	block(p+Vector3(.13,4.6,.76),Vector3(.3,.07,.04),"30424c")

func brandenburg(p: Vector3) -> void:
	for i in 6:
		piece(trunk,p+Vector3(-3+i*1.2,1.5,0),Vector3(2.5,3,2.5),"d4c8aa")
	block(p+Vector3(0,3.2,0),Vector3(7.6,.6,2.1),"d4c8aa")
	block(p+Vector3(0,3.7,0),Vector3(2.2,.5,1.0),"557b72")

func arena(p: Vector3) -> void:
	for i in 24:
		var angle=i*TAU/24
		var at=p+Vector3(cos(angle)*3.6,0,sin(angle)*2.6)
		block(at+Vector3(0,1.4,0),Vector3(.5,2.8,.7),"c9ac85",-angle)
		block(at+Vector3(0,2.9,0),Vector3(1.0,.35,.8),"e5c899",-angle)
		block(at+Vector3(0,1.5,0),Vector3(1.0,.25,.8),"e5c899",-angle)

func temple(p: Vector3) -> void:
	piece(drum,p+Vector3(0,.6,0),Vector3(8,1.2,6.5),"a99a78")
	block(p+Vector3(0,1.4,0),Vector3(6,.4,4.5),"e3cf9e")
	for x in [-2,-1,0,1,2]:
		for z in [-1.5,1.5]:
			piece(trunk,p+Vector3(x,3.0,z),Vector3(2.2,3,2.2),"f0dfb8")
	piece(roof,p+Vector3(0,5.0,0),Vector3(6,1.1,4.5),"d5bc8b")

func domes(p: Vector3) -> void:
	block(p+Vector3(0,1.3,0),Vector3(4,2.6,3),"ddd3ba")
	var tops=["d9ad50","3f8f8a","c4473a"]
	for i in 3:
		var at=p+Vector3((i-1)*1.6,3.3,0)
		piece(trunk,at,Vector3(4,2,4),"d9b464")
		piece(ball,at+Vector3(0,1.3,0),Vector3(1.5,1.8,1.5),tops[(i+int(p.x))%3] if i!=1 else "d9ad50")
		piece(cone,at+Vector3(0,2.5,0),Vector3(.25,.9,.25),"d9ad50")

func nordic_hall(p: Vector3) -> void:
	house(p,Vector3(5,2.5,3),"a1513e","3e5662")
	tower(p+Vector3(-2,0,0),"c6c9bf",6)
	piece(ball,p+Vector3(-2,6.9,0),Vector3(.5,.5,.5),"e3b94a")
	for i in 5:
		block(p+Vector3(i-2,1.5,1.53),Vector3(.35,.7,.04),"f5da8a")

func fortress(p: Vector3) -> void:
	mound(p,Vector2(4.2,3.2),1.0,"8a9a6a")
	block(p+Vector3(0,2.0,0),Vector3(6,2.4,3.5),"d4ae7a")
	for i in 7:
		block(p+Vector3(-2.7+i*.9,3.35,1.75),Vector3(.45,.35,.2),"d4ae7a")
	for x in [-2.6,2.6]:
		for z in [-1.4,1.4]:
			tower(p+Vector3(x,.8,z),"c79c68",4)

func atomium(p: Vector3) -> void:
	# Nine steel spheres on a cube balanced on one corner, with three legs.
	var c=p+Vector3(0,5.2,0)
	var basis=Basis(Vector3(0,0,1),deg_to_rad(45))*Basis(Vector3(1,0,0),deg_to_rad(35.26))
	var corners: Array=[]
	for x in [-1,1]:
		for y in [-1,1]:
			for z in [-1,1]:
				corners.append(c+basis*Vector3(x,y,z)*1.7)
	for i in corners.size():
		beam(c,corners[i],.22,"c9d2d6")
		for j in range(i+1,corners.size()):
			if corners[i].distance_to(corners[j])<3.5:
				beam(corners[i],corners[j],.2,"c9d2d6")
	for corner in corners+[c]:
		piece(ball,corner,Vector3.ONE*1.25,"dfe6ea")
	var lowest: Vector3=corners[0]
	for corner in corners:
		if corner.y<lowest.y:
			lowest=corner
	for i in 3:
		var a=TAU*i/3
		beam(lowest,p+Vector3(cos(a)*2.4,0,sin(a)*2.4),.25,"aeb7bb")

func triumph_arch(p: Vector3) -> void:
	for x in [-1.7,1.7]:
		block(p+Vector3(x,2.3,0),Vector3(1.5,4.6,2.2),"e2d6b6")
	block(p+Vector3(0,5.3,0),Vector3(4.9,1.4,2.2),"e2d6b6")
	block(p+Vector3(0,6.2,0),Vector3(5.1,.4,2.4),"cbbd97")
	block(p+Vector3(0,4.4,0),Vector3(1.9,.4,2.2),"d4c7a3")
	for z in [-1.12,1.12]:
		block(p+Vector3(0,5.3,z),Vector3(3.6,.5,.04),"b5a57d")

func water_strip(p: Vector3,length: float,width: float,along_x: bool=true) -> void:
	block(p+Vector3(0,.1,0),Vector3(length,.08,width) if along_x else Vector3(width,.08,length),"3d8fa8")

func tower_bridge(p: Vector3) -> void:
	water_strip(p,4.0,9.5,false)
	block(p+Vector3(0,1.0,0),Vector3(1.4,.3,9.5),"6f8f9a")
	for z in [-1.9,1.9]:
		block(p+Vector3(0,2.6,z),Vector3(1.8,5.2,1.6),"c9b592")
		for x in [-.7,.7]:
			for dz in [-.6,.6]:
				piece(cone,p+Vector3(x,5.8,z+dz),Vector3(.35,1.0,.35),"52646a")
		piece(cone,p+Vector3(0,6.0,z),Vector3(.8,1.6,.8),"52646a")
	for x in [-.6,.6]:
		beam(p+Vector3(x,4.6,-1.9),p+Vector3(x,4.6,1.9),.25,"5a8fb0")
		for side in [-1,1]:
			beam(p+Vector3(x,4.4,side*1.9),p+Vector3(x,1.2,side*4.6),.15,"5a8fb0")

func ferris_wheel(p: Vector3) -> void:
	var hub=p+Vector3(0,4.4,0)
	var radius=3.7
	var previous=hub+Vector3(radius,0,0)
	for i in 21:
		var a=TAU*float(i)/20
		var at=hub+Vector3(cos(a)*radius,sin(a)*radius,0)
		if i>0:
			beam(previous,at,.14,"eef1f2")
		if i<20:
			beam(hub,at,.05,"cfd6d9")
			if i%2==0:
				block(at+Vector3(0,-.3,0),Vector3(.45,.45,.45),"e05a47" if i%4==0 else "f3c44f")
		previous=at
	for x in [-1,1]:
		for z in [-.9,.9]:
			beam(p+Vector3(x*2.2,0,z),hub,.2,"aab3b6")
	piece(drum,hub,Vector3(.6,.6,.6),"8b979b")

func suspension_bridge(p: Vector3) -> void:
	water_strip(p,12.0,3.4)
	block(p+Vector3(0,1.4,0),Vector3(12.0,.25,1.2),"8a8f8c")
	for x in [-3.4,3.4]:
		for z in [-.55,.55]:
			block(p+Vector3(x,2.6,z),Vector3(.35,5.2,.35),"c4473a")
		block(p+Vector3(x,4.4,0),Vector3(.35,.3,1.4),"c4473a")
	for z in [-.6,.6]:
		var previous=Vector3.ZERO
		for i in 25:
			var x=-6.0+float(i)/24*12.0
			# Parabolic main span between the towers, straight back-stays outside.
			var y=1.9+pow(x/3.4,2)*3.3 if absf(x)<=3.4 else 5.2-(absf(x)-3.4)/2.6*3.7
			var at=p+Vector3(x,y,z)
			if i>0:
				beam(previous,at,.08,"d24c3c")
			if i%2==0 and at.y>1.7:
				beam(at,Vector3(at.x,1.5,at.z),.03,"d9d9d0")
			previous=at

func stone_bridge(p: Vector3) -> void:
	water_strip(p,3.6,9.0,false)
	block(p+Vector3(0,1.0,0),Vector3(1.6,.4,9.0),"c7b18c")
	for z in [-3.0,-1.0,1.0,3.0]:
		block(p+Vector3(0,.5,z),Vector3(1.6,.9,.6),"b49d78")
	for x in [-.75,.75]:
		block(p+Vector3(x,1.35,0),Vector3(.12,.3,9.0),"d6c29d")
	for z in [-4.3,4.3]:
		block(p+Vector3(0,2.0,z),Vector3(1.4,2.4,1.0),"a88b67")
		piece(cone,p+Vector3(0,3.6,z),Vector3(.9,1.0,.9),"52646a")

func basilica_dome(p: Vector3,stone: String,cap: String) -> void:
	block(p+Vector3(0,1.2,1.6),Vector3(3.6,2.4,2.0),stone)
	piece(roof,p+Vector3(0,2.7,1.6),Vector3(3.7,.7,2.1),"b9ab8c")
	piece(drum,p+Vector3(0,2.2,-.4),Vector3(3.0,4.4,3.0),stone)
	piece(half_ball,p+Vector3(0,4.4,-.4),Vector3(3.2,3.2,3.2),cap)
	piece(drum,p+Vector3(0,6.2,-.4),Vector3(.5,.8,.5),stone)
	piece(cone,p+Vector3(0,6.9,-.4),Vector3(.25,.7,.25),"d9ad50")
	for x in [-1.3,-.45,.45,1.3]:
		piece(trunk,p+Vector3(x,1.3,2.7),Vector3(1.6,2.6,1.6),"f2ead6")

func red_dome(p: Vector3) -> void:
	block(p+Vector3(0,1.3,1.8),Vector3(2.6,2.6,4.0),"ece3cf")
	piece(roof,p+Vector3(0,2.9,1.8),Vector3(2.7,.6,4.1),"c0613f")
	piece(drum,p+Vector3(0,2.6,-.8),Vector3(3.2,5.2,3.2),"ece3cf")
	piece(half_ball,p+Vector3(0,5.2,-.8),Vector3(3.3,4.2,3.3),"c9653d")
	for i in 8:
		var a=TAU*i/8
		beam(p+Vector3(cos(a)*1.6,5.2,-.8+sin(a)*1.6),p+Vector3(0,7.2,-.8),.08,"f4ede0")
	piece(drum,p+Vector3(0,7.5,-.8),Vector3(.5,.7,.5),"f4ede0")
	block(p+Vector3(2.3,3.4,1.6),Vector3(1.0,6.8,1.0),"ece3cf")
	block(p+Vector3(2.3,6.9,1.6),Vector3(1.2,.3,1.2),"5f7d58")

func mosque(p: Vector3,minarets: int) -> void:
	block(p+Vector3(0,1.0,0),Vector3(5.0,2.0,4.6),"dcd4c4")
	piece(half_ball,p+Vector3(0,2.0,0),Vector3(4.0,3.8,4.0),"8c9ea6")
	for d in [Vector3(1.8,0,0),Vector3(-1.8,0,0),Vector3(0,0,1.7),Vector3(0,0,-1.7)]:
		piece(half_ball,p+Vector3(0,2.0,0)+d,Vector3(1.9,1.8,1.9),"8c9ea6")
	piece(cone,p+Vector3(0,4.2,0),Vector3(.2,.8,.2),"d9ad50")
	var spots=[Vector3(-2.9,0,-2.7),Vector3(2.9,0,-2.7),Vector3(-2.9,0,2.7),Vector3(2.9,0,2.7),Vector3(-4.2,0,0),Vector3(4.2,0,0)]
	for i in clampi(minarets,2,6):
		var at=p+spots[i]
		piece(drum,at+Vector3(0,3.0,0),Vector3(.45,6.0,.45),"efe9dc")
		piece(drum,at+Vector3(0,4.6,0),Vector3(.75,.15,.75),"efe9dc")
		piece(cone,at+Vector3(0,6.6,0),Vector3(.42,1.3,.42),"8c9ea6")

func kremlin(p: Vector3) -> void:
	for side in [[0,-3.0,8.0,.5],[0,3.0,8.0,.5],[-4.0,0,.5,6.0],[4.0,0,.5,6.0]]:
		block(p+Vector3(side[0],.8,side[1]),Vector3(side[2],1.6,side[3]),"b0402f")
	for corner in [Vector3(-4,0,-3),Vector3(4,0,-3),Vector3(-4,0,3),Vector3(4,0,3)]:
		block(p+corner+Vector3(0,1.4,0),Vector3(.9,2.8,.9),"b0402f")
		piece(cone,p+corner+Vector3(0,3.4,0),Vector3(.7,1.4,.7),"3f7a5c")
	# Spasskaya tower with clock and star.
	var t=p+Vector3(0,0,3.0)
	block(t+Vector3(0,2.0,0),Vector3(1.4,4.0,1.4),"b0402f")
	block(t+Vector3(0,4.4,0),Vector3(1.0,.8,1.0),"e2d6b6")
	block(t+Vector3(0,3.4,.72),Vector3(.7,.7,.05),"f2e3b0")
	piece(cone,t+Vector3(0,5.9,0),Vector3(.9,2.2,.9),"3f7a5c")
	piece(ball,t+Vector3(0,7.2,0),Vector3(.45,.45,.45),"e5333a")
	for i in 3:
		var at=p+Vector3(-1.6+i*1.6,0,-.6)
		piece(drum,at+Vector3(0,1.5,0),Vector3(1.0,3.0,1.0),"efe6d0")
		piece(ball,at+Vector3(0,3.4,0),Vector3(1.1,1.3,1.1),"e2b544")

func opera(p: Vector3) -> void:
	water_strip(p+Vector3(0,0,2.6),9.0,2.4)
	put_mesh(box,p+Vector3(-1.2,.8,.4),Basis(Vector3.RIGHT,-.22)*Basis.from_scale(Vector3(6.4,.3,5.0)),"f2f2ee")
	put_mesh(box,p+Vector3(2.2,1.0,-.6),Basis(Vector3.FORWARD,.18)*Basis.from_scale(Vector3(3.6,.3,4.0)),"e6e8e6")
	block(p+Vector3(.6,2.3,-1.0),Vector3(2.4,2.6,2.0),"9cc4d0")
	block(p+Vector3(.6,3.7,-1.0),Vector3(2.5,.2,2.1),"f2f2ee")

func hallgrims(p: Vector3) -> void:
	block(p+Vector3(0,1.2,1.8),Vector3(2.2,2.4,3.0),"d9dad4")
	piece(roof,p+Vector3(0,2.8,1.8),Vector3(2.3,1.0,3.1),"7d8a8f")
	for step in 5:
		var w=4.4-step*.8
		var h=2.0+step*1.4
		for x in [-1,1]:
			block(p+Vector3(x*(w*.5-.35),h*.5,0),Vector3(.7,h,1.4),"e4e5e0")
	block(p+Vector3(0,5.0,0),Vector3(1.2,10.0,1.4),"eeefea")
	piece(cone,p+Vector3(0,10.7,0),Vector3(.7,1.6,.8),"7d8a8f")

func sagrada(p: Vector3) -> void:
	block(p+Vector3(0,1.5,0),Vector3(4.2,3.0,3.0),"c8a87a")
	var spires=[[-1.6,-1.0,7.0],[-.55,-1.0,8.0],[.55,-1.0,8.0],[1.6,-1.0,7.0],[-1.6,1.0,6.5],[-.55,1.0,7.5],[.55,1.0,7.5],[1.6,1.0,6.5],[0,0,10.5]]
	for s_value in spires:
		var at=p+Vector3(s_value[0],0,s_value[1])
		var h: float=s_value[2]
		var width=.9 if h<10 else 1.4
		piece(taper,at+Vector3(0,h*.5,0),Vector3(width,h,width),"b99a6c" if h<10 else "d3c7b3")
		piece(ball,at+Vector3(0,h+.2,0),Vector3(.45,.45,.45),"e0a33c" if h<10 else "f2f0ea")

func duomo(p: Vector3) -> void:
	block(p+Vector3(0,1.6,0),Vector3(6.0,3.2,3.2),"efe4e0")
	piece(roof,p+Vector3(0,3.6,0),Vector3(6.0,.8,3.2),"e2d6d0")
	for i in 9:
		for z in [-1.6,1.6]:
			piece(cone,p+Vector3(-2.8+i*.7,3.9,z),Vector3(.16,1.4,.16),"f4ece8")
	for z in [-1.0,0.0,1.0]:
		piece(cone,p+Vector3(-3.1,4.0,z),Vector3(.2,1.8,.2),"f4ece8")
	piece(cone,p+Vector3(.5,5.4,0),Vector3(.35,3.6,.35),"f4ece8")
	piece(ball,p+Vector3(.5,7.3,0),Vector3(.3,.4,.3),"e8b53e")

func twin_domes(p: Vector3) -> void:
	block(p+Vector3(1.2,1.6,0),Vector3(4.0,3.2,2.6),"9a4a35")
	piece(roof,p+Vector3(1.2,3.8,0),Vector3(4.1,1.4,2.7),"6b3a2c")
	for z in [-.75,.75]:
		block(p+Vector3(-1.4,3.0,z),Vector3(1.4,6.0,1.4),"9a4a35")
		piece(ball,p+Vector3(-1.4,6.6,z),Vector3(1.3,1.5,1.3),"4f8a77")
		piece(cone,p+Vector3(-1.4,7.5,z),Vector3(.15,.6,.15),"d9ad50")

func elbphilharmonie(p: Vector3) -> void:
	water_strip(p,8.0,6.0)
	block(p+Vector3(0,1.3,0),Vector3(5.0,2.6,3.4),"8d4f3c")
	block(p+Vector3(0,3.6,0),Vector3(5.0,2.0,3.4),"a6c7d6")
	for i in 6:
		var x=-2.1+i*.84
		block(p+Vector3(x,4.8+sin(i*1.2)*.5,0),Vector3(.86,.6+sin(i*1.2)*.5,3.4),"c4dde6")
	for i in 5:
		block(p+Vector3(-2.0+i*1.0,3.6,1.72),Vector3(.5,.5,.04),"eef6f8")

func cathedral_twin(p: Vector3) -> void:
	block(p+Vector3(1.6,2.0,0),Vector3(5.0,4.0,2.6),"4b4a46")
	piece(roof,p+Vector3(1.6,4.6,0),Vector3(5.1,1.4,2.7),"3b3e3f",0)
	for i in 6:
		for z in [-1.3,1.3]:
			piece(cone,p+Vector3(-.4+i*.8,4.3,z),Vector3(.14,1.2,.14),"5a5953")
	for z in [-.8,.8]:
		piece(taper,p+Vector3(-1.6,4.5,z),Vector3(1.6,9.0,1.6),"55534d")
		piece(cone,p+Vector3(-1.6,10.4,z),Vector3(.6,3.0,.6),"55534d")

func spire_tower(p: Vector3) -> void:
	block(p+Vector3(0,1.4,0),Vector3(4.6,2.8,3.0),"d6c9a8")
	block(p+Vector3(0,3.8,0),Vector3(2.6,2.4,2.2),"d6c9a8")
	block(p+Vector3(0,6.0,0),Vector3(1.8,2.0,1.6),"d6c9a8")
	block(p+Vector3(0,7.6,0),Vector3(1.1,1.4,1.0),"d6c9a8")
	piece(cone,p+Vector3(0,9.4,0),Vector3(.5,2.6,.5),"b9ac8c")
	block(p+Vector3(0,7.8,.52),Vector3(.5,.5,.04),"f2e3b0")

func crystal(p: Vector3) -> void:
	block(p+Vector3(0,.8,0),Vector3(4.2,1.6,4.2),"8a989c")
	put_mesh(box,p+Vector3(0,3.6,0),Basis(Vector3.UP,PI/4)*Basis(Vector3.RIGHT,PI/4)*Basis.from_scale(Vector3.ONE*3.2),"6fa3b8")
	put_mesh(box,p+Vector3(0,3.6,0),Basis(Vector3.UP,PI/4)*Basis.from_scale(Vector3(3.8,2.6,3.8)),"8fbccd")

func temple_front(p: Vector3) -> void:
	block(p+Vector3(0,1.6,0),Vector3(4.8,3.2,3.2),"f0ebdd")
	piece(roof,p+Vector3(0,3.6,1.0),Vector3(4.9,1.0,1.4),"e4dcc6")
	for x in [-1.8,-.9,0,.9,1.8]:
		piece(trunk,p+Vector3(x,1.6,1.8),Vector3(1.5,3.2,1.5),"f6f2e6")
	block(p+Vector3(3.4,2.8,1.0),Vector3(1.2,5.6,1.2),"f0ebdd")
	piece(cone,p+Vector3(3.4,6.1,1.0),Vector3(.5,1.0,.5),"8a9a91")

func volcano(p: Vector3,snow: bool) -> void:
	piece(cone,p+Vector3(0,2.6,0),Vector3(8.0,5.2,7.2),"7b6e60")
	piece(cone,p+Vector3(0,4.3,0),Vector3(4.2,2.6,3.8),"6a5f55" if not snow else "e8eee9")
	piece(drum,p+Vector3(0,5.45,0),Vector3(1.5,.2,1.4),"4a3f37" if not snow else "e8eee9")
	if not snow:
		for i in 3:
			piece(ball,p+Vector3(.3*i,6.4+i*.9,-.2*i),Vector3.ONE*(1.0+i*.45),"d4d1cc")

func castle_hill(p: Vector3) -> void:
	mound(p,Vector2(4.0,3.4),2.0,"6f8a5a")
	at_kit_scale(p,func(): kit.castle(p+Vector3(0,1.1,0),false,false))

func canal_houses(p: Vector3) -> void:
	water_strip(p+Vector3(0,0,1.6),9.0,1.6)
	var colours=["d9533f","f2c14e","3f88c5","6dbb75","e98aa3","f29e4c","8e7dbe","4fb3bf"]
	for i in 8:
		var h=2.2+float((i*7)%4)*.45
		var at=p+Vector3(-3.9+i*1.1,0,0)
		block(at+Vector3(0,h*.5,0),Vector3(1.0,h,1.6),colours[(i+int(absf(p.x)))%colours.size()])
		for step in 3:
			block(at+Vector3(0,h+.12+step*.22,.8),Vector3(.9-step*.28,.22,.08),colours[(i+int(absf(p.x)))%colours.size()])
		for y in [.8,1.6]:
			block(at+Vector3(0,y,.81),Vector3(.5,.35,.04),"f6f1e2")

func parliament(p: Vector3) -> void:
	water_strip(p+Vector3(0,0,2.6),11.0,2.0)
	block(p+Vector3(0,1.4,0),Vector3(9.0,2.8,2.6),"efe5d2")
	piece(roof,p+Vector3(0,3.2,0),Vector3(9.1,.9,2.7),"b9473c",0)
	for i in 13:
		piece(cone,p+Vector3(-4.3+i*.72,3.4,1.3),Vector3(.13,1.3,.13),"f6efe2")
	piece(drum,p+Vector3(0,3.6,0),Vector3(2.0,2.0,2.0),"efe5d2")
	piece(half_ball,p+Vector3(0,4.6,0),Vector3(2.2,2.4,2.2),"b9473c")
	piece(cone,p+Vector3(0,6.6,0),Vector3(.3,2.2,.3),"efe5d2")
	for x in [-4.3,4.3]:
		block(p+Vector3(x,2.4,0),Vector3(1.0,4.8,1.0),"efe5d2")
		piece(cone,p+Vector3(x,5.4,0),Vector3(.5,1.4,.5),"b9473c")

func palace(p: Vector3) -> void:
	at_kit_scale(p,func(): kit.palace(p,1.0,false))

# --- Landscape --------------------------------------------------------------

func land_at(pos: Vector3) -> bool:
	if world.lake_contains(pos):
		return false
	for code in world.country_polys:
		if world.country_contains(code,pos):
			return true
	return false

func landscape() -> void:
	# Sparse patches use all-vertex coastline checks to avoid painting over sea.
	for i in 1300:
		var center=world.project(rng.randf_range(-23,43),rng.randf_range(35,70))
		var extent=rng.randf_range(1.2,3.0)
		var valid=true
		for offset in [Vector3(-extent,0,-extent),Vector3(extent,0,-extent),Vector3(extent,0,extent),Vector3(-extent,0,extent)]:
			valid=valid and land_at(center+offset)
		if not valid:
			continue
		var geo=world.unproject(center)
		var latitude=geo.y
		var color="a49465" if latitude<44 else "c0ad72" if latitude<46 and geo.x<-1 else "8a8f6a" if latitude>65 else "55765c" if latitude>57 else "73845c" if i%2==0 else "849457"
		terrain_patch(center,extent,color)
		terrain_patches+=1
		if i%3==0:
			for j in 5:
				tree(center+Vector3(rng.randf_range(-extent,extent),0,rng.randf_range(-extent,extent)),rng.randf_range(.6,1.3))
		# Olive groves and vineyards: neat rows in the south.
		if latitude<46.5 and latitude>36 and i%4==1:
			grove(center,latitude<42)
	# Symbolic mountain belts, with rock, foothills and snow caps.
	for belt in BELTS:
		for i in int(belt[4]):
			var t=float(i)/maxf(1,float(belt[4])-1)
			var center=world.project(lerpf(belt[0],belt[2],t)+rng.randf_range(-.3,.3),lerpf(belt[1],belt[3],t)+rng.randf_range(-.2,.2))
			if land_at(center):
				peak(center,rng.randf_range(3.5,7.5))
	taiga()
	sea_life()

func grove(center: Vector3,olive: bool) -> void:
	var angle=rng.randf()*PI
	var along=Vector3(cos(angle),0,sin(angle))
	var across=Vector3(-along.z,0,along.x)
	for row in 3:
		for k in 6:
			var at=center+along*(k-2.5)*.55+across*(row-1)*.6
			if olive:
				piece(leaf,at+Vector3(0,.35,0),Vector3(.5,.45,.5),"7d8f5a")
			else:
				block(at+Vector3(0,.2,0),Vector3(.5,.3,.18),"5f7d3a",angle)
		grove_rows+=1

func taiga() -> void:
	# Dense conifers across Scandinavia, Finland and north-west Russia.
	for i in 520:
		var at=world.project(rng.randf_range(8,42),rng.randf_range(58.5,68.5))
		if not land_at(at):
			continue
		for j in 2:
			var p=at+Vector3(rng.randf_range(-1.2,1.2),0,rng.randf_range(-1.2,1.2))
			var s_value=rng.randf_range(.7,1.2)
			piece(cone,p+Vector3(0,1.2*s_value,0),Vector3(.9,2.6,.9)*s_value,"2f5a45" if j==0 else "3b6a4e")
			taiga_trees+=1

func sea_life() -> void:
	for lane in SEA_LANES:
		var at=world.project(lane[0],lane[1])
		if land_at(at):
			continue
		boat(at,rng.randf()*TAU,ships_built%3)
		ships_built+=1
	for spot in LIGHTHOUSE_POINTS:
		var at=coast_near(world.project(spot[0],spot[1]))
		if at==Vector3.INF:
			continue
		at_kit_scale(at,func(): kit.lighthouse(at,"c4473a" if lighthouses_built%2==0 else "f2ede0",6.0))
		lighthouses_built+=1
	for farm in WIND_FARMS:
		var center=world.project(farm[0],farm[1])
		for i in 6:
			var at=center+Vector3((i%3)*2.4-2.4,0,(i/3)*2.4-1.2)
			if land_at(at):
				continue
			turbine(at,float(i)*.7)
			turbines_built+=1

# The nearest point on land, searching outward in rings: capes in the
# simplified outlines rarely sit exactly on the real coordinate.
func coast_near(p: Vector3) -> Vector3:
	if land_at(p):
		return p
	for ring in range(1,9):
		for k in 12:
			var a=TAU*k/12.0
			var at=p+Vector3(cos(a),0,sin(a))*ring*.6
			if land_at(at):
				return at
	return Vector3.INF

func boat(p: Vector3,angle: float,kind: int) -> void:
	var forward=Vector3(sin(angle),0,cos(angle))
	ribbon(p-forward*1.8,p-forward*5.5,.9,"d9eef0")
	match kind:
		0:
			# Container ship.
			block(p+Vector3(0,.35,0),Vector3(1.3,.6,4.2),"2f4f6a",angle)
			for k in 3:
				block(p+forward*(-1.0+k*.9)+Vector3(0,.85,0),Vector3(1.1,.45,.8),["d9533f","f2c14e","3f88c5"][k],angle)
			block(p-forward*1.7+Vector3(0,1.0,0),Vector3(1.0,.9,.6),"eceee9",angle)
		1:
			# Ferry.
			block(p+Vector3(0,.35,0),Vector3(1.2,.6,3.6),"eceee9",angle)
			block(p+Vector3(0,.85,0),Vector3(1.0,.5,2.6),"c4473a",angle)
			block(p+Vector3(0,1.25,0),Vector3(.8,.35,1.6),"eceee9",angle)
		_:
			# Sailing yacht.
			block(p+Vector3(0,.25,0),Vector3(.7,.35,2.0),"f2f0ea",angle)
			beam(p+Vector3(0,.3,0),p+Vector3(0,3.0,0),.07,"8a8f8c")
			piece(roof,p+Vector3(0,1.7,0)+forward*.35,Vector3(.06,2.4,1.1),"f6f4ee",angle)

func turbine(p: Vector3,phase: float) -> void:
	piece(drum,p+Vector3(0,.15,0),Vector3(.6,.3,.6),"e7b528")
	piece(taper,p+Vector3(0,3.0,0),Vector3(.32,6.0,.32),"f1f3f2")
	var hub=p+Vector3(0,6.0,.25)
	block(hub+Vector3(0,0,-.3),Vector3(.35,.35,.8),"f1f3f2")
	for k in 3:
		var a=phase+k*TAU/3
		beam(hub,hub+Vector3(cos(a),sin(a),0)*2.6,.14,"f6f7f6")

func peak(p: Vector3,height: float) -> void:
	piece(cone,p+Vector3(0,height*.4,0),Vector3(5.5,height*.8,4.8),"71856f",rng.randf()*TAU)
	piece(cone,p+Vector3(0,height*.54,0),Vector3(3.6,height,3.3),"83929a",rng.randf()*TAU)
	piece(cone,p+Vector3(0,height*.96,0),Vector3(1.3,height*.3,1.2),"e2ece3")
	peak_count+=1

func terrain_patch(center: Vector3,extent: float,color: String) -> void:
	var patch_surface: SurfaceTool=surface(color)
	# Visible from both sides in Compatibility, like the base map polygons.
	var patch_material: StandardMaterial3D=material(color)
	patch_material.cull_mode=BaseMaterial3D.CULL_DISABLED
	var ring: Array[Vector3]=[]
	var angle=rng.randf()*TAU
	for i in 7:
		var theta=angle+i*TAU/7.0
		ring.append(center+Vector3(cos(theta),0,sin(theta))*extent*rng.randf_range(.65,1.0))
	for i in 7:
		for at in [center,ring[(i+1)%7],ring[i]]:
			patch_surface.set_normal(Vector3.UP)
			patch_surface.set_uv(Vector2.ZERO)
			patch_surface.add_vertex(Vector3(at.x,.035,at.z))
