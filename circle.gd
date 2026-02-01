extends Area2D

@export var lifetime := 2.5

signal expired

signal clicked(pos: Vector2)

func _ready():
	input_pickable = true
	await get_tree().create_timer(lifetime).timeout
	
	if is_inside_tree():
		emit_signal("expired")
		queue_free()

func _input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton :
		if event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
			emit_signal("clicked",global_position)
			queue_free()
