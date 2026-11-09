extends SceneTree

var failures: Array[String] = []

func _init() -> void: call_deferred("_run")

func _expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	await main._launch_run(&"boss1")
	var game: Node = main.game
	game.spawner.set_process(false)
	game.spawner.timer.stop()
	game.spawner.get_node("Elite").stop()
	game.player.set_physics_process(false)
	for node_name in ["HandWeapon", "CircleWeapon", "Weapon", "DroneController", "MolotovController", "FreezeController"]:
		game.get_node(node_name).process_mode = Node.PROCESS_MODE_DISABLED
	var boss: Node = game.spawner._active_bosses[0]
	boss.set_physics_process(false)
	boss.collision_mask = 0
	boss.rush_timer.stop()
	boss.global_position = Vector2.ZERO
	game.player.global_position = Vector2(-180, 0)
	boss.charge_state = boss.ChargeState.CHARGE
	boss.charge_direction = Vector2.RIGHT
	boss.sprite_2d.flip_h = false
	boss.stop_charge()
	_expect(boss.sprite_2d.flip_h and boss.animation_player.current_animation == &"idle", "charge completion immediately faces a player who dodged behind the boss")
	game.player.global_position = Vector2(180, 0)
	boss._physics_process(0.05)
	_expect(not boss.sprite_2d.flip_h and boss.charge_state == boss.ChargeState.RECOVER, "recovery follows the player's side without restarting a rush")
	boss._physics_process(1.0)
	for player_side in [-1.0, 1.0]:
		boss.global_position = Vector2.ZERO
		game.player.global_position = Vector2(200 * player_side, 0)
		boss.rush_timer.start(10.0)
		boss._physics_process(0.1)
		_expect(boss.sprite_2d.flip_h == (player_side < 0) and boss.velocity.x * player_side > 0, "approach motion and facing agree on either side")
		_expect(boss.animation_player.current_animation == &"walk" and boss.animation_player.is_playing(), "moving approach uses the looping walk animation instead of idle or the rush pose")
		boss.animation_player.advance(0.35)
		var walking_frame: int = boss.sprite_2d.frame
		boss.animation_player.advance(0.7)
		_expect(boss.animation_player.is_playing() and boss.sprite_2d.frame == walking_frame, "walking frames continue looping rather than freezing after the first clip")
		boss.rush_timer.stop()
		boss._physics_process(0.05)
		_expect(boss.velocity == Vector2.ZERO and boss.animation_player.current_animation == &"idle", "a stopped approach returns to an actual idle pose")
	boss.global_position = Vector2.ZERO
	boss.sprite_2d.flip_h = true
	boss.update_facing_direction(Vector2(0.4, 180))
	_expect(boss.sprite_2d.flip_h, "near-vertical alignment preserves facing instead of jittering between sides")
	game.player.global_position = Vector2(200, 0)
	boss.start_charge_attack()
	_expect(boss.animation_player.current_animation == &"idle" and not boss.sprite_2d.flip_h, "windup faces the target and stops walking in place")
	boss._physics_process(boss.warning_duration() - boss.lock_seconds() + 0.001)
	_expect(boss.warning_locked, "warning locks before the charge")
	var direction: Vector2 = boss.charge_direction
	game.player.global_position = Vector2(-200, 0)
	boss._physics_process(0.05)
	_expect(not boss.sprite_2d.flip_h and boss.charge_direction == direction, "a locked warning keeps its announced direction when the player crosses behind")
	boss._physics_process(1.0)
	_expect(boss.charge_state == boss.ChargeState.CHARGE and not boss.sprite_2d.flip_h and boss.animation_player.current_animation == &"chase", "the actual dash uses its locked direction and rush animation")
	for _i in 20:
		if boss.charge_state != boss.ChargeState.CHARGE: break
		boss._physics_process(0.1)
	_expect(boss.charge_state == boss.ChargeState.RECOVER and boss.sprite_2d.flip_h, "the next recovery turns back toward the player after the finite rush")
	main.show_main_menu()
	if failures.is_empty(): print("BOSS FACING OK: immediate recovery turn, live approach direction and walk loop, idle transitions, vertical stability and locked warning/dash facing")
	else:
		for failure in failures: push_error(failure)
	paused = false
	main.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
