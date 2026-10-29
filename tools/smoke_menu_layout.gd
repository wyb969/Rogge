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
	_check_keys(failures)
	await _check_menu(main, Vector2i(390, 844), "portrait", failures)
	await _check_menu(main, Vector2i(900, 500), "landscape", failures)
	var end_ui: Node = main.get_node("GameEndUI")
	end_ui.show_result({"victory": false, "minutes": 1, "seconds": 5, "kills": 3, "level": 2, "stage": 1})
	await process_frame
	await _check_result(end_ui, Vector2i(390, 844), "portrait", failures)
	await _check_result(end_ui, Vector2i(900, 500), "landscape", failures)
	await _check_settings(main, failures)
	_reset_settings()
	if failures.is_empty():
		print("MENU LAYOUT OK")
		quit(0)
	else:
		for failure in failures:
			print("MENU LAYOUT FAIL: ", failure)
		quit(1)

func _check_keys(failures: Array[String]) -> void:
	if not _action_has_key("up", KEY_W) or not _action_has_key("up", KEY_UP):
		failures.append("up is missing W or arrow")
	if not _action_has_key("down", KEY_S) or not _action_has_key("down", KEY_DOWN):
		failures.append("down is missing S or arrow")
	if not _action_has_key("left", KEY_A) or not _action_has_key("left", KEY_LEFT):
		failures.append("left is missing A or arrow")
	if not _action_has_key("right", KEY_D) or not _action_has_key("right", KEY_RIGHT):
		failures.append("right is missing D or arrow")
	if not _action_has_key("roll", KEY_Z):
		failures.append("dash is missing Z")

func _action_has_key(action: StringName, keycode: Key) -> bool:
	if not InputMap.has_action(action):
		return false
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == keycode:
			return true
	return false

func _set_viewport(size: Vector2i) -> void:
	root.size = size
	await process_frame
	await process_frame

func _check_menu(main: Node, size: Vector2i, label: String, failures: Array[String]) -> void:
	await _set_viewport(size)
	var start: Button = main.get_node("mainUI/Control/MenuCenter/VBoxContainer/StartButton")
	var settings: Button = main.get_node("mainUI/Control/MenuCenter/VBoxContainer/SettingButton")
	var title: Label = main.get_node("mainUI/Control/MenuCenter/VBoxContainer/TitleLabel")
	var hint: Label = main.get_node("mainUI/Control/MenuCenter/VBoxContainer/ControlsHint")
	var vp := root.get_visible_rect().size
	_check_background(main.get_node("mainUI/Control/ColorRect/TextureRect"), label, failures)
	_expect_inside(start, vp, "start %s" % label, failures)
	_expect_inside(settings, vp, "settings %s" % label, failures)
	_expect_inside(title, vp, "title %s" % label, failures)
	_expect_inside(hint, vp, "controls hint %s" % label, failures)
	if not hint.text.contains("WASD") or not hint.text.contains("Z"):
		failures.append("controls hint %s missing keyboard keys" % label)
	if not hint.text.contains("方向键") or not hint.text.contains("摇杆"):
		failures.append("controls hint %s missing touch or arrow text" % label)
	if start.custom_minimum_size.y < 48.0:
		failures.append("start %s button is too short (%s)" % [label, start.custom_minimum_size])
	if start.custom_minimum_size.x > vp.x - 16.0:
		failures.append("start %s wider than viewport" % label)

func _check_result(end_ui: Node, size: Vector2i, label: String, failures: Array[String]) -> void:
	await _set_viewport(size)
	var retry: Button = end_ui.get_node("CanvasLayer/Control/ResultCenter/BoxContainer/RetryButton")
	var title: Label = end_ui.get_node("CanvasLayer/Control/ResultCenter/BoxContainer/ResultTitle")
	var vp := root.get_visible_rect().size
	_check_background(end_ui.get_node("CanvasLayer/Control/ColorRect/TextureRect"), "result " + label, failures)
	_expect_inside(retry, vp, "retry %s" % label, failures)
	_expect_inside(title, vp, "result title %s" % label, failures)
	if retry.custom_minimum_size.y < 48.0:
		failures.append("retry %s button is too short" % label)

