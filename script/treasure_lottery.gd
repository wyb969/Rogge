extends CanvasLayer

signal reward_claimed(upgrade_id: String, levels: int)
const SPIN_SECONDS: = 2.9
var reward: Dictionary = {}
var bonus_levels: = 0
var old_level: = 0
var spinning: = false
var revealed: = false
var claimed: = false
var spin_time: = 0.0
var _tick_left: = 0.0
var _pool: Array = []
var _panel: PanelContainer
var _box: VBoxContainer
var _reels: Array[TextureRect] = []
var _reel_panels: Array[PanelContainer] = []
var _title: Label
var _result: Label
var _detail: Label
var _button: Button
var _burst: GoldBurst
var _tick: AudioStreamPlayer
var _fanfare: AudioStreamPlayer

class GoldBurst extends Control:
	var strength: = 0
	var phase: = 0.0
	func _process(delta: float) -> void :
		phase += delta
		queue_redraw()
	func _draw() -> void :
		if strength <= 0:
			return
		var center: = size * 0.5
		var radius: = minf(size.x, size.y) * 0.39
		var count: = 8 + strength * 8
		for i in count:
			var a: = TAU * float(i) / float(count) + phase * 0.12
			var reach: = radius * (0.8 + 0.1 * strength + 0.15 * sin(phase * 1.8 + i))
			var points: = PackedVector2Array([center, center + Vector2.from_angle(a - 0.025) * reach, center + Vector2.from_angle(a + 0.025) * reach])
			draw_colored_polygon(points, Color(1.0, 0.66, 0.12, 0.04 + 0.025 * strength))
		for i in (6 + strength * 10):
			var a: = float(i) * 2.39996 + phase * 0.06
			var p: = center + Vector2.from_angle(a) * radius * (0.48 + float(i % 7) * 0.08)
			var bright: = (0.5 + 0.5 * sin(phase * 3.0 + float(i)))
			var extent: = 1.0 + bright * float(strength + 1)
			var gold: = Color(1.0, 0.86, 0.36, bright * 0.85)
			draw_line(p - Vector2(extent, 0), p + Vector2(extent, 0), gold, 1.2)
			draw_line(p - Vector2(0, extent), p + Vector2(0, extent), gold, 1.2)

static func bonus_for_roll(roll: int) -> int:

	if roll < 5:
		return 1
	return 2 if roll < 85 else 3

func _ready() -> void :
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 130
	visible = false
	_build_ui()
	get_viewport().size_changed.connect(_fit)

func _style(fill: Color, border: Color, width: int = 2) -> StyleBoxFlat:
	var style: = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(12)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	return style

func _label(text_value: String, font_size: int, bold: bool = false) -> Label:
	var label: = Label.new()
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiFonts.apply_to_label(label, font_size, bold)
	_box.add_child(label)
	return label

func _build_ui() -> void :
	var dim: = ColorRect.new()
	dim.color = Color(0.015, 0.02, 0.035, 0.92)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_burst = GoldBurst.new()
	_burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_burst)
	_burst.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center: = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _style(Color(0.045, 0.055, 0.085, 0.97), Color(0.64, 0.43, 0.16)))
	center.add_child(_panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 16)
	_panel.add_child(_box)
	var eyebrow: = _label("战利品  /  TREASURE", 14)
	eyebrow.add_theme_color_override("font_color", Color(0.88, 0.69, 0.35))
	_title = _label("宝藏老虎机", 30, true)
	var row: = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	_box.add_child(row)
	for i in 3:
		var panel: = PanelContainer.new()
		panel.add_theme_stylebox_override("panel", _style(Color(0.018, 0.025, 0.045), Color(0.32, 0.28, 0.2)))
		row.add_child(panel)
		_reel_panels.append(panel)
		var texture: = TextureRect.new()
		texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		panel.add_child(texture)
		_reels.append(texture)
	_result = _label("守卫已击败 · 你的奖励已就绪", 21, true)
	_detail = _label("随机一张卡，直接提升等级\n+2 级 80%  ·  +3 级 15%  ·  +1 级 5%", 15)
	_button = Button.new()
	_button.custom_minimum_size.y = 54
	UiFonts.apply_to_button(_button, 20)
	_button.add_theme_stylebox_override("normal", _style(Color(0.46, 0.29, 0.07), Color(0.96, 0.74, 0.3)))
	_button.pressed.connect(_on_button)
	_box.add_child(_button)
	_tick = AudioStreamPlayer.new()
	get_node("/root/AudioManager").configure_sfx(_tick)
	_tick.stream = preload("res://assest/sounds/treasure_tick.wav")
	_tick.volume_db = -15
	add_child(_tick)
	_fanfare = AudioStreamPlayer.new()
	get_node("/root/AudioManager").configure_sfx(_fanfare)
	_fanfare.stream = preload("res://assest/sounds/treasure_reward.wav")
	_fanfare.volume_db = -9
	add_child(_fanfare)
	_fit()

