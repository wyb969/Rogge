extends Node2D

## Passive freeze procs on hits. No projectile — pure on-hit frost.
var level: int = 0

func upgrade() -> void:
	level += 1

func reset() -> void:
	level = 0

func get_on_hit_chance() -> float:
	return minf(0.16 + float(level) * 0.07, 0.6)

func get_freeze_duration() -> float:
	return 1.0 + float(level) * 0.25

func get_slow_factor() -> float:
	# Lower = slower. Lv1 ~55% speed, higher level deeper chill.
	return maxf(0.28, 0.6 - float(level) * 0.05)

func get_frozen_bonus() -> float:
	# Extra damage vs already-frozen targets.
	return minf(0.2 + float(level) * 0.1, 0.9)
