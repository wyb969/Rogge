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
	var latest: int = main.game.spawner.FINAL_STAGE
	for stage_num in range(3, latest + 1):
		main._on_debug_button_pressed()
		main.get_node("mainUI/Control/DebugCenter/VBoxContainer/DebugBeast%dButton" % stage_num).pressed.emit()
		await process_frame
		await process_frame
		var game: Node = main.game
		var spawner: Node = game.spawner
		var powers: Node = game.beast_powers
		var player: Node = game.player
		game.level_manager.signal_level_up.disconnect(game.on_level_up)
		for name in ["HandWeapon", "CircleWeapon", "Weapon", "DroneController", "MolotovController", "FreezeController"]:
			game.get_node(name).process_mode = Node.PROCESS_MODE_DISABLED
		player.set_physics_process(false)
		spawner.set_process(false)
		powers.set_process(false)
		var bosses: = get_nodes_in_group("beast_boss")
		_expect(bosses.size() == (2 if stage_num == 5 else 1), "correct live guardian count from debug button %d" % stage_num)
		if bosses.is_empty():
			_finish()
			return
		var beast: Node = bosses[0]
		if stage_num == 5:
			for member in bosses:
				member.set_physics_process(false)
				if member.role == 1:
					beast = member
			for member in bosses:
				if member.role == 0:
					member.apply_hit({"damage": 1000000})
			await create_timer(1.2, true, false, true).timeout
			_expect( not paused and spawner._boss_fight_active, "wind partner remains active after ranged member defeat")
		beast.set_physics_process(false)
		var music: AudioStreamPlayer = root.get_node("AudioManager/BossAudioPlayer")
		_expect(music.stream.resource_path.contains("beast_" + beast.IDS[stage_num - 3]) and music.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "guardian uses its own original looping chiptune")
		_expect(beast.element == stage_num - 3 and beast.health_max_value == (2600.0 if stage_num == 5 else beast.HP[stage_num - 3]), "correct unique art/stats for stage %d" % stage_num)
		_expect(powers.unlocked.size() == stage_num - 3, "debug grants only prior blessings")
		player.max_player_health = 10000
		player.player_health = 10000
		beast.global_position = Vector2(5000, 5000)
		spawner.remove_far_enemy()
		_expect( not beast.is_queued_for_deletion(), "guardian cannot silently despawn when kited far away")
		beast.global_position = Vector2.ZERO
		player.global_position = Vector2(100, 0)
		beast.begin_attack()
		var hp: float = player.player_health
		beast._physics_process(0.4)
		_expect(player.player_health == hp and beast.state == beast.State.WARN, "warning causes no damage")

		var shape: Dictionary = beast.shapes[0]
		var target: Vector2 = shape.center if shape.kind == "circle" else ((shape.a + shape.b) * 0.5 if shape.kind == "lane" else shape.center + Vector2.RIGHT * (float(shape.inner) + float(shape.radius)) * 0.5)
		_expect(beast.attack_contains(target), "drawn attack shape contains its active target")
		if shape.kind == "ring":
			_expect( not beast.attack_contains(shape.center), "earth ring has a real safe center")
		player.global_position = target
		player.hurt_lock = 0
		beast._physics_process(0.7)
		beast._physics_process(0.01)
		if beast.dive:
			beast._physics_process(0.3)
		_expect(player.player_health < hp, "active elemental attack deals damage")
		hp = player.player_health
		player.hurt_lock = 0
		beast._physics_process(0.01)
		_expect(player.player_health == hp, "overlapping shapes cannot hit twice")
		beast.pattern_index = 1
		beast.begin_attack()
		_expect(stage_num == 5 or beast.shapes[0].kind != shape.kind or beast.dive, "each guardian has a second attack pattern")
		player.dashing = true
		beast._attack_hit = false
		beast._hit()
		_expect(player.player_health == hp, "dash immunity applies to elemental damage")
		player.dashing = false
		beast.apply_hit({"damage": beast.health_max_value * 0.51, "from_status": true})
		_expect(beast.phase == 2 and beast.state == beast.State.PHASE and beast.shapes.is_empty(), "half health clears old warnings and enters safe second phase")
		_expect(beast.warning_seconds() >= 0.75, "enraged warnings remain readable")
		beast._physics_process(1.2)
		beast.begin_attack()
		_expect(beast.shapes.size() >= 1, "second phase has valid attack geometry")
		if stage_num == 5:
			beast.pattern_index = 1
			beast.begin_attack()
			beast._physics_process(1.0)
			beast._physics_process(0.7)
			_expect(beast.state == beast.State.WARN and beast._extra_dives == 0, "phase-two falcon dive chains into a separately warned second dive")

		beast.apply_hit({"damage": 1000000})
		var deadline: = Time.get_ticks_msec() + 5000
		while powers._pending_reward < 0 and Time.get_ticks_msec() < deadline:
			await process_frame
		_expect(powers._pending_reward == stage_num and paused, "real defeat opens blessing reward")
		for reward_size in [Vector2i(390, 844), Vector2i(900, 500)]:
			root.size = reward_size
			await process_frame
			powers._layout_reward()
			await process_frame
			var screen: = Rect2(Vector2.ZERO, root.get_visible_rect().size)
			_expect(screen.encloses(powers.reward_claim.get_global_rect()), "blessing claim remains visible after reward-screen rotation")
		powers.reward_claim.pressed.emit()
		powers.reward_claim.pressed.emit()
		_expect(powers.unlocked.size() == stage_num - 2 and powers.selected == stage_num - 3, "reward unlocks exactly one icon and selects its power")
		await process_frame
		if stage_num == 4 or (stage_num == 6 and game.SPEED_TRIAL_ENABLED):
			await process_frame
			_expect(game.trials.flow == game.trials.TrialFlow.INTRO, "divine reward leads to the correct trial intro")
			game.trials.set_process(false)
			game.trials.start_button.pressed.emit()
			var trial_target: Node = game.trials.enemy
			trial_target.set_physics_process(false)
			if stage_num == 6:
				trial_target.teleport_near_player()
				player._start_dash(Vector2.RIGHT)
				trial_target._physics_process(0.51)
				trial_target._physics_process(0.17)
				player._on_dashing_timer_timeout()
			trial_target.apply_hit({"damage": 1000000})
			_expect(game.trials._passed, "real trial target can be defeated before progression resumes")
			game.trials.continue_button.pressed.emit()
			await process_frame
		if stage_num < latest:
			_expect(game.rest_hub.visible and paused, "blessing leads into rest before next stage")
			game.rest_hub._on_reward_pressed("max_hp")
			game.rest_hub.next_button.pressed.emit()
			await create_timer(1.25).timeout
			_expect(spawner.stage == stage_num + 1 and not paused, "normal route advances to the next guardian stage")
			spawner.timer.stop()
			spawner.get_node("Elite").stop()
		else:
			_expect(spawner._endless_trial and powers.finish_button.visible and not paused, "last reward allows a free trial with earned powers")
		spawner.timer.stop()
		spawner.get_node("Elite").stop()

		powers.select(0)
		player.player_health = player.max_player_health
		_expect( not powers.cast_selected() and powers.cooldowns[0] == 0, "full-health heal does not spend cooldown")
		player.player_health = player.max_player_health * 0.2
		_expect(powers.cast_selected() and is_equal_approx(player.player_health, player.max_player_health * 0.65), "earned healing restores exactly 45% max HP")
		_expect( not powers.cast_selected(), "cooldown blocks repeated cast")
		var cd: float = powers.cooldowns[0]
		paused = true
		powers._process(10)
		_expect(powers.cooldowns[0] == cd, "reward pause freezes earned-power cooldowns")
		paused = false
		powers._process(1)
		_expect(is_equal_approx(powers.cooldowns[0], cd - 1), "active cooldown counts down")
		if stage_num >= 4:
			await _check_thunder(game, powers)
		if stage_num >= 5:
			await _check_gale(game, powers)
		if stage_num >= 6:
			_check_aegis(player, powers)
		for size in [Vector2i(390, 844), Vector2i(900, 500)]:
			root.size = size
			await process_frame
			powers._layout()
			var bounds: = Rect2(Vector2.ZERO, root.get_visible_rect().size)
			for button in powers._buttons.values():
				_expect(bounds.encloses(button.get_global_rect()), "left blessing icon fits %s" % size)
		if stage_num >= 4:
			powers._buttons[0].pressed.emit()
			var key: = InputEventKey.new()
			key.physical_keycode = KEY_Q
			key.pressed = true
			powers._unhandled_input(key)
			_expect(powers.selected == 1, "Q cycles the actually selected left HUD power")
		var touch: = InputEventScreenTouch.new()
		touch.index = 15
		touch.pressed = true
		touch.position = powers._buttons[0].get_global_rect().get_center()
		_expect( not main.mobile_controls._handle_touch(touch), "joystick input yields presses on the skill button")

		if stage_num == latest:
			var result: = {"victory": false, "stage": 0}
			game.game_over.connect( func(stats: Dictionary): result.merge(stats, true))
			powers.finish_button.pressed.emit()
			_expect(result.victory and int(result.stage) == latest and paused, "free-trial settlement produces the real victory result")
		else:
			main.on_game_over({"victory": false})
		_expect(player.beast_damage_scale == 1.0, "end of run removes defensive effect")
		await main._on_game_end_ui_main_menu_pressed()
		_expect(main.game.beast_powers.unlocked.is_empty(), "fresh run clears blessings")
	_finish()

