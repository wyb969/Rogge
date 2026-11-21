extends Node2D

const FX := preload("res://script/blood_vortex_fx.gd")
const PULSE := preload("res://rogge_art/combat-fx/blood-vortex/pulse.ogg")
const FINISH := preload("res://rogge_art/combat-fx/blood-vortex/finish.ogg")
const LENGTH := 270.0
const ROOT_RADIUS := 18.0
const MOUTH_RADIUS := 70.0
const SCAN_STEP := 0.08
const RECOVERY := 4.5
const FINISH_MULTIPLIER := 3.0
const PAGE_SIZE := 256
const CROWD_FEEDBACK := 4

var level := 0
var _stats := stats_for(1)
var _active := false
var _age := 0.0
var _beats := 0
var _interval := 0.5
var _duration := 0.0
var _next_beat := 1
var _damage := 0.0
var _heading := Vector2.RIGHT
var _cooldown := 0.0
var _scan_left := 0.0
var _held := {}
# Only blocked bodies enter this table. Deadlines use the paused cast clock.
var _retry_at := {}
var _generation := 0
var _query := PhysicsShapeQueryParameters2D.new()
var _fx := FX.new()
var _sound := AudioStreamPlayer.new()
@onready var game: Node = get_parent()

static func stats_for(rank: int) -> Dictionary:
	var step := clampi(rank, 1, 5) - 1
	var beats := 6 + 2 * step
	var interval := (50 - 3 * step) / 100.0
	return {"damage": 12.0 + 3.0 * step, "beats": beats, "interval": interval, "duration": beats * interval}

func _ready() -> void:
	add_child(_fx)
	add_child(_sound)
	AudioManager.configure_sfx(_sound)
	_sound.volume_db = -10.0
	_query.shape = _funnel_shape()
	_query.collision_mask = 8
	reset()

# The axial profile matches the drawn helix, with an eight-pixel cap at either end.
func _funnel_shape() -> ConvexPolygonShape2D:
	var points := PackedVector2Array()
	for offset: float in [0.0, 1.0, 3.0, 5.0, 8.0, LENGTH - 8.0, LENGTH - 5.0, LENGTH - 3.0, LENGTH - 1.0, LENGTH]:
		var cap := minf(minf(offset, LENGTH - offset) / 8.0, 1.0)
		var width := lerpf(ROOT_RADIUS, MOUTH_RADIUS, offset / LENGTH) * sqrt(cap * (2.0 - cap))
		points.append(Vector2(offset - LENGTH * 0.5, width))
		points.append(Vector2(offset - LENGTH * 0.5, -width))
	var shape := ConvexPolygonShape2D.new()
	shape.set_point_cloud(points)
	return shape

func upgrade() -> void:
	level = mini(5, level + 1)
	_stats = stats_for(level)
	if level == 1: _cooldown = 0.32
	set_physics_process(true)

func reset() -> void:
	clear_combat_effects()
	level = 0
	_cooldown = 0.0
	set_physics_process(false)

func clear_combat_effects() -> void:
	_generation += 1
	_active = false
	_release_all()
	_sound.stop()
	_fx.clear()

func _release_all() -> void:
	for actor in _held.values():
		if is_instance_valid(actor) and actor.blood_vortex_source == self:
			actor.blood_vortex_source = null
	_held.clear()
	_retry_at.clear()

func cast() -> bool:
	if level == 0 or _active or not game.variety._battle_active(): return false
	var origin: Vector2 = game.player.global_position
	var target := CombatTargets.nearest(origin, LENGTH * LENGTH)
	if not is_instance_valid(target) or not game.is_ancestor_of(target): return false
	_heading = origin.direction_to(target.global_position)
	if _heading.is_zero_approx(): _heading = game.player.last_move_direction.normalized()
	if _heading.is_zero_approx(): _heading = Vector2.RIGHT
	global_position = origin + _heading * (LENGTH * 0.5)
	_query.transform = Transform2D(_heading.angle(), global_position)
	_damage = _stats.damage
	_beats = int(_stats.beats)
	_interval = _stats.interval
	_duration = _stats.duration
	_next_beat = 1
	_age = 0.0
	_scan_left = 0.0
	_active = true
	_fx.begin(global_position, _heading, LENGTH, MOUTH_RADIUS)
	return true

