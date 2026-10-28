extends CanvasLayer
## Always-on fullscreen toggle for web / desktop / phone browsers.

@onready var button: Button = %FullscreenButton

func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = true
	if button == null:
		button = get_node_or_null("Root/FullscreenButton")
	if button:
		UiFonts.apply_to_button(button, 15)
		if not button.pressed.is_connected(_on_pressed):
			button.pressed.connect(_on_pressed)
	get_viewport().size_changed.connect(_refresh_label)
	_refresh_label()

func _on_pressed() -> void:
	if AudioManager and AudioManager.has_method("unlock_web_audio"):
		AudioManager.unlock_web_audio()

	if _is_fullscreen():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	call_deferred("_refresh_label")
	var timer := get_tree().create_timer(0.25)
	timer.timeout.connect(_refresh_label)

func _is_fullscreen() -> bool:
	var mode := DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN \
		or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN

func _refresh_label() -> void:
	if button == null:
		return
	button.text = "退出全屏" if _is_fullscreen() else "全屏"
