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

	func _get_drag_data(_at: Vector2) -> Variant:
		if board.checked:
			return null
		if get_viewport().gui_is_dragging():
			set_drag_preview(QuizBoard.preview_chip(place_name))
		return {"quiz_name":place_name}

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
			board.select_name(place_name)
			accept_event()

# The tray takes a name back that was dragged off the map.
class Tray:
	extends PanelContainer
	var board: QuizBoard

	func _can_drop_data(_at: Vector2,data: Variant) -> bool:
		return not board.checked and data is Dictionary and data.has("quiz_name") and data.has("from")

	func _drop_data(_at: Vector2,data: Variant) -> void:
		board.unassign(data.quiz_name)

const DOT_RADIUS = 11.0
# Fingers are wider than a mouse pointer: a drop counts for the nearest dot within this distance.
const DROP_RADIUS = 34.0
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

func _init() -> void:
	mouse_filter=Control.MOUSE_FILTER_STOP
	clip_contents=true
	resized.connect(func(): laid_out_for=Vector2.ZERO; queue_redraw())

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

static func preview_chip(name_text: String) -> Control:
	var chip=PanelContainer.new()
	chip.add_theme_stylebox_override("panel",chip_style(true))
	var l=Label.new()
	l.text=name_text
	l.add_theme_font_override("font",UiFonts.font("bold"))
	l.add_theme_font_size_override("font_size",CHIP_FONT)
	l.add_theme_color_override("font_color",CREAM)
	chip.add_child(l)
	# The finger sits on the chip's left edge, so the name stays readable while dragging.
	chip.position=Vector2(-12,-36)
	var holder=Control.new()
	holder.add_child(chip)
	return holder

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
	queue_redraw()
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
	queue_redraw()
	changed.emit()

func unassign(name_text: String) -> void:
	var dot=placed.find(name_text)
	if checked or dot<0 or locked[dot]:
		return
	placed[dot]=""
	queue_redraw()
	changed.emit()

func select_name(name_text: String) -> void:
	if checked:
		return
	selected_name="" if selected_name==name_text else name_text
	picked.emit(selected_name)
	changed.emit()

# Marks the test: how many dots carry their own name.
func grade() -> Dictionary:
	checked=true
	selected_name=""
	hover=-1
	var right=0
	for i in places.size():
		if placed[i]==places[i].name:
			right+=1
	queue_redraw()
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
	queue_redraw()
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

func _can_drop_data(at: Vector2,data: Variant) -> bool:
	if checked or not (data is Dictionary and data.has("quiz_name")):
		return false
	var dot=nearest_dot(at)
	if dot!=hover:
		hover=dot
		queue_redraw()
	return dot>=0

func _drop_data(at: Vector2,data: Variant) -> void:
	hover=-1
	assign(nearest_dot(at),data.quiz_name)

func _get_drag_data(at: Vector2) -> Variant:
	var data=drag_payload(at)
	if data!=null and get_viewport().gui_is_dragging():
		set_drag_preview(preview_chip(data.quiz_name))
	return data

# The placed name under a point, to drag it to another dot or back to the tray.
func drag_payload(at: Vector2) -> Variant:
	if checked:
		return null
	var dot=nearest_dot(at,DOT_RADIUS+10)
	if dot<0 or placed[dot].is_empty():
		return null
	return {"quiz_name":placed[dot],"from":dot}

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed and not selected_name.is_empty():
		var dot=nearest_dot(event.position)
		if dot>=0:
			assign(dot,selected_name)
			accept_event()

func _notification(what: int) -> void:
	if what==NOTIFICATION_DRAG_END and hover>=0:
		hover=-1
		queue_redraw()

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

func fill(ring: PackedVector2Array,color: Color) -> void:
	var points=PackedVector2Array()
	for point in ring:
		points.append(to_screen(point))
	if points.size()>2 and not Geometry2D.triangulate_polygon(points).is_empty():
		draw_colored_polygon(points,color)

func stroke(paths: Array,color: Color,width: float) -> void:
	for path in paths:
		if path.size()>1:
			var points=PackedVector2Array()
			for point in path:
				points.append(to_screen(point))
			draw_polyline(points,color,width,true)

