extends Node2D

const MAX_LEVEL := 5
const LINKS := 15
const LINKS_PER_GROUP := 5
enum Stroke { SWEEP, FLICK, BACKHAND }
const HALF_WIDTH := 2.1
const ENEMY_LAYER := 8
const AFTERGLOW := Color("#ee245827")
const BLOOM := Color("#ff325e80")
const CORE := Color("#ff819d")
const HOT := Color("#ffebd9")

var level := 0
var casts := 0
var hits := 0
var _stats := stats_for(1)
var _cooldown := 0.0
var active := false
var _age := 0.0
var _duration := 0.0
var _aim := 0.0
var _side := 1.0
var _arc := 1.0
var _curl := 0.0
var _stroke := -1
var _turn_time := 0.0
var _overshoot := 0.0
var _return_angle := 0.0
var _wave_angle := 0.0
var _wave_width := 0.0
var _wave_delay := 0.0
var _wave_start := 0.0
var _reach := 0.0
var _damage := 0.0
var _rng := RandomNumberGenerator.new()
var _angles := PackedFloat32Array()
var _speeds := PackedFloat32Array()
var points := PackedVector2Array()
var previous := PackedVector2Array()
var _middle := PackedVector2Array()
var _struck := {}
var _hit_rids: Array[RID] = []
var _bounds_shape := RectangleShape2D.new()
var _bounds_query := PhysicsShapeQueryParameters2D.new()
var _shape := ConvexPolygonShape2D.new()
var _query := PhysicsShapeQueryParameters2D.new()
@onready var game: Node = get_parent()

static func stats_for(rank: int) -> Dictionary:
	var step := clampi(rank,1,MAX_LEVEL) - 1
	return {
		"damage": 32.0 + 8.0 * step,
		"range": 154.0 + 19.0 * step,
		"swing_time": 0.76 - 0.06 * step,
		"interval": 1.65 - 0.15 * step,
	}

func _ready() -> void:
	z_index = 12
	_angles.resize(LINKS)
	_speeds.resize(LINKS)
	points.resize(LINKS + 1)
	previous.resize(LINKS + 1)
	_middle.resize(LINKS + 1)
	_bounds_query.shape = _bounds_shape
	_bounds_query.collision_mask = ENEMY_LAYER
	_query.shape = _shape
	_query.collision_mask = ENEMY_LAYER
	_rng.randomize()
	reset()

func upgrade() -> void:
	level = mini(MAX_LEVEL, level + 1)
	_stats = stats_for(level)
	if level == 1: _cooldown = 0.25
	set_physics_process(true)

func clear_combat_effects() -> void:
	active = false
	_struck.clear()
	_hit_rids.clear()
	queue_redraw()

func reset() -> void:
	clear_combat_effects()
	level = 0
	_stroke = -1
	casts = 0
	hits = 0
	_cooldown = 0.0
	set_physics_process(false)

