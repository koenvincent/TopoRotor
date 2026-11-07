class_name FlightMinimap
extends Control

# A round minimap with a compass bezel. Expensive boundary/area drawing stays
# on a cached map layer. Only aircraft, goal and compass markers redraw each
# frame; local mode recentres after actual movement. In heading-up mode the
# map layer is turned as a node (rotation around a pivot), so turning never
# redraws the geometry. A clipping square plus four corner masks make the
# map round on every renderer, including gl_compatibility on Android.
class MapLayer:
	extends Control
	var minimap: FlightMinimap
	func _draw() -> void:
		minimap.draw_geometry(self)

class FrameLayer:
	extends Control
	var minimap: FlightMinimap
	func _draw() -> void:
		minimap.draw_frame(self)

class NavigationOverlay:
	extends Control
	var minimap: FlightMinimap
	func _draw() -> void:
		minimap.draw_navigation(self)

signal rotation_mode_changed(rotating: bool)

const PROVINCE_COLORS = ["9bb99a","d3b785","9cabc9","b9a3bf","9bbfc1","c5bb83","c8a297","a9b98e","a2b4d3","d1b29b","b9afd0","8fb6a5"]
# Muted, distinct neighbours so the Netherlands stays the brightest shape.
const NEIGHBOUR_COLORS = {"DEU":"6f7d6d","BEL":"7f7869","FRA":"717688","LUX":"85788c","GBR":"6d7f7a"}
const EUROPE_COLORS = ["66807a","7c866e","747a92","887d73","6f8791"]
const PANEL_BG = Color(.035,.115,.15)
const BEZEL_BG = Color("0a1e25")
const SEA = Color("1f566a")
const LAKE = Color("2c6c80")
const GOLD = Color("ffc35c")
const HELI_RED = Color("ff1f1f")
const CREAM = Color("f1e9ca")
const INK = Color(.03,.1,.13,.9)
const BEZEL = 13.0
const MARGIN = 7.0
const FOOTER = 30.0
var world: TopoWorld:
	set(value):
		world=value
		local_view=false
		current_area=""
		area_sample=Vector2(INF,INF)
		view_radius=0.0
		country_radius=0.0
		update_tooltip()
		redraw_map()
var aircraft: Vector3 = Vector3.ZERO
var heading: float = 0.0
var goal: Vector3 = Vector3.ZERO
var goal_radius: float = 0.0
var show_goal: bool = false
# Learning and practice point the way when the goal is not on the map.
var show_direction: bool = false
# Records keeps the province/country caption neutral so it cannot give away a goal.
var show_place_names: bool = true
# Country code -> Dutch name, for the caption over Europe.
var country_names: Dictionary = {}
# Heading-up: the map turns so the nose always points up.
var rotate_with_heading: bool = false:
	set(value):
		if rotate_with_heading==value:
			return
		rotate_with_heading=value
		redraw_map()
		rotation_mode_changed.emit(value)
var clipper: Control
var map_layer: MapLayer
var frame: FrameLayer
var overlay: NavigationOverlay
var background_draws: int = 0
var local_view: bool = false
var cached_center: Vector2 = Vector2.ZERO
# What the map circle shows: a centre and radius in world units.
var view_center: Vector2 = Vector2.ZERO
var view_radius: float = 0.0
var country_center: Vector2 = Vector2.ZERO
var country_radius: float = 0.0
var current_area: String = ""
var area_sample: Vector2 = Vector2(INF,INF)
# Compass index (0 = N) of the direction arrow, or -1 when none is drawn.
var direction_index: int = -1

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_STOP
	update_tooltip()
	clipper=Control.new()
	clipper.clip_contents=true
	clipper.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(clipper)
	map_layer=MapLayer.new()
	clipper.add_child(map_layer)
	frame=FrameLayer.new()
	overlay=NavigationOverlay.new()
	add_child(frame)
	add_child(overlay)
	for layer in [map_layer,frame,overlay]:
		layer.minimap=self
		layer.mouse_filter=Control.MOUSE_FILTER_IGNORE
	for layer in [frame,overlay]:
		layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(layout_layers)
	layout_layers()

