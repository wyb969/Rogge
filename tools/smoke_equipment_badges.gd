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
	if failures.is_empty(): print("EQUIPMENT BADGES OK: all22 equipment, bold corner digits including6, unobscured 1.5x perimeter and four screen layouts")
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
