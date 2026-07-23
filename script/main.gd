extends Node2D

@onready var main_ui: CanvasLayer = $mainUI
@onready var game_end_ui: Node2D = $GameEndUI
@onready var game_root: Node = $GameRoot

const GAME_SCENE := preload("res://scenes/game.tscn")

var game: Node = null

func _ready() -> void:
	main_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	game_end_ui.process_mode = Node.PROCESS_MODE_ALWAYS

	game_end_ui.hide_result()

	await load_new_game()
	game.prepare_game()

	show_main_menu()


func show_main_menu() -> void:
	main_ui.show()
	game_end_ui.hide_result()
	AudioManager.play_menu_bgm()
	if game and is_instance_valid(game):
		game.prepare_game()

	get_tree().paused = true


func start_game() -> void:
	AudioManager.play_game_bgm()
	main_ui.hide()
	game_end_ui.hide_result()

	get_tree().paused = false

	if game and is_instance_valid(game):
		game.start_game()


func _on_start_button_pressed() -> void:
	await load_new_game()
	start_game()


func _on_setting_button_pressed() -> void:
	print("打开设置界面")


func on_game_over(stat: Dictionary) -> void:
	if game and is_instance_valid(game):
		game.end_game()

	get_tree().paused = true
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
