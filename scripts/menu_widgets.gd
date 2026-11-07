class_name MenuWidgets
extends RefCounted

const GOLD = Color("ffc94a")
const CREAM = Color("fff7e6")
const INK = Color("0b2530")
const MUTED = Color("9fd3d6")
# Leren green, Oefenen blue, Records red; the HUD and summary use the same colours.
const MODE_COLORS = [Color("4cd97b"),Color("3cb9ff"),Color("ff5470")]

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
		var accent: Color=MODE_COLORS[clampi(mode_index,0,2)]
		var box=StyleBoxFlat.new()
		box.set_corner_radius_all(16)
		box.corner_detail=10
		box.anti_aliasing=true
		var hover=is_hovered() and not selected
		# Chosen: a solid plate in the mode colour with a glow. Otherwise dim glass with a coloured rim.
		box.bg_color=accent if selected else Color(accent,.2) if hover else Color(1,1,1,.06)
		box.border_color=accent.darkened(.45) if selected else Color(accent,.6)
		box.set_border_width_all(2)
		box.border_width_bottom=5
		if selected:
			box.shadow_color=Color(accent,.45)
			box.shadow_size=14
		draw_style_box(box,Rect2(Vector2.ZERO,size))
		if has_focus():
			var ring=StyleBoxFlat.new()
			ring.set_corner_radius_all(19)
			ring.draw_center=false
			ring.border_color=Color("4fd8ff")
			ring.set_border_width_all(3)
			draw_style_box(ring,Rect2(Vector2(-4,-4),size+Vector2(8,8)))
		var tint=INK if selected else accent.lightened(.2)
		var centre=Vector2(size.x*.5,26)
		match mode_index:
			0:
				draw_book(centre,tint)
			1:
				draw_target(centre,tint)
			_:
				draw_stopwatch(centre,tint)
		var font=UiFonts.font("display")
		var heading=title_text.to_upper()
		var title_width=font.get_string_size(heading,HORIZONTAL_ALIGNMENT_LEFT,-1,19).x
		draw_string(font,Vector2((size.x-title_width)*.5,63),heading,HORIZONTAL_ALIGNMENT_LEFT,-1,19,INK if selected else CREAM)
		var small=UiFonts.font("bold")
		var sub_width=small.get_string_size(sub_text,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x
		draw_string(small,Vector2((size.x-sub_width)*.5,80),sub_text,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color(INK,.8) if selected else MUTED)

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
