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
var city_plans: Dictionary = {}
var city_stats: Dictionary = {}
var landmark_data: Dictionary = {}
var landmark_built: Dictionary = {}
var kit: LandmarkKit
# Blender pieces (tools/blender/models.py, "scenery"): chamfered blocks for
# walls and big parts, bevelled gable roofs, faceted tree crowns and tiered
# pines. Thin parts such as windows keep the plain box to stay light.
var soft_block: Mesh = box
var crown: Mesh = leaf
var pine: Mesh = cone
const SOFT_MIN = .3
static var _kit: Dictionary = {}

static func scenery_kit() -> Dictionary:
	if _kit.is_empty():
		for file in ["res://assets/models/scenery.glb","res://assets/models/landmarks.glb"]:
			if not ResourceLoader.exists(file):
				continue
			var scene: Node = (load(file) as PackedScene).instantiate()
			for node in scene.find_children("*","MeshInstance3D",true,false):
				_kit[node.name]=(node as MeshInstance3D).mesh
			scene.free()
	return _kit

func _init(parent: Node3D) -> void:
	world=parent
	city_plans=JSON.parse_string(FileAccess.get_file_as_string("res://data/city_plans_nl.json")).cities
	landmark_data=JSON.parse_string(FileAccess.get_file_as_string("res://data/landmarks_nl.json")).cities
	kit=LandmarkKit.new(self)
	var pieces: Dictionary=scenery_kit()
	soft_block=pieces.get("Block",box)
	roof=pieces.get("Roof",roof)
	crown=pieces.get("Crown",leaf)
	pine=pieces.get("Pine",cone)
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

func surface(color: String) -> SurfaceTool:
	if not surfaces.has(color):
		var st=SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		surfaces[color]=st
	return surfaces[color]

func piece(mesh: Mesh, pos: Vector3, dimensions: Vector3, color: String, angle: float=0) -> void:
	surface(color)
	var basis=Basis(Vector3.UP,angle) * Basis.from_scale(dimensions)
	surfaces[color].append_from(mesh,0,Transform3D(basis,pos))

# Every free-form mesh placement goes through here, so a subclass can transform it.
func put_mesh(mesh: Mesh,origin: Vector3,basis: Basis,color: String) -> void:
	surface(color).append_from(mesh,0,Transform3D(basis,origin))

func block(pos: Vector3, dimensions: Vector3, color: String, angle: float=0) -> void:
	var soft=dimensions.x>SOFT_MIN and dimensions.y>SOFT_MIN and dimensions.z>SOFT_MIN
	piece(soft_block if soft else box,pos,dimensions,color,angle)

func beam(a: Vector3,b: Vector3,width: float,color: String) -> void:
	if not surfaces.has(color):
		var surface=SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surfaces[color]=surface
	var direction=b-a
	var up=Vector3.RIGHT if abs(direction.normalized().dot(Vector3.UP))>.98 else Vector3.UP
	var basis=Basis.looking_at(direction.normalized(),up) * Basis.from_scale(Vector3(width,width,direction.length()))
	surfaces[color].append_from(box,0,Transform3D(basis,(a+b)*.5))

func ribbon(a: Vector3,b: Vector3,width: float,color: String) -> void:
	var delta=b-a
	if delta.length()<.001:
		return
	var angle=atan2(delta.x,delta.z)
	block((a+b)*.5,Vector3(width,.025,delta.length()),color,angle)

func house(pos: Vector3, size: Vector3, color: String, roof_color: String="b76b3e", angle: float=0, roof_style: int=-1) -> void:
	if roof_style<0:
		roof_style=rng.randi_range(0,3)
	block(pos+Vector3(0,size.y*.5,0),size,color,angle)
	var front=Vector3(sin(angle),0,cos(angle))
	var right=Vector3(cos(angle),0,-sin(angle))
	if roof_style==2:
		# Flat roofs distinguish post-war housing, offices and warehouses.
		block(pos+Vector3(0,size.y+.06,0),Vector3(size.x*1.04,.12,size.z*1.04),roof_color,angle)
		block(pos+Vector3(0,size.y+.22,0),Vector3(size.x*.35,.25,size.z*.3),"86918b",angle)
	else:
		piece(roof,pos+Vector3(0,size.y+.3,0),Vector3(size.x*1.10,.7,size.z*1.08),roof_color,angle)
		if roof_style==1:
			for level in 3:
				block(pos+front*(size.z*.5+.02)+Vector3(0,size.y+.12+level*.18,0),Vector3(size.x*(.85-level*.23),.18,.1),color,angle)
		elif roof_style==3:
			block(pos+Vector3(0,size.y+.28,0)+front*size.z*.28,Vector3(size.x*.38,.4,.35),color,angle)
		block(pos+right*size.x*.28+Vector3(0,size.y+.65,0),Vector3(.14,.45,.18),"a98b71",angle)
	var floors=maxi(1,int(size.y/.75))
	for floor_index in floors:
		for side in [-1,1]:
			var window=pos+front*(size.z*.5+.025)+right*(size.x*.25*side)+Vector3(0,.48+floor_index*.7,0)
			block(window,Vector3(size.x*.19,.24,.035),"35535a",angle)
	block(pos+front*(size.z*.5+.035)+Vector3(0,.22,0),Vector3(size.x*.24,.44,.045),"60483a",angle)

