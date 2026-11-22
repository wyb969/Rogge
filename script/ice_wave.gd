extends Node2D

const COMBOS := preload("res://script/equipment_combos.gd")

const ICE := preload("res://script/blade_ice.gd")
const ERUPTION := preload("res://rogge_art/combat-fx/ice-wave/eruption.png")
const SHELL := preload("res://rogge_art/combat-fx/ice-wave/shell.png")
const SHATTER := preload("res://rogge_art/combat-fx/ice-wave/shatter.png")
# The two slabs in a pair meet before pressure passes on to the next pair.
const PAIR_STEP := 0.136
const FRONT_DELAY := 0.036
const CONTACT_STEP := 0.038
const LAST_CONTACT := 8
const RISE_TIME := 0.072
const SPIKE_LIFE := 0.49
const SHELL_TIME := 2.15
const BURST_LIFE := 0.30
const MAX_BURSTS := 24

var level := 0
var _stats := stats_for(1)
var _cooldown := 0.0
var _clock := 0.0
var _start := 0.0
var _origin := Vector2.ZERO
var _heading := Vector2.RIGHT
var _count := 0
var _contact_steps := PackedInt32Array()
var _cast_index := 0
var _reach := 0.0
var _radius := 0.0
var _damage := 0.0
var _chance := 0.0
var _hit := {}
var _shells := {}
var _bursts: Array[Dictionary] = []
var _burst_slot := 0
var _shape := CapsuleShape2D.new()
var _query := PhysicsShapeQueryParameters2D.new()
var _rng := RandomNumberGenerator.new()
@onready var game: Node = get_parent()

static func stats_for(rank: int) -> Dictionary:
	var step := clampi(rank, 1, 5) - 1
	return {"damage": 24.0 + 7.0 * step, "range": 180.0 + 30.0 * step,
		"radius": 21.0 + 3.0 * step, "freeze_chance": 0.40 + 0.08 * step, "interval": 1.80}

func _ready() -> void:
	z_index = 13
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_query.shape = _shape
	_query.collision_mask = 8
	_rng.randomize()
	reset()

func upgrade() -> void:
	level = mini(5, level + 1)
	_stats = stats_for(level)
	if level == 1: _cooldown = 0.22
	set_physics_process(true)

func clear_combat_effects() -> void:
	for id in _shells:
		var actor = _shells[id].actor
		if is_instance_valid(actor): actor.blade_ice = null
	_shells.clear()
	_hit.clear()
	_bursts.clear()
	_burst_slot = 0
	_count = 0
	queue_redraw()

func reset() -> void:
	clear_combat_effects()
	level = 0
	_cooldown = 0.0
	set_physics_process(false)

func cast() -> bool:
	if _count > 0 or level == 0 or not game.variety._battle_active(): return false
	var stats := COMBOS.combat_stats("ice_wave", _stats, game.equipment_panel.crimson_active)
	_origin = game.player.global_position
	var target := CombatTargets.nearest(_origin, float(stats.range) ** 2)
	if not is_instance_valid(target) or not game.is_ancestor_of(target): return false
	_heading = _origin.direction_to(target.global_position)
	if _heading.is_zero_approx(): _heading = Vector2.RIGHT
	_reach = stats.range
	_radius = stats.radius
	_damage = stats.damage
	_chance = stats.freeze_chance
	_shape.radius = _radius
	_count = ceili((_reach - 2 * _radius) / (1.40 * _radius)) + 1
	_cast_index += 1
	_contact_steps.resize(_count)
	_contact_steps.fill(0)
	_start = _clock
	_hit.clear()
	_cooldown = stats.interval
	return true

func _birth(index: int) -> float:
	return floori(index * 0.5) * PAIR_STEP + (index % 2) * FRONT_DELAY

func _pressure(pair_age: float) -> float:
	return smoothstep(0.068, 0.175, pair_age) * (1.0 - smoothstep(0.175, 0.278, pair_age))

