extends SceneTree
var failures: Array[String] = []
func _init() -> void :
	call_deferred("_run")
func _expect(ok: bool, message: String) -> void :
	if not ok: failures.append(message)
func _run() -> void :
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	for stage in range(3, 7):
		await main._launch_run(StringName("beast_%d" % stage))
		var game: Node = main.game
		var bosses: = get_nodes_in_group("beast_boss")
		game.level_manager.signal_level_up.disconnect(game.on_level_up)
		game.spawner.set_process(false)
		game.player.set_physics_process(false)
		game.player.max_player_health = 1000000
		game.player.player_health = 1000000
		for name in ["HandWeapon", "CircleWeapon", "Weapon", "DroneController", "MolotovController", "FreezeController"]:
			game.get_node(name).process_mode = Node.PROCESS_MODE_DISABLED
		for boss in bosses: boss.set_physics_process(false)
		var visuals: = get_nodes_in_group("elemental_attack_visual")
		_expect(visuals.size() == bosses.size(), "exactly one reusable renderer per live boss")
		for boss in bosses:
			var fx: Node = boss.attack_visual
			var id: int = fx.get_instance_id()
			for phase in [1, 2]:
				for pattern in range(3):
					boss.phase = phase
					boss.pattern_index = pattern
					boss.global_position = Vector2(-150, 0)
					game.player.global_position = Vector2.ZERO
					game.player.hurt_lock = 0
					boss.begin_attack()
					var builds: int = fx.build_count
					var geometry: Array = boss.shapes.duplicate(true)
					_expect(fx.visible and not fx.active and not fx.is_processing(), "warning is a cached harmless footprint")
					_expect(fx.geometry == geometry and fx.geometry.size() <= 5, "warning and elemental effects use the real damage geometry")
					var before: float = game.player.player_health
					boss._physics_process(boss.warning_seconds() * 0.5)
					_expect(game.player.player_health == before, "red warning has no premature damage")
					game.player.global_position += Vector2(10, 40)
					_expect(fx.geometry == geometry and fx.global_transform == Transform2D.IDENTITY, "telegraph and its visual remain world-locked after the player moves")
					boss._physics_process(boss.warning_seconds() * 0.5 + 0.001)
					_expect(fx.active and fx.is_processing() and fx.element == stage - 3, "warning-to-active transition starts the matching elemental renderer")
					_expect(fx.build_count == builds, "activation reuses prepared geometry instead of rebuilding it per frame")
					var ranged: bool = stage == 5 and boss.role == 0
					if ranged:
						_expect(fx.mode == "projectile" and game.player.player_health == before, "ranged guidance is not an instantaneous lane-wide hit")
						var shots: = get_nodes_in_group("enemy_projectile")
						_expect(shots.size() == (5 if phase == 2 else 3), "real travelling wind gusts launch in both phases")
						for shot in shots:
							_expect(is_equal_approx(shot.life * shot.velocity.length(), 345), "wind blade travel ends at the warned endpoint")
							shot.free()
						_expect(boss.shapes[0].width == 18, "wind lane covers the actual projectile hit radius")
					elif boss.dive:
						game.player.global_position = boss.dive_start + (boss.dive_end - boss.dive_start).normalized() * 40
						boss._physics_process(0.12)
						_expect(fx.mode == "dive" and fx._dive_to == boss.global_position and fx._dive_to != fx._dive_from, "wind melee effect follows the actual swept body segment")
						var dive_damage: float = (88 if phase == 2 else 74) if stage == 5 else (65 + float(stage - 3) * 8 + (15 if phase == 2 else 0))
						_expect(game.player.player_health == before - dive_damage, "visible elemental dive keeps its real damage")
					else:
						var shape: Dictionary = geometry[0]
						var target: Vector2
						if shape.kind == "lane":
							target = (shape.a + shape.b) * 0.5
							var cap: Vector2 = shape.a - (shape.b - shape.a).normalized() * shape.width * 0.95
							_expect(boss.attack_contains(cap) and Geometry2D.is_point_in_polygon(cap, fx._detail[0].fill), "warning capsule covers its damaging round endpoint")
						else:
							target = shape.center
							if shape.kind == "ring":
								_expect( not boss.attack_contains(shape.center) and fx.geometry[0].inner == shape.inner, "magma ring retains its genuinely safe central hole")
								target += Vector2.RIGHT * (shape.inner + shape.radius) * 0.5
						game.player.global_position = target
						boss._physics_process(0.01)
						_expect(game.player.player_health == before - (65 + (stage - 3) * 8 + (15 if phase == 2 else 0)), "elemental footprint still deals its original attack damage")
					boss.state = boss.State.RECOVER
					boss._update_attack_visual()
					_expect( not fx.visible and not fx.active and fx.geometry.is_empty(), "recovery clears the damaging presentation immediately")
			seed(969)
			var next_roll: = randi()
			seed(969)
			for _i in range(200): boss.begin_attack()
			_expect(randi() == next_roll, "cached lightning jitter does not consume combat RNG")
			_expect(fx.get_instance_id() == id and fx.get_child_count() == 0 and fx.geometry.size() <= 5 and fx._detail.size() <= 5, "hundreds of attacks reuse one node and bounded CPU geometry")
			boss.phase = 1
			boss.apply_hit({"damage": boss.health_max_value * 0.51, "from_status": true})
			_expect( not fx.visible and fx.geometry.is_empty(), "phase transition cancels pending elemental attacks")
		game.end_game()
		await process_frame
		await process_frame
		_expect(get_nodes_in_group("elemental_attack_visual").is_empty(), "run teardown removes all boss renderers")
	if failures.is_empty(): print("ELEMENTAL ATTACKS OK: all four elements/both wind roles, both phases/patterns, exact damage/world geometry, safe ring hole, travelling gust range, renderer reuse/RNG and cancellation/teardown")
	else:
		for failure in failures: push_error(failure)
	paused = false
	quit(0 if failures.is_empty() else 1)
