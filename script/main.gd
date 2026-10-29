extends Node2D

@onready var main_ui: CanvasLayer = $mainUI
@onready var game_end_ui: Node2D = $GameEndUI
@onready var game_root: Node = $GameRoot

const GAME_SCENE := preload("res://scenes/game.tscn")
const MOBILE_CONTROLS_SCENE := preload("res://scenes/mobile_controls.tscn")
const FULLSCREEN_TOGGLE_SCENE := preload("res://scenes/fullscreen_toggle.tscn")

var game: Node = null
var mobile_controls: CanvasLayer = null
var fullscreen_toggle: CanvasLayer = null

func _ready() -> void:
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
	print("打开设置界面")


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
