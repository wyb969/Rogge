extends Node2D

@onready var main_ui: CanvasLayer = $mainUI
@onready var game_end_ui: Node2D = $GameEndUI
@onready var game_root: Node = $GameRoot

const GAME_SCENE := preload("res://scenes/game.tscn")
const MOBILE_CONTROLS_SCENE := preload("res://scenes/mobile_controls.tscn")
const FULLSCREEN_TOGGLE_SCENE := preload("res://scenes/fullscreen_toggle.tscn")
const SETTINGS_PAGE_SCENE := preload("res://scenes/settings_page.tscn")

var game: Node = null
var mobile_controls: CanvasLayer = null
var fullscreen_toggle: CanvasLayer = null
var settings_page: CanvasLayer = null

func _ready() -> void:
	_ensure_keyboard_actions()
	main_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	game_end_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	# Warm web glyph atlases so upgrade card digits never tofu.
	UiFonts.ui()
	UiFonts.ui_bold()
	_ensure_mobile_controls()
	_ensure_fullscreen_toggle()

	game_end_ui.hide_result()

	await load_new_game()
	game.prepare_game()

	show_main_menu()


func _ensure_keyboard_actions() -> void:
	_bind_key("up", KEY_W)
	_bind_key("up", KEY_UP)
	_bind_key("down", KEY_S)
	_bind_key("down", KEY_DOWN)
	_bind_key("left", KEY_A)
	_bind_key("left", KEY_LEFT)
	_bind_key("right", KEY_D)
	_bind_key("right", KEY_RIGHT)
	_bind_key("roll", KEY_Z)

func _bind_key(action: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == keycode:
			return
	var key := InputEventKey.new()
	key.physical_keycode = keycode
	InputMap.action_add_event(action, key)

func _ensure_mobile_controls() -> void:
	if mobile_controls != null and is_instance_valid(mobile_controls):
		return
	mobile_controls = MOBILE_CONTROLS_SCENE.instantiate()
	add_child(mobile_controls)
	mobile_controls.hide_controls()


func _ensure_fullscreen_toggle() -> void:
	# Prefer the scene-embedded instance from main.tscn.
	fullscreen_toggle = get_node_or_null("FullscreenToggle")
	if fullscreen_toggle != null and is_instance_valid(fullscreen_toggle):
		return
	fullscreen_toggle = FULLSCREEN_TOGGLE_SCENE.instantiate()
	fullscreen_toggle.name = "FullscreenToggle"
	add_child(fullscreen_toggle)


func show_main_menu() -> void:
	Engine.time_scale = 1.0
	main_ui.show()
	game_end_ui.hide_result()
	AudioManager.play_menu_bgm()
	if mobile_controls:
		mobile_controls.hide_controls()
	if game and is_instance_valid(game):
		game.prepare_game()

	get_tree().paused = true


func start_game() -> void:
	_dismiss_settings()
	Engine.time_scale = 1.0
	# Start is a user gesture — unlock web AudioContext here.
	if AudioManager.has_method("unlock_web_audio"):
		AudioManager.unlock_web_audio()
	AudioManager.play_game_bgm()
	main_ui.hide()
	game_end_ui.hide_result()

	get_tree().paused = false

	if game and is_instance_valid(game):
		game.start_game()
	if mobile_controls:
		mobile_controls.show_controls()


func _on_start_button_pressed() -> void:
	if AudioManager.has_method("unlock_web_audio"):
		AudioManager.unlock_web_audio()
	await load_new_game()
	start_game()


func _on_setting_button_pressed() -> void:
	_ensure_settings_page()
	_ensure_mobile_controls()
	settings_page.open_page()
	if mobile_controls:
		mobile_controls.begin_layout_edit()


func _ensure_settings_page() -> void:
	if settings_page != null and is_instance_valid(settings_page):
		return
	settings_page = SETTINGS_PAGE_SCENE.instantiate()
	settings_page.name = "SettingsPage"
	add_child(settings_page)
	settings_page.closed.connect(_on_settings_closed)


func _on_settings_closed() -> void:
	if mobile_controls and is_instance_valid(mobile_controls):
		mobile_controls.end_layout_edit()


func _dismiss_settings() -> void:
	if settings_page and is_instance_valid(settings_page):
		settings_page.visible = false
	if mobile_controls and is_instance_valid(mobile_controls) and mobile_controls.layout_edit:
		mobile_controls.end_layout_edit()


func on_game_over(stat: Dictionary) -> void:
	Engine.time_scale = 1.0

	if game and is_instance_valid(game):
		game.end_game()
	if mobile_controls:
		mobile_controls.hide_controls()

	get_tree().paused = true

	if stat.get("victory", false):
		AudioManager.play_victory()
	else:
		AudioManager.play_game_over()

	game_end_ui.show_result(stat)


func _on_game_end_ui_retry_pressed() -> void:
	game_end_ui.hide_result()

	await load_new_game()
	start_game()


func _on_game_end_ui_main_menu_pressed() -> void:
	game_end_ui.hide_result()

	await load_new_game()
	game.prepare_game()

	show_main_menu()


func load_new_game() -> void:
	for child in game_root.get_children():
		child.queue_free()

	await get_tree().process_frame

	game = GAME_SCENE.instantiate()
	game.name = "game"
	game.add_to_group("game")
	game_root.add_child(game)

	if game.has_signal("game_over"):
		game.game_over.connect(on_game_over)
