extends CharacterBody2D
@export var player: CharacterBody2D
@onready var rush_timer: Timer = $RushTimer
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var base_sprite_position: Vector2 = $Sprite2D.position
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
var sprite_tint: Color = Color.WHITE
var fight_stage: int = 1
var hurt_tween: Tween
var hitstop_token: int = 0
var last_hitstop_msec: int = 0
const HITSTOP_COOLDOWN_MSEC: = 180
var _difficulty_applied: = false
var _last_particle_msec: = -10000
var poison_slow: = 1.0
enum ChargeState{WAIT, WARN, CHARGE, RECOVER}
const MAX_CHARGE_SECONDS: = 1.6
const MIN_CHARGE_DISTANCE: = 80.0
const CONTACT_INTERVAL: = 0.8
var charge_state: = ChargeState.WAIT
var _state_left: = 0.0
var _distance_left: = 0.0
var _contact_left: = 0.0
var _last_charge_direction: = Vector2.RIGHT
var charges_started: = 0
var _hurt_area: Area2D
var rush_feedback: Node2D
var warning_locked: = false
var _combo_left: = 0
var _attack_round: = 0
var _chain_warning: = false
const LOCK_SECONDS: = 0.34

func set_poison_exposure(active: bool, slow: float, tint: Color) -> void :
	poison_slow = slow if active else 1.0
	if sprite_2d: sprite_2d.self_modulate = tint if active else Color.WHITE

func apply_difficulty_health(multiplier: float) -> void :

	if _difficulty_applied:
		return
	_difficulty_applied = true
	health_max_value *= multiplier
	boss_current_health = health_max_value
	health_bar.init_health(health_max_value)

func configure_stage(stage: int) -> void :
	fight_stage = maxi(stage, 1)

func get_touch_damage() -> float:
	return 95.0 if fight_stage >= 2 else 60.0

func _ready() -> void :
	if fight_stage >= 2:
		health_max_value = 3600.0
		charge_speed = 760.0
		rush_ready_time = 0.42
		if rush_timer:
			rush_timer.wait_time = 0.7
		sprite_2d.modulate = Color(1.2, 0.75, 1.3, 1.0)
		sprite_2d.scale *= 1.06
	base_sprite_scale = sprite_2d.scale
	sprite_tint = sprite_2d.modulate
	_setup_health_bar()
	health_bar.init_health(health_max_value)
	boss_current_health = health_max_value

	line = Line2D.new()
	line.width = 1.2
	line.default_color = Color(1.0, 0.28, 0.24, 0.7)
	line.top_level = true
	line.z_index = 6
	add_child(line)
	line.global_transform = Transform2D.IDENTITY
	line.add_point(Vector2.ZERO)
	line.add_point(Vector2.ZERO)
	line.hide()
	rush_feedback = preload("res://script/boss_rush_feedback.gd").new()
	rush_feedback.boss = self
	add_child(rush_feedback)
	rush_timer.wait_time = 1.4

func enraged() -> bool:
	return boss_current_health <= health_max_value * 0.72

func warning_duration() -> float:
	if _chain_warning: return 1.3
	return 0.72 if enraged() else 0.86

func lock_seconds() -> float:

	return 1.1 if _chain_warning else LOCK_SECONDS

func _aim_charge() -> void :
	var direction: Vector2 = player.global_position - global_position
	charge_direction = direction.normalized() if direction.length_squared() > 0.001 else _last_charge_direction
	_last_charge_direction = charge_direction
	_distance_left = clampf(direction.length() + 60, MIN_CHARGE_DISTANCE, 420)
	target_position = global_position + charge_direction * _distance_left
	update_facing_direction(target_position)
	line.set_point_position(0, global_position)
	line.set_point_position(1, target_position)
	if rush_feedback != null: rush_feedback.path_changed()

func _setup_health_bar() -> void :
	health_bar.z_index = 20
	health_bar.visible = true
	health_bar.show_percentage = false

	var bar_size: = Vector2(140.0, 12.0)
	health_bar.position = Vector2( - bar_size.x * 0.5, -110.0)
	health_bar.size = bar_size
	health_bar.scale = Vector2.ONE
	health_bar.modulate = Color.WHITE

func _process(_delta: float) -> void :
	if is_dying:
		return
	_sync_outline_frame_uv()

func deals_own_contact() -> bool:
	return true

