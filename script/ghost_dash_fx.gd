extends Node2D

const SKULL := preload("res://rogge_art/combat-fx/ghost-dash/skull.png")
const INK := Color("#53436f")
const PLUME := Color("#ad83cd")
const GLEAM := Color("#f4d5ee")
const TRAIL_LIFE := 0.24
const MAX_SEGMENTS := 32

var _starts := PackedVector2Array()
var _ends := PackedVector2Array()
var _distances := PackedFloat32Array()
var _born := PackedFloat64Array()
var width_scale := 1.0
var _first := 0
var _count := 0
var _clock := 0.0
var _run_distance := 0.0

func _ready() -> void:
	z_index = 18
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_starts.resize(MAX_SEGMENTS)
	_ends.resize(MAX_SEGMENTS)
	_distances.resize(MAX_SEGMENTS)
	_born.resize(MAX_SEGMENTS)
	set_process(false)

func clear() -> void:
	_first = 0
	_count = 0
	_clock = 0.0
	_run_distance = 0.0
	set_process(false)
	queue_redraw()

func trail_segment(start: Vector2, finish: Vector2) -> void:
	var length := start.distance_to(finish)
	if length <= 0.01: return
	if _count == 0: _run_distance = 0.0
	var index := (_first + _count) % MAX_SEGMENTS
	if _count == MAX_SEGMENTS:
		_first = (_first + 1) % MAX_SEGMENTS
	else:
		_count += 1
	_starts[index] = to_local(start)
	_ends[index] = to_local(finish)
	_born[index] = _clock
	_distances[index] = _run_distance
	_run_distance += length
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	_clock += delta
	while _count > 0 and _clock - _born[_first] >= TRAIL_LIFE:
		_first = (_first + 1) % MAX_SEGMENTS
		_count -= 1
	if _count == 0:
		set_process(false)
	queue_redraw()

func _draw() -> void:
	for i in _count:
		var index := (_first + i) % MAX_SEGMENTS
		_draw_segment(index, clampf((_clock - _born[index]) / TRAIL_LIFE, 0.0, 1.0))
	var marks: Dictionary = get_parent().marks
	for id in marks:
		var entry: Dictionary = marks[id]
		if entry.controlled and is_instance_valid(entry.actor):
			draw_mark(entry.actor, entry.age, 1.0)

func _draw_segment(index: int, progress: float) -> void:
	var travel := _ends[index] - _starts[index]
	var distance := travel.length()
	var side := travel.orthogonal() * width_scale / distance
	var phase := _distances[index] * 0.12
	var next_phase := phase + distance * 0.12
	var fade := 1.0 - smoothstep(0.12, 1.0, progress)
	var rise := Vector2.UP * (4.0 + 6.0 * progress)
	var a := _starts[index] + side * (2.4 * sin(phase)) + rise
	var b := _ends[index] + side * (2.4 * sin(next_phase)) + rise
	draw_line(a.round(), b.round(), Color(INK, fade * 0.72), (4.2 * fade + 0.5) * width_scale)
	draw_line((a - side).round(), (b - side).round(), Color(PLUME, fade * 0.90), 1.6)
	var strand := side * (4.0 + 3.0 * progress)
	if sin(phase + 0.3) > -0.1:
		draw_line((a + strand).round(), (b + strand).round(), Color(GLEAM, fade * 0.78), 1.0)
	if sin(phase) < -0.5:
		var mote := a.lerp(b, 0.4) - strand - Vector2(0, 6.0 * progress)
		draw_rect(Rect2(mote.round(), Vector2.ONE * 2.0), Color(PLUME, fade))

static func mark_opacity(age: float, duration: float) -> float:
	var t := clampf(age / maxf(duration, 0.001), 0.0, 1.0)
	return smoothstep(0.0, 0.16, t) * (1.0 - smoothstep(0.65, 1.0, t))

func draw_mark(actor: Node2D, age: float, duration: float) -> void:
	var alpha := mark_opacity(age, duration)
	if alpha <= 0.0: return
	var crown := actor.global_position - Vector2(0, 12)
	var sprite := actor.get_node_or_null(^"Sprite2D") as Sprite2D
	if sprite and sprite.texture:
		var rect := sprite.get_rect()
		crown = sprite.to_global(rect.position + Vector2(0.5 * rect.size.x, 0))
	var drift := 1.0 + 2.0 * sin(PI * age / duration)
	var at := to_local(crown) - Vector2(0.5 * SKULL.get_width(), SKULL.get_height() + drift)
	draw_texture(SKULL, at.round(), Color(Color.WHITE, alpha))
