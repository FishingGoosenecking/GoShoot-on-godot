extends Node2D

@onready var bg = $BGcanvas/Parallax2D
@onready var click_particles_scene = preload("res://ClickParticles.tscn")

@export var popup_scene: PackedScene
@export var circle_scene: PackedScene
@export var circle_radius := 32
var player_damage := 1
var combo_bonus := 1.0
var boss_spawn_rate := 1.0

var rng = RandomNumberGenerator.new()
# === ROUND SYSTEM ===
var round := 1
var round_time := 30.0
var time_left := 30.0

var score_goal := 10

var upgrade_points = 0

var in_intermission := false

#night transition
var transition_state := "day"
var transition_time := 0.0
var start_radius := 0.0
@export var TRANSITION_DURATION := 1.2   # seconds

@export var DAY_DARKNESS := 1.0           # full light
@export var NIGHT_DARKNESS := 0.25        # how dark night is

@export var NIGHT_RADIUS := 200.0         # flashlight size

#target limit
@export var MAX_DAY_TARGETS := 2
@export var MAX_NIGHT_TARGETS := 7

@export var SPAWN_INTERVAL_DAY := 1.0
@export var SPAWN_INTERVAL_NIGHT := 0.3

var spawn_timer := 0.0

#combo
@export var combo_break_time := 1000.0

#night
var night_mode := false
var night_timer := 0.0
@export var night_duration := 5
@export var night_chance := 0.1
@export var night_interval := 5
var night_cooldown = night_interval

# flashlight transition
var flashlight_radius := 600.0
var target_radius := 200.0
@export var shrink_speed := 600.0

#combo
var combo := 0
var last_hit_time := 0.0

#score
var score := 0.0
var screen_size

#boss
@export var boss_intro_sounds: Array[AudioStream] = []
@export var boss_spawn_score := 50
@export var boss_chance := 0.2
@export var boss_interval_set := 30
@export var boss_scene: PackedScene
var boss_instance: Node = null
var boss_interval := boss_interval_set

func _ready():
	start_round()
	# Start hidden
	screen_size = get_viewport_rect().size
	spawn_circle()


func _process(delta):
	
	bg.combo = combo
	bg.night_mode = night_mode
	
	if transition_state == "to_day":
		night_cooldown = night_interval
	elif transition_state == "day":
		night_cooldown -= delta
	
	match transition_state:

		"to_night":
			handle_to_night(delta)
			update_flashlight()

		"night":
			update_flashlight()
			$HUD/GameHUD/NightModeLabel.text = "transition_state: %s" % transition_state
			night_mode = true
			night_timer -= delta
			if night_timer <= 0:
				end_night_mode()

		"to_day":
			handle_to_day(delta)
			update_flashlight()

		"day":
			night_mode = false
			pass
			
	handle_spawning(delta)
		
	if combo > 0:
		var diff = Time.get_ticks_msec() - last_hit_time
	
		if diff > combo_break_time * 0.7:
			$HUD/GameHUD/ComboBar.modulate = Color.ORANGE
			

#get_screen_size
func get_screen_diagonal() -> float:
	var size = get_viewport_rect().size
	return sqrt(size.x * size.x + size.y * size.y)

#day/night
func handle_to_night(delta):

	transition_time += delta

	var t = transition_time / TRANSITION_DURATION
	t = clamp(t, 0.0, 1.0)
	t = ease(t, -2.0)

	flashlight_radius = lerp(
		start_radius,
		NIGHT_RADIUS,
		t
	)

	var darkness = lerp(
		DAY_DARKNESS,
		NIGHT_DARKNESS,
		t
	)

	var mat = $NightMode/NightOverlay.material

	mat.set_shader_parameter("radius", flashlight_radius)
	mat.set_shader_parameter("darkness", darkness)

	if t >= 1.0:
		transition_state = "night"

func handle_to_day(delta):

	transition_time += delta

	var t = transition_time / TRANSITION_DURATION
	t = clamp(t, 0.0, 1.0)
	t = ease(t, -2.0)

	flashlight_radius = lerp(
		NIGHT_RADIUS,
		start_radius,
		t
	)

	var darkness = lerp(
		NIGHT_DARKNESS,
		DAY_DARKNESS,
		t
	)

	var mat = $NightMode/NightOverlay.material

	mat.set_shader_parameter("radius", flashlight_radius)
	mat.set_shader_parameter("darkness", darkness)

	if t >= 1.0:

		transition_state = "day"
		$HUD/GameHUD/NightModeLabel.text = "transition_state: %s" % transition_state

		$NightMode/NightOverlay.visible = false

