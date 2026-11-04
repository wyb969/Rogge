extends CharacterBody2D
@export var player_reference: CharacterBody2D
@onready var sprite_2d: Sprite2D = $Sprite2D

@onready var damage_text = preload("res://scenes/damage_text.tscn")
@onready var coin = preload("res://scenes/coin.tscn")
const PROJECTILE_SCENE: = preload("res://scenes/enemy_projectile.tscn")
const FEEDBACK_BUDGET: = preload("res://script/feedback_budget.gd")
const JUICE: = preload("res://script/combat_feedback.gd")
var _hit_recoil: = Vector2.ZERO

var direction: Vector2
var speed: float = 50
var knockback: Vector2 = Vector2.ZERO
var knockback_decay: float = 10.0
var _airflow_velocity := Vector2.ZERO
var _airflow_left := 0.0
var _gravity_velocity := Vector2.ZERO
var _gravity_left := 0.0

const DASHER_MAX_HEALTH: = 20.0
const DASH_AIM_SECONDS: = 0.4
const DASH_LOCK_SECONDS: = 0.2
const DASH_WINDUP_SECONDS: = DASH_AIM_SECONDS + DASH_LOCK_SECONDS
const DASH_SECONDS: = 0.22
const DASH_JUMP_HEIGHT: = 14.0
const DASH_MAX_CONCURRENT: = 3
const DASH_DAMAGE_MULTIPLIER: = 1.25
const DASHER_CONTACT_RECOVERY: = 0.9
var contact_recovery_left: = 0.0

var health: float = 10
var damage: float = 2
var is_elite: bool = false
var _death_started: bool = false
var _hit_flash_left: = 0.0
var _game_ref: WeakRef
signal death_signal

var archetype: EnemyData.Archetype = EnemyData.Archetype.CHASER
var defense: float = 0.0
var body_scale: float = 1.0
var contact_damage: float = 46.0
var contact_cooldown: float = 0.8
var contact_radius: float = 26.0
var contact_timer: float = 0.15
var dash_speed: float = 260.0
var dash_cooldown: float = 2.0
var dash_timer: float = 0.4
var dash_windup: float = 0.0
var dash_time_left: float = 0.0
var is_dashing: bool = false
var dash_dir: Vector2 = Vector2.ZERO
var preferred_range: float = 200.0
var projectile_damage: float = 36.0
var projectile_speed: float = 150.0
var attack_cooldown: float = 1.4
var attack_timer: float = 0.55
var shot_windup: float = 0.0
var shots_fired: int = 0
var slam_windup: float = 0.0
var slam_time_left: float = 0.0
var slam_dir: Vector2 = Vector2.ZERO
var marker_color: Color = Color(0.8, 0.8, 0.85, 1)


var burn_stacks: int = 0
var burn_dps: float = 2.0
var burn_tick: float = 0.0
const MAX_BURN_STACKS: = 10
const BURN_SPREAD_RADIUS: = 78.0


var freeze_time: float = 0.0
var freeze_slow: float = 0.5
var poison_slow: = 1.0
var _poison_tint: = Color.WHITE
var base_modulate: Color = Color.WHITE
var _sprite_base_scale: Vector2 = Vector2.ONE
var _wobble: float = 0.0
var _move_effort: float = 0.0
var _hit_squash: float = 0.0

func _ready() -> void :
	set_process(false)
	queue_redraw()
	_apply_body_scale()
	if sprite_2d:
		_sprite_base_scale = sprite_2d.scale
		sprite_2d.modulate = base_modulate

