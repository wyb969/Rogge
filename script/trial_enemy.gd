extends "res://script/beast_boss.gd"

enum TrialState{ROAM, TRACK, LOCK, ACTIVE, RECOVER, VANISH}
var kind: = "power"
var director: Node
var trial_state: = TrialState.ROAM
var left: = 1.0
var aim_angle: = 0.0
var _beam_origin: = Vector2.ZERO
var _hit_landed: = false
var _dashed: = false
var _exposed: = false
var _beep_left: = 0.0
var lock_beep_count: = 0
var attacks: = 0
var _lock_audio: AudioStreamPlayer
var _attack_audio: AudioStreamPlayer
const LASER_LENGTH: = 680.0
const LASER_HALF_WIDTH: = 14.0
const SLASH_RADIUS: = 112.0
const SLASH_HALF_ANGLE: = 1.08

func _death_stain_kind() -> StringName:
	return &"power_trial" if kind == "power" else &"speed_trial"

func configure_trial(value: String, host: Node) -> void :
	kind = value
	director = host
	configure_stage(4 if kind == "power" else 6)

func _ready() -> void :
	super._ready()
	sprite_2d.material = GamePalette.ramp_material(&"enemy:power_trial" if kind == "power" else &"enemy:speed_trial")
	health_max_value = 5000.0 if kind == "power" else 2600.0
	boss_current_health = health_max_value
	health_bar.init_health(health_max_value)
	sprite_2d.texture = load("res://assest/sprites/trials/%s.svg" % ("clockwork_octopus" if kind == "power" else "blink_wizard"))
	sprite_2d.scale = Vector2.ONE * (0.86 if kind == "power" else 0.7)
	base_sprite_scale = sprite_2d.scale
	_lock_audio = AudioStreamPlayer.new()
	_lock_audio.stream = preload("res://assest/sounds/trial_lock.wav")
	_lock_audio.volume_db = -8
	AudioManager.configure_sfx(_lock_audio)
	add_child(_lock_audio)
	_attack_audio = AudioStreamPlayer.new()
	_attack_audio.stream = preload("res://assest/sounds/trial_laser.wav")
	_attack_audio.volume_db = -7
	AudioManager.configure_sfx(_attack_audio)
	add_child(_attack_audio)
	trial_state = TrialState.ROAM if kind == "power" else TrialState.VANISH
	left = 0.9 if kind == "power" else 1.4
	add_to_group("trial_enemy")
	_update_title()

func _process(delta: float) -> void :
	_elapsed += delta
	if not is_dying:
		sprite_2d.position.y = sin(_elapsed * 3.0) * (2.0 if kind == "power" else 5.0)
	queue_redraw()

func _physics_process(delta: float) -> void :
	if is_dying or not is_instance_valid(director) or not director.active_fight() or not is_instance_valid(player) or player.player_health <= 0:
		return
	left -= delta
	if kind == "power":
		_step_power(delta)
	else:
		_step_speed()
	_update_title()
	queue_redraw()

func _step_power(delta: float) -> void :
	match trial_state:
		TrialState.ROAM:
			var offset: = player.global_position - global_position
			velocity = offset.normalized() * 28 * poison_slow if offset.length() > 155 else Vector2.ZERO
			move_and_slide()
			if left <= 0:
				trial_state = TrialState.TRACK
				left = 1.25
				_beep_left = 0
		TrialState.TRACK:
			aim_angle = (player.global_position - global_position).angle()
			_beam_origin = global_position
			_beep_left -= delta
			if _beep_left <= 0:
				_lock_audio.pitch_scale = 1.0 + (1.25 - left) * 0.45
				_lock_audio.play()
				lock_beep_count += 1
				_beep_left = 0.16 if left < 0.45 else 0.24
			if left <= 0:
				trial_state = TrialState.LOCK
				left = 0.3
				_lock_audio.pitch_scale = 1.75
				_lock_audio.play()
		TrialState.LOCK:
			if left <= 0:
				trial_state = TrialState.ACTIVE
				left = 0.18
				_hit_landed = false
				attacks += 1
				_attack_audio.play()
				_try_attack()
		TrialState.ACTIVE:
			_try_attack()
			if left <= 0:
				trial_state = TrialState.RECOVER
				left = 1.4
		TrialState.RECOVER:
			if left <= 0:
				trial_state = TrialState.ROAM
				left = 0.6

func _step_speed() -> void :
	match trial_state:
		TrialState.VANISH:
			sprite_2d.modulate.a = 0.22
			if left <= 0:
				teleport_near_player()
		TrialState.LOCK:
			_dashed = _dashed or player.is_dash_invulnerable()
			if left <= 0:
				trial_state = TrialState.ACTIVE
				left = 0.16
				_hit_landed = false
				attacks += 1
				_attack_audio.pitch_scale = 0.7
				_attack_audio.play()
				_try_attack()
		TrialState.ACTIVE:
			_dashed = _dashed or player.is_dash_invulnerable()
			_try_attack()
			if left <= 0:
				_exposed = _dashed and not _hit_landed
				trial_state = TrialState.RECOVER
				left = 1.5
		TrialState.RECOVER:
			sprite_2d.modulate = GamePalette.DANGER_ORANGE if _exposed else Color.WHITE
			if left <= 0:
				_exposed = false
				trial_state = TrialState.VANISH
				left = 1.4

