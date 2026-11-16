extends Node
func _ready() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await main._launch_run(&"ice_scene")
	var g: Node = main.game
	g.spawner.timer.stop()
	g.spawner.get_node("Elite").stop()
	g.spawner.set_process(false)
	g.player.set_physics_process(false)
	g.banana_fan.set_physics_process(false)
	g.black_hole.set_physics_process(false)
	g.variety._courier_left = 99999
	g.weather._preview.hide()
	g.variety._notice.hide()
	g.variety._notice_left = 0
	g.level_manager.signal_level_up.disconnect(g.on_level_up)
	for path in ["HandWeapon", "CircleWeapon", "Weapon", "DroneController", "MolotovController", "FreezeController"]: g.get_node(path).process_mode = Node.PROCESS_MODE_DISABLED
	var p: Vector2 = g.player.global_position
	var sample_enemy: Node2D
	for offset in [Vector2(-70,-70),Vector2(80,70),Vector2(-85,85)]:
		var e = load("res://scenes/enemy_shell.tscn").instantiate()
		e.set_enemy_data(load("res://resource/Enemy_1.tres"))
		e.set_player_ref(g.player)
		e.health = 10000
		e.add_to_group("EnemyGroup")
		g.add_child(e)
		e.global_position = p+offset
		e.set_physics_process(false)
		sample_enemy = e
	var warning = g.enemy_attacks.cast(sample_enemy, &"mortar")
	if warning != null:
		warning.target = p+Vector2(-15,-75)
		warning.age = 0.5
	g.enemy_attacks.set_physics_process(false)
	g.poison_trail.upgrade()
	g.poison_trail.set_process(false)
	g.poison_trail._clouds[0].at = p+Vector2(35,85)
	g.poison_trail._clouds[0].left = g.poison_trail.CLOUD_LIFE
	g.poison_trail.queue_redraw()
	g.spawn_healing_orb(p+Vector2(40,30),5)
	g.spawn_xp_coin(p+Vector2(30,-95),2)
	g.spawn_xp_coin(p+Vector2(48,-95),2)
	var bullet = load("res://scenes/enemy_projectile.tscn").instantiate()
	g.add_child(bullet)
	bullet.launch(p+Vector2(35,-55), Vector2.RIGHT, 0, 0, GamePalette.ENEMY_RED)
	bullet.set_physics_process(false)
	for kind in [4,5]:
		g.weather.set_preview(kind,0)
		for size in [Vector2i(900,600),Vector2i(390,844)]:
			get_window().size = size
			for i in 12: await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(OS.get_environment("ROGGE_CAPTURE_DIR")+"/surface-%d-%dx%d.png"%[kind,size.x,size.y])
	main.queue_free()
	await get_tree().process_frame
	get_tree().quit()
