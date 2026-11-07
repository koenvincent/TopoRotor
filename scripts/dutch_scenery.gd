class_name DutchScenery
extends RefCounted

# Geographic anchors come from the catalogue. Buildings and terrain are
# deliberately exaggerated miniatures, not a street map or elevation dataset.
var world: Node3D
var rng = RandomNumberGenerator.new()
var surfaces: Dictionary = {}
var materials: Dictionary = {}
var box = BoxMesh.new()
var roof = PrismMesh.new()
var leaf = SphereMesh.new()
var cone = CylinderMesh.new()
var trunk = CylinderMesh.new()
var landmarks: Dictionary = {}

func _init(parent: Node3D) -> void:
	world=parent
	rng.seed=1206
	leaf.radial_segments=5
	leaf.rings=2
	cone.top_radius=0
	cone.bottom_radius=1
	cone.height=1
	cone.radial_segments=6
	trunk.top_radius=.12
	trunk.bottom_radius=.17
	trunk.height=1
	trunk.radial_segments=5

func material(hex: String) -> Material:
	if not materials.has(hex):
		var m=StandardMaterial3D.new()
		m.albedo_color=Color(hex)
		m.roughness=.88
		materials[hex]=m
	return materials[hex]

func piece(mesh: Mesh, pos: Vector3, dimensions: Vector3, color: String, angle: float=0) -> void:
	if not surfaces.has(color):
		var surface=SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surfaces[color]=surface
	var basis=Basis(Vector3.UP,angle) * Basis.from_scale(dimensions)
	surfaces[color].append_from(mesh,0,Transform3D(basis,pos))

func block(pos: Vector3, dimensions: Vector3, color: String, angle: float=0) -> void:
	piece(box,pos,dimensions,color,angle)

func beam(a: Vector3,b: Vector3,width: float,color: String) -> void:
	if not surfaces.has(color):
		var surface=SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surfaces[color]=surface
	var direction=b-a
	var up=Vector3.RIGHT if abs(direction.normalized().dot(Vector3.UP))>.98 else Vector3.UP
	var basis=Basis.looking_at(direction.normalized(),up) * Basis.from_scale(Vector3(width,width,direction.length()))
	surfaces[color].append_from(box,0,Transform3D(basis,(a+b)*.5))

func house(pos: Vector3, size: Vector3, color: String, roof_color: String="b76b3e", angle: float=0) -> void:
	block(pos+Vector3(0,size.y*.5,0),size,color,angle)
	piece(roof,pos+Vector3(0,size.y+.3,0),Vector3(size.x*1.12,.7,size.z*1.12),roof_color,angle)
	# Windows and doors are geometry, so the exported game needs no textures.
	var front=Vector3(sin(angle),0,cos(angle))
	var right=Vector3(cos(angle),0,-sin(angle))
	for side in [-1,1]:
		var window=pos+front*(size.z*.5+.02)+right*(size.x*.26*side)+Vector3(0,size.y*.65,0)
		block(window,Vector3(.21,.3,.035),"35535a",angle)
	block(pos+front*(size.z*.5+.035)+Vector3(0,.3,0),Vector3(.22,.6,.045),"60483a",angle)
	block(pos+Vector3(size.x*.25,size.y+.7,0),Vector3(.22,.65,.25),"d8bf93",angle)

func tree(pos: Vector3, scale_value: float=1) -> void:
	piece(trunk,pos+Vector3(0,.65*scale_value,0),Vector3(scale_value,1.3*scale_value,scale_value),"67543c")
	var foliage=["466634","58743a","344f32","718346"]
	var shade=foliage[rng.randi_range(0,3)]
	if rng.randf()<.35:
		piece(cone,pos+Vector3(0,2*scale_value,0),Vector3(.9,2.8,.9)*scale_value,shade)
		piece(cone,pos+Vector3(0,2.65*scale_value,0),Vector3(.65,1.8,.65)*scale_value,shade)
	else:
		piece(leaf,pos+Vector3(0,1.9*scale_value,0),Vector3(2.1,1.8,1.9)*scale_value,shade,rng.randf()*TAU)
		piece(leaf,pos+Vector3(.45,2.4,.12)*scale_value,Vector3(1.5,1.2,1.5)*scale_value,shade)