func _draw() -> void :
	if archetype == EnemyData.Archetype.DASHER and contact_recovery_left > 0.0:
		var unit: = 1.0 / maxf(body_scale, 0.4)
		draw_arc(Vector2(0, 11) * unit, 8 * unit, - PI * 0.5, - PI * 0.5 + TAU * contact_recovery_left / DASHER_CONTACT_RECOVERY, 16, Color(0.85, 0.92, 1, 0.65), 1.2 * unit, false)
	if archetype == EnemyData.Archetype.DASHER and (dash_windup > 0.0 or is_dashing):
		var unit: = 1.0 / maxf(body_scale, 0.4)
		var lift: = dash_jump_height() / DASH_JUMP_HEIGHT
		draw_set_transform(Vector2(0, 7) * unit, 0.0, Vector2(unit, unit * 0.38))
		draw_circle(Vector2.ZERO, lerpf(9.0, 6.0, lift), Color(0.015, 0.01, 0.025, 0.4))
		draw_set_transform(Vector2.ZERO)
	draw_circle(Vector2(0, 14), 3.4, marker_color)
	if archetype == EnemyData.Archetype.DASHER and dash_windup > 0.0:


		var unit: = 1.0 / maxf(body_scale, 0.4)
		var progress: = clampf((DASH_WINDUP_SECONDS - dash_windup) / DASH_AIM_SECONDS, 0.0, 1.0)
		var eased: = smoothstep(0.0, 1.0, progress)
		var length: = dash_speed * DASH_SECONDS * lerpf(0.82, 1.0, eased)
		var arrow: = PackedVector2Array([
			Vector2(7, -3.5), Vector2(length - 15, -3.5), Vector2(length - 15, -9), 
			Vector2(length, 0), Vector2(length - 15, 9), Vector2(length - 15, 3.5), Vector2(7, 3.5), 
		])
		draw_set_transform(Vector2.ZERO, dash_dir.angle(), Vector2.ONE * unit)
		draw_colored_polygon(arrow, Color(0.78, 0.035, 0.07, 0.65).lerp(Color(1.0, 0.24, 0.3, 0.95), eased))
		var border: = arrow.duplicate()
		border.append(arrow[0])
		draw_polyline(border, Color(0.13, 0.01, 0.025, 0.9), 2.0, true)
		var tip: = lerpf(10.0, length - 17.0, eased)
		draw_line(Vector2(maxf(8.0, tip - 10.0), 0), Vector2(tip, 0), Color(1.0, 0.7, 0.72, 0.8), 2.0, true)
		draw_set_transform(Vector2.ZERO)

func dash_warning_locked() -> bool:
	return dash_windup > 0.0 and dash_windup <= DASH_LOCK_SECONDS + 1e-05

func dash_jump_height() -> float:
	if not is_dashing:
		return 0.0
	var progress: = clampf(1.0 - dash_time_left / DASH_SECONDS, 0.0, 1.0)
	return sin(progress * PI) * DASH_JUMP_HEIGHT

func deals_own_contact() -> bool:
	return true

func set_enemy_data(data: EnemyData) -> void :
	if data == null:
		return
	var desired_size: = Vector2(20, 20)
	if data.sprite:
		$Sprite2D.texture = data.sprite
		var tex_size = data.sprite.get_size()
		if tex_size.x > 0 and tex_size.y > 0:
			$Sprite2D.scale = desired_size / tex_size
	health = data.health
	damage = data.damage
	archetype = data.archetype
	contact_recovery_left = 0.0
	if archetype == EnemyData.Archetype.DASHER:
		add_to_group("dash_enemies")
	else:
		remove_from_group("dash_enemies")
	speed = data.move_speed
	defense = clampf(data.defense, 0.0, 0.75)
	body_scale = maxf(data.body_scale, 0.4)
	base_modulate = data.tint
	marker_color = data.marker_color
	contact_damage = data.contact_damage
	contact_cooldown = data.contact_cooldown
	contact_radius = data.contact_radius
	dash_speed = data.dash_speed
	dash_cooldown = data.dash_cooldown
	preferred_range = data.preferred_range
	projectile_damage = data.projectile_damage
	projectile_speed = data.projectile_speed
	attack_cooldown = data.attack_cooldown
	attack_timer = minf(0.55, attack_cooldown)

	dash_timer = randf_range(0.6, 1.4) if archetype == EnemyData.Archetype.DASHER else 0.35
	_sprite_base_scale = ($Sprite2D as Sprite2D).scale
	_apply_body_scale()

func set_elite_status() -> void :
	is_elite = true
	var sprite: Sprite2D = $Sprite2D
	var mat: ShaderMaterial = load("res://shaders/rainbow_outline.tres").duplicate()
	mat.set_shader_parameter("outline_color", preload("res://script/visual_style.gd").ELITE)
	var hf: = maxi(1, sprite.hframes)
	var vf: = maxi(1, sprite.vframes)

	if hf > 1 or vf > 1:
		var fw: = 1.0 / float(hf)
		var fh: = 1.0 / float(vf)
		mat.set_shader_parameter("frame_uv_rect", Vector4(0.0, 0.0, fw, fh))
	sprite.material = mat
	body_scale *= 1.28
	_apply_body_scale()
	setHealth(health * 1.75)
	contact_damage *= 1.2
	projectile_damage *= 1.15