func start_night_mode():
	
	if transition_state != "day":
		return
		
	transition_state = "to_night"
	transition_time = 0.0

	night_timer = night_duration

	# Start outside screen
	start_radius = get_screen_diagonal() * 1.2
	flashlight_radius = start_radius

	var mat = $NightMode/NightOverlay.material

	mat.set_shader_parameter("radius", flashlight_radius)
	mat.set_shader_parameter("darkness", DAY_DARKNESS)

	$NightMode/NightOverlay.visible = true
	$HUD/GameHUD/NightModeLabel.text = "transition_state: %s" % transition_state
	
func end_night_mode():
	
	if transition_state != "night":
		return

	transition_state = "to_day"
	transition_time = 0.0
	$HUD/GameHUD/NightModeLabel.text = "transition_state: %s" % transition_state
	
func update_flashlight():

	var mat = $NightMode/NightOverlay.material
	mat.set_shader_parameter(
		"light_pos",
		get_viewport().get_mouse_position()
	)
	mat.set_shader_parameter(
		"screen_size",
		get_viewport_rect().size
	)
	mat.set_shader_parameter(
		"radius",
		flashlight_radius
	)
	

#target
func get_target_count() -> int:
	return get_tree().get_nodes_in_group("targets").size()

func spawn_popup(pos: Vector2, points: int, combo: int):

	var popup = popup_scene.instantiate()
	popup.global_position = pos
	popup.set_text("+%d  x%d" % [points, combo])
	add_child(popup)

func spawn_multiple_circles(amount: int):
	for i in amount:
		spawn_circle()

func _on_circle_expired():
	if boss_instance != null:
		score = max(score-1,0)
		update_hud()
	spawn_circle()
	

func handle_spawning(delta):
	spawn_timer -= delta
	var max_targets = MAX_DAY_TARGETS
	var interval = SPAWN_INTERVAL_DAY
	if transition_state == "night":
		max_targets = MAX_NIGHT_TARGETS
		interval = SPAWN_INTERVAL_NIGHT
	if spawn_timer > 0:
		return

	if get_target_count() >= max_targets:
		return
	spawn_circle()
	spawn_timer = interval

func spawn_circle():
	var limit = MAX_NIGHT_TARGETS if transition_state == "night" else MAX_DAY_TARGETS
	if get_target_count() >= limit:
		return
	if intermission_active == true:
		return
	var circle = circle_scene.instantiate()
	circle.expired.connect(_on_circle_expired)
	
	if night_mode:
		circle.lifetime = 1.5
	else:
		circle.lifetime = 2.5

	var x = randf_range(circle_radius, screen_size.x - circle_radius)
	var y = randf_range(circle_radius, screen_size.y - circle_radius)
	if transition_state == "night":
		circle.scale = Vector2.ONE * 0.7
	circle.position = Vector2(x, y)
	circle.clicked.connect(_on_circle_clicked)
	add_child(circle)
	
func _on_circle_clicked(pos: Vector2):
	spawn_circle()
	spawn_click_particles(pos)
	get_score(pos)
	
	if score > boss_spawn_score and boss_instance == null and randf() < boss_chance and boss_interval <= 0:
		show_alert("BOSS INCOMING!", Color.ORANGE, 1.5)
		# Delay boss spawn slightly
		await get_tree().create_timer(1.2).timeout
		spawn_boss()
	boss_interval -= 1

#boss
func play_random_boss_sound():

	if boss_intro_sounds.is_empty():
		return

	var index = randi() % boss_intro_sounds.size()

	$BossIntroAudio.stream = boss_intro_sounds[index]
	$BossIntroAudio.play()
	
func stop_random_boss_sound():
	$BossIntroAudio.stop()
func spawn_boss():

	if boss_instance:
		return

	boss_instance = boss_scene.instantiate()

	add_child(boss_instance)
	
	play_random_boss_sound()

	boss_instance.position = get_viewport_rect().size / 2

	boss_instance.connect("boss_hit", _on_boss_hit)
	boss_instance.connect("boss_dead", _on_boss_dead)

	init_boss_bar(boss_instance.max_hp)
	boss_interval = boss_interval_set

func init_boss_bar(max_hp):
	var bar = $HUD/GameHUD/BossBar
	bar.max_value = max_hp
	bar.value = max_hp
	bar.visible = true

func _on_boss_hit(hp, max_hp):
	get_score(boss_instance.global_position)
	var bar = $HUD/GameHUD/BossBar
	if randf() < boss_chance:
		play_random_boss_sound()
	bar.value = hp

func _on_boss_dead():
	var bar = $HUD/GameHUD/BossBar
	bar.visible = false
	boss_instance = null
	score += 20
	play_random_boss_sound()