func suspend_feedback() -> void :
	if is_instance_valid(line): line.hide()
	if is_instance_valid(rush_feedback): rush_feedback.reset()

func _physics_process(delta: float) -> void :
	if is_dying or not is_instance_valid(player) or player.player_health <= 0 or get_tree().paused: return
	_contact_left = maxf(0, _contact_left - delta)
	match charge_state:
		ChargeState.WAIT:
			update_facing_direction(player.global_position)
			velocity = Vector2.ZERO
			if not rush_timer.is_stopped():
				var offset: = player.global_position - global_position
				velocity = offset.normalized() * (72 if enraged() else 58) * poison_slow if offset.length() > 135 else offset.normalized().orthogonal() * 22 * poison_slow
				move_and_collide(velocity * delta)
			var animation: StringName = &"walk" if velocity.length_squared() > 1.0 else &"idle"
			if animation_player.current_animation != animation or not animation_player.is_playing():
				animation_player.play(animation)
		ChargeState.WARN:
			_state_left = maxf(0, _state_left - delta)
			if not warning_locked:
				_aim_charge()
				if _state_left <= lock_seconds():
					warning_locked = true
					AudioManager.play_juice("boss_lock")
			line.default_color = Color(1, 0.25, 0.18, 0.9) if warning_locked else Color(1, 0.68, 0.26, 0.7)
			if _state_left <= 0: start_moving_charge()
		ChargeState.CHARGE:
			var step: = minf(maxf(delta, 0), _state_left)
			_state_left = maxf(0, _state_left - delta)
			var speed: = charge_speed * (1.12 if enraged() else 1.0)
			velocity = charge_direction * speed
			var distance: = minf(_distance_left, speed * step)
			var before: = global_position
			var collision: = move_and_collide(charge_direction * distance)
			_try_charge_sweep(before, global_position)
			_distance_left = maxf(0, _distance_left - distance)
			if collision != null or _distance_left <= 0.001 or _state_left <= 0:
				stop_charge()
		ChargeState.RECOVER:
			update_facing_direction(player.global_position)
			_state_left = maxf(0, _state_left - delta)
			if _state_left <= 0:
				charge_state = ChargeState.WAIT
				if _combo_left > 0:
					_combo_left -= 1
					start_charge_attack(true)
				else:
					rush_timer.wait_time = 1.4
					rush_timer.start()
	_try_contact_damage()

func _try_contact_damage() -> void :
	if charge_state != ChargeState.CHARGE: return
	if _contact_left > 0 or player.is_dash_invulnerable() or player.hurt_lock > 0: return
	if not is_instance_valid(_hurt_area): _hurt_area = player.get_node_or_null("Area2D")
	if _hurt_area != null and _hurt_area.overlaps_body(self):
		player.receive_attack(get_touch_damage(), self)
		_contact_left = CONTACT_INTERVAL

func _try_charge_sweep(before: Vector2, after: Vector2) -> void :
	if _contact_left > 0 or player.is_dash_invulnerable() or player.hurt_lock > 0: return
	if rush_feedback != null and rush_feedback.sweep_hits(before, after, player.global_position):
		player.receive_attack(get_touch_damage(), self)
		_contact_left = CONTACT_INTERVAL

func start_charge_attack(chained: bool = false) -> void :
	if is_dying or not is_instance_valid(player) or player.player_health <= 0 or charge_state != ChargeState.WAIT:
		return
	rush_timer.stop()
	_chain_warning = chained
	if not chained:
		_attack_round += 1
		_combo_left = 1 if enraged() and _attack_round % 2 == 0 else 0
	warning_locked = false
	animation_player.play("idle")
	_aim_charge()
	show_warning_line_and_then_charge(target_position)

func update_facing_direction(target_pos: Vector2) -> void :
	var offset_x := target_pos.x - global_position.x
	if absf(offset_x) > 1.0:
		sprite_2d.flip_h = offset_x < 0.0

func show_warning_line_and_then_charge(target_pos: Vector2) -> void :
	if is_dying:
		return
	line.set_point_position(0, global_position)
	line.set_point_position(1, target_pos)
	line.modulate = Color.WHITE
	line.show()
	charge_state = ChargeState.WARN
	_state_left = warning_duration()

func start_moving_charge() -> void :
	if is_dying or charge_state != ChargeState.WARN:
		return
	line.hide()
	charge_state = ChargeState.CHARGE
	_state_left = MAX_CHARGE_SECONDS
	is_charging = true
	charges_started += 1
	update_facing_direction(global_position + charge_direction * MIN_CHARGE_DISTANCE)
	AudioManager.play_juice("boss_rush")
	animation_player.play("chase")

