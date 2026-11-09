extends Node2D

const MAX_LEVEL := 5
const LIFETIME := 3.0
const SCAN_STEP := 0.05
const CAST_RANGE := 290.0
const MIN_CAST_DISTANCE := 88.0
var level := 0
var casts := 0
var damage_ticks := 0
var _cooldown := 0.0
var _left := 0.0
var _scan_left := 0.0
var _scan_elapsed := 0.0
var _redraw_left := 0.0
var _center := Vector2.ZERO
var _generation := 0
var _targets: Array[Node2D] = []
var _exposed: Dictionary = {}
var _remove_ids: Array[int] = []
var _spiral := PackedVector2Array()
var _stats := stats_for(1)
var _audio: AudioStreamPlayer
@onready var game: Node = get_parent()

static func stats_for(rank: int) -> Dictionary:
	var step := clampi(rank, 1, MAX_LEVEL) - 1
	return {"dps": 6.0 + 3.0 * step, "radius": 70.0 + 12.0 * step,
		"interval": 10.0 - float(step), "pull_speed": 190.0 + 15.0 * step}

func _ready() -> void:
	z_index = 11
	_spiral.resize(12)
	_audio = AudioStreamPlayer.new()
	AudioManager.configure_sfx(_audio)
	_audio.stream = preload("res://assest/sounds/black_hole.wav")
	_audio.volume_db = -19.0
	add_child(_audio)
	reset()

func upgrade() -> void:
	level = mini(level + 1, MAX_LEVEL)
	_stats = stats_for(level)
	_cooldown = minf(_cooldown, float(_stats.interval)) if level > 1 else 0.45
	set_physics_process(true)

func reset() -> void:
	clear_combat_effects()
	level = 0
	casts = 0
	damage_ticks = 0
	_cooldown = 0.0
	set_physics_process(false)

func _clear_actor(entry: Dictionary) -> void:
	var actor: Object = entry.actor.get_ref()
	if is_instance_valid(actor) and actor.has_method("clear_gravity_pull"):
		actor.clear_gravity_pull()

func clear_combat_effects() -> void:
	_generation += 1
	for entry in _exposed.values(): _clear_actor(entry)
	_exposed.clear()
	_targets.clear()
	_left = 0.0
	_scan_left = 0.0
	_scan_elapsed = 0.0
	if _audio != null: _audio.stop()
	queue_redraw()

func cast() -> bool:
	if level <= 0 or not game.variety._battle_active() or _left > 0.0: return false
	var origin: Vector2 = game.player.global_position
	var target: Node2D = CombatTargets.nearest(origin, CAST_RANGE * CAST_RANGE)
	if target == null or not game.is_ancestor_of(target): return false
	var offset := target.global_position - origin
	var distance := offset.length()
	var heading: Vector2 = offset / distance if distance > 0.001 else game.player.last_move_direction.normalized()
	if heading.is_zero_approx(): heading = Vector2.RIGHT
	_center = origin + heading * maxf(MIN_CAST_DISTANCE, distance)
	_exposed.clear()
	_left = LIFETIME
	_cooldown = float(_stats.interval)
	_scan_left = 0.0
	_scan_elapsed = 0.0
	casts += 1
	_audio.play()
	queue_redraw()
	return true

func _physics_process(delta: float) -> void:
	if level <= 0 or get_tree().paused: return
	if not game.variety._battle_active():
		if _left > 0.0 or not _exposed.is_empty(): clear_combat_effects()
		return
	_cooldown -= delta
	if _cooldown <= 0.0 and _left <= 0.0:
		_cooldown = float(_stats.interval) if cast() else 0.25
	if _left <= 0.0: return
	var active_delta := minf(delta, _left)
	_left = maxf(0.0, _left - active_delta)
	if _left < 0.000001: _left = 0.0
	_scan_elapsed += active_delta
	_scan_left -= delta
	if _scan_left <= 0.0 or _left <= 0.0:
		_scan_left = SCAN_STEP
		_scan(_scan_elapsed)
		_scan_elapsed = 0.0
	_redraw_left -= delta
	if _redraw_left <= 0.0:
		_redraw_left = 1.0 / 30.0
		queue_redraw()
	if _left <= 0.0: clear_combat_effects()

