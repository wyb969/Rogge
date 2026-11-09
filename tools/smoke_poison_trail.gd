extends SceneTree
var failures: Array[String] = []
var main: Node
func _init() -> void : call_deferred("_run")
func _expect(ok: bool, message: String) -> void :
	if not ok: failures.append(message)
func _enemy(game: Node, at: Vector2, hp: float = 1000) -> Node:
	var actor: Node = load("res://scenes/enemy_shell.tscn").instantiate()
	actor.set_player_ref(game.player)
	actor.set_enemy_data(load("res://resource/Enemy_1.tres"))
	actor.add_to_group("EnemyGroup")
	actor.health = hp
	actor.defense = 0
	actor.death_signal.connect(game.spawner.on_enemy_killed.bind(actor))
	game.add_child(actor)
	actor.global_position = at
	actor.set_physics_process(false)
	return actor
func _field(game: Node, at: Vector2) -> void :
	game.player.global_position = at - Vector2(36, 0)
	game.poison_trail.clear_combat_effects()
	game.player.global_position = at + Vector2(36, 0)
	game.poison_trail._process(0)
func _run() -> void :
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	await main._launch_run(&"")
	var game: Node = main.game
	game.spawner.timer.stop()
	game.spawner.get_node("Elite").stop()
	game.spawner.set_process(false)
	game.player.set_physics_process(false)
	game.level_manager.signal_level_up.disconnect(game.on_level_up)
	for name in ["HandWeapon", "CircleWeapon", "Weapon", "DroneController", "MolotovController", "FreezeController"]:
		game.get_node(name).process_mode = Node.PROCESS_MODE_DISABLED
	var trail: Node = game.poison_trail
	trail._process(2)
	_expect(trail.active_clouds() == 0 and trail.damage_ticks == 0, "unowned trail cannot emit or attack")
	var menu: Node = game.pause_menu
	var full_pool: Array = menu.upgrade_pool.duplicate()
	var entry: Dictionary
	for item in full_pool:
		if item.id == "poison_trail": entry = item
	_expect( not entry.is_empty(), "poison exists in ordinary cards and treasure rewards")
	menu.upgrade_pool = [entry]
	menu.show_upgrade_options()
	var card: Node = menu.h_box_container.get_child(0)
	_expect(card.icon.texture != null and card.desc_label.text.contains("5") and card.desc_label.text.contains("4 秒"), "real card shows original art, first-rank DPS, lifetime and final-rank unlock")
	card.selected.emit("poison_trail")
	menu.upgrade_pool = full_pool
	trail.set_process(false)
	var three: Array = [entry]
	for item in full_pool:
		if item.id in ["freeze_up", "shield_up"]: three.append(item)
	menu.upgrade_pool = three
	for size in [Vector2i(390, 844), Vector2i(1920, 1080)]:
		root.size = size
		menu.show_upgrade_options()
		for _i in 5: await process_frame
		var vp: = root.get_visible_rect().size
		for choice in menu.h_box_container.get_children():
			_expect(choice.desc_label.get_global_rect().end.y < menu.reroll_button.get_global_rect().position.y, "three-card wrapped descriptions cannot overlap the reroll footer")
		_expect(Rect2(Vector2.ZERO, vp).encloses(menu.reroll_hint.get_global_rect()), "card footer stays onscreen in both orientations")
	menu.visible = false
	paused = false
	menu.upgrade_pool = full_pool
	_expect(trail.level == 1 and game.equipment_panel.get_level("poison_trail") == 1 and game.spawner._offense_cards == 1, "normal selection synchronizes controller, equipment and offense")
	trail._process(1)
	_expect(trail.active_clouds() == 0, "standing still cannot continuously renew poison")
	var actor: Node = _enemy(game, Vector2.ZERO)
	var outside: Node = _enemy(game, Vector2(100, 100))
	for step in [0.1, 0.25, 1.0]:
		_field(game, Vector2.ZERO)
		actor.health = 1000
		var count: = int(round(1.0 / step))
		for _i in count: trail._process(step)
		_expect(is_equal_approx(actor.health, 995), "one second of overlap deals exactly 5 base damage at multiple frame steps")
	_expect(outside.health == 1000, "only actors inside the actual cloud circles are damaged")
	_expect(trail.active_clouds() == 4 and actor.poison_slow == 1, "overlap remains one dose and ranks one through four cannot slow")
	var tint: Color = actor.sprite_2d.self_modulate
	trail._process(0.2)
	_expect(actor.sprite_2d.self_modulate != tint and actor._poison_tint.r > actor._poison_tint.g and actor._poison_tint.b > actor._poison_tint.g, "poison pulses magenta instead of burn orange or freeze blue")
	actor.apply_burn({"burn_stacks": 2, "burn_dps": 2})
	actor.apply_freeze({"freeze_duration": 2, "slow_factor": 0.3})
	actor._update_statuses(0)
	_expect(actor.sprite_2d.modulate == GamePalette.FRIENDLY_LIGHT and actor._poison_tint != Color.WHITE, "poison indication coexists with the separate freeze/status tint channel")
	actor.freeze_time = 0
	actor.burn_stacks = 0
	actor._hit_flash_left = 0
	_field(game, Vector2.ZERO)
	actor.health = 1000
	actor.defense = 0.2
	trail._process(1)
	_expect(is_equal_approx(actor.health, 996), "poison damage uses actual enemy mitigation")
	actor.defense = 0
	var clouds_before: int = trail.active_clouds()
	var hp_before: float = actor.health
	var dose_before: float = trail._exposed[actor.get_instance_id()].dose
	paused = true
	trail._process(10)
	_expect(actor.health == hp_before and trail.active_clouds() == clouds_before and trail._exposed[actor.get_instance_id()].dose == dose_before, "cards/rest pauses freeze clouds, damage and exposure")
	paused = false
	for rank in range(2, 6):
		game._on_upgrade_selected("poison_trail")
		_expect(trail.stats_for(rank).dps == rank * 5, "each real rank raises DPS by five")
	_expect(trail.level == 5 and game.equipment_panel.get_level("poison_trail") == 5, "fifth rank is synchronized in real gameplay and HUD")
	var pressure: int = game.spawner._offense_cards
	for _i in 6: game._on_upgrade_selected("poison_trail")
	_expect(trail.level == 5 and game.equipment_panel.get_level("poison_trail") == 5 and game.spawner._offense_cards == pressure, "forced extra ranks cannot exceed five or secretly raise enemy pressure")
	for _i in 60:
		for item in menu._draw_upgrades(3): _expect(item.id != "poison_trail", "max-rank poison leaves normal draws and rerolls")
	_field(game, Vector2.ZERO)
	actor.health = 1000
	trail._process(1)
	_expect(actor.health == 975 and actor.poison_slow == 0.75, "rank five deals 25 damage per second and applies exactly 25 percent movement slow")
	actor._physics_process(0)
	_expect(is_equal_approx(actor.velocity.length(), actor.speed * 0.75), "slow affects real steering rather than only its label")
	actor.apply_freeze({"freeze_duration": 2, "slow_factor": 0.3})
	_expect(actor.status_move_scale() == 0.3, "poison and freeze use the stronger slow without multiplying into an unintended root")
	actor.freeze_time = 0
	actor.global_position = Vector2(500, 500)
	trail._process(0.1)
	_expect(actor.poison_slow == 1 and actor.get_instance_id() not in trail._exposed, "leaving poison promptly removes slow and exposure")
	actor._hit_flash_left = 0
	actor._process(0)
	_expect(actor.sprite_2d.self_modulate == Color.WHITE, "exit restores the body's visual channel without a stuck poison flash")
	actor.global_position = Vector2.ZERO
	_field(game, Vector2.ZERO)
	actor.health = 1000
	for _i in 4: trail._process(1)
	_expect(actor.health == 900 and trail.active_clouds() == 0, "four-second stationary clouds expire and retain the final damage boundary exactly")
	trail._process(1)
	_expect(actor.health == 900 and actor.poison_slow == 1, "expired clouds cannot keep dealing damage or slowing")

	game.molotov_controller.level = 8
	game.freeze_controller.level = 8
	game.player.lifesteal_level = 4
	game.player.player_health = 300
	_field(game, Vector2.ZERO)
	seed(969)
	var expected: = randi()
	seed(969)
	trail._process(1)
	_expect(randi() == expected and actor.burn_stacks == 0 and actor.freeze_time == 0 and game.player.player_health == 300, "poison ticks have isolated randomness and cannot recursively trigger on-hit sustain/status cards")
	game.molotov_controller.level = 0
	game.freeze_controller.level = 0
	game._on_upgrade_selected("monster_necklace")
	actor.health = 1
	var kills: int = game.spawner.enemy_killed_num
	_field(game, Vector2.ZERO)
	trail._process(1)
	_expect(actor._death_started and game.spawner.enemy_killed_num == kills + 1 and get_nodes_in_group("healing_orb").size() == 1, "real poison kills still grant one XP/necklace/kill reward")
	game.clear_enemies()
	await process_frame
	trail.clear_combat_effects()
	var node_count: int = get_node_count()
	for _i in 500:
		game.player.global_position += Vector2(72, 0)
		trail._process(0)
	_expect(trail.active_clouds() == 64 and trail._clouds.size() == 64 and get_node_count() == node_count, "long movement and overlapping clouds reuse 64 records with no per-cloud nodes")
	trail.clear_combat_effects()
	game.player.global_position += Vector2(300, 0)
	trail._process(0)
	_expect(trail.active_clouds() == 0, "teleports do not create an arena-wide poison bridge")
	game.player.global_position += Vector2(108, 0)
	trail._process(0)
	_expect(trail.active_clouds() == 6, "dash-sized movement lays a continuous bounded trail rather than leaving a gap")

	game.spawner.debug_start_beast(3)
	var boss: Node = game.spawner._active_bosses[0]
	boss.set_physics_process(false)
	boss.last_hitstop_msec = Time.get_ticks_msec() + 100000
	_field(game, boss.global_position)
	var boss_hp: float = boss.boss_current_health
	trail._process(1)
	_expect(boss.boss_current_health == boss_hp - 25 and boss.poison_slow == 0.75, "guardian HP, damage and movement slow follow the real boss pipeline")
	game.clear_enemies()
	await process_frame
	game.spawner._active_bosses.clear()
	game.spawner._boss_fight_active = false
	game.trials.begin("speed")
	game.trials.start_attempt()
	var wizard: Node = game.trials.enemy
	wizard.set_physics_process(false)
	_field(game, wizard.global_position)
	var trial_hp: float = wizard.boss_current_health
	trail._process(1)
	_expect(wizard.boss_current_health == trial_hp and wizard.poison_slow == 1, "poison cannot bypass a protected speed-trial wizard")
	wizard.trial_state = wizard.TrialState.RECOVER
	wizard._exposed = true
	_field(game, wizard.global_position)
	trail._process(1)
	_expect(wizard.boss_current_health < trial_hp, "poison works during the real trial counterattack window")
	game.trials.reset()
	game.spawner._boss_fight_active = false
	game.spawner._rest_open = false
	game.poison_trail.level = 4
	game.equipment_panel._slots.poison_trail.level = 4
	var lottery: Node = load("res://script/treasure_lottery.gd").new()
	game.add_child(lottery)
	lottery.open_lottery([entry], game.equipment_panel)
	_expect(lottery.bonus_levels == 1 and lottery.old_level == 4, "a tiny capped debug lottery displays the actual remaining rank")
	lottery.hide()
	paused = false
	game._on_treasure_claimed("poison_trail", 3)
	_expect(trail.level == 5 and game.equipment_panel.get_level("poison_trail") == 5, "multi-rank treasure rewards stop cleanly at rank five")
	main.on_game_over({"victory": false})
	await main._on_game_end_ui_retry_pressed()
	_expect(main.game.poison_trail.level == 0 and main.game.poison_trail.active_clouds() == 0 and main.game.poison_trail._exposed.is_empty(), "Retry clears poison ownership, clouds, slow and weak references")
	await main._launch_run(&"poison5")
	_expect(main.game.poison_trail.level == 5, "real Debug entry equips rank-five poison immediately")
	main.show_main_menu()
	_expect( not main.game.poison_trail.is_processing(), "Back stops poison processing and restores affected actors")
	if failures.is_empty(): print("POISON TRAIL OK: real card/ranks/cap/lottery, exact DPS/radius/nonstacking/expiry, movement/dash/teleport, distinct layered pulse, real slow/freeze interaction, pause/RNG/no proc cascade, kill rewards, fixed pools, boss/trial shields and Debug/Retry/Back")
	else:
		for failure in failures: push_error(failure)
	paused = false
	quit(0 if failures.is_empty() else 1)