func _fit() -> void :
	var vp: = get_viewport().get_visible_rect().size
	var portrait: = vp.y > vp.x


	var ui_scale: = maxf(1.0, vp.x / 450.0) if portrait else clampf(vp.y / 600.0, 0.85, 1.15)
	var width: = vp.x * 0.9 if portrait else minf(660.0, vp.x - 32.0)
	_panel.custom_minimum_size.x = width
	for label in [_title, _result, _detail]:
		label.custom_minimum_size.x = width - 40
	UiFonts.apply_to_label(_box.get_child(0), int(14 * ui_scale))
	UiFonts.apply_to_label(_title, int(30 * ui_scale), true)
	UiFonts.apply_to_label(_result, int(21 * ui_scale), true)
	UiFonts.apply_to_label(_detail, int(15 * ui_scale))
	UiFonts.apply_to_button(_button, int(20 * ui_scale))
	_button.custom_minimum_size.y = 54 * ui_scale
	_box.add_theme_constant_override("separation", int((10 if vp.y < 550 else 18) * ui_scale))
	var reel_size: = clampf((width - 68) / 3.0, 62 * ui_scale, 128 * ui_scale)
	for panel in _reel_panels:
		panel.custom_minimum_size = Vector2(reel_size, reel_size)

func open_lottery(pool: Array, equipment: Control) -> void :
	bonus_levels = bonus_for_roll(randi_range(0, 99))
	_pool = pool.filter( func(card: Dictionary): return equipment.get_level(str(card.id)) < int(card.get("max_level", 2147483647)))
	if _pool.is_empty(): return
	var eligible: = _pool.filter( func(card: Dictionary): return equipment.get_level(str(card.id)) + bonus_levels <= int(card.get("max_level", 2147483647)))
	var choices: Array = eligible if not eligible.is_empty() else _pool
	reward = choices[randi() % choices.size()].duplicate(true)
	old_level = equipment.get_level(str(reward.id))
	bonus_levels = mini(bonus_levels, int(reward.get("max_level", 2147483647)) - old_level)
	spinning = false
	revealed = false
	claimed = false
	spin_time = 0.0
	_tick_left = 0.0
	_burst.strength = 0
	_title.text = "宝藏老虎机"
	_result.text = "守卫已击败 · 你的奖励已就绪"
	_detail.text = "随机一张卡，直接提升等级\n+2 级 80%  ·  +3 级 15%  ·  +1 级 5%"
	_result.add_theme_color_override("font_color", Color.WHITE)
	_button.text = "开启抽奖"
	_button.disabled = false
	for i in _reels.size():
		_set_reel(i, _pool[randi() % _pool.size()])
		_reel_panels[i].modulate = Color.WHITE
	visible = true
	get_tree().paused = true
	root_clear_movement()
	_button.grab_focus()

func root_clear_movement() -> void :
	var mobile: = get_node("/root/MobileInput")
	mobile.clear_move()
	mobile.clear_dash()

func _set_reel(i: int, data: Dictionary) -> void :
	_reels[i].texture = load(str(data.icon))
	preload("res://script/visual_style.gd").style_icon(_reels[i], str(data.id))

func _on_button() -> void :
	if claimed or spinning:
		return
	if not revealed:
		spinning = true
		_button.disabled = true
		_button.text = "抽奖中…"
		_result.text = "好运正在转动…"
		return
	claimed = true
	visible = false
	reward_claimed.emit(str(reward.id), bonus_levels)

func _process(delta: float) -> void :
	if not visible or not spinning:
		return
	spin_time += delta
	_tick_left -= delta
	if _tick_left <= 0.0:
		_tick_left = 0.06 + spin_time * 0.045
		_tick.pitch_scale = 0.9 + spin_time * 0.1
		_tick.play()
		for i in _reels.size():
			if spin_time < 1.65 + float(i) * 0.5:
				_set_reel(i, _pool[randi() % _pool.size()])
			else:
				_set_reel(i, reward)
				_reel_panels[i].modulate = Color(1.25, 1.08, 0.65)
	if spin_time >= SPIN_SECONDS:
		_reveal()

func _reveal() -> void :
	spinning = false
	revealed = true
	for i in _reels.size():
		_set_reel(i, reward)
	_burst.strength = bonus_levels
	_title.text = ["", "小小幸运", "幸运大奖", "超级大奖！"][bonus_levels]
	var card_name: = str(reward.title).replace(" +1 级", "")
	_result.text = "%s  +%d 级" % [card_name, bonus_levels]
	_result.add_theme_color_override("font_color", Color(1.0, 0.78, 0.25))
	_detail.text = "Lv.%d  →  Lv.%d\n同一张卡连续升级 %d 次，领取后生效" % [old_level, old_level + bonus_levels, bonus_levels]
	_button.text = "领取奖励 · 继续战斗"
	_button.disabled = false
	_fanfare.pitch_scale = 0.9 + 0.1 * bonus_levels
	_fanfare.play()
	_button.grab_focus()