func _check_settings(main: Node, failures: Array[String]) -> void:
	var host: Variant = main
	var store: Variant = root.get_node("SettingsStore")
	var player: Variant = host.game.get_node("Player")
	var health_before: float = player.player_health
	var max_before: float = player.max_player_health
	store.set_master_linear(0.4)
	store.set_control_scale(1.3)
	store.set_control_opacity(0.5)
	store.set_difficulty(store.DIFF_HARD)
	store.set_stick_norm(Vector2(0.22, 0.72))
	store.set_dash_norm(Vector2(0.78, 0.62))
	store.master_linear = 1.0
	store.load_from_disk()
	if absf(store.master_linear - 0.4) > 0.001:
		failures.append("master volume did not round-trip")
	if absf(store.control_scale - 1.3) > 0.001:
		failures.append("control scale did not round-trip")
	if absf(store.control_opacity - 0.5) > 0.001:
		failures.append("control opacity did not round-trip")
	if store.difficulty != store.DIFF_HARD:
		failures.append("difficulty did not round-trip")
	if player.player_health != health_before or player.max_player_health != max_before:
		failures.append("difficulty changed player health")
	store.apply_audio()
	var bus := AudioServer.get_bus_index("Master")
	var db := AudioServer.get_bus_volume_db(bus)
	if db > -6.0 or db < -10.0:
		failures.append("master bus db %s is outside the saved 40%% range" % db)
	await _set_viewport(Vector2i(390, 844))
	main._on_setting_button_pressed()
	await process_frame
	await process_frame
	var page: Variant = main.get_node("SettingsPage")
	if not page.visible:
		failures.append("settings page did not open")
	var picker: Variant = page.difficulty_button
	var choices: Variant = page.difficulty_list
	if choices.get_child_count() != 3:
		failures.append("difficulty choice count %s" % choices.get_child_count())
	var easy_label: Variant = choices.get_child(0).get_child(0)
	var hard_label: Variant = choices.get_child(2).get_child(0)
	if easy_label.text != "简单  Easy" or hard_label.text != "困难  Hard":
		failures.append("difficulty labels mismatch")
	if picker.text != "困难  Hard  v":
		failures.append("picker did not sync to hard (%s)" % picker.text)
	var controls: Variant = host.mobile_controls
	if not controls.visible or not controls.layout_edit:
		failures.append("layout edit did not show the on-screen buttons")
	controls.apply_saved_layout()
	await process_frame
	var vp := root.get_visible_rect().size
	var stick_center: Vector2 = controls.stick_base.global_position + controls.stick_base.size * 0.5
	var expected := Vector2(0.22, 0.72) * vp
	if stick_center.distance_to(expected) > 6.0:
		failures.append("stick layout %s expected %s" % [stick_center, expected])
	var expected_stick := 56.0 * 1.3 * 2.0
	if absf(controls.stick_base.size.x - expected_stick) > 1.0:
		failures.append("stick size %s" % controls.stick_base.size)
	if absf(controls.stick_base.modulate.a - 0.5) > 0.02:
		failures.append("stick opacity %s" % controls.stick_base.modulate.a)
	var panel: Control = page._panel
	var back: Control = page.back_button
	_expect_inside(panel, vp, "settings portrait panel", failures)
	_expect_inside(back, vp, "settings portrait back", failures)
	_expect_inside(picker, vp, "settings portrait difficulty", failures)
	page._toggle_difficulty_list()
	await process_frame
	_expect_inside(choices.get_child(2).get_child(0), vp, "settings portrait hard choice", failures)
	page._toggle_difficulty_list()
	await _set_viewport(Vector2i(900, 500))
	page._fit()
	controls.apply_saved_layout()
	await process_frame
	vp = root.get_visible_rect().size
	_expect_inside(page._panel, vp, "settings landscape panel", failures)
	_expect_inside(page.back_button, vp, "settings landscape back", failures)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = controls.dash_button.global_position + Vector2(8, 8)
	controls._input(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = Vector2(120, 80)
	controls._input(release)
	store.load_from_disk()
	if not store.has_custom_dash():
		failures.append("dash drag did not save")
	if store.dash_norm.x > 0.5 or store.dash_norm.y > 0.5:
		failures.append("dash drag stayed in the old corner %s" % store.dash_norm)
	page.close_page()
	await process_frame
	if page.visible or controls.visible:
		failures.append("settings close left the page or buttons up")

func _reset_settings() -> void:
	var store: Variant = root.get_node_or_null("SettingsStore")
	if store == null:
		return
	store.master_linear = 1.0
	store.control_scale = 1.0
	store.control_opacity = 0.85
	store.difficulty = store.DIFF_MEDIUM
	store.stick_norm = Vector2(-1, -1)
	store.dash_norm = Vector2(-1, -1)
	store.save_to_disk()
	store.apply_audio()

func _check_background(rect: TextureRect, label: String, failures: Array[String]) -> void:
	if rect.size.y < 1.0:
		failures.append("background %s has no size" % label)
		return
	rect._apply_aspect()
	var mat := rect.material as ShaderMaterial
	var aspect := float(mat.get_shader_parameter("g_aspect"))
	var expected := rect.size.x / rect.size.y
	if absf(aspect - expected) > 0.04:
		failures.append("background %s aspect %s expected %s" % [label, aspect, expected])
	if label.contains("portrait") and aspect > 1.0:
		failures.append("background %s stayed landscape (%s)" % [label, aspect])
	if label.contains("landscape") and aspect < 1.0:
		failures.append("background %s stayed portrait (%s) rect=%s window=%s visible=%s" % [label, aspect, rect.size, root.size, root.get_visible_rect().size])

func _expect_inside(control: Control, vp: Vector2, label: String, failures: Array[String]) -> void:
	var rect := control.get_global_rect()
	if rect.size.x < 8.0 or rect.size.y < 8.0:
		failures.append("%s has no size %s" % [label, rect])
		return
	if rect.position.x < -2.0 or rect.position.y < -2.0:
		failures.append("%s starts offscreen %s" % [label, rect])
	if rect.end.x > vp.x + 4.0 or rect.end.y > vp.y + 4.0:
		failures.append("%s overflows viewport %s vp=%s" % [label, rect, vp])