func stop_charge() -> void :
	if is_dying or charge_state != ChargeState.CHARGE:
		return
	is_charging = false
	animation_player.play("idle")
	velocity = Vector2.ZERO
	if is_instance_valid(player): update_facing_direction(player.global_position)
	charge_state = ChargeState.RECOVER
	_state_left = 0.34 if _combo_left > 0 else (0.8 if enraged() else 0.64)

func set_player(player_var: Node2D) -> void :
	player = player_var
	_hurt_area = player.get_node_or_null("Area2D")

func _on_rush_timer_timeout() -> void :
	if is_dying or not player:
		return
	start_charge_attack()

func apply_hit(hit_data: Dictionary) -> void :
	if is_dying:
		return

	AudioManager.play_enemy_hurt()
	var damage_value: float = float(hit_data.get("damage", 0))
	var damage_dir: Vector2 = hit_data.get("direction", Vector2.ZERO)
	if damage_dir.length_squared() < 0.001:
		damage_dir = Vector2.RIGHT

	if not hit_data.get("ignore_side_bonus", false) and is_instance_valid(player) and player.has_method("get_side_damage_multiplier"):
		damage_value *= player.get_side_damage_multiplier(global_position)
	elif not hit_data.get("ignore_side_bonus", false) and get_tree().get_first_node_in_group("player") != null:
		var p: = get_tree().get_first_node_in_group("player")
		if p.has_method("get_side_damage_multiplier"):
			damage_value *= p.get_side_damage_multiplier(global_position)

	var critical_player: Node = player if is_instance_valid(player) else get_tree().get_first_node_in_group("player")
	var crit_multiplier := 1.0
	if critical_player != null and critical_player.has_method("roll_critical_multiplier"):
		crit_multiplier = critical_player.roll_critical_multiplier(hit_data)
	damage_value *= crit_multiplier
	var critical := crit_multiplier > 1.0
	var status_damage := preload("res://script/demage_text.gd").is_status_hit(hit_data)
	boss_current_health = max(0.0, boss_current_health - damage_value)
	if damage_value > 0 and (status_damage or critical):
		_show_damage_number(damage_value, status_damage, critical)
	if health_bar:
		health_bar.visible = true
		health_bar.set_health(boss_current_health)
	if not hit_data.get("from_status", false) and damage_value > 0.0:
		var steal_target: Node = player if is_instance_valid(player) else get_tree().get_first_node_in_group("player")
		if steal_target != null and steal_target.has_method("notify_damage_dealt"):
			steal_target.notify_damage_dealt(damage_value)

	play_hit_feedback(damage_dir.normalized())

	if boss_current_health <= health_max_value * 0.72:
		rush_ready_time = 0.25
		_apply_phase2_outline()

	if boss_current_health <= 0.0:
		await start_defeat_sequence()

func _show_damage_number(amount: float, status_damage: bool, critical: bool) -> void :
	if not preload("res://script/feedback_budget.gd").allow_popup(get_tree()): return
	var feedback: = preload("res://script/combat_feedback.gd").find(self)
	var container: Node = feedback.get_parent().effect_container if feedback != null else get_parent()
	var popup: Node = preload("res://scenes/damage_text.tscn").instantiate()
	container.add_child(popup)
	popup.global_position = global_position
	popup.show_damage(str(int(floor(amount))), global_position, 0, 0, status_damage, critical)

func _apply_phase2_outline() -> void :

	if sprite_2d == null:
		return
	if not (sprite_2d.material is ShaderMaterial):
		sprite_2d.material = load("res://shaders/rainbow_outline.tres").duplicate()
	_sync_outline_frame_uv()

func _sync_outline_frame_uv() -> void :
	if sprite_2d == null or not (sprite_2d.material is ShaderMaterial):
		return
	var mat: ShaderMaterial = sprite_2d.material
	var hf: = maxi(1, sprite_2d.hframes)
	var vf: = maxi(1, sprite_2d.vframes)
	var frame: = sprite_2d.frame
	var col: = frame % hf
	var row: = int(frame / hf) % vf
	var fw: = 1.0 / float(hf)
	var fh: = 1.0 / float(vf)
	mat.set_shader_parameter("frame_uv_rect", Vector4(float(col) * fw, float(row) * fh, fw, fh))

