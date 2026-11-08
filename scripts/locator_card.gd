class_name LocatorCard
extends PanelContainer

# After a correct answer in Leren and Oefenen: a north-up map of the whole
# country (or Europe) with the place that was just found, the places found
# before it, and one sentence about where it lies. Learning the spot in the
# flight view alone does not show its position in the country.
class MapPainter:
	extends Control
	var card: LocatorCard
	func _draw() -> void:
		card.draw_map(self)

class PulseOverlay:
	extends Control
	var card: LocatorCard
	func _draw() -> void:
		card.draw_pulse(self)

const SHOW_SECONDS = 6.0
const NL_CENTRE = Vector2(5.3,52.1) # lon, lat; Amersfoort/Utrecht area
const MIDDLE_KM = 35.0
const FAR_WATER_KM = 150.0
const RIVERS = ["Rijn","Waal","IJssel","Maas","Merwede"]
const AREA_LABELS = [["DUITSLAND",8.1,52.05],["BELGIË",4.35,51.0],["NOORDZEE",3.55,53.05]]
# Country names that take an article in a Dutch sentence.
const WITH_ARTICLE = ["Verenigd Koninkrijk"]
# Dutch waters that take "het": lakes, canals and the delta's "-vliet" and "-diep".
const HET_ENDINGS = ["meer","kanaal","vliet","diep"]
# Size of the orientation labels (DUITSLAND, NOORDZEE, Nederland, N) on the card map.
const AREA_FONT = 12
const GOLD = Color("ffc35c")
const CREAM = Color("f5efdc")
const INK = Color(.03,.1,.13,.92)

var world: TopoWorld
# Country code -> Dutch name, for European places.
var country_names: Dictionary = {}
var place: Dictionary = {}
var found_before: Array = []
var time_left: float = 0.0
var shown_count: int = 0
var kicker_label: Label
var title_label: Label
var body_label: Label
var map_box: Control
var painter: MapPainter
var pulse: PulseOverlay
var view: Rect2
var fade: Tween

func _init() -> void:
	mouse_filter=Control.MOUSE_FILTER_STOP
	var style=StyleBoxFlat.new()
	style.bg_color=Color(.035,.115,.15,.95)
	style.set_corner_radius_all(18)
	style.border_color=Color(1,.76,.36,.55)
	style.set_border_width_all(1)
	style.border_width_top=3
	for side in [SIDE_LEFT,SIDE_RIGHT]:
		style.set_content_margin(side,14)
	style.content_margin_top=10
	style.content_margin_bottom=12
	add_theme_stylebox_override("panel",style)
	var col=VBoxContainer.new()
	col.add_theme_constant_override("separation",3)
	col.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(col)
	kicker_label=_label(12,GOLD)
	kicker_label.text="WAAR LIGT HET?"
	col.add_child(kicker_label)
	title_label=_label(24,CREAM)
	title_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.clip_text=true
	col.add_child(title_label)
	body_label=_label(14,Color("d9e6df"))
	body_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	col.add_child(body_label)
	map_box=Control.new()
	map_box.custom_minimum_size=Vector2(0,196)
	map_box.clip_contents=true
	map_box.mouse_filter=Control.MOUSE_FILTER_IGNORE
	col.add_child(map_box)
	painter=MapPainter.new()
	pulse=PulseOverlay.new()
	for layer in [painter,pulse]:
		layer.card=self
		layer.mouse_filter=Control.MOUSE_FILTER_IGNORE
		layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		map_box.add_child(layer)
	map_box.resized.connect(painter.queue_redraw)
	var hint=_label(11,Color("9fc5bc"))
	hint.text="Tik of druk op Enter om te sluiten"
	hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(hint)
	hide()

func _label(size_px: int,color: Color) -> Label:
	var l=Label.new()
	l.add_theme_font_size_override("font_size",size_px)
	l.add_theme_color_override("font_color",color)
	l.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return l

func present(found: Dictionary,before: Array) -> void:
	place=found
	found_before=before
	shown_count+=1
	title_label.text=title_for(found)
	body_label.text=describe(found)
	time_left=SHOW_SECONDS
	if fade:
		fade.kill()
	modulate.a=1.0
	show()
	painter.queue_redraw()

func dismiss() -> void:
	time_left=0.0
	if fade:
		fade.kill()
	hide()

func _process(delta: float) -> void:
	if not visible:
		return
	pulse.queue_redraw()
	if time_left>0.0:
		time_left-=delta
		if time_left<=0.0:
			fade=create_tween()
			fade.tween_property(self,"modulate:a",0.0,.35)
			fade.tween_callback(hide)

# Keyboard: Enter or Escape closes the card. Space is left alone, it answers the next goal.
func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and (event.keycode in [KEY_ENTER,KEY_KP_ENTER,KEY_ESCAPE] or event.physical_keycode==KEY_ESCAPE):
		dismiss()
		get_viewport().set_input_as_handled()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		dismiss()
		accept_event()

# Heading of the card: a province says so, as the sentence below does.
static func title_for(found: Dictionary) -> String:
	return ("Provincie " if found.get("kind","")=="provincie" else "")+display_name(found)