func _check_thunder(game: Node, powers: Node) -> void :
	var enemy: Node = game.spawner.enemy.instantiate()
	enemy.set_enemy_data(load("res://resource/Enemy_1.tres"))
	enemy.set_player_ref(game.player)
	enemy.setHealth(1000)
	enemy.add_to_group("EnemyGroup")
	current_scene.add_child(enemy)
	enemy.global_position = game.player.global_position + Vector2(40, 0)
	enemy.set_physics_process(false)
	var boss: Node = load("res://scenes/beast_boss.tscn").instantiate()
	boss.configure_stage(4)
	boss.set_player(game.player)
	boss.add_to_group("EnemyGroup")
	current_scene.add_child(boss)
	boss.global_position = game.player.global_position + Vector2(-70, 0)
	boss.set_physics_process(false)
	var offscreen: Node = game.spawner.enemy.instantiate()
	offscreen.set_enemy_data(load("res://resource/Enemy_1.tres"))
	offscreen.set_player_ref(game.player)
	offscreen.add_to_group("EnemyGroup")
	current_scene.add_child(offscreen)
	offscreen.global_position = game.player.global_position + Vector2(4000, 0)
	offscreen.set_physics_process(false)
	var offscreen_hp: float = offscreen.health
	var shot: Node = load("res://scenes/enemy_projectile.tscn").instantiate()
	game.effect_container.add_child(shot)
	shot.launch(game.player.global_position + Vector2(100, 0), Vector2.RIGHT, 100, 10, Color.YELLOW)
	powers.select(1)
	_expect(powers.cast_selected() and enemy.health < 1000, "thunder hits a real visible enemy")
	_expect(is_equal_approx(boss.boss_current_health, boss.health_max_value * 0.94), "thunder boss damage is exactly 6% without weapon-stance amplification")
	_expect(offscreen.health == offscreen_hp, "screen attack excludes offscreen enemies")
	_expect(shot.is_queued_for_deletion(), "thunder clears real on-screen enemy bullets")
	enemy.free()
	boss.free()
	offscreen.free()
	await create_timer(0.04, true, false, true).timeout

