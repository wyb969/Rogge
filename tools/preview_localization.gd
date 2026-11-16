extends Node
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await settle()
	var store := get_node("/root/SettingsStore")
	for lang in ["en","zh_CN"]:
		store.set_language(lang)
		for size in [Vector2i(900,600),Vector2i(390,844)]:
			get_window().size = size
			await settle()
			main.show_main_menu()
			await capture("menu-%s-%d.png"%[lang,size.x])
			main._on_setting_button_pressed()
			await settle()
			main.settings_page._scroll.scroll_vertical = 0
			await capture("settings-%s-%d.png"%[lang,size.x])
			main.settings_page.close_page()
			main._on_debug_button_pressed()
			await capture("debug-%s-%d.png"%[lang,size.x])
			main._on_debug_back_pressed()
		await main._launch_run(&"")
		get_tree().paused = true
		var game: Node = main.game
		var pool: Array = []
		for entry in game.pause_menu.upgrade_pool:
			if entry.id in ["rune_bolt","banana_fan","holy_water"]:pool.append(entry)
		game.pause_menu.upgrade_pool = pool
		for size in [Vector2i(900,600),Vector2i(390,844)]:
			get_window().size = size
			game.pause_menu.show_upgrade_options()
			await settle()
			await capture("cards-%s-%d.png"%[lang,size.x])
			await capture("cards-scrolled-%s-%d.png"%[lang,size.x])
		game.pause_menu.hide()
		main.show_main_menu()
	store.set_language("en")
	main.queue_free()
	await get_tree().process_frame
	get_tree().quit()
func settle() -> void:
	for i in 10: await get_tree().process_frame
func capture(file: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("ROGGE_CAPTURE_DIR")+"/"+file)
