extends SceneTree
var failures: Array[String] = []
var main: Node
var settings_store: Node
func _init() -> void :
	call_deferred("_run")
func _expect(ok: bool, message: String) -> void :
	if not ok: failures.append(message)
func _freeze(game: Node) -> void :
	game.level_manager.signal_level_up.disconnect(game.on_level_up)
	game.player.set_physics_process(false)
	game.player.set_process(false)
	game.spawner.set_process(false)
	game.spawner.timer.stop()
	game.spawner.get_node("Elite").stop()
	game.trials.set_process(false)
	game.lightning_ring.set_process(false)
	for name in ["HandWeapon", "CircleWeapon", "Weapon", "DroneController", "MolotovController", "FreezeController"]:
		game.get_node(name).process_mode = Node.PROCESS_MODE_DISABLED
func _launch(mode: StringName, index: int) -> Node:
	settings_store.set_difficulty(index)
	await main._launch_run(mode)
	var game: Node = main.game
	_freeze(game)
	for enemy in get_nodes_in_group("EnemyGroup"):
		enemy.set_physics_process(false)
	return game
func _run() -> void :
	settings_store = root.get_node("SettingsStore")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	for index in 3:
		main._on_setting_button_pressed()
		var settings: Node = main.settings_page
		settings.difficulty_list.get_child(index).pressed.emit()
		_expect(settings.difficulty_description.text == settings.DIFFICULTY.RULES[index], "settings explains the selected rules")
		settings_store.difficulty = 1
		settings_store.load_from_disk()
		_expect(settings_store.difficulty == index, "actual difficulty choice persists on disk")
		settings.close_page()
		var game: Node = await _launch(&"", index)
		var spawner: Node = game.spawner
		var player: Node = game.player
		var scale: float = [0.5, 1.0, 1.5][index]
		var reward: float = 1.5 if index == 0 else 1.0
		_expect(game.run_difficulty.index == index and player.healing_multiplier == reward, "run snapshots the chosen difficulty")
		_expect(player.max_player_health == 500 and player.player_health == 500, "difficulty does not change player maximum health")
		var roster: Array = spawner.enemy_array.duplicate()
		spawner.stage = 2
		spawner.current_level = 8
		spawner._stage_seconds = 20
		spawner._offense_cards = 3
		for data in roster:
			spawner.enemy_array.assign([data])
			spawner._stage_themes.clear()
			spawner._pattern_stage = -1
			var baseline: float = data.health * spawner.threat_hp_multiplier()
			if data.archetype == EnemyData.Archetype.DASHER: baseline = minf(baseline, 20)
			for elite in [false, true]:
				spawner.spawn(player.global_position + Vector2(200, 0), elite)
				var actor: Node = get_nodes_in_group("EnemyGroup")[0]
				actor.set_physics_process(false)
				var expected: float = baseline * (1.75 if elite else 1.0)
				if data.archetype == EnemyData.Archetype.DASHER: expected = minf(expected, 20)
				_expect(is_equal_approx(actor.health, expected * scale), "all normal/elite archetypes apply health difficulty after caps/growth")
				var contact: float = data.contact_damage * spawner.threat_damage_multiplier() * (1.2 if elite else 1.0)
				_expect(is_equal_approx(actor.contact_damage, contact), "difficulty changes enemy health without changing attack damage")
				game.clear_enemies()
				await process_frame
		spawner.enemy_array.assign(roster)
		spawner.stage = 3
		var guardian: Node = spawner.spawn_treasure_guardian()
		guardian.set_physics_process(false)
		var guardian_base: float = clampf(42 * spawner.threat_hp_multiplier() * 4, 240, 720)
		_expect(is_equal_approx(guardian.health, guardian_base * scale) and guardian.max_health == guardian.health, "treasure guardian HP and maximum use the same final scale")
		game.clear_enemies()
		await process_frame

		game.level_manager.level_need_coin_number = 100000
		spawner.enemy_array.assign([load("res://resource/Enemy2.tres")])
		spawner._stage_themes.clear()
		spawner._pattern_stage = -1
		for elite in [false, true]:
			spawner.spawn(player.global_position + Vector2(200, 0), elite)
			var actor: Node = get_nodes_in_group("EnemyGroup")[0]
			actor.set_physics_process(false)
			actor.take_damage(100000)
			await process_frame
			var coin: Node = game.pickup_container.get_child(0)
			var base_xp: int = 5 if elite else 2
			_expect(coin.xp_value == base_xp, "drop records its unscaled XP value")
			var before_xp: int = game.level_manager.coin_number
			coin.collect_coin()
			await create_timer(0.14).timeout
			_expect(game.level_manager.coin_number == before_xp + roundi(base_xp * reward), "normal/elite XP bonus applies exactly once on real collection")
			await process_frame
		player.player_health = 100
		_expect(player.heal(20) == 20 * reward, "direct healing uses the easy bonus once")
		game._on_upgrade_selected("monster_necklace")
		var orb: Node = game.spawn_necklace_orb(player.global_position)
		_expect(orb.heal_amount == 5 and orb.collect() == 5 * reward, "real necklace orb heals 7.5 on easy and 5 otherwise")
		if index == 0: _expect(game.pause_menu._monster_necklace_desc().contains("7.5"), "card preview explains actual easy healing growth")
		game._on_upgrade_selected("regen_up")
		player.player_health = 100
		player._regen_acc = 0
		player._tick_regen(player.regen_interval())
		_expect(is_equal_approx(player.player_health, 100 + player.regen_amount() * reward), "regen receives the same healing bonus")
		game._on_upgrade_selected("lifesteal_up")
		player.player_health = 100
		var steal: float = minf(player.lifesteal_cap_for(1), floorf(player.LIFESTEAL_FLAT + 100 * player.lifesteal_percent_for(1)))
		player.notify_damage_dealt(100)
		_expect(is_equal_approx(player.player_health, 100 + steal * reward), "life steal receives the healing bonus once after its normal cap")
		player.player_health = 100
		game.beast_powers.unlock(0)
		game.beast_powers.cast_selected()
		_expect(is_equal_approx(player.player_health, 100 + 500 * 0.45 * reward), "earned healing power restores the correct percentage")
		if index == 0: _expect(game.beast_powers.description_for(0).contains("67.5"), "blessing text reflects easy healing")
		player.heal(100000)
		_expect(player.player_health == 500 and player.heal(5) == 0, "healing cannot overflow maximum health")
		player.player_health = 0
		_expect(player.heal(100) == 0 and player.player_health == 0, "healing cannot revive dead players")
		player.player_health = 100
		settings_store.set_difficulty((index + 1) % 3)
		_expect(game.run_difficulty.index == index and player.heal(10) == 10 * reward, "mid-run preference changes cannot change this run's rewards")
		spawner._pattern_stage = -1
		spawner.spawn(player.global_position + Vector2(200, 0), false)
		var later_actor: Node = get_nodes_in_group("EnemyGroup")[0]
		later_actor.set_physics_process(false)
		_expect(is_equal_approx(later_actor.health, 42 * spawner.threat_hp_multiplier() * scale), "later enemies keep the initial difficulty snapshot")
		_expect(game._build_run_stats(false).difficulty == index, "run statistics keep the actual run difficulty")

		for stage_num in range(1, 7):
			var mode: StringName = &"" if stage_num == 1 else (&"knight" if stage_num == 2 else StringName("beast_%d" % stage_num))
			game = await _launch(mode, index)
			if stage_num == 1: game.spawner.spawn_boss()
			var bosses: Array = get_nodes_in_group("EnemyGroup").filter( func(node): return node.has_signal("boss_defeated"))
			_expect(bosses.size() == (2 if stage_num == 5 else 1), "real boss entry has the correct encounter size")
			for boss in bosses:
				var base: float = [0, 2000, 3200, 3600, 4200, 4800, 5600][stage_num]
				if stage_num == 5: base = 2200 if boss.role == 0 else 2600
				_expect(boss.health_max_value == base * scale and boss.boss_current_health == base * scale and boss.health_bar.max_value == base * scale, "all boss types and HUD maximums scale once")
				boss.apply_difficulty_health(scale)
				_expect(boss.health_max_value == base * scale, "repeated initialization cannot double-scale boss HP")
				boss.last_hitstop_msec = Time.get_ticks_msec()
				boss.apply_hit({"damage": base * scale * 0.51, "from_status": true, "ignore_side_bonus": true})
				if stage_num >= 2: _expect(boss.phase == 2, "half-health phases use scaled maximum HP")
			Engine.time_scale = 1
		for kind in ["power", "speed"]:
			game = await _launch(StringName("trial_" + kind), index)
			game.trials.start_button.pressed.emit()
			var base: float = 5000 if kind == "power" else 2600
			_expect(game.trials.enemy.health_max_value == base * scale, "both trial encounters inherit difficulty")
			game.trials.fail("测试重试")
			settings_store.set_difficulty((index + 1) % 3)
			game.trials.retry_button.pressed.emit()
			_expect(game.trials.enemy.health_max_value == base * scale, "trial retry preserves the run snapshot without stacking HP scales")
	settings_store.set_difficulty(settings_store.DIFF_MEDIUM)
	paused = false
	Engine.time_scale = 1
	if failures.is_empty(): print("DIFFICULTY OK: real settings, all archetypes/elites/guardian/bosses/trials, scaled phases/HUD, XP collection, healing sources/previews, capped healing and frozen run snapshot")
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
