extends Node2D

@export var speed := 80
@export var lifetime := 0.6

func _ready():
	animate()

func animate():
	var tween = create_tween()

	# Move up
	tween.tween_property(
		self,
		"position",
		position + Vector2(0, -40),
		lifetime
	)

	# Fade out
	tween.parallel().tween_property(
		self,
		"modulate:a",
		0,
		lifetime
	)

	tween.finished.connect(queue_free)
	
func set_text(t: String):
	$Label.text = t
