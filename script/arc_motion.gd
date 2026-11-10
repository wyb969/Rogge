extends RefCounted

# Render between completed physics states; never predict a future hit or fuse.
static func render_age(previous: float, current: float, fraction: float = -1.0) -> float:
	if fraction < 0: fraction = Engine.get_physics_interpolation_fraction()
	return lerpf(previous, current, clampf(fraction, 0.0, 1.0))

static func position_at(origin: Vector2, target: Vector2, age: float, duration: float, height: float) -> Vector2:
	var t := clampf(age / maxf(duration, 0.001), 0.0, 1.0)
	return origin.lerp(target, t) + Vector2.UP * (4.0 * height * t * (1.0 - t))
