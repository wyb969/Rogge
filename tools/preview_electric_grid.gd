extends Node
func _ready() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await main._launch_run(&"electric_grid")
	var g: Node = main.game
	g.spawner.timer.stop()
	g.spawner.get_node("Elite").stop()
	g.spawner.set_process(false)
	g.player.set_physics_process(false)
	g.variety.set_process(false)
	g.meteors.set_process(false)
	g.weather.set_process(false)
	g.weather._preview.hide()
	g.variety._notice.hide()
	g.variety._notice_left = 0
	g.level_manager.signal_level_up.disconnect(g.on_level_up)
	for path in ["HandWeapon","CircleWeapon","Weapon","DroneController","MolotovController","FreezeController"]: g.get_node(path).process_mode = Node.PROCESS_MODE_DISABLED
	var grid: Node = g.weather.electric_grid
	grid.set_physics_process(false)
	grid._physics_process(0.016)
	var p: Vector2 = g.player.global_position
	grid.strips.assign([Rect2(p+Vector2(-130,-85),Vector2(260,40)),Rect2(p+Vector2(-130,75),Vector2(260,40))])
	for offset in [Vector2(-85,-70),Vector2(-50,-50),Vector2(-20,-30),Vector2(15,-15),Vector2(45,5),Vector2(76,20),Vector2(110,35),Vector2(-70,100)]:
		var e = load("res://scenes/enemy_shell.tscn").instantiate()
		e.set_enemy_data(load("res://resource/Enemy_1.tres"))
		e.set_player_ref(g.player)
		e.add_to_group("EnemyGroup")
		g.add_child(e)
		e.health = 10000
		e.global_position = p+offset
		e.set_physics_process(false)
	grid._clock = 0.9
	grid._scan_enemies()
	g.player.global_position = p+Vector2(45,75)
	grid._player_at = g.player.global_position+grid.FOOT
	grid._touch_player()
	g.combat_feedback.set_process(false)
	g.player.get_node("Camera2D").global_position = p
	g.player.get_node("Camera2D").force_update_scroll()
	for size in [Vector2i(900,600),Vector2i(390,844)]:
		get_window().size = size
		for i in 12: await get_tree().process_frame
		grid.queue_redraw()
		grid._overlay.queue_redraw()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OS.get_environment("ROGGE_CAPTURE_DIR")+"/electric-%dx%d.png"%[size.x,size.y])
	main.queue_free()
	await get_tree().process_frame
	get_tree().quit()