func tree(pos: Vector3, scale_value: float=1) -> void:
	piece(trunk,pos+Vector3(0,.65*scale_value,0),Vector3(scale_value,1.3*scale_value,scale_value),"67543c")
	var foliage=["466634","58743a","344f32","718346"]
	var shade=foliage[rng.randi_range(0,3)]
	# Turned by position, not by the generator, so the map layout stays as it was.
	var turn=fposmod(pos.x*12.9898+pos.z*78.233,TAU)
	if rng.randf()<.35:
		piece(pine,pos+Vector3(0,2.3*scale_value,0),Vector3(.95,3.3,.95)*scale_value,shade,turn)
	else:
		piece(crown,pos+Vector3(0,1.9*scale_value,0),Vector3(2.1,1.8,1.9)*scale_value,shade,rng.randf()*TAU)
		piece(crown,pos+Vector3(.45,2.4,.12)*scale_value,Vector3(1.5,1.2,1.5)*scale_value,shade,turn)

func forest(points: Array) -> void:
	for point in points:
		var center=world.project(point[0],point[1])
		for i in 3:
			var pos=center+Vector3(rng.randf_range(-1.1,1.1),0,rng.randf_range(-1.1,1.1))
			if world.country_contains("NLD",pos):
				tree(pos,rng.randf_range(.7,1.3))

func town(pos: Vector3,name: String) -> void:
	var plan: Dictionary=city_plans.get(name,{})
	rng.seed=int(plan.get("seed",1206))
	# Real landmarks claim their ground first; generated plots there are skipped.
	var entries: Array=landmark_data.get(name,[])
	var clear: Array=[]
	for entry in entries:
		if entry.get("type")!="builtin":
			clear.append([Vector2(entry.at[0],entry.at[1]),LandmarkKit.footprint(entry)])
	neighbourhood(pos,plan,clear)
	match name:
		"Amsterdam": amsterdam(pos)
		"Rotterdam": rotterdam(pos)
		"Utrecht": utrecht(pos)
		"Den Haag": hague(pos)
		"Groningen": groningen(pos)
		"Arnhem": arch_bridge(pos,false)
		"Nijmegen": arch_bridge(pos,true)
		"Maastricht": maastricht(pos)
		"Almere": modern_centre(pos,false)
		"Lelystad": modern_centre(pos,true)
		"Leeuwarden": leaning_tower(pos)
		"Zwolle": star_centre(pos)
		"Breda": basilica(pos,"d6c8aa",false)
		"Delft": tower(pos+Vector3(0,0,-.3),"c3aa86",5.5)
		"Middelburg": town_hall(pos)
		"Sneek": water_gate(pos)
		"Eindhoven": factory(pos)
		_:
			if covers(clear,Vector2.ZERO,1.2):
				pass # A landmark already stands on the square.
			elif plan.get("kind")=="port":
				small_harbour(pos)
			elif plan.get("kind")=="green":
				for i in 5:
					tree(pos+Vector3(cos(i*1.25)*1.0,0,sin(i*1.25)*1.0),.65)
			else:
				town_square(pos,plan)
	var built=0
	for entry in entries:
		if entry.get("type")!="builtin":
			kit.build(pos+Vector3(entry.at[0],0,entry.at[1]),entry)
			built+=1
	landmark_built[name]=built
	landmarks[name]=true
	city_stats[name]={"plots":plan.get("plots",[]).size(),"layout":hash(JSON.stringify(plan.get("plots",[]))),"kind":plan.get("kind","")}

func covers(clear: Array,point: Vector2,margin: float) -> bool:
	for zone in clear:
		if point.distance_to(zone[0])<zone[1]+margin:
			return true
	return false

