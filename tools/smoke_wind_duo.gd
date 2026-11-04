extends SceneTree
var failures: Array[String] = []
var main: Node
func _init() -> void :
	call_deferred("_run")
func _expect(ok: bool, message: String) -> void :
	if not ok:
		failures.append(message)
func _enter() -> Node:
	await main._launch_run(&"beast_5")
	var game: Node = main.game
	game.level_manager.signal_level_up.disconnect(game.on_level_up)
	game.spawner.set_process(false)
	game.player.set_physics_process(false)
	game.player.player_health = 50000
	game.player.max_player_health = 50000
	for name in ["HandWeapon", "CircleWeapon", "Weapon", "DroneController", "MolotovController", "FreezeController"]:
		game.get_node(name).process_mode = Node.PROCESS_MODE_DISABLED
	return game
func _members() -> Array[Node]:
	var found: = get_nodes_in_group("beast_boss")
	found.sort_custom( func(a, b): return a.role < b.role)
	return found
func _run() -> void :
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	var game: Node = await _enter()
	var members: = _members()
	_expect(members.size() == 2, "debug creates exactly two real wind bosses")
	if members.size() != 2:
		_finish()
		return
	var ranged: Node = members[0]
	var melee: Node = members[1]
	_expect(ranged.get_parent() == game and melee.get_parent() == game, "both wind bosses are owned by the active game run")
	_expect(ranged.role == 0 and melee.role == 1, "one distinct ranged and one distinct melee role")
	_expect(ranged.health_max_value + melee.health_max_value == 4800, "combined HP preserves the previous encounter budget")
	_expect(ranged.sprite_2d.texture != melee.sprite_2d.texture, "roles have distinguishable blue and gold art")
	var start_ranged: Vector2 = ranged.global_position
	var start_melee: Vector2 = melee.global_position
	await create_timer(6.5).timeout
	_expect(ranged.global_position.distance_to(start_ranged) > 10, "ranged boss really repositions under normal physics")
	_expect(melee.global_position.distance_to(start_melee) > 10, "melee boss really chases/dives under normal physics")
	_expect(ranged._shots_fired >= 3 and melee.pattern_index >= 1, "both roles autonomously attack without test-driven state updates")
	game.spawner.spawn_boss()
	game.spawner.spawn_boss()
	_expect(_members().size() == 2, "repeated spawn requests cannot create duplicates")
	ranged.set_physics_process(false)
	melee.set_physics_process(false)
	for shot in get_nodes_in_group("enemy_projectile"):
		shot.free()

	ranged.phase = 1
	ranged.global_position = Vector2(-220, 0)
	game.player.global_position = Vector2.ZERO
	ranged.begin_attack()
	var hp: float = game.player.player_health
	game.player.hurt_lock = 0
	ranged._physics_process(0.5)
	_expect(game.player.player_health == hp, "ranged windup is harmless")
	ranged._physics_process(0.6)
	_expect(game.player.player_health == hp, "ranged firing does not instantly damage the entire warning lane")
	var shots: = get_nodes_in_group("enemy_projectile")
	_expect(shots.size() == 3, "ranged shot launches three actual travelling wind blades")
	var center_shot: Node = shots[1]
	var origin: Vector2 = center_shot.global_position
	center_shot._physics_process(0.1)
	_expect(is_equal_approx(center_shot.global_position.distance_to(origin), 14.5), "wind blades travel at the readable 145 speed")
	center_shot.global_position = game.player.global_position
	game.player.hurt_lock = 0
	center_shot._physics_process(0)
	_expect(game.player.player_health == hp - 48, "wind blade collision deals the actual ranged damage")
	for shot in get_nodes_in_group("enemy_projectile"):
		if not shot.is_queued_for_deletion():
			shot.queue_free()
	for size in [Vector2i(390, 844), Vector2i(900, 500)]:
		root.size = size
		await process_frame
		await process_frame
		ranged._layout_hud()
		melee._layout_hud()
		var bounds: = Rect2(Vector2.ZERO, root.get_visible_rect().size)
		_expect(bounds.encloses(ranged.health_bar.get_global_rect()) and bounds.encloses(melee.health_bar.get_global_rect()), "both health bars fit portrait and landscape")
		_expect( not ranged.health_bar.get_global_rect().intersects(melee.health_bar.get_global_rect()), "ranged and melee health bars do not overlap")

	for first_role in [0, 1]:
		game = await _enter()
		members = _members()
		for boss in members:
			boss.set_physics_process(false)
		var first: Node = members[first_role]
		var survivor: Node = members[1 - first_role]
		var reward_count: = {"value": 0}
		game.spawner.beast_defeated.connect( func(_stage): reward_count.value += 1)
		var kills: int = game.spawner.enemy_killed_num
		first.apply_hit({"damage": 1000000})
		await _wait_dead(first)
		_expect(_members().size() == 1 and game.spawner._boss_fight_active, "first defeat keeps the remaining boss fight active")
		_expect(reward_count.value == 0 and game.beast_powers._pending_reward < 0 and not paused, "first defeat grants no premature blessing or rest")
		survivor.state = survivor.State.APPROACH
		survivor.state_left = 0
		survivor._physics_process(0.02)
		_expect(survivor.state == survivor.State.WARN, "survivor keeps attacking after its partner dies")
		survivor.apply_hit({"damage": 1000000})
		await _wait_dead(survivor)
		await process_frame
		_expect(_members().is_empty() and reward_count.value == 1 and paused, "only the second defeat opens one paused blessing reward")
		_expect(game.spawner.enemy_killed_num == kills + 2, "two real defeats count exactly two kills")
		game.spawner.spawn_boss()
		_expect(_members().is_empty(), "cleared encounter cannot respawn behind the reward")
		game.beast_powers.reward_claim.pressed.emit()
		await process_frame
		_expect(game.beast_powers.unlocked.has(2) and game.rest_hub.visible, "duo clear grants Gale Gather once and opens rest")
		game.rest_hub._on_reward_pressed("max_hp")
		game.rest_hub.next_button.pressed.emit()
		await create_timer(1.25).timeout
		_expect(game.spawner.stage == 6 and not paused, "duo encounter advances into stage six normally")

	game = await _enter()
	for boss in _members():
		boss.free()
	game.spawner._active_bosses.clear()
	game.spawner._boss_fight_active = false
	game.spawner.boss_show_up()
	game.spawner.spawn_boss()
	await create_timer(2.4).timeout
	_expect(_members().size() == 2, "pending-warning/direct-entry race still leaves exactly one pair")

	game = await _enter()
	for boss in _members():
		boss.free()
	game.spawner._active_bosses.clear()
	game.spawner._boss_fight_active = false
	game.spawner.boss_show_up()
	main.on_game_over({"victory": false})
	await create_timer(2.4, true, false, true).timeout
	_expect(_members().is_empty() and game.spawner._run_closed, "ending during the delayed banner cancels the late spawn")
	await main._on_game_end_ui_retry_pressed()
	_expect(_members().size() == 2 and main._test_mode == &"beast_5", "Retry recreates one active ranged/melee pair")
	_finish()

func _wait_dead(node: Node) -> void :
	var deadline: = Time.get_ticks_msec() + 4000
	while is_instance_valid(node) and Time.get_ticks_msec() < deadline:
		await process_frame

func _finish() -> void :
	if failures.is_empty():
		print("WIND DUO OK: two moving/attacking roles, real travelling blades, independent HP/HUD, both kill orders, survivor AI, one final reward, next stage and duplicate-spawn races")
	else:
		for failure in failures:
			push_error(failure)
	paused = false
	quit(0 if failures.is_empty() else 1)
