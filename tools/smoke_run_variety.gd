extends SceneTree
var failures: Array[String] = []
var main: Node
func _init() -> void :
	call_deferred("_run")
func _expect(ok: bool, message: String) -> void :
	if not ok: failures.append(message)
func _fixture() -> Node:
	await main._launch_run(&"")
	var game: Node = main.game
	game.spawner.timer.stop()
	game.spawner.get_node("Elite").stop()
	game.spawner.set_process(false)
	game.player.set_physics_process(false)
	game.variety.set_process(false)
	game.level_manager.signal_level_up.disconnect(game.on_level_up)
	for name in ["HandWeapon", "CircleWeapon", "Weapon", "DroneController", "MolotovController", "FreezeController"]:
		game.get_node(name).process_mode = Node.PROCESS_MODE_DISABLED
	return game
func _enemy(game: Node, at: Vector2, hp: float = 1000) -> Node2D:
	var actor: Node2D = load("res://scenes/enemy_shell.tscn").instantiate()
	actor.set_player_ref(game.player)
	actor.set_enemy_data(load("res://resource/Enemy_1.tres"))
	actor.add_to_group("EnemyGroup")
	actor.health = hp
	actor.defense = 0.2
	actor.death_signal.connect(game.spawner.on_enemy_killed.bind(actor))
	game.add_child(actor)
	actor.global_position = at
	actor.set_physics_process(false)
	return actor
func _entry(menu: Node, id: String) -> Dictionary:
	for item in menu.upgrade_pool:
		if item.id == id: return item
	return {}
