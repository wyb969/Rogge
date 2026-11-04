extends SceneTree
var failures: Array[String] = []

func _init() -> void :
	call_deferred("_run")

func _run() -> void :
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	_expect(main.menu_page.visible and not main.debug_page.visible, "home is the initial page")
	var original: Node = main.game
	main.get_node("mainUI/Control/MenuCenter/VBoxContainer/DebugButton").pressed.emit()
	_expect(main.debug_page.visible and not main.menu_page.visible and paused, "Debug button opens a separate paused page")
	main.get_node("mainUI/Control/DebugCenter/VBoxContainer/BackButton").pressed.emit()
	_expect(main.menu_page.visible and not main.debug_page.visible and main.game == original, "back restores home without replacing its game")

	main.get_node("mainUI/Control/MenuCenter/VBoxContainer/DebugButton").pressed.emit()
	var necklace: Button = main.get_node("mainUI/Control/DebugCenter/VBoxContainer/DebugNecklaceButton")
	necklace.pressed.emit()
	necklace.pressed.emit()
	await process_frame
	await process_frame
	await physics_frame
	var game: Node = main.game
	game.player.set_physics_process(false)
	for enemy in get_nodes_in_group("EnemyGroup"):
		enemy.set_physics_process(false)
	_expect( not paused and not main.main_ui.visible, "test entry opens gameplay")
	_expect(game.player.monster_necklace_level == 1 and game.equipment_panel.get_level("monster_necklace") == 1, "test starts with one equipped level-one necklace")
	_expect(game.player.player_health == 450.0 and game.player.max_player_health == 500.0, "test leaves 50 HP available for healing")
	_expect(game.spawner.stage == 1 and not game.spawner._boss_fight_active and not game.spawner.timer.is_stopped(), "necklace test uses normal first-stage waves")
	_expect(get_nodes_in_group("EnemyGroup").size() == 3 and main.game_root.get_child_count() == 1, "test seeds three nearby targets without duplicate runs")
	var victim: Node = get_nodes_in_group("EnemyGroup")[0]
	victim.take_damage(100000.0)
	_expect(get_nodes_in_group("healing_orb").size() == 1, "test enemies drop a healing orb")
	var orb: Node = get_nodes_in_group("healing_orb")[0]
	orb.global_position = game.player.global_position
	orb.age = 0.2
	orb._physics_process(1.0 / 60.0)
	_expect(game.player.player_health == 455.0, "test orb really heals five HP")

	main.on_game_over({"victory": false})
	main.game_end_ui.retry_pressed.emit()
	await process_frame
	await process_frame
	_expect(main._test_mode == &"necklace" and main.game.player.monster_necklace_level == 1, "retry keeps necklace test mode without stacking copies")
	_expect(main.game.player.player_health == 450.0 and not paused, "retry resets test health and resumes gameplay")
	main.on_game_over({"victory": false})
	main.game_end_ui.main_menu_pressed.emit()
	await process_frame
	await process_frame
	_expect(main.main_ui.visible and main.menu_page.visible and not main.debug_page.visible and paused, "result return restores the home page")
	_expect(main._test_mode == &"" and main.game.player.monster_necklace_level == 0, "returning home clears test loadout")
	main.get_node("mainUI/Control/MenuCenter/VBoxContainer/StartButton").pressed.emit()
	await process_frame
	await process_frame
	_expect(main.game.player.monster_necklace_level == 0 and main.game.player.player_health == 500.0, "normal Start has no debug equipment or test injury")
	_expect(get_nodes_in_group("EnemyGroup").is_empty() and main.game_root.get_child_count() == 1, "normal Start has no seeded debug targets")
	if failures.is_empty():
		print("DEBUG MENU OK: home/back navigation, equipped necklace test, actual heal, rapid-tap guard, retry and normal-run reset")
	else:
		for failure in failures:
			push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _expect(ok: bool, message: String) -> void :
	if not ok:
		failures.append(message)
