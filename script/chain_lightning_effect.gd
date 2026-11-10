extends Node2D


@export var jump_delay: = 0.08
@export var line_lifetime: = 0.14
const MAX_VISIBLE_LINKS: = 8
var hit_enemies: = {}
var pool_owner: WeakRef
var active: = false
var _current: Node2D
var _damage: = 0.0
var _remaining: = 0
var _range_squared: = 0.0
var _group: StringName = &"EnemyGroup"
var _jump_left: = 0.0
var _tail_left: = 0.0
var _points: Array[PackedVector2Array] = []
var _lives: = PackedFloat32Array()
var _next_link: = 0
var _rng: = RandomNumberGenerator.new()

func _ready() -> void :
	_rng.randomize()
	_lives.resize(MAX_VISIBLE_LINKS)
	for _i in MAX_VISIBLE_LINKS:
		var points: = PackedVector2Array()
		points.resize(6)
		_points.append(points)
	set_process(false)
	hide()

func start_chain(first_enemy: Node2D, data: Dictionary) -> void :
	hit_enemies.clear()
	_lives.fill(0)
	_next_link = 0
	_current = first_enemy
	_damage = float(data.get("damage", 5))
	_remaining = maxi(0, int(data.get("chain_count", 3)))
	_range_squared = pow(float(data.get("chain_range", 180)), 2)
	_group = StringName(data.get("enemy_group", "EnemyGroup"))
	_jump_left = maxf(jump_delay, 0.001)
	_tail_left = line_lifetime
	active = true
	global_position = Vector2.ZERO
	if is_instance_valid(first_enemy): hit_enemies[first_enemy] = true
	show()
	set_process(true)
	_jump()
	queue_redraw()

func _jump() -> void :
	if _remaining <= 0 or not is_instance_valid(_current):
		_remaining = 0
		_tail_left = line_lifetime
		return
	var next: = CombatTargets.nearest(_current.global_position, _range_squared, hit_enemies, _group)
	if next == null:
		_remaining = 0
		_tail_left = line_lifetime
		return
	var from: = _current.global_position
	var to: = next.global_position
	draw_line_between(from, to)
	hit_enemies[next] = true
	_current = next
	_remaining -= 1
	if next.has_method("apply_hit"):
		next.apply_hit({"damage": _damage, "direction": (to - from).normalized(), "effect": "lightning", "source": self})
	if _remaining == 0: _tail_left = jump_delay + line_lifetime

func _process(delta: float) -> void :
	if not active or get_tree().paused: return
	var i: = 0
	while i < MAX_VISIBLE_LINKS:
		_lives[i] = maxf(0, _lives[i] - delta)
		i += 1
	var budget: = delta
	while _remaining > 0 and budget >= _jump_left:
		budget -= _jump_left
		_jump()
		_jump_left = maxf(jump_delay, 0.001)
	if _remaining > 0:
		_jump_left -= budget
	else:
		_tail_left -= budget
		if _tail_left <= 0:
			_finish()
			return
	queue_redraw()

func _finish() -> void :
	if not active: return
	active = false
	_current = null
	hit_enemies.clear()
	_lives.fill(0)
	set_process(false)
	hide()
	var owner: Object = pool_owner.get_ref() if pool_owner != null else null
	if owner != null and not owner.is_queued_for_deletion(): owner.recycle_chain_lightning(self)
	else: queue_free()

func find_nearest_enemy(from_pos: Vector2, search_range: float, enemy_group: StringName) -> Node2D:
	return CombatTargets.nearest(from_pos, search_range * search_range, hit_enemies, enemy_group)

func draw_line_between(start: Vector2, end: Vector2) -> void :
	var points: = _points[_next_link]
	var i: = 0
	while i < 6:
		var point: = start.lerp(end, float(i) / 5)
		if i != 0 and i != 5: point += Vector2(_rng.randf_range(-10, 10), _rng.randf_range(-10, 10))
		points[i] = point
		i += 1
	_points[_next_link] = points
	_lives[_next_link] = line_lifetime
	_next_link = (_next_link + 1) % MAX_VISIBLE_LINKS

func _draw() -> void :
	var i: = 0
	while i < MAX_VISIBLE_LINKS:
		if _lives[i] > 0: draw_polyline(_points[i], Color(0.48, 0.78, 0.84, _lives[i] / maxf(line_lifetime, 0.001)), 1.8, false)
		i += 1
