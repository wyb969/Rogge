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
	game.diagnostic_mode = "meteor_test"

	game.spawner.set_process(false)
	game.spawner.timer.stop()
	game.spawner.get_node("Elite").stop()
	game.player.set_physics_process(false)
	game.level_manager.signal_level_up.disconnect(game.on_level_up)
	for name in ["HandWeapon", "CircleWeapon", "Weapon", "DroneController", "MolotovController", "FreezeController"]:
		game.get_node(name).process_mode = Node.PROCESS_MODE_DISABLED
	var event: Node = game.meteors
	event.set_process(false)
	var at: = Vector2(2500, 1800)
	game.weather.set_process(false)
	game.weather.set_preview(0, 0)
	_expect( not event.eligible() and not event.start_shower(at), "clear daytime cannot create meteor showers")
	game.weather.set_preview(0, 0.5)
	_expect(event.eligible(), "night qualifies regardless of weather")
	game.weather.set_preview(1, 0)
	_expect(event.eligible(), "overcast daytime also qualifies")
	game.weather.set_preview(2, 0)
	_expect( not event.eligible(), "daytime rain alone does not meet the requested condition")
	game.weather.set_preview(1, 0)
	game.diagnostic_mode = "normal"
	var due: float = event._next_event
	paused = true
	event._process(20)
	_expect(event._next_event == due, "paused menus do not advance meteor scheduling")
	paused = false
	game.weather.set_preview(0, 0)
	event._process(20)
	_expect(event._next_event == due, "ineligible clear days preserve the eligible-time countdown")
	game.weather.set_preview(1, 0)
	event._next_event = 0.01
	event._process(0.02)
	_expect(event._count >= 3 and event._count <= 5, "an eligible normal run actually schedules a small shower")
	var count: int = event._count
	var age: float = event._age
	paused = true
	event._process(20)
	_expect(event._age == age and event.impacts == 0, "pending meteors freeze through reward pauses")
	paused = false
	game.spawner._boss_fight_active = true
	event._process(0.02)
	_expect(event._count == 0 and event._reward_left == 0 and not event.start_shower(at), "boss warning cancels pending impacts/rewards and blocks new showers")
	game.spawner._boss_fight_active = false
	game.spawner._mini_spawned = true
	game.spawner._mini_cleared = false
	_expect( not event.eligible() and not event.start_shower(at), "treasure-guardian combat also blocks showers")
	game.spawner._mini_spawned = false
	game.spawner._rest_open = true
	_expect( not event.eligible(), "rest does not schedule a friendly attack")
	game.spawner._rest_open = false
	game.spawner._transitioning = true
	_expect( not event.eligible(), "stage transition does not schedule an attack")
	game.spawner._transitioning = false
	game.diagnostic_mode = "meteor_test"


	game.player.add_monster_necklace_level()
	game.player.add_shield_level()
	var enemy: = _enemy(game, at)
	enemy.health = 50000
	enemy.defense = 0.75
	var outside: = _enemy(game, at + Vector2(event.RADIUS + 0.1, 0))
	outside.health = 1000
	var courier: Node = load("res://scenes/loot_courier.tscn").instantiate()
	courier.set_player_ref(game.player)
	courier.set_enemy_data(load("res://resource/LootCourier.tres"))
	game.add_child(courier)
	courier.global_position = at
	courier.set_physics_process(false)
	var courier_hp: float = courier.health
	var kills: int = game.spawner.enemy_killed_num
	var player_hp: float = game.player.player_health
	event._impact(at)
	event._impact(at)
	_expect(enemy._death_started and outside.health == 1000 and courier.health == courier_hp, "meteor kills covered wave mobs exactly, excludes outside bodies and harmless couriers")
	_expect(game.spawner.enemy_killed_num == kills + 1 and game.player.shield > 0 and game._healing_actors.size() == 1, "real death signals award one kill, the owned necklace drop and kill shield")
	_expect(game.player.player_health == player_hp, "friendly meteors never hurt the player")
	await process_frame
	_expect(game._xp_actors.size() > 0, "meteor kills retain the enemy's normal XP drop")
	outside.free()
	courier.free()
	game.clear_run_objects()
	await process_frame
	await process_frame
	game.player.monster_necklace_level = 0

	var boss: Node = load("res://scenes/beast_boss.tscn").instantiate()
	game.add_child(boss)
	boss.set_physics_process(false)
	boss.global_position = at
	boss.add_to_group("EnemyGroup")
	var boss_hp: float = boss.boss_current_health
	event._impact(at)
	_expect(boss.boss_current_health == boss_hp, "guardian targets remain excluded even at an overlapping landing point")
	boss.free()
	seed(969)
	var expected: = randi()
	seed(969)
	_expect(event.start_shower(at), "overcast test shower starts")
	_expect(randi() == expected, "event placement/reward RNG does not consume combat or loot RNG")
	_expect( not event.start_shower(at), "only one shower may exist at once")
	count = event._count
	var before_impacts: int = event.impacts
	event._process(event.WARNING + event.FALL - 0.01)
	_expect(event.impacts == before_impacts, "telegraphed falling time is harmless until actual impact")
	event._process(0.02)
	_expect(event.impacts == before_impacts + 1, "the first meteor resolves only at its landing time")
	event._reward_healing = true
	var drop_count: int = event._reward_count
	var before_drops: int = event.drops_spawned
	event._process(2)
	_expect(event.impacts == before_impacts + count and event.drops_spawned - before_drops <= 2, "all delayed meteors land once and supply creation is limited to two actors per frame")
	for _frame in 12: event._process(0.01)
	_expect(event.drops_spawned - before_drops == drop_count and drop_count >= 3 and drop_count <= 10, "one shower leaves exactly one pile of 3-10 pickups, without duplicate rewards")
	_expect(game._healing_actors.size() == drop_count and game.player.monster_necklace_level == 0, "a green supply pile works without owning the necklace")
	game.clear_run_objects()
	await process_frame
	await process_frame
	event.clear_combat_effects()
	var pool: Array = event._meteors.duplicate()
	var nodes_before: = event.get_child_count()

	for turn in 80:
		_expect(event.start_shower(at), "subsequent shower can reuse the idle event")
		event._reward_count = 10
		event._reward_healing = turn >= 60
		event._process(3)
		for _frame in 5: event._process(0)
		_expect(game._xp_actors.size() <= 256 and game._healing_actors.size() <= 96, "environmental supplies use existing bounded pickup actors")
		event.clear_combat_effects()
	var raw_xp: = 0
	for coin in game._xp_actors: raw_xp += coin.xp_value
	var healing: = 0.0
	for orb in game._healing_actors: healing += orb.heal_amount
	_expect(raw_xp == 1200 and healing == 1000, "cap consolidation preserves every meteor XP/heal reward")
	var reused: = true
	for i in pool.size(): reused = reused and is_same(pool[i], event._meteors[i])
	_expect(reused and event.get_child_count() == nodes_before and event._meteors.size() == 5, "eighty showers reuse the same five records without extra effect nodes")
	main.show_main_menu()
	_expect( not event._running and event._count == 0 and event._reward_left == 0, "return/retry clears pending meteors and supply queues")
	await main._launch_run(&"meteor")
	_expect(main.game.meteors._count >= 3 and main.game.beast_powers.unlocked.has(2), "real Debug mode starts a visible shower and equips map-wide gathering")
	main.show_main_menu()
	if failures.is_empty(): print("METEOR SHOWER OK: weather/night scheduling, pauses/boss/rest/transition gates, exact telegraphed kills and normal rewards, special-target exclusion, independent RNG, 3-10 supplies without necklace, bounded two/frame and 80 showers, Debug/reset")
	else:
		for message in failures: push_error(message)
	paused = false
	quit(0 if failures.is_empty() else 1)
func _enemy(game: Node, at: Vector2) -> Node:
	var enemy: Node = load("res://scenes/enemy_shell.tscn").instantiate()
	enemy.set_player_ref(game.player)
	enemy.set_enemy_data(load("res://resource/Enemy_1.tres"))
	enemy.add_to_group("EnemyGroup")
	enemy.death_signal.connect(game.spawner.on_enemy_killed.bind(enemy))
	game.add_child(enemy)
	enemy.global_position = at
	enemy.set_physics_process(false)
	return enemy
