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

const HEROES := preload("res://script/hero_roster.gd")
var hero_picker := preload("res://script/hero_picker.gd").new()
var starter_lottery := preload("res://script/starter_lottery.gd").new()
var hero_index := 0
var game: Node = null
var mobile_controls: CanvasLayer = null
var fullscreen_toggle: CanvasLayer = null
var settings_page: CanvasLayer = null
var _test_mode: StringName = &""
var _rolled_start := false
var _starting_run: bool = false
var _fresh_game := false
var _returning_home := false
var _fitting_render_budget: = false
var session_menu: CanvasLayer

func _ready() -> void :
	get_viewport().size_changed.connect(_configure_render_budget)
	_configure_render_budget()
	_ensure_keyboard_actions()
	main_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	game_end_ui.process_mode = Node.PROCESS_MODE_ALWAYS

	UiFonts.ui()
	UiFonts.ui_bold()
	build_version_label.text = "v" + str(ProjectSettings.get_setting("application/config/version", "dev"))
	build_version_label.tooltip_text = L10n.text("打包时间 · 北京时间 UTC+8")
	get_viewport().size_changed.connect(_layout_build_version)
	_layout_build_version()
	AudioManager.game_track_changed.connect(_on_game_track_changed)
	_ensure_mobile_controls()
	_ensure_fullscreen_toggle()
	session_menu = preload("res://script/session_menu.gd").new()
	session_menu.name = "SessionMenu"
	add_child(session_menu)
	fullscreen_toggle.menu_requested.connect(session_menu.open_menu)
	var codex_button := Button.new()
	codex_button.name = "CodexButton"
	codex_button.text = "游戏词典"
	UiFonts.apply_to_button(codex_button,20)
	codex_button.pressed.connect(func():session_menu.open_codex("","home"))
	var menu_box := $mainUI/Control/MenuCenter/VBoxContainer
	menu_box.add_child(codex_button)
	menu_box.move_child(codex_button,4)
	for item in menu_box.get_children():
		if item is Button: preload("res://script/painted_ui.gd").style_button(item)

	hero_picker.hide()
	$mainUI/Control.add_child(hero_picker)
	add_child(starter_lottery)
	starter_lottery.loadout_claimed.connect(_on_starting_loadout_claimed)
	hero_picker.chosen.connect(_hero_chosen)
	hero_picker.cancelled.connect(func():
		hero_picker.hide()
		menu_page.show()
		build_version_label.show()
		$mainUI/Control/MenuCenter/VBoxContainer/StartButton.grab_focus())
	game_end_ui.hide_result()

	await load_new_game()
	preload("res://script/blood_vortex_fx.gd").warm_at_menu(main_ui, game.combat_feedback.impact_feedback.material)

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


func _ensure_fullscreen_toggle() -> void:
	fullscreen_toggle = get_node_or_null("FullscreenToggle")
	if fullscreen_toggle == null:
		fullscreen_toggle = FULLSCREEN_TOGGLE_SCENE.instantiate()
		fullscreen_toggle.name = "FullscreenToggle"
		add_child(fullscreen_toggle)
	if not fullscreen_toggle.home_requested.is_connected(_on_game_end_ui_main_menu_pressed):
		fullscreen_toggle.home_requested.connect(_on_game_end_ui_main_menu_pressed)
	fullscreen_toggle.set_home_available(false)


func show_main_menu() -> void :
	starter_lottery.hide()
	if session_menu: session_menu.dismiss()
	fullscreen_toggle.set_home_available(false)
	_test_mode = &""
	hero_picker.hide()
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


func start_game(rolled_start := false) -> void :
	_fresh_game = false
	fullscreen_toggle.set_home_available(true)
	_dismiss_settings()
	Engine.time_scale = 1.0

	if AudioManager.has_method("unlock_web_audio"):
		AudioManager.unlock_web_audio()
	AudioManager.play_game_bgm(1, true)
	main_ui.hide()
	game_end_ui.hide_result()

	get_tree().paused = false

	if game and is_instance_valid(game):
		game.start_game(rolled_start)
	if mobile_controls:
		mobile_controls.show_controls()


func _on_start_button_pressed() -> void :
	menu_page.hide()
	build_version_label.hide()
	hero_picker.open(hero_index)

func _hero_chosen(index: int) -> void:
	if _starting_run or not hero_picker.visible: return
	hero_index = index
	hero_picker.hide()
	starter_lottery.open_for(HEROES.START_CARDS[hero_index])


func _on_crimson_practice() -> void:
	debug_page.hide()
	starter_lottery.open_for(HEROES.START_CARDS[hero_index], 20)

func _on_theme_practice(roll: int) -> void:
	debug_page.hide()
	starter_lottery.open_for(HEROES.START_CARDS[hero_index],roll)

func _on_dimension_practice() -> void:
	debug_page.hide()
	starter_lottery.open_for(HEROES.START_CARDS[hero_index], 25)

func _on_starting_loadout_claimed(rolled: Dictionary) -> void:
	await _launch_run(&"", rolled)


