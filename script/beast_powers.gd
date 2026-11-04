extends Node2D

const IDS: = ["tide", "thunder", "gale", "aegis"]
const TITLES: = ["潮汐复苏", "雷霆裁决", "苍风牵引", "玄岩壁垒"]
const COLORS: = [Color(0.28, 0.85, 0.95), Color(1.0, 0.83, 0.3), Color(0.6, 1.0, 0.78), Color(1.0, 0.56, 0.26)]
const COOLDOWNS: = [35.0, 45.0, 22.0, 40.0]
const BLESSING_FX: = preload("res://script/blessing_effect.gd")
const SKILL_ICON: = preload("res://script/beast_skill_icon.gd")
const DESCRIPTIONS: = ["回复 45% 最大生命\n冷却 35 秒，满血不消耗", "雷击屏幕内敌人并清除敌弹\n对 Boss 造成 6% 最大生命伤害（上限 420）\n冷却 45 秒", "牵引全地图已掉落的金币与回血球\n没有掉落时不消耗，冷却 22 秒", "6 秒内受到的伤害降低 90%\n冷却 40 秒"]
var unlocked: Array[int] = []
var cooldowns: Array[float] = [0.0, 0.0, 0.0, 0.0]
var selected: = 0
var barrier_left: = 0.0
var game: Node
var player: Node2D
var _canvas: CanvasLayer
var _column: VBoxContainer
var _buttons: Dictionary = {}
var finish_button: Button
var _notice: Label
var _notice_left: = 0.0
var blessing_fx: Node2D
var _screen_veil: ColorRect
var _bolt_targets: Array[Vector2] = []
var _reward: CanvasLayer
var reward_claim: Button
var reward_finish: Button
var _pending_reward: = -1
var _reward_box: VBoxContainer
var _reward_icon: TextureRect
signal blessing_claimed(stage: int, settle: bool)

func _ready() -> void :
	game = get_parent()
	player = game.get_node("Player")
	add_to_group("beast_power_ui")
	_build_ui()
	blessing_fx = BLESSING_FX.new()
	blessing_fx.name = "BlessingEffect"
	add_child(blessing_fx)
	get_viewport().size_changed.connect(_layout)

func unlock(index: int) -> void :
	if unlocked.has(index):
		return
	unlocked.append(index)
	unlocked.sort()
	selected = index
	var button: = SKILL_ICON.new()
	button.configure(load("res://assest/sprites/beasts/skill_%s.svg" % IDS[index]), COLORS[index])
	button.tooltip_text = TITLES[index] + "\n" + description_for(index) + "\n点击直接释放 / E 释放当前 / Q 键切换"
	button.pressed.connect(cast.bind(index))
	_column.add_child(button)
	_buttons[index] = button
	_layout()
	_refresh()

func select(index: int) -> void :
	if unlocked.has(index):
		selected = index
		_refresh()

func cast(index: int) -> bool:
	if not unlocked.has(index): return false
	select(index)
	return cast_selected()

func description_for(index: int) -> String:
	if index == 0:
		var percent: = ("%.1f" % (45.0 * player.healing_multiplier)).trim_suffix(".0")
		return "回复 %s%% 最大生命\n冷却 35 秒，满血不消耗" % percent
	return DESCRIPTIONS[index]

func cycle() -> void :
	if unlocked.is_empty() or get_tree().paused:
		return
	selected = unlocked[(unlocked.find(selected) + 1) % unlocked.size()]
	_refresh()

func _unhandled_input(event: InputEvent) -> void :
	if get_tree().paused or not game.visible or not _canvas.visible or player.player_health <= 0:
		return
	if event.is_action_pressed("beast_skill") and not event.is_echo():
		cast_selected()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("beast_cycle") and not event.is_echo():
		cycle()
		get_viewport().set_input_as_handled()

