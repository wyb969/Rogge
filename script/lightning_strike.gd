extends Node2D

const GOLD: = GamePalette.FRIENDLY_LIGHT
const VIOLET: = GamePalette.FRIENDLY_BLUE
const LIFETIME: = 0.46
var tint: = GOLD
var age: = 0.0
var bolts: Array[Dictionary] = []
var _targets: Array[Vector2] = []
var _rng: = RandomNumberGenerator.new()

func setup(targets: Array[Vector2], color: Color) -> void :
	_targets = targets.duplicate()
	tint = color

func _ready() -> void :
	add_to_group("lightning_fx")
	z_index = 30
	_rng.randomize()
	for target in _targets:
		var end: = to_local(target)
		var start: = end + Vector2(_rng.randf_range(-58, 58), - _rng.randf_range(135, 220))
		var frames: Array[Dictionary] = []
		for _i in 3:
			frames.append(_make_frame(start, end))
		bolts.append({"end": end, "delay": _rng.randf_range(0, 0.055), "frames": frames, "spark_angle": _rng.randf_range(0, TAU)})
	queue_redraw()

func _make_frame(start: Vector2, end: Vector2) -> Dictionary:
	var trunk: = _jagged(start, end, _rng.randi_range(7, 11), _rng.randf_range(12, 26))
	var branches: Array[PackedVector2Array] = []
	for _i in _rng.randi_range(2, 4):
		var at: = _rng.randi_range(2, trunk.size() - 3)
		var root: = trunk[at]
		var side: = -1.0 if _rng.randf() < 0.5 else 1.0
		var tip: = root + Vector2(side * _rng.randf_range(20, 52), _rng.randf_range(12, 42))
		branches.append(_jagged(root, tip, 3, 8))
	return {"trunk": trunk, "branches": branches}

func _jagged(start: Vector2, end: Vector2, segments: int, spread: float) -> PackedVector2Array:
	var points: = PackedVector2Array([start])
	var side: = (end - start).normalized().orthogonal()
	for i in range(1, segments):
		var t: = float(i) / segments
		points.append(start.lerp(end, t) + side * _rng.randf_range( - spread, spread) * sin(PI * t))
	points.append(end)
	return points

func _process(delta: float) -> void :
	age += delta
	if age >= LIFETIME:
		queue_free()
	else:
		queue_redraw()

func _draw() -> void :
	for bolt in bolts:
		var elapsed: float = age - bolt.delay
		if elapsed < 0:
			continue
		var frame: = 0 if elapsed < 0.065 else (1 if elapsed < 0.14 else 2)
		var alpha: = maxf(0, 1.0 - elapsed / LIFETIME)

		if (elapsed > 0.045 and elapsed < 0.065) or (elapsed > 0.12 and elapsed < 0.14):
			alpha *= 0.16
		var shape: Dictionary = bolt.frames[frame]
		_stroke(shape.trunk, alpha, 1.0)
		for branch in shape.branches:
			_stroke(branch, alpha * 0.62, 0.48)
		var end: Vector2 = bolt.end
		draw_arc(end, 4 + elapsed * 18, 0, TAU, 16, Color(tint, alpha * 0.38), 1.0, false)
		for i in 5:
			var direction: = Vector2.from_angle(bolt.spark_angle + TAU * i / 5.0)
			draw_line(end + direction * (3 + elapsed * 22), end + direction * (7 + elapsed * 36), GamePalette.alpha(GamePalette.PLAYER_DAMAGE_WHITE, alpha), 1.5, true)

func _stroke(points: PackedVector2Array, alpha: float, width: float) -> void :
	draw_polyline(points, GamePalette.alpha(GamePalette.INK, alpha * 0.8), 5 * width, false)
	draw_polyline(points, Color(tint, alpha * 0.9), 2.7 * width, false)
	draw_polyline(points, GamePalette.alpha(GamePalette.PLAYER_DAMAGE_WHITE, alpha * 0.9), 0.9 * width, false)