func forest(points: Array) -> void:
	for point in points:
		var center=world.project(point[0],point[1])
		for i in 3:
			var pos=center+Vector3(rng.randf_range(-1.1,1.1),0,rng.randf_range(-1.1,1.1))
			if world.country_contains("NLD",pos):
				tree(pos,rng.randf_range(.7,1.3))

func town(pos: Vector3,name: String) -> void:
	if name=="Amsterdam":
		amsterdam(pos)
	elif name=="Rotterdam":
		rotterdam(pos)
	elif name=="Utrecht":
		utrecht(pos)
	else:
		var walls=["d4bc8c","eddbac","b88861","e2d0a0"]
		for i in 12:
			var x=float(i%4-2)*1.25
			var z=float(i/4-1)*1.9
			if name=="Arnhem" or name=="Nijmegen":
				z+=2.0
			house(pos+Vector3(x,0,z),Vector3(.95,rng.randf_range(.85,1.65),1.25),walls[i%4],"a76142" if i%3 else "53666b")
		block(pos+Vector3(-.6,.055,0),Vector3(6,.05,.5),"c6b58d")
		if name=="Den Haag":
			palace(pos+Vector3(0,0,-4))
		elif name=="Groningen":
			tower(pos+Vector3(0,0,-3),"b69770",5.5)
		elif name=="Arnhem" or name=="Nijmegen":
			bridge(pos+Vector3(0,0,-1),false)
		elif name=="Maastricht":
			bridge(pos+Vector3(0,0,-1),false)
		elif name=="Leeuwarden" or name=="Delft" or name=="Middelburg":
			tower(pos+Vector3(0,0,-3),"d4bc8c",4)
		for i in 4:
			tree(pos+Vector3(-4.1+i*2.2,0,3.3),.55)
	landmarks[name]=true

func tower(pos: Vector3,color: String,height: float) -> void:
	block(pos+Vector3(0,height*.28,0),Vector3(1.35,height*.56,1.35),color)
	block(pos+Vector3(0,height*.65,0),Vector3(1.05,height*.3,1.05),color)
	block(pos+Vector3(0,height*.83,0),Vector3(.8,height*.12,.8),"b9ae92")
	piece(cone,pos+Vector3(0,height,0),Vector3(.6,height*.25,.6),"445c62")
	for x in [-.35,.35]:
		block(pos+Vector3(x,height*.64,.54),Vector3(.22,.8,.035),"344b4e")
	block(pos+Vector3(0,height*.85,.43),Vector3(.32,.32,.035),"ead8a1")

func amsterdam(pos: Vector3) -> void:
	# Three miniature canal arcs suggest the grachtengordel. They are symbolic,
	# not replacements for the geographic rivers in map_nl.json.
	for radius in [3.0,5.1,7.2]:
		var last=pos+Vector3(-radius,.09,0)
		for i in range(1,17):
			var a=PI+float(i)/16.0*PI
			var next=pos+Vector3(cos(a)*radius,.09,-sin(a)*radius*.65)
			beam(last,next,.55,"318c9a")
			last=next
	for row in 2:
		for i in 9:
			var a=PI+(.12+float(i)*.095)*PI
			var radius=3.8+row*2.2
			var at=pos+Vector3(cos(a)*radius,0,-sin(a)*radius*.65)
			house(at,Vector3(.7,1.6+float(i%3)*.35,1.0),["9e6249","d8c99d","b68860"][i%3],"514e48",-a)
	for x in [-3.5,0,3.5]:
		block(pos+Vector3(x,.26,2.6),Vector3(.65,.25,2.8),"d5c497")
	# Canal boat and central church silhouette.
	block(pos+Vector3(3.0,.23,3.5),Vector3(.45,.35,1.4),"f3dfaf")
	tower(pos+Vector3(-1,0,-1),"c7b58b",4.5)

