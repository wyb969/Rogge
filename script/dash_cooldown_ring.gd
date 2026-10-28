extends Node2D

@export var radius: float = 12.0
@export var line_width: float = 3.0
@export var ready_color: Color = Color(0.4, 1.0, 0.5, 0.95)
@export var cooling_color: Color = Color(0.3, 0.9, 0.4, 0.85)
@export var track_color: Color = Color(0.08, 0.18, 0.1, 0.4)
@export var tip_color: Color = Color(0.85, 1.0, 0.7, 1.0)

var progress: float = 1.0
var bounce_tween: Tween
var base_scale: Vector2 = Vector2.ONE

func _ready() -> void:
	base_scale = scale
	z_index = 12
	if not is_in_group("dash_cooldown_ui"):
		add_to_group("dash_cooldown_ui")
	queue_redraw()

func set_progress(value: float) -> void:
	progress = clampf(value, 0.0, 1.0)
	queue_redraw()

func play_ready_bounce() -> void:
	if bounce_tween != null and bounce_tween.is_valid():
		bounce_tween.kill()

	scale = base_scale
	modulate = Color(1.5, 1.7, 1.2, 1.0)
	set_progress(1.0)

	bounce_tween = create_tween()
	bounce_tween.set_parallel(true)
	bounce_tween.tween_property(self, "scale", base_scale * 1.4, 0.12)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	bounce_tween.tween_property(self, "modulate", Color.WHITE, 0.28)
	bounce_tween.set_parallel(false)
	bounce_tween.tween_property(self, "scale", base_scale, 0.28)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _draw() -> void:
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, track_color, line_width, true)

	if progress >= 0.999:
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, ready_color, line_width + 0.6, true)
		return

	var start_angle := -PI * 0.5
	var end_angle := start_angle + TAU * progress
	draw_arc(Vector2.ZERO, radius, start_angle, end_angle, 64, cooling_color, line_width, true)

	# Moving tip on the growing arc for a clearer “closing” feel.
	if progress > 0.02:
		var tip := Vector2(cos(end_angle), sin(end_angle)) * radius
		draw_circle(tip, line_width * 0.85, tip_color)
