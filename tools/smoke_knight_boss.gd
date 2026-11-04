extends SceneTree
var failures: Array[String] = []

func _init() -> void :
	call_deferred("_run")

func _run() -> void :
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	main.get_node("mainUI/Control/MenuCenter/VBoxContainer/DebugButton").pressed.emit()
	var button: Button = main.get_node("mainUI/Control/DebugCenter/VBoxContainer/DebugKnightButton")
	button.pressed.emit()
	await process_frame
	await process_frame
	await physics_frame
	var game: Node = main.game
	var spawner: Node = game.spawner
	var player: Node = game.player
	for name in ["HandWeapon", "CircleWeapon", "Weapon", "DroneController", "MolotovController", "FreezeController"]:
		game.get_node(name).process_mode = Node.PROCESS_MODE_DISABLED
	player.set_physics_process(false)
	player.player_health = 10000.0
	var knight: Node
	for node in get_nodes_in_group("EnemyGroup"):
		if node.get_script() == load("res://script/knight_boss.gd"):
			knight = node
	_expect(knight != null, "debug button spawns the actual knight scene")
	if knight == null:
		quit(1)
		return
	knight.set_physics_process(false)
	_expect(spawner.stage == 2 and spawner._boss_fight_active, "debug entry is a stage-two boss fight")
	_expect( not paused and not main.main_ui.visible, "debug entry leaves menu pause and displays gameplay")
	_expect(spawner.timer.is_stopped() and spawner.get_node("Elite").is_stopped(), "debug entry suppresses minion timers")
	_expect(get_nodes_in_group("EnemyGroup").size() == 1, "debug entry has exactly one boss")
	_expect(game.gun_weapon.level == 2 and player.max_player_health == 725.0 and player.growth_level == 5, "debug build includes normal level growth and rest health without invincibility")
	_expect(knight.sprite_2d.texture.resource_path.ends_with("knight.png") and knight.sprite_2d.hframes == 8, "knight atlas uses real character frames")
	_expect(knight.health_max_value == 3200.0 and knight.health_bar.size.y == 26.0, "knight has 3200 HP and thicker bar")
	for viewport_size in [Vector2i(390, 844), Vector2i(900, 500)]:
		root.size = viewport_size
		await process_frame
		var bounds: = Rect2(Vector2.ZERO, root.get_visible_rect().size)
		_expect(bounds.encloses(knight.health_bar.get_global_rect()), "boss health HUD fits %s" % viewport_size)
		_expect(bounds.encloses(knight._title.get_global_rect()), "boss title fits %s" % viewport_size)
	var audio: Node = root.get_node("AudioManager")
	var boss_music: AudioStreamPlayer = audio.get_node("BossAudioPlayer")
	_expect(boss_music.stream.resource_path.ends_with("knight_boss_8bit.wav") and boss_music.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "stage two uses its own looping chiptune")
	audio.play_boss_bgm(1)
	_expect(boss_music.stream.resource_path.ends_with("boss_bgm.mp3"), "stage-one music remains selectable")
	audio.play_boss_bgm(2)

	knight.global_position = Vector2.ZERO
	player.global_position = Vector2(240, 0)
	knight._begin_dash()
	var hp: float = player.player_health
	player.global_position = Vector2(0, 240)
	knight._physics_process(0.1)
	_expect(is_zero_approx(knight.attack_angle) and player.player_health == hp, "dash warning locks aim and causes no damage")
	knight._physics_process(1.0)
	player.global_position = Vector2(180, 0)
	player.hurt_lock = 0.0
	knight._physics_process(0.4)
	_expect(player.player_health == hp - 80.0, "dash hits along the swept lane without tunneling")
	player.hurt_lock = 0.0
	knight._physics_process(0.01)
	_expect(player.player_health == hp - 80.0, "dash cannot hit twice")
	knight._physics_process(0.5)
	_expect(knight.attack_state == knight.AttackState.SLASH_WINDUP, "dash chains into a warned sword attack")

	knight.global_position = Vector2.ZERO
	player.global_position = Vector2(70, 0)
	knight._begin_slash()
	hp = player.player_health
	player.hurt_lock = 0.0
	knight._physics_process(0.3)
	_expect(player.player_health == hp, "red sword warning is harmless")
	_expect(knight.slash_contains(Vector2(110, 0)) and not knight.slash_contains(Vector2(114, 0)), "sword radius matches its warning")
	_expect( not knight.slash_contains(Vector2(-70, 0)) and not knight.slash_contains(Vector2(0, 90)), "back and sides outside the sector are safe")
	knight._physics_process(0.5)
	knight._physics_process(0.01)
	_expect(player.player_health == hp - 75.0, "sword damages only during active swing")
	player.hurt_lock = 0.0
	knight._physics_process(0.01)
	_expect(player.player_health == hp - 75.0, "one sword swing deals at most one hit")

	player.dashing = true
	knight.attack_hit = false
	hp = player.player_health
	knight._physics_process(0.01)
	_expect(player.player_health == hp, "player dash invulnerability works against the sword")
	player.dashing = false
	knight._begin_slash()
	player.global_position = Vector2(-70, 0)
	knight._physics_process(1.0)
	knight._physics_process(0.01)
	_expect(player.player_health == hp, "dodging behind the boss avoids the locked sword sector")




	var body_origin: = Vector2(0, -8)
	var max_body_offset: = 0.0
	knight.last_hitstop_msec = Time.get_ticks_msec() + 10000
	for i in range(40):
		knight.apply_hit({"damage": 1.0, "direction": Vector2.LEFT, "from_status": true, "ignore_side_bonus": true})
		knight.hurt_tween.custom_step(0.025)
		knight.global_position += Vector2(4, -2)
		max_body_offset = maxf(max_body_offset, knight.sprite_2d.position.distance_to(body_origin))
		_expect(knight._sword.global_position.is_equal_approx(knight.to_global(Vector2(0, 8))), "sword stays attached to moving boss")
	_expect(max_body_offset <= 6.01, "repeated interrupted hits cannot separate body and sword (offset %.2f)" % max_body_offset)
	knight.hurt_tween.custom_step(0.3)
	_expect(knight.sprite_2d.position.is_equal_approx(body_origin), "hit feedback returns to the original body anchor")

	var old_windup: float = knight.slash_windup_seconds()
	var old_recover: float = knight.recovery_seconds()
	knight.apply_hit({"damage": 960.0})
	_expect(knight.phase == 1, "knight does not use the dinosaur's 72% phase transition")
	knight.apply_hit({"damage": 672.0})
	_expect(knight.phase == 2 and knight.attack_state == knight.AttackState.PHASE_SHIFT, "half health enters phase two with a safe transition")
	_expect(knight.slash_windup_seconds() < old_windup and knight.recovery_seconds() < old_recover, "phase two increases attack frequency")
	_expect(knight.slash_windup_seconds() >= 0.45 and knight.dash_windup_seconds() >= 0.6, "phase two keeps readable warning times")
	knight._physics_process(1.2)
	_expect(knight.attack_state == knight.AttackState.APPROACH, "phase transition resumes attacks")

	var result: = {"victory": false}
	game.game_over.connect( func(stats: Dictionary) -> void : result["victory"] = stats.get("victory", false))
	knight.apply_hit({"damage": 100000.0})
	await create_timer(1.3, true, false, true).timeout
	_expect( not result["victory"] and game.rest_hub.visible and paused, "defeating stage-two knight opens the rest gate to stage three")
	_expect(is_equal_approx(Engine.time_scale, 1.0), "boss death restores time scale")
	if failures.is_empty():
		print("KNIGHT BOSS OK: debug entry, music, warned dash/slash, geometry, two phases, invulnerability and third-stage rest gate")
	else:
		for failure in failures:
			push_error(failure)
	paused = false
	quit(0 if failures.is_empty() else 1)

func _expect(ok: bool, message: String) -> void :
	if not ok:
		failures.append(message)
