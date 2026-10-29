extends CanvasLayer

@export var card_scene: PackedScene
@onready var h_box_container: HBoxContainer = $Panel/HBoxContainer

signal upgrade_selected(upgrade_id: String)

const DRAW_COUNT := 3

var upgrade_pool := [
	{
		"id": "axe_up",
		"title": "斧头 +1 级",
		"desc": "提高斧头攻击力",
		"icon": "res://assest/sprites/axe.png"
	},
	{
		"id": "circle_up",
		"title": "书本 +1 级",
		"desc": "提高书本旋转速度",
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
		"icon": "res://assest/sprites/fruit.png"
	},
	{
		"id": "lifesteal_up",
		"title": "吸血 +1 级",
		"desc": "",
		"icon": "res://assest/sprites/fruit.png"
	},
	{
		"id": "shield_up",
		"title": "玉佩 +1 级",
		"desc": "",
		"icon": "res://assest/sprites/fruit.png"
	}
]

func _ready():
	visible = false


func show_upgrade_options():
	get_tree().paused = true
	visible = true
	# Free immediately so previous cards cannot stack with the new draw.
	for child in h_box_container.get_children():
		h_box_container.remove_child(child)
		child.free()

	var drawn := _draw_upgrades(DRAW_COUNT)
	for data in drawn:
		var card = card_scene.instantiate()
		h_box_container.add_child(card)
		card.setup(_build_card_data(data))
		card.selected.connect(on_card_selected)


func _draw_upgrades(count: int) -> Array:
	var pool: Array = upgrade_pool.duplicate()
	pool.shuffle()
	return pool.slice(0, mini(count, pool.size()))


func _build_card_data(data: Dictionary) -> Dictionary:
	var card_data := data.duplicate(true)
	match str(card_data.get("id", "")):
		"left_fist":
			card_data["desc"] = _fist_desc(true)
		"right_fist":
			card_data["desc"] = _fist_desc(false)
		"drone_up":
			card_data["desc"] = _drone_desc()
		"molotov_up":
			card_data["desc"] = _molotov_desc()
		"freeze_up":
			card_data["desc"] = _freeze_desc()
		"regen_up":
			card_data["desc"] = _regen_desc()
		"lifesteal_up":
			card_data["desc"] = _lifesteal_desc()
		"shield_up":
			card_data["desc"] = _shield_desc()
	return card_data


func _get_game() -> Node:
	return get_tree().get_first_node_in_group("game")


func _fist_desc(is_left: bool) -> String:
	var player := get_tree().get_first_node_in_group("player")
	var current_level := 0
	if player != null:
		current_level = player.left_fist_level if is_left else player.right_fist_level

	var next_level := current_level + 1
	var bonus_pct := 20
	var penalty_pct := 12
	if player != null and player.has_method("get_fist_bonus"):
		bonus_pct = int(round(player.get_fist_bonus(next_level) * 100.0))
		penalty_pct = int(round(player.get_fist_penalty(next_level) * 100.0))

	if is_left:
		return "左侧伤害 +%d%%\n右侧伤害 -%d%%\n双持取消减伤" % [bonus_pct, penalty_pct]
	return "右侧伤害 +%d%%\n左侧伤害 -%d%%\n双持取消减伤" % [bonus_pct, penalty_pct]


func _drone_desc() -> String:
	var game := _get_game()
	var lv := 0
	if game and game.get("drone_controller"):
		lv = int(game.drone_controller.level)
	var next := lv + 1
	var life := 6.0 + float(next) * 1.6
	var cd := maxf(0.22, 0.9 - float(next) * 0.09)
	var dmg := 6.0 + float(next) * 4.5
	var count := 1 + int((next - 1) / 3)
	return "召唤 %d 架伴飞无人机\n激光照射 间隔 %.2fs\n存活 %.1fs 伤害 %.0f" % [count, cd, life, dmg]


func _molotov_desc() -> String:
	var game := _get_game()
	var lv := 0
	if game and game.get("molotov_controller"):
		lv = int(game.molotov_controller.level)
	var next := lv + 1
	var interval := maxf(1.6, 4.2 - float(next) * 0.35)
	var stacks := 2 + int((next - 1) / 2)
	var dps := 2.5 + float(next) * 1.8
	var chance := mini(0.18 + float(next) * 0.07, 0.65) * 100.0
	return "投掷汽油瓶\n间隔 %.1fs 燃烧%d层\n击中附燃 %.0f%% DPS%.0f" % [interval, stacks, chance, dps]


func _regen_desc() -> String:
	var player := get_tree().get_first_node_in_group("player")
	var next_level := 1
	if player != null:
		next_level = int(player.regen_level) + 1
	if player != null and player.has_method("regen_amount_for"):
		var amount := int(player.regen_amount_for(next_level))
		var interval: float = player.regen_interval_for(next_level)
		return "每 %.1f 秒 +%d" % [interval, amount]
	return "每 3.0 秒 +1"

func _lifesteal_desc() -> String:
	var player := get_tree().get_first_node_in_group("player")
	var next_level := 1
	if player != null:
		next_level = int(player.lifesteal_level) + 1
	if player != null and player.has_method("lifesteal_cap_for"):
		var percent := int(round(player.lifesteal_percent_for(next_level) * 100.0))
		var cap := int(player.lifesteal_cap_for(next_level))
		return "命中回复少量\n约 %d%% +1  上限 %d" % [percent, cap]
	return "命中回复少量\n约 3% +1  上限 2"

func _shield_desc() -> String:
	var player := get_tree().get_first_node_in_group("player")
	var next_level := 1
	if player != null:
		next_level = int(player.shield_level) + 1
	if player != null and player.has_method("shield_gain_for"):
		var gain := int(player.shield_gain_for(next_level))
		var decay: float = player.shield_decay_for(next_level)
		return "击杀护盾 +%d\n停手后每秒 -%.1f" % [gain, decay]
	return "击杀护盾 +2\n停手后每秒 -4.0"

func _freeze_desc() -> String:
	var game := _get_game()
	var lv := 0
	if game and game.get("freeze_controller"):
		lv = int(game.freeze_controller.level)
	var next := lv + 1
	var chance := mini(0.16 + float(next) * 0.07, 0.6) * 100.0
	var dur := 1.0 + float(next) * 0.25
	var slow := maxf(0.28, 0.6 - float(next) * 0.05) * 100.0
	var bonus := mini(0.2 + float(next) * 0.1, 0.9) * 100.0
	return "击中冰冻 %.0f%%\n持续 %.1fs 移速%.0f%%\n冻伤额外 +%.0f%%" % [chance, dur, slow, bonus]


func on_card_selected(upgrade_id: String):
	upgrade_selected.emit(upgrade_id)
	visible = false
	get_tree().paused = false


func _on_button_pressed():
	get_tree().paused = false
	visible = false
