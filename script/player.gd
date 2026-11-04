extends CharacterBody2D
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var cpu_particles_2d: CPUParticles2D = $CPUParticles2D

@onready var can_dasing_timer: Timer = $Can_Dasing_Timer
@onready var dashing_timer: Timer = $Dashing_Timer
@onready var shadow_timer: Timer = $ShadowTimer
@onready var health_bar: ProgressBar = $HealthBar
@onready var player_ring: Sprite2D = $player_ring
@onready var pick_shape: CollisionShape2D = $PickShape
@onready var hurt_area: Area2D = $Area2D

signal player_died()
signal health_damaged(amount: float)
signal dash_completed(at: Vector2)

var ring_tween: Tween

var max_speed: float = 100.0
var acceleration: float = 1000.0
var friction: float = 600.0
var player_health = 500.0
var max_player_health = 500.0
const HEALTH_PER_LEVEL: = 25.0
const HURT_INVULNERABILITY: = 0.45
var growth_level: = 0
var beast_damage_scale: = 1.0
var healing_multiplier: = 1.0

var SPEED = 100.0
const DASH_SPEED = 780.0
const DASH_DURATION: = 0.14
const DASH_GRACE_SECONDS: = 0.5
const DASH_COOLDOWN: = 3.0
const DASH_SHADOW_INTERVAL: = 0.028
var dashing: bool = false
var can_dash: bool = true
var dash_grace_left: = 0.0
var dash_direction: Vector2 = Vector2.RIGHT
var last_move_direction: Vector2 = Vector2.RIGHT
var animation_directions = ["right", "right_down", "down", "left_down", "left", "left_up", "up", "right_up"]

var pickup_range: float


var left_fist_level: int = 0
var right_fist_level: int = 0
var hurt_lock: float = 0.0

var damage_reduction: float = 0.0
var cooldown_scale: float = 1.0

const REGEN_BASE_AMOUNT: = 1.0
const REGEN_AMOUNT_STEP: = 1.0
const REGEN_AMOUNT_CAP: = 4.0
const REGEN_BASE_INTERVAL: = 3.0
const REGEN_INTERVAL_STEP: = 0.35
const REGEN_INTERVAL_MIN: = 1.2
const LIFESTEAL_PERCENT_BASE: = 0.02
const LIFESTEAL_PERCENT_STEP: = 0.01
const LIFESTEAL_FLAT: = 1.0
const LIFESTEAL_CAP_BASE: = 1.0
const LIFESTEAL_CAP_STEP: = 1.0
const LIFESTEAL_CAP_MAX: = 4.0
const LIFESTEAL_MIN_HIT: = 8.0
var regen_level: int = 0
var lifesteal_level: int = 0
var monster_necklace_level: int = 0
const CRITICAL_GLASSES := preload("res://script/critical_glasses.gd")
var critical_glasses_level := 0
var _critical_rng := RandomNumberGenerator.new()
var _regen_acc: float = 0.0

const SHIELD_GAIN_BASE: = 2.0
const SHIELD_GAIN_STEP: = 1.0
const SHIELD_IDLE_BASE: = 1.25
const SHIELD_IDLE_STEP: = 0.2
const SHIELD_DECAY_BASE: = 4.0
const SHIELD_DECAY_STEP: = 0.6
const SHIELD_DECAY_MIN: = 1.5
var shield_level: int = 0
var shield: float = 0.0
var _shield_idle: float = 0.0
var shield_gem: Node2D
const HEAL_TEXT: = preload("res://scenes/damage_text.tscn")
const SHIELD_GEM_SCRIPT: = preload("res://script/shield_gem.gd")
const FEEDBACK_BUDGET: = preload("res://script/feedback_budget.gd")
var _last_heal_spark_msec: = -10000
const JUICE: = preload("res://script/combat_feedback.gd")
var _visual_base_scale: = Vector2.ONE
var _hurt_tween: Tween
var _hurt_punch: = 0.0

func _ready() -> void :
	_critical_rng.randomize()
	_visual_base_scale = animated_sprite_2d.scale
	health_bar.init_health(player_health)
	max_player_health = player_health
	play_ring_tween()
	dashing_timer.wait_time = DASH_DURATION
	can_dasing_timer.wait_time = DASH_COOLDOWN
	shadow_timer.wait_time = DASH_SHADOW_INTERVAL
	left_fist_level = 0
	right_fist_level = 0
	var circle_shape: = pick_shape.shape as CircleShape2D
	if circle_shape != null:
		pickup_range = circle_shape.radius
	_ensure_shield_gem()

