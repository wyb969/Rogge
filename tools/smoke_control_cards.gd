extends SceneTree

var failures: Array[String] = []
var main: Node

func _init() -> void: call_deferred("_run")

func _expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _isolate(game: Node) -> void:
	game.spawner.timer.stop()
	game.spawner.get_node("Elite").stop()
	game.spawner.set_process(false)
	game.player.set_physics_process(false)
	game.banana_fan.set_physics_process(false)
	game.black_hole.set_physics_process(false)
	game.weather.stop()
	game.variety._courier_left = 99999
	if game.level_manager.signal_level_up.is_connected(game.on_level_up):
		game.level_manager.signal_level_up.disconnect(game.on_level_up)
	for name in ["HandWeapon", "CircleWeapon", "Weapon", "DroneController", "MolotovController", "FreezeController"]:
		game.get_node(name).process_mode = Node.PROCESS_MODE_DISABLED

func _enemy(game: Node, at: Vector2, hp: float = 1000.0) -> Node:
	var actor: Node = load("res://scenes/enemy_shell.tscn").instantiate()
	actor.set_player_ref(game.player)
	actor.set_enemy_data(load("res://resource/Enemy_1.tres"))
	actor.health = hp
	actor.defense = 0.0
	actor.collision_mask = 0
	actor.add_to_group("EnemyGroup")
	actor.death_signal.connect(game.spawner.on_enemy_killed.bind(actor))
	game.add_child(actor)
	actor.global_position = at
	actor.set_physics_process(false)
	return actor

