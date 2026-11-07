class_name FlightMinimap
extends Control

# Expensive boundary/area drawing stays on a cached background. Only aircraft
# and goal markers redraw each frame; local mode recentres after actual movement.
class NavigationOverlay:
	extends Control
	var minimap: FlightMinimap
	func _draw() -> void:
		minimap.draw_navigation(self)

const PROVINCE_COLORS = ["9bb99a","d3b785","9cabc9","b9a3bf","9bbfc1","c5bb83","c8a297","a9b98e","a2b4d3","d1b29b","b9afd0","8fb6a5"]
var world: TopoWorld:
	set(value):
		world=value
		local_view=false
		current_province=""
		province_sample=Vector2(INF,INF)
		queue_redraw()
var aircraft: Vector3 = Vector3.ZERO
var heading: float = 0.0
var goal: Vector3 = Vector3.ZERO
var goal_radius: float = 0.0
var show_goal: bool = false
var overlay: NavigationOverlay
var background_draws: int = 0
var local_view: bool = false
var cached_center: Vector2 = Vector2.ZERO
var view_bounds: Rect2
var current_province: String = ""
var province_sample: Vector2 = Vector2(INF,INF)

func _ready() -> void:
	clip_contents=true
	mouse_filter=Control.MOUSE_FILTER_STOP
	tooltip_text="Tik om te wisselen tussen Nederland en de omgeving. Kleuren gelden alleen voor de minikaart. Grenzen: Kadaster NL, CC BY 4.0."
	overlay=NavigationOverlay.new()
	overlay.minimap=self
	overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	resized.connect(queue_redraw)

func _gui_input(event: InputEvent) -> void:
	# Touch is emitted as a mouse click by the project input settings.
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		toggle_detail()
		accept_event()

func toggle_detail() -> void:
	if not is_instance_valid(world) or world.region!="nl":
		return
	local_view=not local_view
	queue_redraw()

func refresh_navigation() -> void:
	if is_instance_valid(world) and world.region=="nl" and province_sample.distance_to(Vector2(aircraft.x,aircraft.z))>1.0:
		current_province=world.province_at(aircraft)
		province_sample=Vector2(aircraft.x,aircraft.z)
	if local_view and cached_center.distance_to(Vector2(aircraft.x,aircraft.z))>2.0:
		queue_redraw()
	if is_instance_valid(overlay):
		overlay.queue_redraw()

func map_rect() -> Rect2:
	return Rect2(Vector2(12,12),size-Vector2(24,64 if world.region=="nl" else 24))

func map_point(p: Vector2) -> Vector2:
	var inset=map_rect()
	var scale_value=minf(inset.size.x/view_bounds.size.x,inset.size.y/view_bounds.size.y)
	return inset.get_center()+(p-view_bounds.get_center())*scale_value

func mapped(path: PackedVector2Array) -> PackedVector2Array:
	var points=PackedVector2Array()
	for point in path:
		points.append(map_point(point))
	return points

func fill_polygon(path: PackedVector2Array,color: Color) -> void:
	var points=mapped(path)
	if points.size()>2 and not Geometry2D.triangulate_polygon(points).is_empty():
		draw_colored_polygon(points,color)

func stroke(paths: Array,color: Color,width: float) -> void:
	for path in paths:
		if path.size()>1:
			draw_polyline(mapped(path),color,width,true)

