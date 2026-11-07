class_name FlightMinimap
extends Control

# Country polygons are drawn only when the map changes or the control resizes.
# A separate child draws moving markers without retriangulating the background.
class NavigationOverlay:
	extends Control
	var minimap: FlightMinimap
	func _draw() -> void:
		minimap.draw_navigation(self)

var world: TopoWorld:
	set(value):
		world=value
		queue_redraw()
var aircraft: Vector3 = Vector3.ZERO
var goal: Vector3 = Vector3.ZERO
var show_goal: bool = false
var overlay: NavigationOverlay
var background_draws: int = 0

func _ready() -> void:
	overlay=NavigationOverlay.new()
	overlay.minimap=self
	overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	resized.connect(queue_redraw)

func refresh_navigation() -> void:
	if is_instance_valid(overlay):
		overlay.queue_redraw()

func map_point(p: Vector2) -> Vector2:
	var inset = Rect2(Vector2(12,12),size-Vector2(24,24))
	var s = min(inset.size.x/world.bounds.size.x,inset.size.y/world.bounds.size.y)
	var offset = inset.get_center()-world.bounds.size*s*.5
	return offset+(p-world.bounds.position)*s

func _draw() -> void:
	background_draws+=1
	var style = StyleBoxFlat.new()
	style.bg_color=Color(.04,.13,.17,.88)
	style.set_corner_radius_all(16)
	draw_style_box(style,Rect2(Vector2.ZERO,size))
	if not is_instance_valid(world):
		return
	for rings in world.country_polys.values():
		for ring in rings:
			var points=PackedVector2Array()
			for p in ring:
				points.append(map_point(p))
			if points.size()>2 and not Geometry2D.triangulate_polygon(points).is_empty():
				draw_colored_polygon(points,Color("769e8c"))
	refresh_navigation()

func draw_navigation(canvas: Control) -> void:
	if not is_instance_valid(world):
		return
	if show_goal:
		canvas.draw_circle(map_point(Vector2(goal.x,goal.z)),5,Color("ffc35c"))
	var pos=map_point(Vector2(aircraft.x,aircraft.z))
	canvas.draw_circle(pos,5,Color("f2f3d8"))
	canvas.draw_arc(pos,9,0,TAU,24,Color("f2f3d8"),1,true)
	canvas.draw_string(ThemeDB.fallback_font,Vector2(size.x-28,24),"N",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("f1e9ca"))
