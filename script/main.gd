extends Node2D

@onready var main_ui: CanvasLayer = $mainUI
@onready var game_end_ui: Node2D = $GameEndUI
@onready var menu_page: Control = $mainUI / Control / MenuCenter
@onready var debug_page: Control = $mainUI / Control / DebugCenter
@onready var game_root: Node = $GameRoot
@onready var build_version_label: Label = $mainUI / Control / BuildVersionLabel

const GAME_SCENE: = preload("res://scenes/game.tscn")
const MOBILE_CONTROLS_SCENE: = preload("res://scenes/mobile_controls.tscn")
const FULLSCREEN_TOGGLE_SCENE: = preload("res://scenes/fullscreen_toggle.tscn")
const SETTINGS_PAGE_SCENE: = preload("res://scenes/settings_page.tscn")

var game: Node = null
var mobile_controls: CanvasLayer = null
var fullscreen_toggle: CanvasLayer = null
var settings_page: CanvasLayer = null
var _test_mode: StringName = &""
var _starting_run: bool = false
var _fitting_render_budget: = false

func _ready() -> void :
	get_viewport().size_changed.connect(_configure_render_budget)
	_configure_render_budget()
	_ensure_keyboard_actions()
	main_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	game_end_ui.process_mode = Node.PROCESS_MODE_ALWAYS

	UiFonts.ui()
	UiFonts.ui_bold()
	build_version_label.text = "v" + str(ProjectSettings.get_setting("application/config/version", "dev"))
	build_version_label.tooltip_text = "打包时间 · 北京时间 UTC+8"
	get_viewport().size_changed.connect(_layout_build_version)
	_layout_build_version()
	AudioManager.game_track_changed.connect(_on_game_track_changed)
	_ensure_mobile_controls()
	_ensure_fullscreen_toggle()

	game_end_ui.hide_result()

	await load_new_game()
	game.prepare_game()

	show_main_menu()

func _configure_render_budget() -> void :
	if _fitting_render_budget: return
	_fitting_render_budget = true
	var window: = get_tree().root
	var pixels: = window.size
	var base: = window.content_scale_size
	if base.x > 0 and base.y > 0:


		var upscale: = minf(float(pixels.x) / base.x, float(pixels.y) / base.y)
		var desired: = Window.CONTENT_SCALE_MODE_VIEWPORT if upscale > 1.001 else Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		if window.content_scale_mode != desired: window.content_scale_mode = desired
	_fitting_render_budget = false


func _ensure_keyboard_actions() -> void :
	_bind_key("up", KEY_W)
	_bind_key("up", KEY_UP)
	_bind_key("down", KEY_S)
	_bind_key("down", KEY_DOWN)
	_bind_key("left", KEY_A)
	_bind_key("left", KEY_LEFT)
	_bind_key("right", KEY_D)
	_bind_key("right", KEY_RIGHT)
	_bind_key("roll", KEY_SHIFT)
	_bind_key("beast_skill", KEY_E)
	_bind_key("beast_cycle", KEY_Q)

func _bind_key(action: StringName, keycode: Key) -> void :
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == keycode:
			return
	var key: = InputEventKey.new()
	key.physical_keycode = keycode
	InputMap.action_add_event(action, key)

func _ensure_mobile_controls() -> void :
	if mobile_controls != null and is_instance_valid(mobile_controls):
		return
	mobile_controls = MOBILE_CONTROLS_SCENE.instantiate()
	add_child(mobile_controls)
	mobile_controls.hide_controls()


func _ensure_fullscreen_toggle() -> void :

	fullscreen_toggle = get_node_or_null("FullscreenToggle")
	if fullscreen_toggle != null and is_instance_valid(fullscreen_toggle):
		return
	fullscreen_toggle = FULLSCREEN_TOGGLE_SCENE.instantiate()
	fullscreen_toggle.name = "FullscreenToggle"
	add_child(fullscreen_toggle)


func show_main_menu() -> void :
	_test_mode = &""
	debug_page.hide()
	menu_page.show()
	build_version_label.show()
	Engine.time_scale = 1.0
	main_ui.show()
	game_end_ui.hide_result()
	AudioManager.play_menu_bgm()
	if mobile_controls:
		mobile_controls.hide_controls()
	if game and is_instance_valid(game):
		game.prepare_game()

	get_tree().paused = true

func _layout_build_version() -> void :
	var vp: = get_viewport().get_visible_rect().size
	var ui_scale: = 2.0 if vp.y > vp.x else 1.0
	UiFonts.apply_to_label(build_version_label, int(16 * ui_scale))
	build_version_label.position = Vector2(14 * ui_scale, vp.y - 36 * ui_scale)
	build_version_label.size = Vector2(vp.x - 28 * ui_scale, 24 * ui_scale)


func start_game() -> void :
	_dismiss_settings()
	Engine.time_scale = 1.0

	if AudioManager.has_method("unlock_web_audio"):
		AudioManager.unlock_web_audio()
	AudioManager.play_game_bgm(1, true)
	main_ui.hide()
	game_end_ui.hide_result()

	get_tree().paused = false

	if game and is_instance_valid(game):
		game.start_game()
	if mobile_controls:
		mobile_controls.show_controls()


