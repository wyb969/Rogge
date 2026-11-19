extends RefCounted

const MAX_LEVEL := 5
const CHANCE_PER_LEVEL := 0.2
const BASE_MULTIPLIER := 1.5
const MASTER_MULTIPLIER := 2.0

static func chance_for(rank: int) -> float:
	return float(clampi(rank, 0, MAX_LEVEL)) * CHANCE_PER_LEVEL

static func damage_multiplier_for(rank: int) -> float:
	return MASTER_MULTIPLIER if rank >= MAX_LEVEL else BASE_MULTIPLIER

static func roll_multiplier(rank: int, hit: Dictionary, rng: RandomNumberGenerator) -> float:
	return roll_chance(chance_for(rank), damage_multiplier_for(rank), hit, rng)

static func roll_chance(chance: float, multiplier: float, hit: Dictionary, rng: RandomNumberGenerator) -> float:
	if chance <= 0.0 or float(hit.get("damage", 0.0)) <= 0.0:
		return 1.0
	if hit.get("from_status", false) or not hit.get("can_crit", true):
		return 1.0
	if chance < 1.0 and rng.randf() >= chance:
		return 1.0
	return multiplier
