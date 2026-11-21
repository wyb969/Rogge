extends Node2D

const ICE := preload("res://script/blade_ice.gd")
const ERUPTION := preload("res://rogge_art/combat-fx/ice-wave/eruption.png")
const SHELL := preload("res://rogge_art/combat-fx/ice-wave/shell.png")
const SHATTER := preload("res://rogge_art/combat-fx/ice-wave/shatter.png")
const STEP_TIME := 0.064
const RISE_TIME := 0.072
const SPIKE_LIFE := 0.40
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
var _next := 0
var _reach := 0.0
var _radius := 0.0
var _damage := 0.0
var _chance := 0.0
var _hit := {}
var _shells := {}
var _bursts: Array[Dictionary] = []
var _burst_slot := 0
var _shape := CircleShape2D.new()
var _query := PhysicsShapeQueryParameters2D.new()
var _rng := RandomNumberGenerator.new()
@onready var game: Node = get_parent()

static func stats_for(rank: int) -> Dictionary:
	var step := clampi(rank, 1, 5) - 1
	return {"damage": 24.0 + 7.0 * step, "range": 180.0 + 30.0 * step,
		"radius": 21.0 + 3.0 * step, "freeze_chance": 0.26 + 0.09 * step, "interval": 1.80}

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
	_origin = game.player.global_position
	var target := CombatTargets.nearest(_origin, float(_stats.range) ** 2)
	if not is_instance_valid(target) or not game.is_ancestor_of(target): return false
	_heading = _origin.direction_to(target.global_position)
	if _heading.is_zero_approx(): _heading = Vector2.RIGHT
	_reach = _stats.range
	_radius = _stats.radius
	_damage = _stats.damage
	_chance = _stats.freeze_chance
	_shape.radius = _radius
	_count = ceili((_reach - 2 * _radius) / (1.40 * _radius)) + 1
	_next = 0
	_start = _clock
	_hit.clear()
	_cooldown = _stats.interval
	return true

func _center(index: int) -> Vector2:
	return _origin + _heading * lerpf(_radius, _reach - _radius, float(index) / (_count - 1))

func _erupt(at: Vector2) -> void:
	_query.transform = Transform2D(0.0, at)
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
			actor.apply_hit({"damage": _damage, "direction": _heading, "source": self})
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
		while _next < _count and age >= _next * STEP_TIME + RISE_TIME:
			_erupt(_center(_next))
			_next += 1
		if age >= (_count - 1) * STEP_TIME + SPIKE_LIFE: _count = 0
		queue_redraw()
	if not _bursts.is_empty():
		for i in range(_bursts.size()-1, -1, -1):
			if _clock - _bursts[i].start >= BURST_LIFE: _bursts.remove_at(i)
		queue_redraw()
	if not _shells.is_empty(): queue_redraw()

func _stamp(atlas: Texture2D, frame: int, size: Vector2, at: Vector2, anchor: Vector2, flip := false) -> void:
	var cell := float(atlas.get_height())
	var dest := Rect2(to_local(at) - anchor * size, size)
	if flip:
		dest.size.x = -size.x
	draw_texture_rect_region(atlas, dest, Rect2(cell * frame, 0, cell, cell))

func _draw() -> void:
	for i in _count:
		var age := _clock - _start - i * STEP_TIME
		if age < 0.0 or age >= SPIKE_LIFE: continue
		var frame := floori(age / RISE_TIME * 2) if age < RISE_TIME else mini(7, 2 + floori((age-RISE_TIME) / (SPIKE_LIFE-RISE_TIME) * 6))
		var width := 2.25 * _radius
		var height := width * (1.08 + 0.10 * (i % 3))
		_stamp(ERUPTION, frame, Vector2(width, height), _center(i), Vector2(0.5, 39.0/48.0), _heading.x < 0)
	for id in _shells:
		var entry: Dictionary = _shells[id]
		var actor = entry.actor
		if is_instance_valid(actor):
			_stamp(SHELL, mini(3, int((_clock-entry.start)*16)), entry.size, actor.sprite_2d.global_position, Vector2(0.5,0.5))
	for burst in _bursts:
		_stamp(SHATTER, clampi(int((_clock-burst.start)/BURST_LIFE*6),0,5), burst.size, burst.at, Vector2(0.5,0.5))