static func display_name(found: Dictionary) -> String:
	return String(found.name).trim_suffix(" provincie").trim_suffix(" land")

static func country_phrase(name: String,start: bool) -> String:
	return ("Het " if start else "het ")+name if name in WITH_ARTICLE else name

static func water_name(found: Dictionary) -> String:
	var name=display_name(found)
	var lower=name.to_lower()
	return ("Het " if HET_ENDINGS.any(func(ending): return lower.ends_with(ending)) or lower.begins_with("meer ") else "De ")+name

func lonlat(found: Dictionary) -> Vector2:
	return Vector2(float(found.lon),float(found.lat))

func country_of(found: Dictionary) -> String:
	if not is_instance_valid(world):
		return ""
	var at=world.project(found.lon,found.lat)
	for code in world.country_polys:
		if world.country_contains(code,at):
			return country_names.get(code,"")
	return ""

# One sentence in school-topography words: where in the Netherlands it lies,
# or in which direction from the Netherlands for European places.
func describe(found: Dictionary) -> String:
	var name=display_name(found)
	var kind: String=found.get("kind","")
	var at=lonlat(found)
	if found.get("region","nl")=="nl" and kind!="land":
		var km=CompassWords.km_between(NL_CENTRE,at)
		var wind: String=CompassWords.AREA[CompassWords.index_between(NL_CENTRE,at)]
		var area="in het midden van Nederland" if km<MIDDLE_KM else "in het %s van Nederland" % wind
		var province=""
		if is_instance_valid(world) and world.region=="nl" and kind!="provincie":
			province=world.province_at(world.project(found.lon,found.lat))
		match kind:
			"provincie":
				return "%s is een provincie %s." % [name,area]
			"water":
				var article=water_name(found)
				if name in RIVERS:
					return "%s stroomt hier %s%s." % [article,area.replace("in het","door het"),", in de provincie "+province if not province.is_empty() else ""]
				if km>FAR_WATER_KM and is_instance_valid(world) and not world.country_contains("NLD",world.project(found.lon,found.lat)):
					return "%s ligt ten %s van Nederland." % [article,wind]
				return "%s ligt %s." % [article,area]
		return "%s ligt %s%s." % [name,area,", in de provincie "+province if not province.is_empty() else ""]
	var direction: String=CompassWords.AREA[CompassWords.index_between(NL_CENTRE,at)]
	if kind=="land":
		return "%s ligt ten %s van Nederland." % [country_phrase(name,true),direction]
	var country=country_of(found)
	if country=="Nederland":
		return "%s ligt in Nederland." % name
	if country.is_empty() or country==name:
		return "%s ligt ten %s van Nederland." % [name,direction]
	return "%s ligt in %s, ten %s van Nederland." % [name,country_phrase(country,false),direction]

# The whole country (Netherlands) or the full Europe map.
func view_rect() -> Rect2:
	if world.region=="nl":
		var box=Rect2()
		var first=true
		for path in world.boundary_paths.get("national",[]):
			for point in path:
				if first:
					box=Rect2(point,Vector2.ZERO)
					first=false
				else:
					box=box.expand(point)
		if not first:
			return box.grow(maxf(box.size.x,box.size.y)*.04)
	return world.bounds

func to_map(p: Vector2) -> Vector2:
	var inner=Rect2(Vector2.ZERO,map_box.size).grow(-6)
	var s=minf(inner.size.x/view.size.x,inner.size.y/view.size.y)
	return inner.get_center()+(p-view.get_center())*s

func fill(canvas: Control,ring: PackedVector2Array,color: Color) -> void:
	var points=PackedVector2Array()
	for point in ring:
		points.append(to_map(point))
	if points.size()>2 and not Geometry2D.triangulate_polygon(points).is_empty():
		canvas.draw_colored_polygon(points,color)

func line(canvas: Control,paths: Array,color: Color,width: float) -> void:
	for path in paths:
		if path.size()>1:
			var points=PackedVector2Array()
			for point in path:
				points.append(to_map(point))
			canvas.draw_polyline(points,color,width,true)

func place_point(found: Dictionary) -> Vector2:
	var at=world.project(found.lon,found.lat)
	return to_map(Vector2(at.x,at.z))

