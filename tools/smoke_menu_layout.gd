extends SceneTree
## Checks the start menu and result screen reflow for portrait and landscape.

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	_check_menu(main, Vector2i(390, 844), "portrait", failures)
	_check_menu(main, Vector2i(900, 500), "landscape", failures)
	var end_ui: Node = main.get_node("GameEndUI")
	end_ui.show_result({"victory": false, "minutes": 1, "seconds": 5, "kills": 3, "level": 2, "stage": 1})
	await process_frame
	_check_result(end_ui, Vector2i(390, 844), "portrait", failures)
	_check_result(end_ui, Vector2i(900, 500), "landscape", failures)
	if failures.is_empty():
		print("MENU LAYOUT OK")
		quit(0)
	else:
		for failure in failures:
			print("MENU LAYOUT FAIL: ", failure)
		quit(1)

func _set_viewport(size: Vector2i) -> void:
	root.size = size
	await process_frame
	await process_frame

func _check_menu(main: Node, size: Vector2i, label: String, failures: Array[String]) -> void:
	await _set_viewport(size)
	var start: Button = main.get_node("mainUI/Control/MenuCenter/VBoxContainer/StartButton")
	var settings: Button = main.get_node("mainUI/Control/MenuCenter/VBoxContainer/SettingButton")
	var title: Label = main.get_node("mainUI/Control/MenuCenter/VBoxContainer/TitleLabel")
	var vp := root.get_visible_rect().size
	_expect_inside(start, vp, "start %s" % label, failures)
	_expect_inside(settings, vp, "settings %s" % label, failures)
	_expect_inside(title, vp, "title %s" % label, failures)
	if start.custom_minimum_size.y < 48.0:
		failures.append("start %s button is too short (%s)" % [label, start.custom_minimum_size])
	if start.custom_minimum_size.x > vp.x - 16.0:
		failures.append("start %s wider than viewport" % label)

func _check_result(end_ui: Node, size: Vector2i, label: String, failures: Array[String]) -> void:
	await _set_viewport(size)
	var retry: Button = end_ui.get_node("CanvasLayer/Control/ResultCenter/BoxContainer/RetryButton")
	var title: Label = end_ui.get_node("CanvasLayer/Control/ResultCenter/BoxContainer/ResultTitle")
	var vp := root.get_visible_rect().size
	_expect_inside(retry, vp, "retry %s" % label, failures)
	_expect_inside(title, vp, "result title %s" % label, failures)
	if retry.custom_minimum_size.y < 48.0:
		failures.append("retry %s button is too short" % label)

func _expect_inside(control: Control, vp: Vector2, label: String, failures: Array[String]) -> void:
	var rect := control.get_global_rect()
	if rect.size.x < 8.0 or rect.size.y < 8.0:
		failures.append("%s has no size %s" % [label, rect])
		return
	if rect.position.x < -2.0 or rect.position.y < -2.0:
		failures.append("%s starts offscreen %s" % [label, rect])
	if rect.end.x > vp.x + 4.0 or rect.end.y > vp.y + 4.0:
		failures.append("%s overflows viewport %s vp=%s" % [label, rect, vp])
