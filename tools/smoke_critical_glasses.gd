extends SceneTree

const CRITICAL := preload("res://script/critical_glasses.gd")
const BUDGET := preload("res://script/feedback_budget.gd")
var failures: Array[String] = []
var main: Node
var game: Node

func _init() -> void: call_deferred("_run")

func _expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _isolate() -> void:
	game.spawner.timer.stop()
	game.spawner.get_node("Elite").stop()
	game.spawner.set_process(false)
	game.player.set_physics_process(false)
	game.player.global_position = Vector2.ZERO
	game.weather.stop()
	game.variety._courier_left = 99999
	for node_name in ["HandWeapon", "CircleWeapon", "Weapon", "DroneController", "MolotovController", "FreezeController"]:
		game.get_node(node_name).process_mode = Node.PROCESS_MODE_DISABLED

func _admit() -> void:
	BUDGET._tokens = 36
	BUDGET._frame = -1
	BUDGET._stamp = Time.get_ticks_msec()

func _enemy() -> Node:
	var actor: Node = load("res://scenes/enemy_shell.tscn").instantiate()
	actor.set_enemy_data(load("res://resource/Enemy_1.tres"))
	actor.set_player_ref(game.player)
	actor.health = 10000
	actor.defense = 0.0
	actor.add_to_group("EnemyGroup")
	game.add_child(actor)
	actor.global_position = Vector2(-100, 0)
	actor.set_physics_process(false)
	return actor

