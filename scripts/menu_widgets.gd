class_name MenuWidgets
extends RefCounted

const GOLD = Color("ffc35c")
const CREAM = Color("f5efdc")
const INK = Color("143740")
const MUTED = Color("9fc5bc")

# A large, tappable game-mode card with a drawn icon, a name and a short line
# of explanation. The hangar shows three side by side instead of a dropdown.
class ModeTile:
	extends Button
	var mode_index: int = 0
	var title_text: String = ""
	var sub_text: String = ""
	var selected: bool = false:
		set(value):
			selected=value
			queue_redraw()

	func _init(index: int,heading: String,sub: String,description: String) -> void:
		mode_index=index
		title_text=heading
		sub_text=sub
		tooltip_text=description
		text=""
		custom_minimum_size=Vector2(0,88)
		size_flags_horizontal=Control.SIZE_EXPAND_FILL
		focus_mode=Control.FOCUS_ALL
		for state in ["normal","hover","pressed","hover_pressed","disabled","focus"]:
			add_theme_stylebox_override(state,StyleBoxEmpty.new())
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)

	func _draw() -> void:
		var box=StyleBoxFlat.new()
		box.set_corner_radius_all(14)
		box.anti_aliasing=true
		var hover=is_hovered() and not selected
		box.bg_color=Color("2f6170") if selected else Color("2f5f6b") if hover else Color("234a54")
		box.border_color=GOLD if selected else Color(.55,.8,.78,.22)
		box.set_border_width_all(2 if selected else 1)
		box.border_width_bottom=4 if selected else 3
		if not selected:
			box.border_color=Color("143a43")
			box.border_width_top=0
			box.border_width_left=0
			box.border_width_right=0
		draw_style_box(box,Rect2(Vector2.ZERO,size))
		if has_focus():
			draw_rect(Rect2(Vector2(-3,-3),size+Vector2(6,6)),GOLD,false,2.0)
		var tint=GOLD if selected else Color(CREAM,.85)
		var centre=Vector2(size.x*.5,26)
		match mode_index:
			0:
				draw_book(centre,tint)
			1:
				draw_target(centre,tint)
			_:
				draw_stopwatch(centre,tint)
		var font=get_theme_default_font()
		var title_width=font.get_string_size(title_text,HORIZONTAL_ALIGNMENT_LEFT,-1,17).x
		draw_string(font,Vector2((size.x-title_width)*.5,62),title_text,HORIZONTAL_ALIGNMENT_LEFT,-1,17,CREAM)
		var sub_width=font.get_string_size(sub_text,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x
		draw_string(font,Vector2((size.x-sub_width)*.5,79),sub_text,HORIZONTAL_ALIGNMENT_LEFT,-1,12,GOLD if selected else MUTED)

	# Leren: an open book.
	func draw_book(c: Vector2,tint: Color) -> void:
		for side in [-1,1]:
			var page=PackedVector2Array([c+Vector2(0,-8),c+Vector2(side*15,-12),c+Vector2(side*15,8),c+Vector2(0,12)])
			draw_colored_polygon(page,Color(tint,.25))
			var edge=page.duplicate()
			edge.append(page[0])
			draw_polyline(edge,tint,2.0,true)
			for row in 3:
				var y=-5+row*5
				draw_line(c+Vector2(side*4,y-1),c+Vector2(side*11,y-2.5),Color(tint,.7),1.2,true)

	# Oefenen: a target.
	func draw_target(c: Vector2,tint: Color) -> void:
		draw_arc(c,14,0,TAU,40,tint,2.0,true)
		draw_arc(c,8.5,0,TAU,32,tint,2.0,true)
		draw_circle(c,3.5,tint)
		draw_line(c+Vector2(9,-9),c+Vector2(17,-17),tint,2.0,true)
		draw_colored_polygon(PackedVector2Array([c+Vector2(17,-17),c+Vector2(19,-11),c+Vector2(11,-19)]),tint)

	# Records: a stopwatch.
	func draw_stopwatch(c: Vector2,tint: Color) -> void:
		var at=c+Vector2(0,2)
		draw_circle(at,13,Color(tint,.18))
		draw_arc(at,13,0,TAU,40,tint,2.2,true)
		draw_rect(Rect2(at+Vector2(-3.5,-19.5),Vector2(7,4.5)),tint)
		draw_line(at+Vector2(10,-11),at+Vector2(13,-14),tint,2.2,true)
		draw_line(at,at+Vector2(0,-9),tint,2.0,true)
		draw_line(at,at+Vector2(6,3),tint,2.0,true)
		draw_circle(at,2,tint)
