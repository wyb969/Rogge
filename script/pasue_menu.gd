extends CanvasLayer

@export var card_scene: PackedScene
@onready var h_box_container: HBoxContainer = $Panel / HBoxContainer

signal upgrade_selected(upgrade_id: String)

const DRAW_COUNT: = 3
const LIGHTNING_RING: = preload("res://script/lightning_ring.gd")
var growth_hint: Label
const VARIETY: = preload("res://script/run_variety.gd")
const POISON: = preload("res://script/poison_trail.gd")
const FAN := preload("res://script/banana_fan.gd")
const VORTEX := preload("res://script/black_hole.gd")
const CRITICAL := preload("res://script/critical_glasses.gd")
const MOLOTOV := preload("res://script/molotov_controller.gd")
const BOMB := preload("res://script/bomb_controller.gd")
const GROWTH_HINT := "生机：拾取+移速+回复\n集齐后经验 +30%\n移速、回复效果 +20%"
const ARSENAL_HINT := "军械：枪支+无人机+炸弹\n每3秒获得1秒无敌护盾"
const MAX_REROLLS: = 3
var rerolls: = 2
var reroll_button: Button
var reroll_hint: Label
var _offered: Array = []
var _draft_rng: = RandomNumberGenerator.new()
var _fit_pending: = false

var upgrade_pool: = [
	{"id": "bomb", "title": "炸弹 +1 级", "desc": "", "icon": "res://assest/sprites/bomb.svg", "max_level": 5},
	{"id": "critical_glasses", "title": "暴击眼镜 +1 级", "desc": "", "icon": "res://assest/sprites/critical_glasses.svg", "max_level": 5},
	{"id": "banana_fan", "title": "芭蕉扇 +1 级", "desc": "", "icon": "res://assest/sprites/banana_fan.svg", "max_level": 5},
	{"id": "black_hole", "title": "黑洞 +1 级", "desc": "", "icon": "res://assest/sprites/black_hole.svg", "max_level": 5},
	{"id": "poison_trail", "title": "剧毒踪迹 +1 级", "desc": "", "icon": "res://assest/sprites/poison_trail.svg", "max_level": 5}, 
	{"id": "wind_emblem", "title": "踏风徽记 +1 级", "desc": "", "icon": "res://assest/sprites/wind_emblem.svg"}, 
	{"id": "echo_ember", "title": "回响火种 +1 级", "desc": "", "icon": "res://assest/sprites/echo_ember.svg"}, 
	{
		"id": "lightning_ring", 
		"title": "闪电戒指 +1 级", 
		"desc": "", 
		"icon": "res://assest/sprites/lightning_ring.svg"
	}, 
	{
		"id": "axe_up", 
		"title": "斧头 +1 级", 
		"desc": "提高斧头攻击力", 
		"icon": "res://assest/sprites/axe.png"
	}, 
	{
		"id": "circle_up", 
		"title": "书本 +1 级", 
		"desc": "增加书本并提高伤害\n最多12本，之后继续强化伤害", 
		"icon": "res://assest/sprites/book.png"
	}, 
	{
		"id": "gun_up", 
		"title": "枪支 +1 级", 
		"desc": "提高枪支属性", 
		"icon": "res://assest/weaponR1.png"
	}, 
	{
		"id": "pickup_up", 
		"title": "拾取 +1 级", 
		"desc": "提高拾取范围", 
		"icon": "res://assest/bullet.png"
	}, 
	{
		"id": "speed_up", 
		"title": "移速 +1 级", 
		"desc": "提高移动速度", 
		"icon": "res://assest/sprites/Speedup.png"
	}, 
	{
		"id": "left_fist", 
		"title": "左拳 +1 级", 
		"desc": "", 
		"icon": "res://assest/sprites/fist_left.svg"
	}, 
	{
		"id": "right_fist", 
		"title": "右拳 +1 级", 
		"desc": "", 
		"icon": "res://assest/sprites/fist_right.svg"
	}, 
	{
		"id": "drone_up", 
		"title": "无人机 +1 级", 
		"desc": "", 
		"icon": "res://assest/sprites/drone.svg"
	}, 
	{
		"id": "molotov_up", 
		"title": "汽油瓶 +1 级", 
		"desc": "", 
		"icon": "res://assest/sprites/molotov.svg"
	}, 
	{
		"id": "freeze_up", 
		"title": "寒冰 +1 级", 
		"desc": "", 
		"icon": "res://assest/sprites/freeze.svg"
	}, 
	{
		"id": "regen_up", 
		"title": "回复 +1 级", 
		"desc": "", 
		"icon": "res://assest/sprites/regen_sprout.svg"
	}, 
	{
		"id": "lifesteal_up", 
		"title": "吸血 +1 级", 
		"desc": "", 
		"icon": "res://assest/sprites/crimson_fang.svg"
	}, 
	{
		"id": "monster_necklace", 
		"title": "怪物项链 +1 级", 
		"desc": "", 
		"icon": "res://assest/sprites/monster_necklace.png"
	}, 
	{
		"id": "shield_up", 
		"title": "玉佩 +1 级", 
		"desc": "", 
		"icon": "res://assest/sprites/jade_guard.svg"
	}
]

