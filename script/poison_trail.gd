extends Node2D

const MAX_LEVEL: = 5
const MAX_CLOUDS: = 64
const SPACING: = 18.0
const CLOUD_LIFE: = 4.0
const SCAN_STEP: = 0.1
const POISON_TINT: = Color(1.35, 0.42, 1.3)
var level: = 0
var damage_ticks: = 0
var clouds_emitted: = 0
var _clouds: Array[Dictionary] = []
var _next: = 0
var _clock: = 0.0
var _scan_left: = 0.0
var _scan_elapsed: = 0.0
var _redraw_left: = 0.0
var _last_position: = Vector2.ZERO
var _last_drop: = Vector2.ZERO
var _bounds: = Rect2()
var _targets: Array[Node2D] = []
var _exposed: = {}
var _stats: = {"dps": 0.0, "radius": 24.0, "slow": 1.0}
var _remove_ids: Array[int] = []
var _markers: StatusMarkers
@onready var game: Node = get_parent()

class StatusMarkers:
	extends Node2D
	var trail: Node2D
	func _draw() -> void : trail.draw_status(self)

static func stats_for(rank: int) -> Dictionary:
	var capped: = clampi(rank, 0, MAX_LEVEL)
	return {"dps": 5.0 * capped, "radius": 24.0 + 2.0 * maxi(capped - 1, 0), "slow": 0.75 if capped == MAX_LEVEL else 1.0}

func _ready() -> void :
	z_index = -2
	for i in MAX_CLOUDS: _clouds.append({"at": Vector2.ZERO, "left": 0.0, "phase": float(i) * 2.39996})
	_markers = StatusMarkers.new()
	_markers.z_index = 14
	_markers.trail = self
	add_child(_markers)
	reset()

func upgrade() -> void :
	level = mini(level + 1, MAX_LEVEL)
	_stats = stats_for(level)
	_last_position = game.player.global_position
	_last_drop = _last_position
	set_process(true)

func reset() -> void :
	level = 0
	_stats = stats_for(0)
	damage_ticks = 0
	clouds_emitted = 0
	_clock = 0
	clear_combat_effects()
	set_process(false)

func clear_combat_effects() -> void :
	for cloud in _clouds: cloud.left = 0.0
	for entry in _exposed.values(): _clear_actor(entry)
	_exposed.clear()
	_targets.clear()
	_scan_left = 0
	_scan_elapsed = 0
	_last_position = game.player.global_position
	_last_drop = _last_position
	queue_redraw()
	if _markers != null: _markers.queue_redraw()

func _clear_actor(entry: Dictionary) -> void :
	var actor: Object = entry.actor.get_ref()
	if is_instance_valid(actor) and actor.has_method("set_poison_exposure"):
		actor.set_poison_exposure(false, 1.0, Color.WHITE)

func _process(delta: float) -> void :
	if level <= 0 or get_tree().paused: return
	if not game.variety._battle_active():
		clear_combat_effects()
		return
	_clock += delta
	_emit_movement(game.player.global_position)
	_scan_elapsed += delta
	_scan_left -= delta
	if _scan_left <= 0:
		_scan(_scan_elapsed)
		_scan_elapsed = 0
		_scan_left = SCAN_STEP
	for cloud in _clouds:
		if cloud.left > 0: cloud.left = maxf(0, cloud.left - delta)
	_redraw_left -= delta
	if _redraw_left <= 0:
		_redraw_left = 1.0 / 30
		queue_redraw()
		_markers.queue_redraw()

func _emit_movement(at: Vector2) -> void :
	var motion: = at - _last_position
	_last_position = at
	if motion.length_squared() < 0.0001: return
	if motion.length_squared() > 180.0 * 180.0:

		_last_drop = at
		return
	var direction: = motion.normalized()
	var distance: = _last_drop.distance_to(at)
	var steps: = mini(8, int(distance / SPACING))
	for _i in steps:
		_last_drop = _last_drop.move_toward(at, SPACING)
		var cloud: = _clouds[_next]
		cloud.at = _last_drop - direction * 10
		cloud.left = CLOUD_LIFE
		_next = (_next + 1) % MAX_CLOUDS
		clouds_emitted += 1