func setHealth(hp: float) -> void :
	health = minf(hp, DASHER_MAX_HEALTH) if archetype == EnemyData.Archetype.DASHER else hp

func setDamage(dg: float) -> void :
	damage = dg

func scale_offense(mult: float) -> void :
	damage *= mult
	contact_damage *= mult
	projectile_damage *= mult

func set_player_ref(player_ref: CharacterBody2D) -> void :
	player_reference = player_ref
	if player_ref != null and player_ref.get_parent() != null and player_ref.get_parent().has_method("spawn_xp_coin"):
		_game_ref = weakref(player_ref.get_parent())

func _game_owner() -> Node:
	var owner: Node = _game_ref.get_ref() if _game_ref != null else null
	if owner == null:
		owner = get_tree().get_first_node_in_group("game")
		if owner != null: _game_ref = weakref(owner)
	return owner

func _player_owner() -> Node:
	return player_reference if is_instance_valid(player_reference) else get_tree().get_first_node_in_group("player")

func _process(delta: float) -> void :
	_hit_flash_left = maxf(0, _hit_flash_left - delta)
	sprite_2d.self_modulate = _poison_tint * Color.WHITE.lerp(preload("res://script/visual_style.gd").HIT_FLASH, clampf(_hit_flash_left / 0.065, 0, 1))
	if _hit_flash_left == 0: set_process(false)

func is_frozen() -> bool:
	return freeze_time > 0.0

func status_move_scale() -> float:
	return minf(freeze_slow if is_frozen() else 1.0, poison_slow)

func set_poison_exposure(active: bool, slow: float, tint: Color) -> void :
	poison_slow = slow if active else 1.0
	_poison_tint = tint if active else Color.WHITE
	if sprite_2d:
		sprite_2d.self_modulate = _poison_tint * Color.WHITE.lerp(preload("res://script/visual_style.gd").HIT_FLASH, clampf(_hit_flash_left / 0.065, 0, 1))

func crowd_control_scale() -> float:
	# Larger bodies and elites resist displacement; bosses use a different base.
	return clampf(1.0 / pow(maxf(body_scale, 1.0), 1.5), 0.25, 1.0) * (0.65 if is_elite else 1.0)

func apply_airflow(push_velocity: Vector2, seconds: float) -> void:
	if _death_started: return
	_airflow_velocity = push_velocity.limit_length(500.0) * crowd_control_scale()
	_airflow_left = clampf(seconds, 0.0, 0.45)
	if archetype == EnemyData.Archetype.DASHER:
		_finish_dash()
		dash_timer = maxf(dash_timer, 0.75)
	shot_windup = 0.0
	slam_windup = 0.0
	slam_time_left = 0.0
	attack_timer = maxf(attack_timer, _airflow_left)
	queue_redraw()

func clear_airflow() -> void:
	_airflow_velocity = Vector2.ZERO
	_airflow_left = 0.0

func apply_gravity_pull(pull_velocity: Vector2, seconds: float) -> void:
	if _death_started: return
	# Refresh a bounded velocity, never add impulses every scan.
	_gravity_velocity = pull_velocity.limit_length(280.0) * crowd_control_scale()
	_gravity_left = clampf(seconds, 0.0, 0.2)

func clear_gravity_pull() -> void:
	_gravity_velocity = Vector2.ZERO
	_gravity_left = 0.0

func _apply_crowd_motion(delta: float) -> void:
	if delta <= 0.0: return
	if _airflow_left > 0.0:
		var step := minf(delta, _airflow_left)
		var decay := exp(-5.0 * step)
		# Integrate the decaying push so displacement is stable across frame rates.
		velocity = velocity * (1.0 - step / delta) + _airflow_velocity * ((1.0 - decay) / (5.0 * delta))
		_airflow_velocity *= decay
		_airflow_left = maxf(0.0, _airflow_left - delta)
	if _gravity_left > 0.0:
		velocity += _gravity_velocity * (minf(delta, _gravity_left) / delta)
		_gravity_left = maxf(0.0, _gravity_left - delta)

