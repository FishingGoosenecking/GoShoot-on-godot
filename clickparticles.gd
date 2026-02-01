extends GPUParticles2D

func _ready():
	await finished
	queue_free()
	print("particle delete")
