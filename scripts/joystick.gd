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
	draw_circle(center,78,Color(.05,.16,.20,.7))
	draw_arc(center,78,0,TAU,64,Color(.68,.85,.83,.5),2,true)
	for d in [Vector2.UP,Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT]:
		draw_line(center+d*56,center+d*65,Color(.82,.9,.84,.7),2,true)
	draw_circle(center+value*54,29,Color("ffc35c"))
	draw_circle(center+value*54,21,Color("e5a445"))
