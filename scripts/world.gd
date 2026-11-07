class_name TopoWorld
extends Node3D

var region: String = "nl"
var map_data: Dictionary = {}
var geo_scale: float = 85.0
var origin: Vector2 = Vector2(5.3,52.2)
var bounds: Rect2
var labels: Array[Label3D] = []
var label_names: Dictionary = {}
var marker_labels: Dictionary = {}
var hints_enabled: bool = false
var europe_scenery: EuropeScenery
var dutch_scenery: DutchScenery
var water_material: ShaderMaterial
var target: Node3D
var helipads: Dictionary = {}
var country_polys: Dictionary = {}
# Bounding boxes per country polygon, so land checks skip far-away outlines.
var country_boxes: Dictionary = {}
# Full outlines of the neighbouring countries for the 2D maps (minimap and
# locator card). The Dutch map file clips them to its own extent, which reads
# as grey slabs once a map shows more than that rectangle.
var neighbour_polys: Dictionary = {}
const NEIGHBOURS = ["BEL","DEU","FRA","LUX","GBR"]
# Muted land for the neighbours so the Netherlands stays the brightest shape.
const NEIGHBOUR_LAND = Color("838e76")
var lake_polys: Array = []
var boundary_data: Dictionary = {}
var boundary_paths: Dictionary = {}
var province_regions: Array = []
var municipal_boundary: MeshInstance3D
var rng = RandomNumberGenerator.new()
var material_cache: Dictionary = {}
var label_font: Font

# Natural Earth's default admin_0 layer follows de-facto control. Dutch school
# topography (and the Dutch government position) counts these areas as part of
# the country below, so the land check uses that assignment.
const COUNTRY_MERGE = {"CYN":"CYP","ALD":"FIN"}
const KIND_INK = {"stad":Color("153c48"),"eigen punt":Color("153c48"),"water":Color("135d8c"),"gebied":Color("7a4b22"),"eiland":Color("2d6a36"),"land":Color("5b2f61"),"provincie":Color("5b2f61")}

# Map files are the single source of truth for region extents: [min_lon,min_lat,max_lon,max_lat].
static func map_bounds(map_region: String) -> Array:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/map_%s.json" % map_region))
	return data.bounds if data is Dictionary and data.get("bounds") is Array else []

static func in_bounds(b: Array, lat: float, lon: float) -> bool:
	return b.size()==4 and lon>=b[0] and lon<=b[2] and lat>=b[1] and lat<=b[3]

func project(lon: float, lat: float) -> Vector3:
	return Vector3((lon-origin.x)*cos(deg_to_rad(origin.y))*geo_scale,0,-(lat-origin.y)*geo_scale)

func unproject(p: Vector3) -> Vector2:
	return Vector2(p.x/(cos(deg_to_rad(origin.y))*geo_scale)+origin.x,origin.y-p.z/geo_scale)

func mat(color: Color, unshaded: bool = false, cull_disabled: bool = false) -> StandardMaterial3D:
	var key = "%s|%s|%s" % [color.to_html(), unshaded, cull_disabled]
	if material_cache.has(key):
		return material_cache[key]
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if cull_disabled:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_cache[key] = m
	return m

