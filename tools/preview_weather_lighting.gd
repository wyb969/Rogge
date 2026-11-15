extends Node
func _ready() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await main._launch_run(&"weather")
	var game: Node = main.game
	game.spawner.timer.stop()
	game.spawner.get_node("Elite").stop()
	game.spawner.set_process(false)
	game.variety._courier_left = 99999
	game.weather._preview.hide()
	game.player.set_physics_process(false)
	for path in ["HandWeapon", "CircleWeapon", "Weapon", "DroneController", "MolotovController", "FreezeController"]: game.get_node(path).process_mode = Node.PROCESS_MODE_DISABLED
	for offset in [Vector2(50,0), Vector2(-65,40), Vector2(100,-70), Vector2(-100,-70), Vector2(80,70)]:
		var actor = load("res://scenes/enemy_shell.tscn").instantiate()
		actor.set_player_ref(game.player)
		actor.set_enemy_data(load("res://resource/Enemy_1.tres"))
		actor.health = 10000
		actor.add_to_group("EnemyGroup")
		game.add_child(actor)
		actor.global_position = game.player.global_position + offset
		actor.set_physics_process(false)
	for size in [Vector2i(900,600), Vector2i(390,844)]:
		get_window().size = size
		for kind in [0,2]:
			game.weather.set_preview(kind, 0.0 if kind == 0 else 0.5)
			for i in 8: await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(OS.get_environment("ROGGE_CAPTURE_DIR") + "/weather-%d-%dx%d.png" % [kind,size.x,size.y])
	main.queue_free()
	await get_tree().process_frame
	get_tree().quit()