func _sway(index: int, age: float) -> float:
	# Phase lags down the ridge. A smaller harmonic makes the return stroke asymmetric.
	var phase := age * (17.8 + 0.7 * (index % 3)) - 0.57 * index + 0.73 * (_cast_index % 9)
	var envelope := smoothstep(0.014, 0.095, age) * (1.0 - smoothstep(0.32, SPIKE_LIFE, age))
	return envelope * (sin(phase) + 0.13 * sin(2.0 * phase + 0.8)) / 1.13

func _plate_center(index: int, local_age: float) -> Vector2:
	var front := index % 2
	var pair_age := local_age + front * FRONT_DELAY
	# Reserve a last stride at the far end so the outer peak can advance as it rises.
	var pitch := (_reach - 2.0 * _radius) / (_count - 1 + 1.20)
	var push := smoothstep(0.034, 0.182, pair_age)
	var slide := smoothstep(0.161, 0.319, pair_age)
	var follow := smoothstep(0.225, 0.43, pair_age)
	var shift := -0.61 + 1.23 * push + 0.61 * follow
	if front:
		shift = -0.43 + 0.12 * push + 1.46 * slide + 0.12 * follow
	var along := clampf(_radius + (index + shift) * pitch, _radius, _reach - _radius)
	var side := _radius * (0.46 + 0.055 * (index % 3)) * _sway(index, local_age)
	return _origin + _heading * along + _heading.orthogonal() * side

func _erupt(start: Vector2, finish: Vector2) -> void:
	# Narrow ground sweep of the moving base, including the initial circular contact.
	_shape.height = 2.0 * _radius + start.distance_to(finish)
	var delta_pos := finish - start
	_query.transform = Transform2D(delta_pos.angle() - PI * 0.5, (start + finish) * 0.5)
	var excluded: Array[RID] = []
	while _count > 0:
		_query.exclude = excluded
		var contacts := get_world_2d().direct_space_state.intersect_shape(_query, 32)
		for contact in contacts:
			var actor: Node2D = contact.collider
			excluded.append(contact.rid)
			if not is_instance_valid(actor) or actor.is_queued_for_deletion() or not actor.is_in_group("EnemyGroup"): continue
			var id := actor.get_instance_id()
			if _hit.has(id) or not game.is_ancestor_of(actor) or not actor.has_method("apply_hit"): continue
			if actor.has_method("vulnerable") and not actor.vulnerable(): continue
			_hit[id] = true
			var had_shell := _shells.has(id)
			actor.apply_hit({"hitstop": false, "budget_impact": true, "damage": _damage, "direction": _heading, "source": self})
			if _count == 0: return # A lethal hit can synchronously end the encounter.
			if had_shell or not is_instance_valid(actor) or actor.is_queued_for_deletion() or not actor.is_in_group("EnemyGroup"): continue
			if actor.has_method("encase_in_blade_ice") and _rng.randf() < _chance:
				_freeze(actor)
		if contacts.size() < 32: break

func _freeze(actor: Node2D) -> void:
	var seconds := 0.85 if actor.has_method("is_control_immune") else SHELL_TIME
	var ice := ICE.new(self, seconds, _damage * 0.60)
	if not actor.encase_in_blade_ice(ice): return
	var sprite: Sprite2D = actor.sprite_2d
	var size := Vector2(34, 38)
	if is_instance_valid(sprite):
		size = sprite.get_rect().size * sprite.global_scale.abs() * 1.15
	size = size.clamp(Vector2(30, 34), Vector2(168, 176))
	_shells[actor.get_instance_id()] = {"actor": actor, "size": size, "start": _clock}
	queue_redraw()