func neighbourhood(pos: Vector3,plan: Dictionary,clear: Array=[]) -> void:
	var ground_color="b8b6a0" if plan.get("kind") in ["modern","industrial","port"] else "c4b899"
	if not surfaces.has(ground_color):
		var ground=SurfaceTool.new()
		ground.begin(Mesh.PRIMITIVE_TRIANGLES)
		surfaces[ground_color]=ground
	var ground: SurfaceTool=surfaces[ground_color]
	for polygon in plan.get("blocks",[]):
		var points=PackedVector2Array()
		for point in polygon:
			points.append(Vector2(point[0],point[1]))
		var indices=Geometry2D.triangulate_polygon(points)
		for index in range(0,indices.size(),3):
			var a=points[indices[index]]
			var b=points[indices[index+1]]
			var c=points[indices[index+2]]
			for point in ([a,c,b] if (b-a).cross(c-a)>0 else [a,b,c]):
				ground.set_normal(Vector3.UP)
				ground.add_vertex(pos+Vector3(point.x,.055,point.y))
	for street in plan.get("streets",[]):
		for i in range(street.size()-1):
			var a=pos+Vector3(street[i][0],.09,street[i][1])
			var b=pos+Vector3(street[i+1][0],.09,street[i+1][1])
			ribbon(a,b,.12,"9d9f91")
	var historic=["a27054","d7c6a0","c39770","e0d3b4","9d735d"]
	var modern=["9dada9","c8c4b5","ab795b","d9d4ba","758a8d"]
	var colors=modern if plan.get("kind") in ["modern","industrial","port"] else historic
	var plot_index=0
	for plot in plan.get("plots",[]):
		if covers(clear,Vector2(plot[0],plot[1]),max(plot[2],plot[3])*.5):
			plot_index+=1
			continue
		var at=pos+Vector3(plot[0],.06,plot[1])
		var roof_color="687575" if int(plot[6])==2 else ["a95f3e","746550","594f4c"][plot_index%3]
		house(at,Vector3(plot[2],plot[4],plot[3]),colors[plot_index%colors.size()],roof_color,plot[5],int(plot[6]))
		if plot_index%7==0:
			tree(at+Vector3(.6,0,.6),.4)
		plot_index+=1

func town_square(pos: Vector3,plan: Dictionary) -> void:
	var angle=float(plan.get("angle",0))
	block(pos+Vector3(0,.06,0),Vector3(1.8,.05,1.4),"cbbb9b",angle)
	house(pos+Vector3(0,0,-.7),Vector3(1.25,1.35,.7),"d3b992","766654",angle,1)
	for x in [-1.0,1.0]:
		tree(pos+Vector3(x,0,.7),.45)

func hague(pos: Vector3) -> void:
	# Hofvijver and courtyard contrast with a small modern skyline.
	block(pos+Vector3(0,.11,-1.8),Vector3(5.5,.12,2.2),"318c9a")
	for x in [-1.8,0,1.8]:
		house(pos+Vector3(x,0,.2),Vector3(1.5,1.45,1.1),"bc9c75","64594c",0,0)
	for x in [-2.4,2.4]:
		house(pos+Vector3(x,0,1.5),Vector3(.8,1.2,2.6),"c5ab85","64594c",0,0)
	for i in 3:
		var at=pos+Vector3(2.5+i*.8,0,3.2)
		var h=2.6+i*.55
		house(at,Vector3(.65,h,.7),["8a8980","a97f62","7c9394"][i],"576a6f",0,2)

func groningen(pos: Vector3) -> void:
	block(pos+Vector3(-.6,.07,.4),Vector3(3.4,.08,2.6),"c6b58e")
	tower(pos+Vector3(.7,0,-.8),"ba9b72",5.5)
	house(pos+Vector3(-1,0,-1.2),Vector3(1.3,1.7,1.1),"d9c8aa","65706b",0,1)
	for i in 3:
		house(pos+Vector3(-1.7+i*.9,0,1.9),Vector3(.65,1.2+i*.2,.8),"b88763","a45d41",0,1)

func arch_bridge(pos: Vector3,double_span: bool) -> void:
	# Distinct miniature steel arch silhouettes for Arnhem and Nijmegen.
	var length=7.5 if double_span else 5.6
	block(pos+Vector3(0,.1,0),Vector3(1.7,.12,length+2),"318c9a")
	block(pos+Vector3(0,.6,0),Vector3(length,.25,.8),"9baca8")
	var spans=2 if double_span else 1
	var span_length=length/spans
	for span in spans:
		for z in [-.43,.43]:
			var previous=Vector3.ZERO
			for i in 13:
				var t=float(i)/12
				var at=pos+Vector3(-length*.5+span*span_length+t*span_length,.8+sin(t*PI)*(1.55 if double_span else 1.7),z)
				if i>0:
					beam(previous,at,.11,"c8d1c0")
				if i%2==0:
					beam(at,Vector3(at.x,.7,at.z),.055,"91a6a0")
				previous=at