func _ready():
	visible = false
	_draft_rng.randomize()
	growth_hint = Label.new()
	growth_hint.name = "GrowthHint"
	growth_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	growth_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	growth_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	growth_hint.add_theme_color_override("font_color", GamePalette.PLAYER_CYAN)
	$Panel.add_child(growth_hint)
	reroll_button = Button.new()
	reroll_button.name = "RerollButton"
	reroll_button.pressed.connect(_on_reroll)
	$Panel.add_child(reroll_button)
	var style: = StyleBoxFlat.new()
	style.bg_color = GamePalette.UI_GREY_DARK
	style.border_color = GamePalette.UI_GREY_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	reroll_button.add_theme_stylebox_override("normal", style)
	var disabled_style: = style.duplicate() as StyleBoxFlat
	disabled_style.bg_color = Color(0.08, 0.09, 0.1)
	disabled_style.border_color = Color(0.25, 0.3, 0.32)
	reroll_button.add_theme_stylebox_override("disabled", disabled_style)
	JuicyHover.bind(reroll_button)
	reroll_hint = Label.new()
	reroll_hint.text = "每局 2 次 · 击败宝囊精可补充"
	reroll_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reroll_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reroll_hint.modulate = GamePalette.UI_GREY_ACTIVE
	$Panel.add_child(reroll_hint)
	_refresh_reroll()
	get_viewport().size_changed.connect(_fit_cards)
	h_box_container.minimum_size_changed.connect(_queue_fit_cards)

func _queue_fit_cards() -> void :
	if _fit_pending: return
	_fit_pending = true
	call_deferred("_fit_cards")


func show_upgrade_options():
	get_tree().paused = true
	visible = true
	var player: = get_tree().get_first_node_in_group("player")
	if player != null:
		growth_hint.text = "人物每升一级：生命上限 +%d，同时补充 %d" % [player.HEALTH_PER_LEVEL, player.HEALTH_PER_LEVEL]
	_display_options([])

func _display_options(excluded: Array) -> void :

	for child in h_box_container.get_children():
		h_box_container.remove_child(child)
		child.free()

	var drawn: = _draw_upgrades(DRAW_COUNT, excluded)
	_offered.clear()
	for data in drawn:
		_offered.append(str(data.id))
		var card = card_scene.instantiate()
		h_box_container.add_child(card)
		card.setup(_build_card_data(data))
		card.selected.connect(on_card_selected)
	_refresh_reroll()
	_fit_cards()

func reset_draft() -> void :
	rerolls = 2
	_offered.clear()
	_refresh_reroll()

func grant_reroll() -> bool:
	if rerolls >= MAX_REROLLS: return false
	rerolls += 1
	_refresh_reroll()
	return true

func _refresh_reroll() -> void :
	if reroll_button == null: return
	reroll_button.text = "换一组 · 剩余 %d 次" % rerolls
	reroll_button.disabled = rerolls <= 0
	reroll_button.tooltip_text = "每局 2 次，击败宝囊精补充；最多储存 3 次"

func _on_reroll() -> void :
	if not visible or not get_tree().paused or rerolls <= 0: return
	rerolls -= 1
	var previous: = _offered.duplicate()
	_display_options(previous)
	AudioManager.play_pickup()
	RunDiagnostics.mark("card_reroll", {"remaining": rerolls})