func apply_level_growth(new_level: int) -> float:


	var levels: = maxi(0, new_level - growth_level)
	if levels == 0 or player_health <= 0.0:
		return 0.0
	growth_level = new_level
	var gained: = HEALTH_PER_LEVEL * levels
	max_player_health += gained
	player_health = minf(max_player_health, player_health + gained)
	health_bar.visible = true
	health_bar.set_max_health(max_player_health, player_health)
	_sync_shield_visuals()
	_spawn_heal_popup(gained)
	return gained

func full_heal() -> void :
	hurt_lock = 0.0
	_cancel_dash()
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
	player_health = minf(max_player_health, player_health + effective_heal_amount(amount))
	var gained: float = player_health - before
	if gained <= 0.0:
		return 0.0
	if health_bar:
		health_bar.visible = true
		health_bar.set_health(player_health)
	_spawn_heal_popup(gained)
	_spawn_heal_spark()
	return gained

func effective_heal_amount(base_amount: float) -> float:
	return base_amount * healing_multiplier

func add_regen_level() -> void :
	regen_level += 1

func add_lifesteal_level() -> void :
	lifesteal_level += 1

func add_monster_necklace_level() -> void :
	monster_necklace_level += 1

func add_critical_glasses_level() -> void:
	critical_glasses_level = mini(critical_glasses_level + 1, CRITICAL_GLASSES.MAX_LEVEL)

func roll_critical_multiplier(hit: Dictionary) -> float:
	return CRITICAL_GLASSES.roll_multiplier(critical_glasses_level, hit, _critical_rng)

func reset_critical_glasses() -> void:
	critical_glasses_level = 0

func monster_necklace_heal_for(level: int) -> float:
	return 5.0 * float(maxi(level, 0))

func add_shield_level() -> void :
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

func notify_enemy_killed() -> void :
	if shield_level <= 0 or player_health <= 0.0:
		return
	shield += shield_gain_for(shield_level)
	_shield_idle = 0.0
	_sync_shield_visuals()

func _tick_shield(delta: float) -> void :
	if shield <= 0.0 or shield_level <= 0 or player_health <= 0.0:
		return
	var idle_before: = _shield_idle
	_shield_idle += delta
	var delay: = shield_idle_for(shield_level)
	if _shield_idle < delay:
		return
	var decay_dt: = delta
	if idle_before < delay:
		decay_dt = _shield_idle - delay
	shield = maxf(0.0, shield - shield_decay_for(shield_level) * decay_dt)
	_sync_shield_visuals()

func _ensure_shield_gem() -> void :
	if shield_gem != null and is_instance_valid(shield_gem):
		return
	shield_gem = Node2D.new()
	shield_gem.name = "ShieldGem"
	shield_gem.z_index = 3
	shield_gem.visible = false
	shield_gem.set_script(SHIELD_GEM_SCRIPT)
	add_child(shield_gem)

func _sync_shield_visuals() -> void :
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

func _tick_regen(delta: float) -> void :
	if regen_level <= 0 or player_health <= 0.0 or player_health >= max_player_health:
		return
	_regen_acc += delta
	var interval: = regen_interval()
	var ticks: = 0
	while _regen_acc >= interval and ticks < 3 and player_health < max_player_health:
		_regen_acc -= interval
		heal(regen_amount())
		ticks += 1



func notify_damage_dealt(dealt: float) -> void :
	if lifesteal_level <= 0 or dealt < LIFESTEAL_MIN_HIT or player_health <= 0.0:
		return
	var percent: = lifesteal_percent_for(lifesteal_level)
	var cap: = lifesteal_cap_for(lifesteal_level)
	var amount: = minf(cap, floorf(LIFESTEAL_FLAT + dealt * percent))
	if amount >= 1.0:
		heal(amount)

func _spawn_heal_popup(gained: float) -> void :
	if gained < 0.1 or not FEEDBACK_BUDGET.allow_popup(get_tree()):
		return
	var shown: = ("%.1f" % gained).trim_suffix(".0")
	var text_node: = HEAL_TEXT.instantiate()
	var container: = get_tree().get_first_node_in_group("effect_container")
	if container == null:
		container = get_tree().current_scene
	if container == null:
		text_node.queue_free()
		return
	text_node.process_mode = Node.PROCESS_MODE_ALWAYS
	container.add_child(text_node)
	text_node.global_position = global_position + Vector2(0, -30)
	if text_node.has_method("show_heal"):
		text_node.show_heal("+" + shown)
	else:
		text_node.show_damage("+" + shown, Vector2.ZERO, 0, 0)

func _spawn_heal_spark() -> void :
	var now: = Time.get_ticks_msec()
	if now - _last_heal_spark_msec < 80:
		return
	_last_heal_spark_msec = now
	var feedback: = JUICE.find(self)
	if feedback != null:
		feedback.spray(global_position + Vector2(0, -8), Vector2.UP, Color(0.45, 1, 0.55), 6, 46)
		return
	var particles: = CPUParticles2D.new()
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
	var container: = get_tree().get_first_node_in_group("effect_container")
	if container:
		container.add_child(particles)
	else:
		add_child(particles)
	particles.emitting = true
	particles.finished.connect(particles.queue_free)

