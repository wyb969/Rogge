extends Node

signal completed(kind: String, passed: bool, settle: bool)
const ENEMY: = preload("res://scenes/trial_enemy.tscn")
const HORDE := preload("res://script/wooden_trial.gd")
const TITLES := {"power": "力量试炼", "speed": "速度试炼", "wooden": "木头人挑战"}
enum TrialFlow{IDLE, INTRO, ACTIVE, RESULT, DONE}
const RULES: = {
	"wooden": "目标：原地抵挡 60 秒怪潮，活下来即通过。\n移动和冲刺锁定，自动攻击与装备效果保留。\n可点击左侧神兽技能治疗、清场或防御。\n每 20 秒增强一波，击杀仍会掉落补给。\n开始与重试都会补满生命，说明页不计时。",
	"power": "目标：60 秒内击败重甲机械章鱼。\n它移动较慢、血量很高，会用激光锁定你。\n听到锁定音，留意红色瞄准线和准星。\n最后一段预警方向固定：横移或冲刺躲激光。\n说明页不计时，准备好后点击开始。\n卡片和已获得的神兽技能均可使用。", 
	"speed": "目标：击败近身瞬移的巫刃术士。\n它瞬移到你身边后，0.5 秒内发起扇形斩击。\n红色预警期间按 Shift / DASH 冲刺避开。\n成功冲刺躲斩后，才有 1.5 秒反击窗口。\n屏障关闭时攻击无效，耐心等下一轮。\n本关不限总时间，卡片与神兽技能均可使用。"
}
var flow: = TrialFlow.IDLE
var kind: = "power"
var elapsed: = 0.0
var results: Dictionary = {}
var enemy: Node2D
var game: Node
var player: Node
var _token: = 0
var _passed: = false
var _modal: CanvasLayer
var _panel: PanelContainer
var _box: VBoxContainer
var _title: Label
var _icon: TextureRect
var _body: Label
var _actions: VBoxContainer
var _hud: CanvasLayer
var _clock: Label
var start_button: Button
var retry_button: Button
var continue_button: Button
var settle_button: Button
var horde: Node2D

func _ready() -> void :
	game = get_parent()
	player = game.get_node("Player")
	_build_ui()
	horde = HORDE.new()
	horde.name = "WoodenHorde"
	add_child(horde)
	get_viewport().size_changed.connect(_fit)

func active_fight() -> bool:
	return flow == TrialFlow.ACTIVE

func blocks_rewards() -> bool:
	return flow in [TrialFlow.INTRO, TrialFlow.ACTIVE, TrialFlow.RESULT]

func begin(value: String) -> void :
	if blocks_rewards() or not RULES.has(value):
		return
	kind = value
	flow = TrialFlow.INTRO
	elapsed = 0
	game.spawner._rest_open = true
	game.spawner.timer.stop()
	game.spawner.get_node("Elite").stop()
	game.spawner._clear_minions()
	game.spawner_ui.hide()
	_set_controls(false)
	get_node("/root/AudioManager").play_game_bgm(game.spawner.stage)
	_show_modal(TITLES[kind] + " · 挑战说明", RULES[kind])
	start_button = _button("开始试炼", start_attempt)
	_fit()
	get_tree().paused = true
	start_button.grab_focus()

func start_attempt() -> void :
	if flow != TrialFlow.INTRO and flow != TrialFlow.RESULT:
		return
	_cleanup_enemy()
	_token += 1
	elapsed = 0
	Engine.time_scale = 1.0
	_passed = false
	flow = TrialFlow.ACTIVE
	game.spawner._boss_fight_active = true
	game.clear_run_objects()
	game.variety.clear_combat_effects()
	player.player_health = player.max_player_health
	player.health_bar.set_health(player.player_health)
	player.hurt_lock = 0
	player.reset_dash()
	game.damage_flash.reset()
	var mobile: = get_node("/root/MobileInput")
	mobile.clear_move()
	mobile.clear_dash()
	_modal.hide()
	_hud.show()
	if kind == "wooden":
		player.set_movement_locked(true)
		horde.begin(game)
	else:
		enemy = ENEMY.instantiate()
		enemy.configure_trial(kind, self)
		enemy.set_player(player)
		enemy.add_to_group("EnemyGroup")
		enemy.boss_defeated.connect(_on_enemy_defeated.bind(_token))
		game.add_child(enemy)
		enemy.apply_difficulty_health(game.run_difficulty.health_scale)
		enemy.global_position = player.global_position + Vector2(-115, -40)
		enemy.reset_physics_interpolation()
	get_node("/root/AudioManager").play_boss_bgm(4 if kind == "power" else 5)
	get_tree().paused = false
	_set_controls(kind != "wooden")
	_update_clock()

