extends SceneTree
var checks := 0
var failures: Array[String] = []
var chinese := RegEx.new()
var main: Node
var store: Node
var preview: Script
func _init() -> void: call_deferred("run")
func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
func settle() -> void:
	for i in 5: await process_frame
func english(text: String, context: String) -> void:
	expect(chinese.search(text) == null, context + ": untranslated " + text)
func inside(control: Control, context: String) -> void:
	var bounds := Rect2(Vector2.ZERO,root.get_visible_rect().size).grow(2)
	expect(bounds.encloses(control.get_global_rect()),context+" fits: "+str(control.get_global_rect()))
func run() -> void:
	chinese.compile("[\\x{4e00}-\\x{9fff}]")
	store = root.get_node("SettingsStore")
	expect(store.language == "en" and TranslationServer.get_locale() == "en", "fresh install defaults to English regardless of OS")
	expect(L10n.text("怪物项链") == "Monster Necklace", "catalog loaded in runtime / packed build")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await settle()
	main._on_setting_button_pressed()
	await settle()
	var page: Node = main.get_node("SettingsPage")
	store.set_control_scale(1.2)
	store.set_control_opacity(0.6)
	store.set_stick_norm(Vector2(0.2,0.72))
	store.set_dash_norm(Vector2(0.8,0.7))
	store.set_music_linear(0.42)
	store.set_difficulty(2)
	for dimensions in [Vector2i(900,600),Vector2i(390,844),Vector2i(844,390)]:
		root.size = dimensions
		await settle()
		for index in 2:
			page.language_buttons[index].pressed.emit()
			await settle()
			expect(store.language == L10n.LANGUAGES[index],"real settings button switches locale")
			expect(page.language_buttons[index].button_pressed,"selected language highlighted")
			expect(L10n.text("Start") == ("Start" if index==0 else "开始游戏"),"home menu updates without restarting")
			expect(L10n.text(page.back_button.text) == ("Back" if index==0 else "返回"),"existing settings button updates immediately")
			inside(page._panel,"settings panel "+str(dimensions))
			inside(page.back_button,"fixed Back button")
			page._scroll.scroll_vertical = 0
			await settle()
			for button in page.language_buttons: inside(button,"language button")
			page._scroll.ensure_control_visible(page.difficulty_button)
			await settle()
			inside(page.difficulty_button,"scroll-reachable difficulty")
			expect(page.difficulty_description.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART,"long descriptions wrap")
	var file := ConfigFile.new()
	expect(file.load(store.PATH)==OK and file.get_value("play","language")=="zh_CN","language saved to disk")
	store.language = "en"
	store.load_from_disk()
	expect(store.language == "zh_CN","language round-trips")
	expect(store.control_scale==1.2 and store.control_opacity==0.6 and store.stick_norm==Vector2(0.2,0.72) and store.dash_norm==Vector2(0.8,0.7),"control layout preserved")
	expect(store.music_linear==0.42 and store.difficulty==2,"audio and difficulty preserved")
	file.erase_section_key("play","language")
	file.save(store.PATH)
	store.load_from_disk()
	expect(store.language == "en","older settings migrate to English")
	store.set_language("unsupported")
	expect(store.language=="en","unsupported language safely falls back")
	expect(AudioServer.get_bus_index("Music")>=0 and InputMap.has_action("Debug"),"internal bus and action identifiers are not localized")
	page.close_page()
	await main._launch_run(&"")
	paused = true
	var game: Node = main.game
	preview = load("res://script/card_preview.gd")
	for entry in game.pause_menu.upgrade_pool:
		store.set_language("en")
		var en: Dictionary = game.pause_menu._build_card_data(entry)
		english(en.title,"card title "+entry.id)
		english(en.desc,"card description "+entry.id)
		expect(en.desc.contains("→"),"numeric comparison retained "+entry.id)
		store.set_language("zh_CN")
		var zh: Dictionary = game.pause_menu._build_card_data(entry)
		expect(chinese.search(zh.title)!=null,"Chinese card title "+entry.id)
		expect(en.rows.size()==zh.rows.size(),"same stat count")
		for i in en.rows.size():
			expect(en.rows[i].before==zh.rows[i].before and en.rows[i].after==zh.rows[i].after and en.rows[i].label==zh.rows[i].label,"identical formulas and stable stat keys across languages")
	store.set_language("en")
	for i in 4:
		game.beast_powers.unlock(i)
		english(game.beast_powers.description_for(i),"guardian description")
		english(game.beast_powers._buttons[i].tooltip_text,"guardian tooltip")
	for lang in L10n.LANGUAGES:
		store.set_language(lang)
		for dimensions in [Vector2i(900,600),Vector2i(390,844),Vector2i(844,390)]:
			root.size = dimensions
			await settle()
			# Longest explanations: no text clipping, outer scroll retains all details.
			var pool: Array = []
			for entry in game.pause_menu.upgrade_pool:
				if entry.id in ["rune_bolt","banana_fan","holy_water"]: pool.append(entry)
			var original: Array = game.pause_menu.upgrade_pool
			game.pause_menu.upgrade_pool = pool
			game.pause_menu.show_upgrade_options()
			await settle()
			var menu: Node = game.pause_menu
			inside(menu.reroll_button,"reroll "+lang+str(dimensions))
			inside(menu._card_area,"card viewport")
			for card in menu.h_box_container.get_children():
				expect(card.title_label.size.y >= 18 and not card.title_label.text.is_empty(),"card title remains visible when text is clipped")
				expect(card.title_label.max_lines_visible==1 and card.title_label.tooltip_text.begins_with(card.title_label.text),"title wraps / ellipsis preserves full tooltip")
				expect(card.get_global_rect().grow(1).encloses(card.desc_label.get_global_rect()),"description inside card")
				expect(card.desc_label.get_content_height()<=card.desc_label.size.y+1,"full short description visible")
			menu.upgrade_pool = original
			menu.hide()
	main.show_main_menu()
	store.set_language("en")
	if failures.is_empty(): print("LOCALIZATION OK: %d checks; default, live switch, persistence, migration, stats parity, all cards, four powers and three layouts"%checks)
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