func apply_rest_max_hp(bonus: float) -> void :
	max_player_health += bonus
	player_health = max_player_health
	if health_bar:
		health_bar.visible = true
		health_bar.init_health(max_player_health)

func apply_rest_defense(amount: float) -> void :
	damage_reduction = clampf(damage_reduction + amount, 0.0, 0.6)

func apply_rest_move_speed(bonus: float) -> void :
	SPEED += bonus


func apply_rest_cooldown(scale: float) -> float:
	cooldown_scale = clampf(cooldown_scale * scale, 0.45, 1.0)
	if can_dasing_timer:
		can_dasing_timer.wait_time = DASH_COOLDOWN * cooldown_scale
	return cooldown_scale

func upgrade_left_fist() -> void :
	left_fist_level += 1

func upgrade_right_fist() -> void :
	right_fist_level += 1


func get_fist_bonus(level: int) -> float:

	return minf(0.1 + 0.1 * float(level), 0.75)

func get_fist_penalty(level: int) -> float:

	return minf(0.06 + 0.06 * float(level), 0.35)

func get_side_damage_multiplier(target_global_pos: Vector2) -> float:
	if left_fist_level <= 0 and right_fist_level <= 0:
		return 1.0

	var target_on_left: = target_global_pos.x < global_position.x
	var both: = left_fist_level > 0 and right_fist_level > 0
	var mult: = 1.0

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

func dash_cooldown_progress() -> float:
	if can_dash: return 1.0
	var duration: = maxf(can_dasing_timer.wait_time, 0.001)
	return clampf(1.0 - can_dasing_timer.time_left / duration, 0, 0.999)

func is_dash_invulnerable() -> bool:
	return dashing or dash_grace_left > 0

func _cancel_dash() -> void :
	dashing = false
	dash_grace_left = 0
	dashing_timer.stop()
	shadow_timer.stop()
	_sync_dash_hurt_area()

func reset_dash() -> void :
	_cancel_dash()
	can_dasing_timer.stop()
	can_dash = true
	velocity = Vector2.ZERO

func _process(delta: float) -> void :
	_tick_visuals(delta)
	_tick_regen(delta)
	_tick_shield(delta)

func _tick_visuals(delta: float) -> void :
	_hurt_punch = move_toward(_hurt_punch, 0, delta * 8)
	var effort: = clampf(velocity.length() / maxf(SPEED, 1), 0, 1)
	var stretch: = Vector2(1.13, 0.88) if dashing else Vector2(1.0 + effort * 0.025, 1.0 - effort * 0.015)
	stretch += Vector2(0.1, -0.08) * _hurt_punch
	animated_sprite_2d.scale = animated_sprite_2d.scale.lerp(_visual_base_scale * stretch, 1.0 - exp( - delta * 25))
	animated_sprite_2d.rotation = lerpf(animated_sprite_2d.rotation, - velocity.x / maxf(DASH_SPEED, 1) * 0.09, 1.0 - exp( - delta * 20))

func speed_up(val: float):
	SPEED += val

func pick_up_upgrade(scale: float):
	var circle_shape: = pick_shape.shape as CircleShape2D
	if circle_shape == null:
		return
	pickup_range = pickup_range * scale
	print(" raduis:  ", pickup_range)
	circle_shape.radius = pickup_range

func _physics_process(delta: float) -> void :
	if not dashing and dash_grace_left > 0:
		dash_grace_left = maxf(0, dash_grace_left - delta)
		if dash_grace_left < 1e-06:
			dash_grace_left = 0
			_sync_dash_hurt_area()
	if hurt_lock > 0.0:
		hurt_lock = maxf(0.0, hurt_lock - delta)
	var keys: = Input.get_vector("left", "right", "up", "down")
	var input_direction: = keys

	if MobileInput.controls_enabled and MobileInput.has_move_input():
		if not keys.is_zero_approx():
			input_direction = (keys + MobileInput.move_vector).limit_length(1.0)
		else:
			input_direction = MobileInput.move_vector

	if not input_direction.is_zero_approx():
		last_move_direction = input_direction.normalized()

	var look_target: = get_global_mouse_position()

	if MobileInput.controls_enabled:
		if not input_direction.is_zero_approx():
			look_target = global_position + input_direction
		elif velocity.length_squared() > 1.0:
			look_target = global_position + velocity
	var look_direction: = look_target - global_position
	playAnimation(look_direction)

	var dash_input_direction: = input_direction
	var want_dash: = Input.is_action_just_pressed("roll")
	if MobileInput.controls_enabled and MobileInput.consume_dash():
		want_dash = true


		if not MobileInput.dash_move_vector.is_zero_approx():
			dash_input_direction = MobileInput.dash_move_vector
	if want_dash and can_dash:
		_start_dash(dash_input_direction)

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