# Only the Dutch map has a tap toggle and Kadaster borders; Europe shows no promise it cannot keep.
func update_tooltip() -> void:
	if is_instance_valid(world) and world.region!="nl":
		tooltip_text="Kleuren gelden alleen voor de minikaart."
	else:
		tooltip_text="Tik om te wisselen tussen Nederland en de omgeving. Kleuren gelden alleen voor de minikaart. Grenzen: Kadaster NL, CC BY 4.0."

func _gui_input(event: InputEvent) -> void:
	# Touch is emitted as a mouse click by the project input settings.
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		toggle_detail()
		accept_event()

func toggle_detail() -> void:
	if not is_instance_valid(world) or world.region!="nl":
		return
	local_view=not local_view
	layout_view()
	redraw_map()

func toggle_rotation() -> void:
	rotate_with_heading=not rotate_with_heading

# The clipper is the bounding square of the map circle. The map layer is
# offset back so it draws in this control's coordinates.
func layout_layers() -> void:
	if not is_instance_valid(clipper):
		return
	var r=map_radius()
	var square=Rect2(circle_center()-Vector2(r,r),Vector2(r,r)*2)
	clipper.position=square.position
	clipper.size=square.size
	map_layer.position=-square.position
	map_layer.size=size
	redraw_map()

func redraw_map() -> void:
	queue_redraw()
	if is_instance_valid(map_layer):
		map_layer.queue_redraw()
		frame.queue_redraw()
		overlay.queue_redraw()

func refresh_navigation() -> void:
	if is_instance_valid(world) and area_sample.distance_to(Vector2(aircraft.x,aircraft.z))>1.0:
		current_area=world.province_at(aircraft) if world.region=="nl" else country_names.get(world.country_at(aircraft),"")
		area_sample=Vector2(aircraft.x,aircraft.z)
	if local_view and cached_center.distance_to(Vector2(aircraft.x,aircraft.z))>2.0 and is_instance_valid(map_layer):
		map_layer.queue_redraw()
	if view_radius<=0 and is_instance_valid(world):
		# Before the first draw (and in headless runs, which never draw).
		layout_view()
	if is_instance_valid(map_layer) and view_radius>0:
		map_layer.pivot_offset=map_pivot()
		map_layer.rotation=map_rotation()
		update_direction()
	if is_instance_valid(overlay):
		overlay.queue_redraw()

func circle_outer() -> float:
	return maxf(minf(size.x*.5-MARGIN,(size.y-FOOTER-MARGIN*2)*.5),BEZEL+10)

func map_radius() -> float:
	return circle_outer()-BEZEL

func circle_center() -> Vector2:
	return Vector2(size.x*.5,MARGIN+circle_outer())

# The circle around the whole country (or every European map place).
func measure_country() -> void:
	var points=PackedVector2Array()
	if world.region=="nl":
		for path in world.boundary_paths.get("national",[]):
			points.append_array(path)
	else:
		for marker in world.labels:
			points.append(Vector2(marker.position.x,marker.position.z))
	if points.is_empty():
		country_center=world.bounds.get_center()
		country_radius=maxf(world.bounds.size.x,world.bounds.size.y)*.5
		return
	var box=Rect2(points[0],Vector2.ZERO)
	for point in points:
		box=box.expand(point)
	country_center=box.get_center()
	var reach=0.0
	for point in points:
		reach=maxf(reach,point.distance_to(country_center))
	country_radius=reach*(1.04 if world.region=="nl" else 1.08)

# Country view, or a local window centred on the helicopter.
func layout_view() -> void:
	if not is_instance_valid(world):
		return
	if country_radius<=0:
		measure_country()
	cached_center=Vector2(aircraft.x,aircraft.z)
	view_center=country_center
	view_radius=country_radius
	if local_view:
		view_center=cached_center
		view_radius=country_radius/3.0

func map_scale() -> float:
	return map_radius()/maxf(view_radius,.001)

