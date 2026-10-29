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
var hurt_lock: float = 0.0
## Boss-rest rewards. damage_reduction is a fraction of incoming hit damage.
var damage_reduction: float = 0.0
var cooldown_scale: float = 1.0
## Regen and lifesteal stay at 0 until a card or rest reward is picked.
const REGEN_BASE_AMOUNT := 1.0
const REGEN_AMOUNT_STEP := 1.0
const REGEN_AMOUNT_CAP := 4.0
const REGEN_BASE_INTERVAL := 3.0
const REGEN_INTERVAL_STEP := 0.35
const REGEN_INTERVAL_MIN := 1.2
const LIFESTEAL_PERCENT_BASE := 0.02
const LIFESTEAL_PERCENT_STEP := 0.01
const LIFESTEAL_FLAT := 1.0
const LIFESTEAL_CAP_BASE := 1.0
const LIFESTEAL_CAP_STEP := 1.0
const LIFESTEAL_CAP_MAX := 4.0
const LIFESTEAL_MIN_HIT := 8.0
var regen_level: int = 0
var lifesteal_level: int = 0
var _regen_acc: float = 0.0
## Kill shield stays at 0 until a card or rest reward is picked.
const SHIELD_GAIN_BASE := 2.0
const SHIELD_GAIN_STEP := 1.0
const SHIELD_IDLE_BASE := 1.25
const SHIELD_IDLE_STEP := 0.2
const SHIELD_DECAY_BASE := 4.0
const SHIELD_DECAY_STEP := 0.6
const SHIELD_DECAY_MIN := 1.5
var shield_level: int = 0
var shield: float = 0.0
var _shield_idle: float = 0.0
var shield_gem: Node2D
const HEAL_TEXT := preload("res://scenes/damage_text.tscn")
const SHIELD_GEM_SCRIPT := preload("res://script/shield_gem.gd")

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
	_ensure_shield_gem()

func full_heal() -> void:
	hurt_lock = 0.0
	if dashing:
		dashing = false
	if hurt_area:
		hurt_area.set_deferred("monitoring", true)
	var missing: float = max_player_health - float(player_health)
	if missing > 0.0:
		heal(missing)
	elif health_bar:
		health_bar.visible = true
		health_bar.set_health(player_health)

func heal(amount: float) -> float:
	if amount <= 0.0 or player_health <= 0.0:
		return 0.0
	var before: float = player_health
	player_health = minf(max_player_health, player_health + amount)
	var gained: float = player_health - before
	if gained <= 0.0:
		return 0.0
	if health_bar:
		health_bar.visible = true
		health_bar.set_health(player_health)
	_spawn_heal_popup(gained)
	_spawn_heal_spark()
	return gained

func add_regen_level() -> void:
	regen_level += 1

func add_lifesteal_level() -> void:
	lifesteal_level += 1

func add_shield_level() -> void:
	shield_level += 1

func shield_gain_for(level: int) -> float:
	if level <= 0:
		return 0.0
	return SHIELD_GAIN_BASE + SHIELD_GAIN_STEP * float(level - 1)

func shield_idle_for(level: int) -> float:
	if level <= 0:
		return SHIELD_IDLE_BASE
	return SHIELD_IDLE_BASE + SHIELD_IDLE_STEP * float(level - 1)

func shield_decay_for(level: int) -> float:
	if level <= 0:
		return SHIELD_DECAY_BASE
	return maxf(SHIELD_DECAY_MIN, SHIELD_DECAY_BASE - SHIELD_DECAY_STEP * float(level - 1))

func notify_enemy_killed() -> void:
	if shield_level <= 0 or player_health <= 0.0:
		return
	shield += shield_gain_for(shield_level)
	_shield_idle = 0.0
	_sync_shield_visuals()

func _tick_shield(delta: float) -> void:
	if shield <= 0.0 or shield_level <= 0 or player_health <= 0.0:
		return
	var idle_before := _shield_idle
	_shield_idle += delta
	var delay := shield_idle_for(shield_level)
	if _shield_idle < delay:
		return
	var decay_dt := delta
	if idle_before < delay:
		decay_dt = _shield_idle - delay
	shield = maxf(0.0, shield - shield_decay_for(shield_level) * decay_dt)
	_sync_shield_visuals()

func _ensure_shield_gem() -> void:
	if shield_gem != null and is_instance_valid(shield_gem):
		return
	shield_gem = Node2D.new()
	shield_gem.name = "ShieldGem"
	shield_gem.z_index = 3
	shield_gem.visible = false
	shield_gem.set_script(SHIELD_GEM_SCRIPT)
	add_child(shield_gem)

func _sync_shield_visuals() -> void:
	if health_bar and health_bar.has_method("set_shield"):
		health_bar.set_shield(shield, float(max_player_health))
	if shield_gem and is_instance_valid(shield_gem):
		shield_gem.visible = shield > 0.05 and player_health > 0.0

func regen_amount() -> float:
	return regen_amount_for(regen_level)

func regen_amount_for(level: int) -> float:
	if level <= 0:
		return 0.0
	return minf(REGEN_AMOUNT_CAP, REGEN_BASE_AMOUNT + REGEN_AMOUNT_STEP * float(level - 1))

func regen_interval() -> float:
	return regen_interval_for(regen_level)

