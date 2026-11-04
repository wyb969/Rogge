extends SceneTree
var failures: Array[String] = []
func _init() -> void : call_deferred("_run")
func _expect(ok: bool, message: String) -> void :
	if not ok: failures.append(message)
func _run() -> void :
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	await main._launch_run(&"")
	var game: Node = main.game
	game.diagnostic_mode = "boss_overlap_test"
	game.spawner.set_process(false)
	game.spawner.timer.stop()
	game.spawner.get_node("Elite").stop()
	for name in ["HandWeapon", "CircleWeapon", "Weapon", "DroneController", "MolotovController", "FreezeController"]:
		game.get_node(name).process_mode = Node.PROCESS_MODE_DISABLED
	var player: Node = game.player
	player.max_player_health = 10000
	player.player_health = 10000
	player.health_bar.set_max_health(10000, 10000)
	var boss: = _spawn(game, Vector2(-150, 0))
	var line_id: int = boss.line.get_instance_id()
	Engine.max_fps = 10
	boss.start_charge_attack()
	await create_timer(4.5).timeout
	_expect(boss.charges_started >= 2 and boss.global_position.distance_to(player.global_position) < 200, "10-FPS real movement cannot overshoot and remain in one infinite charge")
	_expect(player.player_health <= 9880, "actual continuous contact still damages a stationary player after the first entry")
	_expect(boss.line.get_instance_id() == line_id and boss.line.get_parent() == boss, "repeated attacks reuse one run-owned warning")
	Engine.max_fps = 60
	boss.set_physics_process(false)
	boss.rush_timer.stop()

	boss.charge_state = boss.ChargeState.WAIT
	boss.is_charging = false
	boss.global_position = Vector2(-150, 0)
	boss.start_charge_attack()
	boss._physics_process(1)
	boss._physics_process(0.5)
	_expect(boss.global_position.distance_to(boss.target_position) < 0.01 and boss.charge_state == boss.ChargeState.RECOVER, "slow frames clamp movement to the endpoint instead of stepping across it")
	boss._physics_process(0.7)
	_expect( not boss.rush_timer.is_stopped(), "recovery always rearms the next attack")
	boss.rush_timer.stop()
	boss.global_position = player.global_position
	boss.start_charge_attack()
	_expect(boss.charge_direction.length() > 0.99 and boss.target_position.distance_to(boss.global_position) >= 79.99, "exact overlap chooses a nonzero step-out direction")
	var warning_left: float = boss._state_left
	paused = true
	boss._physics_process(5)
	_expect(boss._state_left == warning_left, "a paused warning cannot advance to a hidden attack")
	paused = false
	boss._physics_process(1)
	boss._physics_process(0.5)
	_expect( not boss.is_charging and boss.charge_state == boss.ChargeState.RECOVER, "a zero-distance starting overlap still ends and recovers")
	boss._physics_process(0.7)
	boss.rush_timer.stop()
	boss.global_position = Vector2(-2000, 0)
	player.global_position = Vector2(8000, 0)
	boss.start_charge_attack()
	boss._physics_process(1)
	boss._physics_process(3)
	_expect( not boss.is_charging and boss.charge_state == boss.ChargeState.RECOVER, "even a very distant locked target has a finite charge time")
	boss._physics_process(0.7)
	boss.rush_timer.stop()

	player.global_position = Vector2.ZERO
	boss.global_position = Vector2(-180, 0)
	var wall: = StaticBody2D.new()
	wall.collision_layer = 1
	var shape: = CollisionShape2D.new()
	var rectangle: = RectangleShape2D.new()
	rectangle.size = Vector2(20, 400)
	shape.shape = rectangle
	wall.add_child(shape)
	game.add_child(wall)
	wall.global_position = Vector2(-70, 0)
	await physics_frame
	await physics_frame
	boss.start_charge_attack()
	boss._physics_process(1)
	boss._physics_process(0.5)
	_expect(boss.charge_state == boss.ChargeState.RECOVER and boss.global_position.x < -70, "a real world collision cannot trap the charging state")
	wall.queue_free()
	await physics_frame
	await physics_frame

	boss._physics_process(0.7)
	boss.rush_timer.stop()
	var children: int = boss.get_child_count()
	for _cycle in 100:
		boss.global_position = Vector2(-150, 0)
		boss.start_charge_attack()
		boss._physics_process(1)
		boss._physics_process(0.5)
		boss._physics_process(0.7)
		boss.rush_timer.stop()
	_expect(boss.get_child_count() == children and boss.line.get_instance_id() == line_id, "one hundred attacks reuse the same warning and do not accumulate delayed nodes")

	boss.charge_state = boss.ChargeState.CHARGE
	boss.is_charging = true
	boss.charge_speed = 0
	boss._distance_left = 80
	boss._state_left = boss.MAX_CHARGE_SECONDS
	boss.global_position = player.global_position
	boss.rush_timer.stop()
	player.hurt_lock = 0
	player.shield = 0
	await physics_frame
	await physics_frame
	var hp: float = player.player_health
	boss._contact_left = 0
	boss._try_contact_damage()
	_expect(player.player_health == hp - 60, "exact overlap uses the existing 60-damage player pipeline")
	player.hurt_lock = 0
	boss._physics_process(0.79)
	_expect(player.player_health == hp - 60, "contact cannot stack faster than its own attack interval")
	boss._physics_process(0.02)
	_expect(player.player_health == hp - 120, "remaining inside the same body does not permanently disable damage")
	player.hurt_lock = 0
	player._start_dash(Vector2.RIGHT)
	player._on_dashing_timer_timeout()
	player.velocity = Vector2.ZERO
	boss.global_position = player.global_position
	boss._contact_left = 0
	hp = player.player_health
	await create_timer(0.32).timeout
	boss._try_contact_damage()
	_expect(player.is_dash_invulnerable() and player.player_health == hp, "post-dash grace still protects an overlapping player")
	var deadline: = Time.get_ticks_msec() + 1500
	while player.is_dash_invulnerable() and Time.get_ticks_msec() < deadline: await physics_frame
	await physics_frame
	await physics_frame
	player.hurt_lock = 0
	boss._try_contact_damage()
	_expect(player.player_health == hp - 60, "overlap becomes damaging again when actual dash grace expires")
	player.hurt_lock = 0
	player.shield = 100
	boss._contact_left = 0
	hp = player.player_health
	boss._try_contact_damage()
	_expect(player.player_health == hp and player.shield == 40, "contact continues to respect kill shields")
	boss.charge_state = boss.ChargeState.WAIT
	boss.is_charging = false
	boss.start_charge_attack()
	var warning: Node = boss.line
	boss.queue_free()
	await process_frame
	await process_frame
	_expect( not is_instance_valid(warning), "freeing a warning-state boss also frees the warning without a stale callback")
	main.show_main_menu()
	await main._launch_run(&"boss1")
	_expect(main.game.spawner._active_bosses.size() == 1 and main.game.spawner._active_bosses[0].global_position.distance_to(main.game.player.global_position) < 0.1, "actual first-boss Debug reproduces overlap with normal health/damage rules")
	main.show_main_menu()
	Engine.max_fps = 0
	paused = false
	if failures.is_empty(): print("FIRST BOSS OVERLAP OK: actual 10-FPS cycles, endpoint clamping, overlap direction/recovery, distant/time/solid interruption, pause, repeat contact, real dash grace/shield and owned warning cleanup")
	else:
		for message in failures: push_error(message)
	quit(0 if failures.is_empty() else 1)
func _spawn(game: Node, at: Vector2) -> Node:
	var boss: Node = load("res://scenes/boss.tscn").instantiate()
	boss.set_player(game.player)
	boss.add_to_group("EnemyGroup")
	game.add_child(boss)
	boss.rush_timer.stop()
	boss.global_position = at
	return boss