# Unrotated position on the map layer.
func map_point(p: Vector2) -> Vector2:
	return circle_center()+(p-view_center)*map_scale()

func map_rotation() -> float:
	# A nose heading of h on a north-up map turns up when the map turns by h.
	return heading if rotate_with_heading else 0.0

# The local view turns around the helicopter, the country view around its centre.
func map_pivot() -> Vector2:
	return map_point(Vector2(aircraft.x,aircraft.z)) if local_view else circle_center()

# Position on screen, after the map layer's rotation.
func screen_point(p: Vector2) -> Vector2:
	var pivot=map_pivot()
	return pivot+(map_point(p)-pivot).rotated(map_rotation())

# Screen direction of a world direction (x east, y south).
func screen_direction(world_direction: Vector2) -> Vector2:
	return world_direction.rotated(map_rotation())

func on_map(point: Vector2,margin: float=0.0) -> bool:
	return point.distance_to(circle_center())<=map_radius()-margin

func mapped(path: PackedVector2Array) -> PackedVector2Array:
	var points=PackedVector2Array()
	for point in path:
		points.append(map_point(point))
	return points

func fill_polygon(canvas: Control,path: PackedVector2Array,color: Color) -> void:
	var points=mapped(path)
	if points.size()>2 and not Geometry2D.triangulate_polygon(points).is_empty():
		canvas.draw_colored_polygon(points,color)

func stroke(canvas: Control,paths: Array,color: Color,width: float) -> void:
	for path in paths:
		if path.size()>1:
			canvas.draw_polyline(mapped(path),color,width,true)

func outline(canvas: Control,rings: Array,color: Color,width: float) -> void:
	for ring in rings:
		if ring.size()>2:
			var closed=mapped(ring)
			closed.append(closed[0])
			canvas.draw_polyline(closed,color,width,true)

func _draw() -> void:
	var style=StyleBoxFlat.new()
	style.bg_color=PANEL_BG
	style.set_corner_radius_all(18)
	style.border_color=Color(.55,.8,.78,.22)
	style.set_border_width_all(1)
	style.shadow_color=Color(0,0,0,.25)
	style.shadow_size=6
	draw_style_box(style,Rect2(Vector2.ZERO,size))

func neighbour_color(code: String) -> Color:
	return Color(NEIGHBOUR_COLORS.get(code,"727a72"))

func draw_geometry(canvas: Control) -> void:
	background_draws+=1
	if not is_instance_valid(world):
		return
	layout_view()
	# Sea everywhere the turning map can reach.
	var reach=size.length()*1.5
	canvas.draw_rect(Rect2(map_pivot()-Vector2(reach,reach),Vector2(reach,reach)*2),SEA)
	if world.region=="nl":
		# Full neighbour outlines first, then the Dutch file's own (clipped,
		# more detailed) neighbour shapes on top in the same colour: those
		# meet the Dutch border exactly, so no sea shows through along it.
		for code in world.neighbour_polys:
			for ring in world.neighbour_polys[code]:
				fill_polygon(canvas,ring,neighbour_color(code))
		for code in world.country_polys:
			for ring in world.country_polys[code]:
				fill_polygon(canvas,ring,Color("8fae8c") if code=="NLD" else neighbour_color(code))
		outline(canvas,world.neighbour_polys.values().reduce(func(all,rings): return all+rings,[]),Color(1,1,1,.2),.8)
		var province_index=0
		for province in world.province_regions:
			for polygon in province.polygons:
				fill_polygon(canvas,polygon,Color(PROVINCE_COLORS[province_index%PROVINCE_COLORS.size()]))
			province_index+=1
		for lake in world.lake_polys:
			fill_polygon(canvas,lake,LAKE)
		if local_view:
			stroke(canvas,world.boundary_paths.get("municipal",[]),Color(.13,.26,.36,.6),.8)
		stroke(canvas,world.boundary_paths.get("provincial",[]),Color(.97,.94,.85,.95 if local_view else .8),1.6 if local_view else 1.0)
		stroke(canvas,world.boundary_paths.get("national",[]),GOLD,2.0 if local_view else 1.5)
	else:
		var country_index=0
		for code in world.country_polys:
			for ring in world.country_polys[code]:
				fill_polygon(canvas,ring,Color("e08a4f") if code=="NLD" else Color(EUROPE_COLORS[country_index%EUROPE_COLORS.size()]))
			country_index+=1
		outline(canvas,world.country_polys.values().reduce(func(all,rings): return all+rings,[]),Color(1,.87,.6,.55),.8)
	refresh_navigation()

