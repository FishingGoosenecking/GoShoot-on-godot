extends Parallax2D

@export var base_speed := 30
@export var combo_speed := 10

@export var day_color := Color(1, 1, 1, 1)
@export var night_color := Color(0.25, 0.25, 0.35, 1)

@onready var sprite := $BackgroundTex

var night_mode := false
var combo := 0

func _process(delta):
	var speed = base_speed + (combo * combo_speed)
	scroll_offset.x += speed * delta
	scroll_offset.y += (speed/4) * delta
	
	if night_mode:
		sprite.modulate = sprite.modulate.lerp(night_color, delta * 5)
	else:
		sprite.modulate = sprite.modulate.lerp(day_color, delta * 5)
