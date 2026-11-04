extends Node2D

const MAX_LEVEL := 5
const GUST_SECONDS := 0.52
const SCAN_STEP := 0.05
const HALF_ANGLE := 0.64
const MAX_WAKES := 24
const ICON := preload("res://assest/sprites/banana_fan.svg")
var level := 0
var casts := 0
var hits := 0
var status_echoes := 0
var _cooldown := 0.0
var _wave_left := 0.0
var _scan_left := 0.0
var _redraw_left := 0.0
var _origin := Vector2.ZERO
var _direction := Vector2.RIGHT
var _hit_ids: Dictionary = {}
var _targets: Array[Node2D] = []
var _wakes: Array[Dictionary] = []
var _wake_slot := 0
var _generation := 0
var _visuals_visible := false
var _stream := PackedVector2Array()
var _stats := stats_for(1)
var _audio: AudioStreamPlayer
@onready var game: Node = get_parent()

static func stats_for(rank: int) -> Dictionary:
	var step := clampi(rank, 1, MAX_LEVEL) - 1
	return {"damage": 12.0 + 4.0 * step, "range": 130.0 + 25.0 * step,
		"interval": 3.0 * pow(0.8, step), "push_speed": 300.0 + 25.0 * step}

func _ready() -> void:
	z_index = 7
	_stream.resize(7)
	for _i in MAX_WAKES:
		_wakes.append({"actor": null, "left": 0.0, "phase": float(_i) * 2.39996})
	_audio = AudioStreamPlayer.new()
	AudioManager.configure_sfx(_audio)
	_audio.stream = preload("res://assest/sounds/banana_fan.wav")
	_audio.volume_db = -18.0
	add_child(_audio)
	reset()

func upgrade() -> void:
	level = mini(level + 1, MAX_LEVEL)
	_stats = stats_for(level)
	_cooldown = minf(_cooldown, float(_stats.interval)) if level > 1 else 0.25
	set_physics_process(true)

func reset() -> void:
	clear_combat_effects()
	level = 0
	casts = 0
	hits = 0
	status_echoes = 0
	_cooldown = 0.0
	set_physics_process(false)

func clear_combat_effects() -> void:
	_generation += 1
	for ref in _hit_ids.values():
		var actor: Object = ref.get_ref()
		if is_instance_valid(actor) and actor.has_method("clear_airflow"):
			actor.clear_airflow()
	_hit_ids.clear()
	_targets.clear()
	_wave_left = 0.0
	_visuals_visible = false
	_scan_left = 0.0
	for wake in _wakes:
		wake.left = 0.0
		wake.actor = null
	if _audio != null: _audio.stop()
	queue_redraw()

func aim_direction() -> Vector2:
	var player: Node = game.player
	var heading: Vector2 = player.dash_direction if player.dashing else player.last_move_direction
	return heading.normalized() if not heading.is_zero_approx() else Vector2.RIGHT

func _contains(at: Vector2, reach: float) -> bool:
	var offset := at - _origin
	var distance_squared := offset.length_squared()
	if distance_squared > reach * reach: return false
	return distance_squared < 0.001 or offset.dot(_direction) >= sqrt(distance_squared) * cos(HALF_ANGLE)

func cast() -> bool:
	if level <= 0 or not game.variety._battle_active() or _wave_left > 0.0: return false
	_direction = aim_direction()
	_origin = game.player.global_position + _direction * 8.0
	_targets.clear()
	CombatTargets.fill_in_radius(_origin, _stats.range * _stats.range, game, _targets)
	var found := false
	for actor in _targets:
		if not actor.has_method("apply_hit"): continue
		if _contains(actor.global_position, _stats.range) and (not actor.has_method("vulnerable") or actor.vulnerable()):
			found = true
			break
	if not found: return false
	_hit_ids.clear()
	_wave_left = GUST_SECONDS
	_visuals_visible = true
	_cooldown = float(_stats.interval)
	_scan_left = 0.0
	casts += 1
	_audio.play()
	queue_redraw()
	return true

func _physics_process(delta: float) -> void:
	if level <= 0 or get_tree().paused: return
	if not game.variety._battle_active():
		if _wave_left > 0.0 or not _hit_ids.is_empty(): clear_combat_effects()
		return
	_cooldown -= delta
	if _cooldown <= 0.0 and _wave_left <= 0.0:
		_cooldown = float(_stats.interval) if cast() else 0.2
	if _wave_left > 0.0:
		_wave_left = maxf(0.0, _wave_left - delta)
		_scan_left -= delta
		if _scan_left <= 0.0 or _wave_left <= 0.0:
			_scan_left = SCAN_STEP
			_scan_gust()
	var has_wakes := false
	for wake in _wakes:
		if wake.left > 0.0:
			wake.left = maxf(0.0, wake.left - delta)
			has_wakes = true
	_redraw_left -= delta
	if _redraw_left <= 0.0 and (_wave_left > 0.0 or has_wakes):
		_redraw_left = 1.0 / 30.0
		queue_redraw()
	elif _wave_left <= 0.0 and not has_wakes and _visuals_visible:
		_visuals_visible = false
		queue_redraw()