func build(new_region: String, catalog: TopoCatalog) -> void:
	region = new_region
	geo_scale = 85.0 if region == "nl" else 14.0
	origin = Vector2(5.3,52.2) if region == "nl" else Vector2(10.5,49.0)
	map_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/map_%s.json" % region))
	var b = map_data.bounds
	var a = project(b[0],b[3])
	var z = project(b[2],b[1])
	bounds = Rect2(Vector2(a.x,a.z),Vector2(z.x-a.x,z.z-a.z))
	var sea = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(bounds.size.x+800,2,bounds.size.y+800)
	sea.mesh = box_mesh
	sea.position = Vector3(bounds.get_center().x,-1.8,bounds.get_center().y)
	sea.material_override = mat(Color("286375"),true)
	if region in ["nl","eu"]:
		water_material = ShaderMaterial.new()
		water_material.shader = load("res://assets/shaders/water.gdshader")
		sea.material_override = water_material
	add_child(sea)
	var colors = [Color("94b68a"),Color("a7b998"),Color("b3bea0"),Color("8eae87"),Color("bac4a1")] if region == "nl" else [Color("84b494"),Color("93b89b"),Color("a4c2a0"),Color("7da98d"),Color("b0c59f")]
	var index = 0
	# Segments shared by two countries are land borders: they get no beach
	# or shelf line (those read as white and cyan stripes inside the land).
	var file_borders = shared_segments(map_data.countries)
	for country in map_data.countries:
		var rings: Array = []
		for polygon in country.polygons:
			var ring = PackedVector2Array()
			for p in polygon:
				var v = project(p[0],p[1])
				ring.append(Vector2(v.x,v.z))
			if ring.size()>3 and ring[0].is_equal_approx(ring[-1]):
				ring.remove_at(ring.size()-1)
			rings.append(ring)
			var neighbour = region == "nl" and country.code != "NLD"
			land_polygon(ring,NEIGHBOUR_LAND if neighbour else colors[index%colors.size()],0)
			if region == "nl":
				# Edges along the map file's rectangle are a cut, not a coast.
				for run in coast_runs(ring,func(a,b): return not (on_bounds_edge(a) and on_bounds_edge(b)) and not file_borders.has(segment_key(a,b))):
					coast_wall(run,false)
					line(run,Color("517f7e"),-.67,2.2)
					line(run,Color("d9d7ad"),.045,.32)
			else:
				line(ring,Color("d7d5a9"),.16,.55,true)
		var code = COUNTRY_MERGE.get(country.code,country.code)
		if not country_polys.has(code):
			country_polys[code] = []
		country_polys[code].append_array(rings)
		index += 1
	if region == "eu":
		reassign_crimea()
	neighbour_polys = {}
	if region == "nl":
		load_neighbours()
		build_neighbour_land()
	if region == "nl":
		dutch_scenery=DutchScenery.new(self)
		dutch_scenery.landscape()
	build_landscape_detail()
	for lake in map_data.lakes:
		var ring = PackedVector2Array()
		for p in lake:
			var v = project(p[0],p[1])
			ring.append(Vector2(v.x,v.z))
		if ring.size()>3 and ring[0].is_equal_approx(ring[-1]):
			ring.remove_at(ring.size()-1)
		lake_polys.append(ring)
		land_polygon(ring,Color("377f94"),.08)
	for river in map_data.rivers:
		var points = PackedVector2Array()
		for p in river:
			var v = project(p[0],p[1])
			points.append(Vector2(v.x,v.z))
		if region == "nl":
			line(points,Color("c1c9ac"),.09,1.0)
		line(points,Color("377f94"),.12,.65 if region=="nl" else .38)
	if region=="eu":
		europe_scenery=EuropeScenery.new(self)
		for p in catalog.places:
			if p.kind == "stad" and (p.region == "eu" or p.name == "Amsterdam"):
				var anchor = project(p.lon,p.lat)
				europe_scenery.city_anchors.append(Vector2(anchor.x,anchor.z))
		europe_scenery.landscape()
	rng.seed = 1206
	for p in catalog.places:
		if (region == "nl" and p.region != "nl") or (region == "eu" and p.region == "nl" and p.name != "Amsterdam") :
			continue
		add_place_marker(p)
	if region=="nl":
		dutch_scenery.bake()
		build_boundaries()
	if region=="eu":
		europe_scenery.bake()
	# The goal's visuals (range circle, beacon) come from FlightFx; this node
	# carries the position and the visibility decided by the game mode.
	target = Node3D.new()
	add_child(target)
	target.visible = false

func land_polygon(points: PackedVector2Array, color: Color, y: float) -> void:
	if points.size()<3:
		return
	var indices = Geometry2D.triangulate_polygon(points)
	if indices.is_empty():
		return
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0,indices.size(),3):
		var a = points[indices[i]]
		var b = points[indices[i+1]]
		var c = points[indices[i+2]]
		var cross_value = (b-a).cross(c-a)
		var tri = [a,c,b] if cross_value>0 else [a,b,c]
		for p in tri:
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(p.x,y,p.y))
	var mesh = MeshInstance3D.new()
	mesh.mesh = st.commit()
	var land_mat = mat(color,false,true)
	mesh.material_override = water_material if color == Color("377f94") else land_mat
	add_child(mesh)