func _process(delta: float) -> void :
	if flow != TrialFlow.ACTIVE or get_tree().paused:
		return


	var active_delta: = delta / maxf(Engine.time_scale, 0.001)
	elapsed += active_delta
	game.spawner.run_seconds += active_delta
	game.spawner._sync_run_clock()
	_update_clock()
	if kind == "wooden":
		if player.player_health <= 0:
			fail("生命耗尽：未能抵挡本次怪潮。")
		elif elapsed >= 60.0:
			_finish(true, "")
		else:
			horde.advance(active_delta, elapsed)
	elif kind == "power" and elapsed >= 60:
		fail("时间已到：需要在 60 秒内完成击杀。")

func _on_enemy_defeated(token: int) -> void :
	if token != _token or flow != TrialFlow.ACTIVE:
		return
	if kind == "power" and elapsed > 60:
		fail("时间已到：本次未在限时内完成。")
		return
	game.spawner.enemy_killed_num += 1
	_finish(true, "")

func fail(reason: String) -> void :
	if flow != TrialFlow.ACTIVE:
		return
	_finish(false, reason)

func _finish(passed: bool, reason: String) -> void :
	flow = TrialFlow.RESULT
	Engine.time_scale = 1.0
	game.spawner._boss_fight_active = false
	_passed = passed
	_token += 1
	_cleanup_enemy()
	_hud.hide()
	_set_controls(false)
	get_node("/root/AudioManager").play_game_bgm(game.spawner.stage)
	var name_text: String = TITLES[kind]
	var body: = ("成功击败试炼敌人！\n用时 %.1f 秒。\n继续后进入休整区，保留当前全部构筑。" % elapsed) if passed else reason + "\n卡片与神兽技能会保留。\n重试会回复生命，并重置冲刺。\n也可以放弃本次试炼，按下方选项继续。"
	if passed and kind == "speed":
		body = "成功抓住冲刺反击的时机，击败巫刃术士！\n接下来是木头人挑战：原地抵挡 60 秒怪潮。\n保留全部装备与神兽技能，准备好后继续。"
	if passed and kind == "wooden":
		body = "成功抵挡 60 秒怪潮！\n移动与冲刺已恢复，木头人挑战通过。\n可通关结算，或进入自由试炼。"
	_show_modal(name_text + (" · 通过" if passed else " · 未通过"), body)
	if not passed:
		retry_button = _button("重试试炼", start_attempt)
	if kind == "power":
		continue_button = _button("继续休整" if passed else "放弃本次试炼 · 继续主线", _continue.bind(false))
	elif kind == "speed":
		continue_button = _button("进入木头人挑战" if passed else "放弃本次试炼 · 进入木头人挑战", _continue.bind(false))
	else:
		continue_button = _button("进入自由试炼" if passed else "放弃本次试炼 · 进入自由试炼", _continue.bind(false))
		settle_button = _button("通关结算" if passed else "放弃本次试炼 · 通关结算", _continue.bind(true))
	_fit()
	get_tree().paused = true
	(continue_button if passed else retry_button).grab_focus()

func _continue(settle: bool) -> void :
	if flow != TrialFlow.RESULT:
		return
	flow = TrialFlow.DONE
	results[kind] = {"passed": _passed, "seconds": elapsed}
	_modal.hide()
	_hud.hide()
	player.player_health = player.max_player_health
	player.full_heal()
	game.spawner_ui.show()
	get_tree().paused = false
	_set_controls(true)
	completed.emit(kind, _passed, settle)

