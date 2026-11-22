extends Node2D

const COMBOS := preload("res://script/equipment_combos.gd")

const FX := preload("res://script/ghost_dash_fx.gd")
const HOLD_TIME := 1.0
# Half-width of the player's body, independent of the coin pickup radius.
const PATH_RADIUS := 12.0
const PAGE_SIZE := 64

var level := 0
var _stats := stats_for(1)
var marks := {}
var _touched := {}
var pass_distance := 0.0
var _damage := 0.0
var _shape := CapsuleShape2D.new()
var _query := PhysicsShapeQueryParameters2D.new()
var _fx := FX.new()
@onready var game: Node = get_parent()

static func stats_for(rank: int) -> Dictionary:
	var step := clampi(rank, 1, 5) - 1
	return {"damage": 30.0 + 9.0 * step, "radius": PATH_RADIUS, "range": 132.0 + 18.0 * step, "interval": 2.70 - 0.30 * step}

func _ready() -> void:
	add_child(_fx)
	_query.shape = _shape
	_query.collision_mask = 8
	_shape.radius = PATH_RADIUS
	game.player.ghost_dash = self
	set_physics_process(false)

func upgrade() -> void:
	level = mini(5, level + 1)
	_stats = stats_for(level)

func begin_pass() -> void:
	_touched.clear()
	var stats := COMBOS.combat_stats("ghost_dash", _stats, game.equipment_panel.crimson_active)
	pass_distance = stats.range
	_damage = stats.damage
	_shape.radius = stats.radius
	_fx.width_scale = stats.radius / PATH_RADIUS

func sweep(start: Vector2, finish: Vector2) -> void:
	if level <= 0 or not game.variety._battle_active(): return
	_fx.trail_segment(start, finish)
	_shape.height = 2 * _shape.radius + start.distance_to(finish)
	_query.transform = Transform2D((finish - start).angle() - PI / 2, (start + finish) * 0.5)
	var excluded: Array[RID] = []
	var world := get_world_2d().direct_space_state
	while true:
		_query.exclude = excluded
		var hits := world.intersect_shape(_query, PAGE_SIZE)
		for hit in hits:
			excluded.append(hit.rid)
			var actor: Node2D = hit.collider
			var id := actor.get_instance_id()
			if _touched.has(id) or not actor.is_in_group("EnemyGroup") or not game.is_ancestor_of(actor): continue
			if not actor.has_method("apply_hit") or (actor.has_method("vulnerable") and not actor.vulnerable()): continue
			_touched[id] = true
			var bound: bool = actor.has_method("bind_ghost") and actor.bind_ghost()
			# A rest cooldown bonus can bring a second pass inside the first second.
			var pending: Array = []
			if marks.has(id):
				var previous: Dictionary = marks[id]
				pending = previous.pending
				pending.append({"left": HOLD_TIME - previous.age, "damage": previous.damage})
			marks[id] = {"actor": actor, "age": 0.0, "damage": _damage, "controlled": bound, "born": Engine.get_physics_frames(), "pending": pending}
		if hits.size() < PAGE_SIZE: break
	_query.exclude = []
	set_physics_process(not marks.is_empty())

func _physics_process(delta: float) -> void:
	if not game.variety._battle_active():
		clear_combat_effects()
		return
	for id in marks.keys():
		# A delayed kill may synchronously end the stage and clear every mark.
		if not marks.has(id): continue
		var mark: Dictionary = marks[id]
		var actor = mark.actor
		if not is_instance_valid(actor) or actor.is_queued_for_deletion() or not actor.is_in_group("EnemyGroup"):
			_release(mark)
			marks.erase(id)
			continue
		var pending: Array = mark.pending
		for impact in pending: impact.left -= delta
		while not pending.is_empty() and pending[0].left <= 0.000001:
			var due: Dictionary = pending.pop_front()
			_deal_damage(actor, due.damage)
			if not marks.has(id): break
		if not marks.has(id) or mark.born == Engine.get_physics_frames(): continue
		if mark.controlled and not actor.ghost_bound: mark.controlled = false
		mark.age += delta
		if mark.age < HOLD_TIME - 0.000001: continue
		marks.erase(id)
		_release(mark)
		_deal_damage(actor, mark.damage)
	_fx.queue_redraw()
	set_physics_process(not marks.is_empty())

func _deal_damage(actor: Node2D, amount: float) -> void:
	if is_instance_valid(actor) and not actor.is_queued_for_deletion() and actor.is_in_group("EnemyGroup"):
		if not actor.has_method("vulnerable") or actor.vulnerable():
			actor.apply_hit({"damage": amount, "from_status": true, "source": self})

func _release(mark: Dictionary) -> void:
	if mark.controlled and is_instance_valid(mark.actor): mark.actor.ghost_bound = false

func clear_combat_effects() -> void:
	game.player.cancel_ghost_dash()
	for mark in marks.values(): _release(mark)
	marks.clear()
	_touched.clear()
	_fx.clear()
	set_physics_process(false)

func reset() -> void:
	clear_combat_effects()
	level = 0