func end_shell(actor: Node2D, shattered: bool) -> void:
	var id := actor.get_instance_id()
	if not _shells.has(id): return
	if shattered:
		var burst := {"at": actor.sprite_2d.global_position, "size": _shells[id].size * 1.45, "start": _clock}
		if _bursts.size() < MAX_BURSTS: _bursts.append(burst)
		else:
			_bursts[_burst_slot] = burst
			_burst_slot = (_burst_slot + 1) % MAX_BURSTS
	_shells.erase(id)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if not game.variety._battle_active():
		if _count or not _shells.is_empty() or not _bursts.is_empty(): clear_combat_effects()
		return
	_clock += delta
	_cooldown -= delta
	if _cooldown <= 0.0 and _count == 0 and not cast(): _cooldown = 0.16
	var age := _clock - _start
	if _count:
		for i in _count:
			var local_age := age - _birth(i)
			var step := _contact_steps[i]
			while step <= LAST_CONTACT and local_age >= RISE_TIME + step * CONTACT_STEP:
				var sample_age := RISE_TIME + step * CONTACT_STEP
				var prior_age := maxf(RISE_TIME, sample_age - CONTACT_STEP)
				_erupt(_plate_center(i, prior_age), _plate_center(i, sample_age))
				if _count == 0: return
				step += 1
			_contact_steps[i] = step
		if age >= _birth(_count - 1) + SPIKE_LIFE: _count = 0
		queue_redraw()
	if not _bursts.is_empty():
		for i in range(_bursts.size()-1, -1, -1):
			if _clock - _bursts[i].start >= BURST_LIFE: _bursts.remove_at(i)
		queue_redraw()
	if not _shells.is_empty(): queue_redraw()

func _stamp(atlas: Texture2D, frame: int, size: Vector2, at: Vector2, anchor: Vector2, cell: int, row := 0, tilt := 0.0, flip := false) -> void:
	draw_set_transform(to_local(at), tilt, Vector2(-1, 1) if flip else Vector2.ONE)
	draw_texture_rect_region(atlas, Rect2(-anchor * size, size), Rect2(frame * cell, row * cell, cell, cell))

func _shell_frame(age: float, offset: float) -> int:
	if age < 0.22: return mini(3, floori(age / 0.055))
	# Give the polished face a short sweep followed by a quiet hold.
	var phase := fposmod(age - 0.22 + offset, 0.92)
	if phase >= 0.40: return 4
	return 4 + floori(phase / 0.10)

func _draw() -> void:
	# Paint the plates nearest the camera last when the wave approaches it.
	for order in _count:
		var i := _count - order - 1 if _heading.y < -0.1 else order
		var age := _clock - _start - _birth(i)
		if age < 0.0 or age >= SPIKE_LIFE: continue
		var front := i % 2
		var pair_age := age + front * FRONT_DELAY
		var pressure := _pressure(pair_age)
		var row := (floori(i * 0.5) + front + _cast_index) % 3
		var lift := pressure * (0.33 if front else 0.18)
		var recede := smoothstep(0.20, 0.41, age)
		var width := _radius * (1.94 - 0.12 * pressure) * (1.0 - 0.20 * recede)
		var height := _radius * (2.12 + 0.22 * row + lift) * (1.0 - 0.50 * recede)
		# A tall point reacts slightly after its foot slips. This screen-space
		# lean also reads when casting straight up or down the arena.
		var tilt := 0.37 * _sway(i, maxf(age - 0.040, 0.0))
		tilt += _heading.x * (0.09 + (-0.10 if front else 0.10) * pressure)
		var frame := floori(age / RISE_TIME * 2)
		if age >= 0.16:
			frame = mini(7, 5 + floori((age - 0.16) / 0.115))
		elif age >= RISE_TIME:
			frame = 2 + mini(2, floori((age - RISE_TIME) / (0.16 - RISE_TIME) * 3))
		_stamp(ERUPTION, frame, Vector2(width, height), _plate_center(i, age), Vector2(0.5, 39.0/48.0), 48, row, tilt, _heading.x < 0)
	for id in _shells:
		var entry: Dictionary = _shells[id]
		var actor = entry.actor
		if is_instance_valid(actor):
			_stamp(SHELL, _shell_frame(_clock - entry.start, float(id % 7) * 0.035), entry.size, actor.sprite_2d.global_position, Vector2(0.5,0.5), 40)
	for burst in _bursts:
		_stamp(SHATTER, clampi(int((_clock-burst.start)/BURST_LIFE*6),0,5), burst.size, burst.at, Vector2(0.5,0.5), 48)
	draw_set_transform(Vector2.ZERO)
