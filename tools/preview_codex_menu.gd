extends Node
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	var main=load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await settle()
	var store:=get_node("/root/SettingsStore")
	for lang in ["en","zh_CN"]:
		store.set_language(lang)
		await main._launch_run(&"")
		var game: Node=main.game
		game.spawner.timer.stop()
		game.spawner.get_node("Elite").stop()
		var menu: Node=main.session_menu
		menu.open_menu()
		for size in [Vector2i(900,600),Vector2i(390,844)]:
			get_window().size=size
			await capture("pause-%s-%d.png"%[lang,size.x])
			menu.open_codex("banana_fan")
			await capture("codex-equipment-%s-%d.png"%[lang,size.x])
			menu.codex.show_list()
			await capture("codex-list-%s-%d.png"%[lang,size.x])
			menu.codex.open_page(game,"dino")
			await capture("codex-boss-%s-%d.png"%[lang,size.x])
			menu.codex.open_page(game,"trial_speed")
			await capture("codex-trial-%s-%d.png"%[lang,size.x])
			menu.codex.close_page()
		menu.close_menu()
		var pool: Array=[]
		for entry in game.pause_menu.upgrade_pool:
			if entry.id in ["monster_necklace","banana_fan","holy_water"]:pool.append(entry)
		game.pause_menu.upgrade_pool=pool
		game.variety._notice.hide()
		for size in [Vector2i(900,600),Vector2i(390,844)]:
			get_window().size=size
			game.pause_menu.show_upgrade_options()
			await capture("cards-%s-%d.png"%[lang,size.x])
			game.pause_menu._card_scroll.scroll_vertical=100000
			await capture("cards-scrolled-%s-%d.png"%[lang,size.x])
		game.pause_menu.hide()
		game.trials.begin("power")
		for size in [Vector2i(900,500),Vector2i(390,844)]:
			get_window().size=size
			await capture("trial-intro-%s-%d.png"%[lang,size.x])
		main.show_main_menu()
		await capture("home-%s.png"%lang)
	store.set_language("en")
	main.queue_free()
	await get_tree().process_frame
	get_tree().quit()
func settle() -> void:
	for i in 8:await get_tree().process_frame
func capture(name: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("ROGGE_CAPTURE_DIR")+"/"+name)