func _physics_process(delta: float) -> void :
	if _death_started or not is_instance_valid(player_reference):
		return

	_update_statuses(delta)
	if _death_started:
		return
	contact_timer = maxf(0.0, contact_timer - delta)
	var recovering: = archetype == EnemyData.Archetype.DASHER and contact_recovery_left > 0.0

	var to_player: = player_reference.global_position - global_position
	var dist: = to_player.length()
	var dir: = to_player / dist if dist > 0.001 else Vector2.ZERO
	var move_speed: = speed
	move_speed *= status_move_scale()

	match archetype:
		EnemyData.Archetype.DASHER:
			_steer_dasher(delta, dir, dist, move_speed)
		EnemyData.Archetype.TANK:
			_steer_tank(delta, dir, dist, move_speed)
		EnemyData.Archetype.RANGED:
			_steer_ranged(delta, dir, dist, move_speed)
		_:
			_steer_chaser(dir, move_speed)
	if recovering and _airflow_left <= 0.0 and _gravity_left <= 0.0:


		knockback = Vector2.ZERO
		_apply_move_juice(delta)
		return

	if knockback.length() > 0.1:
		velocity += knockback
		knockback = knockback.move_toward(Vector2.ZERO, knockback_decay * delta)
	_apply_crowd_motion(delta)
	var collision = move_and_collide(velocity * delta)
	if collision:
		if collision.get_collider() is CharacterBody2D:
			var other = collision.get_collider()
			var away = (global_position - other.global_position).normalized()
			knockback = away * 10.0

	if is_instance_valid(player_reference):
		_try_contact(global_position.distance_to(player_reference.global_position))
	_face(dash_dir if archetype == EnemyData.Archetype.DASHER and (dash_windup > 0.0 or is_dashing) else dir)
	_apply_move_juice(delta)

func _steer_chaser(dir: Vector2, move_speed: float) -> void :
	velocity = dir * move_speed

func _steer_dasher(delta: float, dir: Vector2, dist: float, move_speed: float) -> void :
	queue_redraw()
	if contact_recovery_left > 0.0:
		contact_recovery_left = maxf(0.0, contact_recovery_left - delta)
		velocity = Vector2.ZERO
		return
	if is_dashing:
		if dash_time_left <= 0.0:
			_finish_dash()
			velocity = Vector2.ZERO
			return
		var step_time: = minf(delta, dash_time_left)
		dash_time_left = maxf(0.0, dash_time_left - delta)
		var dash_mul: = status_move_scale()


		velocity = dash_dir * dash_speed * dash_mul * step_time / maxf(delta, 1e-06)
		if sprite_2d:
			sprite_2d.modulate = Color(1.7, 0.55, 0.35, 1)
		return

	if dash_windup > 0.0:
		if not dash_warning_locked() and not dir.is_zero_approx():
			var aim_step: = minf(delta, dash_windup - DASH_LOCK_SECONDS)
			dash_dir = Vector2.RIGHT.rotated(lerp_angle(dash_dir.angle(), dir.angle(), 1.0 - exp(-16.0 * aim_step)))
		dash_windup = maxf(0.0, dash_windup - delta)
		velocity = Vector2.ZERO
		if sprite_2d:
			sprite_2d.modulate = Color(1.4, 0.85, 0.4, 1)
		if dash_windup <= 1e-06 and not is_frozen():
			dash_windup = 0.0
			is_dashing = true
			dash_time_left = DASH_SECONDS
		elif dash_windup <= 1e-06:
			_finish_dash()
		return

	dash_timer -= delta
	velocity = dir * move_speed
	if dash_timer <= 0.0 and dist < 180.0 and dist > 46.0 and not is_frozen():
		if _dash_slot_available():
			dash_windup = DASH_WINDUP_SECONDS
			dash_dir = dir
			velocity = Vector2.ZERO
		else:
			dash_timer = randf_range(0.15, 0.35)

