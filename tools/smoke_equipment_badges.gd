extends SceneTree
var failures: Array[String] = []
func _init() -> void: call_deferred("_run")
func _expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	await main._launch_run(&"equipment_combos")
	var panel: Node = main.game.equipment_panel
	for id in panel.EQUIP_DEFS:
		if panel.get_level(id) == 0: panel.apply_upgrade(id)
	for level in range(panel.get_level("gun_up"),6): panel.apply_upgrade("gun_up")
	await create_timer(0.5).timeout
	for size in [Vector2i(390,844),Vector2i(320,568),Vector2i(844,390),Vector2i(900,600)]:
		root.size = size
		await process_frame
		await process_frame
		panel._fit_equipment()
		await process_frame
		_expect(panel.scale.x <= 1.0 and panel.slot_list.columns == 2, "equipment never enlarges in portrait and stays in two compact columns")
		var bounds := Rect2(Vector2.ZERO,root.get_visible_rect().size)
		for id in panel._slots:
			var slot: Dictionary = panel._slots[id]
			var label: Label = slot.level_label
			_expect(label.text == str(slot.level) and not label.text.contains("Lv"), "rank is digits only: "+id)
			_expect(label.get_theme_font("font")==UiFonts.ui_bold() and label.get_theme_constant("outline_size")>=2, "rank stays bold and outlined")
			_expect(bounds.encloses(label.get_global_rect()) and bounds.encloses(slot.icon_wrap.get_global_rect()), "icon and badge fit "+str(size))
			_expect(label.get_global_rect().get_center().x > slot.icon.get_global_rect().get_center().x and label.get_global_rect().get_center().y > slot.icon.get_global_rect().get_center().y, "rank sits at its icon's bottom right")
			var border: Control = slot.combo_border
			if border != null:
				_expect(border.get_parent()==slot.icon_wrap and border.WIDTH_SCALE==1.5, "wider color perimeter surrounds the complete icon frame")
	_expect(panel.get_level("gun_up")==6 and panel._slots.gun_up.level_label.text=="6", "higher levels also show plain digits")
	await _check_rank_hud(main.game)
	if failures.is_empty(): print("EQUIPMENT BADGES OK: classic badges, right-side skill ranks, tier colors, paused and interrupted hops, four viewport sizes")
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _check_rank_hud(game: Node) -> void:
	var panel: Control = game.equipment_panel
	panel.reset_equipment(false)
	game.forge.begin(game,true)
	for id in ["axe_up","gun_up","speed_up","regen_up"]:
		game._on_upgrade_selected(id)
	var label: Label = panel._slots.gun_up.level_label
	await create_timer(0.5).timeout
	var icon_frame: Control = panel._slots.gun_up.icon_wrap
	_expect(label.get_theme_font("font") == UiFonts.ui() and label.get_theme_constant("outline_size") == 1, "thin pixel figures")
	_expect(label.size.y == icon_frame.size.y and absf(label.size.x - icon_frame.size.x) <= 6, "single-digit frame matches the icon")
	var rest := label.position
	for size in [Vector2i(390,844),Vector2i(320,568),Vector2i(844,390),Vector2i(900,600)]:
		root.size = size
		await process_frame
		panel._fit_equipment()
		await process_frame
		var bounds := Rect2(Vector2.ZERO,root.get_visible_rect().size)
		var badge: Rect2 = panel._slots.gun_up.root.get_global_rect()
		_expect(bounds.encloses(badge) and badge.get_center().x > bounds.size.x * 0.5, "right-side badges fit " + str(size))
		_expect(absf(panel.slot_list.get_global_rect().end.x - (bounds.end.x - 8 * preload("res://script/boss_hud_layout.gd").display_scale(panel))) < 2, "grid follows the right margin")
	paused = true
	game._on_upgrade_selected("gun_up")
	await create_timer(0.18).timeout
	_expect(label.text == "+2" and label.position == rest and label.scale == Vector2.ONE,"paused upgrade waits for play")
	paused = false
	var tween: Tween = panel._slots.gun_up.juice_tween
	tween.pause()
	tween.custom_step(0.05)
	tween.custom_step(0.12)
	_expect(label.position.y < rest.y - 5.0, "rank rises above its baseline")
	game._on_upgrade_selected("gun_up")
	_expect(not tween.is_valid(), "new upgrade replaces the in-flight hop")
	await create_timer(0.5).timeout
	_expect(label.position == rest and label.scale == Vector2.ONE, "interrupted hop settles exactly")
	for level in [1,3,6,9,12,123,1234]:
		panel.set_card_count("gun_up",level)
		var width := label.get_theme_font("font").get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,label.get_theme_font_size("font_size")).x
		_expect(label.text == "+%d" % level and label.get_theme_color("font_color") == panel.QUALITY.COLORS[panel.QUALITY.tier_for(level)], "rank text and color")
		_expect(width <= panel.QUALITY_FOOTPRINT.x-panel.RANK_LEFT and (level>99 or label.get_theme_font_size("font_size")==panel.RANK_FONT_SIZE), "normal ranks match icon scale and long ranks fit")
	panel.set_card_count("gun_up",0)
	_expect(not panel._slots.has("gun_up"), "sacrifice removes the animating slot")
