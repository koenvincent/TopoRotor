class_name EuropeScenery
extends DutchScenery

# Exaggerated, deterministic miniatures. Geographic anchors use the catalogue;
# regional scenery is decorative, not an elevation or land-use dataset.
var city_styles: Dictionary = {}
var terrain_patches: int = 0
var peak_count: int = 0

func town(pos: Vector3,place_name: String) -> void:
	var geo=world.unproject(pos)
	var north=geo.y>55
	var south=geo.y<44
	var walls=["e3c891","d4a46e","eadbb3","bb7656"] if south else ["ccd2c5","bd9b7a","dbcfb0","9baead"]
	var roofs=["ae593e","cb8050","8a5143"] if south else ["3e5662","596975","934c41"]
	city_styles[place_name]="mediterranean" if south else "nordic" if north else "continental"
	# Two avenues and four neighbourhoods; centre stays clear for the helipad.
	block(pos+Vector3(0,.06,0),Vector3(14,.06,.65),"b4afa0")
	block(pos+Vector3(0,.07,0),Vector3(.65,.06,12),"b4afa0")
	for i in 24:
		var x=(float(i%6)-2.5)*2.0
		var z=(float(i/6)-1.5)*2.6
		if abs(x)<1.5 and abs(z)<2:
			continue
		var height=rng.randf_range(.9,2.4) if south else rng.randf_range(1.2,3.1)
		house(pos+Vector3(x,0,z),Vector3(1.2,height,1.6),walls[i%4],roofs[i%3])
	for i in 7:
		tree(pos+Vector3(-7+rng.randf_range(-1,1),0,-5+i*1.6),.6 if south else .9)
	var anchor=pos+Vector3(6,0,-7)
	match place_name:
		"Parijs": eiffel(anchor)
		"Londen": clock_tower(anchor)
		"Berlijn": gate(anchor)
		"Rome": arena(anchor)
		"Athene": temple(anchor)
		"Moskou", "Kyiv", "Sofia": domes(anchor)
		"Stockholm", "Kopenhagen", "Oslo", "Helsinki", "Reykjavik": nordic_hall(anchor)
		"Madrid", "Lissabon", "Valletta", "Nicosia": fortress(anchor)
		_: palace(anchor)
	landmarks[place_name]=true

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

func gate(p: Vector3) -> void:
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
	block(p+Vector3(0,.2,0),Vector3(6,.4,4.5),"e3cf9e")
	for x in [-2,-1,0,1,2]:
		for z in [-1.5,1.5]:
			piece(trunk,p+Vector3(x,1.8,z),Vector3(2.2,3,2.2),"f0dfb8")
	piece(roof,p+Vector3(0,3.8,0),Vector3(6,1.1,4.5),"d5bc8b")

func domes(p: Vector3) -> void:
	block(p+Vector3(0,1.3,0),Vector3(4,2.6,3),"ddd3ba")
	for i in 3:
		var at=p+Vector3((i-1)*1.6,3.3,0)
		piece(trunk,at,Vector3(4,2,4),"d9b464")
		piece(leaf,at+Vector3(0,1.3,0),Vector3(1.7,1.7,1.7),"638b82" if i!=1 else "d9ad50")
		beam(at+Vector3(0,1.8,0),at+Vector3(0,2.8,0),.1,"d9ad50")

func nordic_hall(p: Vector3) -> void:
	house(p,Vector3(5,2.5,3),"a1513e","3e5662")
	tower(p+Vector3(-2,0,0),"c6c9bf",6)
	for i in 5:
		block(p+Vector3(i-2,1.5,1.53),Vector3(.35,.7,.04),"f5da8a")

func fortress(p: Vector3) -> void:
	block(p+Vector3(0,1.2,0),Vector3(6,2.4,3.5),"d4ae7a")
	for x in [-2.6,2.6]:
		for z in [-1.4,1.4]:
			tower(p+Vector3(x,0,z),"c79c68",4)

func land_at(pos: Vector3) -> bool:
	if world.lake_contains(pos):
		return false
	for code in world.country_polys:
		if world.country_contains(code,pos):
			return true
	return false

func landscape() -> void:
	# Sparse patches use all-vertex coastline checks to avoid painting over sea.
	for i in 1100:
		var center=world.project(rng.randf_range(-23,43),rng.randf_range(35,70))
		var extent=rng.randf_range(1.2,3.0)
		var points=PackedVector2Array()
		var valid=true
		for offset in [Vector3(-extent,0,-extent),Vector3(extent,0,-extent),Vector3(extent,0,extent),Vector3(-extent,0,extent)]:
			var at=center+offset
			valid=valid and land_at(at)
			points.append(Vector2(at.x,at.z))
		if not valid:
			continue
		var latitude=world.unproject(center).y
		var color="a49465" if latitude<44 else "55765c" if latitude>57 else "73845c"
		# Flat patch, merged with every other same-colour patch.
		terrain_patch(center,extent,color)
		terrain_patches+=1
		if i%3==0:
			for j in 5:
				tree(center+Vector3(rng.randf_range(-extent,extent),0,rng.randf_range(-extent,extent)),rng.randf_range(.6,1.3))
	# Symbolic mountain belts, with rock, foothills and snow caps.
	for belt in [[-5.0,43.0,3.0,42.6,12],[6.0,45.5,15.0,47.0,22],[5.0,58.0,19.0,68.0,22],[18.0,49.0,26.0,46.0,14],[17.0,43.5,24.0,39.5,12]]:
		for i in int(belt[4]):
			var t=float(i)/maxf(1,float(belt[4])-1)
			var center=world.project(lerpf(belt[0],belt[2],t)+rng.randf_range(-.3,.3),lerpf(belt[1],belt[3],t)+rng.randf_range(-.2,.2))
			if land_at(center):
				peak(center,rng.randf_range(3.5,7.0))

func peak(p: Vector3,height: float) -> void:
	piece(cone,p+Vector3(0,height*.4,0),Vector3(5.5,height*.8,4.8),"71856f",rng.randf()*TAU)
	piece(cone,p+Vector3(0,height*.54,0),Vector3(3.6,height,3.3),"83929a",rng.randf()*TAU)
	piece(cone,p+Vector3(0,height*.96,0),Vector3(1.3,height*.3,1.2),"e2ece3")
	peak_count+=1

func terrain_patch(center: Vector3,extent: float,color: String) -> void:
	if not surfaces.has(color):
		var surface=SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surfaces[color]=surface
	var surface: SurfaceTool=surfaces[color]
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
			surface.set_normal(Vector3.UP)
			surface.set_uv(Vector2.ZERO)
			surface.add_vertex(Vector3(at.x,.035,at.z))
