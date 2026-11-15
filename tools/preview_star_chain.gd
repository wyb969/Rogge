extends Node
func _ready() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await main._launch_run(&"star_chain")
	var game: Node = main.game
	game.spawner.timer.stop()
	game.spawner.get_node("Elite").stop()
	game.spawner.set_process(false)
	game.player.set_physics_process(false)
	game.level_manager.signal_level_up.disconnect(game.on_level_up)
	game.level_manager.level_need_coin_number = 100000
	game.star_chain.set_physics_process(false)
	game.weather.set_preview(0,0)
	game.variety._courier_left = 99999
	for path in ["HandWeapon", "CircleWeapon", "Weapon", "DroneController", "MolotovController", "FreezeController"]: game.get_node(path).process_mode = Node.PROCESS_MODE_DISABLED
	for size in [Vector2i(900,600),Vector2i(390,844)]:
		get_window().size = size
		for i in 8: await get_tree().process_frame
		game.star_chain.clear_combat_effects()
		game.star_chain.cooldown = 0
		game.star_chain.start_route()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OS.get_environment("ROGGE_CAPTURE_DIR")+"/route-%dx%d.png"%[size.x,size.y])
		for i in 3:
			game.player.global_position = game.star_chain._points[i]
			game.star_chain._physics_process(0.02)
		game.star_chain._magnet_batch()
		for i in 3: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OS.get_environment("ROGGE_CAPTURE_DIR")+"/fever-%dx%d.png"%[size.x,size.y])
	main.queue_free()
	await get_tree().process_frame
	get_tree().quit()