func _dash_slot_available() -> bool:
	var committed: = 0
	for enemy in get_tree().get_nodes_in_group("dash_enemies"):
		if enemy == self or enemy._death_started or enemy.is_queued_for_deletion() or enemy.player_reference != player_reference:
			continue
		if enemy.is_dashing or enemy.dash_windup > 0.0:
			committed += 1
			if committed >= DASH_MAX_CONCURRENT:
				return false
	return true

func _finish_dash() -> void :
	is_dashing = false
	dash_windup = 0.0
	dash_time_left = 0.0
	dash_timer = dash_cooldown + randf_range(0.0, 0.4)
	if sprite_2d and freeze_time <= 0.0 and burn_stacks <= 0:
		sprite_2d.modulate = base_modulate

func _begin_contact_recovery() -> void :
	if is_dashing:
		_finish_dash()
	else:
		dash_windup = 0.0
		dash_time_left = 0.0
		dash_timer = maxf(dash_timer, dash_cooldown)
	contact_recovery_left = DASHER_CONTACT_RECOVERY
	contact_timer = maxf(contact_timer, DASHER_CONTACT_RECOVERY)
	velocity = Vector2.ZERO
	knockback = Vector2.ZERO
	_move_effort = 0.0
	queue_redraw()

func _steer_tank(delta: float, dir: Vector2, dist: float, move_speed: float) -> void :
	if slam_time_left > 0.0:
		slam_time_left -= delta
		velocity = slam_dir * move_speed * 3.4
		if sprite_2d:
			sprite_2d.modulate = Color(0.75, 0.85, 1.5, 1)
		if slam_time_left <= 0.0 and sprite_2d and freeze_time <= 0.0 and burn_stacks <= 0:
			sprite_2d.modulate = base_modulate
		return

	if slam_windup > 0.0:
		slam_windup -= delta
		velocity = Vector2.ZERO
		if sprite_2d:
			sprite_2d.modulate = Color(0.45, 0.6, 1.35, 1)
		if slam_windup <= 0.0 and not is_frozen():
			slam_time_left = 0.22
			slam_dir = dir if dir.length_squared() > 0.001 else Vector2.RIGHT
		elif slam_windup <= 0.0 and sprite_2d:
			sprite_2d.modulate = base_modulate
		return

	attack_timer -= delta
	velocity = dir * move_speed
	if attack_timer <= 0.0 and dist < 120.0 and not is_frozen():
		slam_windup = 0.36
		attack_timer = maxf(attack_cooldown, 1.35)

func _steer_ranged(delta: float, dir: Vector2, dist: float, move_speed: float) -> void :
	if shot_windup > 0.0:
		shot_windup -= delta
		velocity = - dir * move_speed * 0.35
		if sprite_2d:
			sprite_2d.modulate = Color(1.45, 1.35, 0.45, 1)
		if shot_windup <= 0.0:
			if not is_frozen():
				_fire_projectile(dir)
			if sprite_2d and freeze_time <= 0.0 and burn_stacks <= 0:
				sprite_2d.modulate = base_modulate
		return

	attack_timer -= delta
	var inner: = preferred_range * 0.72
	var outer: = preferred_range * 1.28
	if dist < inner:
		velocity = - dir * move_speed
	elif dist > outer:
		velocity = dir * move_speed * 0.9
	else:
		var strafe: = Vector2( - dir.y, dir.x)
		if int(Time.get_ticks_msec() / 1300) % 2 == 0:
			strafe = - strafe
		var correct: = clampf(preferred_range - dist, -40.0, 40.0) / 40.0
		velocity = strafe * move_speed * 0.85 + dir * correct * move_speed * 0.35

	if attack_timer <= 0.0 and dist < preferred_range + 150.0 and dist > 70.0 and not is_frozen():
		shot_windup = 0.2
		attack_timer = attack_cooldown

func _fire_projectile(dir: Vector2) -> void :
	if dir.length_squared() < 0.001:
		return
	var shot: = PROJECTILE_SCENE.instantiate()
	var aim: = dir.normalized()
	var container: = get_tree().get_first_node_in_group("effect_container")
	if container == null:
		container = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	container.add_child(shot)
	shot.launch(global_position + aim * 16.0, aim, projectile_speed, projectile_damage, marker_color)
	shots_fired += 1

