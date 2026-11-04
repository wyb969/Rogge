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
	game.diagnostic_mode = "pickup_test"
	game.spawner.timer.stop()
	game.spawner.get_node("Elite").stop()
	game.player.set_physics_process(false)
	game.level_manager.signal_level_up.disconnect(game.on_level_up)
	game.level_manager.level_need_coin_number = 1000000
	for name in ["HandWeapon", "CircleWeapon", "Weapon", "DroneController", "MolotovController", "FreezeController"]:
		game.get_node(name).process_mode = Node.PROCESS_MODE_DISABLED
	var powers: Node = game.beast_powers
	powers.set_process(false)
	powers.unlock(2)
	_expect( not powers.cast(2) and powers.cooldowns[2] == 0, "a truly empty map preserves the skill charge")
	game.player.player_health = game.player.max_player_health - 50
	var hp: float = game.player.player_health
	var xp: int = game.level_manager.coin_number
	var expected: = 0
	for pair in [[Vector2(20, 0), 2], [Vector2(6000, 4000), 7], [Vector2(-9000, -3000), 11]]:
		game._spawn_xp_coin_now(pair[0], pair[1])
		expected += game.run_difficulty.experience_for(pair[1])
	var orb: Node = game.spawn_healing_orb(Vector2(-7000, 5000), 5)
	_expect(orb != null and game.player.monster_necklace_level == 0, "environmental healing drops exist without the necklace card")
	orb.age = 59.9
	paused = true
	_expect( not powers.cast(2) and powers.cooldowns[2] == 0, "paused gathering cannot consume the charge")
	paused = false
	_expect(powers.cast(2) and powers.cooldowns[2] == 22, "offscreen drops make the real skill cast successfully")
	for coin in game._xp_actors:
		_expect(coin.start_pick and coin.player_body == game.player, "all local and distant coins enter the normal pickup pipeline")
	_expect(orb.attracting, "distant green orb begins global attraction")

	game.player.global_position += Vector2(80, -40)
	var deadline: = Time.get_ticks_msec() + 1800
	while ( not game._xp_actors.is_empty() or not game._healing_actors.is_empty()) and Time.get_ticks_msec() < deadline:
		await process_frame
	_expect(game._xp_actors.is_empty() and game._healing_actors.is_empty(), "even very distant/near-expiry drops reach the moving hero within the bounded flight")
	_expect(game.level_manager.coin_number == xp + expected and game.player.player_health == hp + game.player.effective_heal_amount(5), "global gathering awards every difficulty-adjusted XP/heal exactly once")
	powers.cooldowns[2] = 0
	_expect( not powers.cast(2) and powers.cooldowns[2] == 0, "after collection an empty map again preserves the charge")
	main.show_main_menu()
	if failures.is_empty(): print("GLOBAL PICKUP OK: actual skill, map-wide coins/orbs, offscreen and moving targets, expiring drops, exact XP/heal without necklace, pause/no-op and cooldown")
	else:
		for message in failures: push_error(message)
	paused = false
	quit(0 if failures.is_empty() else 1)
