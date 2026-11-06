extends SceneTree
var failures: Array[String] = []
var checks: = 0

class SimulatedScreenDebug extends "res://script/debug_menu_layout.gd":
	var display_pixel_ratio: = 1.0
	func _display_pixel_ratio() -> float:
		return display_pixel_ratio

func _init() -> void:
	call_deferred("_run")

func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)

func _inside(control: Control, vp: Vector2) -> bool:
	var rect: = control.get_global_rect()
	return rect.size.x > 0 and rect.size.y > 0 and rect.position.x >= -1 and rect.position.y >= -1 and rect.end.x <= vp.x + 1 and rect.end.y <= vp.y + 1

func _layout(page: Control, physical_size: Vector2i, ratio: float = 1.0) -> void:
	page.display_pixel_ratio = ratio
	root.size = physical_size
	await process_frame
	await process_frame
	page.open_page()
	await process_frame
	var vp: = root.get_visible_rect().size
	var transform: = root.get_final_transform()
	var scale: = (transform * Vector2.RIGHT - transform * Vector2.ZERO).length() / ratio
	var seen: = {}
	var footer_y: float = page.back_button.position.y
	var panel_rect: Rect2 = page.panel.get_global_rect()
	_expect(_inside(page.panel, vp), "panel fits %s: %s / %s" % [physical_size, panel_rect, vp])
	_expect(page.prev_button.disabled and not page.next_button.disabled, "first page has bounded navigation")
	for index in page.page_count:
		_expect(page.page_index == index, "Next advances exactly one page")
		var controls: Array[Control] = [page.title, page.prev_button, page.next_button, page.page_label, page.back_button, page.report_button]
		if page.hint.visible: controls.append(page.hint)
		var visible_count: = 0
		for button in page.entries:
			if button.visible:
				visible_count += 1
				_expect(not seen.has(button.name), "entry appears on one page only")
				seen[button.name] = true
				controls.append(button)
				_expect(not button.disabled and button.get_script() == null, "visible entries are interactive without overflowing hover transforms")
				_expect(button.size.y * scale >= 47.0, "test entry remains a displayed 48px touch target")
			else:
				_expect(button.disabled, "off-page entries cannot receive focus/taps")
		_expect(visible_count > 0 and visible_count <= page.page_size, "each page has bounded nonempty content")
		for control in controls:
			_expect(_inside(control, vp), "%s fits %s" % [control.name, physical_size])
		for button in [page.back_button, page.report_button, page.prev_button, page.next_button]:
			_expect(button.size.y * scale >= 43.0, "footer remains a displayed 44px touch target")
		for i in controls.size():
			for j in range(i + 1, controls.size()):
				_expect(not controls[i].get_global_rect().intersects(controls[j].get_global_rect()), "%s/%s do not overlap at %s" % [controls[i].name, controls[j].name, physical_size])
		_expect(is_equal_approx(page.back_button.position.y, footer_y) and page.panel.get_global_rect() == panel_rect, "footer and panel stay fixed across pages")
		if index < page.page_count - 1:
			page.next_button.pressed.emit()
	_expect(seen.size() == 13 and page.next_button.disabled and not page.prev_button.disabled, "all thirteen recent tests are reachable, last-page Next disabled")
	page.set_page(999)
	_expect(page.page_index == page.page_count - 1, "large page request clamps")
	page.prev_button.pressed.emit()
	_expect(page.page_index == page.page_count - 2, "Previous goes back one page")
	page.set_page(-5)
	_expect(page.page_index == 0 and page.prev_button.disabled, "negative page request clamps")
	page.show_status("Exported: ".repeat(60) + "\nLong diagnostics path")
	await process_frame
	_expect(_inside(page.report_button, vp) and _inside(page.panel, vp) and page.hint.tooltip_text.contains("Long diagnostics"), "long report status cannot expand the panel")