func _scan_gust() -> void:
	var generation := _generation
	var progress := clampf(1.0 - _wave_left / GUST_SECONDS, 0.0, 1.0)
	var reach := lerpf(18.0, float(_stats.range), 1.0 - pow(1.0 - progress, 2.0))
	_targets.clear()
	CombatTargets.fill_in_radius(_origin, reach * reach, game, _targets)
	for actor in _targets:
		if not actor.has_method("apply_hit"): continue
		var id := actor.get_instance_id()
		if _hit_ids.has(id) or not _contains(actor.global_position, reach): continue
		if actor.has_method("vulnerable") and not actor.vulnerable(): continue
		var ref: WeakRef = weakref(actor)
		_hit_ids[id] = ref
		# Snapshot before the direct hit can add a new on-hit status.
		var extra_damage := 0.0
		if actor.has_method("get_status_echo_damage"):
			extra_damage = actor.get_status_echo_damage(game.poison_trail.extra_tick_damage_for(actor))
		actor.apply_hit({"damage": _stats.damage, "direction": _direction, "effect": "banana_fan", "source": self})
		if generation != _generation: return
		hits += 1
		if not is_instance_valid(actor) or actor.is_queued_for_deletion() or not actor.is_in_group("EnemyGroup"): continue
		if extra_damage > 0.0:
			# A final status-only hit cannot reapply statuses or reroll modifiers.
			actor.apply_hit({"damage": extra_damage, "direction": _direction, "effect": "fan_status_bonus",
				"from_status": true, "damage_is_final": true, "ignore_side_bonus": true, "source": self})
			status_echoes += 1
			if generation != _generation: return
			if not is_instance_valid(actor) or actor.is_queued_for_deletion() or not actor.is_in_group("EnemyGroup"): continue
		if actor.has_method("apply_airflow"):
			actor.apply_airflow(_direction * float(_stats.push_speed), 0.36)
			var wake: Dictionary = _wakes[_wake_slot]
			wake.actor = ref
			wake.left = 0.46
			_wake_slot = (_wake_slot + 1) % MAX_WAKES

func _draw() -> void:
	if level <= 0: return
	if _wave_left > 0.0:
		var progress := 1.0 - _wave_left / GUST_SECONDS
		var reach := lerpf(18.0, float(_stats.range), 1.0 - pow(1.0 - progress, 2.0))
		var fade := minf(1.0, _wave_left / 0.18)
		draw_set_transform(to_local(_origin), _direction.angle())
		draw_arc(Vector2.ZERO, reach, -HALF_ANGLE, HALF_ANGLE, 22, Color(0.7, 0.94, 0.87, 0.55 * fade), 2.0)
		for lane in 5:
			var spread := (float(lane) - 2.0) * HALF_ANGLE * 0.42
			for i in _stream.size():
				var t := float(i) / float(_stream.size() - 1)
				var radius := maxf(12.0, reach - 58.0) + t * minf(reach - 12.0, 58.0)
				_stream[i] = Vector2.RIGHT.rotated(spread + sin(t * PI + progress * 7.0 + lane) * 0.04) * radius
			draw_polyline(_stream, Color(0.79, 0.94, 0.88, fade * 0.52), 1.4)
		draw_set_transform(to_local(_origin), _direction.angle() + PI * 0.25 + sin(progress * PI) * 0.3)
		draw_texture_rect(ICON, Rect2(-14.0, -14.0, 28.0, 28.0), false, Color(1, 1, 1, fade))
		draw_set_transform(Vector2.ZERO)
	for wake in _wakes:
		if wake.left <= 0.0 or wake.actor == null: continue
		var actor: Object = wake.actor.get_ref()
		if not is_instance_valid(actor) or actor.is_queued_for_deletion(): continue
		var at := to_local(actor.global_position)
		var alpha: float = wake.left / 0.46 * 0.65
		for i in 2:
			var spin: float = wake.phase + (0.46 - wake.left) * 12.0 + i * PI
			draw_arc(at - _direction * 5.0 + Vector2(0, float(i) * 5.0 - 3.0), 8.0 + i * 3.0, spin, spin + PI * 0.85, 9, Color(0.73, 0.92, 0.85, alpha), 1.1)
