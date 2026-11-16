extends SceneTree
var failures: Array[String]=[]
var checks:=0
var main: Node
var menu: Node
var store: Node
var DATA: Script
func _init() -> void:call_deferred("run")
func expect(ok: bool, message: String) -> void:
	checks+=1
	if not ok:failures.append(message)
func settle() -> void:
	for i in 4:await process_frame
func escape() -> void:
	var e:=InputEventKey.new()
	e.keycode=KEY_ESCAPE
	e.pressed=true
	Input.parse_input_event(e)
	await settle()
	e.pressed=false
	Input.parse_input_event(e)
func click(control: Control) -> void:
	var at := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position=at
	motion.global_position=at
	root.push_input(motion,true)
	for down in [true,false]:
		var event:=InputEventMouseButton.new()
		event.position=at
		event.global_position=at
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=down
		root.push_input(event,true)
	await settle()
func inside(control: Control,label: String) -> void:
	expect(Rect2(Vector2.ZERO,root.get_visible_rect().size).grow(2).encloses(control.get_global_rect()),label+" inside viewport "+str(control.get_global_rect()))
func run() -> void:
	store=root.get_node("SettingsStore")
	main=load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene=main
	await settle()
	menu=main.session_menu
	DATA=load("res://script/codex_data.gd")
	var entries: Array=DATA.entries()
	var seen:={}
	var zh:=RegEx.new()
	zh.compile("[\\x{4e00}-\\x{9fff}]")
	for entry in entries:
		expect(not seen.has(entry.id),"unique entry "+entry.id)
		seen[entry.id]=true
		expect(DATA.texture_for(entry)!=null,"icon exists "+entry.id)
		for lang in L10n.LANGUAGES:
			store.set_language(lang)
			var body: String=DATA.description(entry)
			expect(body.length()>15,"detailed description "+entry.id)
			if lang=="en":expect(zh.search(body)==null and zh.search(L10n.text(entry.title))==null,"English entry translated "+entry.id)
	for id in main.game.equipment_panel.EQUIP_DEFS:expect(seen.has(id),"every equipment is in codex")
	main.get_node("mainUI/Control/MenuCenter/VBoxContainer/CodexButton").pressed.emit()
	await settle()
	expect(menu.active and menu.codex.visible and paused,"home codex opens while paused")
	menu.codex.close_page()
	expect(not menu.active and paused and main.menu_page.visible,"home codex returns to home without unpausing")
	await main._launch_run(&"")
	var g: Node=main.game
	g.spawner.timer.stop()
	g.spawner.get_node("Elite").stop()
	await click(main.fullscreen_toggle.menu_button)
	expect(menu.active and paused,"actual toolbar click pauses active run")
	await escape()
	await escape()
	expect(menu.active and paused,"Esc pauses active run")
	var position: Vector2=g.player.position
	var time_left: float=g.player.can_dasing_timer.time_left
	var health: float=g.player.player_health
	await create_timer(0.15,true,false,true).timeout
	expect(g.player.position==position and g.player.player_health==health and g.player.can_dasing_timer.time_left==time_left,"player motion, health and dash timer frozen")
	expect(not root.get_node("MobileInput").controls_enabled,"touch gameplay input disabled")
	menu.open_settings()
	await settle()
	expect(main.settings_page.visible and paused,"settings remains paused")
	main.settings_page.language_buttons[0].pressed.emit()
	await escape()
	expect(menu.active and not main.settings_page.visible and menu.panel.visible and paused,"Esc from settings returns to paused menu")
	menu.open_codex("banana_fan")
	await settle()
	expect(menu.codex._text.text.contains("gust"),"current English equipment detail")
	for size in [Vector2i(900,600),Vector2i(390,844),Vector2i(844,390)]:
		root.size=size
		await settle()
		for lang in L10n.LANGUAGES:
			store.set_language(lang)
			await settle()
			inside(menu.codex._root,"codex panel "+str(size))
			inside(menu.codex._back,"codex back")
			expect(menu.codex._back.size.x >= 80*menu.codex._ui_scale(),"back button has readable physical width")
			expect(not menu.codex._text.text.is_empty(),"locale change keeps selected detail")
			menu.codex.show_list()
			await settle()
			inside(menu.codex._list_scroll,"entry list")
			menu.codex._select("banana_fan")
			await settle()
			inside(menu.codex._detail_scroll,"detail viewport")
	menu.codex.close_page()
	await escape()
	expect(not paused and not menu.active,"Esc resumes active run")
	root.size=Vector2i(900,600)
	await settle()
	# Opening over an upgrade must not reroll, claim or resume it.
	g.pause_menu.show_upgrade_options()
	await settle()
	var offered: Array=g.pause_menu._offered.duplicate()
	var rng_state: int=g.pause_menu._draft_rng.state
	var card: Node=g.pause_menu.h_box_container.get_child(0)
	await escape()
	menu.open_codex(card.upgrade_id)
	expect(menu.active and menu.origin=="run" and menu.codex.selected_id==card.upgrade_id,"menu Codex opens while draft is pending")
	menu.codex.close_page()
	await escape()
	expect(paused and g.pause_menu.visible and g.pause_menu._offered==offered,"return preserves pending upgrade")
	await escape()
	menu.open_settings()
	store.set_language("en")
	store.set_language("zh_CN")
	await settle()
	expect(g.pause_menu._offered==offered and g.pause_menu._draft_rng.state==rng_state,"locale refresh does not reroll or spend draft RNG")
	await escape()
	await escape()
	expect(paused and g.pause_menu.visible,"nested pause restores previously paused state")
	g.pause_menu.hide()
	paused=false
	# Same card geometry and full short text for every equipment in both languages.
	root.size=Vector2i(900,600)
	await settle()
	var sample: Node=load("res://scenes/UpgradeCard.tscn").instantiate()
	root.add_child(sample)
	for lang in L10n.LANGUAGES:
		store.set_language(lang)
		expect(CardNumbers.value_pair(0,3,"s")==L10n.text("未装备 → ")+"3s","new cooldown uses None instead of misleading zero seconds")
		for entry in g.pause_menu.upgrade_pool:
			sample.setup(g.pause_menu._build_card_data(entry))
			sample.set_display_width(190,1)
			await settle()
			expect(sample.size==Vector2(190,307.42),"fixed card size "+entry.id+lang+str(sample.size))
			expect(sample.icon.size.y>=64,"large icon "+entry.id)
			expect(sample.desc_label.get_content_height()<=sample.desc_label.size.y+1,"short description fits "+entry.id+lang)
			expect(sample.stats_label.get_content_height()<=sample.stats_label.size.y+1,"key values fit "+entry.id+lang)
			expect(sample.desc_label.text==DATA.summary(entry.id),"card uses shared short description")
	sample.queue_free()
	g._open_rest_hub()
	await settle()
	await escape()
	await escape()
	expect(paused and g.rest_hub.visible,"rest page remains paused after menu round trip")
	g.rest_hub.close_hub()
	g.trials.begin("power")
	await settle()
	await escape()
	menu.open_codex("trial_power")
	await settle()
	menu.codex.close_page()
	await escape()
	expect(paused and g.trials.flow==g.trials.TrialFlow.INTRO and g.trials.elapsed==0,"trial intro preserved; no time consumed")
	for size in [Vector2i(390,844),Vector2i(844,390)]:
		root.size=size
		for lang in L10n.LANGUAGES:
			store.set_language(lang)
			await settle()
			g.trials._fit()
			await settle()
			inside(g.trials._panel,"translated trial intro")
			inside(g.trials.start_button,"trial action stays visible")
	await main._on_game_end_ui_main_menu_pressed()
	expect(not menu.active and not menu.codex.visible and paused,"return-home teardown cannot resume an old run")
	store.set_language("en")
	if failures.is_empty():print("CODEX MENU OK: %d checks; 53 entries, bilingual content, exact card sizing, pause ownership, Esc/settings/details, no rerolls, rest/trial lifecycle"%checks)
	else:
		for failure in failures:push_error(failure)
	quit(0 if failures.is_empty() else 1)
