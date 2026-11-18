extends RefCounted

# Each row is a species from the supplied atlas; five consecutive strips hold four poses each.
const SHEETS: Array[Texture2D] = [
	preload("res://assest/stage_monsters/kitchen.png"),
	preload("res://assest/stage_monsters/stationery.png"),
	preload("res://assest/stage_monsters/fastfood.png"),
	preload("res://assest/stage_monsters/appliances.png"),
	preload("res://assest/stage_monsters/furniture.png"),
	preload("res://assest/stage_monsters/zoo.png"),
	preload("res://assest/stage_monsters/dino.png"),
	preload("res://assest/stage_monsters/vegetables.png"),
]
# Native facing of the ten source drawings, in atlas row order (not role order).
# Front views keep their original orientation when changing direction.
const SOURCE_FACING = [
	[0, 0, 0, 0, 0, 0, -1, -1, -1, -1], # kitchen
	[1, 0, -1, -1, 0, -1, -1, 0, -1, 0], # stationery
	[1, 1, 0, -1, 0, 0, 0, 0, -1, -1], # fastfood
	[-1, 0, 1, 0, 1, -1, 0, 0, -1, -1], # appliances
	[0, 0, 0, 0, 0, -1, 0, 1, 0, 0], # furniture
	[1, 1, -1, -1, 0, -1, 1, -1, -1, -1], # zoo
	[-1, -1, -1, -1, -1, -1, -1, -1, -1, -1], # dino
	[-1, 0, 0, 0, -1, 0, 0, -1, 0, -1], # vegetables
]
# Original 1-based species IDs in role order, so heavier silhouettes get tank
# attacks and the quicker silhouettes use the dash tell. Last two are alternates.
const SPECIES = [
	[1, 8, 7, 3, 9, 5, 4, 2, 10, 6],
	[2, 3, 6, 8, 1, 5, 9, 10, 4, 7],
	[1, 9, 7, 8, 4, 3, 6, 2, 5, 10],
	[3, 7, 1, 9, 10, 4, 8, 5, 6, 2],
	[3, 1, 2, 7, 6, 8, 5, 9, 4, 10],
	[5, 2, 7, 1, 4, 3, 6, 9, 8, 10],
	[6, 2, 5, 4, 8, 1, 3, 7, 9, 10],
	[2, 3, 8, 6, 1, 7, 5, 9, 4, 10],
]
const ROLE_SLOT = {
	"chaser": 0, "chaser_brute": 1, "tank": 2, "ranged": 3,
	"dasher": 4, "blade_mantis": 5, "boomerang_imp": 6, "spore_bomber": 7,
}

var _rng := RandomNumberGenerator.new()
var _series: Array[int] = []

func _init() -> void:
	# This draw belongs only to art. Never advance combat or spawn RNG.
	var remaining := range(SHEETS.size())
	while not remaining.is_empty():
		_series.append(remaining.pop_at(_rng.randi_range(0, remaining.size() - 1)))

func apply(actor: Node, stage: int, data: EnemyData) -> void:
	var series := _series[clampi(stage, 1, _series.size()) - 1]
	var slot: int = ROLE_SLOT.get(data.title, 0)
	if slot <= 1 and _rng.randi_range(0, 1) == 1:
		slot += 8
	var row: int = SPECIES[series][slot] - 1
	actor.set_walk_sheet(SHEETS[series], row, SOURCE_FACING[series][row], _rng.randf_range(0.0, TAU))
