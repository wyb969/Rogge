extends Node2D


var forged_bonus := -1.0
var level: int = 0

func upgrade() -> void :
	level += 1

func reset() -> void :
	forged_bonus = -1.0
	level = 0

func get_on_hit_chance(rank: int = -1) -> float:
	if rank < 0: rank = level
	return minf(0.16 + float(rank) * 0.07, 0.6)

func get_freeze_duration(rank: int = -1) -> float:
	if rank < 0: rank = level
	return 1.0 + float(rank) * 0.25

func get_slow_factor(rank: int = -1) -> float:
	if rank < 0: rank = level

	return maxf(0.28, 0.6 - float(rank) * 0.05)

func get_frozen_bonus(rank: int = -1) -> float:
	if rank < 0 and forged_bonus >= 0.0: return forged_bonus
	if rank < 0: rank = level

	return minf(0.2 + float(rank) * 0.1, 0.9)