func draw_map(canvas: Control) -> void:
	if not is_instance_valid(world) or place.is_empty() or map_box.size.x<=0:
		return
	view=view_rect()
	var box=StyleBoxFlat.new()
	box.bg_color=FlightMinimap.SEA
	box.set_corner_radius_all(10)
	canvas.draw_style_box(box,Rect2(Vector2.ZERO,map_box.size))
	var target_code=String(place.get("code","")) if place.get("kind","")=="land" else ""
	# Whole neighbours (Germany, Belgium, ...) instead of the clipped slabs of
	# the Dutch map file; the clipped shapes go on top to meet the border.
	for code in world.neighbour_polys:
		for ring in world.neighbour_polys[code]:
			fill(canvas,ring,Color(FlightMinimap.NEIGHBOUR_COLORS.get(code,"727a72")).darkened(.25))
	for code in world.country_polys:
		var color=Color(FlightMinimap.NEIGHBOUR_COLORS.get(code,"727a72")).darkened(.25) if world.region=="nl" else Color("5d7270")
		if world.region!="nl" and code=="NLD":
			color=Color("e67b34") # the home country as a fixed reference
		if code==target_code:
			color=GOLD
		for ring in world.country_polys[code]:
			fill(canvas,ring,color)
	if world.region=="nl":
		var own=world.province_at(world.project(place.lon,place.lat)) if place.get("kind","")!="provincie" else ""
		var target_province=TopoWorld.province_name_for(place) if place.get("kind","")=="provincie" else own
		var index=0
		for province in world.province_regions:
			var base=Color(FlightMinimap.PROVINCE_COLORS[index%FlightMinimap.PROVINCE_COLORS.size()])
			var color=base if province.name==target_province else base.darkened(.42)
			if province.name==target_province and place.get("kind","")=="provincie":
				color=GOLD
			for polygon in province.polygons:
				fill(canvas,polygon,color)
			index+=1
		for lake in world.lake_polys:
			fill(canvas,lake,FlightMinimap.LAKE)
		for code in world.neighbour_polys:
			for ring in world.neighbour_polys[code]:
				var edge=ring.duplicate()
				edge.append(ring[0])
				line(canvas,[edge],Color(1,1,1,.16),.8)
		line(canvas,world.boundary_paths.get("provincial",[]),Color(.96,.93,.85,.55),1.0)
		line(canvas,world.boundary_paths.get("national",[]),Color("f3c466"),1.6)
		for province in world.province_regions:
			if province.name==target_province:
				for polygon in province.polygons:
					var closed=polygon.duplicate()
					closed.append(polygon[0])
					line(canvas,[closed],CREAM,1.6)
	else:
		for rings in world.country_polys.values():
			for ring in rings:
				var closed=ring.duplicate()
				closed.append(ring[0])
				line(canvas,[closed],Color(.94,.77,.43,.6),.8)
	var font: Font=UiFonts.font("bold")
	if world.region=="nl":
		for entry in AREA_LABELS:
			var at3=world.project(entry[1],entry[2])
			var at=to_map(Vector2(at3.x,at3.z))
			var width=font.get_string_size(entry[0],HORIZONTAL_ALIGNMENT_LEFT,-1,AREA_FONT).x
			var label_at=at-Vector2(width*.5,-3)
			canvas.draw_string_outline(font,label_at,entry[0],HORIZONTAL_ALIGNMENT_LEFT,-1,AREA_FONT,3,INK)
			canvas.draw_string(font,label_at,entry[0],HORIZONTAL_ALIGNMENT_LEFT,-1,AREA_FONT,Color("a9dbe6",.95) if entry[0]=="NOORDZEE" else Color(1,1,1,.9))
	for earlier in found_before:
		if earlier.get("kind","")=="land":
			continue
		var at=place_point(earlier)
		canvas.draw_circle(at,3.2,INK)
		canvas.draw_circle(at,2.2,CREAM)
	if world.region!="nl":
		var home=to_map(Vector2(world.project(NL_CENTRE.x,NL_CENTRE.y).x,world.project(NL_CENTRE.x,NL_CENTRE.y).z))
		canvas.draw_string_outline(font,home+Vector2(6,-4),"Nederland",HORIZONTAL_ALIGNMENT_LEFT,-1,AREA_FONT,3,INK)
		canvas.draw_string(font,home+Vector2(6,-4),"Nederland",HORIZONTAL_ALIGNMENT_LEFT,-1,AREA_FONT,Color("ffb27a"))
	var spot=place_point(place)
	canvas.draw_circle(spot,6.5,INK)
	canvas.draw_circle(spot,5.0,GOLD)
	var name=display_name(place)
	var width=font.get_string_size(name,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x
	var left=spot.x+10+width>map_box.size.x-6
	var text_at=spot+Vector2(-10-width if left else 10,5)
	text_at.y=clampf(text_at.y,14,map_box.size.y-6)
	canvas.draw_string_outline(font,text_at,name,HORIZONTAL_ALIGNMENT_LEFT,-1,13,4,INK)
	canvas.draw_string(font,text_at,name,HORIZONTAL_ALIGNMENT_LEFT,-1,13,CREAM)
	# North arrow: the card is always north-up, also when the minimap turns.
	var n=Vector2(map_box.size.x-16,22)
	canvas.draw_circle(n,11,INK)
	canvas.draw_colored_polygon(PackedVector2Array([n+Vector2(0,-9),n+Vector2(5,2),n+Vector2(0,0),n+Vector2(-5,2)]),GOLD)
	canvas.draw_string(font,n+Vector2(-4,10),"N",HORIZONTAL_ALIGNMENT_LEFT,-1,AREA_FONT,GOLD)

func draw_pulse(canvas: Control) -> void:
	if not is_instance_valid(world) or place.is_empty() or view.size.x<=0:
		return
	var spot=place_point(place)
	var phase=fmod(Time.get_ticks_msec()/1000.0,1.4)/1.4
	canvas.draw_arc(spot,6.0+phase*16.0,0,TAU,32,Color(GOLD,1.0-phase),2.0,true)
