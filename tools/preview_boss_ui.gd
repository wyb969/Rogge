extends Node
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	var main=load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await settle()
	for stage in [1,2,3,4,5,6]:
		await main._launch_run(&"")
		var g: Node=main.game
		g.spawner.timer.stop()
		g.spawner.get_node("Elite").stop()
		g.spawner.stage=stage
		g.spawner.spawn_boss()
		g.variety._notice.hide()
		get_tree().paused=true
		for size in [Vector2i(900,600),Vector2i(390,844)]:
			get_window().size=size
			await capture("boss-%d-%d.png"%[stage,size.x])
			for b in g.spawner._active_bosses:
				print("HUD ",stage," ",size," ",b.health_bar.visible," tree:",b.health_bar.is_visible_in_tree()," value:",b.health_bar.value," rect:",b.health_bar.get_global_rect())
		if stage==1:
			g.spawner._active_bosses[0].apply_electric_stun(1)
			await capture("boss-shocked.png")
			print("AFTER SHOCK HUD ",g.spawner._active_bosses[0].health_bar.is_visible_in_tree())
		main.show_main_menu()
	get_tree().quit()
func settle() -> void:
	for i in 5:await get_tree().process_frame
func capture(name: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("ROGGE_CAPTURE_DIR")+"/"+name)