func line(points: PackedVector2Array,color: Color,y: float,width: float,closed: bool=false) -> void:
	if points.size()<2:
		return
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count = points.size() if closed else points.size()-1
	for i in count:
		var a = points[i]
		var b = points[(i+1)%points.size()]
		var normal = (b-a).normalized().orthogonal()*width*.5
		for p in [a-normal,a+normal,b+normal,a-normal,b+normal,b-normal]:
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(p.x,y,p.y))
	var mesh = MeshInstance3D.new()
	mesh.mesh = st.commit()
	var m = mat(color,false,true)
	mesh.material_override = m
	add_child(mesh)

func coast_wall(points: PackedVector2Array,closed: bool=true,top: float=0.0) -> void:
	if points.size()<2:
		return
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in (points.size() if closed else points.size()-1):
		var a = Vector3(points[i].x,top,points[i].y)
		var b = Vector3(points[(i+1)%points.size()].x,top,points[(i+1)%points.size()].y)
		var down = Vector3(0,-.95,0)
		for v in [a,b,b+down,a,b+down,a+down]:
			st.add_vertex(v)
	st.generate_normals()
	var mesh = MeshInstance3D.new()
	mesh.mesh = st.commit()
	mesh.material_override = mat(Color("b3b28a"),false,true)
	add_child(mesh)

func make_city(pos: Vector3,place_name: String="") -> void:
	if region == "nl":
		dutch_scenery.town(pos,place_name)
		return
	europe_scenery.town(pos,place_name)

func make_pad(pos: Vector3,place_name: String) -> void:
	var node = Node3D.new()
	node.position = pos+Vector3(0,.2,0)
	add_child(node)
	var disk = MeshInstance3D.new()
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = 2.1
	cylinder.bottom_radius = 2.1
	cylinder.height = .06
	disk.mesh = cylinder
	disk.material_override = mat(Color("386b65"))
	node.add_child(disk)
	var h = Label3D.new()
	h.text="H"
	h.font_size=64
	h.pixel_size=.035
	h.rotation_degrees.x=-90
	h.position.y=.07
	h.modulate=Color("f2e9ba")
	node.add_child(h)
	helipads[place_name]=node

func mountain(pos: Vector3) -> void:
	for i in 7:
		var peak = MeshInstance3D.new()
		var cone = CylinderMesh.new()
		cone.top_radius = 0
		cone.bottom_radius = rng.randf_range(3,7)
		cone.height = rng.randf_range(4,10)
		cone.radial_segments = 5
		peak.mesh = cone
		peak.position = pos+Vector3(i*3.2,cone.height/2,rng.randf_range(-4,4))
		peak.material_override = mat(Color("98a99f"))
		add_child(peak)

func set_hints(enabled: bool) -> void:
	hints_enabled = enabled
	for label in labels:
		label.visible = enabled

func reassign_crimea() -> void:
	# The Crimean peninsula is a separate ring inside the RUS polygons; count it as Ukraine.
	var probe = project(34.1,44.95)
	var point = Vector2(probe.x,probe.z)
	var rus: Array = country_polys.get("RUS",[])
	for i in range(rus.size()-1,-1,-1):
		if Geometry2D.is_point_in_polygon(point,rus[i]):
			if not country_polys.has("UKR"):
				country_polys["UKR"] = []
			country_polys["UKR"].append(rus[i])
			rus.remove_at(i)
	country_boxes.clear()

# Neighbour outlines from the Europe map, in this map's projection. 2D only:
# the 3D landscape keeps the detailed, clipped Dutch map.
func load_neighbours() -> void:
	var europe = JSON.parse_string(FileAccess.get_file_as_string("res://data/map_eu.json"))
	if not europe is Dictionary or not europe.get("countries") is Array:
		return
	for country in europe.countries:
		if not country.get("code","") in NEIGHBOURS:
			continue
		var rings: Array = []
		for polygon in country.polygons:
			var ring = PackedVector2Array()
			for p in polygon:
				var v = project(p[0],p[1])
				ring.append(Vector2(v.x,v.z))
			if ring.size()>3 and ring[0].is_equal_approx(ring[-1]):
				ring.remove_at(ring.size()-1)
			if ring.size()>2:
				rings.append(ring)
		neighbour_polys[country.code] = rings

