extends Area2D

@export var max_hp := 50
@export var min_speed := 200
@export var max_speed := 400

var hp := 0
var velocity := Vector2.ZERO

signal boss_hit(hp, max_hp)
signal boss_dead


func _ready():

	hp = max_hp

	randomize()

	var speed = randf_range(min_speed, max_speed)

	velocity = Vector2(
		randf_range(-1, 1),
		randf_range(-1, 1)
	).normalized() * speed


func _process(delta):

	position += velocity * delta

	bounce_on_edges()


func bounce_on_edges():

	var size = get_viewport_rect().size
	var margin = 40

	if position.x < margin or position.x > size.x - margin:
		velocity.x *= -1

	if position.y < margin or position.y > size.y - margin:
		velocity.y *= -1


func take_damage():
	hp -= 1
	emit_signal("boss_hit", hp, max_hp)

	if hp <= 0:
		emit_signal("boss_dead")
		queue_free()


func _input_event(viewport, event, shape_idx):

	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed:

		take_damage()