func _fit_cards() -> void :
	_fit_pending = false
	if h_box_container == null:
		return
	var vp: = get_viewport().get_visible_rect().size
	var count: = h_box_container.get_child_count()
	if count == 0 or vp.x <= 0:
		return
	var ui_scale: = 2.0 if vp.y > vp.x else 1.0
	var gap: = 20.0 * ui_scale
	var width: = minf(180.0 * ui_scale, (vp.x - 32.0 - gap * (count - 1)) / count)
	for card in h_box_container.get_children():
		card.set_display_width(width, ui_scale)


	var row_height: = maxf(250 * ui_scale, h_box_container.get_combined_minimum_size().y)
	var content: = Vector2(width * count + gap * (count - 1), row_height)
	h_box_container.set_anchors_preset(Control.PRESET_TOP_LEFT)
	h_box_container.scale = Vector2.ONE
	h_box_container.add_theme_constant_override("separation", int(gap))
	h_box_container.size = content
	h_box_container.position = Vector2((vp.x - content.x) * 0.5, maxf(64 * ui_scale, (vp.y - content.y - 108 * ui_scale) * 0.5))
	UiFonts.apply_to_label(growth_hint, int(16 * ui_scale), true)
	growth_hint.position = Vector2(16, maxf(12.0, h_box_container.position.y - 50.0 * ui_scale))
	growth_hint.size = Vector2(vp.x - 32, 40 * ui_scale)
	UiFonts.apply_to_button(reroll_button, int(17 * ui_scale))
	reroll_button.position = Vector2((vp.x - 260 * ui_scale) * 0.5, h_box_container.position.y + content.y + 20 * ui_scale)
	reroll_button.size = Vector2(260, 48) * ui_scale
	UiFonts.apply_to_label(reroll_hint, int(12 * ui_scale))
	reroll_hint.position = reroll_button.position + Vector2(-40, 58) * ui_scale
	reroll_hint.size = Vector2(340, 24) * ui_scale
	$Panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _shuffle(pool: Array) -> void :
	for i in range(pool.size() - 1, 0, -1):
		var other: = _draft_rng.randi_range(0, i)
		var value = pool[i]
		pool[i] = pool[other]
		pool[other] = value

func _draw_upgrades(count: int, excluded: Array = []) -> Array:
	var eligible: = available_upgrades()
	var pool: Array = []
	var fallback: Array = []
	for entry in eligible:
		if str(entry.id) in excluded: fallback.append(entry)
		else: pool.append(entry)
	_shuffle(pool)
	_shuffle(fallback)

	while pool.size() < mini(count, eligible.size()) and not fallback.is_empty(): pool.append(fallback.pop_back())
	var result: Array = []
	var game: = _get_game()
	if game != null and count >= 2:

		for owned in [true, false]:
			for i in pool.size():
				if (game.equipment_panel.get_level(str(pool[i].id)) > 0) == owned:
					result.append(pool[i])
					pool.remove_at(i)
					break
	while result.size() < count and not pool.is_empty(): result.append(pool.pop_back())
	_shuffle(result)
	return result

func available_upgrades() -> Array:
	var game: = _get_game()
	var result: Array = []
	for entry in upgrade_pool:
		if game == null or game.equipment_panel.get_level(str(entry.id)) < int(entry.get("max_level", 2147483647)): result.append(entry)
	return result


