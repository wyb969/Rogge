extends SceneTree
var failures: Array[String] = []
func _init() -> void :
	call_deferred("_run")
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
	var p: Node = game.player
	var powers: Node = game.beast_powers
	game.spawner.timer.stop()
	game.spawner.get_node("Elite").stop()
	p.set_physics_process(false)
	powers.set_process(false)
	for name in ["HandWeapon", "CircleWeapon", "Weapon", "DroneController", "MolotovController", "FreezeController"]:
		game.get_node(name).process_mode = Node.PROCESS_MODE_DISABLED
	for index in 4: powers.unlock(index)
	_expect(powers._buttons.size() == 4, "four earned powers have exactly four compact buttons")
	var buttons: = 0
	for child in powers._canvas.get_children():
		if child is Button: buttons += 1
	_expect(buttons == 1, "only the unrelated settlement button remains outside the icon column; no right cast/cycle controls")
	p.player_health = p.max_player_health * 0.2
	powers.select(3)
	powers._buttons[0].pressed.emit()
	_expect(is_equal_approx(p.player_health, p.max_player_health * 0.65) and powers.cooldowns[0] == 35 and powers.selected == 0, "one heal-icon click immediately casts even when another power was selected")
	var hp: float = p.player_health
	powers._buttons[0].pressed.emit()
	_expect(p.player_health == hp and powers._buttons[0].disabled and powers._buttons[0]._mask.fraction == 1, "cooldown darkens the icon and blocks repeat casts")
	powers._buttons[3].pressed.emit()
	_expect(powers.barrier_left == 6 and powers.cooldowns[3] == 40 and powers.cooldowns[0] == 35, "a second icon casts independently without a selection step")
	powers._process(17.5)
	_expect(is_equal_approx(powers._buttons[0]._mask.fraction, 0.5) and powers._buttons[0].disabled, "half cooldown uncovers half of the icon without restoring availability early")
	paused = true
	powers._process(20)
	_expect(powers.cooldowns[0] == 17.5, "reward pauses freeze icon and power cooldown together")
	paused = false
	powers._process(17.5)
	_expect( not powers._buttons[0].disabled and powers._buttons[0]._mask.fraction == 0, "completed cooldown restores the entire colored icon")
	p.player_health = p.max_player_health
	powers._buttons[0].pressed.emit()
	_expect(powers.cooldowns[0] == 0, "full-health icon taps preserve the healing charge")
	powers._buttons[2].pressed.emit()
	_expect(powers.cooldowns[2] == 0, "empty-screen pickup icon taps preserve its charge")
	var enemy: Node = load("res://scenes/enemy_shell.tscn").instantiate()
	enemy.set_enemy_data(load("res://resource/Enemy_1.tres"))
	enemy.set_player_ref(p)
	enemy.add_to_group("EnemyGroup")
	game.add_child(enemy)
	enemy.global_position = p.global_position + Vector2(60, 0)
	enemy.health = 1000
	enemy.set_physics_process(false)
	powers._buttons[1].pressed.emit()
	_expect(enemy.health < 1000 and powers.cooldowns[1] == 45 and powers.selected == 1, "the lightning icon directly damages a real on-screen enemy")
	enemy.free()
	Engine.time_scale = 1
	for size in [Vector2i(390, 844), Vector2i(900, 500), Vector2i(390, 844), Vector2i(900, 500)]:
		root.size = size
		await process_frame
		powers._layout()
		await process_frame
		await process_frame
		var bounds: = Rect2(Vector2.ZERO, root.get_visible_rect().size)
		for icon in powers._buttons.values():
			_expect(icon.text == "" and is_equal_approx(icon.size.x, icon.size.y) and bounds.encloses(icon.get_global_rect()), "icons remain square/text-free and fit through repeated phone/landscape rotation")
			_expect(icon.get_global_rect().end.x < bounds.size.x * 0.2, "skills occupy only the compact left edge")
			var touch: = InputEventScreenTouch.new()
			touch.index = 15
			touch.pressed = true
			touch.position = icon.get_global_rect().get_center()
			_expect(powers.owns_pointer(touch.position) and not main.mobile_controls._handle_touch(touch), "joystick ownership yields both ready and cooling icon touches")
	var original: Array = powers._buttons.values()
	for _repeat in 100: powers._refresh()
	_expect(powers._buttons.values() == original, "cooldown updates reuse existing icons and masks")
	main.on_game_over({"victory": false})
	_expect( not powers._canvas.visible, "results hide every skill icon")
	await main._on_game_end_ui_retry_pressed()
	_expect(main.game.beast_powers.unlocked.is_empty() and main.game.beast_powers._buttons.is_empty(), "new runs contain no previous-run skills or cooldown overlays")
	main.show_main_menu()
	if failures.is_empty(): print("SKILL ICONS OK: direct heal/defense/lightning casts, preserved no-op charges, independent cooldown masks/pause/readiness, no right controls, compact rotation layout/touch ownership and run reset")
	else:
		for failure in failures: push_error(failure)
	paused = false
	quit(0 if failures.is_empty() else 1)