func _try_contact(dist: float) -> void :
	if _death_started or is_queued_for_deletion() or (archetype == EnemyData.Archetype.DASHER and (dash_windup > 0.0 or contact_recovery_left > 0.0)):
		return
	if archetype == EnemyData.Archetype.RANGED:
		return
	if contact_timer > 0.0 or not is_instance_valid(player_reference):
		return
	var radius: = contact_radius
	var dmg: = contact_damage
	var cd: = contact_cooldown
	if archetype == EnemyData.Archetype.DASHER and is_dashing:
		radius += 8.0
		dmg *= DASH_DAMAGE_MULTIPLIER
	if archetype == EnemyData.Archetype.TANK and slam_time_left > 0.0:
		radius = maxf(radius, 48.0)
		dmg *= 1.8
		cd = 0.4
	if dist > radius:
		return
	if not player_reference.has_method("receive_attack"):
		return
	player_reference.receive_attack(dmg, self)
	contact_timer = cd
	if archetype == EnemyData.Archetype.DASHER:

		_begin_contact_recovery()

func _apply_body_scale() -> void :
	scale = Vector2(body_scale, body_scale)



func move_wobble_hz() -> float:
	var profile: = _juice_profile()
	var quickness: = clampf(speed / 56.0, 0.35, 2.6) / clampf(body_scale, 0.55, 2.2)
	return clampf(2.4 * quickness * profile.x, 1.6, 3.2)

func _juice_profile() -> Vector3:

	match archetype:
		EnemyData.Archetype.DASHER:
			return Vector3(1.12, 0.8, 1.12)
		EnemyData.Archetype.TANK:
			return Vector3(0.7, 0.65, 1.2)
		EnemyData.Archetype.RANGED:
			return Vector3(0.95, 0.85, 0.95)
		_:
			return Vector3(1.0, 1.0, 1.0)

func _apply_move_juice(delta: float) -> void :
	if sprite_2d == null:
		return
	var cruise: = maxf(speed, 8.0)

	var target: = clampf(velocity.length() / cruise, 0.0, 1.0)
	_move_effort = move_toward(_move_effort, target, delta * 6.0)
	_hit_squash = maxf(0.0, _hit_squash - delta * 5.0)
	var effort: = _move_effort
	_wobble += delta * TAU * move_wobble_hz() * maxf(effort, 0.0)
	var profile: = _juice_profile()
	var size_factor: = clampf(body_scale, 0.55, 2.2)
	var quickness: = clampf(speed / 56.0, 0.35, 2.6) / size_factor

	var lean: = deg_to_rad(clampf(2.0 + 1.0 / size_factor, 1.8, 3.6) * profile.y) * effort
	var stretch: = clampf(0.04 * quickness * profile.z, 0.03, 0.07) * effort
	var step: = sin(_wobble)
	var squash: = sin(_wobble * 2.0)
	var sx: = 1.0 + squash * stretch + _hit_squash * 0.1
	var sy: = 1.0 - squash * stretch * 0.85 - _hit_squash * 0.07
	if dash_windup > 0.0 or slam_windup > 0.0 or shot_windup > 0.0:
		sx *= 1.05
		sy *= 0.96
	if archetype == EnemyData.Archetype.DASHER and dash_windup > 0.0:
		var crouch: = clampf(1.0 - dash_windup / DASH_WINDUP_SECONDS, 0.0, 1.0)
		sx *= 1.0 + crouch * 0.08
		sy *= 1.0 - crouch * 0.14
	sprite_2d.rotation = step * lean
	sprite_2d.scale = Vector2(_sprite_base_scale.x * sx, _sprite_base_scale.y * sy)
	var sway: = (1.2 / size_factor) * effort
	sprite_2d.position = Vector2(step * sway, - abs(squash) * (1.1 + stretch * 8.0))
	_hit_recoil = _hit_recoil.lerp(Vector2.ZERO, 1.0 - exp( - delta * 22))
	sprite_2d.position += _hit_recoil
	if archetype == EnemyData.Archetype.DASHER:
		sprite_2d.position.y -= dash_jump_height() / maxf(body_scale, 0.4)
		if contact_recovery_left > 0.0:
			sprite_2d.scale *= Vector2(1.12, 0.85)
			sprite_2d.position.y += 2.0 / maxf(body_scale, 0.4)
			sprite_2d.rotation = 0