func cast() -> bool:
	if active or level <= 0 or not game.variety._battle_active(): return false
	var origin: Vector2 = game.player.global_position
	var target := CombatTargets.nearest(origin, float(_stats.range) ** 2)
	if not is_instance_valid(target) or not game.is_ancestor_of(target): return false
	_aim = (target.global_position - origin).angle() + _rng.randf_range(-0.12,0.12)
	_side = -1.0 if _rng.randf() < 0.5 else 1.0
	# Sample a new wrist impulse on each cast. Skip the preceding family,
	# then vary its shape continuously so consecutive casts read differently.
	if _stroke < 0:
		_stroke = _rng.randi_range(0, 2)
	else:
		_stroke = (_stroke + _rng.randi_range(1, 2)) % 3
	match _stroke:
		Stroke.SWEEP:
			_arc = _rng.randf_range(1.15, 1.95)
			_turn_time = _rng.randf_range(0.48, 0.60)
			_overshoot = _rng.randf_range(1.0, 1.60)
			_return_angle = _rng.randf_range(0.35, 0.80)
		Stroke.FLICK:
			_arc = _rng.randf_range(0.25, 0.62)
			_turn_time = _rng.randf_range(0.28, 0.37)
			_overshoot = _rng.randf_range(0.32, 0.68)
			_return_angle = _rng.randf_range(-0.75, -0.25)
		Stroke.BACKHAND:
			_arc = _rng.randf_range(0.65, 1.05)
			_turn_time = _rng.randf_range(0.32, 0.41)
			_overshoot = _rng.randf_range(0.85, 1.40)
			_return_angle = _rng.randf_range(-1.7, -1.05)
	_curl = _rng.randf_range(0.8,1.9)
	_wave_angle = _rng.randf_range(0.9, 2.2) * (-1.0 if _rng.randf() < 0.5 else 1.0)
	_wave_width = _rng.randf_range(0.19, 0.31)
	_wave_delay = _rng.randf_range(0.25, 0.40)
	_wave_start = _turn_time - _rng.randf_range(0.18, 0.27)
	_duration = float(_stats.swing_time) * _rng.randf_range(0.96, 1.04)
	_reach = float(_stats.range)
	_damage = float(_stats.damage)
	_age = 0.0
	active = true
	casts += 1
	_struck.clear()
	_hit_rids.clear()
	for i in LINKS:
		_angles[i] = _aim - _side * (_arc + _curl * float(i) / LINKS)
		_speeds[i] = 0.0
	_pose(origin, 0.0)
	for i in points.size(): previous[i] = points[i]
	_cooldown = float(_stats.interval)
	queue_redraw()
	return true

func _pose(origin: Vector2, t: float) -> void:
	var out := smoothstep(0.06, _turn_time, t)
	var extension := (0.22 + 0.78 * out) * (1.0 - 0.76 * smoothstep(0.80,1.0,t))
	var length := (_reach - 8.0) * extension / LINKS
	points[0] = origin + Vector2.from_angle(_angles[0]) * 8.0
	for i in LINKS:
		# A compact bipolar bending wave runs down the lash. The window
		# vanishes smoothly on both ends, leaving the grip steady.
		var along := float(i) / (LINKS - 1)
		var phase := (t - _wave_start - along * _wave_delay) / _wave_width
		var wave := 0.0
		if absf(phase) < 1.0:
			var envelope := 1.0 - phase * phase
			wave = 3.5 * phase * envelope * envelope
		var angle := _angles[i] + _side * _wave_angle * along * along * wave
		points[i+1] = points[i] + Vector2.from_angle(angle) * length

func _advance(dt: float, origin: Vector2) -> void:
	_age += dt
	var t := minf(_age / _duration, 1.0)
	# The wrist drives only the first link. Spring torque travels outward; lighter
	# distal links carry momentum through the wrist reversal and snap past it.
	var stroke := lerpf(-_arc, _overshoot, smoothstep(0.08, _turn_time, t))
	var recovery := _turn_time + 0.26
	stroke += (_return_angle - _overshoot) * smoothstep(_turn_time, recovery, t)
	if _stroke == Stroke.BACKHAND:
		stroke += (0.55 - _return_angle) * smoothstep(recovery, 0.95, t)
	_angles[0] = _aim + _side * stroke
	for i in range(1,LINKS):
		var along := float(i) / LINKS
		var omega := lerpf(96.0,125.0,along)
		var bend := angle_difference(_angles[i],_angles[i-1])
		# Implicit damped spring stays stable through a sharp change in direction.
		var damping := 2.0 * lerpf(0.83,0.62,along) * omega
		_speeds[i] = (_speeds[i] + dt * omega * omega * bend) / (1.0 + dt * damping + dt * dt * omega * omega)
		_angles[i] += _speeds[i] * dt
	_pose(origin,t)

