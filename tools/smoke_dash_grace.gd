extends SceneTree
var failures: Array[String] = []
func _init() -> void :
	call_deferred("_run")
func _expect(ok: bool, message: String) -> void :
	if not ok: failures.append(message)
func _freeze(game: Node) -> void :
	game.spawner.timer.stop()
	game.spawner.get_node("Elite").stop()
	game.player.set_physics_process(false)
	for name in ["HandWeapon", "CircleWeapon", "Weapon", "DroneController", "MolotovController", "FreezeController"]:
		game.get_node(name).process_mode = Node.PROCESS_MODE_DISABLED
func _run() -> void :
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	await main._launch_run(&"")
	var game: Node = main.game
	_freeze(game)
	var p: Node = game.player
	var controls: Node = main.mobile_controls
	var button: Control = controls.dash_button
	controls.visible = true
	root.get_node("MobileInput").controls_enabled = true
	_expect( not game.has_node("HudLayer/DashCooldownRing") and get_nodes_in_group("dash_cooldown_ui").is_empty(), "old independent cooldown ring is removed")
	for step in [1.0 / 30.0, 1.0 / 60.0, 0.2]:
		p.reset_dash()
		p.hurt_lock = 0
		p.shield = 40
		p._start_dash(Vector2.LEFT)
		p.dashing_timer.stop()
		var hp: float = p.player_health
		p.receive_attack(80)
		_expect(p.is_dash_invulnerable() and p.player_health == hp and p.shield == 40 and p.hurt_lock == 0, "dash immunity blocks HP/shield damage without consuming hurt immunity")
		p._on_dashing_timer_timeout()
		_expect( not p.dashing and p.dash_grace_left == 0.5 and p.is_dash_invulnerable(), "movement ends before the separate exact 0.5-second grace window")
		var elapsed: = 0.0
		while elapsed < 0.49 - 1e-06:
			var delta: = minf(step, 0.49 - elapsed)
			p._physics_process(delta)
			p.receive_attack(80)
			elapsed += delta
		_expect(p.player_health == hp and p.shield == 40 and p.is_dash_invulnerable(), "no accepted hits during the first 0.49 post-dash seconds at every frame step")
		p._physics_process(0.009)
		p.receive_attack(80)
		_expect(p.player_health == hp and p.is_dash_invulnerable(), "protection still holds at 0.499 seconds")
		p._physics_process(0.002)
		p.receive_attack(80)
		_expect( not p.is_dash_invulnerable() and p.player_health == hp - 40 and p.shield == 0 and p.hurt_lock > 0, "normal shield/damage processing resumes after 0.5 seconds")
		p.full_heal()
	p.reset_dash()
	p._start_dash(Vector2.RIGHT)
	p.dashing_timer.stop()
	p._on_dashing_timer_timeout()
	await process_frame
	_expect( not p.hurt_area.monitoring, "contact Area remains disabled during the post-dash grace")
	var hp: float = p.player_health
	var enemy: Node = load("res://scenes/enemy_shell.tscn").instantiate()
	enemy.set_enemy_data(load("res://resource/Enemy_5.tres"))
	enemy.set_player_ref(p)
	game.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.contact_timer = 0
	enemy._try_contact(0)
	var shot: Node = load("res://scenes/enemy_projectile.tscn").instantiate()
	game.effect_container.add_child(shot)
	shot.launch(p.global_position, Vector2.RIGHT, 100, 50, Color.RED)
	shot._physics_process(0)
	var boss: Node = load("res://scenes/beast_boss.tscn").instantiate()
	boss.player = p
	game.add_child(boss)
	boss.set_physics_process(false)
	boss._hit()
	_expect(p.player_health == hp and p.hurt_lock == 0 and enemy.contact_recovery_left > 0, "real contact/projectile/guardian attacks all respect grace without removing the dasher's escape opening")
	enemy.free()
	boss.free()
	p._physics_process(0.5)
	await process_frame
	_expect(p.hurt_area.monitoring, "normal contact monitoring returns after grace expires")


	p.reset_dash()
	p.set_physics_process(true)
	p._start_dash(Vector2.UP)
	await create_timer(0.22, true, false, true).timeout
	_expect( not p.dashing and p.dash_grace_left > 0 and p.dash_grace_left < 0.5, "actual dash timer transitions into protection after movement ends")
	paused = true
	var left: float = p.dash_grace_left
	var cooldown: float = p.can_dasing_timer.time_left
	await create_timer(0.2, true, false, true).timeout
	_expect(p.dash_grace_left == left and p.can_dasing_timer.time_left == cooldown, "card pause freezes protection and cooldown together")
	paused = false
	await create_timer(0.55, true, false, true).timeout
	_expect( not p.is_dash_invulnerable() and not p.can_dash, "post-dash protection expires independently of the longer cooldown")
	p.set_physics_process(false)
	p.reset_dash()
	p.apply_rest_cooldown(0.5)
	controls.bind_player(p)
	controls._process(0)
	_expect(button.available and button.progress == 1 and button._bounce == null, "binding a new run shows ready green without a false completion cue")
	var touch_rect: = button.get_global_rect()
	var origin: = button.position
	var original_size: = button.size
	p._start_dash(Vector2.LEFT)
	controls._process(0)
	_expect( not button.available and button.progress < 0.01 and button._fill.size() < 3, "using dash immediately leaves a gray empty button")
	await create_timer(0.68, true, false, true).timeout
	controls._process(0)
	_expect(button.progress > 0.35 and button.progress < 0.65 and button._fill.size() >= 3, "actual reduced cooldown fills green from bottom while still unavailable")
	for point in button._fill:
		_expect(point.y >= button._radius * (1 - 2 * button.progress) - 0.001, "fill polygon stays below its rising horizontal level")
	var event: = InputEventScreenTouch.new()
	event.index = 8
	event.position = button.get_global_rect().get_center()
	event.pressed = true
	controls._input(event)
	p._physics_process(0.001)
	_expect( not p.dashing, "tapping while gray/cooling cannot bypass the actual player cooldown")
	event.pressed = false
	controls._input(event)
	await create_timer(0.95, true, false, true).timeout
	controls._process(0)
	_expect(p.can_dash and button.available and button.progress == 1, "actual cooldown completion fills the entire button green")

	button.set_cooldown(0.9, false)
	button.set_cooldown(1, true)
	Engine.time_scale = 0.08
	await create_timer(0.1, true, false, true).timeout
	_expect(button.visual_scale > 1.1 and button.get_global_rect() == touch_rect and button.position == origin and button.size == original_size, "ready punch enlarges only drawing/label, leaving touch/layout bounds fixed through hitstop")
	var tween: Tween = button._bounce
	for _repeat in 10: controls._process(0)
	_expect(button._bounce == tween, "ready UI polling never restarts the one-time bounce")
	await create_timer(0.3, true, false, true).timeout
	Engine.time_scale = 1
	_expect(is_equal_approx(button.visual_scale, 1) and button._bounce == null, "one-time ready punch settles fully")
	button.play_ready_bounce()
	controls.hide_controls()
	_expect(button._bounce == null and button.visual_scale == 1, "hiding or leaving run cancels button feedback")
	p.reset_dash()
	p._start_dash(Vector2.RIGHT)
	p._on_dashing_timer_timeout()
	p.full_heal()
	_expect( not p.is_dash_invulnerable() and p.dashing_timer.is_stopped(), "full-heal interludes cancel grace and stale movement timeout")
	await main._launch_run(&"trial_speed")
	game = main.game
	_freeze(game)
	game.trials.start_button.pressed.emit()
	p = game.player
	p.set_physics_process(false)
	var wizard: Node = game.trials.enemy
	wizard.set_physics_process(false)
	wizard.teleport_near_player()
	p._start_dash(Vector2.RIGHT)
	p.dashing_timer.stop()
	p._on_dashing_timer_timeout()
	hp = p.player_health
	wizard._physics_process(0.51)
	wizard._physics_process(0.17)
	_expect( not p.dashing and p.player_health == hp and wizard.vulnerable(), "a real post-dash dodge also opens the speed trial counterattack window")
	game.trials.fail("test reset")
	game.trials.retry_button.pressed.emit()
	game.trials.enemy.set_physics_process(false)
	_expect( not p.is_dash_invulnerable() and p.can_dash and p.dash_grace_left == 0, "trial retry clears old grace and restores dash availability")
	main.on_game_over({"victory": false})
	await main._on_game_end_ui_retry_pressed()
	_expect(controls._player.get_ref() == main.game.player and not main.game.player.is_dash_invulnerable(), "run Retry binds the persistent button to the new player only")
	main.show_main_menu()
	if failures.is_empty(): print("DASH GRACE OK: exact post-dash 0.5s at 30/60 FPS/slow steps, all attack routes, shields/contact, actual pause/timers, trial dodge/retry, gray rising fill, fixed touch bounds, single ready punch and run ownership")
	else:
		for failure in failures: push_error(failure)
	paused = false
	quit(0 if failures.is_empty() else 1)