func _face(dir: Vector2) -> void :
	if sprite_2d == null:
		return
	var face: = velocity if absf(velocity.x) > 2.0 else dir
	if absf(face.x) > 0.01:
		sprite_2d.flip_h = face.x < 0.0

func _update_statuses(delta: float) -> void :
	if freeze_time > 0.0:
		freeze_time = maxf(0.0, freeze_time - delta)
		if sprite_2d and not is_dashing and slam_windup <= 0.0 and shot_windup <= 0.0:
			sprite_2d.modulate = Color(0.55, 0.85, 1.2, 1.0)
		if freeze_time <= 0.0 and burn_stacks <= 0 and sprite_2d:
			sprite_2d.modulate = base_modulate

	if burn_stacks > 0:
		if sprite_2d and freeze_time <= 0.0 and not is_dashing and shot_windup <= 0.0 and slam_windup <= 0.0:
			sprite_2d.modulate = Color(1.25, 0.55, 0.25, 1.0)
		burn_tick += delta
		if burn_tick >= 0.45:
			burn_tick = 0.0
			var tick_damage: = float(burn_stacks) * burn_dps * 0.45
			_take_status_damage(tick_damage)
			_try_spread_burn()
			burn_stacks = max(burn_stacks - 1, 0)
			if burn_stacks <= 0 and freeze_time <= 0.0 and sprite_2d and not is_dashing:
				sprite_2d.modulate = base_modulate

func _mitigate(raw: float) -> float:
	var dealt: = raw * (1.0 - clampf(defense, 0.0, 0.75))
	if raw > 0.0:
		dealt = maxf(dealt, 1.0)
	return dealt

func receive_hit(direction: Vector2, damage_value: float, status_damage: bool = false, critical: bool = false) -> float:
	if _death_started or damage_value <= 0: return 0.0
	var dealt: = _mitigate(damage_value)
	var feedback: = JUICE.find(self)
	if feedback != null: feedback.hit(global_position, direction, is_elite)
	play_hit_tween(direction)
	show_damage_text(dealt, status_damage, critical)
	AudioManager.play_enemy_hurt()
	_apply_health_loss(dealt)
	return dealt

func apply_hit(hit_data: Dictionary) -> void :
	var status_damage: = preload("res://script/demage_text.gd").is_status_hit(hit_data)
	var damage_value = float(hit_data.get("damage", 0))
	var damage_dir: Vector2 = hit_data.get("direction", Vector2.ZERO)
	var player_node: = _player_owner()
	if player_node != null and player_node.has_method("get_side_damage_multiplier"):
		damage_value *= player_node.get_side_damage_multiplier(global_position)


	var game: = _game_owner()
	if is_frozen() and game != null and game.get("freeze_controller") != null:
		var fc = game.freeze_controller
		if fc != null and fc.level > 0:
			damage_value *= 1.0 + fc.get_frozen_bonus()
			status_damage = true

	var crit_multiplier := 1.0
	if player_node != null and player_node.has_method("roll_critical_multiplier"):
		crit_multiplier = player_node.roll_critical_multiplier(hit_data)
	var dealt: float = receive_hit(damage_dir, damage_value * crit_multiplier, status_damage, crit_multiplier > 1.0)
	if not hit_data.get("from_status", false):
		_report_lifesteal(dealt)

	var effect_type = hit_data.get("effect", "")
	match effect_type:
		"burn":
			apply_burn(hit_data)
		"freeze":
			apply_freeze(hit_data)
		"shock":
			apply_shock(hit_data)
		"lightning":
			apply_lightning(hit_data)


	if game != null:
		_try_passive_procs(game, hit_data)

func _try_passive_procs(game: Node, hit_data: Dictionary) -> void :

	if hit_data.get("from_status", false):
		return
	var mc = game.get("molotov_controller")
	if mc != null and mc.level > 0 and randf() < mc.get_on_hit_chance():
		apply_burn({
			"burn_stacks": mc.get_on_hit_stacks(), 
			"burn_dps": mc.get_burn_dps() * 0.65
		})
	var fc = game.get("freeze_controller")
	if fc != null and fc.level > 0 and randf() < fc.get_on_hit_chance():
		apply_freeze({
			"freeze_duration": fc.get_freeze_duration(), 
			"slow_factor": fc.get_slow_factor()
		})

