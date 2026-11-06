extends SceneTree

const COMBOS := preload("res://script/equipment_combos.gd")
var failures: Array[String] = []
var checks := 0
var main: Node
var game: Node

func _init() -> void: call_deferred("_run")
func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _isolate() -> void:
	game.spawner.timer.stop()
	game.spawner.get_node("Elite").stop()
	game.spawner.set_process(false)
	game.player.set_physics_process(false)
	game.player.set_process(false)
	game.weather.stop()
	game.variety._courier_left = 99999
	game.bomb_controller.set_physics_process(false)
	game.arsenal_combo.set_physics_process(false)
	if game.level_manager.signal_level_up.is_connected(game.on_level_up): game.level_manager.signal_level_up.disconnect(game.on_level_up)
	game.level_manager.level_need_coin_number = 1000000
	for name in ["HandWeapon", "CircleWeapon", "Weapon", "DroneController", "MolotovController", "FreezeController"]:
		game.get_node(name).process_mode = Node.PROCESS_MODE_DISABLED

func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	var settings: Node = root.get_node("SettingsStore")
	settings.difficulty = 1
	await main._launch_run(&"")
	game = main.game
	_isolate()
	var player: Node = game.player
	var panel: Node = game.equipment_panel
	var base_pickup_radius: float = player.pickup_range
	_expect(not game.growth_combo_active and player.growth_move_multiplier == 1 and player.growth_heal_multiplier == 1, "normal starts have no growth multipliers")
	game.on_coin_collected(2)
	_expect(game.level_manager.coin_number == 2, "ordinary XP is unchanged before the set")
	game.beast_powers.unlock(0)
	_expect(game.beast_powers._buttons[0].tooltip_text.contains("45%"), "healing power starts with its ordinary tooltip")
	game._on_upgrade_selected("pickup_up")
	game._on_upgrade_selected("speed_up")
	_isolate()
	_expect(not game.growth_combo_active and is_equal_approx(player.effective_move_speed(), 120) and panel._growth_label.text.contains("2/3"), "two cards grant only their own stats and display progress")
	_expect(is_equal_approx(player.pickup_range, base_pickup_radius * 1.2), "the pickup card still changes only this player's radius")
	for id in ["pickup_up", "speed_up"]:
		_expect(not panel._slots[id].combo_border.visible, "incomplete sets have no activated border")
	game._spawn_xp_coin_now(Vector2(5000, 0), 2)
	var old_coin: Node = game._xp_actors.back()
	_expect(old_coin.prepared_xp == 2, "difficulty-prepared coins do not snapshot the future combo")
	game._on_upgrade_selected("regen_up")
	_isolate()
	_expect(game.growth_combo_active and is_equal_approx(player.SPEED, 120) and is_equal_approx(player.effective_move_speed(), 144), "the third card multiplies final walking speed without overwriting its base")
	_expect(is_equal_approx(player.effective_heal_amount(5), 6) and player.healing_multiplier == 1, "recovery gains twenty percent independently of difficulty")
	_expect(panel._growth_label.text.contains("已激活") and game.beast_powers._buttons[0].tooltip_text.contains("54%"), "activation updates set status and the existing healing-power tooltip")
	var xp: int = game.level_manager.coin_number
	old_coin.collect_coin()
	old_coin.collect_coin()
	for i in 4:
		game._spawn_xp_coin_now(Vector2(6000 + i * 20, 0), 2)
		var coin: Node = game._xp_actors.back()
		_expect(coin.prepared_xp == 2, "new coins retain only the original difficulty preparation")
		coin.collect_coin()
	await create_timer(0.18).timeout
	_expect(game.level_manager.coin_number == xp + 13 and game._growth_xp_tenths == 0, "five real two-XP pickups give exactly thirteen XP, including a pre-activation coin and duplicate pickup calls")
	xp = game.level_manager.coin_number
	game.on_coin_collected(10)
	_expect(game.level_manager.coin_number == xp + 13, "the legacy/direct coin route receives the same bonus once")
	player.player_health = 300
	player._regen_acc = 0
	player._tick_regen(3)
	_expect(is_equal_approx(player.player_health, 301.2), "real regeneration ticks receive twenty percent more healing")
	var orb: Node = game.spawn_healing_orb(Vector2(7000, 0), 5)
	_expect(is_equal_approx(orb.collect(), 6), "green-orb healing uses the same one-time recovery multiplier")
	player.lifesteal_level = 1
	var hp: float = player.player_health
	player.notify_damage_dealt(100)
	_expect(is_equal_approx(player.player_health - hp, 2.4), "lifesteal applies the boost after its ordinary cap")
	player.player_health = 50
	_expect(game.beast_powers.cast(0) and is_equal_approx(player.player_health, 320), "the real healing power restores fifty-four percent of base maximum HP")
	var max_hp: float = player.max_player_health
	player.apply_level_growth(1)
	_expect(player.max_player_health == max_hp + 25, "XP health growth is not multiplied as healing")
	var description: String = game.pause_menu._regen_desc()
	_expect(description.contains("2.4") and game.pause_menu._monster_necklace_desc().contains("6"), "regeneration and necklace previews match the boosted amounts")
	game._on_upgrade_selected("speed_up")
	_isolate()
	for _i in 20: game._refresh_growth_combo()
	_expect(is_equal_approx(player.SPEED, 140) and is_equal_approx(player.effective_move_speed(), 168) and is_equal_approx(player.effective_heal_amount(5), 6), "member upgrades and repeated refreshes cannot compound set multipliers")
	player.apply_rest_move_speed(35)
	_expect(is_equal_approx(player.effective_move_speed(), 210), "rest movement upgrades participate in the final twenty-percent speed bonus")
	Input.action_press("right")
	player._physics_process(0.3)
	Input.action_release("right")
	_expect(is_equal_approx(player.velocity.x, 210), "the real movement step uses the boosted speed")
	player._start_dash(Vector2.RIGHT)
	_expect(player.velocity == Vector2.RIGHT * player.DASH_SPEED and is_equal_approx(player.DASH_DURATION, 0.14), "walking bonuses do not change dash speed or duration")
	player.reset_dash()
	xp = game.level_manager.coin_number
	for i in game.MAX_XP_COINS + 20: game._spawn_xp_coin_now(Vector2(8000 + i * 5, 0), 2)
	var prepared := 0
	for coin in game._xp_actors: prepared += coin.prepared_xp
	_expect(game._xp_actors.size() == game.MAX_XP_COINS and prepared == (game.MAX_XP_COINS + 20) * 2, "overflow merging preserves only base prepared XP")
	for coin in game._xp_actors: coin.collect_coin()
	await create_timer(0.18).timeout
	_expect(game.level_manager.coin_number == xp + 717 and game._growth_xp_tenths == 6, "merged pickups retain the exact thirty-percent total and fractional remainder")
	game.variety.clear_combat_effects()
	_expect(game.growth_combo_active and game._growth_xp_tenths == 6 and is_equal_approx(player.growth_move_multiplier, 1.2), "stage effect cleanup preserves passive set bonuses and XP remainder")
	var balance: int = game.level_manager.coin_number
	game.on_coin_collected(0)
	game.on_coin_collected(-4)
	_expect(game.level_manager.coin_number == balance and game._growth_xp_tenths == 6, "zero and invalid XP cannot consume or create a fractional bonus")
	game.equipment_panel.reset_equipment()
	game._refresh_growth_combo()
	_expect(not game.growth_combo_active and player.growth_move_multiplier == 1 and player.growth_heal_multiplier == 1 and game._growth_xp_tenths == 0, "loss of the set removes only its own multipliers and remainder")
	await main._launch_run(&"")
	game = main.game
	_isolate()
	game._on_upgrade_selected("pickup_up")
	game._on_upgrade_selected("speed_up")
	game.spawner._on_boss_defeated()
	await process_frame
	var hub: Node = game.rest_hub
	hub._on_reward_pressed("regen_up")
	_expect(not game.growth_combo_active and game.player.regen_level == 0, "selecting an unconfirmed rest reward cannot activate a set")
	hub._on_next_pressed()
	_expect(game.spawner.stage == 2 and game.growth_combo_active and game.player.regen_level == 1 and game.equipment_panel.get_level("regen_up") == 1 and is_equal_approx(game.player.effective_move_speed(), 144), "a real boss-rest regeneration reward equips the missing card and completes the set for the next stage")
	hub._on_next_pressed()
	_expect(game.player.regen_level == 1 and game.equipment_panel.get_level("regen_up") == 1, "duplicate rest confirmation cannot stack the card or set")
	for difficulty in [0, 1, 2]:
		settings.difficulty = difficulty
		await main._launch_run(&"growth")
		game = main.game
		_isolate()
		var base_reward: float = 1.5 if difficulty == 0 else 1.0
		_expect(game.growth_combo_active and is_equal_approx(game.player.healing_multiplier, base_reward) and is_equal_approx(game.player.effective_heal_amount(10), base_reward * 12), "difficulty and set healing compose once")
		var before: int = game.level_manager.coin_number
		game.on_coin_collected(10)
		game.on_coin_collected(10)
		_expect(game.level_manager.coin_number - before == (39 if difficulty == 0 else 26), "difficulty-adjusted direct XP retains exact set totals")
	settings.difficulty = 1
	await main._launch_run(&"equipment_combos")
	game = main.game
	_isolate()
	panel = game.equipment_panel
	panel.set_process(false)
	_expect(game.growth_combo_active and game.arsenal_combo.unlocked and panel._active_combo_borders.size() == 6, "both Debug sets activate exactly six equipment borders")
	panel._process(0.36)
	for group in ["growth", "arsenal"]:
		var members: Array[String] = COMBOS.GROWTH_MEMBERS if group == "growth" else COMBOS.ARSENAL_MEMBERS
		var phase: float = panel._slots[members[0]].combo_border.phase
		for id in members:
			var border: Control = panel._slots[id].combo_border
			_expect(border.visible and border.tint == COMBOS.color_for(group) and is_equal_approx(border.phase, phase) and not border.is_processing(), "same-set icon borders share color and exact phase without per-icon processing")
	var clock: float = panel._combo_clock
	game._on_upgrade_selected("speed_up")
	panel.set_process(false)
	_expect(panel._combo_clock == clock, "upgrading one member cannot restart its highlight phase")
	paused = true
	panel._process(2)
	_expect(panel._combo_clock == clock, "pause freezes the shared highlighter clock")
	paused = false
	panel.hide()
	panel._process(2)
	_expect(panel._combo_clock == clock, "hidden equipment performs no highlight updates")
	panel.show()
	var nodes: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	for _i in 100:
		panel.refresh_combo_borders()
		panel._process(0.05)
	_expect(panel._active_combo_borders.size() == 6 and int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) == nodes, "repeated refreshes reuse the same six border nodes")
	for size in [Vector2i(390, 844), Vector2i(900, 500)]:
		root.size = size
		await process_frame
		await process_frame
		panel._fit_equipment()
		var viewport: Vector2 = root.get_visible_rect().size
		for label in [panel._arsenal_label, panel._growth_label]:
			var rect: Rect2 = label.get_global_rect()
			_expect(rect.position.x >= 0 and rect.end.x <= viewport.x and rect.end.y <= viewport.y, "both status labels stay inside portrait and landscape viewports")
	await main._launch_run(&"growth")
	game = main.game
	_expect(game.growth_combo_active and is_equal_approx(game.player.effective_move_speed(), 144), "growth Debug is equipped once")
	await main._on_game_end_ui_retry_pressed()
	game = main.game
	_expect(game.growth_combo_active and is_equal_approx(game.player.effective_move_speed(), 144), "Debug retry restores the selected set without compounding")
	_expect(is_equal_approx(game.player.pickup_range, base_pickup_radius * 1.2), "Debug retries cannot compound a shared scene pickup shape")
	await main._launch_run(&"")
	game = main.game
	_expect(not game.growth_combo_active and game.player.growth_heal_multiplier == 1 and game.player.growth_move_multiplier == 1 and game._growth_xp_tenths == 0 and game.equipment_panel._active_combo_borders.is_empty(), "new normal runs inherit no set, XP remainder or border animation")
	_expect(is_equal_approx(game.player.pickup_range, base_pickup_radius), "a normal new run restores the original pickup radius")
	main.show_main_menu()
	if failures.is_empty(): print("GROWTH COMBO OK: %d checks; actual movement/healing/XP pickups/merge/difficulty, no stacking, shared green/gold phase, bounded border work, layout and Debug lifecycle" % checks)
	else:
		for message in failures: push_error(message)
	quit(0 if failures.is_empty() else 1)
