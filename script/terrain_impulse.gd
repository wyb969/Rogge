extends RefCounted
# Collision-aware displacement with analytical linear decay (same travel at 30/60 Hz).
const AIR_SECONDS := 0.44
const LAND_SECONDS := 0.12
var visual_age := AIR_SECONDS
var peak := 0.0
var landing_left := 0.0
var left := 0.0
var duration := 0.28
var push := Vector2.ZERO
func start(velocity: Vector2, seconds: float = 0.28, height: float = 32.0) -> void:
	visual_age = 0
	peak = clampf(height,0,48)
	landing_left = 0
	duration = clampf(seconds,0.05,0.4)
	left = duration
	push = velocity.limit_length(440)
func clear() -> void:
	visual_age = AIR_SECONDS
	peak = 0
	landing_left = 0
	left = 0
	push = Vector2.ZERO
func tick(actor: CharacterBody2D, delta: float) -> bool:
	if left<=0: return false
	var step := minf(maxf(delta,0),left)
	var after := maxf(0,left-step)
	actor.velocity = push*left/duration
	actor.move_and_collide(push*((left+after)*0.5/duration)*step)
	left = 0.0 if after<0.000001 else after
	if left<=0: actor.velocity = Vector2.ZERO
	return true

# Cosmetic Z follows display delta independently from ground collision integration.
func advance_visual(delta: float) -> bool:
	var step := maxf(0,delta)
	landing_left = maxf(0,landing_left-step)
	if visual_age>=AIR_SECONDS: return false
	var next := visual_age+step
	visual_age = minf(next,AIR_SECONDS)
	if next>=AIR_SECONDS:
		landing_left = maxf(0,LAND_SECONDS-(next-AIR_SECONDS))
		return true
	return false

func height_ratio() -> float:
	var t := clampf(visual_age/AIR_SECONDS,0,1)
	return 4*t*(1-t)

func height() -> float: return peak*height_ratio()
func landing_strength() -> float:
	return sin(PI*(1-landing_left/LAND_SECONDS)) if landing_left>0 else 0.0
func is_active() -> bool:
	return left>0 or visual_age<AIR_SECONDS or landing_left>0