#scoring
func get_score(pos: Vector2):
	var now = Time.get_ticks_msec()
	# How long since last hit
	var diff = now - last_hit_time
	# Update last hit time
	last_hit_time = now
	# Multiplier
	var multiplier := 1.0
	if combo >= 24: # need 3 fast hits first
		multiplier = 5
	elif combo >= 12:
		multiplier = 4
	elif combo >= 6:
		multiplier = 3
	elif combo >= 3:
		multiplier = 2
	if diff < combo_break_time:
		combo += 1
		$HUD/GameHUD/ComboLabel.text = "Combo: %d, Multi: %d" % [combo, multiplier]
	else:
		if combo > 0:
			show_alert("COMBO BREAK!", Color.RED)
			combo = 0
			$HUD/GameHUD/ComboLabel.text = "Multi: %d" % multiplier
	var points = int(1 * multiplier)
	score += points
	$HUD/GameHUD/ScoreLabel.text = "Score: %d" % score
	$ClickSound.pitch_scale = 1.0 + combo * 0.05
	$ClickSound.play()
	spawn_popup(pos, points, combo)
	update_combo_bar(combo, 24)
	check_goal()
	update_hud()

	if not night_mode and randf() < night_chance and night_cooldown <= 0:
		start_night_mode()
	
func update_combo_bar(combo: int, max_combo: int):
	var bar = $HUD/GameHUD/ComboBar
	bar.value = combo
	var percent := float(combo) / max_combo
	percent = clamp(percent, 0.0, 1.0)

	# HSV rainbow (0 = red, 1 = full loop)
	var hue = percent
	var color = Color.from_hsv(hue, 1.0, 1.0)
	bar.modulate = color

#alert
func show_alert(text: String, color := Color.WHITE, time := 1.2):
	var label = $HUD/GameHUD/AlertLabel
	
	label.text = text
	label.modulate = color
	label.visible = true
	label.scale = Vector2.ONE
	
	var tween = create_tween()

	# Flash + scale
	tween.tween_property(label, "scale", Vector2(1.3, 1.3), 0.15)
	tween.tween_property(label, "scale", Vector2.ONE, 0.15)

	# Blink
	tween.tween_property(label, "modulate:a", 0.0, time)
	tween.finished.connect(func():
		label.visible = false
		label.modulate.a = 1.0
	)
	
# ========= Rounding + Timer ===========

func start_round():
	$HUD/GameHUD/Goalbar.max_value = score_goal
	in_intermission = false
	time_left = round_time
	$Timer.start()
	update_hud()
	
func _on_timer_timeout():
	if in_intermission == true:
		return
	time_left -= 1
	if time_left <= 0:
		$Timer.stop()
		show_game_over()
		print("Done")
	else:
		update_hud()

func check_goal():
	if score >= score_goal:
		show_round_clear()

func reset_progress():
	round = 1
	score = 0

	score_goal = 10
	round_time = 30.0

func _on_ContinueButton_pressed():
	start_next_round()

func update_hud():
	$HUD/GameHUD/Goalbar.value = score
	$HUD/GameHUD/TimerLabel.text = "Time: " + str(int(time_left))
	
func show_game_over():
	play_random_boss_sound()
	$HUD/GameHUD.visible = false
	$HUD/IntermissionHUD.visible = false
	$HUD/GameOverHUD.visible = true
	$HUD/GameOverHUD/GameOverPanel/RoundLabel.text="You survived %d Round(s)" % round
	$HUD/GameOverHUD/GameOverPanel/ScoreLabel.text="With score of: %d" % score
	get_tree().paused = true
# ========== Intermission HUD ===========

var intermission_active = false
var intermission_tween: Tween

func show_round_clear():
	play_random_boss_sound()
	intermission_active = true
	in_intermission = true
	upgrade_points += 2
	$Timer.stop()
	# Show intermission
	$HUD/GameHUD.hide()
	$HUD/IntermissionHUD.show()
	get_tree().paused = true
	
func _on_continue_button_pressed() -> void:
	hide_round_clear()
	stop_random_boss_sound()

func start_next_round():
	intermission_active = false
	get_tree().paused = false 
	
	round_time += rng.randf_range(-10,10)
	score_goal += rng.randf_range(10,50)
	boss_chance += rng.randf_range(0.0,0.1)
	combo = 0
	$Timer.start()
	start_round()
	
func hide_round_clear():
	$HUD/GameHUD.show()
	$HUD/IntermissionHUD.hide()
	start_next_round()

#========== Click particles =========='
func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed:
		spawn_click_particles(event.position)
		print("CLICK:", event.position)

func spawn_click_particles(pos: Vector2):
	var p = click_particles_scene.instantiate()
	p.global_position = pos
	add_child(p)
	p.emitting = true
	print("spawn")
	
