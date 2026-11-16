extends Node
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	var main=load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await settle()
	for lang in ["en","zh_CN"]:
		get_node("/root/SettingsStore").set_language(lang)
		await main._launch_run(&"")
		var game: Node=main.game
		game.spawner.timer.stop()
		game.spawner.get_node("Elite").stop()
		game.variety._notice.hide()
		main.mobile_controls.show_controls()
		main.mobile_controls.visible=true
		get_tree().paused=true
		for size in [Vector2i(900,600),Vector2i(390,844),Vector2i(320,568),Vector2i(844,390)]:
			get_window().size=size
			game.pause_menu.hide()
			await capture("dash-%s-%d.png"%[lang,size.x])
			var pool: Array=[]
			for entry in game.pause_menu.upgrade_pool:
				if entry.id in ["poison_trail","banana_fan","bomb"]:pool.append(entry)
			game.pause_menu.upgrade_pool=pool
			game.pause_menu.show_upgrade_options()
			await capture("cards-%s-%d.png"%[lang,size.x])
		main.show_main_menu()
	get_node("/root/SettingsStore").set_language("en")
	get_tree().quit()
func settle() -> void:
	for i in 8:await get_tree().process_frame
func capture(name: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("ROGGE_CAPTURE_DIR")+"/"+name)