func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("mainUI/Control/DebugCenter").set_script(SimulatedScreenDebug)
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	_expect(main.menu_page.visible and not main.debug_page.visible, "home is the initial page")
	var original: Node = main.game
	main.get_node("mainUI/Control/MenuCenter/VBoxContainer/DebugButton").pressed.emit()
	var page: Control = main.debug_page
	_expect(page.visible and not main.menu_page.visible and paused, "Debug opens a separate paused page")
	_expect(page.entries.size() == 13, "only thirteen recent test entries remain")
	for old in ["DebugKnightButton", "DebugNecklaceButton", "DebugWeatherButton", "DebugBeast3Button", "DebugMusicButton", "DebugStabilityButton"]:
		_expect(not page.box.has_node(old), "restored old entry removed: " + old)
	for size in [Vector2i(390,844), Vector2i(320,568), Vector2i(280,480), Vector2i(844,390), Vector2i(640,360), Vector2i(900,500), Vector2i(1440,900)]:
		await _layout(page, size)
	for ratio in [2.0, 3.0]:
		await _layout(page, Vector2i(Vector2(390,844) * ratio), ratio)
		_expect(page.columns == 1 and page.page_size == 4 and page.page_count == 4, "high-DPI phone keeps the same CSS layout at DPR %s" % ratio)
		await _layout(page, Vector2i(Vector2(844,390) * ratio), ratio)
		_expect(page.columns == 2 and page.page_size == 6 and page.page_count == 3, "high-DPI landscape keeps the same CSS layout at DPR %s" % ratio)
	page.display_pixel_ratio = 1.0
	root.size = Vector2i(900,600)
	await process_frame
	await process_frame
	_expect(main.game == original and paused, "paging/resizing cannot replace or start the prepared run")
	page.report_button.pressed.emit()
	_expect(page.visible and paused and not page.hint.text.is_empty(), "diagnostics remains available without starting gameplay")
	page.back_button.pressed.emit()
	_expect(main.menu_page.visible and not page.visible and main.game == original, "Back restores home and its existing game")
	main._on_debug_button_pressed()
	_expect(page.page_index == 0 and page.hint.text == page.DEFAULT_HINT, "reopen resets paging and report status")
	var button: Button = page.box.get_node("DebugGrowthButton")
	page.ensure_control_visible(button)
	_expect(button.visible, "current recent preset is visible on its page")
	button.pressed.emit()
	button.pressed.emit()
	await process_frame
	await process_frame
	_expect(not paused and not main.main_ui.visible and main.game_root.get_child_count() == 1, "rapid double tap launches exactly one run")
	_expect(main._test_mode == &"growth" and main.game.growth_combo_active and is_equal_approx(main.game.player.effective_move_speed(),144), "retained Growth button equips its actual preset once")
	main.on_game_over({"victory": false})
	main.game_end_ui.retry_pressed.emit()
	await process_frame
	await process_frame
	_expect(main._test_mode == &"growth" and main.game.growth_combo_active and is_equal_approx(main.game.player.effective_move_speed(),144), "Retry keeps the chosen preset without stacking")
	main.on_game_over({"victory": false})
	main.game_end_ui.main_menu_pressed.emit()
	await process_frame
	await process_frame
	_expect(main.menu_page.visible and not page.visible and paused and main._test_mode == &"", "result return restores home and clears debug mode")
	main.get_node("mainUI/Control/MenuCenter/VBoxContainer/StartButton").pressed.emit()
	await process_frame
	await process_frame
	_expect(not main.game.growth_combo_active and main.game.player.growth_move_multiplier == 1 and main.game_root.get_child_count() == 1, "normal Start inherits no debug set or duplicate game")
	if failures.is_empty():
		print("DEBUG MENU OK: %d assertions; seven viewport sizes plus DPR 2/3 portrait/landscape, all pages, touch targets, fixed footer, diagnostics, launch/retry/reset" % checks)
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
