class_name GamePalette
extends RefCounted

# Semantic colors. Geometry, alpha and animation may vary; hue comes from here.
const PICKUP_GREEN := Color("4ade80")
const HEAL_GREEN := Color("6ee7a0")
const POISON_PURPLE := Color("a855f7")
const POISON_PURPLE_DARK := Color("6b21a8")
const POISON_TINT := Color("c084fc")
const DANGER_RED := Color("ef4444")
const DANGER_ORANGE := Color("f97316")
# Brighter red projectile/edge on the unchanged darkest and brightest floors.
const DANGER_PROJECTILE := Color("f9b4b4")
const SHIELD_YELLOW := Color("facc15")
const PLAYER_DAMAGE_WHITE := Color("f8fafc")
const UI_GREY_BASE := Color("374151")
const UI_GREY_BORDER := Color("9ca3af")
const UI_GREY_ACTIVE := Color("e5e7eb")
const UI_GREY_COOLDOWN := Color("1f2937")
const INK := Color("17212e")
const FRIENDLY_CYAN := Color("69c9ff")
const FRIENDLY_LIGHT := Color("d8edff")
const FRIENDLY_BLUE := Color("7097f5")
const FRIENDLY_PINK := Color("e0a5e9")
const HEALTH_WHITE := Color("dce6ef")
const ENEMY_BODY := Color("91afd5")
const RECOLORED_ENEMIES := [&"chaser_brute",&"ranged",&"blade_mantis",&"loot_courier"]
const CARD_GAIN := PLAYER_DAMAGE_WHITE
const CARD_COST := DANGER_ORANGE
const INK_PIGMENTS := {
	&"chaser": Color("e492e8"), &"chaser_brute": Color("b8a1ed"),
	&"dasher": Color("92b7ff"), &"tank": Color("72a2f5"),
	&"ranged": Color("70c9ee"), &"blade_mantis": Color("94c6fa"),
	&"boomerang_imp": Color("cf9bea"), &"spore_bomber": Color("779dff"),
	&"loot_courier": Color("be98f5"), &"treasure_guardian": Color("98c6f5"),
	&"charger_boss": Color("ef98f5"), &"knight": Color("a0a4ff"),
	&"tide": Color("72bdff"), &"thunder": Color("ca98f5"),
	&"gale": Color("7fc4ed"), &"gale_ranged": Color("8dbbeb"),
	&"gale_melee": Color("98c1f5"), &"aegis": Color("98b6f5"),
	&"power_trial": Color("98caf5"), &"speed_trial": Color("c8a3eb"),
}
static var _materials := {}
static var _weapon_gradient: Gradient
static var _silhouette: ShaderMaterial

static func weapon_gradient() -> Gradient:
	if _weapon_gradient == null:
		_weapon_gradient = Gradient.new()
		_weapon_gradient.colors = PackedColorArray([FRIENDLY_BLUE,FRIENDLY_CYAN,FRIENDLY_LIGHT])
	return _weapon_gradient

static func silhouette_material() -> ShaderMaterial:
	if _silhouette == null:
		_silhouette = ShaderMaterial.new()
		_silhouette.shader = preload("res://shaders/status_echo_flash.gdshader")
		_silhouette.set_shader_parameter("ink_color", INK)
	return _silhouette

static func alpha(color: Color, opacity: float) -> Color:
	return Color(color, opacity)

static func surface(fill: Color = UI_GREY_BASE, border: Color = UI_GREY_BORDER, opacity: float = 0.95) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = alpha(fill, opacity)
	style.border_color = alpha(border, 0.65)
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style

static func apply_button(button: Button) -> void:
	button.add_theme_stylebox_override("normal", surface())
	button.add_theme_stylebox_override("hover", surface(UI_GREY_BASE.lightened(0.12), UI_GREY_ACTIVE))
	button.add_theme_stylebox_override("pressed", surface(UI_GREY_BASE.lightened(0.24), UI_GREY_ACTIVE))
	button.add_theme_stylebox_override("disabled", surface(UI_GREY_COOLDOWN, UI_GREY_BASE))
	button.add_theme_stylebox_override("focus", surface(UI_GREY_BASE, UI_GREY_ACTIVE, 0))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, UI_GREY_ACTIVE)
	button.add_theme_color_override("font_disabled_color", UI_GREY_BORDER)

static func ramp_material(kind: StringName) -> ShaderMaterial:
	if not _materials.has(kind):
		var shader := ShaderMaterial.new()
		shader.shader = preload("res://shaders/semantic_ramp.gdshader")
		var main := PICKUP_GREEN if kind == &"pickup" else (POISON_PURPLE if kind == &"poison" else (SHIELD_YELLOW if kind == &"shield" else (UI_GREY_ACTIVE if kind == &"ui" else (ENEMY_BODY if kind == &"enemy" else FRIENDLY_CYAN))))
		shader.set_shader_parameter("dark_color", POISON_PURPLE_DARK if kind == &"poison" else main.darkened(0.48))
		shader.set_shader_parameter("main_color", main)
		shader.set_shader_parameter("light_color", POISON_TINT if kind == &"poison" else main.lerp(PLAYER_DAMAGE_WHITE, 0.45))
		_materials[kind] = shader
	return _materials[kind]

static func configure_enemy_material(shader: ShaderMaterial, recolor: bool) -> void:
	shader.set_shader_parameter("semantic_body",recolor)
	if recolor:
		shader.set_shader_parameter("body_dark",ENEMY_BODY.darkened(0.48))
		shader.set_shader_parameter("body_main",ENEMY_BODY)
		shader.set_shader_parameter("body_light",ENEMY_BODY.lerp(PLAYER_DAMAGE_WHITE,0.45))

static func configure_xp_shader(shader: ShaderMaterial) -> void:
	shader.set_shader_parameter("edge_base", FRIENDLY_CYAN)
	shader.set_shader_parameter("edge_hot", FRIENDLY_BLUE)
	shader.set_shader_parameter("flare_base", FRIENDLY_CYAN)
	shader.set_shader_parameter("flare_tip", PLAYER_DAMAGE_WHITE)
	shader.set_shader_parameter("spark_color", PLAYER_DAMAGE_WHITE)
