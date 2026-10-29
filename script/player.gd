extends CharacterBody2D
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var cpu_particles_2d: CPUParticles2D = $CPUParticles2D
@onready var shadow = preload("res://scenes/shadow.tscn")

@onready var can_dasing_timer: Timer = $Can_Dasing_Timer
@onready var dashing_timer: Timer = $Dashing_Timer
@onready var shadow_timer: Timer = $ShadowTimer
@onready var health_bar: ProgressBar = $HealthBar
@onready var player_ring: Sprite2D = $player_ring
@onready var pick_shape: CollisionShape2D = $PickShape
@onready var hurt_area: Area2D = $Area2D

var dash_cooldown_ring: Node2D

signal player_died()

var ring_tween: Tween

var max_speed: float = 100.0
var acceleration: float = 1000.0
var friction: float = 600.0
var player_health = 500.0
var max_player_health = 500.0

var SPEED = 100.0
const DASH_SPEED = 780.0
const DASH_DURATION := 0.14
const DASH_COOLDOWN := 3.0
const DASH_SHADOW_INTERVAL := 0.028
var dashing: bool = false
var can_dash: bool = true
var dash_direction: Vector2 = Vector2.RIGHT
var animation_directions = ["right", "right_down", "down", "left_down", "left", "left_up", "up", "right_up"]

var pickup_range: float

## Left / right fist stance levels (0 = not owned).
var left_fist_level: int = 0
var right_fist_level: int = 0

func _ready() -> void:
	health_bar.init_health(player_health)
	max_player_health = player_health
	play_ring_tween()
	dashing_timer.wait_time = DASH_DURATION
	can_dasing_timer.wait_time = DASH_COOLDOWN
	shadow_timer.wait_time = DASH_SHADOW_INTERVAL
	left_fist_level = 0
	right_fist_level = 0
	var circle_shape := pick_shape.shape as CircleShape2D
	if circle_shape != null:
		pickup_range = circle_shape.radius

func upgrade_left_fist() -> void:
	left_fist_level += 1

func upgrade_right_fist() -> void:
	right_fist_level += 1

## Side bonus grows with fist level; wrong-side penalty is removed when both fists are owned.
func get_fist_bonus(level: int) -> float:
	# Lv1 20% → Lv2 30% → Lv3 40% → Lv4 50% → soft cap 75%
	return minf(0.10 + 0.10 * float(level), 0.75)

func get_fist_penalty(level: int) -> float:
	# Lv1 12% → Lv2 18% → Lv3 24% → Lv4 30% → soft cap 35%
	return minf(0.06 + 0.06 * float(level), 0.35)

func get_side_damage_multiplier(target_global_pos: Vector2) -> float:
	if left_fist_level <= 0 and right_fist_level <= 0:
		return 1.0

	var target_on_left := target_global_pos.x < global_position.x
	var both := left_fist_level > 0 and right_fist_level > 0
	var mult := 1.0

	if left_fist_level > 0:
		if target_on_left:
			mult *= 1.0 + get_fist_bonus(left_fist_level)
		elif not both:
			mult *= 1.0 - get_fist_penalty(left_fist_level)

	if right_fist_level > 0:
		if not target_on_left:
			mult *= 1.0 + get_fist_bonus(right_fist_level)
		elif not both:
			mult *= 1.0 - get_fist_penalty(right_fist_level)

	return mult

func set_dash_cooldown_ui(ring: Node2D) -> void:
	dash_cooldown_ring = ring
	if dash_cooldown_ring and dash_cooldown_ring.has_method("set_progress"):
		dash_cooldown_ring.set_progress(1.0 if can_dash else 0.0)

func _process(_delta: float) -> void:
	_update_dash_cooldown_ui()

func speed_up(val: float):
	SPEED += val

func pick_up_upgrade(scale: float):
	var circle_shape := pick_shape.shape as CircleShape2D
	if circle_shape == null:
		return
	pickup_range = pickup_range * scale
	print(" raduis:  ", pickup_range)
	circle_shape.radius = pickup_range

func _physics_process(delta: float) -> void:
	var input_direction := Input.get_vector("left", "right", "up", "down")
	if MobileInput.controls_enabled and MobileInput.has_move_input():
		input_direction = MobileInput.move_vector

	var look_target := get_global_mouse_position()
	# On touch / web, aim along move or current velocity instead of mouse.
	if MobileInput.controls_enabled:
		if input_direction.length_squared() > 0.01:
			look_target = global_position + input_direction
		elif velocity.length_squared() > 1.0:
			look_target = global_position + velocity
	var look_direction := look_target - global_position
	playAnimation(look_direction)

	var want_dash := Input.is_action_just_pressed("roll")
	if MobileInput.controls_enabled and MobileInput.consume_dash():
		want_dash = true
	if want_dash and can_dash:
		_start_dash(input_direction)

	if dashing:
		velocity = dash_direction * DASH_SPEED
	else:
		max_speed = SPEED
		acceleration = 900.0
		if input_direction != Vector2.ZERO:
			velocity = velocity.move_toward(input_direction.normalized() * max_speed, acceleration * delta)
		else:
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	if velocity.length_squared() > 1.0:
		cpu_particles_2d.emitting = true

	move_and_slide()