func cast_selected() -> bool:
	if get_tree().paused or not game.visible or player.player_health <= 0 or not unlocked.has(selected) or cooldowns[selected] > 0.0:
		return false
	match selected:
		0:
			if player.heal(player.max_player_health * 0.45) <= 0:
				_notify("生命已满，技能保留")
				return false
		1:
			_bolt_targets.clear()
			for enemy in get_tree().get_nodes_in_group("EnemyGroup"):
				if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or not _on_screen(enemy):
					continue
				_bolt_targets.append(enemy.global_position)
				var damage: float = 180.0 + 12.0 * game.current_level
				if enemy.has_signal("boss_defeated"):
					damage = minf(float(enemy.health_max_value) * 0.06, 420.0)
				if enemy.has_method("apply_hit"):
					enemy.apply_hit({"damage": damage, "direction": Vector2.ZERO, "from_status": true, "ignore_side_bonus": true})
			if not _bolt_targets.is_empty():
				game.show_lightning_strikes(_bolt_targets, game.LIGHTNING_FX.GOLD)
			for shot in get_tree().get_nodes_in_group("enemy_projectile"):
				if is_instance_valid(shot) and _on_screen(shot):
					shot.queue_free()
		2:
			var count: = 0
			for pickup in game.pickup_container.get_children():
				if not pickup is Node2D or pickup.is_queued_for_deletion():
					continue
				if pickup.is_in_group("healing_orb"):
					pickup.start_global_pickup()
					count += 1
				elif pickup.has_method("start_pickup") and not pickup.is_collecting and not pickup.start_pick:
					pickup.player_body = player
					pickup.start_pickup()
					count += 1
			if count == 0:
				_notify("地图上没有可拾取物，技能保留")
				return false
		3:
			barrier_left = 6.0
			player.beast_damage_scale = 0.1
	cooldowns[selected] = COOLDOWNS[selected]
	blessing_fx.play(selected)
	_notify(TITLES[selected] + "！")
	get_node("/root/AudioManager").play_beast_power(selected)
	_refresh()
	return true

func _on_screen(node: Node2D) -> bool:
	return get_viewport().get_visible_rect().has_point(get_viewport().get_canvas_transform() * node.global_position)

func _process(delta: float) -> void :
	if get_tree().paused:
		return
	for i in 4:
		cooldowns[i] = maxf(0, cooldowns[i] - delta)
	barrier_left = maxf(0, barrier_left - delta)
	player.beast_damage_scale = 0.1 if barrier_left > 0 else 1.0
	_notice_left = maxf(0, _notice_left - delta)
	_notice.visible = _notice_left > 0
	blessing_fx.advance(delta)
	_screen_veil.color.a = BLESSING_FX.SCREEN_ALPHA * blessing_fx.opacity()
	_screen_veil.visible = _screen_veil.color.a > 0
	global_position = player.global_position
	_refresh()
	queue_redraw()

func _draw() -> void :
	if barrier_left > 0:
		draw_arc(Vector2.ZERO, 34, 0, TAU, 48, Color(COLORS[3], 0.5), 1.5, false)
		draw_arc(Vector2.ZERO, 39, 0, TAU, 6, Color(COLORS[3], 0.25), 1, false)

func _notify(message: String) -> void :
	_notice.text = message
	_notice_left = 2.4

func _style(color: Color, selected_style: bool = false) -> StyleBoxFlat:
	var s: = StyleBoxFlat.new()
	s.bg_color = Color(0.025, 0.04, 0.07, 0.92)
	s.border_color = color if selected_style else Color(0.2, 0.26, 0.34)
	s.set_border_width_all(3 if selected_style else 1)
	s.set_corner_radius_all(8)
	s.content_margin_left = 8
	s.content_margin_right = 8
	return s

func _build_ui() -> void :
	_canvas = CanvasLayer.new()
	_canvas.layer = 85
	add_child(_canvas)
	_screen_veil = ColorRect.new()
	_screen_veil.color = Color(BLESSING_FX.GREEN, 0)
	_screen_veil.hide()
	_screen_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_screen_veil)
	_screen_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 7)
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_column)
	finish_button = Button.new()
	finish_button.text = "通关结算"
	finish_button.pressed.connect(game.on_boss_defeated)
	finish_button.hide()
	_canvas.add_child(finish_button)
	_notice = Label.new()
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiFonts.apply_to_label(_notice, 18, true)
	_notice.add_theme_color_override("font_outline_color", Color.BLACK)
	_notice.add_theme_constant_override("outline_size", 4)
	_canvas.add_child(_notice)
	_layout()

func _layout() -> void :
	if not is_instance_valid(_column):
		return
	var vp: = get_viewport().get_visible_rect().size
	var scale_ui: = maxf(1, vp.x / 450) if vp.y > vp.x else 1.0
	_column.position = Vector2(12, 120) * scale_ui
	_column.add_theme_constant_override("separation", int(6 * scale_ui))
	for index in _buttons:
		var button: Button = _buttons[index]
		button.custom_minimum_size = Vector2(48, 48) * scale_ui
		button.size = Vector2(48, 48) * scale_ui
		button.add_theme_constant_override("icon_max_width", int(36 * scale_ui))
	_column.set_deferred("size", Vector2(48 * scale_ui, maxf(0, _buttons.size() * 54 - 6) * scale_ui))
	finish_button.size = Vector2(145, 40) * scale_ui
	finish_button.position = Vector2(14, vp.y - 58 * scale_ui)
	UiFonts.apply_to_button(finish_button, int(15 * scale_ui))
	_notice.position = Vector2(vp.x * 0.2, 94 * scale_ui)
	_notice.size = Vector2(vp.x * 0.6, 50 * scale_ui)
	UiFonts.apply_to_label(_notice, int(18 * scale_ui), true)
	_layout_reward()

