extends SceneTree
var main: Node
var game: Node


var directory: = ProjectSettings.globalize_path("user://visual-style")
func _init() -> void : call_deferred("_run")
func shot(label: String) -> void :
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory + "/" + label + ".png")
func _run() -> void :
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): directory = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(directory)
	seed(969)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	await main._launch_run(&"")
	game = main.game
	game.spawner.timer.stop()
	game.spawner.get_node("Elite").stop()
	game.spawner.set_process(false)
	game.player.set_physics_process(false)
	game.level_manager.signal_level_up.disconnect(game.on_level_up)
	game.variety.set_process(false)
	for name in ["HandWeapon", "Weapon", "DroneController", "MolotovController", "FreezeController"]:
		game.get_node(name).process_mode = Node.PROCESS_MODE_DISABLED
	game.player.get_node("Camera2D").position_smoothing_enabled = false
	game.player.get_node("Camera2D").offset = Vector2.ZERO
	game.combat_feedback.set_process(false)
	game.get_node("InfiniteBackground")._apply_palette(2)
	game.weather.set_preview(0, 0)
	game.weather.set_process(false)
	game.player.add_shield_level()
	game.player.notify_enemy_killed()
	game.player.shield = 120
	game.player._sync_shield_visuals()
	for i in 5:
		var actor: Node = load("res://scenes/enemy_shell.tscn").instantiate()
		actor.set_player_ref(game.player)
		actor.set_enemy_data(load(["res://resource/Enemy_1.tres", "res://resource/Enemy2.tres", "res://resource/Enemy_3.tres", "res://resource/Enemy_4.tres", "res://resource/Enemy_5.tres"][i]))
		actor.add_to_group("EnemyGroup")
		game.add_child(actor)
		actor.global_position = [Vector2(-145, -70), Vector2(120, -80), Vector2(150, 85), Vector2(-155, 75), Vector2(78, 5)][i]
		actor.set_physics_process(false)
		if i == 0: actor.set_elite_status()
		if i == 4:
			actor.dash_windup = 0.25
			actor.dash_dir = Vector2.LEFT
			actor.queue_redraw()
	for at in [Vector2(-90, 40), Vector2(75, -45), Vector2(95, 65)]:
		var bullet: Node = load("res://scenes/enemy_projectile.tscn").instantiate()
		game.effect_container.add_child(bullet)
		bullet.launch(at, Vector2.RIGHT, 150, 30, load("res://resource/Enemy_4.tres").marker_color)
		bullet.set_physics_process(false)
	game.player.monster_necklace_level = 1
	for i in 10:
		var at: = Vector2(-105 + i * 23, 130 + float(i % 3) * 12)
		game._spawn_xp_coin_now(at, 2)
		var orb: Node = game.spawn_necklace_orb(at + Vector2(0, 28))
		orb.set_physics_process(false)
	game.circle_weapon.set_process(false)
	for unit in game.circle_weapon.get_children(): unit.set_process(false)
	await shot("01-combat-day")
	game.weather.set_preview(2, 0.5)
	await shot("02-combat-rain-night")
	for _i in 9: game._on_upgrade_selected("circle_up")
	for unit in game.circle_weapon.get_children(): unit.set_process(false)
	var positions: Array[Vector2] = [Vector2(-145, -70), Vector2(120, -80), Vector2(150, 85), Vector2(-155, 75)]
	var bolt: Node = game.show_lightning_strikes(positions, game.LIGHTNING_FX.VIOLET)
	bolt.set_process(false)
	bolt.age = 0.08
	await shot("03-late-lightning")
	bolt.queue_free()
	root.size = Vector2i(390, 844)
	game.weather.set_preview(3, 0)
	await shot("04-phone-snow")
	root.size = Vector2i(1920, 1080)
	game.clear_enemies()
	await process_frame
	game.spawner.debug_start_beast(6)
	var boss: Node = game.spawner._active_bosses[0]
	boss.set_physics_process(false)
	boss.global_position = Vector2(105, -25)
	boss.shapes.clear()
	boss.shapes.append({"kind": "ring", "center": Vector2.ZERO, "radius": 170.0, "inner": 90.0})
	boss.state = boss.State.WARN
	boss._update_attack_visual()
	await shot("05-boss-warning")
	boss.state = boss.State.ACTIVE
	boss._update_attack_visual()
	boss.attack_visual.set_process(false)
	boss.attack_visual.age = 0.1
	await shot("06-boss-active")
	main.show_main_menu()
	print("VISUAL STYLE NATIVE OK ", directory)
	quit()
