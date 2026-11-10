extends Control


const SEGMENTS: = 64
const COOLING: = Color(GamePalette.UI_GREY_DARK, 0.94)
const GREEN: = Color(GamePalette.UI_GREY, 0.94)
var progress: = 1.0
var available: = true
var _circle: = PackedVector2Array()
var _fill: = PackedVector2Array()
var _radius: = 0.0
var _pressed: = false
var _bounce: Tween
var visual_scale: = 1.0:
	set(value):
		visual_scale = value
		_refresh_scale()
var ready_glow: = 0.0:
	set(value):
		ready_glow = value
		queue_redraw()

func _ready() -> void :
	resized.connect(_rebuild_circle)
	visibility_changed.connect( func():
		if not is_visible_in_tree(): reset_feedback())
	_rebuild_circle()

func set_cooldown(value: float, can_use: bool, notify: bool = true) -> void :
	var next: = 1.0 if can_use else clampf(value, 0, 0.999)
	var became_ready: = can_use and not available
	var changed: = not is_equal_approx(next, progress) or can_use != available
	progress = next
	available = can_use
	if not available and _bounce != null: reset_feedback()
	if changed:
		_rebuild_fill()
		queue_redraw()
	if became_ready and notify and is_visible_in_tree(): play_ready_bounce()

func play_ready_bounce() -> void :
	reset_feedback()
	ready_glow = 1
	_bounce = create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_bounce.tween_property(self, "visual_scale", 1.16, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_bounce.tween_property(self, "visual_scale", 1.0, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bounce.parallel().tween_property(self, "ready_glow", 0.0, 0.24)
	_bounce.tween_callback( func(): _bounce = null)

func reset_feedback() -> void :
	if _bounce != null and _bounce.is_valid(): _bounce.kill()
	_bounce = null
	_pressed = false
	visual_scale = 1
	ready_glow = 0

func set_pressed_visual(pressed: bool) -> void :
	_pressed = pressed
	_refresh_scale()

func _refresh_scale() -> void :
	var label: = get_node_or_null("Label") as Label
	if label != null:
		label.pivot_offset = size * 0.5
		label.scale = Vector2.ONE * visual_scale * (0.94 if _pressed else 1.0)
	queue_redraw()

func _rebuild_circle() -> void :
	_radius = maxf(1, minf(size.x, size.y) * 0.5 - 4)
	_circle.clear()
	for i in SEGMENTS:
		_circle.append(Vector2.from_angle(float(i) / SEGMENTS * TAU) * _radius)
	_rebuild_fill()
	_refresh_scale()

func _rebuild_fill() -> void :
	_fill.clear()
	if _circle.is_empty() or progress <= 0: return
	var level: = _radius * (1.0 - 2.0 * progress)
	var previous: = _circle[-1]
	for point in _circle:
		if (previous.y >= level) != (point.y >= level):
			var weight: = (level - previous.y) / (point.y - previous.y)
			_fill.append(previous.lerp(point, weight))
		if point.y >= level: _fill.append(point)
		previous = point

func _draw() -> void :
	draw_set_transform(size * 0.5, 0, Vector2.ONE * visual_scale * (0.94 if _pressed else 1.0))
	draw_circle(Vector2.ZERO, _radius, GREEN if available else COOLING)
	if not available and _fill.size() >= 3:
		draw_colored_polygon(_fill, GREEN)
		var level: = _radius * (1.0 - 2.0 * progress)
		var half_width: = sqrt(maxf(0, _radius * _radius - level * level))
		draw_line(Vector2( - half_width, level), Vector2(half_width, level), Color(GamePalette.UI_GREY_ACTIVE, 0.9), 1.5, true)
	draw_arc(Vector2.ZERO, _radius, 0, TAU, SEGMENTS, GamePalette.UI_GREY_ACTIVE if available else GamePalette.UI_GREY_BORDER, 2.5, true)
	if ready_glow > 0:
		draw_arc(Vector2.ZERO, _radius + 3, 0, TAU, SEGMENTS, Color(GamePalette.UI_GREY_ACTIVE, ready_glow * 0.8), 2, true)