func _start_dash(input_direction: Vector2) -> void:
	can_dash = false
	dashing = true
	_set_dash_invincible(true)

	if input_direction.length_squared() > 0.01:
		dash_direction = input_direction.normalized()
	elif velocity.length_squared() > 100.0:
		dash_direction = velocity.normalized()
	else:
		var mouse_dir := get_global_mouse_position() - global_position
		if MobileInput.controls_enabled:
			dash_direction = Vector2.RIGHT
		else:
			dash_direction = mouse_dir.normalized() if mouse_dir.length_squared() > 0.01 else Vector2.RIGHT

	velocity = dash_direction * DASH_SPEED
	if dash_cooldown_ring and dash_cooldown_ring.has_method("set_progress"):
		dash_cooldown_ring.set_progress(0.0)
	dashing_timer.start()
	can_dasing_timer.start()
	shadow_timer.start()

func _update_dash_cooldown_ui() -> void:
	if dash_cooldown_ring == null or not is_instance_valid(dash_cooldown_ring):
		dash_cooldown_ring = get_tree().get_first_node_in_group("dash_cooldown_ui")
		if dash_cooldown_ring == null:
			return
	if can_dash:
		return
	if can_dasing_timer.is_stopped():
		return
	var wait_time := maxf(can_dasing_timer.wait_time, 0.001)
	var ratio := 1.0 - (can_dasing_timer.time_left / wait_time)
	dash_cooldown_ring.set_progress(ratio)

func _set_dash_invincible(active: bool) -> void:
	if hurt_area:
		hurt_area.set_deferred("monitoring", not active)

func playAnimation(direction: Vector2):
	direction = direction.normalized()
	var snap = snappedf(direction.angle(), PI / 4) / (PI / 4)
	var index = wrapi(int(snap), 0, 8)
	animated_sprite_2d.play(animation_directions[index])

func _on_shadow_timer_timeout() -> void:
	if not dashing or velocity.length_squared() <= 0.00001:
		shadow_timer.stop()
		return
	var sh = shadow.instantiate()
	get_tree().root.add_child(sh)
	sh.texture = animated_sprite_2d.sprite_frames.get_frame_texture(animated_sprite_2d.animation, animated_sprite_2d.frame)
	sh.global_position = animated_sprite_2d.global_position
	sh.scale = animated_sprite_2d.scale
	sh.start_tween()

func _on_dashing_timer_timeout() -> void:
	dashing = false
	_set_dash_invincible(false)
	shadow_timer.stop()
	velocity = dash_direction * minf(SPEED * 1.35, DASH_SPEED * 0.35)

func _on_can_dasing_timer_timeout() -> void:
	can_dash = true
	if dash_cooldown_ring:
		dash_cooldown_ring.set_progress(1.0)
		if dash_cooldown_ring.has_method("play_ready_bounce"):
			dash_cooldown_ring.play_ready_bounce()

func _on_area_2d_body_entered(_body: Node2D) -> void:
	get_hit()

func get_hit() -> void:
	if dashing:
		return
	AudioManager.play_hit()
	play_hit_tween()
	player_health = player_health - 60
	player_health = max(0, player_health)
	health_bar.set_health(player_health)
	if player_health <= 0:
		die()

func play_hit_tween() -> void:
	var tween = get_tree().create_tween()
	tween.set_loops(3)
	tween.tween_property(animated_sprite_2d, "modulate", Color.RED, 0.2)
	tween.tween_property(animated_sprite_2d, "modulate", Color.WHITE, 0.1)
	tween.tween_property(animated_sprite_2d, "scale", Vector2(2.2, 2.2), 0.2)
	tween.tween_property(animated_sprite_2d, "scale", Vector2(1.68, 1.68), 0.1)

func die() -> void:
	player_died.emit()

func play_ring_tween() -> void:
	if player_ring == null:
		return

	if ring_tween != null and ring_tween.is_valid():
		ring_tween.kill()
	var ring_base_scale = player_ring.scale
	player_ring.scale = ring_base_scale
	player_ring.modulate = Color(1, 1, 1, 0.85)

	ring_tween = create_tween()
	ring_tween.set_loops()
	ring_tween.set_trans(Tween.TRANS_SINE)
	ring_tween.set_ease(Tween.EASE_IN_OUT)

	ring_tween.tween_property(player_ring, "scale", ring_base_scale * 1.18, 0.45)
	ring_tween.parallel().tween_property(player_ring, "modulate", Color(1, 1, 1, 0.55), 0.45)
	ring_tween.tween_property(player_ring, "scale", ring_base_scale, 0.45)
	ring_tween.parallel().tween_property(player_ring, "modulate", Color(1, 1, 1, 0.85), 0.45)
