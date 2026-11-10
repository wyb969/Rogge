class_name GamePalette
extends RefCounted

# v4 semantic colors. Geometry, damage and cooldowns stay in their owners.
# Green is reserved for XP and healing pickups. Coins keep their original gold art.

const PLAYER_CYAN := Color("5ec8ea")
const HIT_FLASH_WHITE := Color("fffdf6")
const HURT_FLASH_RED := Color("ffabb4")
const MARKER_GOLD := Color("e6c15a")
const ENEMY_RED := Color("e23b3b")
const ENEMY_ORANGE := Color("f97316")
const ENEMY_AMBER := Color("f0a030")
const TELEGRAPH_FILL := Color("d1232c")
const TELEGRAPH_EDGE := Color("ff6a32")
const POISON := Color("a855f7")
const POISON_DARK := Color("6b21a8")
const POISON_LIGHT := Color("d8b4fe")
# Sprite multiply: red and blue both stay above green so poison reads purple, not burn or freeze.
const POISON_BODY := Color(1.28, 0.36, 1.42)
const HEAL := Color("3ddc6a")
const HEAL_TEXT := Color(0.4, 1, 0.55)
const XP_GREEN := Color("4ade80")
const XP_BAR := Color("2f6fbf")
const XP_TRACK := Color("16345c")
const COIN_GOLD := Color("f5c542")
const SHADOW := Color(0.0, 0.0, 0.0, 1.0)
const INK := Color("14141c")
const UI_GREY := Color("6b7280")
const UI_GREY_DARK := Color("374151")
const UI_GREY_BORDER := Color("9ca3af")
const UI_GREY_ACTIVE := Color("e5e7eb")
const UI_SLOT := Color(0.08, 0.09, 0.1, 0.9)
const SKILL_TIDE := Color("e15a68")
const SKILL_THUNDER := Color("f0c14b")
const SKILL_GALE := Color("3d7edb")
const SKILL_AEGIS := Color("e0a23a")
const BOOK_TAN := Color("c4a574")
const ICE := Color("7ec8e3")
const VOID := Color("8b7fd6")

const STAGE_NAMES: Array[String] = [
	"Teal moss", "Plum", "Warm slate", "Dusk blue",
	"Dry olive", "Ash", "Wine", "Pine",
	"Rust", "Steel", "Mulberry", "Night olive",
]
const STAGE_TINTS: Array[Color] = [
	Color(0.11, 0.20, 0.16), Color(0.16, 0.09, 0.14),
	Color(0.18, 0.12, 0.08), Color(0.08, 0.11, 0.18),
	Color(0.14, 0.15, 0.07), Color(0.12, 0.12, 0.14),
	Color(0.15, 0.08, 0.10), Color(0.07, 0.14, 0.12),
	Color(0.17, 0.09, 0.07), Color(0.10, 0.13, 0.16),
	Color(0.14, 0.07, 0.11), Color(0.09, 0.11, 0.08),
]
const STAGE_ONE := 0

static var _bodies: Dictionary = {}

static func stage_index(stage_num: int) -> int:
	var stage_i := maxi(stage_num, 1)
	if stage_i == 1:
		return STAGE_ONE
	return ((stage_i - 2) % (STAGE_TINTS.size() - 1)) + 1

static func stage_tint(stage_num: int) -> Color:
	return STAGE_TINTS[stage_index(stage_num)]

static func stage_vignette(palette_index: int) -> float:
	return 0.68 if palette_index == STAGE_ONE else 0.18

static func shadow(alpha: float) -> Color:
	return Color(SHADOW, alpha)

static func body_material(kind: StringName) -> ShaderMaterial:
	if not _bodies.has(kind):
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://shaders/body_tint.gdshader")
		var target := PLAYER_CYAN if kind == &"player" else ENEMY_RED
		mat.set_shader_parameter("target", Vector3(target.r, target.g, target.b))
		mat.set_shader_parameter("amount", 0.86 if kind == &"player" else 0.94)
		mat.set_shader_parameter("lift", 0.38 if kind == &"player" else 0.64)
		_bodies[kind] = mat
	return _bodies[kind]

