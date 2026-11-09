extends Theme

const PALETTE := preload("res://script/game_palette.gd")

func _init() -> void:
	set_stylebox("normal", "Button", PALETTE.surface())
	set_stylebox("hover", "Button", PALETTE.surface(PALETTE.UI_GREY_BASE.lightened(0.12), PALETTE.UI_GREY_ACTIVE))
	set_stylebox("pressed", "Button", PALETTE.surface(PALETTE.UI_GREY_BASE.lightened(0.24), PALETTE.UI_GREY_ACTIVE))
	set_stylebox("disabled", "Button", PALETTE.surface(PALETTE.UI_GREY_COOLDOWN, PALETTE.UI_GREY_BASE))
	set_stylebox("focus", "Button", PALETTE.surface(PALETTE.UI_GREY_BASE, PALETTE.UI_GREY_ACTIVE, 0))
	set_stylebox("panel", "Panel", PALETTE.surface(PALETTE.UI_GREY_COOLDOWN, PALETTE.UI_GREY_BORDER, 0.98))
	set_stylebox("panel", "PanelContainer", PALETTE.surface(PALETTE.UI_GREY_COOLDOWN, PALETTE.UI_GREY_BORDER, 0.98))
	set_stylebox("panel", "TooltipPanel", PALETTE.surface(PALETTE.UI_GREY_COOLDOWN, PALETTE.UI_GREY_BORDER, 0.98))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		set_color(state, "Button", PALETTE.UI_GREY_ACTIVE)
	set_color("font_color", "Label", PALETTE.PLAYER_DAMAGE_WHITE)
	set_color("font_color", "TooltipLabel", PALETTE.PLAYER_DAMAGE_WHITE)