func teleport_near_player() -> void :
	var angle: = float(randi() % 8) * PI / 4.0
	global_position = player.global_position + Vector2.from_angle(angle) * 90.0
	reset_physics_interpolation()
	aim_angle = (player.global_position - global_position).angle()
	_dashed = player.is_dash_invulnerable()
	_exposed = false
	_hit_landed = false
	trial_state = TrialState.LOCK
	left = 0.5
	sprite_2d.modulate = Color.WHITE

func attack_contains(point: Vector2) -> bool:
	if kind == "power":
		var end: = _beam_origin + Vector2.from_angle(aim_angle) * LASER_LENGTH
		return Geometry2D.get_closest_point_to_segment(point, _beam_origin, end).distance_to(point) <= LASER_HALF_WIDTH
	var offset: = point - global_position
	return offset.length() <= SLASH_RADIUS and absf(wrapf(offset.angle() - aim_angle, - PI, PI)) <= SLASH_HALF_ANGLE

func _try_attack() -> void :
	if _hit_landed or not attack_contains(player.global_position) or player.is_dash_invulnerable():
		return
	_hit_landed = true
	player.receive_attack(100.0 if kind == "power" else 95.0, self)

func vulnerable() -> bool:
	return kind == "power" or (trial_state == TrialState.RECOVER and _exposed)

func apply_hit(data: Dictionary) -> void :
	if not is_instance_valid(director) or not director.active_fight() or not vulnerable():
		return
	super.apply_hit(data)
	if not is_dying:
		_update_title()

func start_defeat_sequence() -> void :
	if is_dying:
		return
	is_dying = true
	_lock_audio.stop()
	_attack_audio.stop()
	_hud.hide()
	remove_from_group("EnemyGroup")
	remove_from_group("trial_enemy")
	_spawn_death_burst(28, GamePalette.DANGER_ORANGE)

	boss_defeated.emit()
	queue_free()

func _update_title() -> void :
	if kind == "power":
		var status: = "缓慢接近" if trial_state == TrialState.ROAM else ("锁定中 · 准备横移" if trial_state == TrialState.TRACK else ("瞄准已固定！" if trial_state == TrialState.LOCK else ("激光发射" if trial_state == TrialState.ACTIVE else "冷却 · 趁机输出")))
		_title.text = "机械章鱼 / " + status
	else:
		_title.text = "巫刃术士 / " + ("闪避成功 · 反击！" if vulnerable() else ("0.5 秒后挥刀 · DASH！" if trial_state == TrialState.LOCK else "屏障关闭 · 等待冲刺时机"))
	_title.add_theme_color_override("font_color", GamePalette.DANGER_ORANGE if kind == "power" else GamePalette.DANGER_ORANGE)

func _draw() -> void :
	if is_dying:
		return
	draw_set_transform(Vector2(0, 42), 0, Vector2(1, 0.3))
	draw_circle(Vector2.ZERO, 42, GamePalette.SHADOW)
	draw_set_transform(Vector2.ZERO)
	if kind == "power":
		if trial_state == TrialState.TRACK:
			var target: = player.global_position - global_position
			draw_line(Vector2.ZERO, target, GamePalette.alpha(GamePalette.DANGER_RED, 0.8), 1.5, true)
			draw_arc(target, 18, 0, TAU, 32, GamePalette.DANGER_RED, 2, true)
			draw_line(target - Vector2(24, 0), target + Vector2(24, 0), Color.WHITE, 1, true)
			draw_line(target - Vector2(0, 24), target + Vector2(0, 24), Color.WHITE, 1, true)
		elif trial_state == TrialState.LOCK or trial_state == TrialState.ACTIVE:
			var origin: = _beam_origin - global_position
			var end: = origin + Vector2.from_angle(aim_angle) * LASER_LENGTH
			var side: = Vector2.from_angle(aim_angle).orthogonal() * LASER_HALF_WIDTH
			var points: = PackedVector2Array([origin - side, end - side, end + side, origin + side])
			draw_colored_polygon(points, GamePalette.alpha(GamePalette.DANGER_RED, 0.23 if trial_state == TrialState.LOCK else 0.7))
			points.append(points[0])
			draw_polyline(points, GamePalette.INK, 5, true)
			draw_polyline(points, GamePalette.DANGER_RED, 2, true)
			if trial_state == TrialState.ACTIVE:
				draw_line(origin, end, GamePalette.DANGER_ORANGE, 8, true)
	else:
		if not vulnerable():
			draw_arc(Vector2.ZERO, 42, 0, TAU, 32, GamePalette.alpha(GamePalette.DANGER_ORANGE, 0.65), 2, true)
		if trial_state == TrialState.LOCK or trial_state == TrialState.ACTIVE:
			var points: = PackedVector2Array([Vector2.ZERO])
			for i in 33:
				points.append(Vector2.from_angle(aim_angle - SLASH_HALF_ANGLE + 2 * SLASH_HALF_ANGLE * i / 32.0) * SLASH_RADIUS)
			draw_colored_polygon(points, GamePalette.alpha(GamePalette.DANGER_RED, 0.28 if trial_state == TrialState.LOCK else 0.55))
			points.append(points[0])
			draw_polyline(points, GamePalette.INK, 6, true)
			draw_polyline(points, GamePalette.DANGER_RED, 2.5, true)
			if trial_state == TrialState.ACTIVE:
				var angle: = aim_angle - SLASH_HALF_ANGLE + 2 * SLASH_HALF_ANGLE * clampf(1 - left / 0.16, 0, 1)
				draw_line(Vector2.from_angle(angle) * 15, Vector2.from_angle(angle) * SLASH_RADIUS, GamePalette.DANGER_ORANGE, 5, true)

func _request_hitstop(_scale: float, _duration_real: float) -> void :
	pass
