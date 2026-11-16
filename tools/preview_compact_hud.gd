extends Node
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	var main=load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await settle()
	for lang in ["en","zh_CN"]:
		get_node("/root/SettingsStore").set_language(lang)
		await main._launch_run(&"")
		var g: Node=main.game
		g.spawner.timer.stop()
		g.spawner.get_node("Elite").stop()
		g.variety.notify(L10n.text("宝囊精出现！追上它获得经验和重抽次数"))
		g.star_chain.fever_left=1.3
		g.star_chain._update_hud()
		get_tree().paused=true
		for size in [Vector2i(900,600),Vector2i(390,844),Vector2i(320,568),Vector2i(844,390)]:
			get_window().size=size
			await capture("combat-%s-%d.png"%[lang,size.x])
			var toolbar=main.fullscreen_toggle
			for button in [toolbar.button,toolbar.home_button,toolbar.menu_button]:
				assert(button.text.is_empty() and button.icon!=null and not button.tooltip_text.is_empty())
				assert(not button.get_global_rect().intersects(g.spawner._stage_label.get_global_rect()))
			assert(not g.variety._notice.is_visible_in_tree())
			assert(not g.star_chain._bar.is_visible_in_tree() and g.star_chain._label.text=="1.3")
		g.spawner.stage=5
		g.spawner.spawn_boss()
		get_window().size=Vector2i(390,844)
		await capture("boss-%s.png"%lang)
		for boss in g.spawner._active_bosses:
			assert(boss.health_bar.is_visible_in_tree())
			assert(not boss._title.is_visible_in_tree() and not boss._action_label.is_visible_in_tree())
		main.show_main_menu()
	get_node("/root/SettingsStore").set_language("en")
	print("COMPACT HUD CAPTURE OK: icon bounds, numeric timer, hidden notices, health-only twins")
	get_tree().quit()
func settle() -> void:
	for i in 8: await get_tree().process_frame
func capture(name: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("ROGGE_CAPTURE_DIR")+"/"+name)
