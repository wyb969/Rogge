extends CharacterBody2D
@export var player: CharacterBody2D
@onready var rush_timer: Timer = $RushTimer
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var health_bar: ProgressBar = $HealthBar
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D

signal boss_defeated

var charge_speed: float = 600.0
var is_charging: bool = false
var charge_direction: Vector2 = Vector2.ZERO
var target_position: Vector2 = Vector2.ZERO

var health_max_value: float = 2000.0
var boss_current_health: float = 2000.0
var line: Line2D
var rush_ready_time: float = 0.6

var is_dying: bool = false
var base_sprite_scale: Vector2 = Vector2(8, 8)
var hurt_tween: Tween
var hitstop_token: int = 0
var last_hitstop_msec: int = 0
const HITSTOP_COOLDOWN_MSEC := 180

func _ready() -> void:
	base_sprite_scale = sprite_2d.scale
	_setup_health_bar()
	health_bar.init_health(health_max_value)
	boss_current_health = health_max_value

func _setup_health_bar() -> void:
	health_bar.z_index = 20
	health_bar.visible = true
	health_bar.show_percentage = false
	# Keep a wide bar centered above the oversized boss sprite.
	var bar_size := Vector2(140.0, 12.0)
	health_bar.position = Vector2(-bar_size.x * 0.5, -110.0)
	health_bar.size = bar_size
	health_bar.scale = Vector2.ONE
	health_bar.modulate = Color.WHITE

func _process(_delta: float) -> void:
	if is_dying:
		return
	if is_charging:
		velocity = charge_direction * charge_speed
		move_and_slide()
		if global_position.distance_to(target_position) < 20.0:
			stop_charge()

func start_charge_attack() -> void:
	if is_dying or not is_instance_valid(player):
		return
	target_position = player.global_position
	charge_direction = (target_position - global_position).normalized()
	update_facing_direction(target_position)
	show_warning_line_and_then_charge(target_position)

func update_facing_direction(target_pos: Vector2) -> void:
	sprite_2d.flip_h = target_pos.x < global_position.x

func show_warning_line_and_then_charge(target_pos: Vector2) -> void:
	if is_dying:
		return
	line = Line2D.new()
	line.width = 12.0
	line.default_color = Color(1.0, 0.0, 0.0, 0.8)
	line.add_point(global_position)
	line.add_point(target_pos)
	line.z_index = 1
	get_tree().current_scene.add_child(line)

	var tween = create_tween()
	tween.tween_interval(0.6)
	tween.tween_property(line, "modulate:a", 0.0, 0.2)
	tween.tween_callback(line.queue_free)
	tween.tween_callback(start_moving_charge)

func start_moving_charge() -> void:
	if is_dying:
		return
	is_charging = true
	animation_player.play("chase")

func stop_charge() -> void:
	if is_dying:
		return
	is_charging = false
	animation_player.play("idle")
	velocity = Vector2.ZERO
	await get_tree().create_timer(0.6).timeout
	if is_dying:
		return
	rush_timer.start()

func set_player(player_var: Node2D) -> void:
	player = player_var

func _on_rush_timer_timeout() -> void:
	if is_dying or not player:
		return
	start_charge_attack()

func apply_hit(hit_data: Dictionary) -> void:
	if is_dying:
		return

	AudioManager.play_enemy_hurt()
	var damage_value: float = float(hit_data.get("damage", 0))
	var damage_dir: Vector2 = hit_data.get("direction", Vector2.ZERO)
	if damage_dir.length_squared() < 0.001:
		damage_dir = Vector2.RIGHT

	if is_instance_valid(player) and player.has_method("get_side_damage_multiplier"):
		damage_value *= player.get_side_damage_multiplier(global_position)
	elif get_tree().get_first_node_in_group("player") != null:
		var p := get_tree().get_first_node_in_group("player")
		if p.has_method("get_side_damage_multiplier"):
			damage_value *= p.get_side_damage_multiplier(global_position)

	boss_current_health = max(0.0, boss_current_health - damage_value)
	if health_bar:
		health_bar.visible = true
		health_bar.set_health(boss_current_health)

	play_hit_feedback(damage_dir.normalized())

	if boss_current_health <= health_max_value * 0.72:
		rush_ready_time = 0.25
		sprite_2d.material = load("res://shaders/rainbow_outline.tres")

	if boss_current_health <= 0.0:
		await start_defeat_sequence()

func play_hit_feedback(hit_dir: Vector2) -> void:
	_spawn_hit_particles(hit_dir)
	_play_hit_deform(hit_dir)
	_request_hitstop(0.42, 0.022)

