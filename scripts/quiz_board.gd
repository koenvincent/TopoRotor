class_name QuizBoard
extends Control

# Overhoren: the test without flying. A north-up map of the chosen homework
# cards with a numbered dot for every place, as on the blank worksheet, and a
# tray of names. Drag a name onto its dot (or tap the name, then the dot);
# Nakijken marks every dot right or wrong. Places that were right stay fixed
# when only the mistakes are tried again.

signal changed
signal picked(chosen: String)

# A name chip in the tray. Dragging it carries the name; a tap selects it,
# so a tap on a dot places it too.
class NameChip:
	extends PanelContainer
	var board: QuizBoard
	var place_name: String
	var text_label: Label

	func _init(owner_board: QuizBoard,name_text: String) -> void:
		board=owner_board
		place_name=name_text
		name=("Chip_"+name_text).validate_node_name()
		mouse_filter=Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape=Control.CURSOR_DRAG
		text_label=Label.new()
		text_label.text=name_text
		text_label.add_theme_font_override("font",UiFonts.font("bold"))
		text_label.add_theme_font_size_override("font_size",QuizBoard.CHIP_FONT)
		text_label.add_theme_color_override("font_color",QuizBoard.CREAM)
		text_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
		add_child(text_label)
		refresh()

	func refresh() -> void:
		add_theme_stylebox_override("panel",QuizBoard.chip_style(board.selected_name==place_name))

	# The drag starts on the press itself; the board follows the pointer from there.
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
			board.begin_drag(place_name,-1,event.global_position,event.device==InputEvent.DEVICE_ID_EMULATION,self)
			accept_event()
		elif event is InputEventMouseMotion and board.dragging():
			# Keep the moves of a drag away from the tray's ScrollContainer, which would scroll instead.
			accept_event()

# The tray of names; a name dragged off the map onto it goes back.
class Tray:
	extends PanelContainer
	var board: QuizBoard

# The map is drawn once per test and size; dots and names on a layer above it,
# so a drag only repaints the dots, never the provinces and water.
class MapLayer:
	extends Control
	var board: QuizBoard
	var draws: int = 0
	func _draw() -> void:
		draws+=1
		board.draw_map(self)

class DotLayer:
	extends Control
	var board: QuizBoard
	var draws: int = 0
	func _draw() -> void:
		draws+=1
		board.draw_dots(self)

# What follows the finger: a ring on the aim point and the name beside it.
# Moving it costs one position change, no redraw of the map.
class DragGhost:
	extends Control
	var chip: PanelContainer
	var text_label: Label

	func _init() -> void:
		mouse_filter=Control.MOUSE_FILTER_IGNORE
		chip=PanelContainer.new()
		chip.mouse_filter=Control.MOUSE_FILTER_IGNORE
		chip.add_theme_stylebox_override("panel",QuizBoard.chip_style(true))
		chip.position=Vector2(14,-16)
		text_label=Label.new()
		text_label.add_theme_font_override("font",UiFonts.font("bold"))
		text_label.add_theme_font_size_override("font_size",QuizBoard.CHIP_FONT)
		text_label.add_theme_color_override("font_color",QuizBoard.CREAM)
		text_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
		chip.add_child(text_label)
		add_child(chip)
		hide()

	func _draw() -> void:
		draw_circle(Vector2.ZERO,QuizBoard.DOT_RADIUS+5,Color(QuizBoard.GOLD,.25))
		draw_arc(Vector2.ZERO,QuizBoard.DOT_RADIUS+5,0,TAU,32,QuizBoard.GOLD,2.5,true)
		draw_circle(Vector2.ZERO,2.5,QuizBoard.GOLD)