func _build_card_data(data: Dictionary) -> Dictionary:
	var card_data: = data.duplicate(true)
	match str(card_data.get("id", "")):
		"bomb":
			var game := _get_game()
			var rank: int = mini(BOMB.MAX_LEVEL, 1 + (game.bomb_controller.level if game != null else 0))
			var stats := BOMB.stats_for(rank)
			card_data["desc"] = "自动投弹 · 爆炸击飞\n伤害 %.0f · 半径 %.0f\n间隔 %.2fs · 最高5级\n%s" % [stats.damage, stats.radius, stats.interval, ARSENAL_HINT]
		"gun_up":
			card_data["desc"] = "强化枪支伤害与射速\n" + ARSENAL_HINT
		"pickup_up":
			card_data["desc"] = "拾取范围提高20%\n" + GROWTH_HINT
		"speed_up":
			card_data["desc"] = "基础移动速度 +20\n" + GROWTH_HINT
		"critical_glasses":
			var game := _get_game()
			var rank: int = mini(CRITICAL.MAX_LEVEL, 1 + (game.player.critical_glasses_level if game != null else 0))
			card_data["desc"] = "直接攻击暴击率 %d%%\n暴击造成 %d%% 伤害\n每级 +20%% · 最高5级\n满级：暴击伤害200%%\n持续伤害不触发暴击" % [roundi(CRITICAL.chance_for(rank) * 100.0), roundi(CRITICAL.damage_multiplier_for(rank) * 100.0)]
		"banana_fan":
			var game := _get_game()
			var rank: int = mini(5, 1 + (game.banana_fan.level if game != null else 0))
			var stats := FAN.stats_for(rank)
			card_data["desc"] = "沿移动方向吹出气流\n伤害 %.0f · 距离 %.0f\n间隔 %.2f 秒 · 击退敌人\n已有灼烧/中毒额外一跳\n最高5级 · 追加不传播" % [stats.damage, stats.range, stats.interval]
		"black_hole":
			var game := _get_game()
			var rank: int = mini(5, 1 + (game.black_hole.level if game != null else 0))
			var stats := VORTEX.stats_for(rank)
			card_data["desc"] = "自动召唤黑洞聚怪\n每秒伤害 %.0f · 半径 %.0f\n间隔 %.1f 秒 · 持续3秒\n升级增伤、扩围、减冷却\n最高 5 级" % [stats.dps, stats.radius, stats.interval]
		"poison_trail":
			var game: = _get_game()
			var rank: int = mini(5, 1 + (game.poison_trail.level if game != null else 0))
			var stats: = POISON.stats_for(rank)
			card_data["desc"] = "移动留下 4 秒毒雾\n每秒伤害 %.0f · 范围 %.0f\n%s\n最高 5 级，重叠不叠伤" % [stats.dps, stats.radius, "5 级：移速降低 25%" if rank == 5 else "5 级解锁移速减速 25%"]
		"left_fist":
			card_data["desc"] = _fist_desc(true)
		"right_fist":
			card_data["desc"] = _fist_desc(false)
		"drone_up":
			card_data["desc"] = _drone_desc() + "\n" + ARSENAL_HINT
		"molotov_up":
			card_data["desc"] = _molotov_desc()
		"freeze_up":
			card_data["desc"] = _freeze_desc()
		"regen_up":
			card_data["desc"] = _regen_desc() + "\n" + GROWTH_HINT
		"lifesteal_up":
			card_data["desc"] = _lifesteal_desc()
		"shield_up":
			card_data["desc"] = _shield_desc()
		"monster_necklace":
			card_data["desc"] = _monster_necklace_desc()
		"lightning_ring":
			card_data["desc"] = _lightning_ring_desc()
		"wind_emblem", "echo_ember":
			var game: = _get_game()
			var rank: int = 1 + (game.equipment_panel.get_level(str(card_data.id)) if game != null else 0)
			var stats: = VARIETY.wind_stats(rank) if card_data.id == "wind_emblem" else VARIETY.echo_stats(rank)
			card_data["desc"] = ("冲刺结束释放风压\n伤害 %.0f · 范围 %.0f\n利用无敌窗口切入" % [stats.damage, stats.radius]) if card_data.id == "wind_emblem" else ("每击杀 %d 个敌人\n在最后击杀处引爆回响\n伤害 %.0f · 范围 %.0f" % [stats.kills, stats.damage, stats.radius])
	return card_data


func _get_game() -> Node:
	return get_tree().get_first_node_in_group("game")


func _fist_desc(is_left: bool) -> String:
	var player: = get_tree().get_first_node_in_group("player")
	var current_level: = 0
	if player != null:
		current_level = player.left_fist_level if is_left else player.right_fist_level

	var next_level: = current_level + 1
	var bonus_pct: = 20
	var penalty_pct: = 12
	if player != null and player.has_method("get_fist_bonus"):
		bonus_pct = int(round(player.get_fist_bonus(next_level) * 100.0))
		penalty_pct = int(round(player.get_fist_penalty(next_level) * 100.0))

	if is_left:
		return "左侧伤害 +%d%%\n右侧伤害 -%d%%\n双持取消减伤" % [bonus_pct, penalty_pct]
	return "右侧伤害 +%d%%\n左侧伤害 -%d%%\n双持取消减伤" % [bonus_pct, penalty_pct]


func _drone_desc() -> String:
	var game: = _get_game()
	var lv: = 0
	if game and game.get("drone_controller"):
		lv = int(game.drone_controller.level)
	var next: = lv + 1
	var life: = 6.0 + float(next) * 1.6
	var cd: = maxf(0.22, 0.9 - float(next) * 0.09)
	var dmg: = 6.0 + float(next) * 4.5
	var count: = 1 + int((next - 1) / 3)
	return "召唤 %d 架伴飞无人机\n激光照射 间隔 %.2fs\n存活 %.1fs 伤害 %.0f" % [count, cd, life, dmg]


