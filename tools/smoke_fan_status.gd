extends SceneTree

var failures: Array[String] = []
var main: Node
var game: Node
var fan: Node
const BUDGET := preload("res://script/feedback_budget.gd")

func _init() -> void: call_deferred("_run")
func _expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _isolate() -> void:
	game.spawner.timer.stop()
	game.spawner.get_node("Elite").stop()
	game.spawner.set_process(false)
	game.player.set_physics_process(false)
	game.player.global_position = Vector2.ZERO
	game.player.last_move_direction = Vector2.RIGHT
	game.weather.stop()
	game.variety._courier_left = 99999
	game.poison_trail.set_process(false)
	fan.set_physics_process(false)
	for name in ["HandWeapon", "CircleWeapon", "Weapon", "DroneController", "MolotovController", "FreezeController"]:
		game.get_node(name).process_mode = Node.PROCESS_MODE_DISABLED

func _enemy(at: Vector2, hp: float = 1000.0) -> Node:
	var actor: Node = load("res://scenes/enemy_shell.tscn").instantiate()
	actor.set_player_ref(game.player)
	actor.set_enemy_data(load("res://resource/Enemy_1.tres"))
	actor.health = hp
	actor.defense = 0.0
	actor.add_to_group("EnemyGroup")
	actor.death_signal.connect(game.spawner.on_enemy_killed.bind(actor))
	game.add_child(actor)
	actor.global_position = at
	actor.set_physics_process(false)
	return actor

func _cloud(at: Vector2) -> void:
	game.poison_trail._clouds[0].at = at
	game.poison_trail._clouds[0].left = 4.0
	game.poison_trail._scan(0.0)