func _scan(elapsed: float) -> void :
	var stats: = _stats
	var radius_squared: float = stats.radius * stats.radius
	var any: = false
	for cloud in _clouds:
		if cloud.left <= 0: continue
		var area: = Rect2(cloud.at - Vector2.ONE * stats.radius, Vector2.ONE * stats.radius * 2)
		_bounds = _bounds.merge(area) if any else area
		any = true
	_targets.clear()
	if any: CombatTargets.fill_in_bounds(_bounds.grow(0.001), game, _targets)
	for entry in _exposed.values(): entry.inside = false
	for actor in _targets:
		if actor.has_method("vulnerable") and not actor.vulnerable(): continue
		var position: = actor.global_position
		var inside: = false
		var exposure_life: = 0.0
		for cloud in _clouds:
			if cloud.left > 0 and position.distance_squared_to(cloud.at) <= radius_squared:
				inside = true
				exposure_life = maxf(exposure_life, cloud.left)
		if not inside: continue
		var id: = actor.get_instance_id()
		if not _exposed.has(id): _exposed[id] = {"actor": weakref(actor), "dose": 0.0, "inside": true}
		var entry: Dictionary = _exposed[id]
		entry.inside = true
		entry.dose += minf(elapsed, exposure_life)
		if actor.has_method("set_poison_exposure"):
			var blend: = 0.35 + 0.55 * (0.5 + 0.5 * sin(_clock * 8.0))
			actor.set_poison_exposure(true, stats.slow, Color.WHITE.lerp(POISON_TINT, blend))
		while entry.dose >= 1.0 - 1e-05:
			entry.dose = maxf(0, entry.dose - 1.0)

			actor.apply_hit({"damage": stats.dps, "direction": Vector2.ZERO, "effect": "poison_trail", "from_status": true, "source": self})
			damage_ticks += 1
			if not actor.is_in_group("EnemyGroup") or actor.is_queued_for_deletion(): break
	_remove_ids.clear()
	for id in _exposed:
		var entry: Dictionary = _exposed[id]
		var actor: Object = entry.actor.get_ref()
		if not entry.inside or not is_instance_valid(actor) or actor.is_queued_for_deletion() or not actor.is_in_group("EnemyGroup"):
			_clear_actor(entry)
			_remove_ids.append(id)
	for id in _remove_ids: _exposed.erase(id)

func active_clouds() -> int:
	var count: = 0
	for cloud in _clouds:
		if cloud.left > 0: count += 1
	return count

func _draw() -> void :
	if level <= 0: return
	var radius: float = _stats.radius
	for cloud in _clouds:
		if cloud.left <= 0: continue
		var fade: = minf(1, cloud.left / 0.7)
		var at: Vector2 = to_local(cloud.at)
		var offset: = Vector2(sin(cloud.phase + _clock) * 5, -3)
		draw_circle(at, radius, Color(0.18, 0.32, 0.17, 0.08 * fade))
		draw_circle(at + offset, radius * 0.68, Color(0.34, 0.48, 0.2, 0.12 * fade))
		draw_circle(at + Vector2(5, -7 - fposmod(_clock * 9 + cloud.phase, 12)), 1.4, Color(0.64, 0.78, 0.28, 0.4 * fade))

func draw_status(canvas: Node2D) -> void :
	for entry in _exposed.values():
		var actor: Object = entry.actor.get_ref()
		if not is_instance_valid(actor) or actor.is_queued_for_deletion(): continue
		var at: Vector2 = canvas.to_local(actor.global_position) + Vector2(0, -16)
		var bright: = 0.55 + 0.4 * (0.5 + 0.5 * sin(_clock * 8))
		canvas.draw_circle(at + Vector2(-4, -2), 2.0, Color(0.9, 0.3, 0.78, bright))
		canvas.draw_circle(at + Vector2(4, -5), 1.5, Color(0.93, 0.52, 0.9, bright))