const DOT_RADIUS = 11.0
# Fingers are wider than a mouse pointer: a drop counts for the nearest dot within this distance.
const DROP_RADIUS = 40.0
# A press that moves less than this is a tap (select a name, or place the selected one).
const DRAG_START = 6.0
# With a finger the aim sits this far above the touch, so the finger never hides the dot.
const TOUCH_LIFT = Vector2(0,-48)
# Dots closer than this on screen are pushed apart; a thin line keeps them tied to the real spot.
const MIN_GAP = 26.0
const CHIP_FONT = 16
const NUMBER_FONT = 12
const NAME_FONT = 13
const CREAM = Color("fff7e6")
const GOLD = Color("ffc94a")
const INK = Color(.03,.1,.13,.94)
const RIGHT = Color("5cff8f")
const WRONG = Color("ff5470")
const SEA = Color("1f566a")
const LAKE = Color("2c6c80")
const RIVER = Color("63b4cf")
# Dot colours by kind, so cities, provinces, water and areas read apart as on the worksheet.
const KIND_COLORS = {"stad":Color("fff1cf"),"plek":Color("fff1cf"),"provincie":Color("c9b6ff"),"water":Color("8fe0ff"),"gebied":Color("ffc98a"),"eiland":Color("ffc98a")}
const LEGEND = [["stad","stad of plek"],["provincie","provincie"],["water","water, rivier of dijk"],["gebied","gebied of eiland"]]
# Orientation names only; the Noordzee is a question on Kaart A, so it gets no label.
const AREA_LABELS = [["DUITSLAND",7.6,52.3],["BELGIË",4.6,51.1]]

var world: TopoWorld
var places: Array = []
var placed: PackedStringArray = PackedStringArray()
var locked: Array = []
var checked: bool = false
var selected_name: String = ""
var hover: int = -1
var view: Rect2
var dot_at: PackedVector2Array = PackedVector2Array()
var true_at: PackedVector2Array = PackedVector2Array()
var river_paths: Array = []
var laid_out_for: Vector2 = Vector2.ZERO
var label_blocks: Array = []
var labels_dirty: bool = true
var map_layer: MapLayer
var dot_layer: DotLayer
# Set by the game: where the ghost is drawn (above everything) and the tray to drop names back on.
var float_layer: Control
var tray: Control
var ghost: DragGhost
var drag_name: String = ""
var drag_from: int = -1
var drag_origin: Vector2 = Vector2.ZERO
var drag_moved: bool = false
var drag_touch: bool = false
var drag_chip: Control
var aim: Vector2 = Vector2(-9999,-9999)
var tap_pending: bool = false

func _init() -> void:
	mouse_filter=Control.MOUSE_FILTER_STOP
	clip_contents=true
	map_layer=MapLayer.new()
	dot_layer=DotLayer.new()
	for layer in [map_layer,dot_layer]:
		layer.board=self
		layer.mouse_filter=Control.MOUSE_FILTER_IGNORE
		layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(layer)
	ghost=DragGhost.new()
	resized.connect(func():
		laid_out_for=Vector2.ZERO
		redraw_all()
	)

func redraw_all() -> void:
	labels_dirty=true
	map_layer.queue_redraw()
	dot_layer.queue_redraw()

func redraw_dots() -> void:
	labels_dirty=true
	dot_layer.queue_redraw()

static func chip_style(selected: bool) -> StyleBoxFlat:
	var s=StyleBoxFlat.new()
	s.bg_color=Color("2f8fa6") if selected else Color("16485a")
	s.border_color=GOLD if selected else Color(.55,.9,1.0,.45)
	s.set_border_width_all(2 if selected else 1)
	s.set_corner_radius_all(10)
	s.content_margin_left=10
	s.content_margin_right=10
	s.content_margin_top=4
	s.content_margin_bottom=5
	return s

# A new test on these places; their order is the dot numbering.
func setup(on_world: TopoWorld,quiz_places: Array) -> void:
	world=on_world
	places=quiz_places.duplicate()
	placed=PackedStringArray()
	placed.resize(places.size())
	locked=[]
	locked.resize(places.size())
	locked.fill(false)
	checked=false
	selected_name=""
	hover=-1
	river_paths=[]
	for river in world.map_data.get("rivers",[]):
		var path=PackedVector2Array()
		for p in river:
			var v=world.project(p[0],p[1])
			path.append(Vector2(v.x,v.z))
		river_paths.append(path)
	laid_out_for=Vector2.ZERO
	dot_at=PackedVector2Array()
	true_at=PackedVector2Array()
	cancel_drag()
	redraw_all()
	changed.emit()

func names_left() -> PackedStringArray:
	var left=PackedStringArray()
	for p in places:
		if not placed.has(p.name):
			left.append(p.name)
	return left

func placed_count() -> int:
	var n=0
	for name_text in placed:
		if not name_text.is_empty():
			n+=1
	return n