func _cleanup_enemy() -> void :
	player.set_movement_locked(false)
	if is_instance_valid(horde): horde.stop()
	if is_instance_valid(enemy):
		enemy.remove_from_group("EnemyGroup")
		enemy.remove_from_group("trial_enemy")
		enemy.set_physics_process(false)
		enemy.queue_free()
	enemy = null
	for shot in get_tree().get_nodes_in_group("enemy_projectile"):
		if is_instance_valid(shot):
			shot.queue_free()

func reset() -> void :
	flow = TrialFlow.IDLE
	_token += 1
	_cleanup_enemy()
	_modal.hide()
	_hud.hide()

func _set_controls(showing: bool) -> void :
	var main: = get_tree().current_scene
	if main != null and main.get("mobile_controls") != null:
		if showing:
			main.mobile_controls.show_controls()
		else:
			main.mobile_controls.hide_controls()

func _build_ui() -> void :
	_hud = CanvasLayer.new()
	_hud.layer = 45
	add_child(_hud)
	_clock = Label.new()
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.03))
	_clock.add_theme_constant_override("outline_size", 5)
	UiFonts.apply_to_label(_clock, 24, true)
	_hud.add_child(_clock)
	_hud.hide()
	_modal = CanvasLayer.new()
	_modal.layer = 136
	_modal.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_modal)
	var dim: = ColorRect.new()
	dim.color = Color(0.015, 0.025, 0.045, 0.95)
	_modal.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center: = CenterContainer.new()
	_modal.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	var style: = StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.055, 0.09)
	style.border_color = Color(0.55, 0.78, 0.94)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 10)
	_panel.add_child(_box)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(_title)
	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_box.add_child(_icon)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(_body)
	_actions = VBoxContainer.new()
	_actions.add_theme_constant_override("separation", 8)
	_box.add_child(_actions)
	_modal.hide()
	_fit()

func _show_modal(title: String, body: String) -> void :
	start_button = null
	retry_button = null
	continue_button = null
	settle_button = null
	for child in _actions.get_children():
		_actions.remove_child(child)
		child.queue_free()
	_title.text = title
	_body.text = body
	var icons := {"power": "clockwork_octopus", "speed": "blink_wizard", "wooden": "wooden_dummy"}
	_icon.texture = load("res://assest/sprites/trials/%s.svg" % icons[kind])
	_modal.show()

func _button(text_value: String, callback: Callable) -> Button:
	var button: = Button.new()
	button.text = text_value
	button.pressed.connect(callback)
	_actions.add_child(button)
	return button

func _update_clock() -> void :
	if kind == "wooden":
		_clock.text = "木头人 · %.1f 秒 · 第%d/3波\n移动 / 冲刺锁定 · 神兽技能可用" % [maxf(0, 60 - elapsed), mini(3, int(elapsed / 20.0) + 1)]
		return
	_clock.text = "力量试炼 · %.1f 秒" % maxf(0, 60 - elapsed) if kind == "power" else "速度试炼 · 冲刺后反击"

func _fit() -> void :
	if not is_instance_valid(_panel):
		return
	var vp: = get_viewport().get_visible_rect().size
	var scale_ui: = maxf(1, vp.x / 450) if vp.y > vp.x else 1.0
	var compact := vp.y < 520.0
	var width: = minf(vp.x - 48, 620 * scale_ui)
	_panel.custom_minimum_size.x = width
	_title.custom_minimum_size.x = width - 36
	_body.custom_minimum_size.x = width - 36
	UiFonts.apply_to_label(_title, int((22 if compact else 26) * scale_ui), true)
	UiFonts.apply_to_label(_body, int((14 if compact else 16) * scale_ui))
	_icon.custom_minimum_size = Vector2.ONE * (36 if compact else 64) * scale_ui
	for button in _actions.get_children():
		button.custom_minimum_size.y = 48 * scale_ui
		UiFonts.apply_to_button(button, int(17 * scale_ui))
	_clock.position = Vector2(24, 14)
	_clock.size = Vector2(vp.x - 48, (64 if kind == "wooden" else 44) * scale_ui)
	UiFonts.apply_to_label(_clock, int((20 if kind == "wooden" else 24) * scale_ui), true)
