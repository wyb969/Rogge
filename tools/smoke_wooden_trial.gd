extends SceneTree
var failures: Array[String] = []
var checks := 0

func _init() -> void: call_deferred("_run")
func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _modal_fits(trials: Node) -> void:
	for size in [Vector2i(390,844), Vector2i(320,568), Vector2i(844,390), Vector2i(900,500)]:
		root.size = size
		await process_frame
		await process_frame
		trials._fit()
		await process_frame
		var bounds := Rect2(Vector2.ZERO, root.get_visible_rect().size)
		_expect(bounds.encloses(trials._panel.get_global_rect()), "wooden modal fits %s: %s" % [size,trials._panel.get_global_rect()])
		for button in trials._actions.get_children():
			_expect(bounds.encloses(button.get_global_rect()), "wooden action fits %s" % size)

func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	main._on_debug_button_pressed()
	var button: Button = main.debug_page.box.get_node("DebugWoodenTrialButton")
	main.debug_page.ensure_control_visible(button)
	_expect(button.visible and not button.disabled, "wooden challenge is reachable on its current Debug page")
	button.pressed.emit()
	button.pressed.emit()
	await process_frame
	await process_frame
	var game: Node = main.game
	var trials: Node = game.trials
	var player: Node = game.player
	var mobile: Node = root.get_node("MobileInput")
	trials.set_process(false)
	game.spawner.set_process(false)
	game.weather.stop()
	game.meteors.set_process(false)
	game.variety._courier_left = 99999
	_expect(trials.kind == "wooden" and trials.flow == trials.TrialFlow.INTRO and main.game_root.get_child_count() == 1, "real Debug entry opens one paused wooden intro")
	_expect(paused and not player.movement_locked and trials.horde.alive_count() == 0 and trials.elapsed == 0, "explanation consumes no time or movement lock and spawns no enemies")
	await _modal_fits(trials)
	for name in ["HandWeapon","CircleWeapon","Weapon","DroneController","MolotovController","FreezeController"]:
		game.get_node(name).process_mode = Node.PROCESS_MODE_DISABLED
	trials.start_button.pressed.emit()
	var anchor: Vector2 = player.global_position
	_expect(trials.active_fight() and player.movement_locked and not player.can_dash and not paused and not main.mobile_controls.visible, "start locks movement/dash and hides their mobile controls")
	Input.action_press("right")
	Input.action_press("roll")
	mobile.controls_enabled = true
	mobile.set_move_vector(Vector2.LEFT)
	mobile.request_dash()
	player._physics_process(0.1)
	player._start_dash(Vector2.UP)
	player._on_can_dasing_timer_timeout()
	_expect(player.global_position == anchor and player.velocity == Vector2.ZERO and not player.dashing and not player.can_dash, "keyboard, touch, direct dash and cooldown callback cannot escape the lock")
	Input.action_release("right")
	Input.action_release("roll")
	mobile.controls_enabled = false
	_expect(not mobile.has_move_input() and not mobile.dash_just_pressed, "locked inputs do not accumulate for later")
	game._on_upgrade_selected("regen_up")
	player.player_health -= 30
	var hp: float = player.player_health
	player._tick_regen(3.0)
	_expect(player.player_health > hp and player.movement_locked, "regeneration continues while movement is locked")
	game.beast_powers.select(0)
	_expect(game.beast_powers.cast_selected() and player.player_health > hp, "earned healing skill remains usable")
	trials._process(0.5)
	_expect(trials.horde.spawned == 2 and trials.enemy == null, "first tide spawns actual horde actors, no wizard or boss")
	for actor in get_nodes_in_group("wooden_trial_enemy"):
		actor.set_physics_process(false)
	var actor: Node = get_nodes_in_group("wooden_trial_enemy")[0]
	player.hurt_lock = 0
	hp = player.player_health
	player.receive_attack(actor.contact_damage, actor)
	_expect(player.player_health < hp and player.global_position == anchor, "contact damage is real and does not move the player")
	for phase in 3:
		trials.elapsed = phase * 20.0
		for _i in 100: trials.horde.advance(1.0, trials.elapsed)
		_expect(trials.horde.wave == phase and trials.horde.alive_count() == trials.horde.CAPS[phase], "tide %d is independently capped" % phase)
		for target in get_nodes_in_group("wooden_trial_enemy"): target.set_physics_process(false)
	_expect(trials.horde.alive_count() <= 72, "crowd work has an absolute 72-enemy ceiling")
	game._on_upgrade_selected("monster_necklace")
	game._on_upgrade_selected("shield_up")
	var kills: int = game.spawner.enemy_killed_num
	actor.apply_hit({"damage":100000.0})
	_expect(game.spawner.enemy_killed_num == kills + 1 and player.shield > 0 and get_nodes_in_group("healing_orb").size() == 1, "horde kills use ordinary kill rewards and necklace/shield procs exactly once")
	var before_free: int = trials.horde.alive_count()
	get_nodes_in_group("wooden_trial_enemy").back().queue_free()
	await process_frame
	await process_frame
	_expect(trials.horde.alive_count() == before_free - 1, "freed actors prune safely even after the engine releases their objects")
	trials.elapsed = 59.8
	paused = true
	trials._process(10)
	_expect(is_equal_approx(trials.elapsed,59.8) and trials.active_fight(), "pause cannot finish the survival timer")
	paused = false
	trials._process(0.1)
	_expect(trials.active_fight() and player.movement_locked, "survival cannot pass before the full minute")
	trials._process(0.2)
	_expect(trials._passed and trials.flow == trials.TrialFlow.RESULT and paused and not player.movement_locked and player.can_dash, "one minute alive succeeds and restores movement/dash")
	_expect(not trials.horde.active and trials.horde.alive_count() == 0 and get_nodes_in_group("wooden_trial_enemy").size() == 0, "success clears all surviving horde actors")
	trials.continue_button.pressed.emit()
	trials.continue_button.pressed.emit()
	_expect(trials.results.wooden.passed and game.spawner._endless_trial and game.beast_powers.finish_button.visible, "success records once and opens ordinary free play")

	await main._launch_run(&"trial_wooden")
	game = main.game
	trials = game.trials
	player = game.player
	trials.set_process(false)
	trials.start_button.pressed.emit()
	trials._process(0.5)
	player.hurt_lock = 0
	player.receive_attack(1000000)
	_expect(trials.flow == trials.TrialFlow.RESULT and not trials._passed and not player.movement_locked and not game._death_presented and trials.horde.alive_count() == 0, "death fails the trial, clears crowd/lock and offers Retry instead of destroying the run")
	await _modal_fits(trials)
	trials.retry_button.pressed.emit()
	_expect(trials.active_fight() and trials.elapsed == 0 and player.player_health == player.max_player_health and player.movement_locked and trials.horde.spawned == 0, "Retry gives full health and one fresh minute without duplicate waves")
	game.end_game()
	_expect(not player.movement_locked and not trials.horde.active and trials.horde.alive_count() == 0, "interrupted run cleans lock and owned enemies")
	await main._launch_run(&"")
	_expect(not main.game.player.movement_locked and main.game.player.can_dash and get_nodes_in_group("wooden_trial_enemy").is_empty(), "ordinary new game inherits no lock or challenge actors")
	if failures.is_empty(): print("WOODEN TRIAL OK: %d checks; actual Debug, real horde/rewards, lock/input/dash, timer, pause, skills, density caps, result/retry/reset and mobile modals" % checks)
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