func _physics_process(delta: float) -> void:
	if not game.variety._battle_active():
		if active: clear_combat_effects()
		return
	_cooldown -= delta
	if not active:
		if _cooldown > 0.0: return
		if not cast():
			_cooldown = 0.17
			return
	for i in points.size(): previous[i] = points[i]
	var anchor: Vector2 = game.player.global_position
	if previous[0].distance_to(anchor) > _reach:
		clear_combat_effects()
		return
	var dt := minf(delta, _duration - _age)
	# At the normal 60 Hz physics rate solve twice. Only split collision at
	# the intermediate pose when collapsing it would cut across a tight turn.
	var prior_anchor := previous[0] - Vector2.from_angle(_angles[0]) * 8.0
	_advance(dt * 0.5, prior_anchor.lerp(anchor, 0.5))
	for i in points.size(): _middle[i] = points[i]
	_advance(dt * 0.5, anchor)
	var curved := false
	for i in points.size():
		if _middle[i].distance_squared_to((previous[i] + points[i]) * 0.5) > HALF_WIDTH * HALF_WIDTH:
			curved = true
			break
	if curved:
		_sweep(previous, _middle)
		if active: _sweep(_middle, points)
	else:
		_sweep(previous, points)
	if _age >= _duration - 0.00001: active = false
	queue_redraw()

func _sweep(start: PackedVector2Array, finish: PackedVector2Array) -> void:
	var space := get_world_2d().direct_space_state
	for first in range(0, LINKS, LINKS_PER_GROUP):
		var last := mini(first + LINKS_PER_GROUP, LINKS)
		var bounds := Rect2(start[first], Vector2.ZERO)
		for i in range(first, last + 1):
			bounds = bounds.expand(start[i]).expand(finish[i])
		bounds = bounds.grow(HALF_WIDTH)
		_bounds_shape.size = bounds.size
		_bounds_query.transform = Transform2D(0.0, bounds.get_center())
		_bounds_query.exclude = _hit_rids
		if space.intersect_shape(_bounds_query, 1).is_empty(): continue
		_hit_links(space, start, finish, first, last)
		if not active: return

func _hit_links(space: PhysicsDirectSpaceState2D, start: PackedVector2Array, finish: PackedVector2Array, first: int, last: int) -> void:
	for i in range(first, last):
		var a := start[i]
		var b := start[i + 1]
		var c := finish[i]
		var d := finish[i + 1]
		var n := a.direction_to(b).orthogonal() * HALF_WIDTH
		var m := c.direction_to(d).orthogonal() * HALF_WIDTH
		# Sweep the old and new visible strip together to catch a fast-moving tip.
		var hull := Geometry2D.convex_hull(PackedVector2Array([a+n,b+n,b-n,a-n,c+m,d+m,d-m,c-m]))
		hull.resize(hull.size()-1)
		_shape.points = hull
		_query.exclude = _hit_rids
		while active:
			var contacts := space.intersect_shape(_query,32)
			for contact in contacts:
				var actor: Node2D = contact.collider
				if not is_instance_valid(actor): continue
				var id := actor.get_instance_id()
				if _struck.has(id) or actor.is_queued_for_deletion() or not actor.is_in_group("EnemyGroup") or not game.is_ancestor_of(actor): continue
				if not actor.has_method("apply_hit") or (actor.has_method("vulnerable") and not actor.vulnerable()): continue
				_struck[id] = true
				_hit_rids.append(contact.rid)
				hits += 1
				actor.apply_hit({"damage":_damage, "direction":c.direction_to(d), "source":self})
				if not active: return
			if contacts.size() < 32: break
			# Godot copies query.exclude. Only allocate a pagination list when
			# a single link actually fills the entire result page.
			var excluded := _query.exclude
			for contact in contacts: excluded.append(contact.rid)
			_query.exclude = excluded

func _draw() -> void:
	if not active: return
	draw_set_transform_matrix(global_transform.affine_inverse())
	draw_polyline(previous, AFTERGLOW, 6.0)
	draw_polyline(points, AFTERGLOW, 13.0)
	draw_polyline(points, BLOOM, 7.0)
	draw_polyline(points, CORE, 2.0 * HALF_WIDTH)
	draw_polyline(points, HOT, 1.4)
	for i in range(3,LINKS,3):
		var axis := points[i-1].direction_to(points[i])
		var normal := axis.orthogonal() * (1 if i % 2 else -1)
		var tip := points[i] - axis * 3 + normal * 4
		draw_colored_polygon(PackedVector2Array([points[i]-axis*2,tip,points[i]+axis*2]), CORE)
	var tip := points[LINKS]
	draw_circle(tip,3.4,BLOOM)
	draw_circle(tip,1.8,HOT)
