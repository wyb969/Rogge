extends RefCounted

const INK: = GamePalette.INK
const PAPER: = GamePalette.PLAYER_DAMAGE_WHITE
const FRIENDLY: = GamePalette.FRIENDLY_CYAN
const DANGER: = GamePalette.DANGER_RED
const HEAL: = GamePalette.HEAL_GREEN
const TEXT: = GamePalette.PLAYER_DAMAGE_WHITE
const ELITE: = GamePalette.ENEMY_TELEGRAPH_EDGE
const HIT_FLASH: = GamePalette.HIT_FLASH
const GROUND_VALUES: = GamePalette.GROUND_VALUES
const GROUND_MAX_FACTOR: = 1.08
static var _book_material: ShaderMaterial

static func book_material() -> ShaderMaterial:
	if _book_material == null:
		_book_material = ShaderMaterial.new()
		_book_material.shader = preload("res://shaders/book_palette.gdshader")
		_book_material.set_shader_parameter("ink_color", GamePalette.INK)
		_book_material.set_shader_parameter("mid_color", GamePalette.PARCHMENT.darkened(0.28))
		_book_material.set_shader_parameter("paper_color", GamePalette.PARCHMENT)
	return _book_material

static func style_icon(icon: CanvasItem, id: String) -> void:
	var kind: StringName = &"steel"
	if id in ["regen_up", "lifesteal_up", "monster_necklace"]: kind = &"warm"
	if id in ["poison_trail", "molotov_up"]: kind = &"poison"
	if id == "shield_up": kind = &"shield"
	if id == "lightning_ring": kind = &"lightning"
	if id in ["black_hole", "freeze_up", "wind_emblem"]: kind = &"cooldown"
	icon.material = book_material() if id == "circle_up" else GamePalette.ramp_material(kind)