func regen_interval_for(level: int) -> float:
	if level <= 0:
		return REGEN_BASE_INTERVAL
	return maxf(REGEN_INTERVAL_MIN, REGEN_BASE_INTERVAL - REGEN_INTERVAL_STEP * float(level - 1))

func lifesteal_percent_for(level: int) -> float:
	return LIFESTEAL_PERCENT_BASE + LIFESTEAL_PERCENT_STEP * float(maxi(level, 1))

func lifesteal_cap_for(level: int) -> float:
	return minf(LIFESTEAL_CAP_MAX, LIFESTEAL_CAP_BASE + LIFESTEAL_CAP_STEP * float(maxi(level, 1)))

func _tick_regen(delta: float) -> void:
	if regen_level <= 0 or player_health <= 0.0 or player_health >= max_player_health:
		return
	_regen_acc += delta
	var interval := regen_interval()
	var ticks := 0
	while _regen_acc >= interval and ticks < 3 and player_health < max_player_health:
		_regen_acc -= interval
		heal(regen_amount())
		ticks += 1

## Hits under LIFESTEAL_MIN_HIT do not heal (chip hits such as orbiting books).
## Burn ticks never call this. Direct apply_hit damage does.
func notify_damage_dealt(dealt: float) -> void:
	if lifesteal_level <= 0 or dealt < LIFESTEAL_MIN_HIT or player_health <= 0.0:
		return
	var percent := lifesteal_percent_for(lifesteal_level)
	var cap := lifesteal_cap_for(lifesteal_level)
	var amount := minf(cap, floorf(LIFESTEAL_FLAT + dealt * percent))
	if amount >= 1.0:
		heal(amount)

func _spawn_heal_popup(gained: float) -> void:
	var shown := int(round(gained))
	if shown < 1:
		return
	var text_node := HEAL_TEXT.instantiate()
	var container := get_tree().get_first_node_in_group("effect_container")
	if container == null:
		container = get_tree().current_scene
	if container == null:
		text_node.queue_free()
		return
	text_node.process_mode = Node.PROCESS_MODE_ALWAYS
	container.add_child(text_node)
	text_node.global_position = global_position + Vector2(0, -30)
	if text_node.has_method("show_heal"):
		text_node.show_heal("+%d" % shown)
	else:
		text_node.show_damage("+%d" % shown, Vector2.ZERO, 0, 0)

func _spawn_heal_spark() -> void:
	var particles := CPUParticles2D.new()
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.amount = 6
	particles.lifetime = 0.32
	particles.emitting = false
	particles.direction = Vector2(0, -1)
	particles.spread = 50.0
	particles.gravity = Vector2(0, -30)
	particles.initial_velocity_min = 18.0
	particles.initial_velocity_max = 46.0
	particles.scale_amount_min = 1.4
	particles.scale_amount_max = 2.8
	particles.color = Color(0.45, 1.0, 0.55, 1)
	particles.z_index = 12
	particles.global_position = global_position + Vector2(0, -8)
	var container := get_tree().get_first_node_in_group("effect_container")
	if container:
		container.add_child(particles)
	else:
		add_child(particles)
	particles.emitting = true
	particles.finished.connect(particles.queue_free)

func apply_rest_max_hp(bonus: float) -> void:
	max_player_health += bonus
	player_health = max_player_health
	if health_bar:
		health_bar.visible = true
		health_bar.init_health(max_player_health)

func apply_rest_defense(amount: float) -> void:
	damage_reduction = clampf(damage_reduction + amount, 0.0, 0.6)

func apply_rest_move_speed(bonus: float) -> void:
	SPEED += bonus

## Returns the cumulative scale applied to dash cooldown (1 = unchanged).
func apply_rest_cooldown(scale: float) -> float:
	cooldown_scale = clampf(cooldown_scale * scale, 0.45, 1.0)
	if can_dasing_timer:
		can_dasing_timer.wait_time = DASH_COOLDOWN * cooldown_scale
	return cooldown_scale

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

func _process(delta: float) -> void:
	_tick_regen(delta)
	_tick_shield(delta)
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
	if hurt_lock > 0.0:
		hurt_lock = maxf(0.0, hurt_lock - delta)
	var keys := Input.get_vector("left", "right", "up", "down")
	var input_direction := keys
	# Touch and keys stay live together. A resting stick does not block WASD.
	if MobileInput.controls_enabled and MobileInput.has_move_input():
		if keys.length_squared() > 0.01:
			input_direction = (keys + MobileInput.move_vector).limit_length(1.0)
		else:
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

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body != null and body.has_method("deals_own_contact") and body.deals_own_contact():
		return
	var amount := 60.0
	if body != null and body.has_method("get_touch_damage"):
		amount = float(body.get_touch_damage())
	receive_attack(amount, body)

func receive_attack(amount: float, _source: Node = null) -> void:
	if dashing or amount <= 0.0 or hurt_lock > 0.0 or player_health <= 0.0:
		return
	hurt_lock = 0.18
	AudioManager.play_hit()
	play_hit_tween()
	var taken := amount * (1.0 - clampf(damage_reduction, 0.0, 0.6))
	var absorbed := minf(shield, taken)
	shield -= absorbed
	var hp_loss := taken - absorbed
	player_health = max(0.0, player_health - hp_loss)
	health_bar.set_health(player_health)
	_sync_shield_visuals()
	if player_health <= 0.0:
		die()

func get_hit() -> void:
	receive_attack(60.0, null)

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
