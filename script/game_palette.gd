class_name GamePalette
extends RefCounted

# v4 semantic roles. Alpha/animation/geometry may vary at the call site.
const PLAYER_PRIMARY := Color("22d3ee")
const PLAYER_ATTACK := Color("67e8f9")
const SHIELD_GOLD := Color("facc15")
const ENEMY_CRIMSON := Color("e11d48")
const ENEMY_ORANGE := Color("f97316")
const ENEMY_RUST := Color("ea580c")
const ENEMY_PROJECTILE := Color("ff3b3b")
const ENEMY_TELEGRAPH_FILL := Color("ef4444")
const ENEMY_TELEGRAPH_EDGE := Color("ff5a3c")
const ENEMY_TELEGRAPH_INNER := Color("b83232")
const POISON := Color("a855f7")
const POISON_DARK := Color("6b21a8")
const POISON_RIM := Color("c084fc")
const COIN_GOLD := SHIELD_GOLD
const COIN_HIGHLIGHT := Color("fde68a")
const COIN_EDGE := Color("b45309")
const PICKUP_GREEN := Color("4ade80")
const HEAL_GREEN := Color("22c55e")
const PARCHMENT := Color("e8d3a3")
const SHADOW := Color(0, 0, 0, 0.35)
const BLACK := Color.BLACK
const WHITE := Color.WHITE
const INK := Color("111018")
const UI_PANEL := Color("0f172a")
const UI_BUTTON := Color("111827")
const UI_BORDER := Color("cbd5e1")
const UI_TEXT := Color("f8fafc")
const UI_GREY_BASE := Color("374151")
const UI_GREY_BORDER := Color("9ca3af")
const UI_GREY_ACTIVE := Color("e5e7eb")
const UI_GREY_COOLDOWN := Color("1f2937")
const SKILL_HEAL := Color("fb7185")
const SKILL_LIGHTNING := Color("fde047")
const SKILL_COOLDOWN := Color("38bdf8")
const WARM_WHITE := Color("fff4df")
const STEEL_SILVER := Color("d7dee7")
const SKILL_ACCENTS := [SKILL_HEAL, SKILL_LIGHTNING, SKILL_COOLDOWN, SHIELD_GOLD]
const GROUND_MOSS_DARK := Color("1f3a3a")
const GROUND_MOSS_LIGHT := Color("24433f")
const GROUND_GRASS := Color("2f5550")
const GROUND_PALETTES: Array[Color] = [
	GROUND_MOSS_DARK, Color("213d3c"), Color("22403e"), GROUND_MOSS_LIGHT,
	Color("39302b"), Color("3d322d"), Color("382b2a"), Color("40342c"),
	Color("312b40"), Color("392e43"), Color("302a3c"), Color("3b3045"),
]
const GROUND_VALUES := Vector2(0.92, 0.14)
const GROUND_NOISE := 0.035
const GROUND_PATCH := 0.12
const GROUND_VIGNETTE := 0.19
const GROUND_DECOR_ALPHA := 0.85
const WEATHER_NIGHT := Color("b2c4db")
const WEATHER_DAY := Color("ebf0f5")
const WEATHER_HORIZON := Color("f0dbc2")
const WEATHER_RAIN := Color("a3c9f2")
const WEATHER_SNOW := Color("d9f0ff")
const WEATHER_STAR := Color("ebfaff")
const HIT_FLASH := Color(1.4, 1.4, 1.4)
const BRIGHT_FLASH := Color(3, 3, 3)
const HOVER_MULTIPLIER := Color(1.16, 1.16, 1.16)
const STATUS_FREEZE := Color("b4ddff")

# Compatibility names keep existing combat/UI callers on the same semantic roles.
const POISON_PURPLE := POISON
const POISON_PURPLE_DARK := POISON_DARK
const POISON_TINT := POISON_RIM
const DANGER_RED := ENEMY_TELEGRAPH_FILL
const DANGER_ORANGE := ENEMY_ORANGE
const DANGER_PROJECTILE := ENEMY_PROJECTILE
const SHIELD_YELLOW := SHIELD_GOLD
const PLAYER_DAMAGE_WHITE := UI_TEXT
const FRIENDLY_CYAN := PLAYER_ATTACK
const FRIENDLY_LIGHT := UI_TEXT
const FRIENDLY_BLUE := PLAYER_PRIMARY
const FRIENDLY_PINK := PLAYER_ATTACK
const HEALTH_WHITE := UI_TEXT
const ENEMY_BODY := ENEMY_CRIMSON
const CARD_GAIN := UI_TEXT
const CARD_COST := ENEMY_ORANGE
# Fixed pigments remain species-specific; dead enemy ink stays in warm hues.
const INK_PIGMENTS := {
	&"chaser": Color("ff657e"), &"chaser_brute": Color("f97c72"),
	&"dasher": Color("ff894d"), &"tank": Color("ef7755"),
	&"ranged": Color("fa698c"), &"blade_mantis": Color("f58a77"),
	&"boomerang_imp": Color("f77891"), &"spore_bomber": Color("ee6e88"),
	&"loot_courier": Color("ff9b76"), &"treasure_guardian": Color("f58a59"),
	&"charger_boss": Color("ff7287"), &"knight": Color("f0836a"),
	&"tide": Color("f57b86"), &"thunder": Color("ff9873"),
	&"gale": Color("f76686"), &"gale_ranged": Color("f38898"),
	&"gale_melee": Color("fa7b72"), &"aegis": Color("f8875c"),
	&"power_trial": Color("f58b6d"), &"speed_trial": Color("ff7d8f"),
}
static var _materials := {}
static var _weapon_gradient: Gradient
static var _silhouette: ShaderMaterial