func dot_of(name_text: String) -> int:
	return placed.find(name_text)

func assign(dot: int,name_text: String) -> void:
	if checked or dot<0 or dot>=places.size() or locked[dot]:
		return
	var from=placed.find(name_text)
	if from>=0:
		if locked[from]:
			return
		placed[from]=""
	placed[dot]=name_text
	if selected_name==name_text:
		selected_name=""
	redraw_dots()
	changed.emit()

func unassign(name_text: String) -> void:
	var dot=placed.find(name_text)
	if checked or dot<0 or locked[dot]:
		return
	placed[dot]=""
	redraw_dots()
	changed.emit()

func select_name(name_text: String) -> void:
	if checked:
		return
	selected_name="" if selected_name==name_text else name_text
	picked.emit(selected_name)
	changed.emit()

# Marks the test: how many dots carry their own name.
func grade() -> Dictionary:
	cancel_drag()
	checked=true
	selected_name=""
	hover=-1
	var right=0
	for i in places.size():
		if placed[i]==places[i].name:
			right+=1
	redraw_dots()
	changed.emit()
	return {"right":right,"total":places.size()}

func is_right(dot: int) -> bool:
	return placed[dot]==places[dot].name

# Right answers stay as fixed green dots; the rest go back to the tray.
func retry_wrong() -> void:
	for i in places.size():
		if is_right(i):
			locked[i]=true
		else:
			placed[i]=""
	checked=false
	redraw_dots()
	changed.emit()

func all_locked() -> bool:
	return locked.all(func(v): return v)

# Nearest dot within reach of a screen point, or -1. open_only skips dots fixed in an earlier round.
func nearest_dot(at: Vector2,reach: float=DROP_RADIUS,open_only: bool=true) -> int:
	layout()
	var best=-1
	var best_d=reach
	for i in dot_at.size():
		if open_only and locked[i]:
			continue
		var d=at.distance_to(dot_at[i])
		if d<=best_d:
			best=i
			best_d=d
	return best

# --- dragging ----------------------------------------------------------------
# The drag is the game's own: it starts on the press, follows every pointer
# move without a threshold delay or a drag preview, and snaps to the nearest
# open dot within DROP_RADIUS of the aim. Positions are canvas coordinates.

func dragging() -> bool:
	return not drag_name.is_empty()