func _molotov_desc() -> String:
	var game: = _get_game()
	var lv: = 0
	if game and game.get("molotov_controller"):
		lv = int(game.molotov_controller.level)
	var next: = lv + 1
	var interval: float = MOLOTOV.interval_for(next)
	var stacks: = 2 + int((next - 1) / 2)
	var dps: = 2.5 + float(next) * 1.8
	var chance: = mini(0.18 + float(next) * 0.07, 0.65) * 100.0
	return "投掷汽油瓶\n间隔 %.2fs 燃烧%d层\n击中附燃 %.0f%% DPS%.0f" % [interval, stacks, chance, dps]


func _regen_desc() -> String:
	var player: = get_tree().get_first_node_in_group("player")
	var next_level: = 1
	if player != null:
		next_level = int(player.regen_level) + 1
	if player != null and player.has_method("regen_amount_for"):
		var amount: float = player.effective_heal_amount(player.regen_amount_for(next_level))
		var interval: float = player.regen_interval_for(next_level)
		return "每 %.1f 秒 +%s" % [interval, _heal_number(amount)]
	return "每 3.0 秒 +1"

func _lifesteal_desc() -> String:
	var player: = get_tree().get_first_node_in_group("player")
	var next_level: = 1
	if player != null:
		next_level = int(player.lifesteal_level) + 1
	if player != null and player.has_method("lifesteal_cap_for"):
		var multiplier: float = player.total_healing_multiplier()
		var percent: float = player.lifesteal_percent_for(next_level) * 100.0 * multiplier
		var cap: float = player.effective_heal_amount(player.lifesteal_cap_for(next_level))
		return "命中回复少量\n约 %s%% +%s  上限 %s" % [_heal_number(percent), _heal_number(multiplier), _heal_number(cap)]
	return "命中回复少量\n约 3% +1  上限 2"

func _shield_desc() -> String:
	var player: = get_tree().get_first_node_in_group("player")
	var next_level: = 1
	if player != null:
		next_level = int(player.shield_level) + 1
	if player != null and player.has_method("shield_gain_for"):
		var gain: = int(player.shield_gain_for(next_level))
		var decay: float = player.shield_decay_for(next_level)
		return "击杀护盾 +%d\n停手后每秒 -%.1f" % [gain, decay]
	return "击杀护盾 +2\n停手后每秒 -4.0"

func _freeze_desc() -> String:
	var game: = _get_game()
	var lv: = 0
	if game and game.get("freeze_controller"):
		lv = int(game.freeze_controller.level)
	var next: = lv + 1
	var chance: = mini(0.16 + float(next) * 0.07, 0.6) * 100.0
	var dur: = 1.0 + float(next) * 0.25
	var slow: = maxf(0.28, 0.6 - float(next) * 0.05) * 100.0
	var bonus: = mini(0.2 + float(next) * 0.1, 0.9) * 100.0
	return "击中冰冻 %.0f%%\n持续 %.1fs 移速%.0f%%\n冻伤额外 +%.0f%%" % [chance, dur, slow, bonus]


func on_card_selected(upgrade_id: String):
	if not visible: return
	visible = false
	upgrade_selected.emit(upgrade_id)
	get_tree().paused = false


func _on_button_pressed():
	get_tree().paused = false
	visible = false

func _monster_necklace_desc() -> String:
	var player: = get_tree().get_first_node_in_group("player")
	var next_level: = 1
	if player != null:
		next_level = int(player.monster_necklace_level) + 1
	var multiplier: float = player.total_healing_multiplier() if player != null else 1.0
	return "击杀掉落回血球\n拾取回复 +%s 生命\n每级增加 %s 点" % [_heal_number(next_level * 5 * multiplier), _heal_number(5 * multiplier)]

func _heal_number(amount: float) -> String:
	return ("%.1f" % amount).trim_suffix(".0")

func _lightning_ring_desc() -> String:
	var game: = _get_game()
	var next_level: = 1
	if game and game.get("lightning_ring"):
		next_level = game.lightning_ring.level + 1
	var stats: = LIGHTNING_RING.stats_for(next_level)
	return "每 %.0f 秒自动落雷\n最多 %d 个不同目标\n单道伤害 %.0f · 范围 %.0f" % [stats.interval, stats.bolts, stats.damage, stats.range]
