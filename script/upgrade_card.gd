extends PanelContainer

signal selected(upgrade_id: String)
var upgrade_id: String = ""
var hover_tween: Tween

const CARD_SIZE := Vector2(180, 250)
const UI_FONT := preload("res://assest/fonts/DroidSansFallback.ttf")

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var desc_label: Label = $VBoxContainer/DescLabel
@onready var icon: TextureRect = $VBoxContainer/Icon

func _ready() -> void:
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	call_deferred("_init_pivot")

	mouse_entered.connect(_on_mouse_enter)
	mouse_exited.connect(_on_mouse_exited)

	_configure_labels()

func _configure_labels() -> void:
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_override("font", UI_FONT)
	title_label.add_theme_font_size_override("font_size", 16)

	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_label.custom_minimum_size = Vector2(CARD_SIZE.x - 24.0, 0.0)
	desc_label.add_theme_font_override("font", UI_FONT)
	desc_label.add_theme_font_size_override("font_size", 13)

	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

func setup(data: Dictionary):
	upgrade_id = data["id"]
	title_label.text = data["title"]
	desc_label.text = data["desc"]
	icon.texture = load(data["icon"])
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE

func _on_selected_pressed():
	selected.emit(upgrade_id)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			selected.emit(upgrade_id)

func _on_mouse_enter() -> void:
	play_hover_tween(Vector2(1.08, 1.08), Color(1.15, 1.15, 1.15), 0.12)

func _on_mouse_exited() -> void:
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