# Corner masks make the clipped square round; the bezel ring hides their edge.
func draw_frame(canvas: Control) -> void:
	var c=circle_center()
	var r=map_radius()
	for quarter in 4:
		var start=quarter*PI*.5
		var corner=c+Vector2(cos(start+PI*.25),sin(start+PI*.25))*r*sqrt(2.0)
		var points=PackedVector2Array([corner])
		for step in 13:
			var angle=start+PI*.5*step/12.0
			points.append(c+Vector2(cos(angle),sin(angle))*r)
		canvas.draw_colored_polygon(points,PANEL_BG)
	var outer=circle_outer()
	canvas.draw_arc(c,r+BEZEL*.5,0,TAU,96,BEZEL_BG,BEZEL+.5,true)
	canvas.draw_arc(c,r,0,TAU,96,Color(1,.86,.55,.6),1.6,true)
	canvas.draw_arc(c,outer,0,TAU,96,Color(.55,.8,.78,.3),1.0,true)

func goal_on_map() -> bool:
	return show_goal and on_map(screen_point(Vector2(goal.x,goal.z)),4)

func update_direction() -> void:
	direction_index=-1
	if show_direction and not goal_on_map():
		var delta=Vector2(goal.x-aircraft.x,goal.z-aircraft.z)
		if delta.length()>.01:
			direction_index=CompassWords.index_for_map_delta(delta)

func caption_text() -> String:
	if not is_instance_valid(world):
		return ""
	var fallback="Nederland" if world.region=="nl" else "Europa"
	var area=current_area if show_place_names and not current_area.is_empty() else fallback
	if world.region=="nl":
		return area+(" · tik: NL" if local_view else " · tik: omgeving")
	return area

func draw_navigation(canvas: Control) -> void:
	if not is_instance_valid(world) or view_radius<=0:
		return
	var font=ThemeDB.fallback_font
	var c=circle_center()
	var attribution="Kadaster · CC BY" if world.region=="nl" else ""
	var attribution_width=font.get_string_size(attribution,HORIZONTAL_ALIGNMENT_LEFT,-1,9).x
	canvas.draw_string(font,Vector2(14,size.y-12),caption_text(),HORIZONTAL_ALIGNMENT_LEFT,size.x-34-attribution_width,12,Color("e3eadf"))
	if not attribution.is_empty():
		canvas.draw_string(font,Vector2(size.x-14-attribution_width,size.y-12),attribution,HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color("8fabad"))
	if show_goal:
		var goal_point=screen_point(Vector2(goal.x,goal.z))
		if on_map(goal_point):
			# The answer range as a ring, never smaller than a readable dot.
			var ring=maxf(goal_radius*map_scale(),7.0) if goal_radius>0 else 0.0
			if ring>0:
				canvas.draw_circle(goal_point,ring,Color(1,.76,.36,.2))
				canvas.draw_arc(goal_point,ring,0,TAU,32,GOLD,1.5,true)
			canvas.draw_circle(goal_point,4.5,INK)
			canvas.draw_circle(goal_point,3.5,GOLD)
	draw_bezel_marks(canvas,font)
	if direction_index>=0:
		draw_direction_arrow(canvas,font)
	var pos=screen_point(Vector2(aircraft.x,aircraft.z))
	if on_map(pos):
		# North-up: the arrow shows the nose. Heading-up: the nose always points up.
		var ahead=screen_direction(Vector2(-sin(heading),-cos(heading)))
		if ahead.is_zero_approx():
			ahead=Vector2.UP
		draw_heli_icon(canvas,pos,ahead)
	if rotate_with_heading:
		# Lubber mark: the nose points here.
		var top=c+Vector2(0,-circle_outer())
		canvas.draw_colored_polygon(PackedVector2Array([top+Vector2(-5,-1),top+Vector2(5,-1),top+Vector2(0,6)]),CREAM)

