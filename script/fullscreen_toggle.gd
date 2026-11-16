extends CanvasLayer


signal home_requested
signal menu_requested

@onready var button: Button = %FullscreenButton
@onready var home_button: Button = %HomeButton
var _home_available := false
var menu_button: Button

func _ready() -> void :
	layer = 160
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = true
	add_to_group("session_toolbar")
	UiFonts.apply_to_button(home_button, 15)
	menu_button = Button.new()
	menu_button.name = "MenuButton"
	menu_button.text = "菜单"
	menu_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	$Root.add_child(menu_button)
	UiFonts.apply_to_button(menu_button,15)
	GamePalette.apply_neutral_button(menu_button)
	menu_button.pressed.connect(func():menu_requested.emit())
	home_button.pressed.connect(_request_home)
	set_home_available(false)
	if button == null:
		button = get_node_or_null("Root/FullscreenButton")
	if button:
		UiFonts.apply_to_button(button, 15)
		GamePalette.apply_neutral_button(button)
		if not button.pressed.is_connected(_on_pressed):
			button.pressed.connect(_on_pressed)
	GamePalette.apply_neutral_button(home_button)
	button.icon=preload("res://assest/ui/toolbar_fullscreen.svg")
	home_button.icon=preload("res://assest/ui/toolbar_home.svg")
	menu_button.icon=preload("res://assest/ui/toolbar_menu.svg")
	get_viewport().size_changed.connect(_refresh_label)
	_refresh_label()

func set_home_available(available: bool) -> void:
	_home_available = available
	home_button.visible = available
	home_button.disabled = not available
	if menu_button:
		menu_button.visible=available
		menu_button.disabled=not available
		_refresh_label()

func _request_home() -> void:
	if not _home_available: return
	set_home_available(false)
	home_requested.emit()

func owns_pointer(point: Vector2) -> bool:
	if not visible: return false
	for control in [button, home_button, menu_button]:
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
	button.tooltip_text = L10n.text("退出全屏") if _is_fullscreen() else L10n.text("全屏")
	home_button.tooltip_text = L10n.text("结束当前局并返回主页")
	menu_button.tooltip_text = L10n.text("菜单")
	var ui: float=preload("res://script/boss_hud_layout.gd").display_scale(self)
	var controls: Array=[button,home_button,menu_button]
	var group_width: float=(128 if _home_available else 40)*ui
	for i in controls.size():
		var control: Button=controls[i]
		control.text=""
		control.expand_icon=true
		control.add_theme_constant_override("icon_max_width",int(20*ui))
		control.offset_top=8*ui
		control.offset_bottom=48*ui
		control.set_anchors_preset(Control.PRESET_CENTER_TOP)
		control.offset_right=group_width*0.5-44*i*ui
		control.offset_left=control.offset_right-40*ui
		for state in ["normal","hover","pressed","disabled","focus"]:
			var style: StyleBox=control.get_theme_stylebox(state)
			for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]: style.set_content_margin(side,4*ui)