func _refresh() -> void :
	for i in _buttons:
		_buttons[i].set_state(cooldowns[i], COOLDOWNS[i], selected == i)

func owns_pointer(point: Vector2) -> bool:
	if not _canvas.visible:
		return false
	for button in [finish_button] + _buttons.values():
		if button.is_visible_in_tree() and button.get_global_rect().has_point(point):
			return true
	return false

func set_hud_visible(value: bool) -> void :
	_canvas.visible = value
	if not value:
		_reset_blessing()
	if value:
		call_deferred("_layout")

func open_reward(stage: int, final: bool) -> void :
	if _pending_reward >= 0:
		return
	_pending_reward = stage
	_reward = CanvasLayer.new()
	_reward.layer = 135
	_reward.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_reward)
	var dim: = ColorRect.new()
	dim.color = Color(0.015, 0.025, 0.045, 0.95)
	_reward.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center: = CenterContainer.new()
	_reward.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel: = PanelContainer.new()
	var i: = stage - 3
	panel.add_theme_stylebox_override("panel", _style(COLORS[i], true))
	center.add_child(panel)
	var box: = VBoxContainer.new()
	_reward_box = box
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)
	var vp: = get_viewport().get_visible_rect().size
	var scale_ui: = maxf(1, vp.x / 450) if vp.y > vp.x else 1.0
	var width: = minf(vp.x - 40, 560 * scale_ui)
	for text_value in ["神兽已击败 · 新的祝福", TITLES[i], description_for(i), "点击左侧图标直接释放 · 图标显示冷却\n键盘：E 释放当前 · Q 切换"]:
		var label: = Label.new()
		label.text = text_value
		label.custom_minimum_size.x = width - 24
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UiFonts.apply_to_label(label, int((26 if text_value == TITLES[i] else 15) * scale_ui), text_value == TITLES[i])
		box.add_child(label)
		if text_value == TITLES[i]:
			var icon: = TextureRect.new()
			_reward_icon = icon
			icon.texture = load("res://assest/sprites/beasts/skill_%s.svg" % IDS[i])
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.custom_minimum_size = Vector2(100, 100) * scale_ui
			box.add_child(icon)
	reward_claim = Button.new()
	reward_claim.text = "领取 · 进入自由试炼" if final else "领取祝福 · 继续"
	reward_claim.custom_minimum_size.y = 54 * scale_ui
	UiFonts.apply_to_button(reward_claim, int(18 * scale_ui))
	reward_claim.pressed.connect(_claim_reward.bind(stage, false), CONNECT_ONE_SHOT)
	box.add_child(reward_claim)
	if final:
		reward_finish = Button.new()
		reward_finish.text = "领取并通关结算"
		reward_finish.custom_minimum_size.y = 48 * scale_ui
		UiFonts.apply_to_button(reward_finish, int(16 * scale_ui))
		reward_finish.pressed.connect(_claim_reward.bind(stage, true), CONNECT_ONE_SHOT)
		box.add_child(reward_finish)
	_layout_reward()
	get_tree().paused = true
	reward_claim.grab_focus()

func _layout_reward() -> void :
	if _pending_reward < 0 or not is_instance_valid(_reward_box):
		return
	var vp: = get_viewport().get_visible_rect().size
	var scale_ui: = maxf(1, vp.x / 450) if vp.y > vp.x else 1.0
	var width: = minf(vp.x - 40, 560 * scale_ui)
	_reward_box.add_theme_constant_override("separation", int(14 * scale_ui))
	for child in _reward_box.get_children():
		if child is Label:
			child.custom_minimum_size.x = width - 24
			var title: bool = child.text == TITLES[_pending_reward - 3]
			UiFonts.apply_to_label(child, int((26 if title else 15) * scale_ui), title)
		elif child is Button:
			child.custom_minimum_size.y = 50 * scale_ui
			UiFonts.apply_to_button(child, int(17 * scale_ui))
	if is_instance_valid(_reward_icon):
		_reward_icon.custom_minimum_size = Vector2(100, 100) * scale_ui

func _claim_reward(stage: int, settle: bool) -> void :
	if _pending_reward != stage:
		return
	_pending_reward = -1
	unlock(stage - 3)
	_reward.hide()
	_reward.queue_free()
	blessing_claimed.emit(stage, settle)

func _reset_blessing() -> void :
	if is_instance_valid(blessing_fx): blessing_fx.reset()
	if is_instance_valid(_screen_veil):
		_screen_veil.color.a = 0
		_screen_veil.hide()
	AudioManager.stop_beast_power_audio()

func reset_effects() -> void :
	_reset_blessing()
	player.beast_damage_scale = 1.0
	barrier_left = 0
	if is_instance_valid(_reward):
		_reward.hide()
	_canvas.hide()