func bridge(pos: Vector3,cabled: bool) -> void:
	block(pos+Vector3(0,.12,0),Vector3(11,.1,2.0),"318c9a")
	block(pos+Vector3(0,.72,0),Vector3(.9,.25,5.8),"d5cdb0")
	for side in [-.52,.52]:
		beam(pos+Vector3(side,1,-2.9),pos+Vector3(side,1,2.9),.065,"f0e5c5")
	if cabled:
		var apex=pos+Vector3(.6,4.3,.8)
		beam(pos+Vector3(0,.8,1.5),apex,.3,"eee5c7")
		beam(apex,pos+Vector3(0,.8,2.7),.19,"eee5c7")
		for z in [-2.7,-1.8,-.9,0.0]:
			beam(apex,pos+Vector3(-.35,.9,z),.045,"e8e3c9")
	else:
		for z in [-2.2,0,2.2]:
			block(pos+Vector3(0,.37,z),Vector3(.65,.7,.4),"ad9675")

func rotterdam(pos: Vector3) -> void:
	bridge(pos,true)
	for i in 6:
		var h=1.8+float(i%3)*1.25
		block(pos+Vector3(2.1+float(i%3)*1.45,h*.5,-2.5+float(i/3)*2.2),Vector3(1.05,h,1.15),["728e8e","a9b9af","d4cfac"][i%3])
	# Harbour quays, colourful containers, cranes and a cargo vessel.
	block(pos+Vector3(-5,.05,0),Vector3(5,.1,5),"8f9b8d")
	block(pos+Vector3(-7,.1,2.8),Vector3(5,.15,1.8),"318c9a")
	for i in 8:
		block(pos+Vector3(-6+float(i%4)*.8,.35,-1+float(i/4)),Vector3(.65,.6,.8),["b57545","627f80","d8bb63"][i%3])
	for x in [-6.5,-3.5]:
		beam(pos+Vector3(x,0,.3),pos+Vector3(x,3,.3),.15,"d9b85c")
		beam(pos+Vector3(x,3,-.3),pos+Vector3(x,3,2.5),.16,"d9b85c")
		beam(pos+Vector3(x,3,2.1),pos+Vector3(x,1.3,2.1),.06,"40585b")
	block(pos+Vector3(-5.3,.25,2.7),Vector3(2.8,.5,.75),"354f59")
	block(pos+Vector3(-4.3,.7,2.7),Vector3(.5,.7,.55),"ead6a5")

func utrecht(pos: Vector3) -> void:
	block(pos+Vector3(-2,.07,0),Vector3(.65,.1,10),"318c9a")
	for i in 5:
		for x in [-3.3,-.7]:
			house(pos+Vector3(x,0,float(i)*1.6-3.4),Vector3(.9,1.3+float(i%2)*.3,1.1),"d4b98a")
	for z in [-2,2.5]:
		block(pos+Vector3(-2,.25,z),Vector3(2,.25,.65),"d8c9a3")
	tower(pos+Vector3(1.2,0,0),"bfad8c",6.7)
	house(pos+Vector3(3.1,0,-1.8),Vector3(2,2.3,4),"dac8a2","606a64")

func palace(pos: Vector3) -> void:
	block(pos+Vector3(0,.06,-1.3),Vector3(6,.08,2),"318c9a")
	for x in [-2.0,0.0,2.0]:
		house(pos+Vector3(x,0,0),Vector3(1.8,1.8,2),"c5aa7b","625748")
	for x in [-1.1,1.1]:
		tower(pos+Vector3(x,0,1.2),"c5aa7b",2.7)