func _check_gale(game: Node, powers: Node) -> void :
	var orb: Node = load("res://scenes/healing_orb.tscn").instantiate()
	orb.configure(5, game.player)
	game.pickup_container.add_child(orb)
	orb.global_position = game.player.global_position + Vector2(130, 0)
	var coin: Node = load("res://scenes/coin.tscn").instantiate()
	coin.coin_collected.connect(game.on_coin_collected)
	game.pickup_container.add_child(coin)
	coin.global_position = game.player.global_position + Vector2(120, -40)
	game.level_manager.level_need_coin_number = 100000
	var xp: int = game.level_manager.coin_number
	var hp: float = game.player.player_health
	powers.select(2)
	_expect(powers.cast_selected() and orb.attracting and coin.start_pick, "gale starts real coin and orb attraction outside normal pickup radius")
	var deadline: = Time.get_ticks_msec() + 2000
	while (is_instance_valid(orb) or is_instance_valid(coin)) and Time.get_ticks_msec() < deadline:
		await process_frame
	_expect( not is_instance_valid(orb) and not is_instance_valid(coin), "gale pickups actually reach the player")
	_expect(game.level_manager.coin_number == xp + 2 and is_equal_approx(game.player.player_health, hp + 5), "gale preserves actual experience and healing rewards")
	powers.cooldowns[2] = 0
	_expect( not powers.cast_selected() and powers.cooldowns[2] == 0, "empty-screen gale does not consume cooldown")

func _check_aegis(player: Node, powers: Node) -> void :
	powers.select(3)
	var key: = InputEventKey.new()
	key.physical_keycode = KEY_E
	key.pressed = true
	powers._unhandled_input(key)
	_expect(powers.cooldowns[3] > 0 and powers.barrier_left == 6, "E activates the selected defensive power")
	var hp: float = player.player_health
	player.hurt_lock = 0
	player.damage_reduction = 0
	player.receive_attack(100)
	_expect(is_equal_approx(player.player_health, hp - 10), "aegis reduces actual incoming damage by 90%")
	player.damage_reduction = 0.5
	player.hurt_lock = 0
	hp = player.player_health
	player.receive_attack(100)
	_expect(is_equal_approx(player.player_health, hp - 5), "aegis stacks multiplicatively with rest defense")
	paused = true
	powers._process(30)
	_expect(powers.barrier_left == 6, "pause does not consume barrier duration")
	paused = false
	powers._process(6.1)
	_expect(player.damage_reduction == 0.5, "barrier expiry preserves permanent rest defense")
	_expect(player.beast_damage_scale == 1, "barrier expires without leaving permanent defense")

func _finish() -> void :
	if failures.is_empty():
		print("BEASTS OK: unique stage bosses, locked warning/damage geometry, two phases, dash immunity, real defeat rewards, left HUD, earned powers, cooldowns, progression and run reset")
	else:
		for failure in failures:
			push_error(failure)
	paused = false
	quit(0 if failures.is_empty() else 1)
