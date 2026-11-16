extends Node
var g: Node
var grid: Node
var actors: Array[Node] = []
func _ready() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await main._launch_run(&"electric_grid")
	g = main.game
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
	grid = g.weather.electric_grid
	grid.set_physics_process(false)
	grid._physics_process(0.016)
	var p: Vector2 = g.player.global_position
	grid.zones.clear()
	for i in 4:
		var center := p+Vector2(-90 if i%2==0 else 90,-70 if i<2 else 70)
		grid.zones.append(grid.make_zone(Rect2(center-Vector2(42,42),Vector2(84,84)),i%2==0))
		var e = load("res://scenes/enemy_shell.tscn").instantiate()
		e.set_enemy_data(load("res://resource/Enemy_%d.tres"%[1,3,4,5][i]))
		e.set_player_ref(g.player)
		e.add_to_group("EnemyGroup")
		g.add_child(e)
		e.health = 10000
		e.global_position = center
		e.set_physics_process(false)
		e.set_process(false)
		actors.append(e)
	grid._clock = 0.9
	grid._scan_enemies()
	grid._zap(g.player)
	g.combat_feedback.set_process(false)
	var camera: Camera2D = g.player.get_node("Camera2D")
	camera.global_position = p
	camera.force_update_scroll()
	for size in [Vector2i(900,600),Vector2i(390,844)]:
		await capture("zones",size)
	for actor in actors: actor.queue_free()
	await get_tree().process_frame
	grid._zaps.clear()
	grid._links.clear()
	grid.zones.clear()
	get_window().size = Vector2i(900,600)
	camera.zoom = Vector2.ONE
	for i in 6:
		var path: String = ["boss","knight_boss","beast_boss","beast_boss","beast_boss","beast_boss"][i]
		var actor = load("res://scenes/"+path+".tscn").instantiate()
		if i>=2: actor.configure_stage(i+1)
		actor.set_player(g.player)
		g.add_child(actor)
		actor.set_physics_process(false)
		actor.set_process(false)
		actor.rush_timer.stop()
		actor.suspend_feedback()
		actor.health_bar.hide()
		actor.global_position = p+Vector2((i%3-1)*250,-85 if i<3 else 155)
		grid._zap(actor)
		var label := Label.new()
		label.text = ["DINOSAUR","KNIGHT","TIDE","THUNDER","GALE","AEGIS"][i]
		label.position = actor.global_position+Vector2(-55,92)
		label.z_index = 40
		g.add_child(label)
	await capture("boss-skeletons",Vector2i(900,600))
	main.queue_free()
	await get_tree().process_frame
	get_tree().quit()

func capture(title: String, size: Vector2i) -> void:
	get_window().size = size
	for i in 12: await get_tree().process_frame
	grid.queue_redraw()
	grid._overlay.queue_redraw()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("ROGGE_CAPTURE_DIR")+"/%s-%dx%d.png"%[title,size.x,size.y])