func mound(center: Vector3,radius: Vector2,height: float,color: String) -> void:
	# Low faceted relief: Holland remains flat; only dunes and Limburg rise.
	if not world.country_contains("NLD",center):
		return
	if not surfaces.has(color):
		var surface=SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surfaces[color]=surface
	var st: SurfaceTool=surfaces[color]
	for i in 9:
		var a=TAU*float(i)/9
		var b=TAU*float(i+1)/9
		var p=center+Vector3(cos(a)*radius.x,.04,sin(a)*radius.y)
		var q=center+Vector3(cos(b)*radius.x,.04,sin(b)*radius.y)
		var peak=center+Vector3(radius.x*.12,height,-radius.y*.08)
		# Prevent decorative relief leaking over the geographic shoreline.
		if not world.country_contains("NLD",p) or not world.country_contains("NLD",q):
			continue
		var normal=(q-p).cross(peak-p).normalized()
		var vertices=[p,q,peak]
		if normal.y<0:
			normal=-normal
			vertices=[p,peak,q]
		for vertex in vertices:
			st.set_normal(normal)
			st.add_vertex(vertex)

func landscape() -> void:
	# Small flat grass facets add texture without external bitmap assets.
	var grass=SurfaceTool.new()
	grass.begin(Mesh.PRIMITIVE_TRIANGLES)
	for field in world.map_data.fields:
		var center=Vector3.ZERO
		for geo in field.polygon:
			center+=world.project(geo[0],geo[1])
		center/=field.polygon.size()
		for i in 4:
			var point=field.polygon[rng.randi_range(0,field.polygon.size()-1)]
			var at=center.lerp(world.project(point[0],point[1]),rng.randf_range(.1,.7))
			if not world.country_contains("NLD",at):
				continue
			var radius=rng.randf_range(.15,.65)
			grass.set_normal(Vector3.UP)
			for offset in [Vector3(-radius,.045,0),Vector3(0,.045,radius*.65),Vector3(radius,.045,-radius*.4)]:
				grass.add_vertex(at+offset)
	surfaces["a0ae63"]=grass
	# Approximate regional bands, not a digital elevation model.
	for geo in [Vector2(4.36,52.13),Vector2(4.43,52.22),Vector2(4.55,52.36),Vector2(4.60,52.45),Vector2(4.65,52.56),Vector2(4.68,52.65),Vector2(4.72,52.75),Vector2(4.74,52.84)]:
		var center=world.project(geo.x,geo.y)
		mound(center,Vector2(1.1,3.1),.65,"d5c48a")
		for i in 3:
			var at=center+Vector3(rng.randf_range(-.5,1),0,rng.randf_range(-2,2))
			if world.country_contains("NLD",at):
				piece(leaf,at+Vector3(0,.3,0),Vector3(.8,.65,.7),"889653")
	for geo in [Vector2(5.88,50.83),Vector2(5.98,50.85),Vector2(5.92,50.90),Vector2(6.0,50.91)]:
		mound(world.project(geo.x,geo.y),Vector2(3.8,3.8),1.6,"8c9d56")
	# Small windmills are landscape accents around the western polders.
	for geo in [Vector2(4.48,52.05),Vector2(4.64,52.46),Vector2(4.88,51.89)]:
		windmill(world.project(geo.x,geo.y))

func windmill(pos: Vector3) -> void:
	if not world.country_contains("NLD",pos):
		return
	piece(cone,pos+Vector3(0,1.0,0),Vector3(.8,2,.8),"ae9566")
	piece(cone,pos+Vector3(0,2.15,0),Vector3(.65,.7,.65),"4b5146")
	for sign_value in [-1,1]:
		beam(pos+Vector3(-1.25,2.2-sign_value*1.25,.6),pos+Vector3(1.25,2.2+sign_value*1.25,.6),.14,"e4d5ae")

func bake() -> void:
	# One draw surface per palette colour rather than one node per window/tree.
	for color in surfaces:
		var node=MeshInstance3D.new()
		node.name="DutchScenery_"+color
		node.mesh=surfaces[color].commit()
		node.material_override=material(color)
		world.add_child(node)