func maastricht(pos: Vector3) -> void:
	block(pos+Vector3(0,.1,0),Vector3(1.2,.12,7),"318c9a")
	block(pos+Vector3(0,.8,0),Vector3(5.5,.24,.8),"c4b18f")
	for x in [-2.3,-1.5,-.7,.1,.9,1.7,2.5]:
		block(pos+Vector3(x,.4,0),Vector3(.22,.8,.65),"b5a17e")
	basilica(pos+Vector3(-2.3,0,-1.5),"b79c7c",true)
	for i in 4:
		house(pos+Vector3(1.5+i*.6,0,1.5),Vector3(.5,1.0+i*.15,.8),"c5ac8b","a76142",0,0)

func modern_centre(pos: Vector3,harbour: bool) -> void:
	block(pos+Vector3(0,.07,0),Vector3(4,.08,3),"c3c0ad")
	for i in 5:
		var at=pos+Vector3(-1.6+(i%3)*1.3,0,-1+(i/3)*1.7)
		house(at,Vector3(.8,1.2+(i%3)*.8,1.0),["adb9b1","b48866","829c9d"][i%3],"5b7274",.15 if i%2 else 0,2)
	if harbour:
		small_harbour(pos+Vector3(-2,0,2))
	else:
		block(pos+Vector3(0,.1,2.2),Vector3(5,.1,.6),"318c9a")

func leaning_tower(pos: Vector3) -> void:
	# Oldehove: broad, unfinished and visibly leaning rather than a generic spire.
	var basis=Basis(Vector3.FORWARD,.075)
	var transform_value=Transform3D(basis,pos+Vector3(0,1.9,0))
	var color="b69b7c"
	if not surfaces.has(color):
		var surface=SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surfaces[color]=surface
	surfaces[color].append_from(box,0,transform_value*Transform3D(Basis.from_scale(Vector3(1.5,3.8,1.4)),Vector3.ZERO))
	block(pos+Vector3(.14,3.9,0),Vector3(1.6,.18,1.5),"8b806c")

func star_centre(pos: Vector3) -> void:
	var previous=Vector3.ZERO
	for i in 17:
		var a=TAU*float(i)/16
		var radius=2.3 if i%2==0 else 1.7
		var at=pos+Vector3(cos(a)*radius,.12,sin(a)*radius)
		if i>0:
			beam(previous,at,.3,"318c9a")
		previous=at
	tower(pos,"c4ad86",4.3)

func basilica(pos: Vector3,color: String,twin: bool) -> void:
	house(pos+Vector3(0,0,-.6),Vector3(1.5,1.6,2.8),color,"59665f",0,0)
	for x in ([-.65,.65] if twin else [0.0]):
		tower(pos+Vector3(x,0,.9),color,3.4 if twin else 5.1)

func town_hall(pos: Vector3) -> void:
	house(pos,Vector3(2.5,1.6,1.4),"c9b391","a65f42",0,1)
	for x in [-1.1,0.0,1.1]:
		tower(pos+Vector3(x,0,-.1),"c9b391",2.4 if x else 4.1)

func water_gate(pos: Vector3) -> void:
	block(pos+Vector3(0,.11,0),Vector3(.7,.12,6),"318c9a")
	for x in [-.8,.8]:
		tower(pos+Vector3(x,0,0),"ae8f6b",2.4)
	beam(pos+Vector3(-.8,1.2,0),pos+Vector3(.8,1.2,0),.6,"c6ad84")

func factory(pos: Vector3) -> void:
	house(pos+Vector3(0,0,-.4),Vector3(3.2,1.15,1.7),"ac775b","637676",0,2)
	for x in [-1.3,-.5,.3,1.1]:
		block(pos+Vector3(x,1.1,.48),Vector3(.45,.55,.03),"71979b")
	piece(trunk,pos+Vector3(1.8,1.8,-.8),Vector3(1.7,3.6,1.7),"a5765c")

func small_harbour(pos: Vector3) -> void:
	block(pos+Vector3(0,.1,.8),Vector3(3.5,.1,1.3),"318c9a")
	block(pos+Vector3(-.7,.32,.8),Vector3(2,.45,.5),"405d65")
	block(pos+Vector3(-1.2,.65,.8),Vector3(.4,.4,.45),"e0d0aa")
	beam(pos+Vector3(1.5,0,-.2),pos+Vector3(1.5,2.4,-.2),.13,"c3a35d")
	beam(pos+Vector3(1.5,2.4,-.2),pos+Vector3(1.5,2.4,1.7),.12,"c3a35d")

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
			ribbon(last,next,.5,"318c9a")
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
	# The kit points back at this scenery; drop it so the RefCounted cycle
	# does not keep every material alive after the world is freed.
	kit=null
	# One draw surface per palette colour rather than one node per window/tree.
	for color in surfaces:
		var node=MeshInstance3D.new()
		node.name="DutchScenery_"+color
		node.mesh=surfaces[color].commit()
		node.material_override=material(color)
		world.add_child(node)