func _on_setting_button_pressed() -> void :
	_ensure_settings_page()
	_ensure_mobile_controls()
	settings_page.layer = 70
	settings_page.hint_label.text=L10n.text("拖动摇杆和冲刺键   Drag stick and DASH")
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
	if _returning_home: return
	if session_menu: session_menu.dismiss()
	fullscreen_toggle.set_home_available(false)
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
	if _rolled_start:
		game_end_ui.hide_result()
		starter_lottery.open_for(HEROES.START_CARDS[hero_index])
	else:
		await _launch_run(_test_mode)


func _on_game_end_ui_main_menu_pressed() -> void :
	if _returning_home: return
	_returning_home = true
	if get_tree().has_meta("player_death_slowmo"):
		get_tree().remove_meta("player_death_slowmo")
	fullscreen_toggle.set_home_available(false)
	_dismiss_settings()
	Engine.time_scale = 1.0
	get_tree().paused = true
	game_end_ui.hide_result()

	await load_new_game()

	show_main_menu()
	_returning_home = false


func load_new_game() -> void :
	_fresh_game = false
	if session_menu: session_menu.dismiss()
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
	_fresh_game = true

func _on_debug_button_pressed() -> void :
	menu_page.hide()
	build_version_label.hide()
	debug_page.open_page()

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
	debug_page.show_status(RunDiagnostics.export_report())

func _on_game_track_changed(title: String) -> void :
	var button: Button = debug_page.get_node_or_null("VBoxContainer/DebugMusicButton")
	if button == null or not debug_page.visible or not AudioManager.adventure_music.preview_mode:
		return
	var index: int = AudioManager.adventure_music.track_index + 1
	button.text = L10n.text("试听：%s（%d/8）· 下一首") % [L10n.text(title), index]

func _on_debug_knight_pressed() -> void :
	await _launch_run(&"knight")

func _on_debug_necklace_pressed() -> void :
	await _launch_run(&"necklace")

func _on_debug_treasure_pressed() -> void :
	await _launch_run(&"treasure")

func _launch_run(mode: StringName, opening: Dictionary = {}) -> void :
	if _starting_run or _returning_home:
		return
	_starting_run = true
	_test_mode = mode
	_rolled_start = not opening.is_empty()
	AudioManager.unlock_web_audio()
	if not _fresh_game or not is_instance_valid(game):
		await load_new_game()
	game.diagnostic_mode = str(mode) if mode != &"" else "normal"
	game.player.set_hero(hero_index if mode == &"" else 0)
	start_game(_rolled_start or mode == &"forge")
	if mode == &"":
		game._on_upgrade_selected(HEROES.START_CARDS[hero_index],0)
		for id in opening.get("cards", []):
			game._on_upgrade_selected(id, int(opening.get("tiers",{}).get(id,0)))
		if opening.get("backup", "") != "":
			game._on_upgrade_selected(opening.backup,int(opening.get("tiers",{}).get(opening.backup,0)))
	match mode:
		&"forge":
			game.spawner.stop_run()
			for entry in [["axe_up",2],["axe_up",0],["gun_up",1],["drone_up",0],["bomb",0],["speed_up",1],["regen_up",0],["pickup_up",0],["critical_glasses",3]]:
				game._on_upgrade_selected(entry[0],entry[1])
			game.forge.materials = game.forge.furnace_cost()
			game.forge.earn(180)
			game.forge.seal_stage()
			game._forge_due = true
			game._open_forge()
		&"ghost_dash":
			game.prepare_ghost_dash_debug()
		&"blood_vortex":
			game.prepare_blood_vortex_debug()
		&"draw_slash":
			game.prepare_draw_slash_debug()
		&"ice_wave":
			game.prepare_ice_wave_debug()
		&"light_thorn":
			game.prepare_light_thorn_debug()
		&"arcane_weapons":
			game.prepare_arcane_debug()
		&"relic_weapons":
			game.prepare_relic_debug()
		&"hitstop":
			game.prepare_hitstop_debug()
		&"motion_vfx":
			game.prepare_motion_vfx_debug()
		&"tactical_enemies":
			game.prepare_tactical_enemy_debug()
		&"ink_surf":
			game.prepare_ink_surf_debug()
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
		&"star_chain":
			game.prepare_star_chain_debug()
		&"minefield":
			game.prepare_weather_debug()
			game.weather.set_preview(1,0)
			game.weather.set_hazard(0)
			game.variety.notify(L10n.text("九宫格地雷：红灯闪烁表示危险\n踩中后爆炸击退，触发3秒后恢复\n玩家24 / 怪物72起；冲刺可避伤害"))
		&"electric_grid":
			game.prepare_weather_debug()
			game.weather.set_hazard(1)
			game.variety.notify(L10n.text("电网：每0.5秒放电，探索刷新4处圆形 / 方形区域\n麻痹1秒；恢复后0.5秒电网保护\n引怪入网，近距离传导每次脉冲只命中一次"))
		&"wind_scene":
			game.prepare_surface_debug(4)
		&"ice_scene":
			game.prepare_surface_debug(5)
			game.weather.set_hazard(2)
		&"winter":
			game.prepare_weather_debug()
			game.weather.set_preview(3, 0)
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
		&"fan_status":
			game.prepare_fan_status_debug()
		&"bomb", &"bomb5", &"arsenal":
			game.prepare_bomb_debug(mode)
		&"growth", &"equipment_combos":
			game.prepare_growth_debug(mode == &"equipment_combos")
		&"critical", &"critical5":
			game.prepare_critical_debug(5 if mode == &"critical5" else 1)
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