static func enemy_color_for(kind: StringName) -> Color:
	if kind in [&"dasher", &"speed_trial", &"blade_mantis"]: return ENEMY_ORANGE
	if kind in [&"tank", &"chaser_brute", &"treasure_guardian", &"loot_courier", &"aegis", &"power_trial"]: return ENEMY_RUST
	return ENEMY_CRIMSON

static func icon_border_for(id: String) -> Color:
	if id in ["regen_up", "lifesteal_up", "monster_necklace"]: return SKILL_HEAL
	if id in ["molotov_up", "poison_trail"]: return POISON_RIM
	if id == "lightning_ring": return SKILL_LIGHTNING
	if id == "shield_up": return SHIELD_GOLD
	if id == "circle_up": return UI_BORDER
	if id in ["black_hole", "freeze_up", "wind_emblem"]: return SKILL_COOLDOWN
	return PLAYER_PRIMARY

static func weapon_gradient() -> Gradient:
	if _weapon_gradient == null:
		_weapon_gradient = Gradient.new()
		_weapon_gradient.colors = PackedColorArray([PLAYER_PRIMARY, PLAYER_ATTACK, UI_TEXT])
	return _weapon_gradient

static func silhouette_material() -> ShaderMaterial:
	if _silhouette == null:
		_silhouette = ShaderMaterial.new()
		_silhouette.shader = preload("res://shaders/status_echo_flash.gdshader")
		_silhouette.set_shader_parameter("ink_color", INK)
	return _silhouette

static func alpha(color: Color, opacity: float) -> Color:
	return Color(color, opacity)

static func surface(fill: Color = UI_BUTTON, border: Color = UI_BORDER, opacity: float = 0.8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = alpha(fill, opacity)
	style.border_color = alpha(border, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style

static func apply_button(button: Button) -> void:
	button.add_theme_stylebox_override("normal", surface())
	button.add_theme_stylebox_override("hover", surface(UI_BUTTON.lightened(0.12), UI_GREY_ACTIVE))
	button.add_theme_stylebox_override("pressed", surface(UI_BUTTON.lightened(0.24), UI_GREY_ACTIVE))
	button.add_theme_stylebox_override("disabled", surface(UI_GREY_COOLDOWN, UI_GREY_BASE))
	button.add_theme_stylebox_override("focus", surface(UI_BUTTON, UI_GREY_ACTIVE, 0))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, UI_TEXT)
	button.add_theme_color_override("font_disabled_color", UI_GREY_BORDER)

static func ramp_material(kind: StringName) -> ShaderMaterial:
	if not _materials.has(kind):
		var shader := ShaderMaterial.new()
		shader.shader = preload("res://shaders/semantic_ramp.gdshader")
		var main := PLAYER_ATTACK
		var dark := INK
		var light := UI_TEXT
		match kind:
			&"pickup": main = PICKUP_GREEN; dark = PICKUP_GREEN.darkened(0.5)
			&"coin": main = COIN_GOLD; dark = COIN_EDGE; light = COIN_HIGHLIGHT
			&"poison": main = POISON; dark = POISON_DARK; light = POISON_RIM
			&"shield": main = SHIELD_GOLD; dark = SHIELD_GOLD.darkened(0.5)
			&"ui", &"steel": main = STEEL_SILVER
			&"warm": main = WARM_WHITE; light = WARM_WHITE
			&"lightning": main = SKILL_LIGHTNING; dark = SKILL_LIGHTNING.darkened(0.5)
			&"cooldown": main = SKILL_COOLDOWN
			&"player": main = PLAYER_PRIMARY; dark = PLAYER_PRIMARY.darkened(0.62)
			&"grass": main = GROUND_GRASS; dark = GROUND_MOSS_DARK; light = GROUND_GRASS.lightened(0.08)
			_:
				if String(kind).begins_with("enemy:"):
					main = enemy_color_for(StringName(String(kind).trim_prefix("enemy:")))
					dark = main.darkened(0.58)
					light = main.lerp(UI_TEXT, 0.4)
		shader.set_shader_parameter("dark_color", dark)
		shader.set_shader_parameter("main_color", main)
		shader.set_shader_parameter("light_color", light)
		if kind == &"grass":
			# Dark source grass needs its middle values lifted into the muted teal role.
			shader.set_shader_parameter("dark_threshold", 0.12)
			shader.set_shader_parameter("light_threshold", 0.6)
		_materials[kind] = shader
	return _materials[kind]

static func configure_enemy_material(shader: ShaderMaterial, color: Color) -> void:
	shader.set_shader_parameter("semantic_body", true)
	shader.set_shader_parameter("body_dark", color.darkened(0.58))
	shader.set_shader_parameter("body_main", color)
	shader.set_shader_parameter("body_light", color.lerp(UI_TEXT, 0.4))

static func configure_xp_shader(shader: ShaderMaterial) -> void:
	shader.set_shader_parameter("edge_base", PLAYER_PRIMARY.darkened(0.25))
	shader.set_shader_parameter("edge_hot", PLAYER_ATTACK)
	shader.set_shader_parameter("flare_base", PLAYER_PRIMARY)
	shader.set_shader_parameter("flare_tip", UI_TEXT)
	shader.set_shader_parameter("spark_color", UI_TEXT)
