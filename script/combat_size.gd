extends RefCounted

const MONSTER := 3.0
const BOSS := 2.0
const WARNING_Z := 12

# The same swept circle is used for a locked charge lane and its rounded ends.
static func capsule(a: Vector2, b: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var angle := (b - a).angle()
	for i in 13:
		points.append(b + Vector2.from_angle(angle - PI * 0.5 + PI * i / 12) * radius)
	for i in 13:
		points.append(a + Vector2.from_angle(angle + PI * 0.5 + PI * i / 12) * radius)
	return points

# Actors already invalidate their drawings when their attack state changes.
static func add_warning_layer(actor: Node2D, paint: Callable) -> void:
	var overlay := Node2D.new()
	overlay.name = "AttackWarning"
	overlay.z_index = WARNING_Z
	actor.add_child(overlay)
	overlay.draw.connect(paint.bind(overlay))
	actor.draw.connect(overlay.queue_redraw)