func _draw() -> void:
	var back=StyleBoxFlat.new()
	back.bg_color=SEA
	back.set_corner_radius_all(16)
	draw_style_box(back,Rect2(Vector2.ZERO,size))
	if not is_instance_valid(world) or places.is_empty():
		return
	layout()
	if dot_at.size()!=places.size():
		return
	for code in world.neighbour_polys:
		for ring in world.neighbour_polys[code]:
			fill(ring,Color(FlightMinimap.NEIGHBOUR_COLORS.get(code,"727a72")).darkened(.2))
	for code in world.country_polys:
		if code!="NLD":
			for ring in world.country_polys[code]:
				fill(ring,Color(FlightMinimap.NEIGHBOUR_COLORS.get(code,"727a72")).darkened(.2))
	var index=0
	for province in world.province_regions:
		for polygon in province.polygons:
			fill(polygon,Color(FlightMinimap.PROVINCE_COLORS[index%FlightMinimap.PROVINCE_COLORS.size()]).darkened(.18))
		index+=1
	for lake in world.lake_polys:
		fill(lake,LAKE)
	stroke(river_paths,RIVER,2.2)
	stroke(world.boundary_paths.get("provincial",[]),Color(.97,.94,.85,.6),1.2)
	stroke(world.boundary_paths.get("national",[]),GOLD,2.0)
	var font: Font=UiFonts.font("bold")
	for entry in AREA_LABELS:
		var at=to_screen(place_xy({"lon":entry[1],"lat":entry[2]}))
		at.x-=font.get_string_size(entry[0],HORIZONTAL_ALIGNMENT_LEFT,-1,13).x*.5
		draw_string_outline(font,at,entry[0],HORIZONTAL_ALIGNMENT_LEFT,-1,13,3,INK)
		draw_string(font,at,entry[0],HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color(1,1,1,.8))
	for i in places.size():
		if dot_at[i].distance_to(true_at[i])>4.0:
			draw_line(true_at[i],dot_at[i],Color(INK,.8),1.5,true)
			draw_circle(true_at[i],3.0,INK)
			draw_circle(true_at[i],1.8,CREAM)
	# Names first, dots on top: a label never hides a dot that still needs a name.
	var labels=label_layout(font)
	for block in labels:
		draw_label(block,font)
	for i in places.size():
		draw_dot(i,font)
	draw_legend(font)

func dot_color(i: int) -> Color:
	if locked[i]:
		return RIGHT
	if checked:
		return RIGHT if is_right(i) else WRONG
	return KIND_COLORS.get(places[i].get("kind",""),CREAM)

func draw_dot(i: int,font: Font) -> void:
	var at=dot_at[i]
	if i==hover:
		draw_circle(at,DOT_RADIUS+7,Color(GOLD,.35))
		draw_arc(at,DOT_RADIUS+7,0,TAU,32,GOLD,2.0,true)
	draw_circle(at,DOT_RADIUS+2,INK)
	draw_circle(at,DOT_RADIUS,dot_color(i))
	var number=str(i+1)
	var w=font.get_string_size(number,HORIZONTAL_ALIGNMENT_LEFT,-1,NUMBER_FONT).x
	draw_string(font,at+Vector2(-w*.5,NUMBER_FONT*.38),number,HORIZONTAL_ALIGNMENT_LEFT,-1,NUMBER_FONT,INK)

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

func draw_label(block: Dictionary,font: Font) -> void:
	var box: Rect2=block.box
	var dot: Vector2=block.dot
	var nearest=dot.clamp(box.position,box.end)
	if nearest.distance_to(dot)>DOT_RADIUS+8:
		draw_line(dot,nearest,Color(CREAM,.7),1.2,true)
	draw_rect(box,Color(INK,.86))
	var y=box.position.y+NAME_FONT+1
	for entry in block.lines:
		var x=box.position.x+4
		draw_string(font,Vector2(x,y),entry[0],HORIZONTAL_ALIGNMENT_LEFT,-1,NAME_FONT,entry[1])
		if entry[2]:
			var tw=font.get_string_size(entry[0],HORIZONTAL_ALIGNMENT_LEFT,-1,NAME_FONT).x
			draw_line(Vector2(x,y-NAME_FONT*.35),Vector2(x+tw,y-NAME_FONT*.35),entry[1],2.0)
		y+=LINE_HEIGHT

func draw_legend(font: Font) -> void:
	var box=Rect2(10,size.y-LEGEND.size()*18-16,176,LEGEND.size()*18+8)
	draw_rect(box,Color(INK,.75))
	var y=box.position.y+14
	for entry in LEGEND:
		draw_circle(Vector2(box.position.x+12,y-4),6,KIND_COLORS[entry[0]])
		draw_string(font,Vector2(box.position.x+24,y),entry[1],HORIZONTAL_ALIGNMENT_LEFT,-1,12,CREAM)
		y+=18
