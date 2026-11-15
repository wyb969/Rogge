extends SceneTree
var failures: Array[String] = []
var checks := 0
func _init() -> void: call_deferred("_run")
func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
func _enemy(g: Node, at: Vector2) -> Node2D:
	var e = load("res://scenes/enemy_shell.tscn").instantiate()
	e.set_enemy_data(load("res://resource/Enemy_1.tres"))
	e.set_player_ref(g.player)
	e.add_to_group("EnemyGroup")
	g.add_child(e)
	e.global_position = at
	e.health = 1
	e.set_physics_process(false)
	e.death_signal.connect(g.spawner.on_enemy_killed.bind(e))
	return e
func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await main._launch_run(&"")
	var g: Node = main.game
	g.spawner.timer.stop()
	g.spawner.get_node("Elite").stop()
	g.spawner.set_process(false)
	g.variety._courier_left = 99999
	g.player.set_physics_process(false)
	g.level_manager.signal_level_up.disconnect(g.on_level_up)
	g.level_manager.level_need_coin_number = 100000
	for path in ["HandWeapon","CircleWeapon","Weapon","DroneController","MolotovController","FreezeController"]: g.get_node(path).process_mode = Node.PROCESS_MODE_DISABLED
	var s: Node = g.star_chain
	s.set_physics_process(false)
	expect(s._running and s.charge == 0 and not s._hud.visible, "normal run begins clean without an unsolicited event")
	var p: Vector2 = g.player.global_position
	for i in 18:
		var e := _enemy(g,p+Vector2(120+i,70))
		e.apply_hit({"damage":10000.0,"from_status":true,"source":s})
		expect(s.charge == i+1, "real death signal charges once")
		s.note_kill(e)
		expect(s.charge == i+1, "duplicate death cannot charge again")
	expect(s._seen.size() == 18, "deduplication history is bounded by charge threshold")
	s._physics_process(0.001)
	expect(s.route_left > 0 and s.step == 0 and s.charge == 0 and s._points.size() == 3, "18 real kills create one three-point route")
	var bounds: Rect2 = (root.get_canvas_transform().affine_inverse()*root.get_visible_rect()).grow(-27)
	for at in s._points: expect(bounds.has_point(at), "route points start inside visible play space")
	paused = true
	var left: float = s.route_left
	await create_timer(0.05,true,false,true).timeout
	expect(s.route_left == left, "card pause does not consume route time")
	paused = false
	s._points = PackedVector2Array([p+Vector2(40,0),p+Vector2(90,0),p+Vector2(140,0)])
	s._last_at = p+Vector2(180,0)
	g.player.global_position = p
	s._physics_process(0.1)
	expect(s.step == 1, "reverse crossing does not collect later stars earlier along the same segment")
	s.clear_combat_effects()
	s.cooldown = 0
	g.player.global_position = p
	s.start_route()
	s._points = PackedVector2Array([p+Vector2(40,0),p+Vector2(90,0),p+Vector2(140,0)])
	s._last_at = p
	g.player.global_position = p+Vector2(170,0)
	var wins: int = s.completed
	s._physics_process(0.1)
	expect(s._notes == [1.0,1.25,1.5], "one-frame dash queues three bounded ascending notes instead of overwriting audio")
	expect(s.step == 3 and s.completed == wins+1 and s.fever_left == 5, "fast forward crossing collects all three in order and starts fever")
	s._collect_path(p,p+Vector2(170,0))
	expect(s.completed == wins+1, "completed route cannot reward twice")
	await process_frame
	var reward_count := 0
	for coin in g._xp_actors:
		coin.set_process(false)
		if coin.xp_value == 8+2*g.spawner.stage: reward_count += 1
	expect(reward_count == 1, "exactly one real XP bonus drop created")
	for i in 40: g._spawn_xp_coin_now(g.player.global_position+Vector2(80,i),2)
	g._spawn_xp_coin_now(g.player.global_position+Vector2(400,0),2)
	var far: Node = g._xp_actors.back()
	for coin in g._xp_actors: coin.set_process(false)
	var admitted: int = s.magnet_started
	s._magnet_batch()
	expect(s.magnet_started-admitted <= 12 and s.magnet_started > admitted, "magnet starts at most twelve actual pickups per batch")
	for i in 20: s._magnet_batch()
	expect(not far.start_pick, "fever does not collect beyond 180 world units")
	var picked := 0
	for coin in g._xp_actors:
		if coin.start_pick: picked += 1
	expect(picked >= 40, "rolling scan eventually reaches nearby coins without restarting them")
	var hp: float = g.player.player_health
	var speed: float = g.player.effective_move_speed()
	s._physics_process(6)
	expect(s.fever_left == 0 and g.player.player_health == hp and g.player.effective_move_speed() == speed, "fever expires without damage/speed stat mutation")
	s.clear_combat_effects()
	s.cooldown = 0
	s.start_route()
	s.route_left = 0.01
	s._last_at = p
	g.player.global_position = p
	s._physics_process(1)
	expect(s.route_left == 0 and s.cooldown == 35 and s.completed == wins+1, "route timeout gives no reward and starts rest period")
	expect(not s.start_route(), "cooldown prevents farming repeat events")
	s.cooldown = 0
	s.start_route()
	s._points[0] = p+Vector2(300,0)
	s._last_at = p
	g.player.global_position = p+Vector2(500,0)
	s._physics_process(0.1)
	expect(s.step == 0, "teleports do not collect stars")
	g.spawner._boss_fight_active = true
	s._physics_process(0.1)
	expect(s.route_left == 0 and not s._hud.visible and not s.start_route(), "boss entry cancels route and blocks new ones")
	g.spawner._boss_fight_active = false
	s.cooldown = 0
	g.player.movement_locked = true
	expect(not s.start_route(), "movement-locked trial cannot require a moving objective")
	g.player.movement_locked = false
	g.trials.flow = g.trials.TrialFlow.ACTIVE
	expect(not s.start_route(), "active trial blocks optional rewards even when combat is active")
	g.trials.flow = g.trials.TrialFlow.IDLE
	var nodes := get_node_count()
	var children: int = s.get_child_count()
	for i in 120: s._process(0.016)
	expect(get_node_count() == nodes and s.get_child_count() == children and s._points.size() == 3, "render updates keep fixed nodes and route buffer")
	main.show_main_menu()
	expect(not s._running and not s._hud.visible and s.fever_left == 0, "return clears objective, HUD and bonus")
	await main._launch_run(&"star_chain")
	expect(main.game.star_chain.route_left > 0 and main.game.player.max_player_health > 500, "Debug starts real route and grants training health")
	main.game.star_chain._debug_button.pressed.emit()
	expect(main.game.star_chain.route_left == 8 and main.game.star_chain.owns_pointer(main.game.star_chain._debug_button.get_global_rect().get_center()), "Debug replay is immediate and owns its touch area")
	main.show_main_menu()
	await main._launch_run(&"")
	expect(main.game.star_chain.completed == 0 and main.game.star_chain.route_left == 0 and main.game.player.max_player_health == 500, "normal new game does not inherit Debug event or health")
	main.show_main_menu()
	if failures.is_empty(): print("STAR CHAIN OK: %d checks; real kills/duplicate gate, route order/sweeps, reward once, magnet bounds, expiry/pause/boss/trial/reset and fixed nodes" % checks)
	else:
		for message in failures: push_error(message)
	quit(0 if failures.is_empty() else 1)