func play_hit_feedback(hit_dir: Vector2) -> void :
	var feedback: = preload("res://script/combat_feedback.gd").find(self)
	if feedback != null: feedback.hit(global_position, hit_dir, true)
	var now: = Time.get_ticks_msec()
	if now - _last_particle_msec >= 80:
		_last_particle_msec = now
		_spawn_hit_particles(hit_dir)
	_play_hit_deform(hit_dir)
	_request_hitstop(0.42, 0.022)

func _play_hit_deform(hit_dir: Vector2) -> void :
	if hurt_tween != null and hurt_tween.is_valid():
		hurt_tween.kill()

	sprite_2d.modulate = Color(1.45, 1.45, 1.35)
	var squash: = Vector2(
		base_sprite_scale.x * (1.0 + absf(hit_dir.x) * 0.18), 
		base_sprite_scale.y * (1.0 - absf(hit_dir.x) * 0.1 + absf(hit_dir.y) * 0.14)
	)
	if absf(hit_dir.y) > absf(hit_dir.x):
		squash = Vector2(
			base_sprite_scale.x * (1.0 - 0.1), 
			base_sprite_scale.y * (1.0 + 0.22)
		)

	var knock_offset: = hit_dir * 6.0


	var origin: = base_sprite_position

	hurt_tween = create_tween()
	hurt_tween.set_parallel(true)
	hurt_tween.tween_property(sprite_2d, "scale", squash, 0.02).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hurt_tween.tween_property(sprite_2d, "position", origin + knock_offset, 0.02)
	hurt_tween.set_parallel(false)
	hurt_tween.tween_property(sprite_2d, "modulate", sprite_tint, 0.04)
	hurt_tween.set_parallel(true)
	hurt_tween.tween_property(sprite_2d, "scale", base_sprite_scale, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hurt_tween.tween_property(sprite_2d, "position", origin, 0.06)

func _request_hitstop(scale: float, duration_real: float) -> void :
	var now: = Time.get_ticks_msec()
	if now - last_hitstop_msec < HITSTOP_COOLDOWN_MSEC:
		return
	last_hitstop_msec = now

	hitstop_token += 1
	var token: = hitstop_token
	Engine.time_scale = scale
	await get_tree().create_timer(duration_real, true, false, true).timeout
	if token == hitstop_token and not is_dying and not get_tree().has_meta("player_death_slowmo"):
		Engine.time_scale = 1.0

func _spawn_hit_particles(hit_dir: Vector2) -> void :
	var feedback: = preload("res://script/combat_feedback.gd").find(self)
	if feedback != null:
		feedback.spray(global_position, - hit_dir, Color(1, 0.95, 0.75), 14, 220)
		return
	var particles: = CPUParticles2D.new()
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.amount = 14
	particles.lifetime = 0.28
	particles.emitting = false
	particles.direction = - hit_dir
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

func start_defeat_sequence() -> void :
	if is_dying:
		return
	is_dying = true
	if rush_feedback != null: rush_feedback.reset()
	var feedback: = preload("res://script/combat_feedback.gd").find(self)
	if feedback != null: feedback.reward(global_position, true)
	is_charging = false
	velocity = Vector2.ZERO
	rush_timer.stop()
	collision_shape_2d.set_deferred("disabled", true)
	animation_player.pause()

	if is_instance_valid(line):
		line.queue_free()
		line = null


	hitstop_token += 1


	Engine.time_scale = 0.06
	sprite_2d.modulate = Color(3.0, 3.0, 3.0, 1.0)
	_spawn_death_burst(28, Color(1.0, 1.0, 1.0, 1.0))
	await get_tree().create_timer(0.21, true, false, true).timeout


	Engine.time_scale = 0.2
	_play_defeat_deform()
	_spawn_death_burst(40, Color(1.0, 0.55, 0.2, 1.0))
	await get_tree().create_timer(0.77, true, false, true).timeout


	Engine.time_scale = 1.0
	boss_defeated.emit()
	queue_free()

func _play_defeat_deform() -> void :
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

func _spawn_death_burst(amount: int, color: Color) -> void :
	var particles: = CPUParticles2D.new()
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

func _add_to_effect_container(node: Node) -> void :
	var container: = get_tree().get_first_node_in_group("effect_container")
	if container != null:
		container.add_child(node)
	else:
		get_tree().current_scene.add_child(node)
