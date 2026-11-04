extends Node

var game: Node
var duration: = 60.0
var elapsed: = 0.0
var _spawn_left: = 1.0
var _label: Label
var _layer: CanvasLayer
var _buttons: HBoxContainer
var _done: = false
const LOADOUT: = {"axe_up": 5, "circle_up": 16, "gun_up": 8, "drone_up": 6, "molotov_up": 6, "freeze_up": 6, "lightning_ring": 6, "monster_necklace": 4, "lifesteal_up": 4, "regen_up": 4, "shield_up": 4, "wind_emblem": 5, "echo_ember": 5, "poison_trail": 5}

func _ready() -> void :
	game = get_parent()
	add_to_group("diagnostic_ui")
	_layer = CanvasLayer.new()
	_layer.layer = 95
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	_layer.add_child(_label)
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 12)
	_layer.add_child(_buttons)
	for title in ["导出报告", "停止 / 返回主页"]:
		var button: = Button.new()
		button.text = title
		button.custom_minimum_size = Vector2(260, 56)
		_buttons.add_child(button)
	_buttons.get_child(0).pressed.connect( func(): _label.text = RunDiagnostics.export_report())
	_buttons.get_child(1).pressed.connect(stop)
	get_viewport().size_changed.connect(_fit)
	_fit()

func start(seconds: float = 60.0) -> void :
	duration = seconds
	RunDiagnostics.batching = true
	seed(969969)
	game.current_level = 18
	game.level_manager.level = 18
	game.level_manager.label.text = "Level: 18"
	game.level_manager.level_need_coin_number = game.level_manager.get_need_exp(18)
	game.spawner.handle_level_up(18)
	game.player.apply_level_growth(18)
	if game.level_manager.signal_level_up.is_connected(game.on_level_up):
		game.level_manager.signal_level_up.disconnect(game.on_level_up)
	for id in LOADOUT:
		for _i in LOADOUT[id]:
			game._on_upgrade_selected(id)
	game.player.max_player_health = 1000000.0
	game.player.player_health = 1000000.0
	game.player.health_bar.set_max_health(1000000, 1000000)
	for index in range(4):
		game.beast_powers.unlock(index)
	game.spawner.debug_start_beast(6)
	var boss: Node = game.spawner._active_bosses[0]
	boss.last_hitstop_msec = Time.get_ticks_msec() + 3600000


	boss.health_max_value = 1000000000000.0
	boss.boss_current_health = boss.health_max_value
	boss.health_bar.init_health(boss.health_max_value)
	boss.apply_hit({"damage": boss.health_max_value * 0.55, "ignore_side_bonus": true, "from_status": true})
	RunDiagnostics.batching = false
	RunDiagnostics.mark("stress_ready", {"seed": 969969, "seconds": duration, "scenario": "final_beast_phase_two"}, true)
	_replenish()

func _process(delta: float) -> void :
	if _done:
		return
	elapsed += delta
	_spawn_left -= delta
	if _spawn_left <= 0.0:
		_spawn_left = 1.0
		_replenish()
	_label.text = "后期压力测试  %.0f / %.0f 秒\nFPS %d · 节点 %d · 书本 %d · 特效 %d · 拾取 %d" % [elapsed, duration, Engine.get_frames_per_second(), Performance.get_monitor(Performance.OBJECT_NODE_COUNT), game.circle_weapon.get_child_count(), game.effect_container.get_child_count(), game.pickup_container.get_child_count()]
	if elapsed >= duration:
		_done = true
		RunDiagnostics.finish("stress_complete")
		_label.text = "压力测试完成，可导出报告\n最大节点 %d · 书本 %d · 特效 %d" % [RunDiagnostics.report.peaks.get("nodes", 0), RunDiagnostics.report.peaks.get("books", 0), RunDiagnostics.report.peaks.get("effects", 0)]
		get_tree().paused = true

func _replenish() -> void :
	var alive: = 0
	for enemy in get_tree().get_nodes_in_group("EnemyGroup"):
		if game.is_ancestor_of(enemy) and not enemy.has_signal("boss_defeated"):
			alive += 1
	for _i in maxi(0, 16 - alive):
		game.spawner.spawn(game.player.global_position + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(145, 220), false)

func owns_pointer(point: Vector2) -> bool:
	for button in _buttons.get_children():
		if button.get_global_rect().has_point(point):
			return true
	return false

func _fit() -> void :
	var vp: = get_viewport().get_visible_rect().size
	var scale: = 2.0 if vp.y > vp.x else 1.0
	UiFonts.apply_to_label(_label, int(16 * scale), true)
	_label.position = Vector2(20, 112 * scale)
	_label.size = Vector2(vp.x - 40, 90 * scale)
	var width: = minf(720, vp.x - 40)
	for button in _buttons.get_children():
		button.custom_minimum_size = Vector2((width - 12) * 0.5, 56 * scale)
		UiFonts.apply_to_button(button, int(18 * scale))
	_buttons.position = Vector2((vp.x - width) * 0.5, vp.y - 76 * scale)

func stop() -> void :
	RunDiagnostics.finish("stress_stopped")
	get_tree().paused = false
	Engine.time_scale = 1.0
	game.end_game()
	_layer.hide()
	set_process(false)
	var main: = get_tree().current_scene
	if main != null and main.has_method("show_main_menu"):
		main.show_main_menu()
	queue_free()
