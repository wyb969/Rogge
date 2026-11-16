extends Node
var trails: Node
var g: Node
func _ready() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await main._launch_run(&"wind_scene")
	g = main.game
	g.spawner.timer.stop()
	g.spawner.get_node("Elite").stop()
	g.spawner.set_process(false)
	g.player.set_physics_process(false)
	g.weather.set_process(false)
	g.combat_feedback.set_process(false)
	g.variety.set_process(false)
	g.variety._notice.hide()
	g.weather._preview.hide()
	g.meteors.set_process(false)
	for field in [g.weather.minefield,g.weather.electric_grid,g.weather.spikes]:
		field.stop()
		field.set_physics_process(false)
	for path in ["HandWeapon","CircleWeapon","Weapon","DroneController","MolotovController","FreezeController"]: g.get_node(path).process_mode = Node.PROCESS_MODE_DISABLED
	trails = g.weather.surface.wind_trails
	var camera: Camera2D = g.player.get_node("Camera2D")
	camera.global_position = g.player.global_position
	camera.force_update_scroll()
	for size in [Vector2i(900,600),Vector2i(390,844),Vector2i(640,420)]:
		get_window().size = size
		for i in 10: await get_tree().process_frame
		trails.stop()
		trails._rng.seed = 241
		g.weather.surface.sync()
		trails.set_process(false)
		for i in 50: trails.advance(1.0/60)
		await capture("wind-%dx%d.png"%[size.x,size.y])
		if size.x==640:
			for i in 48:
				trails.advance(1.0/24)
				await capture("motion-%02d.png"%i)
	main.queue_free()
	await get_tree().process_frame
	get_tree().quit()
func capture(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("ROGGE_CAPTURE_DIR")+"/"+file)
