extends ScrollContainer

@onready var box: VBoxContainer = $VBoxContainer
func _ready() -> void :
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	follow_focus = true
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	get_viewport().size_changed.connect(_fit)
	call_deferred("_fit")
func _fit() -> void :
	var vp: = get_viewport().get_visible_rect().size
	var portrait: = vp.y > vp.x
	var width: = minf(760.0, vp.x - 40.0)
	var font_size: = 32 if portrait else 22
	box.custom_minimum_size.x = width
	box.add_theme_constant_override("separation", 10 if portrait else 8)
	for child in box.get_children():
		if child is Button:
			child.custom_minimum_size = Vector2(width, 104 if portrait else 54)
			UiFonts.apply_to_button(child, font_size)
		elif child is Label:
			child.custom_minimum_size.x = width
			child.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			child.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			UiFonts.apply_to_label(child, 46 if child.name == "TitleLabel" else font_size, child.name == "TitleLabel")