func _on_start_button_pressed() -> void :
	await _launch_run(&"")


func _on_setting_button_pressed() -> void :
	_ensure_settings_page()
	_ensure_mobile_controls()
	settings_page.open_page()
	if mobile_controls:
		mobile_controls.begin_layout_edit()


func _ensure_settings_page() -> void :
	if settings_page != null and is_instance_valid(settings_page):
		return
	settings_page = SETTINGS_PAGE_SCENE.instantiate()
	settings_page.name = "SettingsPage"
	add_child(settings_page)
	settings_page.closed.connect(_on_settings_closed)


func _on_settings_closed() -> void :
	if mobile_controls and is_instance_valid(mobile_controls):
		mobile_controls.end_layout_edit()


func _dismiss_settings() -> void :
	if settings_page and is_instance_valid(settings_page):
		settings_page.visible = false
	if mobile_controls and is_instance_valid(mobile_controls) and mobile_controls.layout_edit:
		mobile_controls.end_layout_edit()


func on_game_over(stat: Dictionary) -> void :
	Engine.time_scale = 1.0

	if game and is_instance_valid(game):
		game.end_game()
	if mobile_controls:
		mobile_controls.hide_controls()

	get_tree().paused = true

	if stat.get("victory", false):
		AudioManager.play_victory()
	else:
		AudioManager.play_game_over()

	game_end_ui.show_result(stat)


func _on_game_end_ui_retry_pressed() -> void :
	await _launch_run(_test_mode)


func _on_game_end_ui_main_menu_pressed() -> void :
	game_end_ui.hide_result()

	await load_new_game()
	game.prepare_game()

	show_main_menu()


func load_new_game() -> void :
	if is_instance_valid(game):
		game.end_game()
	for child in game_root.get_children():
		child.queue_free()

	await get_tree().process_frame

	game = GAME_SCENE.instantiate()
	game.name = "game"
	game.add_to_group("game")
	game_root.add_child(game)
	mobile_controls.bind_player(game.player)

	if game.has_signal("game_over"):
		game.game_over.connect(on_game_over)

func _on_debug_button_pressed() -> void :
	if not AudioManager.adventure_music.active:
		$mainUI / Control / DebugCenter / VBoxContainer / DebugMusicButton.text = "音乐试听 / 下一首"
	menu_page.hide()
	build_version_label.hide()
	debug_page.show()
	$mainUI / Control / DebugCenter / VBoxContainer / DebugKnightButton.grab_focus()

func _on_debug_back_pressed() -> void :
	AudioManager.play_menu_bgm()
	debug_page.hide()
	menu_page.show()
	build_version_label.show()
	$mainUI / Control / MenuCenter / VBoxContainer / DebugButton.grab_focus()

func _on_debug_music_pressed() -> void :
	AudioManager.unlock_web_audio()
	AudioManager.preview_game_bgm_next()

func _on_debug_report_pressed() -> void :
	$mainUI / Control / DebugCenter / VBoxContainer / DebugHint.text = RunDiagnostics.export_report()

func _on_game_track_changed(title: String) -> void :
	if not debug_page.visible or not AudioManager.adventure_music.preview_mode:
		return
	var index: int = AudioManager.adventure_music.track_index + 1
	$mainUI / Control / DebugCenter / VBoxContainer / DebugMusicButton.text = "试听：%s（%d/8）· 下一首" % [title, index]

func _on_debug_knight_pressed() -> void :
	await _launch_run(&"knight")

func _on_debug_necklace_pressed() -> void :
	await _launch_run(&"necklace")

func _on_debug_treasure_pressed() -> void :
	await _launch_run(&"treasure")

func _launch_run(mode: StringName) -> void :
	if _starting_run:
		return
	_starting_run = true
	_test_mode = mode
	AudioManager.unlock_web_audio()
	await load_new_game()
	game.diagnostic_mode = str(mode) if mode != &"" else "normal"
	start_game()
	match mode:
		&"juice":
			game.prepare_feedback_debug()
		&"lighting":
			game.prepare_lighting_debug()
		&"boss1":
			game.prepare_first_boss_debug()
		&"blessings":
			game.prepare_blessing_debug()
		&"knight":
			game.prepare_knight_debug_fight()
		&"necklace":
			game.prepare_necklace_debug_run()
		&"treasure":
			game.prepare_treasure_debug_run()
		&"lightning":
			game.prepare_lightning_debug_run()
		&"weather":
			game.prepare_weather_debug()
		&"variety":
			game.prepare_variety_debug()
		&"meteor":
			game.prepare_meteor_debug()
		&"poison", &"poison5":
			game.prepare_poison_debug(5 if mode == &"poison5" else 1)
		&"fan", &"fan5", &"black_hole", &"black_hole5", &"control_cards":
			game.prepare_control_debug(mode)
		&"stability":
			var test: Node = load("res://script/stability_test.gd").new()
			test.name = "StabilityTest"
			game.add_child(test)
			test.start()
	if str(mode).begins_with("trial_"):
		game.prepare_trial_debug(str(mode).trim_prefix("trial_"))
	if str(mode).begins_with("beast_"):
		game.prepare_beast_debug(int(str(mode).trim_prefix("beast_")))
	_starting_run = false
