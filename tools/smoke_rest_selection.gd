extends SceneTree
var failures: Array[String] = []
func _init() -> void : call_deferred("_run")
func _expect(ok: bool, message: String) -> void :
	if not ok: failures.append(message)
func _run() -> void :
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	await main._launch_run(&"")
	var game: Node = main.game
	game.diagnostic_mode = "rest_test"
	game.spawner.timer.stop()
	game.spawner.get_node("Elite").stop()
	game.player.set_physics_process(false)
	game.spawner._on_boss_defeated()
	await process_frame
	var hub: Node = game.rest_hub
	var hp: float = game.player.max_player_health
	var defense: float = game.player.damage_reduction
	var events: = {"reward": 0, "next": 0}
	hub.reward_picked.connect( func(_id: String): events.reward += 1)
	hub.next_stage_pressed.connect( func(): events.next += 1)
	hub.next_button.pressed.emit()
	_expect(events.next == 0 and hub.next_button.disabled, "no selection cannot advance or grant a reward")
	var last: Button
	for id in ["max_hp", "defense", "monster_necklace", "max_hp"]:
		for button in hub._buttons:
			if str(button.get_meta("reward_id")) == id:
				button.pressed.emit()
				last = button
		_expect(game.player.max_player_health == hp and game.player.damage_reduction == defense and game.player.monster_necklace_level == 0 and events.reward == 0, "reselection never grants, removes or stacks rewards before confirmation")
		for button in hub._buttons:
			_expect( not button.disabled, "all options remain available before confirmation")
			_expect(button.get_theme_stylebox("normal") == (hub._selected_style if button == last else hub._idle_style), "only the selected option has a solid filled button")
	_expect(last.text.begins_with("已选") and not hub.next_button.disabled, "selection is named explicitly and enables confirmation")
	for size in [Vector2i(390, 844), Vector2i(1000, 700)]:
		root.size = size
		await process_frame
		await process_frame
		var viewport_bounds: = Rect2(Vector2.ZERO, root.get_visible_rect().size)
		_expect(viewport_bounds.encloses(hub._panel.get_global_rect()), "rest panel fits both portrait and landscape")
		var button: Button = hub._buttons[0]
		var physical_height: float = (root.get_final_transform() * Vector2(0, button.size.y) - root.get_final_transform() * Vector2.ZERO).length()
		_expect(physical_height >= 39.5, "rest choices preserve readable physical touch height")
		_expect(hub._selected_id == "max_hp", "rotation preserves the pending selection without granting it")
	hub.next_button.pressed.emit()
	hub.next_button.pressed.emit()
	hub._on_reward_pressed("defense")
	_expect(game.player.max_player_health == hp + 120 and game.player.damage_reduction == defense and game.player.monster_necklace_level == 0, "only the final selected max-HP reward is granted")
	_expect(events.reward == 1 and events.next == 1 and game.spawner.stage == 2, "duplicate confirm/hidden selection cannot award again or skip a stage")
	hub.open_hub()
	_expect(hub._selected_id == "" and hub.next_button.disabled and not hub._committed, "a later rest page starts without a stale selection")
	hub._on_reward_pressed("invalid")
	_expect(hub.next_button.disabled, "unknown reward identifiers cannot become selections")
	main.show_main_menu()
	if failures.is_empty(): print("REST SELECTION OK: real boss rest, freely changing filled selections, deferred exact reward, one confirmation/advance, hidden and invalid guards, reset")
	else:
		for message in failures: push_error(message)
	paused = false
	quit(0 if failures.is_empty() else 1)