func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	await main._launch_run(&"")
	game = main.game
	_isolate()
	var player: Node = game.player
	var actor: Node = _enemy()
	_admit()
	actor.apply_hit({"damage": 10.0})
	var plain: Node = game.effect_container.get_children().back()
	var plain_font_size: int = plain.label.get_theme_font_size("font_size")
	_expect(actor.health == 9990 and not plain._critical, "unowned glasses leave real damage and its popup unchanged")
	var pool: Array = game.pause_menu.upgrade_pool.duplicate()
	var entry: Dictionary = {}
	for option in pool:
		if option.id == "critical_glasses": entry = option
	_expect(not entry.is_empty(), "glasses appear in the ordinary draft and lottery pool")
	if entry.is_empty(): quit(1); return
	game.pause_menu.upgrade_pool = [entry]
	game.pause_menu.show_upgrade_options()
	var card: Node = game.pause_menu.h_box_container.get_child(0)
	_expect(card.icon.texture != null and card.desc_label.text.contains("20%") and card.desc_label.text.contains("150%"), "real card shows its sunglasses icon and first-rank statistics")
	for viewport_size in [Vector2i(390, 844), Vector2i(1066, 600)]:
		root.size = viewport_size
		for _i in 5: await process_frame
		_expect(card.desc_label.get_global_rect().end.y < game.pause_menu.reroll_button.get_global_rect().position.y, "critical card text fits above the reroll control on phone and desktop")
	card.selected.emit("critical_glasses")
	_expect(player.critical_glasses_level == 1 and game.equipment_panel.get_level("critical_glasses") == 1 and game.spawner._offense_cards == 1, "real selection synchronizes player, equipment and offense pressure")
	_isolate()
	for rank in range(1, 5):
		player.critical_glasses_level = rank
		player._critical_rng.seed = 129873 + rank
		var count := 0
		for _i in 5000:
			if player.roll_critical_multiplier({"damage": 10.0}) > 1.0: count += 1
		_expect(absf(float(count) / 5000.0 - float(rank) * 0.2) < 0.035, "seeded rolls approximate the expected %d%% chance" % (rank * 20))
	player.critical_glasses_level = 1
	for _i in 3: game._on_upgrade_selected("critical_glasses")
	var next: Dictionary = game.pause_menu._build_card_data(entry)
	_expect(next.desc.contains("100%") and next.desc.contains("200%"), "rank-five preview advertises guaranteed double damage")
	var lottery: Node = load("res://script/treasure_lottery.gd").new()
	game.add_child(lottery)
	lottery.open_lottery([entry], game.equipment_panel)
	_expect(lottery.bonus_levels == 1 and lottery.old_level == 4, "lottery clamps its bonus to the one remaining rank")
	lottery.reward_claimed.connect(func(id: String, ranks: int):
		for _i in ranks: game._on_upgrade_selected(id))
	lottery._reveal()
	lottery._on_button()
	lottery.hide()
	paused = false
	_expect(player.critical_glasses_level == 5 and game.equipment_panel.get_level("critical_glasses") == 5, "actual lottery claim equips the fifth rank")
	var pressure: int = game.spawner._offense_cards
	for _i in 3: game._on_upgrade_selected("critical_glasses")
	_expect(player.critical_glasses_level == 5 and game.spawner._offense_cards == pressure and game.pause_menu.available_upgrades().is_empty(), "max rank cannot be drafted or overclaimed and adds no phantom pressure")
	game.pause_menu.upgrade_pool = pool
	game.pause_menu.hide()
	_admit()
	var data := {"damage": 10.0, "direction": Vector2.LEFT}
	var saved := data.duplicate()
	var hp: float = actor.health
	actor.apply_hit(data)
	var popup: Node = game.effect_container.get_children().back()
	_expect(actor.health == hp - 20 and data == saved, "max rank doubles direct enemy damage once without mutating a shared hit payload")
	_expect(popup._critical and popup.label.text == "20!" and popup.label.get_theme_font_size("font_size") > plain_font_size and popup.label.get_theme_constant("outline_size") == 3, "critical popup is larger, outlined and marked with an exclamation")
	player.left_fist_level = 1
	game.freeze_controller.level = 1
	actor.freeze_time = 1.0
	actor.defense = 0.25
	hp = actor.health
	actor.apply_hit({"damage": 10.0})
	_expect(is_equal_approx(hp - actor.health, 23.4), "critical combines once with side bonus, frozen bonus and enemy defense")
	player.left_fist_level = 0
	game.freeze_controller.level = 0
	actor.freeze_time = 0.0
	actor.defense = 0.0
	for hit in [{"damage": 5.0, "effect": "poison_trail", "from_status": true}, {"damage": 6.0, "effect": "black_hole", "from_status": true}, {"damage": 8.0, "can_crit": false}]:
		_admit()
		hp = actor.health
		var rng_state: int = player._critical_rng.state
		actor.apply_hit(hit)
		popup = game.effect_container.get_children().back()
		_expect(actor.health == hp - hit.damage and not popup._critical and player._critical_rng.state == rng_state, "periodic and explicitly excluded hits neither crit nor consume crit rolls")
	hp = actor.health
	actor._take_status_damage(5.0)
	_expect(actor.health == hp - 5.0, "burn ticks cannot crit again")
	_admit()
	var boss: Node = load("res://scenes/boss.tscn").instantiate()
	boss.set_player(player)
	game.add_child(boss)
	boss.add_to_group("EnemyGroup")
	boss.rush_timer.stop()
	boss.set_physics_process(false)
	boss.last_hitstop_msec = Time.get_ticks_msec() + 100000
	hp = boss.boss_current_health
	boss.apply_hit({"damage": 10.0})
	popup = game.effect_container.get_children().back()
	_expect(boss.boss_current_health == hp - 20 and popup._critical, "Boss base applies the same double damage and critical popup")
	hp = boss.boss_current_health
	boss.apply_hit({"damage": 5.0, "from_status": true})
	_expect(boss.boss_current_health == hp - 5.0, "Boss status damage also avoids a second crit")
	game.variety.clear_combat_effects()
	_expect(player.critical_glasses_level == 5, "between-stage cleanup preserves passive ranks")
	main.show_main_menu()
	_expect(player.critical_glasses_level == 0, "returning to the menu clears crit state on the old run")
	await main._launch_run(&"critical5")
	game = main.game
	_isolate()
	_expect(game.player.critical_glasses_level == 5 and game.equipment_panel.get_level("critical_glasses") == 5, "debug entry prepares guaranteed criticals")
	main.on_game_over({"victory": false})
	main.game_end_ui.retry_pressed.emit()
	for _i in 8: await process_frame
	_expect(main._test_mode == &"critical5" and main.game.player.critical_glasses_level == 5, "retry preserves the test mode without stacking ranks")
	main.show_main_menu()
	await main._launch_run(&"")
	game = main.game
	_expect(game.player.critical_glasses_level == 0 and game.equipment_panel.get_level("critical_glasses") == 0, "a normal run does not inherit debug glasses")
	main.show_main_menu()
	await main._launch_run(&"trial_speed")
	game = main.game
	game.trials.start_button.pressed.emit()
	_isolate()
	game.trials.set_process(false)
	player = game.player
	for _i in 5: game._on_upgrade_selected("critical_glasses")
	var wizard: Node = game.trials.enemy
	wizard.set_physics_process(false)
	hp = wizard.boss_current_health
	wizard.apply_hit({"damage": 100.0})
	_expect(wizard.boss_current_health == hp, "guaranteed criticals cannot bypass the wizard barrier")
	wizard.teleport_near_player()
	player._start_dash(Vector2.RIGHT)
	wizard._physics_process(0.51)
	wizard._physics_process(0.17)
	player._on_dashing_timer_timeout()
	_expect(wizard.vulnerable(), "real dodge opens the counterattack window with glasses equipped")
	wizard.apply_hit({"damage": 100.0, "ignore_side_bonus": true})
	_expect(wizard.boss_current_health == hp - 200.0, "the exposed wizard receives exactly one critical multiplier")
	main.show_main_menu()
	if failures.is_empty(): print("CRITICAL GLASSES OK: real draft/icon, rank probabilities, master damage, capped lottery, enemy/Boss damage and text, bonus composition, status exclusions, stage/menu/retry lifecycle")
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
