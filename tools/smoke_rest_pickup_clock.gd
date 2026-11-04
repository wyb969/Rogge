extends SceneTree
var failures: Array[String] = []

func _init() -> void :
	call_deferred("_run")

func _expect(ok: bool, message: String) -> void :
	if not ok:
		failures.append(message)

func _run() -> void :
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	await main._on_start_button_pressed()
	var game: Node = main.game
	var spawner: Node = game.spawner
	var player: Node = game.player
	for name in ["HandWeapon", "CircleWeapon", "Weapon", "DroneController", "MolotovController", "FreezeController"]:
		game.get_node(name).process_mode = Node.PROCESS_MODE_DISABLED
	player.set_physics_process(false)
	spawner.set_process(false)
	spawner.timer.stop()
	spawner.get_node("Elite").stop()

	game.level_manager.signal_level_up.disconnect(game.on_level_up)
	_expect(player.monster_necklace_level == 0, "fixture starts without the necklace")
	player.player_health = 400.0
	spawner._boss_fight_active = true
	spawner.spawn_boss()
	var first_boss: Node
	for node in get_nodes_in_group("EnemyGroup"):
		if node.has_signal("boss_defeated"):
			first_boss = node
	first_boss.apply_hit({"damage": 1000000})
	var deadline: = Time.get_ticks_msec() + 5000
	while ( not is_instance_valid(game.rest_hub) or not game.rest_hub.visible) and Time.get_ticks_msec() < deadline:
		await process_frame
	_expect(is_instance_valid(game.rest_hub) and game.rest_hub.visible and paused, "real boss defeat opens paused rest")
	if not is_instance_valid(game.rest_hub):
		_finish()
		return
	for button in game.rest_hub._buttons:
		if str(button.get_meta("reward_id")) == "monster_necklace":
			button.pressed.emit()
	_expect(player.monster_necklace_level == 0, "actual rest button only previews the first necklace")
	_expect(player.player_health == player.max_player_health, "rest starts the next stage at full health")
	game.rest_hub.next_button.pressed.emit()
	_expect(player.monster_necklace_level == 1 and game.equipment_panel.get_level("monster_necklace") == 1, "actual confirmation grants the first necklace")
	await create_timer(1.3).timeout
	spawner.timer.stop()
	spawner.get_node("Elite").stop()
	_expect( not paused and spawner.stage == 2, "next stage really resumes world processing")

	await _kill_and_pickup(spawner, player, 0.0, "full-health post-rest pickup")
	player.hurt_lock = 0.0
	player.receive_attack(40.0, null)
	var injured_hp: float = player.player_health
	_expect(injured_hp < player.max_player_health, "actual enemy damage leaves healing room")
	await _kill_and_pickup(spawner, player, 5.0, "injured post-rest pickup")
	game._on_upgrade_selected("monster_necklace")
	await _kill_and_pickup(spawner, player, 10.0, "stacked post-rest pickup")


	spawner.stage = 3
	spawner._mini_spawned = true
	spawner._mini_cleared = false
	spawner._mini_reward_claimed = false
	spawner._boss_fight_active = true
	spawner.run_seconds = 10.0
	spawner._sync_run_clock()
	for _i in 20:
		spawner._on_timer_timeout()
	_expect(spawner.run_seconds == 10.0 and spawner.second == 10, "spawn ticks do not accelerate the run clock")
	spawner._process(1.0)
	_expect(spawner.run_seconds == 11.0, "boss combat still advances time while spawn timer is stopped")
	paused = true
	spawner._process(30.0)
	_expect(spawner.run_seconds == 11.0, "upgrade/lottery pause does not count")
	paused = false
	spawner._rest_open = true
	spawner._process(30.0)
	_expect(spawner.run_seconds == 11.0, "rest time does not count")
	spawner._rest_open = false
	spawner._transitioning = true
	spawner._process(30.0)
	_expect(spawner.run_seconds == 11.0, "stage transition breather does not count")
	spawner._transitioning = false
	spawner._boss_fight_active = false
	spawner.stage_boss_countdown = 0.001
	spawner._process(1.0)
	_expect( not spawner._boss_fight_active and spawner.stage_boss_countdown > 190, "old stage-local countdown cannot spawn the final boss early")
	spawner.run_seconds = 210.0
	spawner._process(0.01)
	_expect( not spawner._boss_fight_active, "03:30 still waits for a living guardian")
	spawner._mini_cleared = true
	spawner._process(0.01)
	_expect( not spawner._boss_fight_active, "03:30 still waits for the unclaimed slot reward")
	spawner.complete_treasure_reward()
	spawner.run_seconds = 209.5
	spawner._process(0.49)
	_expect( not spawner._boss_fight_active and spawner.minute == 3 and spawner.second == 29, "03:29.99 does not trigger the boss")
	_expect(spawner.get_node("UI/HBoxContainer/Mintue").text == "03" and spawner.get_node("UI/HBoxContainer/Second").text == "29", "HUD displays the actual total combat time")
	spawner._process(0.02)
	_expect(spawner._boss_fight_active and spawner.stage == 3 and spawner.minute == 3 and spawner.second == 30, "03:30 starts the final warning without entering stage four")
	await create_timer(2.4).timeout
	var knights: = 0
	for node in get_nodes_in_group("EnemyGroup"):
		if node.get_script() == load("res://script/beast_boss.gd"):
			knights += 1
	_expect(knights == 1, "the scheduled warning spawns exactly one real water guardian")
	_finish()

func _kill_and_pickup(spawner: Node, player: Node, expected_heal: float, description: String) -> void :
	var hp: float = player.player_health
	var pos: Vector2 = player.global_position + Vector2(40, 0)
	spawner.spawn(pos, false)
	for enemy in get_nodes_in_group("EnemyGroup"):
		if enemy.global_position.is_equal_approx(pos):
			enemy.set_physics_process(false)
			enemy.take_damage(1000000)
			break
	_expect(get_nodes_in_group("healing_orb").size() == 1, description + ": kill drops one orb")
	var deadline: = Time.get_ticks_msec() + 2000

	while not get_nodes_in_group("healing_orb").is_empty() and Time.get_ticks_msec() < deadline:
		await process_frame
	_expect(get_nodes_in_group("healing_orb").is_empty(), description + ": real attraction and collection work")
	_expect(is_equal_approx(player.player_health, hp + expected_heal), description + ": correct capped health")
	var audio: AudioStreamPlayer = root.get_node("AudioManager/HealingPickupAudioPlayer")
	_expect(audio.playing, description + ": collection plays its sound")
	await process_frame

func _finish() -> void :
	if failures.is_empty():
		print("REST PICKUP / CLOCK OK: first necklace from real boss rest; automatic full/injured/stacked collection and audio; active-time HUD, pause exclusions, 03:30 final boss and guardian/reward gates")
	else:
		for failure in failures:
			push_error(failure)
	paused = false
	quit(0 if failures.is_empty() else 1)