func _play_hit_deform(hit_dir: Vector2) -> void:
	if hurt_tween != null and hurt_tween.is_valid():
		hurt_tween.kill()

	sprite_2d.modulate = Color(2.4, 2.4, 2.4, 1.0)
	var squash := Vector2(
		base_sprite_scale.x * (1.0 + absf(hit_dir.x) * 0.18),
		base_sprite_scale.y * (1.0 - absf(hit_dir.x) * 0.1 + absf(hit_dir.y) * 0.14)
	)
	if absf(hit_dir.y) > absf(hit_dir.x):
		squash = Vector2(
			base_sprite_scale.x * (1.0 - 0.1),
			base_sprite_scale.y * (1.0 + 0.22)
		)

	var knock_offset := hit_dir * 6.0
	var origin := sprite_2d.position

	hurt_tween = create_tween()
	hurt_tween.set_parallel(true)
	hurt_tween.tween_property(sprite_2d, "scale", squash, 0.02).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hurt_tween.tween_property(sprite_2d, "position", origin + knock_offset, 0.02)
	hurt_tween.set_parallel(false)
	hurt_tween.tween_property(sprite_2d, "modulate", Color.WHITE, 0.04)
	hurt_tween.set_parallel(true)
	hurt_tween.tween_property(sprite_2d, "scale", base_sprite_scale, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hurt_tween.tween_property(sprite_2d, "position", origin, 0.06)

func _request_hitstop(scale: float, duration_real: float) -> void:
	var now := Time.get_ticks_msec()
	if now - last_hitstop_msec < HITSTOP_COOLDOWN_MSEC:
		return
	last_hitstop_msec = now

	hitstop_token += 1
	var token := hitstop_token
	Engine.time_scale = scale
	await get_tree().create_timer(duration_real, true, true).timeout
	if token == hitstop_token and not is_dying:
		Engine.time_scale = 1.0

func _spawn_hit_particles(hit_dir: Vector2) -> void:
	var particles := CPUParticles2D.new()
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.amount = 14
	particles.lifetime = 0.28
	particles.emitting = false
	particles.direction = -hit_dir
	particles.spread = 55.0
	particles.initial_velocity_min = 90.0
	particles.initial_velocity_max = 220.0
	particles.gravity = Vector2(0, 280)
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.5
	particles.color = Color(1.0, 0.95, 0.75, 1.0)
	particles.z_index = 20
	particles.global_position = global_position
	_add_to_effect_container(particles)
	particles.emitting = true
	particles.finished.connect(particles.queue_free)

func start_defeat_sequence() -> void:
	if is_dying:
		return
	is_dying = true
	is_charging = false
	velocity = Vector2.ZERO
	rush_timer.stop()
	collision_shape_2d.set_deferred("disabled", true)
	animation_player.pause()

	if is_instance_valid(line):
		line.queue_free()
		line = null

	# Invalidate any pending hitstop restores, take exclusive control of time_scale.
	hitstop_token += 1

	# Phase 1: hard freeze (DNF final blow) — shortened ~1/3
	Engine.time_scale = 0.06
	sprite_2d.modulate = Color(3.0, 3.0, 3.0, 1.0)
	_spawn_death_burst(28, Color(1.0, 1.0, 1.0, 1.0))
	await get_tree().create_timer(0.21, true, true).timeout

	# Phase 2: slow-mo collapse — shortened ~1/3
	Engine.time_scale = 0.2
	_play_defeat_deform()
	_spawn_death_burst(40, Color(1.0, 0.55, 0.2, 1.0))
	await get_tree().create_timer(0.77, true, true).timeout

	# Phase 3: restore time, then settle
	Engine.time_scale = 1.0
	boss_defeated.emit()
	queue_free()

func _play_defeat_deform() -> void:
	if hurt_tween != null and hurt_tween.is_valid():
		hurt_tween.kill()

	hurt_tween = create_tween()
	hurt_tween.set_parallel(true)
	hurt_tween.tween_property(sprite_2d, "scale", base_sprite_scale * Vector2(1.35, 0.55), 0.17)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hurt_tween.tween_property(sprite_2d, "modulate", Color(1.0, 0.35, 0.2, 1.0), 0.13)
	hurt_tween.set_parallel(false)
	hurt_tween.tween_property(sprite_2d, "scale", base_sprite_scale * Vector2(0.35, 1.45), 0.23)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	hurt_tween.set_parallel(true)
	hurt_tween.tween_property(sprite_2d, "modulate:a", 0.0, 0.3)
	hurt_tween.tween_property(sprite_2d, "scale", base_sprite_scale * 0.15, 0.3)

func _spawn_death_burst(amount: int, color: Color) -> void:
	var particles := CPUParticles2D.new()
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = amount
	particles.lifetime = 0.55
	particles.emitting = false
	particles.direction = Vector2(0, -1)
	particles.spread = 180.0
	particles.initial_velocity_min = 120.0
	particles.initial_velocity_max = 320.0
	particles.gravity = Vector2(0, 420)
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 7.0
	particles.color = color
	particles.z_index = 25
	particles.global_position = global_position
	_add_to_effect_container(particles)
	particles.emitting = true
	particles.finished.connect(particles.queue_free)

func _add_to_effect_container(node: Node) -> void:
	var container := get_tree().get_first_node_in_group("effect_container")
	if container != null:
		container.add_child(node)
	else:
		get_tree().current_scene.add_child(node)
