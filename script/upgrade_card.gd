extends PanelContainer

signal  selected(upgrade_id:String)
var upgrade_id:String= ""
var hover_tween:Tween

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var desc_label: Label = $VBoxContainer/DescLabel

func _ready() -> void:
	custom_minimum_size = Vector2(160, 220)
	mouse_filter = Control.MOUSE_FILTER_STOP
	call_deferred("_init_pivot")

	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_enter)
	mouse_exited.connect(_on_mouse_exited)

func setup(data:Dictionary):
	upgrade_id = data["id"]
	title_label.text = data["title"]
	desc_label.text = data["desc"]


func _on_selected_pressed():
	selected.emit(upgrade_id)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			selected.emit(upgrade_id)

func _on_mouse_enter()->void:
	play_hover_tween(Vector2(1.1,1.1),0.5)

func _on_mouse_exited()->void:
	play_hover_tween(Vector2(1.0,1.0),0.5)

func play_hover_tween(target_scale: Vector2, duration: float):
	if hover_tween != null and hover_tween.is_valid():
		hover_tween.kill()

	hover_tween = create_tween()
	hover_tween.set_trans(Tween.TRANS_BACK)
	hover_tween.set_ease(Tween.EASE_OUT)
	hover_tween.tween_property(self, "scale", target_scale, duration)

func _init_pivot():
	pivot_offset = size / 2
