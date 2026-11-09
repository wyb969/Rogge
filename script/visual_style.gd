extends RefCounted

const INK: = GamePalette.INK
const PAPER: = GamePalette.PLAYER_DAMAGE_WHITE
const FRIENDLY: = GamePalette.FRIENDLY_CYAN
const DANGER: = GamePalette.DANGER_RED
const HEAL: = GamePalette.PICKUP_GREEN
const TEXT: = GamePalette.PLAYER_DAMAGE_WHITE
const ELITE: = GamePalette.FRIENDLY_PINK
const HIT_FLASH: = Color(1.4, 1.4, 1.4)
const GROUND_VALUES: = Vector2(0.84, 0.24)
const GROUND_MAX_FACTOR: = 1.08
static var _book_material: ShaderMaterial

static func book_material() -> ShaderMaterial:
	if _book_material == null:
		_book_material = ShaderMaterial.new()
		_book_material.shader = preload("res://shaders/book_palette.gdshader")
		_book_material.set_shader_parameter("ink_color", GamePalette.INK)
		_book_material.set_shader_parameter("mid_color", GamePalette.UI_GREY_BORDER)
		_book_material.set_shader_parameter("paper_color", GamePalette.PLAYER_DAMAGE_WHITE)
	return _book_material

static func style_icon(icon: CanvasItem, id: String) -> void :
	icon.material = book_material() if id == "circle_up" else GamePalette.ramp_material(&"ui")
	if id == "poison_trail": icon.material = GamePalette.ramp_material(&"poison")
	if id == "shield_up": icon.material = GamePalette.ramp_material(&"shield")