func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	await main._launch_run(&"")
	game = main.game
	fan = game.banana_fan
	_isolate()
	game._on_upgrade_selected("banana_fan")
	game._on_upgrade_selected("poison_trail")
	_isolate()
	var crowd: Array[Node] = []
	for i in 20:
		var actor: Node = _enemy(Vector2(90 + (i % 4) * 6, -12 + int(i / 4) * 6))
		actor.apply_burn({"burn_stacks": 3, "burn_dps": 4.0})
		actor.burn_tick = 0.17
		crowd.append(actor)
	_cloud(Vector2(99, 0))
	for actor in crowd: game.poison_trail._exposed[actor.get_instance_id()].dose = 0.31
	var cold: Node = _enemy(Vector2(75, 42))
	var behind: Node = _enemy(Vector2(-40, 0))
	seed(329)
	var expected_random := randi()
	seed(329)
	_expect(fan.cast(), "fan starts a real crowd cast")
	fan._physics_process(0.52)
	_expect(fan.hits == 21 and fan.status_echoes == 20, "twenty overlapping burning/poisoned targets each produce exactly one combined status hit")
	for actor in crowd:
		_expect(is_equal_approx(actor.health, 977.6), "each crowd target receives 12 wind + 5.4 burn + 5 poison, without neighbor multiplication")
		_expect(actor.burn_stacks == 3 and actor.burn_tick == 0.17 and is_equal_approx(game.poison_trail._exposed[actor.get_instance_id()].dose, 0.31), "extra ticks preserve stacks and both natural damage clocks")
	_expect(cold.health == 988 and cold.burn_stacks == 0 and behind.health == 1000 and game.burn_spread._count == 0, "extra ticks neither ignite clean targets nor enqueue a spread/explosion")
	_expect(randi() == expected_random, "status replay consumes no global proc/spread randomness")
	for _i in 8: fan._scan_gust()
	_expect(fan.status_echoes == 20 and is_equal_approx(crowd[0].health, 977.6), "repeated range scans cannot hit the center enemy again")
	var target: Node = crowd[0]
	target.defense = 0.25
	target.freeze_time = 1.0
	game.freeze_controller.level = 1
	game.player.left_fist_level = 1
	game.player.global_position.x = 200
	for _i in 5: game.player.add_critical_glasses_level()
	game.player.lifesteal_level = 4
	game.player.player_health = 300
	game.molotov_controller.level = 8
	var amount: float = target.get_status_echo_damage(5.0)
	_expect(is_equal_approx(amount, 9.9), "replay preserves distinct burn and poison mitigation plus poison's side/frozen bonuses")
	var hp: float = target.health
	var crit_state: int = game.player._critical_rng.state
	BUDGET._frame = -1
	BUDGET._tokens = 36
	BUDGET._stamp = Time.get_ticks_msec()
	target.apply_hit({"damage": amount, "effect": "fan_status_bonus", "from_status": true, "damage_is_final": true})
	var popup: Node = game.effect_container.get_children().back()
	_expect(is_equal_approx(hp - target.health, 9.9) and game.player.player_health == 300 and game.player._critical_rng.state == crit_state, "combined replay does not double-mitigate, crit or lifesteal")
	_expect(popup._status and not popup._critical and target.burn_stacks == 3 and target.freeze_time == 1.0, "replay is one status popup and cannot reapply burn/freeze")
	game.player.left_fist_level = 0
	game.player.reset_critical_glasses()
	game.player.lifesteal_level = 0
	game.freeze_controller.level = 0
	game.molotov_controller.level = 0
	target.freeze_time = 0
	for value in 100:
		seed(value)
		if randf() <= 0.4:
			seed(value)
			break
	target._update_statuses(0.29)
	_expect(target.burn_stacks == 2 and game.burn_spread._count == 1, "the original timed burn still consumes a layer and can spread normally")
	game.variety.clear_combat_effects()
	game.clear_enemies()
	await process_frame
	game.player.global_position = Vector2.ZERO
	var fresh: Node = _enemy(Vector2(95, 0))
	game.molotov_controller.level = 8
	for value in 100:
		seed(value)
		if randf() < 0.65:
			seed(value)
			break
	var echo_before: int = fan.status_echoes
	fan.cast()
	fan._physics_process(0.52)
	_expect(fresh.burn_stacks > 0 and fresh.health == 988 and fan.status_echoes == echo_before, "statuses newly added by the direct hit cannot feed its own snapshot")
	game.molotov_controller.level = 0
	game.variety.clear_combat_effects()
	game.clear_enemies()
	await process_frame
	game._on_upgrade_selected("monster_necklace")
	var victim: Node = _enemy(Vector2(95, 0), 15)
	victim.apply_burn({"burn_stacks": 3, "burn_dps": 4.0})
	var kills: int = game.spawner.enemy_killed_num
	fan.cast()
	fan._physics_process(0.52)
	_expect(victim._death_started and game.spawner.enemy_killed_num == kills + 1 and get_nodes_in_group("healing_orb").size() == 1, "an extra tick kill grants kill/necklace rewards once")
	game.variety.clear_combat_effects()
	game.clear_enemies()
	await process_frame
	var dummy: Node = _enemy(Vector2(95, 0), 100000)
	for rank in range(1, 6):
		fan.reset()
		for _i in rank: fan.upgrade()
		fan.set_physics_process(false)
		_expect(is_equal_approx(fan._stats.damage, 12 + 4 * (rank - 1)) and is_equal_approx(fan._stats.range, 130 + 25 * (rank - 1)), "damage/range remain unchanged at every rank")
		var expected: float = [3.0, 2.4, 1.92, 1.536, 1.2288][rank - 1]
		_expect(is_equal_approx(fan._stats.interval, expected), "each rank multiplies the previous cooldown by 80 percent")
		fan.cast()
		var elapsed := 0.0
		while fan.casts < 2 and elapsed < 4:
			fan._physics_process(0.01)
			elapsed += 0.01
		_expect(absf(elapsed - expected) <= 0.011, "real automatic casts follow each rank's cooldown")
	var remaining: float = fan._cooldown
	paused = true
	fan._physics_process(20)
	_expect(fan._cooldown == remaining, "pause freezes the shorter cooldown")
	paused = false
	game.variety.clear_combat_effects()
	game.clear_enemies()
	await process_frame
	game.spawner.debug_start_beast(3)
	var boss: Node = game.spawner._active_bosses[0]
	boss.set_physics_process(false)
	boss.last_hitstop_msec = Time.get_ticks_msec() + 100000
	game.player.global_position = boss.global_position - Vector2(95, 0)
	_cloud(boss.global_position)
	hp = boss.boss_current_health
	fan.cast()
	fan._physics_process(0.52)
	_expect(boss.boss_current_health == hp - 33, "Boss poison gets one extra tick alongside rank-five wind damage")
	game.variety.clear_combat_effects()
	game.clear_enemies()
	await process_frame
	game.spawner._active_bosses.clear()
	game.spawner._boss_fight_active = false
	game.trials.begin("speed")
	game.trials.start_attempt()
	var wizard: Node = game.trials.enemy
	wizard.set_physics_process(false)
	wizard.last_hitstop_msec = Time.get_ticks_msec() + 100000
	game.player.global_position = wizard.global_position - Vector2(95, 0)
	hp = wizard.boss_current_health
	wizard.apply_hit({"damage": 50.0, "effect": "fan_status_bonus", "from_status": true, "damage_is_final": true})
	_expect(not fan.cast() and wizard.boss_current_health == hp, "final status damage and fan targeting both respect the speed-trial shield")
	wizard.trial_state = wizard.TrialState.RECOVER
	wizard._exposed = true
	_cloud(wizard.global_position)
	fan.cast()
	fan._physics_process(0.52)
	_expect(wizard.boss_current_health == hp - 33, "the exposed wizard takes one fan hit plus one poison replay")
	main.show_main_menu()
	await main._launch_run(&"fan_status")
	game = main.game
	fan = game.banana_fan
	_isolate()
	_expect(fan.level == 5 and game.poison_trail.level == 1 and game.molotov_controller.level == 1, "status Debug entry equips the actual combination")
	main.on_game_over({"victory": false})
	main.game_end_ui.retry_pressed.emit()
	for _i in 8: await process_frame
	_expect(main._test_mode == &"fan_status" and main.game.banana_fan.level == 5, "Retry restores the status test without stacking cards")
	main.show_main_menu()
	await main._launch_run(&"")
	_expect(main.game.banana_fan.level == 0 and main.game.poison_trail.level == 0, "normal runs do not inherit the status test")
	main.show_main_menu()
	if failures.is_empty(): print("FAN STATUS OK: exact crowd deduplication, snapshot-only burn/poison replay, unchanged clocks/natural spread, one popup, no recursive procs/crit/lifesteal, rewards, five real cooldowns, Boss and Debug lifecycle")
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