func _start_dash(input_direction: Vector2) -> void :
	if not can_dash or player_health <= 0: return
	can_dash = false
	dashing = true
	dash_grace_left = 0
	_sync_dash_hurt_area()

	if not input_direction.is_zero_approx():
		dash_direction = input_direction.normalized()
		last_move_direction = dash_direction
	elif MobileInput.controls_enabled:

		dash_direction = last_move_direction
	elif velocity.length_squared() > 100.0:
		dash_direction = velocity.normalized()
	else:
		var mouse_dir: = get_global_mouse_position() - global_position
		dash_direction = mouse_dir.normalized() if mouse_dir.length_squared() > 0.01 else last_move_direction

	velocity = dash_direction * DASH_SPEED
	dashing_timer.start()
	can_dasing_timer.start()
	shadow_timer.start()
	var feedback: = JUICE.find(self)
	if feedback != null: feedback.dash(global_position, dash_direction)

func _sync_dash_hurt_area() -> void :
	if hurt_area:
		hurt_area.set_deferred("monitoring", not is_dash_invulnerable())

func playAnimation(direction: Vector2):
	direction = direction.normalized()
	var snap = snappedf(direction.angle(), PI / 4) / (PI / 4)
	var index = wrapi(int(snap), 0, 8)
	animated_sprite_2d.play(animation_directions[index])

func _on_shadow_timer_timeout() -> void :
	if not dashing or velocity.length_squared() <= 1e-05:
		shadow_timer.stop()
		return
	var feedback: = JUICE.find(self)
	if feedback != null: feedback.ghost(animated_sprite_2d)

func _on_dashing_timer_timeout() -> void :
	if not dashing: return
	dashing = false
	dash_grace_left = DASH_GRACE_SECONDS
	_sync_dash_hurt_area()
	shadow_timer.stop()
	velocity = dash_direction * minf(SPEED * 1.35, DASH_SPEED * 0.35)
	dash_completed.emit(global_position)

func _on_can_dasing_timer_timeout() -> void :
	can_dash = true
	var feedback: = JUICE.find(self)
	if feedback != null and feedback.is_processing(): AudioManager.play_juice("ready")

func _on_area_2d_body_entered(body: Node2D) -> void :
	if body != null and body.has_method("deals_own_contact") and body.deals_own_contact():
		return
	var amount: = 60.0
	if body != null and body.has_method("get_touch_damage"):
		amount = float(body.get_touch_damage())
	receive_attack(amount, body)

func receive_attack(amount: float, _source: Node = null) -> void :
	if is_dash_invulnerable() or amount <= 0.0 or hurt_lock > 0.0 or player_health <= 0.0:
		return
	hurt_lock = HURT_INVULNERABILITY
	AudioManager.play_hit()
	play_hit_tween()
	var taken: = amount * (1.0 - clampf(damage_reduction, 0.0, 0.6)) * beast_damage_scale
	var absorbed: = minf(shield, taken)
	shield -= absorbed
	var hp_loss: = taken - absorbed
	var feedback: = JUICE.find(self)
	if feedback != null:
		var direction: = Vector2.ZERO
		if is_instance_valid(_source) and _source is Node2D:
			direction = (_source.global_position - global_position).normalized()
		feedback.hurt(global_position, direction, hp_loss <= 0)
	player_health = max(0.0, player_health - hp_loss)
	health_bar.set_health(player_health)
	_sync_shield_visuals()
	if hp_loss > 0.0:
		health_damaged.emit(hp_loss)
	if player_health <= 0.0:
		die()

func get_hit() -> void :
	receive_attack(60.0, null)

func play_hit_tween() -> void :
	_hurt_punch = 1.0
	if _hurt_tween != null and _hurt_tween.is_valid(): _hurt_tween.kill()
	animated_sprite_2d.modulate = Color(1, 0.3, 0.35)
	_hurt_tween = create_tween().set_loops(2)
	_hurt_tween.tween_property(animated_sprite_2d, "modulate", Color.WHITE, 0.06)
	_hurt_tween.tween_property(animated_sprite_2d, "modulate", Color(1, 0.5, 0.5), 0.04)
	_hurt_tween.tween_property(animated_sprite_2d, "modulate", Color.WHITE, 0.04)

func die() -> void :
	player_died.emit()

func play_ring_tween() -> void :
	if player_ring == null:
		return

	if ring_tween != null and ring_tween.is_valid():
		ring_tween.kill()
	player_ring.scale = Vector2.ONE
	player_ring.modulate = Color.WHITE
	player_ring.queue_redraw()