func _scan(elapsed: float) -> void:
	var generation := _generation
	_targets.clear()
	CombatTargets.fill_in_radius(_center, _stats.radius * _stats.radius, game, _targets)
	for entry in _exposed.values(): entry.inside = false
	for actor in _targets:
		if not actor.has_method("apply_hit"): continue
		if actor.has_method("vulnerable") and not actor.vulnerable(): continue
		var id := actor.get_instance_id()
		if not _exposed.has(id): _exposed[id] = {"actor": weakref(actor), "dose": 0.0, "inside": true}
		var entry: Dictionary = _exposed[id]
		entry.inside = true
		entry.dose += elapsed
		var offset := _center - actor.global_position
		var distance := offset.length()
		if actor.has_method("apply_gravity_pull"):
			var inward := offset / distance if distance > 0.001 else Vector2.ZERO
			var pull := minf(float(_stats.pull_speed), distance * 10.0)
			var swirl := inward.orthogonal() * minf(22.0, distance * 0.8)
			actor.apply_gravity_pull(inward * pull + swirl, SCAN_STEP * 2.5)
		var ticks := int(floor(entry.dose + 0.00001))
		if ticks > 0:
			entry.dose = maxf(0.0, entry.dose - float(ticks))
			actor.apply_hit({"damage": float(_stats.dps) * ticks, "direction": offset.normalized(),
				"effect": "black_hole", "from_status": true, "source": self})
			if generation != _generation: return
			damage_ticks += ticks
	_remove_ids.clear()
	for id in _exposed:
		var entry: Dictionary = _exposed[id]
		var actor: Object = entry.actor.get_ref()
		if not entry.inside or not is_instance_valid(actor) or actor.is_queued_for_deletion() or not actor.is_in_group("EnemyGroup"):
			_clear_actor(entry)
			_remove_ids.append(id)
	for id in _remove_ids: _exposed.erase(id)

func _draw() -> void:
	if level <= 0 or _left <= 0.0: return
	var age := LIFETIME - _left
	var fade := minf(minf(1.0, age / 0.2), _left / 0.3)
	var center := to_local(_center)
	var radius: float = _stats.radius
	draw_circle(center, radius, GamePalette.alpha(GamePalette.INK, 0.13 * fade))
	draw_arc(center, radius, age * 0.35, age * 0.35 + TAU * 0.86, 38, GamePalette.alpha(GamePalette.FRIENDLY_CYAN, 0.3 * fade), 1.0)
	for arm in 4:
		for i in _spiral.size():
			var t := float(i) / float(_spiral.size() - 1)
			var angle := float(arm) * PI * 0.5 + age * 2.0 + t * 2.3
			_spiral[i] = center + Vector2.RIGHT.rotated(angle) * lerpf(11.0, radius * 0.9, t)
		draw_polyline(_spiral, GamePalette.alpha(GamePalette.FRIENDLY_CYAN, 0.34 * fade), 1.25)
	draw_circle(center, 13.0 + sin(age * 5.0) * 1.0, GamePalette.alpha(GamePalette.INK, fade))
	draw_arc(center, 15.5, age * 2.2, age * 2.2 + TAU * 0.83, 24, GamePalette.alpha(GamePalette.FRIENDLY_LIGHT, 0.85 * fade), 2.0)
	for mote in 7:
		var phase := fposmod(age * 0.52 + float(mote) / 7.0, 1.0)
		var angle := float(mote) * 2.39996 + age * 1.8
		var at := center + Vector2.RIGHT.rotated(angle) * lerpf(radius, 15.0, phase)
		draw_rect(Rect2(at, Vector2(2, 2)), Color(0.73, 0.7, 0.94, fade * sin(phase * PI) * 0.65))