static func paint_actor(sprite: CanvasItem, kind: StringName) -> void:
	if sprite == null:
		return
	sprite.material = body_material(kind)

static func neutral_surface(fill: Color = UI_GREY_DARK, border: Color = UI_GREY_BORDER) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(fill.r, fill.g, fill.b, 0.92)
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

static func apply_neutral_button(button: Button) -> void:
	if button == null:
		return
	button.add_theme_stylebox_override("normal", neutral_surface())
	button.add_theme_stylebox_override("hover", neutral_surface(UI_GREY_DARK.lightened(0.08), UI_GREY_ACTIVE))
	button.add_theme_stylebox_override("pressed", neutral_surface(UI_GREY.darkened(0.15), UI_GREY_ACTIVE))
	button.add_theme_stylebox_override("disabled", neutral_surface(UI_GREY_DARK.darkened(0.2), UI_GREY))
	button.add_theme_stylebox_override("focus", neutral_surface())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, UI_GREY_ACTIVE)
	button.add_theme_color_override("font_disabled_color", UI_GREY_BORDER)

static func icon_accent(id: String) -> Color:
	match id:
		"poison_trail":
			return POISON
		"axe_up", "left_fist", "right_fist", "bomb", "molotov_up", "echo_ember":
			return ENEMY_ORANGE
		"circle_up":
			return BOOK_TAN
		"gun_up":
			return UI_GREY_BORDER
		"drone_up", "speed_up", "wind_emblem", "banana_fan", "pickup_up":
			return PLAYER_CYAN
		"lightning_ring":
			return SKILL_THUNDER
		"shield_up", "critical_glasses":
			return SKILL_AEGIS
		"black_hole":
			return VOID
		"freeze_up":
			return ICE
		"monster_necklace", "regen_up", "lifesteal_up":
			return SKILL_TIDE
		_:
			return UI_GREY_BORDER

# Current development UI/feedback APIs use these names. Every alias resolves to
# the Cursor palette above; there is no second palette or texture-remapping layer.
const BLACK := Color.BLACK
const WHITE := Color.WHITE
const PLAYER_ATTACK := PLAYER_CYAN
const PLAYER_DAMAGE_WHITE := Color(1, 0.96, 0.83) # Cursor damage popup paper tint.
const ENEMY_CRIMSON := ENEMY_RED
const ENEMY_PROJECTILE := ENEMY_RED
const DANGER_RED := TELEGRAPH_FILL
const ENEMY_TELEGRAPH_EDGE := TELEGRAPH_EDGE
const FRIENDLY_CYAN := PLAYER_CYAN
const FRIENDLY_BLUE := PLAYER_CYAN
const FRIENDLY_LIGHT := UI_GREY_ACTIVE
const HEAL_GREEN := HEAL_TEXT
const PICKUP_GREEN := XP_GREEN
const POISON_PURPLE := POISON
const POISON_TINT := POISON_LIGHT
const UI_TEXT := UI_GREY_ACTIVE
const UI_BORDER := UI_GREY_BORDER
const UI_BUTTON := UI_GREY_DARK
const UI_GREY_BASE := UI_GREY_DARK
const UI_GREY_COOLDOWN := UI_GREY_DARK
const UI_PANEL := UI_SLOT
const CARD_GAIN := UI_GREY_ACTIVE
const CARD_COST := ENEMY_ORANGE

static func alpha(color: Color, opacity: float) -> Color:
	return Color(color, opacity)

static func surface(fill: Color = UI_BUTTON, border: Color = UI_BORDER, opacity: float = 0.92) -> StyleBoxFlat:
	var style := neutral_surface(fill, border)
	style.bg_color = alpha(fill, opacity)
	return style
