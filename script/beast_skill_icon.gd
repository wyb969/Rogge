extends Button

var remaining: = 0.0
var total: = 1.0
var accent: = Color.WHITE
var _mask: CooldownMask
var _styles: Array[StyleBoxFlat] = []
var _selected: = false

class CooldownMask:
	extends Control
	var fraction: = 0.0
	var accent: = Color.WHITE
	func _draw() -> void :
		if fraction <= 0: return
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, size.y * fraction)), GamePalette.alpha(GamePalette.UI_GREY_COOLDOWN, 0.8))
		draw_rect(Rect2(3, size.y - 4, (size.x - 6) * (1 - fraction), 2), accent)

func configure(texture: Texture2D, color: Color) -> void :
	icon = texture
	material = GamePalette.ramp_material(&"ui")
	accent = GamePalette.UI_GREY_ACTIVE
	expand_icon = true
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text = ""
	add_theme_color_override("icon_disabled_color", Color.WHITE)
	for selected_style in [false, true]:
		var style: = StyleBoxFlat.new()
		style.bg_color = GamePalette.alpha(GamePalette.UI_GREY_COOLDOWN, 0.9)
		style.border_color = GamePalette.UI_GREY_ACTIVE if selected_style else GamePalette.UI_GREY_BORDER
		style.set_border_width_all(2)
		style.set_corner_radius_all(7)
		style.content_margin_left = 5
		style.content_margin_right = 5
		_styles.append(style)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, _styles[0])
	_mask = CooldownMask.new()
	_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mask.accent = accent
	add_child(_mask)
	_mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mask.resized.connect(_mask.queue_redraw)

func set_state(cooldown: float, duration: float, keyboard_selected: bool) -> void :
	remaining = maxf(0, cooldown)
	total = maxf(duration, 0.001)
	disabled = remaining > 0
	var fraction: = clampf(remaining / total, 0, 1)
	if absf(_mask.fraction - fraction) > 0.001 or (_mask.fraction > 0 and fraction == 0):
		_mask.fraction = fraction
		_mask.queue_redraw()
	if _selected == keyboard_selected: return
	_selected = keyboard_selected
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, _styles[1 if _selected else 0])
