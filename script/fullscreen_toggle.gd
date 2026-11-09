extends CanvasLayer


signal home_requested

@onready var button: Button = %FullscreenButton
@onready var home_button: Button = %HomeButton
var _home_available := false

func _ready() -> void :
	layer = 160
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = true
	add_to_group("session_toolbar")
	UiFonts.apply_to_button(home_button, 15)
	GamePalette.apply_button(home_button)
	home_button.pressed.connect(_request_home)
	set_home_available(false)
	if button == null:
		button = get_node_or_null("Root/FullscreenButton")
	if button:
		UiFonts.apply_to_button(button, 15)
		GamePalette.apply_button(button)
		if not button.pressed.is_connected(_on_pressed):
			button.pressed.connect(_on_pressed)
	get_viewport().size_changed.connect(_refresh_label)
	_refresh_label()

func set_home_available(available: bool) -> void:
	_home_available = available
	home_button.visible = available
	home_button.disabled = not available

func _request_home() -> void:
	if not _home_available: return
	set_home_available(false)
	home_requested.emit()

func owns_pointer(point: Vector2) -> bool:
	if not visible: return false
	for control in [button, home_button]:
		if control.visible and control.get_global_rect().has_point(point): return true
	return false

func _on_pressed() -> void :
	if AudioManager and AudioManager.has_method("unlock_web_audio"):
		AudioManager.unlock_web_audio()

	if _is_fullscreen():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	call_deferred("_refresh_label")
	var timer: = get_tree().create_timer(0.25)
	timer.timeout.connect(_refresh_label)

func _is_fullscreen() -> bool:
	var mode: = DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN\
	or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN

func _refresh_label() -> void :
	if button == null:
		return
	button.text = "退出全屏" if _is_fullscreen() else "全屏"
	var vp: = get_viewport().get_visible_rect().size
	if vp.x < 8.0 or vp.y < 8.0:
		return
	var h: = clampf(vp.y * 0.055, 40.0, 52.0)
	var w: = clampf(vp.x * 0.28, 96.0, 168.0)
	button.offset_top = 8.0
	button.offset_right = -10.0
	button.offset_bottom = 8.0 + h
	button.offset_left = -10.0 - w

	# Same height, style and fixed gap: the two controls form one compact toolbar.
	var home_width := clampf(vp.x * 0.22, 100.0, 138.0)
	home_button.offset_top = button.offset_top
	home_button.offset_bottom = button.offset_bottom
	home_button.offset_right = button.offset_left - 8.0
	home_button.offset_left = home_button.offset_right - home_width