func _run() -> void :
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	var game: Node = await _fixture()
	var variety: Node = game.variety
	var menu: Node = game.pause_menu
	var pool: Array = menu.upgrade_pool.duplicate()
	var near: Node = _enemy(game, Vector2(150, 0))
	var far: Node = _enemy(game, Vector2(251, 0))
	variety.on_dash_completed(Vector2(150, 0))
	_expect(near.health == 1000 and variety.pulses_cast == 0, "unowned cards cannot create attacks")
	menu.upgrade_pool = [_entry(menu, "wind_emblem")]
	menu.show_upgrade_options()
	var card: Node = menu.h_box_container.get_child(0)
	_expect(card.icon.texture != null and card.desc_label.text.contains("32") and card.desc_label.text.contains("100"), "real wind card has original art and next-rank stats")
	card.selected.emit("wind_emblem")
	_expect(variety.wind_level == 1 and game.equipment_panel.get_level("wind_emblem") == 1 and game.spawner._offense_cards == 1, "normal selection synchronizes gameplay, HUD and pressure")
	menu.on_card_selected("wind_emblem")
	_expect(variety.wind_level == 1, "duplicate selection after closing cannot award a second card")
	menu.upgrade_pool = pool
	game.player._start_dash(Vector2.RIGHT)
	game.player.global_position = Vector2(150, 0)
	game.player._on_dashing_timer_timeout()
	_expect(is_equal_approx(near.health, 974.4) and far.health == 1000, "actual dash completion hits one time at its landing radius through mitigation")
	_expect(game.player.dash_grace_left == 0.5 and variety.pulses_cast == 1, "wind preserves the post-dash invulnerability window")
	game.player._on_dashing_timer_timeout()
	_expect(variety.pulses_cast == 1, "duplicate timer completion cannot fire a second pulse")
	game.player._start_dash(Vector2.LEFT)
	game.player.reset_dash()
	game.player._on_dashing_timer_timeout()
	_expect(variety.pulses_cast == 1, "cancelled/interlude dashes do not attack")
	game._on_upgrade_selected("wind_emblem")
	var data: Dictionary = menu._build_card_data(_entry(menu, "wind_emblem"))
	_expect(data.desc.contains("64") and data.desc.contains("116"), "description follows the next wind upgrade rather than stale cached stats")
	game.spawner._rest_open = true
	variety.on_dash_completed(near.global_position)
	_expect(variety.pulses_cast == 1, "rest screens cannot farm landing attacks")
	game.spawner._rest_open = false
	game.clear_enemies()
	await process_frame
	game._on_upgrade_selected("echo_ember")
	var target: Node = _enemy(game, Vector2(400, 0))
	for i in 8:
		var victim: Node = _enemy(game, Vector2(400, 0), 1)
		victim.apply_hit({"damage": 5})
		_expect(variety.echo_charge == ((i + 1) % 8), "actual weapon kills charge exactly once each")
	_expect(variety._pending_echoes.size() == 1 and target.health == 1000, "eighth kill queues one pulse outside the collision callback")
	paused = true
	variety._process(10)
	_expect(variety._pending_echoes.size() == 1 and target.health == 1000, "earned echo is retained across card pauses without dealing damage")
	paused = false
	variety._process(0.01)
	_expect(is_equal_approx(target.health, 968) and variety._pending_echoes.is_empty(), "resumed echo hits once through the actual mitigation pipeline")
	target.health = 1
	variety.echo_charge = 7
	var victim: Node = _enemy(game, Vector2(400, 0), 1)
	victim.apply_hit({"damage": 5})
	variety._process(0.01)
	_expect(target._death_started and variety.echo_charge == 0 and variety._pending_echoes.is_empty(), "echo kills still grant rewards but cannot recharge their own explosion")
	variety.echo_charge = 7
	victim = _enemy(game, Vector2(400, 0), 1)
	victim.apply_hit({"damage": 5})
	variety.clear_combat_effects()
	_expect(variety._pending_echoes.is_empty(), "interludes cancel old queued impacts")
	game._on_treasure_claimed("echo_ember", 3)
	_expect(variety.echo_level == 4 and game.equipment_panel.get_level("echo_ember") == 4 and variety.echo_stats(4).kills == 5, "treasure multi-rank reward applies every real stack and bounded cadence")

	seed(194)
	var expected: = randi()
	seed(194)
	var seen: = {}
	for _i in 300:
		var options: Array = menu._draw_upgrades(3)
		var ids: = {}
		var owned: = false
		var discovery: = false
		for option in options:
			ids[option.id] = true
			seen[option.id] = true
			if game.equipment_panel.get_level(option.id) > 0: owned = true
			else: discovery = true
		_expect(ids.size() == 3 and owned and discovery, "draft offers distinct progress and discovery when both exist")
	_expect(seen.size() == pool.size() and randi() == expected, "every card remains reachable and offer RNG cannot disturb combat/loot RNG")
	menu.show_upgrade_options()
	var old: Array = menu._offered.duplicate()
	var wind_rank: int = variety.wind_level
	menu.reroll_button.pressed.emit()
	_expect(menu.rerolls == 1 and paused and menu.visible and variety.wind_level == wind_rank, "real reroll consumes one token without granting a card or unpausing")
	for id in old: _expect(id not in menu._offered, "a full-pool reroll avoids all three old choices")
	menu.reroll_button.pressed.emit()
	var second: Array = menu._offered.duplicate()
	menu.reroll_button.pressed.emit()
	_expect(menu.rerolls == 0 and menu.reroll_button.disabled and menu._offered == second, "exhausted rerolls cannot reroll again")
	menu.visible = false
	paused = false
	menu.upgrade_pool = [pool[0]]
	_expect(menu._draw_upgrades(3, [pool[0].id]).size() == 1, "tiny custom/debug pools remain valid and do not duplicate choices")
	menu.upgrade_pool = pool
	game.clear_enemies()
	await process_frame


	variety.echo_level = 1
	variety.echo_charge = 0
	for _i in 7:
		var charge_victim: Node = _enemy(game, Vector2(520, 30), 1)
		charge_victim.apply_hit({"damage": 5})
	paused = true
	variety.upgrade("echo_ember")
	_expect(variety.echo_charge == 0 and variety._pending_echoes.size() == 1 and variety._pending_echoes[0] == Vector2(520, 30), "threshold-lowering upgrades cash out earned charge once at the last kill position")
	var before_upgrade_pulse: int = variety.pulses_cast
	variety._process(1)
	_expect(variety.pulses_cast == before_upgrade_pulse, "threshold-upgrade pulses wait through the choice pause")
	paused = false
	variety._process(0.01)
	_expect(variety.pulses_cast == before_upgrade_pulse + 1 and variety._pending_echoes.is_empty(), "upgrade-completed charge releases once on resume")
	variety.echo_level = 4
	await process_frame

	game.clear_run_objects()
	await process_frame
	var courier: Node = variety.spawn_courier()
	_expect(courier != null and variety.spawn_courier() == null, "only one optional courier can be alive")
	_expect(is_equal_approx(courier.health, 52 * (1 + 0.03 * game.current_level) * game.run_difficulty.health_scale), "courier starts with the stage/level/difficulty-adjusted HP")
	courier.set_physics_process(false)
	var before: float = game.player.player_health
	courier.global_position = game.player.global_position + Vector2(30, 0)
	courier.age = 1
	courier._physics_process(0.1)
	_expect(courier.velocity.dot(courier.global_position - game.player.global_position) > 0 and courier.speed < 100 and game.player.player_health == before, "courier flees below base run speed without contact damage")
	courier.apply_freeze({"freeze_duration": 2, "slow_factor": 0.3})
	courier._physics_process(0.01)
	_expect(courier.velocity.length() < 30, "freeze builds can intercept the fleeing target")
	var kills: int = game.spawner.enemy_killed_num
	courier.apply_hit({"damage": 10000})
	courier.apply_hit({"damage": 10000})
	_expect(variety.couriers_defeated == 1 and menu.rerolls == 1 and game.spawner.enemy_killed_num == kills + 1, "courier grants exactly one token, one defeat and one kill reward")
	await process_frame
	_expect(game._xp_actors.size() == 1 and game._xp_actors[0].xp_value == 18, "courier XP uses the normal bounded pickup pipeline")
	courier = variety.spawn_courier()
	courier.set_physics_process(false)
	menu.rerolls = menu.MAX_REROLLS
	courier.apply_hit({"damage": 10000})
	await process_frame
	_expect(menu.rerolls == 3 and game._xp_actors.back().xp_value == 26, "full token storage converts bonus to XP without losing the reward")
	courier = variety.spawn_courier()
	courier.set_physics_process(false)
	courier.age = courier.LIFETIME - 0.01
	courier._physics_process(0.02)
	_expect(courier.is_queued_for_deletion() and variety.couriers_defeated == 2, "escape despawns without kill rewards")
	await process_frame
	var snapshot: RefCounted = game.run_difficulty
	for difficulty in [0, 2]:
		game.run_difficulty = game.RUN_DIFFICULTY.new(difficulty)
		courier = variety.spawn_courier()
		_expect(is_equal_approx(courier.health, 52 * (1 + 0.03 * game.current_level) * game.run_difficulty.health_scale), "optional courier honors easy/hard HP without normal threat-spiral inflation")
		courier.queue_free()
		await process_frame
	game.run_difficulty = snapshot
	game.spawner._boss_fight_active = true
	_expect(variety.spawn_courier() == null, "bosses cannot spawn pursuit distractions")
	game.spawner._boss_fight_active = false
	game.trials.flow = game.trials.TrialFlow.INTRO
	_expect(variety.spawn_courier() == null, "trial intro cannot spawn pursuit targets")
	game.trials.reset()
	game.spawner.debug_start_beast(3)
	var boss: Node = game.spawner._active_bosses[0]
	boss.set_physics_process(false)
	boss.last_hitstop_msec = Time.get_ticks_msec() + 100000
	var boss_hp: float = boss.boss_current_health
	variety.on_dash_completed(boss.global_position)
	_expect(boss.boss_current_health < boss_hp, "landing pulses retain actual guardian mitigation/HP routing during a boss fight")
	game.clear_enemies()
	await process_frame
	game.spawner._active_bosses.clear()
	game.spawner._boss_fight_active = false
	game.trials.begin("power")
	game.trials.start_attempt()
	var trial_actor: Node = game.trials.enemy
	trial_actor.set_physics_process(false)
	var trial_hp: float = trial_actor.boss_current_health
	variety.on_dash_completed(trial_actor.global_position)
	_expect(trial_actor.boss_current_health < trial_hp, "new cards stay active during real trial combat")
	game.trials.reset()
	game.spawner._boss_fight_active = false
	game.spawner._rest_open = false
	game.diagnostic_mode = "variety"
	variety._courier_left = 0.01
	paused = true
	variety._process(1)
	_expect(variety._courier_left == 0.01, "optional event countdown freezes on paused pages")
	paused = false
	variety._process(0.02)
	_expect(get_nodes_in_group("loot_courier").size() == 1 and variety._courier_left >= 48, "normal combat schedules a bounded optional pursuit with a long random gap")

	for _i in 100: variety.on_dash_completed(Vector2(1000, 1000))
	_expect(variety._pulses.size() == 8 and variety.get_child_count() == 1, "pulse storms reuse eight records and allocate no per-cast nodes")
	for id in game.equipment_panel.EQUIP_DEFS:
		if game.equipment_panel.get_level(id) == 0: game.equipment_panel.apply_upgrade(id)
	for size in [Vector2i(390, 844), Vector2i(1920, 1080), Vector2i(900, 500)]:
		root.size = size
		await process_frame
		await process_frame
		menu.show_upgrade_options()
		var vp: = root.get_visible_rect().size
		_expect(Rect2(Vector2.ZERO, vp).encloses(menu.reroll_button.get_global_rect()), "reroll remains inside both orientations")
		for slot in game.equipment_panel._slots.values():
			_expect(Rect2(Vector2.ZERO, vp).encloses(slot.root.get_global_rect()), "all acquired equipment remains inside the screen")
		menu.visible = false
		paused = false
	main.on_game_over({"victory": false})
	await main._on_game_end_ui_retry_pressed()
	_expect(main.game.variety.wind_level == 0 and main.game.variety.echo_level == 0 and main.game.pause_menu.rerolls == 2 and main.game.variety._pending_echoes.is_empty(), "Retry starts with new cards, pulse history and reroll state cleared")
	main.show_main_menu()
	if failures.is_empty(): print("RUN VARIETY OK: real wind/echo cards, landing damage/grace/cancel, exact queued pause-safe nonrecursive echo, lottery stacks, diverse independent draws, reroll UI/tokens, harmless bounded courier/rewards/escape, full HUD layout and Retry")
	else:
		for failure in failures: push_error(failure)
	paused = false
	quit(0 if failures.is_empty() else 1)