func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	await main._launch_run(&"")
	var game: Node = main.game
	_isolate(game)
	var fan: Node = game.banana_fan
	var hole: Node = game.black_hole
	_expect(not fan.cast() and not hole.cast(), "unowned control cards cannot attack")
	var menu: Node = game.pause_menu
	var pool: Array = menu.upgrade_pool.duplicate()
	var entries: Dictionary = {}
	for entry in pool:
		if entry.id in ["banana_fan", "black_hole"]: entries[entry.id] = entry
	_expect(entries.size() == 2, "both cards are in ordinary drafts and treasure rewards")
	for id in ["banana_fan", "black_hole"]:
		menu.upgrade_pool = [entries[id]]
		menu.show_upgrade_options()
		var card: Node = menu.h_box_container.get_child(0)
		_expect(card.icon.texture != null and card.desc_label.text.contains("130" if id == "banana_fan" else "70"), "real card icon and rank-one stats are rendered")
		card.selected.emit(id)
	_expect(fan.level == 1 and hole.level == 1 and game.equipment_panel.get_level("banana_fan") == 1 and game.equipment_panel.get_level("black_hole") == 1 and game.spawner._offense_cards == 2, "real selections synchronize controllers, HUD and offense balance")
	_isolate(game)
	menu.upgrade_pool = [entries.banana_fan, entries.black_hole, pool.back()]
	for viewport_size in [Vector2i(390, 844), Vector2i(1920, 1080)]:
		root.size = viewport_size
		menu.show_upgrade_options()
		for _i in 5: await process_frame
		for card in menu.h_box_container.get_children():
			_expect(card.desc_label.get_global_rect().end.y < menu.reroll_button.get_global_rect().position.y, "new card text fits above rerolls on phone and desktop")
	menu.visible = false
	menu.upgrade_pool = pool
	paused = false
	game.player.global_position = Vector2.ZERO
	game.player.last_move_direction = Vector2.RIGHT
	var front: Node = _enemy(game, Vector2(95, 0))
	var side: Node = _enemy(game, Vector2(50, 100))
	var behind: Node = _enemy(game, Vector2(-70, 0))
	var far: Node = _enemy(game, Vector2(220, 0))
	_expect(fan.cast(), "fan casts toward an eligible forward target")
	for _i in 15: fan._physics_process(0.04)
	_expect(front.health == 988 and side.health == 1000 and behind.health == 1000 and far.health == 1000, "travelling cone deals one hit and excludes sides, rear and distant targets")
	_expect(front._airflow_left > 0 and front._airflow_velocity.x > 0, "fan applies real outward movement")
	front.speed = 0
	var before: Vector2 = front.global_position
	front._physics_process(0.1)
	_expect(front.global_position.x > before.x + 10, "enemy body moves, rather than only its sprite recoiling")
	var displacement: Array[float] = []
	for step in [1.0 / 30.0, 1.0 / 60.0, 1.0 / 120.0]:
		front.global_position = Vector2(95, 0)
		front.knockback = Vector2.ZERO
		front.apply_airflow(Vector2(300, 0), 0.36)
		for _i in int(round(0.6 / step)): front._physics_process(step)
		displacement.append(front.global_position.x - 95)
	_expect(absf(displacement[0] - displacement[2]) < 0.1 and displacement[0] > 45, "push distance remains stable at 30, 60 and 120 physics steps")
	front.archetype = EnemyData.Archetype.DASHER
	front.is_dashing = true
	front.dash_time_left = 0.2
	front.apply_airflow(Vector2(300, 0), 0.36)
	_expect(not front.is_dashing and front.dash_windup == 0 and front.dash_timer >= 0.75, "fan interrupts a small charging enemy and prevents an immediate follow-up dash")
	front.archetype = EnemyData.Archetype.CHASER
	front.body_scale = 2.0
	front.apply_airflow(Vector2(300, 0), 0.36)
	_expect(front._airflow_velocity.length() < 150, "heavy enemies resist displacement")
	for heading in [Vector2.UP, Vector2.LEFT, Vector2.DOWN, Vector2(-1, 1).normalized()]:
		fan.clear_combat_effects()
		game.player.last_move_direction = heading
		var target: Node = _enemy(game, heading * 90.0)
		_expect(fan.cast(), "fan casts in each movement direction")
		fan._physics_process(0.52)
		_expect(target.health == 988 and fan._direction.is_equal_approx(heading), "fan respects vertical, left and diagonal headings")
	game.player.dashing = true
	game.player.dash_direction = Vector2.UP
	_expect(fan.aim_direction() == Vector2.UP, "an active dash supplies its real direction")
	game.player.dashing = false
	game.player.last_move_direction = Vector2.LEFT
	_expect(fan.aim_direction() == Vector2.LEFT, "standing still retains the last movement heading")
	fan.clear_combat_effects()
	game.clear_enemies()
	await process_frame
	var anchor: Node = _enemy(game, Vector2(150, 0))
	var pulled: Node = _enemy(game, Vector2(175, 35))
	var outside: Node = _enemy(game, Vector2(150, 95))
	_expect(hole.cast() and hole._center == anchor.global_position, "black hole opens on a nearby enemy")
	hole._physics_process(1.0)
	_expect(anchor.health == 994 and pulled.health == 994 and outside.health == 1000, "black hole deals six damage per second only inside its radius")
	pulled.speed = 0.0
	var old_distance: float = pulled.global_position.distance_to(hole._center)
	pulled._physics_process(1.0 / 60.0)
	_expect(pulled.global_position.distance_to(hole._center) < old_distance, "black hole pulls the actual enemy body toward its center")
	pulled.global_position = Vector2(400, 0)
	hole._scan(0.05)
	_expect(pulled._gravity_left == 0 and pulled.get_instance_id() not in hole._exposed, "leaving the hole promptly releases pull and partial damage exposure")
	for step in [0.05, 0.25, 1.0]:
		hole.clear_combat_effects()
		anchor.health = 1000
		_expect(hole.cast(), "black hole can start a fresh isolated cast")
		for _i in int(round(3.0 / step)): hole._physics_process(step)
		_expect(anchor.health == 982 and hole._left == 0 and hole._exposed.is_empty() and anchor._gravity_left == 0, "three-second duration delivers exactly three ticks and releases all force across frame steps")
	hole.cast()
	hole._physics_process(0.5)
	var lifetime: float = hole._left
	var hp: float = anchor.health
	paused = true
	hole._physics_process(20)
	fan._physics_process(20)
	_expect(hole._left == lifetime and anchor.health == hp, "upgrade pauses freeze lifetime, cooldowns, damage and motion")
	paused = false
	game.molotov_controller.level = 8
	game.freeze_controller.level = 8
	game.player.lifesteal_level = 4
	game.player.player_health = 300
	seed(969)
	var expected_random := randi()
	seed(969)
	hole._physics_process(0.5)
	_expect(randi() == expected_random and anchor.burn_stacks == 0 and anchor.freeze_time == 0 and game.player.player_health == 300, "black-hole ticks do not recursively proc burning, freezing or lifesteal")
	game.molotov_controller.level = 0
	game.freeze_controller.level = 0
	game.player.lifesteal_level = 0
	game._on_upgrade_selected("monster_necklace")
	anchor.health = 1
	var kills: int = game.spawner.enemy_killed_num
	hole._physics_process(1.0)
	_expect(anchor._death_started and game.spawner.enemy_killed_num == kills + 1 and get_nodes_in_group("healing_orb").size() == 1, "black-hole kills grant normal kill and necklace rewards once")
	game.variety.clear_combat_effects()
	_expect(hole._left == 0 and hole._exposed.is_empty() and fan._hit_ids.is_empty() and fan.level == 1, "stage transitions remove visual and movement effects without losing cards")
	game.clear_enemies()
	await process_frame
	game.spawner.debug_start_beast(3)
	var boss: Node = game.spawner._active_bosses[0]
	boss.set_physics_process(false)
	boss.last_hitstop_msec = Time.get_ticks_msec() + 100000
	game.player.global_position = boss.global_position - Vector2(95, 0)
	game.player.last_move_direction = Vector2.RIGHT
	var boss_position: Vector2 = boss.global_position
	var boss_hp: float = boss.boss_current_health
	fan.cast()
	fan._physics_process(0.52)
	hole.cast()
	hole._physics_process(1.0)
	_expect(boss.boss_current_health == boss_hp - 18 and boss.global_position == boss_position, "guardian receives fan and black-hole damage but cannot be displaced out of its telegraphs")
	game.variety.clear_combat_effects()
	game.clear_enemies()
	await process_frame
	game.spawner._active_bosses.clear()
	game.spawner._boss_fight_active = false
	game.trials.begin("speed")
	game.trials.start_attempt()
	var wizard: Node = game.trials.enemy
	wizard.set_physics_process(false)
	game.player.global_position = wizard.global_position - Vector2(95, 0)
	var protected_hp: float = wizard.boss_current_health
	fan.cast()
	fan._physics_process(0.52)
	hole.cast()
	hole._physics_process(1.0)
	_expect(wizard.boss_current_health == protected_hp, "new cards cannot bypass the speed trial's invulnerable window")
	wizard.trial_state = wizard.TrialState.RECOVER
	wizard._exposed = true
	hole._physics_process(1.0)
	_expect(wizard.boss_current_health < protected_hp, "black-hole damage works during the trial counterattack window")
	game.trials.reset()
	game.spawner._rest_open = false
	for id in ["banana_fan", "black_hole"]:
		for _i in 4: game._on_upgrade_selected(id)
		var controller: Node = fan if id == "banana_fan" else hole
		_expect(controller.level == 5 and game.equipment_panel.get_level(id) == 5, "all five levels synchronize with equipment")
		var pressure: int = game.spawner._offense_cards
		for _i in 4: game._on_upgrade_selected(id)
		_expect(controller.level == 5 and game.spawner._offense_cards == pressure, "extra grants cannot exceed five or increase enemy pressure")
		for entry in menu.available_upgrades(): _expect(entry.id != id, "max-rank control cards leave ordinary and treasure reward pools")
	var low_fan: Dictionary = fan.stats_for(1)
	var high_fan: Dictionary = fan.stats_for(5)
	var low_hole: Dictionary = hole.stats_for(1)
	var high_hole: Dictionary = hole.stats_for(5)
	_expect(high_fan.interval < low_fan.interval and high_fan.range > low_fan.range, "fan upgrades improve frequency and reach")
	_expect(high_hole.interval < low_hole.interval and high_hole.radius > low_hole.radius and high_hole.dps > low_hole.dps, "black-hole upgrades improve cooldown, area and DPS")
	for id in ["banana_fan", "black_hole"]:
		var controller: Node = fan if id == "banana_fan" else hole
		controller.level = 4
		game.equipment_panel._slots[id].level = 4
		var pressure: int = game.spawner._offense_cards
		game._on_treasure_claimed(id, 3)
		_expect(controller.level == 5 and game.equipment_panel.get_level(id) == 5 and game.spawner._offense_cards == pressure + 1, "multi-level treasure rewards stop at the remaining rank without hidden extra upgrades")
	game.clear_enemies()
	await process_frame
	game.player.global_position = Vector2.ZERO
	game.player.last_move_direction = Vector2.RIGHT
	var near_target: Node = _enemy(game, Vector2(120, 0), 100000)
	var far_target: Node = _enemy(game, Vector2(220, 0), 100000)
	var fan_counts: Array[int] = []
	for rank in [1, 5]:
		fan.clear_combat_effects()
		fan.level = rank
		fan._stats = fan.stats_for(rank)
		fan._cooldown = 0
		var count: int = fan.casts
		far_target.health = 100000
		for _i in 180: fan._physics_process(0.05)
		fan_counts.append(fan.casts - count)
		_expect((far_target.health < 100000) == (rank == 5), "higher fan rank really reaches a distant target that rank one cannot hit")
	_expect(fan_counts[1] > fan_counts[0], "automatic fan cadence actually increases with upgrades")
	fan.clear_combat_effects()
	far_target.global_position = Vector2(120, 100)
	var hole_counts: Array[int] = []
	for rank in [1, 5]:
		hole.clear_combat_effects()
		hole.level = rank
		hole._stats = hole.stats_for(rank)
		hole._cooldown = 0
		var count: int = hole.casts
		far_target.health = 100000
		for _i in 250: hole._physics_process(0.05)
		hole_counts.append(hole.casts - count)
		_expect((far_target.health < 100000) == (rank == 5), "higher black-hole rank really damages targets outside its first-rank radius")
	_expect(hole_counts[1] > hole_counts[0], "automatic black-hole cooldown actually shortens with upgrades")
	hole.clear_combat_effects()
	game.clear_enemies()
	await process_frame
	game.player.global_position = Vector2.ZERO
	game.player.last_move_direction = Vector2.RIGHT
	for i in 180:
		_enemy(game, Vector2(120, 0) + Vector2.RIGHT.rotated(float(i) * 2.39996) * (15.0 + float(i % 65)), 100000)
	var registry: Node = root.get_node("CombatTargets")
	var queries_before: int = registry.queries
	var started := Time.get_ticks_usec()
	fan.cast()
	hole.cast()
	for _i in 60:
		fan._physics_process(0.05)
		hole._physics_process(0.05)
	var query_count: int = registry.queries - queries_before
	_expect(query_count <= 100 and fan.get_child_count() == 1 and hole.get_child_count() == 1 and fan._wakes.size() == 24, "dense crowds use bounded scans, fixed wake records and two persistent audio nodes")
	print("CONTROL CARDS CROWD: 180 enemies / 3 simulated seconds / %d queries / %d us" % [query_count, Time.get_ticks_usec() - started])
	for pair in [["DebugFanButton", 1, 0], ["DebugFan5Button", 5, 0], ["DebugBlackHoleButton", 0, 1], ["DebugBlackHole5Button", 0, 5], ["DebugControlCardsButton", 5, 5]]:
		main.show_main_menu()
		main._on_debug_button_pressed()
		main.get_node("mainUI/Control/DebugCenter/VBoxContainer/" + pair[0]).pressed.emit()
		for _i in 4: await process_frame
		_expect(main.game.banana_fan.level == pair[1] and main.game.black_hole.level == pair[2] and not paused, "each actual Debug button launches its matching loadout")
	await main._on_game_end_ui_retry_pressed()
	_expect(main.game.banana_fan.level == 5 and main.game.black_hole.level == 5, "Retry restores the selected test loadout without stacking levels")
	main.show_main_menu()
	_expect(main.game.banana_fan.level == 0 and main.game.black_hole.level == 0 and not main.game.banana_fan.is_physics_processing(), "Back resets cards, fields, motion and processing")
	await main._launch_run(&"")
	_expect(main.game.banana_fan.level == 0 and main.game.black_hole.level == 0, "normal Start never inherits debug equipment")
	if failures.is_empty():
		print("CONTROL CARDS OK: draft/art/HUD/layout, directional cone/body push/dash interrupt/mass, exact area DPS/pull/expiry/pause/no-proc/rewards, boss/trial rules, capped upgrades, bounded crowd work, actual Debug/Retry/Back")
	else:
		for failure in failures: push_error(failure)
	paused = false
	main.show_main_menu()
	main.queue_free()
	main = null
	await process_frame
	quit(0 if failures.is_empty() else 1)
