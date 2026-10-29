extends CanvasLayer
## Rest hub after the stage 1 boss. One run-long reward, then Next Stage.
## Cooldown reward scales dash cooldown and the gun's fire interval / shot lock.
## It does not change the axe, orbiting books, drones, molotov, or freeze.

signal reward_picked(reward_id: String)
signal next_stage_pressed

const MAX_HP_BONUS := 120.0
const DEFENSE_BONUS := 0.15
const MOVE_SPEED_BONUS := 35.0
const COOLDOWN_SCALE := 0.8

var _picked: bool = false
var _buttons: Array[Button] = []
var next_button: Button
var _built: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 125
	visible = false
	_build_ui()

func open_hub() -> void:
	_picked = false
	visible = true
	for btn in _buttons:
		btn.disabled = false
		btn.modulate = Color.WHITE
	if next_button:
		next_button.disabled = true

func close_hub() -> void:
	visible = false

func _build_ui() -> void:
	if _built:
		return
	_built = true

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.03, 0.05, 0.1, 0.8)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	add_child(panel)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -260.0
	panel.offset_top = -310.0
	panel.offset_right = 260.0
	panel.offset_bottom = 310.0

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title := Label.new()
	title.text = "休整  Rest"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiFonts.apply_to_label(title, 28, true)
	box.add_child(title)

	var sub := Label.new()
	sub.text = "选择一项奖励   Choose one"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiFonts.apply_to_label(sub, 16)
	box.add_child(sub)

	_add_reward_button(box, "max_hp", "生命 +120")
	_add_reward_button(box, "defense", "减伤 15%")
	_add_reward_button(box, "move_speed", "移速 +35")
	_add_reward_button(box, "cooldown", "冷却 -20%  Dash+Gun")
	_add_reward_button(box, "regen_up", "回复  Regen")
	_add_reward_button(box, "lifesteal_up", "吸血  Lifesteal")

	next_button = Button.new()
	next_button.name = "NextStage"
	next_button.text = "下一关  Next Stage"
	next_button.disabled = true
	next_button.custom_minimum_size = Vector2(460, 52)
	UiFonts.apply_to_button(next_button, 18)
	next_button.pressed.connect(_on_next_pressed)
	box.add_child(next_button)

func _add_reward_button(parent: Node, id: String, label_text: String) -> void:
	var btn := Button.new()
	btn.text = label_text
	btn.set_meta("reward_id", id)
	btn.custom_minimum_size = Vector2(460, 46)
	UiFonts.apply_to_button(btn, 16)
	btn.pressed.connect(_on_reward_pressed.bind(id))
	parent.add_child(btn)
	_buttons.append(btn)

func _on_reward_pressed(id: String) -> void:
	if _picked:
		return
	_picked = true
	for btn in _buttons:
		btn.disabled = true
		if str(btn.get_meta("reward_id", "")) == id:
			btn.modulate = Color(0.7, 1.0, 0.72)
	if next_button:
		next_button.disabled = false
	reward_picked.emit(id)

func _on_next_pressed() -> void:
	if not _picked:
		return
	next_stage_pressed.emit()