# Germany, Belgium, France and the UK continue past the Dutch map file, so
# the hangar and overview no longer end in a grey rectangle. They sit just
# next to the clipped (more detailed) shapes, which cover the rectangle;
# coasts are only added outside it so no cliff is drawn twice.
func build_neighbour_land() -> void:
	var frame=PackedVector2Array([bounds.position,Vector2(bounds.end.x,bounds.position.y),bounds.end,Vector2(bounds.position.x,bounds.end.y)])
	var borders: Dictionary = {}
	for code in neighbour_polys:
		for ring in neighbour_polys[code]:
			for i in ring.size():
				var key=segment_key(ring[i],ring[(i+1)%ring.size()])
				borders[key]=borders.get(key,0)+1
	for code in neighbour_polys:
		for ring in neighbour_polys[code]:
			# Only the part outside the map rectangle: inside it the clipped,
			# detailed shapes already exist, so both meet at ground level.
			for part in Geometry2D.clip_polygons(ring,frame):
				if not Geometry2D.is_polygon_clockwise(part) or part.size()<3:
					land_polygon(part,NEIGHBOUR_LAND,0)
			for run in coast_runs(ring,func(a,b): return not bounds.has_point(a) and not bounds.has_point(b) and borders.get(segment_key(a,b),0)<2):
				# The Europe file does not tell coast from land border, so no
				# cliff or beach line here: on a border they show as light
				# stripes. The shallow-water band only shows along the sea.
				line(run,Color("517f7e"),-.67,2.2)

func segment_key(a: Vector2,b: Vector2) -> String:
	var first="%.2f,%.2f" % [a.x,a.y]
	var second="%.2f,%.2f" % [b.x,b.y]
	return first+"|"+second if first<second else second+"|"+first

# Projected segments that occur in more than one ring of a map file.
func shared_segments(countries: Array) -> Dictionary:
	var count: Dictionary = {}
	for country in countries:
		for polygon in country.polygons:
			var ring=PackedVector2Array()
			for point in polygon:
				var v=project(point[0],point[1])
				ring.append(Vector2(v.x,v.z))
			for i in ring.size():
				var key=segment_key(ring[i],ring[(i+1)%ring.size()])
				count[key]=count.get(key,0)+1
	var shared: Dictionary = {}
	for key in count:
		if count[key]>1:
			shared[key]=true
	return shared

# The map file was simplified after clipping, so cut edges wander up to
# ~0.01 degrees from the rectangle; one world unit covers that.
func on_bounds_edge(p: Vector2) -> bool:
	var e=1.0
	return absf(p.x-bounds.position.x)<e or absf(p.x-bounds.end.x)<e or absf(p.y-bounds.position.y)<e or absf(p.y-bounds.end.y)<e

# Open runs of a closed ring made of the segments that keep(a, b) accepts.
func coast_runs(ring: PackedVector2Array,keep: Callable) -> Array:
	var n=ring.size()
	var runs: Array=[]
	if n<2:
		return runs
	var start=-1
	for i in n:
		if not keep.call(ring[i],ring[(i+1)%n]):
			start=i
			break
	if start<0:
		var closed=ring.duplicate()
		closed.append(ring[0])
		return [closed]
	var current=PackedVector2Array()
	for k in n:
		var i=(start+1+k)%n
		var a=ring[i]
		var b=ring[(i+1)%n]
		if keep.call(a,b):
			if current.is_empty():
				current.append(a)
			current.append(b)
		elif current.size()>1:
			runs.append(current)
			current=PackedVector2Array()
		else:
			current=PackedVector2Array()
	if current.size()>1:
		runs.append(current)
	return runs

func country_at(position3: Vector3) -> String:
	for code in country_polys:
		if country_contains(code,position3):
			return code
	return ""

func has_country(code: String) -> bool:
	return not country_polys.get(code,[]).is_empty()

func country_contains(code: String, position3: Vector3) -> bool:
	var polygons: Array = country_polys.get(code,[])
	if polygons.is_empty():
		return false
	if not country_boxes.has(code):
		var boxes: Array = []
		for polygon in polygons:
			var box := Rect2(polygon[0],Vector2.ZERO)
			for point in polygon:
				box = box.expand(point)
			boxes.append(box)
		country_boxes[code] = boxes
	var point := Vector2(position3.x,position3.z)
	var boxes: Array = country_boxes[code]
	for i in polygons.size():
		if boxes[i].has_point(point) and Geometry2D.is_point_in_polygon(point,polygons[i]):
			return true
	return false

