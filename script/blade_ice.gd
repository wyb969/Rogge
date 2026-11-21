extends RefCounted
## Only the wave owns these shells. Other slows keep their own clocks.
var left: float
var bonus: float
var wave: Node

func _init(owner_wave: Node, seconds: float, break_damage: float) -> void:
	wave = owner_wave
	left = seconds
	bonus = break_damage

func release(actor: Node2D, shattered := false) -> void:
	actor.blade_ice = null
	if is_instance_valid(wave):
		wave.end_shell(actor, shattered)

func tick(actor: Node2D, delta: float) -> void:
	left -= delta
	if left <= 0.0: release(actor)

func break_damage(actor: Node2D, hit: Dictionary) -> float:
	if float(hit.get("damage", 0.0)) <= 0 or hit.get("from_status", false) or hit.get("damage_is_final", false):
		return 0.0
	release(actor, true)
	return bonus
