extends Node

const RADIUS: = 78.0
const CELL: = 80.0
const MAX_REQUESTS: = 512
const MAX_BUCKETS: = 256
const ENEMY: = preload("res://script/enemy_shell.gd")
var _requests: = PackedVector3Array()
var _sources: = PackedInt64Array()
var _potencies: = PackedFloat64Array()
var _count: = 0
var _targets: Array[Node2D] = []
var _stacks: = PackedInt32Array()
var _dps: = PackedFloat64Array()
var _capacity: = PackedInt32Array()
var _positions: = PackedVector2Array()
var _ids: = PackedInt64Array()
var _dirty: = PackedByteArray()
var _buckets: Array[Array] = []
var _cells: = {}
var _overflow: Array[int] = []
var _used: = 0
var batches: = 0
var examined: = 0
var distance_checks: = 0
var applied: = 0
@onready var game: Node = get_parent()

func _ready() -> void :
	_requests.resize(MAX_REQUESTS)
	_sources.resize(MAX_REQUESTS)
	_potencies.resize(MAX_REQUESTS)
	for _i in MAX_BUCKETS: _buckets.append([])
	process_physics_priority = 100
	set_physics_process(false)

func reset() -> void :
	_count = 0
	_clear_index()
	set_physics_process(false)

func _clear_index() -> void :
	for i in _used: _buckets[i].clear()
	_used = 0
	_cells.clear()
	_overflow.clear()
	_targets.clear()

func request(actor: Node2D, potency: float) -> void :

	if _count == MAX_REQUESTS: flush()
	_requests[_count] = Vector3(actor.global_position.x, actor.global_position.y, 0)
	_potencies[_count] = potency
	_sources[_count] = actor.get_instance_id()
	_count += 1
	set_physics_process(true)

func _physics_process(_delta: float) -> void : flush()

func flush() -> void :
	if _count == 0 or get_tree().paused: return
	batches += 1
	_clear_index()
	var origin: = Vector2(_requests[0].x, _requests[0].y)
	var bounds: = Rect2(origin, Vector2.ZERO)
	var max_potency: = 0.0
	for i in _count:
		bounds = bounds.expand(Vector2(_requests[i].x, _requests[i].y))
		max_potency = maxf(max_potency, _potencies[i])
	CombatTargets.fill_in_bounds(bounds.grow(RADIUS + 0.001), game, _targets)
	examined += CombatTargets._entries.size()
	_stacks.resize(_targets.size())
	_dps.resize(_targets.size())
	_capacity.resize(_targets.size())
	_positions.resize(_targets.size())
	_ids.resize(_targets.size())
	_dirty.resize(_targets.size())
	_stacks.fill(0)
	_dps.fill(0)
	_dirty.fill(0)
	for i in _targets.size():
		var actor: = _targets[i]
		if not actor.has_method("apply_burn"): continue
		_positions[i] = actor.global_position
		_ids[i] = actor.get_instance_id()
		_capacity[i] = maxi(0, actor.MAX_BURN_STACKS - actor.burn_stacks) if actor is ENEMY else MAX_REQUESTS
		_dps[i] = actor.burn_dps if "burn_dps" in actor else 0.0
		if _capacity[i] == 0 and _dps[i] >= max_potency: continue
		var cell: = Vector2i((actor.global_position / CELL).floor())
		if not _cells.has(cell):
			if _used == MAX_BUCKETS:
				_overflow.append(i)
				continue
			_cells[cell] = _used
			_used += 1
		_buckets[_cells[cell]].append(i)
	for i in _count:
		var at: = Vector2(_requests[i].x, _requests[i].y)
		var source: int = _sources[i]
		var potency: float = _potencies[i]
		var lower: = Vector2i(((at - Vector2.ONE * RADIUS) / CELL).floor())
		var upper: = Vector2i(((at + Vector2.ONE * RADIUS) / CELL).floor())
		for y in range(lower.y, upper.y + 1):
			for x in range(lower.x, upper.x + 1):
				var cell: = Vector2i(x, y)
				if _cells.has(cell):
					_accumulate_bucket(_buckets[_cells[cell]], at, source, potency)
		_accumulate_bucket(_overflow, at, source, potency)

	for i in _targets.size():
		if not _dirty[i]: continue
		var actor: = _targets[i]
		if not is_instance_valid(actor) or actor.is_queued_for_deletion() or not actor.is_in_group("EnemyGroup"): continue
		actor.apply_burn({"burn_stacks": _stacks[i], "burn_dps": _dps[i], "from_spread": true})
		applied += 1
	_count = 0
	_clear_index()
	set_physics_process(false)

func _accumulate_bucket(bucket: Array, at: Vector2, source: int, potency: float) -> void :
	for index in bucket:

		if _stacks[index] >= _capacity[index] and _dps[index] >= potency: continue
		if _ids[index] == source: continue
		distance_checks += 1
		if at.distance_squared_to(_positions[index]) > RADIUS * RADIUS: continue
		_stacks[index] = mini(_capacity[index], _stacks[index] + 1)
		_dps[index] = maxf(_dps[index], potency)
		_dirty[index] = 1
