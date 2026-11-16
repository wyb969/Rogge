extends RefCounted
# Collision-aware displacement with analytical linear decay (same travel at 30/60 Hz).
var left := 0.0
var duration := 0.28
var push := Vector2.ZERO
func start(velocity: Vector2, seconds: float = 0.28) -> void:
	duration = clampf(seconds,0.05,0.4)
	left = duration
	push = velocity.limit_length(440)
func clear() -> void:
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
