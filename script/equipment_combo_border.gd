extends Control

const SEGMENTS := 16
const TAIL := 0.24
var combo_group := ""
var tint := Color.WHITE
var phase := 0.0
var _trail := PackedVector2Array()
var _colors := PackedColorArray()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_trail.resize(SEGMENTS + 1)
	_colors.resize(SEGMENTS + 1)
	resized.connect(queue_redraw)
	set_process(false)

func configure(group: String, color: Color, active: bool) -> void:
	combo_group = group
	tint = color
	visible = active
	queue_redraw()

func set_phase(value: float) -> void:
	phase = fposmod(value, 1.0)
	queue_redraw()

func _edge_point(progress: float, rect: Rect2) -> Vector2:
	var w := rect.size.x
	var h := rect.size.y
	var distance := fposmod(progress, 1.0) * 2.0 * (w + h)
	if distance < w: return rect.position + Vector2(distance, 0)
	distance -= w
	if distance < h: return rect.position + Vector2(w, distance)
	distance -= h
	if distance < w: return rect.position + Vector2(w - distance, h)
	return rect.position + Vector2(0, h - (distance - w))

func _draw() -> void:
	if size.x <= 0 or size.y <= 0 or _trail.is_empty(): return
	var rect := Rect2(Vector2(-3, -3), size + Vector2(6, 6))
	# Thin local glow with an empty center: the item art keeps its own colors.
	draw_rect(rect, Color(tint, 0.13), false, 4.5)
	draw_rect(rect, Color(tint, 0.62), false, 1.0)
	for i in SEGMENTS + 1:
		var p := float(i) / SEGMENTS
		_trail[i] = _edge_point(phase - TAIL + TAIL * p, rect)
		_colors[i] = Color(tint.lerp(Color.WHITE, p * p * 0.62), p * p * 0.95)
	draw_polyline(_trail, Color(tint, 0.18), 4.0, false)
	draw_polyline_colors(_trail, _colors, 1.8, false)
