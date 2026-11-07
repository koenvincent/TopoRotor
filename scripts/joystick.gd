class_name FlightJoystick
extends Control

var value: Vector2 = Vector2.ZERO
var finger: int = -1
var mouse_down: bool = false
var center: Vector2 = Vector2(90,90)

func _ready() -> void:
	custom_minimum_size=Vector2(180,180)
	mouse_filter=Control.MOUSE_FILTER_STOP

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and finger==-1:
			finger=event.index
			value=((event.position-center)/64).limit_length()
		elif event.index==finger and not event.pressed:
			finger=-1
			value=Vector2.ZERO
	elif event is InputEventScreenDrag and event.index==finger:
		value=((event.position-center)/64).limit_length()
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		mouse_down=event.pressed
		value=((event.position-center)/64).limit_length() if mouse_down else Vector2.ZERO
	elif event is InputEventMouseMotion and mouse_down:
		value=((event.position-center)/64).limit_length()
	queue_redraw()

func reset() -> void:
	value=Vector2.ZERO
	finger=-1
	mouse_down=false
	queue_redraw()

func _draw() -> void:
	draw_circle(center+Vector2(0,4),80,Color(0,0,0,.25))
	draw_circle(center,80,Color(.03,.11,.14,.78))
	draw_arc(center,80,0,TAU,72,Color(1,.76,.36,.55),2,true)
	draw_arc(center,58,0,TAU,64,Color(.68,.85,.83,.22),1,true)
	var ink=Color(.9,.94,.88,.85)
	# Up/down chevrons: thrust along the nose. Curved arrows: turn left/right.
	for dir in [-1,1]:
		var tip=center+Vector2(0,dir*70)
		draw_colored_polygon(PackedVector2Array([tip,tip+Vector2(-8,-dir*9),tip+Vector2(8,-dir*9)]),ink if dir<0 else Color(ink,.5))
		# Left (dir -1) and right (dir 1) arcs, each with its arrowhead at the top end.
		var middle=PI if dir<0 else 0.0
		draw_arc(center,68,middle-.35,middle+.35,12,ink,3,true)
		var end_angle=middle-dir*.35
		var end=center+Vector2(cos(end_angle),sin(end_angle))*68
		var tangent=Vector2(-sin(end_angle),cos(end_angle))*-dir
		draw_colored_polygon(PackedVector2Array([end+tangent*9,end-tangent*2+tangent.orthogonal()*7,end-tangent*2-tangent.orthogonal()*7]),ink)
	var knob=center+value*54
	draw_circle(knob+Vector2(0,3),30,Color(0,0,0,.3))
	draw_circle(knob,30,Color("c27f2b"))
	draw_circle(knob+Vector2(0,-2),27,Color("ffc35c"))
	draw_circle(knob+Vector2(-7,-9),8,Color(1,1,1,.25))
