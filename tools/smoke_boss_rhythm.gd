extends SceneTree
var failures: Array[String] = []
var main: Node
var game: Node
func _init() -> void : call_deferred("_run")
func expect(ok: bool, message: String) -> void :
	if not ok: failures.append(message)
func freeze_run() -> void :
	game.spawner.set_process(false)
	game.spawner.timer.stop()
	game.spawner.get_node("Elite").stop()
	game.player.set_physics_process(false)
	game.player.max_player_health = 1000000
	game.player.player_health = 1000000
	game.level_manager.signal_level_up.disconnect(game.on_level_up)
	for name in ["HandWeapon", "CircleWeapon", "Weapon", "DroneController", "MolotovController", "FreezeController"]: game.get_node(name).process_mode = Node.PROCESS_MODE_DISABLED
func _run() -> void :
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	await main._launch_run(&"")
	game = main.game
	freeze_run()
	var player: Node = game.player
	var boss: Node = load("res://scenes/boss.tscn").instantiate()
	boss.set_player(player)
	game.add_child(boss)
	boss.add_to_group("EnemyGroup")
	boss.set_physics_process(false)
	boss.rush_timer.stop()
	boss.global_position = Vector2(-160, 0)
	boss.start_charge_attack()
	var target: Vector2 = boss.target_position
	player.global_position = Vector2(20, 35)
	boss._physics_process(0.12)
	expect( not boss.warning_locked and boss.target_position != target, "windup tracks actual player movement before the final lock")
	boss._physics_process(0.41)
	expect(boss.warning_locked, "a visible final lock stops targeting before the charge")
	target = boss.target_position
	player.global_position += Vector2(100, -100)
	boss._physics_process(0.2)
	expect(boss.target_position == target and boss.line.visible and boss.line.modulate.a > 0.99, "last warning stays visible and locked when the player dodges")
	var hp: float = player.player_health
	player.global_position = boss.global_position
	boss._try_contact_damage()
	expect(player.player_health == hp, "body overlap during a harmless warning cannot deal damage")
	player.global_position = Vector2.ZERO
	boss.global_position = Vector2(-200, 0)
	boss.charge_direction = Vector2.RIGHT
	boss.target_position = Vector2(200, 0)
	boss._distance_left = 400
	boss.rush_feedback.path_changed()
	var inside: = Vector2(0, 40)
	var outside: = Vector2(0, 100)
	expect(boss.rush_feedback.sweep_hits(boss.global_position, boss.target_position, inside) and Geometry2D.is_point_in_polygon(inside, boss.rush_feedback._polygon), "swept hurt boxes and the visible corridor include the same side hit")
	expect( not boss.rush_feedback.sweep_hits(boss.global_position, boss.target_position, outside) and not Geometry2D.is_point_in_polygon(outside, boss.rush_feedback._polygon), "a point outside the footprint is genuinely outside the swept attack")
	player.hurt_lock = 0
	boss._contact_left = 0
	boss.start_moving_charge()
	boss._physics_process(0.8)
	expect(player.player_health == hp - 60 and boss.charge_state == boss.ChargeState.RECOVER, "a slow frame cannot tunnel over the player or apply two hits")
	player.hurt_lock = 0
	boss.global_position = player.global_position
	boss._try_contact_damage()
	expect(player.player_health == hp - 60, "the visible recovery is a real safe counterattack opening")
	boss._physics_process(0.7)
	boss.rush_timer.stop()
	boss.boss_current_health = boss.health_max_value * 0.5
	boss._attack_round = 1
	boss.global_position = Vector2(-130, 0)
	var attacks: int = boss.charges_started
	boss.start_charge_attack()
	expect(boss._combo_left == 1 and boss.warning_duration() >= 0.7, "phase two alternates a bounded double rush while retaining readable anticipation")
	boss._physics_process(0.73)
	boss._physics_process(0.6)
	expect(boss.charge_state == boss.ChargeState.RECOVER and boss._combo_left == 1, "double rush has a distinct inter-rush breathing beat")
	boss._physics_process(0.35)
	expect(boss.charge_state == boss.ChargeState.WARN and not boss.warning_locked and boss._state_left >= 0.7, "second rush gets its own full new warning")
	expect(boss.lock_seconds() >= 0.9, "the follow-up leaves enough locked time to walk out while dash is cooling down")
	var walk_distance: float = player.SPEED * (boss.lock_seconds() - 0.17)
	var walk_exit: Vector2 = player.global_position + boss.charge_direction.orthogonal() * walk_distance
	expect( not boss.rush_feedback.sweep_hits(boss.global_position, boss.target_position, walk_exit), "an unupgraded player has a real perpendicular walking escape with reaction/acceleration allowance")
	boss._physics_process(boss.warning_duration() + 0.01)
	boss._physics_process(0.6)
	expect(boss.charges_started == attacks + 2 and boss.charge_state == boss.ChargeState.RECOVER and boss._combo_left == 0, "double rush ends after exactly two charges")
	for size in [Vector2i(390, 844), Vector2i(1920, 1080)]:
		root.size = size
		await process_frame
		await process_frame
		boss.rush_feedback._layout()
		expect(Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses(boss.rush_feedback._panel.get_global_rect()), "first boss HUD and rhythm strip fit portrait and landscape")
	main.show_main_menu()
	expect( not boss.rush_feedback._panel.visible, "first-boss canvas HUD is explicitly hidden on menu return")
	for stage in [3, 4, 5, 6]:
		await main._launch_run(StringName("beast_%d" % stage))
		game = main.game
		freeze_run()
		var members: Array = game.spawner._active_bosses.duplicate()
		for member in members: member.set_physics_process(false)
		for member in members:
			member.global_position = Vector2(90, 0)
			game.player.global_position = Vector2.ZERO
			member.state = member.State.APPROACH
			member.state_left = 3
			var before: Vector2 = member.global_position


			member.set_physics_process(true)
			for _i in 8: await physics_frame
			member.set_physics_process(false)
			expect(member.global_position.distance_to(before) > 2, "each live guardian actively repositions even at close range")
			member.global_position = Vector2(100, 0)
			member._physics_process(0.01)
			var speed: float = member.velocity.length()
			member.global_position = Vector2(100, 0)
			member.poison_slow = 0.5
			member._physics_process(0.01)
			expect(is_equal_approx(member.velocity.length(), speed * 0.5), "new roaming keeps the existing poison slow")
			member.poison_slow = 1
			member.global_position = Vector2(-150, 0)
			member.pattern_index = 1
			member.begin_attack()
			var geometry: Array = member.shapes.duplicate(true)
			var at: Vector2 = member.global_position
			game.player.global_position += Vector2(15, 30)
			member._physics_process(member.warning_seconds() * 0.5)
			expect(member.global_position == at and member.shapes == geometry, "moving bosses still freeze their world attack geometry for the full warning")
			member._physics_process(member.warning_seconds() * 0.5 + 0.001)
			if stage != 5 or member.role == 1:
				expect(member.dive, "water, thunder, magma and wind melee have real movement attacks")
				member._physics_process(0.1)
				expect(member.global_position != at and member.attack_visual._dive_to == member.global_position, "attribute effects travel with the actual damaging body")
				member._physics_process(2)
				expect(member.state == member.State.RECOVER, "movement attack has a finite endpoint and a recovery opening")
			else:
				expect(member._shots_fired > 0, "wind ranged keeps actual projectiles instead of becoming a second melee boss")
			member.last_hitstop_msec = Time.get_ticks_msec() + 100000
			member.apply_hit({"damage": member.health_max_value * 0.55, "from_status": true, "ignore_side_bonus": true})
			expect(member.phase == 2 and member.state == member.State.PHASE and member.shapes.is_empty(), "phase transition cancels movement warnings/attacks safely")
		main.show_main_menu()
		for member in members: expect( not member._hud.visible and not member.attack_visual.visible, "guardian canvas HUDs and world effects close before the next menu/frame")
	if failures.is_empty(): print("BOSS RHYTHM OK: tracking/visible lock/swept real hurt geometry/safe anticipation and opening, bounded two-rush phase/HUD, all guardian close-range movement/slow, frozen warnings, finite elemental travel, wind roles and phase cancellation")
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