func _contacts() -> Dictionary:
	var result := {}
	var excluded: Array[RID] = []
	var world := get_world_2d().direct_space_state
	while true:
		var hits := world.intersect_shape(_query, PAGE_SIZE)
		for hit in hits:
			var actor: Node2D = hit.collider
			if actor.is_in_group("EnemyGroup") and not actor.is_queued_for_deletion() and game.is_ancestor_of(actor) and actor.has_method("apply_hit"):
				if not actor.has_method("vulnerable") or actor.vulnerable():
					result[actor.get_instance_id()] = actor
		if hits.size() < PAGE_SIZE: break
		for hit in hits: excluded.append(hit.rid)
		_query.exclude = excluded
	if not excluded.is_empty(): _query.exclude = []
	return result

func _capture(inside: Dictionary) -> void:
	for id in _held.keys():
		if inside.has(id): continue
		var actor = _held[id]
		if is_instance_valid(actor) and actor.blood_vortex_source == self: actor.blood_vortex_source = null
		_held.erase(id)
		_retry_at.erase(id)
	for id in inside:
		var actor: Node = inside[id]
		if actor.has_method("catch_blood_vortex") and actor.blood_vortex_source != self:
			if actor.catch_blood_vortex(self): _held[id] = actor

func pull_body(actor: CharacterBody2D, delta: float, resistance: float) -> void:
	var id := actor.get_instance_id()
	if _age < float(_retry_at.get(id, -1.0)):
		actor.velocity = Vector2.ZERO
		return
	var inward := global_position - actor.global_position
	if inward.length_squared() < 1.0:
		actor.velocity = Vector2.ZERO
		return
	# Tangential speed falls off at the core so bodies settle between beats.
	var motion := (inward * 7.0 + inward.orthogonal() * 2.0).limit_length(240.0) * resistance
	actor.velocity = motion
	var collision := actor.move_and_collide((motion * delta).limit_length(inward.length()))
	if collision:
		# A packed crowd usually blocks the same sweep for several ticks.
		# Retry on staggered deadlines; never teleport through another body.
		_retry_at[id] = _age + 0.075 + float(posmod(hash(id), 6)) / 60.0
	else:
		_retry_at.erase(id)

func _strike(inside: Dictionary, final: bool) -> void:
	var generation := _generation
	var count := inside.size()
	var index := 0
	var offset := (_next_beat * CROWD_FEEDBACK) % maxi(1, count)
	for actor in inside.values():
		if not is_instance_valid(actor) or actor.is_queued_for_deletion() or not actor.is_in_group("EnemyGroup"): continue
		var direction := global_position.direction_to(actor.global_position)
		if direction.is_zero_approx(): direction = _heading
		# Sample overlapping cosmetic feedback, never damage, procs or launch.
		var quiet := count > 6 and (index + offset) % count >= CROWD_FEEDBACK
		index += 1
		actor.apply_hit({"quiet_crowd_feedback": quiet, "damage": _damage * (FINISH_MULTIPLIER if final else 1.0),
			"direction": direction, "from_status": not final, "source": self})
		if generation != _generation: return
		if final and is_instance_valid(actor) and not actor.is_queued_for_deletion() and actor.is_in_group("EnemyGroup") and not actor.is_in_group("trial_enemy") and actor.has_method("apply_terrain_impulse"):
			actor.apply_terrain_impulse(direction * 385.0)

func _physics_process(delta: float) -> void:
	if get_tree().paused: return
	if not game.variety._battle_active():
		if _active or _fx.visible or _sound.playing: clear_combat_effects()
		return
	if not _active:
		_cooldown -= delta
		if _cooldown <= 0.0 and not cast(): _cooldown = 0.20
		return
	_age = minf(_duration, _age + delta)
	_fx.advance(_age, _duration)
	_scan_left -= delta
	if _scan_left > 0.0 and _age + 0.000001 < _next_beat * _interval: return
	_scan_left = SCAN_STEP
	var inside := _contacts()
	_capture(inside)
	while _active and _age + 0.000001 >= _next_beat * _interval:
		var final := _next_beat == _beats
		_next_beat += 1
		if final:
			_active = false
			_cooldown = RECOVERY
			_release_all()
			_fx.finish()
		else:
			_fx.pulse()
		var cue := FINISH if final else PULSE
		if _sound.stream != cue: _sound.stream = cue
		_sound.play()
		_strike(inside, final)