func _report_lifesteal(dealt: float) -> void :
	if dealt <= 0.0:
		return
	var player_node: = _player_owner()
	if player_node != null and player_node.has_method("notify_damage_dealt"):
		player_node.notify_damage_dealt(dealt)

func apply_lightning(hit_data: Dictionary) -> void :
	var source = hit_data.get("source", null)
	if source == null:
		return
	if not source.has_method("trigger_chain_lightning"):
		return
	source.trigger_chain_lightning(self, hit_data)

func apply_burn(hit_data: Dictionary) -> void :
	var add_stacks: int = int(hit_data.get("burn_stacks", 1))
	burn_stacks = mini(burn_stacks + add_stacks, MAX_BURN_STACKS)
	burn_dps = maxf(burn_dps, float(hit_data.get("burn_dps", burn_dps)))
	if sprite_2d and freeze_time <= 0.0 and not is_dashing:
		sprite_2d.modulate = Color(1.25, 0.55, 0.25, 1.0)

func apply_freeze(hit_data: Dictionary) -> void :
	freeze_time = maxf(freeze_time, float(hit_data.get("freeze_duration", 1.2)))
	freeze_slow = float(hit_data.get("slow_factor", 0.5))
	if sprite_2d and not is_dashing:
		sprite_2d.modulate = Color(0.55, 0.85, 1.2, 1.0)

func apply_shock(_hit_data: Dictionary) -> void :
	pass

func _try_spread_burn() -> void :
	if burn_stacks < 2:
		return
	if randf() > 0.4:
		return
	var game: = _game_owner()
	if game != null and game.get("burn_spread") != null:
		game.burn_spread.request(self, burn_dps * 0.85)
		return

	for entry in CombatTargets._entries:
		if not CombatTargets._live(entry, &"EnemyGroup"): continue
		var enemy: Node2D = entry.actor
		if enemy == self or not is_instance_valid(enemy):
			continue
		if not (enemy is Node2D):
			continue
		if global_position.distance_squared_to(enemy.global_position) > BURN_SPREAD_RADIUS * BURN_SPREAD_RADIUS:
			continue
		if enemy.has_method("apply_burn"):
			enemy.apply_burn({
				"burn_stacks": 1, 
				"burn_dps": burn_dps * 0.85, 
				"from_spread": true
			})

func _take_status_damage(amount: float) -> void :
	if amount <= 0.0:
		return
	var dealt: = _mitigate(amount)
	show_damage_text(dealt, true)
	_apply_health_loss(dealt)

func play_hit_tween(direction: Vector2):
	if not is_inside_tree():
		return
	if sprite_2d == null or not is_instance_valid(sprite_2d):
		return
	_hit_squash = 1.0

	_hit_recoil = direction.normalized() * 3.0 / maxf(body_scale, 0.4)
	sprite_2d.self_modulate = preload("res://script/visual_style.gd").HIT_FLASH
	_hit_flash_left = 0.1
	set_process(true)

func take_damage(damage_value: float) -> void :
	AudioManager.play_enemy_hurt()
	_apply_health_loss(_mitigate(damage_value))

func _apply_health_loss(dealt: float) -> void :
	if _death_started:
		return
	health -= dealt
	if health <= 0:
		_death_started = true
		var feedback: = JUICE.find(self)
		if feedback != null: feedback.kill(global_position, base_modulate, is_elite)
		spaw_icon()
		remove_from_group("EnemyGroup")
		death_signal.emit()
		queue_free()

func show_damage_text(damage_value: float, status_damage: bool = false, critical: bool = false) -> void :
	var owner: = _game_owner()
	var container: Node = owner.effect_container if owner != null else get_tree().get_first_node_in_group("effect_container")
	if container == null or not FEEDBACK_BUDGET.allow_popup(get_tree()):
		return
	var d = damage_text.instantiate()
	container.add_child(d)
	d.position = self.position
	d.show_damage(str(int(floor(damage_value))), self.global_position, 0, 0, status_damage, critical)

func spaw_icon() -> void :
	var game: = _game_owner()
	if game == null:
		return
	game.spawn_xp_coin(global_position, 5 if is_elite else 2)
