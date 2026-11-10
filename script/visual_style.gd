extends RefCounted

const INK: = Color(0.09, 0.13, 0.17)
const PAPER: = Color(0.91, 0.88, 0.76)
const FRIENDLY: = Color(0.48, 0.78, 0.84)
const DANGER: = Color(1.0, 0.28, 0.24)
const HEAL: = Color(0.2, 0.95, 0.48)
const TEXT: = Color(0.84, 0.88, 0.83)
const ELITE: = Color(0.87, 0.73, 0.46)
const HIT_FLASH: = Color(1.45, 1.45, 1.35)
const GROUND_VALUES: = Vector2(0.84, 0.24)
const GROUND_MAX_FACTOR: = 1.08
static var _book_material: ShaderMaterial

static func book_material() -> ShaderMaterial:
	if _book_material == null:
		_book_material = ShaderMaterial.new()
		_book_material.shader = preload("res://shaders/book_palette.gdshader")
	return _book_material

static func style_icon(icon: CanvasItem, id: String) -> void :
	icon.material = book_material() if id == "circle_up" else null
