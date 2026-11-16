extends SceneTree
var failures: Array[String]=[]
var checks:=0
func _init() -> void: call_deferred("run")
func expect(ok: bool, note: String) -> void:
	checks+=1
	if not ok:failures.append(note)
func settle() -> void:
	for i in 4:await process_frame
func run() -> void:
	var main: Node=load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await settle()
	await main._launch_run(&"")
	var game: Node=main.game
	game.spawner.timer.stop()
	game.spawner.get_node("Elite").stop()
	var menu: Node=game.pause_menu
	var pool: Array=menu.upgrade_pool.duplicate()
	var store: Node=root.get_node("SettingsStore")
	for lang in ["en","zh_CN"]:
		store.set_language(lang)
		var label: Label=main.mobile_controls.dash_label
		expect(label.get_theme_font("font").has_char("冲".unicode_at(0)) and label.get_theme_font("font").has_char("刺".unicode_at(0)),"DASH font has Chinese glyphs")
		expect(label.get_theme_font("font")==UiFonts.ui(),"DASH uses shared composite font")
		for dimensions in [Vector2i(320,568),Vector2i(390,844),Vector2i(844,390),Vector2i(900,600),Vector2i(667,375)]:
			root.size=dimensions
			await settle()
			for batch in range(0,pool.size(),3):
				menu.upgrade_pool=[pool[batch],pool[(batch+1)%pool.size()],pool[(batch+2)%pool.size()]]
				menu.show_upgrade_options()
				await settle()
				var bounds:=Rect2(Vector2.ZERO,root.get_visible_rect().size)
				expect(menu.h_box_container.get_child_count()==3,"three choices")
				expect(not menu._card_area is ScrollContainer,"draft has no scroll container")
				expect(bounds.encloses(menu.reroll_button.get_global_rect()),"reroll visible")
				for card in menu.h_box_container.get_children():
					var context: String=lang+str(dimensions)+card.upgrade_id
					expect(bounds.grow(1).encloses(card.get_global_rect()),"whole card visible "+context)
					expect(card.get_global_rect().end.y < menu.reroll_button.position.y,"card above reroll "+context)
					expect(card.find_children("*","Button").is_empty(),"no Details button "+context)
					for label_node in [card.desc_label,card.stats_label]:
						expect(label_node.get_content_height()<=label_node.size.y+1,"text fits "+context+str(label_node.get_content_height())+"/"+str(label_node.size.y))
						expect(card.get_global_rect().grow(1).encloses(label_node.get_global_rect()),"text bounds "+context)
	menu.upgrade_pool=pool
	menu.show_upgrade_options()
	await settle()
	var card: Node=menu.h_box_container.get_child(2)
	var id: String=card.upgrade_id
	var before: int=game.equipment_panel.get_level(id)
	var at: Vector2=card.get_global_rect().get_center()
	for down in [true,false]:
		var click:=InputEventMouseButton.new()
		click.position=at
		click.global_position=at
		click.button_index=MOUSE_BUTTON_LEFT
		click.pressed=down
		root.push_input(click,true)
	await settle()
	expect(not menu.visible and not paused,"clicking the third card resumes gameplay")
	expect(game.equipment_panel.get_level(id)==before+1,"actual click grants exactly the selected upgrade")
	main.show_main_menu()
	store.set_language("en")
	if failures.is_empty():print("THREE CARDS OK: %d checks; all 28 cards, both languages, five viewports, no scrolling, CJK DASH"%checks)
	else:
		for failure in failures:push_error(failure)
	quit(0 if failures.is_empty() else 1)
