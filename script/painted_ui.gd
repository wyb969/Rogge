extends RefCounted

const MOSS := preload("res://rogge_art/environment-ui/moss/panel.tres")
const MOSS_ACCENT := preload("res://rogge_art/environment-ui/moss/panel-accent.tres")
const TIDE := preload("res://rogge_art/environment-ui/tide/panel.tres")
const TIDE_ACCENT := preload("res://rogge_art/environment-ui/tide/panel-accent.tres")
const MOSS_GROUND := preload("res://rogge_art/environment-ui/moss/ground-900x600.png")
const TIDE_GROUND := preload("res://rogge_art/environment-ui/tide/ground-900x600.png")

static func style_button(button: Button, tide := false) -> void:
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.add_theme_stylebox_override("normal", TIDE if tide else MOSS)
	for state in ["hover", "pressed", "hover_pressed"]:
		button.add_theme_stylebox_override(state, TIDE_ACCENT if tide else MOSS_ACCENT)
