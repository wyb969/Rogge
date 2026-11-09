extends PanelContainer

signal selected(upgrade_id: String)
var upgrade_id: String = ""
var hover_tween: Tween
var _press_at := Vector2.ZERO
var _tracking_press := false
var _dragged := false

const CARD_SIZE: = Vector2(240, 230)

@onready var title_label: Label = $VBoxContainer / TitleLabel
@onready var desc_label: RichTextLabel = $VBoxContainer / DescLabel
@onready var icon: TextureRect = $VBoxContainer / Icon

func _ready() -> void :
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	call_deferred("_init_pivot")

	mouse_entered.connect(_on_mouse_enter)
	mouse_exited.connect(_on_mouse_exited)

	_configure_labels()

func _configure_labels() -> void :
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiFonts.apply_to_label(title_label, 16)

	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_label.custom_minimum_size = Vector2(CARD_SIZE.x - 24.0, 0.0)
	_style_description(14)

	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

func setup(data: Dictionary):
	upgrade_id = data["id"]

	title_label.text = str(data.get("title", ""))
	desc_label.text = str(data.get("rich_desc", data.get("desc", "")))
	icon.texture = load(data["icon"])
	preload("res://script/visual_style.gd").style_icon(icon, upgrade_id)
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE

func set_display_width(width: float, ui_scale: float = 1.0, compact: bool = false) -> void :
	desc_label.custom_minimum_size.x = width - 24.0 * ui_scale
	UiFonts.apply_to_label(title_label, int(16 * ui_scale))
	_style_description(int(14 * ui_scale))
	icon.custom_minimum_size = Vector2.ONE * (24 if compact else 48) * ui_scale
	$VBoxContainer.add_theme_constant_override("separation", int(5 * ui_scale))
	custom_minimum_size = Vector2(width, (120 if compact else CARD_SIZE.y) * ui_scale)
	size = custom_minimum_size
	pivot_offset = size * 0.5

func _on_selected_pressed():
	selected.emit(upgrade_id)

func _gui_input(event: InputEvent) -> void :
	if event is InputEventScreenDrag or event is InputEventMouseMotion:
		if _tracking_press and event.position.distance_to(_press_at) > 10.0:
			_dragged = true
	elif event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		if event.pressed:
			_press_at = event.position
			_tracking_press = true
			_dragged = false
		else:
			var choose := _tracking_press and not _dragged and Rect2(Vector2.ZERO,size).has_point(event.position)
			_tracking_press = false
			if choose:
				selected.emit(upgrade_id)
				accept_event()

func _on_mouse_enter() -> void :
	play_hover_tween(Vector2(1.02, 1.02), Color(1.1, 1.1, 1.1), 0.12)

func _on_mouse_exited() -> void :
	play_hover_tween(Vector2.ONE, Color.WHITE, 0.12)

func play_hover_tween(target_scale: Vector2, target_color: Color, duration: float):
	if hover_tween != null and hover_tween.is_valid():
		hover_tween.kill()

	hover_tween = create_tween()
	hover_tween.set_trans(Tween.TRANS_BACK)
	hover_tween.set_ease(Tween.EASE_OUT)
	hover_tween.tween_property(self, "scale", target_scale, duration)
	hover_tween.parallel().tween_property(self, "modulate", target_color, duration)

func _init_pivot():
	pivot_offset = size / 2.0

func _style_description(font_size: int) -> void:
	desc_label.add_theme_font_override("normal_font",UiFonts.ui())
	desc_label.add_theme_font_override("bold_font",UiFonts.ui_bold())
	desc_label.add_theme_font_size_override("normal_font_size",font_size)
	desc_label.add_theme_font_size_override("bold_font_size",font_size)
	desc_label.add_theme_color_override("default_color",GamePalette.PLAYER_DAMAGE_WHITE)