func _draw() -> void:
	background_draws+=1
	var style=StyleBoxFlat.new()
	style.bg_color=Color("102f39")
	style.set_corner_radius_all(16)
	draw_style_box(style,Rect2(Vector2.ZERO,size))
	if not is_instance_valid(world):
		return
	cached_center=Vector2(aircraft.x,aircraft.z)
	view_bounds=world.bounds
	if local_view:
		var extent=world.bounds.size/3.8
		view_bounds=Rect2(cached_center-extent*.5,extent)
	var country_index=0
	for rings in world.country_polys.values():
		for ring in rings:
			fill_polygon(ring,Color(["596f72","737a64","696c80","7b726b"][country_index%4]))
		country_index+=1
	if world.region=="nl":
		var province_index=0
		for province in world.province_regions:
			for polygon in province.polygons:
				fill_polygon(polygon,Color(PROVINCE_COLORS[province_index%PROVINCE_COLORS.size()]))
			province_index+=1
		for lake in world.lake_polys:
			fill_polygon(lake,Color("255b71"))
		stroke(world.boundary_paths.get("municipal",[]),Color(.15,.28,.40,.75 if local_view else .32),.85 if local_view else .45)
		stroke(world.boundary_paths.get("provincial",[]),Color("f4eed9"),1.7 if local_view else 1.25)
		stroke(world.boundary_paths.get("national",[]),Color("f3c466"),2.2)
	else:
		for rings in world.country_polys.values():
			for ring in rings:
				var closed=ring.duplicate()
				closed.append(ring[0])
				stroke([closed],Color("efc46e"),1.2)
	# Mask geometry outside the map inset before adding its legend.
	var inset=map_rect()
	var mask=Color("102f39")
	draw_rect(Rect2(0,0,size.x,inset.position.y),mask)
	draw_rect(Rect2(0,inset.end.y,size.x,size.y-inset.end.y),mask)
	draw_rect(Rect2(0,0,inset.position.x,size.y),mask)
	draw_rect(Rect2(inset.end.x,0,size.x-inset.end.x,size.y),mask)
	if world.region=="nl":
		var y=size.y-39
		var x=12.0
		for item in [["Land","f3c466",50],["Provincie","f4eed9",75],["Gemeente","86adc2",0]]:
			draw_line(Vector2(x,y-3),Vector2(x+10,y-3),Color(item[1]),2)
			draw_string(ThemeDB.fallback_font,Vector2(x+14,y),item[0],HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("e7e7cf"))
			x+=item[2]
		draw_string(ThemeDB.fallback_font,Vector2(12,size.y-8),"Grenzen: Kadaster NL · CC BY 4.0",HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color("9cb4b5"))
	refresh_navigation()

func draw_navigation(canvas: Control) -> void:
	if not is_instance_valid(world) or view_bounds.size.x<=0:
		return
	var inset=map_rect()
	if world.region=="nl":
		var region_name=current_province if not current_province.is_empty() else "Nederland"
		var caption=region_name+(" · tik: NL" if local_view else " · tik: omgeving")
		canvas.draw_string(ThemeDB.fallback_font,Vector2(12,size.y-22),caption,HORIZONTAL_ALIGNMENT_LEFT,size.x-24,11,Color("dae3d6"))
	if show_goal:
		var goal_point=map_point(Vector2(goal.x,goal.z))
		if inset.has_point(goal_point):
			# The answer range as a ring, never smaller than a readable dot.
			var ring=maxf((map_point(Vector2(goal.x,goal.z)+Vector2(0,goal_radius))-goal_point).length(),7.0) if goal_radius>0 else 0.0
			if ring>0:
				canvas.draw_circle(goal_point,ring,Color(1,.76,.36,.18))
				canvas.draw_arc(goal_point,ring,0,TAU,32,Color("ffc35c"),1.5,true)
			canvas.draw_circle(goal_point,4,Color("ffc35c"))
	var pos=map_point(Vector2(aircraft.x,aircraft.z))
	if inset.has_point(pos):
		# The flight camera turns with the helicopter; the map stays north-up and
		# shows the nose direction instead.
		var nose=Vector2(-sin(heading),-cos(heading))
		var ahead=(map_point(Vector2(aircraft.x,aircraft.z)+nose*10.0)-pos).normalized()
		if ahead.is_zero_approx():
			ahead=Vector2.UP
		var side=ahead.orthogonal()
		canvas.draw_arc(pos,10,0,TAU,24,Color(.95,.95,.85,.55),1,true)
		canvas.draw_colored_polygon(PackedVector2Array([pos+ahead*9,pos-ahead*5+side*5.5,pos-ahead*2,pos-ahead*5-side*5.5]),Color("f2f3d8"))
	canvas.draw_string(ThemeDB.fallback_font,Vector2(size.x-28,24),"N",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("f1e9ca"))