# The helicopter as a hard red dot with a white rim and a dark halo, so it
# stands out on every province colour, on water and on the grey neighbours.
# A white pointer outside the dot shows where the nose points.
func draw_heli_icon(canvas: Control,pos: Vector2,ahead: Vector2) -> void:
	var side=ahead.orthogonal()
	canvas.draw_circle(pos,12.5,Color(0,0,0,.35))
	var tip=PackedVector2Array([pos+ahead*17.5,pos+ahead*7.0+side*6.5,pos+ahead*7.0-side*6.5])
	var tip_edge=tip.duplicate()
	tip_edge.append(tip[0])
	canvas.draw_colored_polygon(tip,Color.WHITE)
	canvas.draw_polyline(tip_edge,Color(0,0,0,.6),1.0,true)
	canvas.draw_circle(pos,9.2,Color.WHITE)
	canvas.draw_circle(pos,7.2,HELI_RED)
	canvas.draw_arc(pos,9.2,0,TAU,32,Color(0,0,0,.5),1.0,true)
	# A small highlight keeps the dot from reading as a hole.
	canvas.draw_circle(pos-side*2.2-ahead*2.2,1.8,Color(1,.75,.75,.9))

# Compass bezel: N, O, Z and W, a tick every 15 degrees, turning with the
# map in heading-up mode.
func draw_bezel_marks(canvas: Control,font: Font) -> void:
	var c=circle_center()
	var r=map_radius()
	for step in 24:
		var degrees=step*15
		var direction=screen_direction(CompassWords.map_direction(0).rotated(deg_to_rad(degrees)))
		if degrees%90==0:
			var index=degrees/45
			var at=c+direction*(r+BEZEL*.5)
			var letter: String=CompassWords.SHORT[index]
			var north=index==0
			var width=font.get_string_size(letter,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x
			if north:
				canvas.draw_circle(at,7.5,GOLD)
			canvas.draw_string(font,at+Vector2(-width*.5,4.3),letter,HORIZONTAL_ALIGNMENT_LEFT,-1,12,INK if north else CREAM)
		elif degrees%45==0:
			canvas.draw_line(c+direction*(r+3),c+direction*(r+BEZEL-3),Color(CREAM,.75),1.4,true)
		else:
			canvas.draw_line(c+direction*(r+BEZEL-5),c+direction*(r+BEZEL-2),Color(CREAM,.35),1.0,true)

# A gold arrow just inside the rim, pointing in the eight-wind direction of
# the goal. It is coarse on purpose: a direction, not the spot.
func draw_direction_arrow(canvas: Control,font: Font) -> void:
	var direction=screen_direction(CompassWords.map_direction(direction_index)).normalized()
	var c=circle_center()
	var tip=c+direction*(map_radius()-4)
	var side=direction.orthogonal()
	var pulse=.75+.25*sin(Time.get_ticks_msec()*.006)
	var arrow=PackedVector2Array([tip,tip-direction*11+side*7,tip-direction*7,tip-direction*11-side*7])
	canvas.draw_colored_polygon(arrow,Color(GOLD,pulse))
	var closed=arrow.duplicate()
	closed.append(arrow[0])
	canvas.draw_polyline(closed,INK,1.0,true)
	var label: String=CompassWords.SHORT[direction_index]
	var width=font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,11).x
	var at=tip-direction*22
	canvas.draw_string_outline(font,at+Vector2(-width*.5,4),label,HORIZONTAL_ALIGNMENT_LEFT,-1,11,3,INK)
	canvas.draw_string(font,at+Vector2(-width*.5,4),label,HORIZONTAL_ALIGNMENT_LEFT,-1,11,GOLD)
