class_name FlightCompass
extends Control

# Heading tape for the chase camera: the view turns with the helicopter, so the
# pilot needs a fixed reference for north. heading uses Godot's rotation.y
# (radians, counter-clockwise seen from above, 0 = nose pointing north).
const LETTERS = {0:"N",45:"NO",90:"O",135:"ZO",180:"Z",225:"ZW",270:"W",315:"NW"}
const GOLD = Color("ffc35c")
const CREAM = Color("f5efdc")
var heading: float = 0.0:
	set(value):
		heading=value
		queue_redraw()

func _ready() -> void:
	custom_minimum_size=Vector2(300,46)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	clip_contents=true

# Compass bearing in degrees, clockwise from north (0-359).
static func bearing(rotation_y: float) -> int:
	return posmod(int(round(rad_to_deg(-rotation_y))),360)

func _draw() -> void:
	var box=Rect2(Vector2.ZERO,size)
	draw_style_box(_panel(),box)
	var font=get_theme_default_font()
	var mid=size.x*.5
	var px_per_degree=size.x/110.0
	var current=float(bearing(heading))
	for step in range(-60,61,5):
		var deg=int(round(current/5.0))*5+step
		var x=mid+(deg-current)*px_per_degree
		if x<6 or x>size.x-6:
			continue
		var wrapped=posmod(deg,360)
		var major=wrapped%45==0
		draw_line(Vector2(x,size.y-6),Vector2(x,size.y-(14 if major else 9)),Color(CREAM,.85 if major else .45),2.0 if major else 1.0,true)
		if major:
			var text: String=LETTERS[wrapped]
			var colour=GOLD if wrapped==0 else CREAM
			var width=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x
			draw_string(font,Vector2(x-width*.5,size.y-18),text,HORIZONTAL_ALIGNMENT_LEFT,-1,15,colour)
	# Fixed lubber line marks where the nose points.
	draw_colored_polygon(PackedVector2Array([Vector2(mid-7,0),Vector2(mid+7,0),Vector2(mid,9)]),GOLD)

var panel_style: StyleBoxFlat

func _panel() -> StyleBoxFlat:
	if panel_style==null:
		panel_style=StyleBoxFlat.new()
		panel_style.bg_color=Color(.03,.1,.13,.88)
		panel_style.set_corner_radius_all(12)
		panel_style.border_color=Color(1,.76,.36,.45)
		panel_style.set_border_width_all(1)
	return panel_style