func board_point(canvas_pos: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse()*canvas_pos

func begin_drag(name_text: String,from: int,canvas_pos: Vector2,touch: bool,chip: Control=null) -> void:
	if checked or name_text.is_empty() or (from>=0 and locked[from]):
		return
	tap_pending=false
	drag_name=name_text
	drag_from=from
	drag_origin=canvas_pos
	drag_moved=false
	drag_touch=touch
	drag_chip=chip
	ghost.text_label.text=name_text
	move_drag(canvas_pos)

func move_drag(canvas_pos: Vector2) -> void:
	if not dragging():
		return
	if not drag_moved and canvas_pos.distance_to(drag_origin)>=DRAG_START:
		drag_moved=true
		if is_instance_valid(drag_chip):
			drag_chip.modulate.a=.35
		if is_instance_valid(float_layer):
			if ghost.get_parent()!=float_layer:
				if ghost.get_parent():
					ghost.get_parent().remove_child(ghost)
				float_layer.add_child(ghost)
			ghost.move_to_front()
			ghost.show()
	var aim_canvas=canvas_pos+(TOUCH_LIFT if drag_touch else Vector2.ZERO)
	aim=board_point(aim_canvas)
	if ghost.is_inside_tree():
		ghost.position=(ghost.get_parent() as Control).get_global_transform_with_canvas().affine_inverse()*aim_canvas
	var dot=nearest_dot(aim) if drag_moved else -1
	if dot!=hover:
		hover=dot
		dot_layer.queue_redraw()

func end_drag(canvas_pos: Vector2) -> void:
	if not dragging():
		return
	move_drag(canvas_pos)
	var name_text=drag_name
	var from=drag_from
	var moved=drag_moved
	var target=nearest_dot(aim) if moved else -1
	cancel_drag()
	if not moved:
		# A tap: on a name it selects it, on a placed dot it puts the selected name there.
		if from<0:
			select_name(name_text)
		elif not selected_name.is_empty():
			assign(from,selected_name)
		return
	if target>=0:
		assign(target,name_text)
	elif from>=0 and is_instance_valid(tray) and tray.get_global_rect().has_point(canvas_pos):
		unassign(name_text)

func cancel_drag() -> void:
	if is_instance_valid(drag_chip):
		drag_chip.modulate.a=1.0
	drag_chip=null
	drag_name=""
	drag_from=-1
	drag_moved=false
	tap_pending=false
	ghost.hide()
	if hover>=0:
		hover=-1
		if is_instance_valid(dot_layer):
			dot_layer.queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if checked or not (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed):
		return
	var dot=nearest_dot(event.position,DOT_RADIUS+12)
	if dot>=0 and not placed[dot].is_empty():
		begin_drag(placed[dot],dot,event.global_position,event.device==InputEvent.DEVICE_ID_EMULATION)
		accept_event()
	elif not selected_name.is_empty():
		tap_pending=true
		accept_event()

# Moves and the release are followed here, wherever the pointer goes (over the tray, off the map).
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if dragging():
		if event is InputEventMouseMotion:
			move_drag(event.position)
		elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
			end_drag(event.position)
	elif tap_pending and event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
		tap_pending=false
		var dot=nearest_dot(board_point(event.position))
		if dot>=0:
			assign(dot,selected_name)

func _exit_tree() -> void:
	cancel_drag()

# --- layout ----------------------------------------------------------------

func place_xy(p: Dictionary) -> Vector2:
	var v=world.project(p.lon,p.lat)
	return Vector2(v.x,v.z)

func national_box() -> Rect2:
	var box=Rect2()
	var first=true
	for path in world.boundary_paths.get("national",[]):
		for point in path:
			if first:
				box=Rect2(point,Vector2.ZERO)
				first=false
			else:
				box=box.expand(point)
	return world.bounds if first else box

# The part of the country the cards cover, a little wider so dots at the edge keep room for their name.
func view_rect() -> Rect2:
	var country=national_box()
	if places.is_empty():
		return country
	var box=Rect2(place_xy(places[0]),Vector2.ZERO)
	for p in places:
		box=box.expand(place_xy(p))
	var least=maxf(country.size.x,country.size.y)*.32
	box=box.grow_individual(maxf(0,(least-box.size.x)*.5),maxf(0,(least-box.size.y)*.5),maxf(0,(least-box.size.x)*.5),maxf(0,(least-box.size.y)*.5))
	return box.grow(maxf(box.size.x,box.size.y)*.1)

func to_screen(p: Vector2) -> Vector2:
	var inner=Rect2(Vector2.ZERO,size).grow(-8)
	var s=minf(inner.size.x/view.size.x,inner.size.y/view.size.y)
	return inner.get_center()+(p-view.get_center())*s

func layout() -> void:
	if not is_instance_valid(world) or size.x<=0 or size.y<=0 or (laid_out_for==size and dot_at.size()==places.size()):
		return
	laid_out_for=size
	view=view_rect()
	true_at=PackedVector2Array()
	for p in places:
		true_at.append(to_screen(place_xy(p)))
	dot_at=spread(true_at,MIN_GAP,Rect2(Vector2.ZERO,size).grow(-DOT_RADIUS-2))

# Pushes points that sit closer than gap apart, a few rounds, inside the box.
static func spread(points: PackedVector2Array,gap: float,box: Rect2) -> PackedVector2Array:
	var out=points.duplicate()
	for _pass in 60:
		var moved=false
		for i in out.size():
			for j in range(i+1,out.size()):
				var d=out[j]-out[i]
				var length=d.length()
				if length>=gap:
					continue
				var dir=d/length if length>.01 else Vector2.RIGHT.rotated(float(i*7+j)*.9)
				var push=(gap-length)*.5+.1
				out[i]-=dir*push
				out[j]+=dir*push
				moved=true
		for i in out.size():
			out[i]=out[i].clamp(box.position,box.end)
		if not moved:
			break
	return out

# --- drawing ---------------------------------------------------------------

func fill(c: CanvasItem,ring: PackedVector2Array,color: Color) -> void:
	var points=PackedVector2Array()
	for point in ring:
		points.append(to_screen(point))
	if points.size()>2 and not Geometry2D.triangulate_polygon(points).is_empty():
		c.draw_colored_polygon(points,color)

func stroke(c: CanvasItem,paths: Array,color: Color,width: float) -> void:
	for path in paths:
		if path.size()>1:
			var points=PackedVector2Array()
			for point in path:
				points.append(to_screen(point))
			c.draw_polyline(points,color,width,true)

func draw_map(c: CanvasItem) -> void:
	var back=StyleBoxFlat.new()
	back.bg_color=SEA
	back.set_corner_radius_all(16)
	c.draw_style_box(back,Rect2(Vector2.ZERO,size))
	if not is_instance_valid(world) or places.is_empty():
		return
	layout()
	if dot_at.size()!=places.size():
		return
	for code in world.neighbour_polys:
		for ring in world.neighbour_polys[code]:
			fill(c,ring,Color(FlightMinimap.NEIGHBOUR_COLORS.get(code,"727a72")).darkened(.2))
	for code in world.country_polys:
		if code!="NLD":
			for ring in world.country_polys[code]:
				fill(c,ring,Color(FlightMinimap.NEIGHBOUR_COLORS.get(code,"727a72")).darkened(.2))
	var index=0
	for province in world.province_regions:
		for polygon in province.polygons:
			fill(c,polygon,Color(FlightMinimap.PROVINCE_COLORS[index%FlightMinimap.PROVINCE_COLORS.size()]).darkened(.18))
		index+=1
	for lake in world.lake_polys:
		fill(c,lake,LAKE)
	stroke(c,river_paths,RIVER,2.2)
	stroke(c,world.boundary_paths.get("provincial",[]),Color(.97,.94,.85,.6),1.2)
	stroke(c,world.boundary_paths.get("national",[]),GOLD,2.0)
	var font: Font=UiFonts.font("bold")
	for entry in AREA_LABELS:
		var at=to_screen(place_xy({"lon":entry[1],"lat":entry[2]}))
		at.x-=font.get_string_size(entry[0],HORIZONTAL_ALIGNMENT_LEFT,-1,13).x*.5
		c.draw_string_outline(font,at,entry[0],HORIZONTAL_ALIGNMENT_LEFT,-1,13,3,INK)
		c.draw_string(font,at,entry[0],HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color(1,1,1,.8))
	for i in places.size():
		if dot_at[i].distance_to(true_at[i])>4.0:
			c.draw_line(true_at[i],dot_at[i],Color(INK,.8),1.5,true)
			c.draw_circle(true_at[i],3.0,INK)
			c.draw_circle(true_at[i],1.8,CREAM)
	draw_legend(c,font)

# Names first, dots on top: a label never hides a dot that still needs a name.
# The label spots are worked out once per change of names, not per frame of a drag.
func draw_dots(c: CanvasItem) -> void:
	if not is_instance_valid(world) or places.is_empty():
		return
	layout()
	if dot_at.size()!=places.size():
		return
	var font: Font=UiFonts.font("bold")
	if labels_dirty:
		label_blocks=label_layout(font)
		labels_dirty=false
	for block in label_blocks:
		draw_label(c,block,font)
	for i in places.size():
		draw_dot(c,i,font)

func dot_color(i: int) -> Color:
	if locked[i]:
		return RIGHT
	if checked:
		return RIGHT if is_right(i) else WRONG
	return KIND_COLORS.get(places[i].get("kind",""),CREAM)

func draw_dot(c: CanvasItem,i: int,font: Font) -> void:
	var at=dot_at[i]
	if i==hover:
		c.draw_circle(at,DOT_RADIUS+9,Color(GOLD,.4))
		c.draw_arc(at,DOT_RADIUS+9,0,TAU,32,GOLD,2.5,true)
	c.draw_circle(at,DOT_RADIUS+2,INK)
	c.draw_circle(at,DOT_RADIUS,dot_color(i))
	var number=str(i+1)
	var w=font.get_string_size(number,HORIZONTAL_ALIGNMENT_LEFT,-1,NUMBER_FONT).x
	c.draw_string(font,at+Vector2(-w*.5,NUMBER_FONT*.38),number,HORIZONTAL_ALIGNMENT_LEFT,-1,NUMBER_FONT,INK)

# The lines next to a dot: the placed name and, after marking a mistake, the right name in gold.
func label_lines(i: int) -> Array:
	var lines: Array=[]
	var wrong=checked and not is_right(i)
	if not placed[i].is_empty():
		lines.append([placed[i],WRONG.lightened(.35) if wrong else CREAM,wrong])
	if wrong:
		lines.append([LocatorCard.display_name(places[i]),GOLD,false])
	return lines

const LINE_HEIGHT = 18.0

# A spot for every label beside its dot: right, left, above or below, or a
# little higher or lower, whichever covers the fewest other labels and dots.
func label_layout(font: Font) -> Array:
	var blocks: Array=[]
	var taken: Array=[]
	var dots: Array=[]
	for at in dot_at:
		dots.append(Rect2(at-Vector2.ONE*(DOT_RADIUS+2),Vector2.ONE*(DOT_RADIUS+2)*2))
	var bounds=Rect2(Vector2.ZERO,size).grow(-2)
	for i in places.size():
		var lines=label_lines(i)
		if lines.is_empty():
			continue
		var width=0.0
		for entry in lines:
			width=maxf(width,font.get_string_size(entry[0],HORIZONTAL_ALIGNMENT_LEFT,-1,NAME_FONT).x)
		var box_size=Vector2(width+8,lines.size()*LINE_HEIGHT+2)
		var at=dot_at[i]
		var gap=DOT_RADIUS+4
		var half=box_size.y*.5
		var options=[Vector2(at.x+gap,at.y-half),Vector2(at.x-gap-box_size.x,at.y-half),
			Vector2(at.x-box_size.x*.5,at.y-gap-box_size.y),Vector2(at.x-box_size.x*.5,at.y+gap)]
		# Further out, tied to the dot with a thin line, for crowded parts such as the Randstad.
		for step in [1,2,3,4]:
			for side_x in [at.x+gap+step*10,at.x-gap-step*10-box_size.x]:
				for dy in [-step*LINE_HEIGHT,step*LINE_HEIGHT]:
					options.append(Vector2(side_x,at.y-half+dy))
		var best=Rect2()
		var best_cost=INF
		for corner in options:
			var box=Rect2(corner,box_size)
			var cost=(0.0 if bounds.encloses(box) else 100.0)+corner.distance_to(options[0])*.01
			for other in taken:
				if box.intersects(other):
					cost+=10.0
			for j in dots.size():
				if j!=i and box.intersects(dots[j]):
					cost+=4.0
			if cost<best_cost:
				best_cost=cost
				best=box
			if cost<.05:
				break
		taken.append(best)
		blocks.append({"box":best,"lines":lines,"dot":at})
	return blocks

func draw_label(c: CanvasItem,block: Dictionary,font: Font) -> void:
	var box: Rect2=block.box
	var dot: Vector2=block.dot
	var nearest=dot.clamp(box.position,box.end)
	if nearest.distance_to(dot)>DOT_RADIUS+8:
		c.draw_line(dot,nearest,Color(CREAM,.7),1.2,true)
	c.draw_rect(box,Color(INK,.86))
	var y=box.position.y+NAME_FONT+1
	for entry in block.lines:
		var x=box.position.x+4
		c.draw_string(font,Vector2(x,y),entry[0],HORIZONTAL_ALIGNMENT_LEFT,-1,NAME_FONT,entry[1])
		if entry[2]:
			var tw=font.get_string_size(entry[0],HORIZONTAL_ALIGNMENT_LEFT,-1,NAME_FONT).x
			c.draw_line(Vector2(x,y-NAME_FONT*.35),Vector2(x+tw,y-NAME_FONT*.35),entry[1],2.0)
		y+=LINE_HEIGHT

func draw_legend(c: CanvasItem,font: Font) -> void:
	var box=Rect2(10,size.y-LEGEND.size()*18-16,176,LEGEND.size()*18+8)
	c.draw_rect(box,Color(INK,.75))
	var y=box.position.y+14
	for entry in LEGEND:
		c.draw_circle(Vector2(box.position.x+12,y-4),6,KIND_COLORS[entry[0]])
		c.draw_string(font,Vector2(box.position.x+24,y),entry[1],HORIZONTAL_ALIGNMENT_LEFT,-1,12,CREAM)
		y+=18
