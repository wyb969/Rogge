extends SceneTree
var failures: Array[String] = []
var main: Node
func _init() -> void :
	call_deferred("_run")
func _expect(ok: bool, message: String) -> void :
	if not ok: failures.append(message)
func _configure(game: Node) -> void :
	game.level_manager.signal_level_up.disconnect(game.on_level_up)
	game.player.set_physics_process(false)
	game.trials.set_process(false)
	for name in ["HandWeapon", "CircleWeapon", "Weapon", "DroneController", "MolotovController", "FreezeController"]:
		game.get_node(name).process_mode = Node.PROCESS_MODE_DISABLED
func _enter(kind: String) -> Node:
	await main._launch_run(StringName("trial_" + kind))
	var game: Node = main.game
	_configure(game)
	return game
func _dash_window(actor: Node, player: Node) -> void :
	actor.teleport_near_player()
	player._start_dash(Vector2.RIGHT)
	actor._physics_process(0.51)
	actor._physics_process(0.17)
	player._on_dashing_timer_timeout()
func _run() -> void :
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	main._on_debug_button_pressed()
	main._launch_run(&"trial_power")
	await process_frame
	await process_frame
	var game: Node = main.game
	_configure(game)
	var trials: Node = game.trials
	var player: Node = game.player
	_expect(paused and trials.flow == trials.TrialFlow.INTRO and trials.enemy == null, "legacy trial preset opens explanation before creating the enemy")
	_expect(trials._body.text.contains("60 秒") and trials._body.text.contains("锁定音"), "strength introduction explains time and laser lock audio")
	trials._process(30)
	_expect(trials.elapsed == 0, "reading the introduction does not consume trial time")
	for size in [Vector2i(390, 844), Vector2i(900, 500)]:
		root.size = size
		await process_frame
		trials._fit()
		await process_frame
		var bounds: = Rect2(Vector2.ZERO, root.get_visible_rect().size)
		_expect(bounds.encloses(trials.start_button.get_global_rect()) and bounds.encloses(trials._panel.get_global_rect()), "intro and start button fit portrait/landscape")
	trials.start_button.pressed.emit()
	trials.start_button.pressed.emit()
	_expect(trials.active_fight() and not paused and get_nodes_in_group("trial_enemy").size() == 1, "start gesture creates only one real trial enemy")
	var actor: Node = trials.enemy
	actor.set_physics_process(false)
	_expect(actor.health_max_value == 5000 and actor.get_parent() == game, "thick mechanical target belongs to the current run")
	_expect(game.beast_powers.unlocked.size() == 2, "strength trial retains both preceding blessings")
	actor.global_position = Vector2.ZERO
	player.global_position = Vector2(170, 0)
	actor.trial_state = actor.TrialState.ROAM
	actor.left = 0
	actor._physics_process(0.01)
	var hp: float = player.player_health
	actor._physics_process(0.05)
	_expect(actor.lock_beep_count > 0 and actor._lock_audio.playing, "tracking plays the actual lock sound")
	player.global_position = Vector2(170, 90)
	actor._physics_process(1.3)
	var angle: float = actor.aim_angle
	_expect(actor.trial_state == actor.TrialState.LOCK and angle > 0.1, "tracking follows movement then enters fixed-aim warning")
	player.global_position = Vector2(-170, 0)
	actor._physics_process(0.15)
	_expect(actor.aim_angle == angle and player.player_health == hp, "fixed laser warning no longer tracks and is harmless")
	player.global_position = actor._beam_origin + Vector2.from_angle(angle) * 100
	player.dashing = true
	actor._physics_process(0.16)
	_expect(actor.trial_state == actor.TrialState.ACTIVE and player.player_health == hp, "dash immunity works against the laser")
	player.dashing = false
	player.hurt_lock = 0
	actor._physics_process(0.01)
	_expect(player.player_health == hp - 100, "active laser deals damage along its warned lane")
	player.hurt_lock = 0
	actor._physics_process(0.01)
	_expect(player.player_health == hp - 100, "one beam cannot repeatedly damage the player")
	paused = true
	trials._process(30)
	_expect(trials.elapsed == 0, "paused combat does not consume the deadline")
	paused = false
	trials._process(59.99)
	actor.apply_hit({"damage": 1000000})
	_expect(trials.flow == trials.TrialFlow.RESULT and trials._passed and paused, "lethal hit at 59.99 seconds succeeds before death effects")
	_expect(Engine.time_scale == 1, "trial kill cannot leave hitstop time scale stuck")
	trials.continue_button.pressed.emit()
	await process_frame
	_expect(trials.results.power.passed and game.rest_hub.visible, "success records the result and continues through normal rest")
	game.rest_hub._on_reward_pressed("max_hp")
	game.rest_hub.next_button.pressed.emit()
	await create_timer(1.25).timeout
	_expect(game.spawner.stage == 5 and not paused, "strength interlude resumes stage five")
	game = await _enter("power")
	trials = game.trials
	trials.start_button.pressed.emit()
	trials.enemy.set_physics_process(false)
	trials._process(60.01)
	_expect(trials.flow == trials.TrialFlow.RESULT and not trials._passed and paused, "timeout fails cleanly and stops combat")
	trials.retry_button.pressed.emit()
	trials.retry_button.pressed.emit()
	_expect(trials.active_fight() and trials.elapsed == 0 and get_nodes_in_group("trial_enemy").size() == 1, "retry resets timer/health and creates one target")
	trials.enemy.set_physics_process(false)
	game.player.hurt_lock = 0
	game.player.receive_attack(game.player.max_player_health * 2)
	_expect(trials.flow == trials.TrialFlow.RESULT and not game._death_presented, "trial death opens retry UI instead of destroying the run")
	trials.continue_button.pressed.emit()
	await process_frame
	_expect( not trials.results.power.passed and game.rest_hub.visible and game.player.player_health > 0, "explicit abandon preserves build and continues without recording a pass")
	main.game.end_game()
	main._on_debug_button_pressed()
	game = await _enter("speed")
	trials = game.trials
	player = game.player
	_expect(trials._body.text.contains("0.5") and trials._body.text.contains("反击"), "speed introduction teaches the reaction/window mechanic")
	trials.start_button.pressed.emit()
	actor = trials.enemy
	actor.set_physics_process(false)
	actor.teleport_near_player()
	_expect(is_equal_approx(actor.global_position.distance_to(player.global_position), 90), "wizard really teleports close to the player")
	var enemy_hp: float = actor.boss_current_health
	actor.apply_hit({"damage": 100})
	_expect(actor.boss_current_health == enemy_hp, "wizard shield blocks premature auto-attacks")
	hp = player.player_health
	actor._physics_process(0.49)
	_expect(actor.trial_state == actor.TrialState.LOCK and player.player_health == hp, "0.49-second warning remains harmless")
	player.hurt_lock = 0
	actor._physics_process(0.011)
	_expect(actor.trial_state == actor.TrialState.ACTIVE and player.player_health == hp - 95, "wizard swings after the 0.5-second warning")
	actor._physics_process(0.17)
	_expect( not actor.vulnerable(), "tanking the slash does not open the damage window")
	_dash_window(actor, player)
	_expect(actor.vulnerable(), "real player dash state creates a counterattack opening")
	actor.apply_hit({"damage": 100, "ignore_side_bonus": true})
	_expect(actor.boss_current_health == enemy_hp - 100, "counterattacks damage the exposed wizard")
	actor._physics_process(1.51)
	actor.apply_hit({"damage": 100})
	_expect(actor.boss_current_health == enemy_hp - 100, "the barrier returns after the response window")
	trials._process(90)
	_expect(trials.active_fight(), "speed trial has no unintended total time limit")
	_dash_window(actor, player)
	actor.apply_hit({"damage": 1000000})
	_expect(trials._passed and paused, "defeating the exposed wizard succeeds")
	var result: = {"victory": false}
	game.game_over.connect( func(stats: Dictionary): result.merge(stats, true))
	trials.settle_button.pressed.emit()
	_expect(result.victory and result.trials.speed.passed, "speed success can settle the real stage-six victory")

	await main._launch_run(&"beast_4")
	game = main.game
	_configure(game)
	var beast: Node = get_nodes_in_group("beast_boss")[0]
	beast.apply_hit({"damage": 1000000})
	var deadline: = Time.get_ticks_msec() + 4000
	while game.beast_powers._pending_reward < 0 and Time.get_ticks_msec() < deadline:
		await process_frame
	game.beast_powers.reward_claim.pressed.emit()
	await process_frame
	await process_frame
	_expect(game.trials.flow == game.trials.TrialFlow.INTRO and game.spawner.stage == 4, "normal route inserts strength after the second divine beast's blessing")

	game.trials.start_button.pressed.emit()
	await main._launch_run(&"trial_power")
	_expect(get_nodes_in_group("trial_enemy").is_empty() and main.game.trials.flow == main.game.trials.TrialFlow.INTRO, "new run leaves no old trial actor or running timer")
	if main.game.SPEED_TRIAL_ENABLED:

		await main._launch_run(&"beast_6")
		game = main.game
		_configure(game)
		beast = get_nodes_in_group("beast_boss")[0]
		beast.apply_hit({"damage": 1000000})
		deadline = Time.get_ticks_msec() + 4000
		while game.beast_powers._pending_reward < 0 and Time.get_ticks_msec() < deadline:
			await process_frame
		_expect( not is_instance_valid(game.beast_powers.reward_finish) or not game.beast_powers.reward_finish.visible, "final blessing cannot bypass the speed explanation")
		game.beast_powers.reward_claim.pressed.emit()
		await process_frame
		await process_frame
		trials = game.trials
		_expect(trials.kind == "speed" and trials.flow == trials.TrialFlow.INTRO and game.beast_powers.unlocked.size() == 4, "fourth divine blessing opens speed trial with all four powers")
		trials.start_button.pressed.emit()
		trials.enemy.set_physics_process(false)
		trials.fail("测试重试")
		for size in [Vector2i(390, 844), Vector2i(900, 500)]:
			root.size = size
			await process_frame
			trials._fit()
			await process_frame
			var bounds: = Rect2(Vector2.ZERO, root.get_visible_rect().size)
			_expect(bounds.encloses(trials.retry_button.get_global_rect()) and bounds.encloses(trials.settle_button.get_global_rect()), "speed retry and explicit settlement fit both viewports")
		trials.retry_button.pressed.emit()
		actor = trials.enemy
		actor.set_physics_process(false)
		_dash_window(actor, game.player)
		actor.apply_hit({"damage": 1000000})
		trials.continue_button.pressed.emit()
		await process_frame
		_expect(game.spawner._endless_trial and game.beast_powers.finish_button.visible and trials.results.speed.passed, "speed completion resumes the real free-trial arena with its settlement button")
	if failures.is_empty(): print("TRIALS OK: intro/viewport, real laser/audio, 60s deadline, retry/death/skip, 0.5s teleport slash, dash-only opening, retained powers, real progression and reset")
	else:
		for failure in failures: push_error(failure)
	paused = false
	quit(0 if failures.is_empty() else 1)
