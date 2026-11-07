extends SceneTree
var model: RotorHelicopter
func _initialize() -> void:
	model=RotorHelicopter.new()
	model.name="HelicopterModel"
	root.add_child(model)
	call_deferred("bake")
func own_children(node: Node) -> void:
	for child in node.get_children():
		child.owner=model
		own_children(child)
func bake() -> void:
	own_children(model)
	model.set_script(null)
	var scene=PackedScene.new()
	assert(scene.pack(model)==OK)
	assert(ResourceSaver.save(scene,"res://assets/helicopter-model.tscn")==OK)
	print("Saved standalone helicopter graphic scene")
	quit()