func build_landscape_detail() -> void:
	if map_data.has("fields"):
		var st=SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var tones=[Color("a3b45c"),Color("aebb68"),Color("a7b864"),Color("bdc67a"),Color("c8bd76"),Color("94aa58"),Color("b1bd68")] if region == "nl" else [Color("7fad87"),Color("91b28c"),Color("8caf8a"),Color("9ab893"),Color("a5bb8f"),Color("86ae89"),Color("90b794")]
		for field in map_data.fields:
			var points=PackedVector2Array()
			for p in field.polygon:
				var v=project(p[0],p[1])
				points.append(Vector2(v.x,v.z))
			if points.size()>3 and points[0].is_equal_approx(points[-1]):
				points.remove_at(points.size()-1)
			var indices=Geometry2D.triangulate_polygon(points)
			for index in indices:
				st.set_color(tones[int(field.tone)].srgb_to_linear() if region == "nl" else tones[int(field.tone)])
				st.set_normal(Vector3.UP)
				st.add_vertex(Vector3(points[index].x,.025,points[index].y))
		var mesh=MeshInstance3D.new()
		mesh.mesh=st.commit()
		var m=StandardMaterial3D.new()
		m.albedo_color=Color.WHITE
		m.roughness=1.0
		if region != "nl":
			m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		m.vertex_color_is_srgb=false
		m.vertex_color_use_as_albedo=true
		m.cull_mode=BaseMaterial3D.CULL_DISABLED
		mesh.material_override=m
		add_child(mesh)
	if map_data.has("trees") and region == "nl":
		dutch_scenery.forest(map_data.trees)
	elif map_data.has("trees"):
		var crowns=MultiMeshInstance3D.new()
		var multi=MultiMesh.new()
		multi.transform_format=MultiMesh.TRANSFORM_3D
		var cone=CylinderMesh.new()
		cone.top_radius=0
		cone.bottom_radius=.65
		cone.height=2.7
		cone.radial_segments=5
		multi.mesh=cone
		multi.instance_count=map_data.trees.size()
		var i=0
		for point in map_data.trees:
			var pos=project(point[0],point[1])+Vector3(0,1.35,0)
			multi.set_instance_transform(i,Transform3D(Basis.IDENTITY,pos))
			i+=1
		crowns.multimesh=multi
		crowns.material_override=mat(Color("416f58"),region != "nl")
		add_child(crowns)

func ensure_mission_markers(places: Array) -> void:
	for place in places:
		add_place_marker(place,false)

func add_place_marker(p: Dictionary,with_scenery: bool = true) -> void:
	if label_names.has(p.name):
		if p.kind == "eigen punt" and marker_labels.has(p.name):
			marker_labels[p.name].position = project(p.lon,p.lat)+Vector3(0,3.8,0)
		return
	label_names[p.name]=true
	var pos = project(p.lon,p.lat)
	if with_scenery and p.kind == "stad":
		make_city(pos,p.name)
		make_pad(pos,p.name)
	var label = Label3D.new()
	label.text = p.name
	label.position = pos+Vector3(0,3.8 if region=="nl" else 2.1,0)
	if label_font == null:
		label_font = UiFonts.font("black")
	label.font = label_font
	label.font_size = 36 if p.kind == "stad" else 30
	label.pixel_size = .035 if region=="nl" else .06
	# Colour by kind, like a school atlas: water blue, relief brown, islands green.
	label.modulate = KIND_INK.get(p.kind,Color("2b5b63"))
	label.outline_modulate = Color("f6f2d7")
	label.outline_size = 4 if region=="nl" else 8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	add_child(label)
	label.set_meta("kind",p.kind)
	marker_labels[p.name]=label
	labels.append(label)

func refresh_labels(focus: Vector3, overview: bool, view_size: float=46.0) -> void:
	if region=="eu":
		for marker in labels:
			var distance=Vector2(marker.position.x-focus.x,marker.position.z-focus.z).length()
			marker.pixel_size=.045*clampf(view_size/95.0,.6,2.0)
			marker.visible=hints_enabled and (distance<60.0*maxf(1.0,view_size/95.0) or overview and marker.get_meta("kind","")=="land")
		return
	# Limit visible names spatially, without sorting every frame. Higher
	# flight sees further, so names reach further too.
	var reach=maxf(1.0,view_size/46.0)
	for marker in labels:
		marker.pixel_size=.035*clampf(view_size/46.0,.4,2.0)
		var distance = Vector2(marker.position.x-focus.x,marker.position.z-focus.z).length()
		var is_city = marker.get_meta("kind","") in ["stad","eigen punt"]
		marker.visible = hints_enabled and (distance < (32.0 if is_city else 18.0)*reach)
		if overview:
			marker.visible = hints_enabled and is_city and marker.text in ["Amsterdam","Rotterdam","Den Haag","Utrecht","Arnhem","Groningen","Maastricht","Leeuwarden","Zwolle"]

func lake_contains(position3: Vector3) -> bool:
	for polygon in lake_polys:
		if Geometry2D.is_point_in_polygon(Vector2(position3.x,position3.z),polygon):
			return true
	return false

func build_boundaries() -> void:
	boundary_data=JSON.parse_string(FileAccess.get_file_as_string("res://data/boundaries_nl.json"))
	for level in boundary_data.lines:
		var paths: Array=[]
		for source in boundary_data.lines[level]:
			var path=PackedVector2Array()
			for geo in source:
				var point=project(geo[0],geo[1])
				path.append(Vector2(point.x,point.z))
			paths.append(path)
		boundary_paths[level]=paths
	for province in boundary_data.provinces:
		var polygons: Array=[]
		for source in province.polygons:
			var polygon=PackedVector2Array()
			for geo in source:
				var point=project(geo[0],geo[1])
				polygon.append(Vector2(point.x,point.z))
			if polygon.size()>3 and polygon[0].is_equal_approx(polygon[-1]):
				polygon.remove_at(polygon.size()-1)
			polygons.append(polygon)
		province_regions.append({"code":province.code,"name":province.name,"polygons":polygons})
	# Neutral strokes only on the real landscape. Coloured fills belong to the minimap.
	municipal_boundary=boundary_mesh(boundary_paths.municipal,.035,.18,.24,.18)
	boundary_mesh(boundary_paths.provincial,.085,.19,1.0,.45)
	boundary_mesh(boundary_paths.national,.15,.2,0,0)

func boundary_mesh(paths: Array,width: float,height: float,dash: float,gap: float) -> MeshInstance3D:
	var surface=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for path in paths:
		var walked=0.0
		for i in range(path.size()-1):
			var a: Vector2=path[i]
			var b: Vector2=path[i+1]
			var length=a.distance_to(b)
			if length<.00001:
				continue
			var direction=(b-a)/length
			var normal=direction.orthogonal()*width*.5
			var offset=0.0
			while offset<length-.00001:
				var advance=length-offset
				var visible=true
				if dash>0:
					var phase=fposmod(walked+offset,dash+gap)
					visible=phase<dash
					advance=minf(advance,(dash if visible else dash+gap)-phase)
				advance=maxf(advance,.00001)
				if visible:
					var start=a+direction*offset
					var finish=a+direction*minf(offset+advance,length)
					for point in [start-normal,start+normal,finish+normal,start-normal,finish+normal,finish-normal]:
						surface.set_normal(Vector3.UP)
						surface.add_vertex(Vector3(point.x,height,point.y))
				offset+=advance
			walked+=length
	var node=MeshInstance3D.new()
	node.mesh=surface.commit()
	node.material_override=mat(Color("566056"),true,true)
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node

func set_boundary_detail(view_size: float) -> void:
	if is_instance_valid(municipal_boundary):
		# Laag and Midden (zoom 38 and 64) show municipalities, Hoog stays calm.
		municipal_boundary.visible=view_size<=70.0

# Catalog names that differ from the official province name in boundaries_nl.json.
const PROVINCE_NAMES = {"Friesland":"Fryslân"}

# The boundary name for a catalog province ("Utrecht provincie" -> "Utrecht").
static func province_name_for(place: Dictionary) -> String:
	var name=String(place.get("name","")).trim_suffix(" provincie")
	return PROVINCE_NAMES.get(name,name)

func has_province(place: Dictionary) -> bool:
	if place.get("kind","")!="provincie":
		return false
	var name=province_name_for(place)
	for province in province_regions:
		if province.name==name:
			return true
	return false

func province_contains(place: Dictionary,position3: Vector3) -> bool:
	var name=province_name_for(place)
	var point=Vector2(position3.x,position3.z)
	for province in province_regions:
		if province.name==name:
			for polygon in province.polygons:
				if Geometry2D.is_point_in_polygon(point,polygon):
					return true
	return false

func province_at(position3: Vector3) -> String:
	var point=Vector2(position3.x,position3.z)
	for province in province_regions:
		for polygon in province.polygons:
			if Geometry2D.is_point_in_polygon(point,polygon):
				return province.name
	return ""
