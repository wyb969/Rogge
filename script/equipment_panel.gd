extends Control

const SLOT_SIZE: = Vector2(48, 48)
const ICON_SIZE: = Vector2(36, 36)
const UI_FONT_SIZE: = 15
const LEVEL_COLOR: = preload("res://script/visual_style.gd").TEXT

@onready var slot_list: GridContainer = $SlotList

var _slots: Dictionary = {}

const EQUIP_DEFS: = {
	"poison_trail": {"title": "剧毒踪迹", "icon": "res://assest/sprites/poison_trail.svg", "start_level": 0, "max_level": 5}, 
	"wind_emblem": {"title": "踏风徽记", "icon": "res://assest/sprites/wind_emblem.svg", "start_level": 0}, 
	"echo_ember": {"title": "回响火种", "icon": "res://assest/sprites/echo_ember.svg", "start_level": 0}, 
	"lightning_ring": {
		"title": "闪电戒指", 
		"icon": "res://assest/sprites/lightning_ring.svg", 
		"start_level": 0
	}, 
	"monster_necklace": {
		"title": "怪物项链", 
		"icon": "res://assest/sprites/monster_necklace.png", 
		"start_level": 0
	}, 
	"axe_up": {
		"title": "斧头", 
		"icon": "res://assest/sprites/axe.png", 
		"start_level": 1
	}, 
	"circle_up": {
		"title": "书本", 
		"icon": "res://assest/sprites/book.png", 
		"start_level": 1
	}, 
	"gun_up": {
		"title": "枪支", 
		"icon": "res://assest/weaponR1.png", 
		"start_level": 0
	}, 
	"pickup_up": {
		"title": "拾取", 
		"icon": "res://assest/bullet.png", 
		"start_level": 0
	}, 
	"speed_up": {
		"title": "移速", 
		"icon": "res://assest/sprites/Speedup.png", 
		"start_level": 0
	}, 
	"left_fist": {
		"title": "左拳", 
		"icon": "res://assest/sprites/fist_left.svg", 
		"start_level": 0
	}, 
	"right_fist": {
		"title": "右拳", 
		"icon": "res://assest/sprites/fist_right.svg", 
		"start_level": 0
	}, 
	"drone_up": {
		"title": "无人机", 
		"icon": "res://assest/sprites/drone.svg", 
		"start_level": 0
	}, 
	"molotov_up": {
		"title": "汽油瓶", 
		"icon": "res://assest/sprites/molotov.svg", 
		"start_level": 0
	}, 
	"freeze_up": {
		"title": "寒冰", 
		"icon": "res://assest/sprites/freeze.svg", 
		"start_level": 0
	}, 
	"regen_up": {
		"title": "回复", 
		"icon": "res://assest/sprites/regen_sprout.svg", 
		"start_level": 0
	}, 
	"lifesteal_up": {
		"title": "吸血", 
		"icon": "res://assest/sprites/crimson_fang.svg", 
		"start_level": 0
	}, 
	"shield_up": {
		"title": "玉佩", 
		"icon": "res://assest/sprites/jade_guard.svg", 
		"start_level": 0
	}
}

func _ready() -> void :
	get_viewport().size_changed.connect(_fit_equipment)
	reset_equipment()

func _fit_equipment() -> void :
	var vp: = get_viewport().get_visible_rect().size
	var count: = _slots.size()
	slot_list.columns = 2 if count > 6 else 1
	var rows: = int(ceil(float(count) / slot_list.columns))
	var height: = rows * 58.0
	var budget: = maxf(180, vp.y - 240)
	var factor: = minf(1, budget / maxf(height, 1))
	var width: = 128.0 * slot_list.columns
	scale = Vector2.ONE * factor
	global_position = Vector2(vp.x - width * factor - 18, 120)
	slot_list.size = Vector2(width, height)

func reset_equipment() -> void :
	for child in slot_list.get_children():
		child.queue_free()
	_slots.clear()

	for id in ["axe_up", "circle_up"]:
		_add_or_set_level(id, EQUIP_DEFS[id]["start_level"], false)

func apply_upgrade(upgrade_id: String) -> void :
	if not EQUIP_DEFS.has(upgrade_id):
		return
	if get_level(upgrade_id) >= int(EQUIP_DEFS[upgrade_id].get("max_level", 2147483647)): return
	if _slots.has(upgrade_id):
		_add_or_set_level(upgrade_id, int(_slots[upgrade_id]["level"]) + 1, true)
	else:
		_add_or_set_level(upgrade_id, 1, true)

func get_level(upgrade_id: String) -> int:
	if _slots.has(upgrade_id):
		return int(_slots[upgrade_id]["level"])
	return 0

func _add_or_set_level(upgrade_id: String, level: int, juice: bool = false) -> void :
	if level <= 0:
		return
	var def: Dictionary = EQUIP_DEFS[upgrade_id]
	if _slots.has(upgrade_id):
		_slots[upgrade_id]["level"] = level
		var label: Label = _slots[upgrade_id]["level_label"]
		label.text = "Lv.%d" % level
		if juice:
			_play_level_up_juice(upgrade_id)
		return

	var root: = HBoxContainer.new()
	root.custom_minimum_size = Vector2(120, SLOT_SIZE.y)
	root.add_theme_constant_override("separation", 8)

	var icon_wrap: = PanelContainer.new()
	icon_wrap.custom_minimum_size = SLOT_SIZE

	var icon: = TextureRect.new()
	icon.custom_minimum_size = ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = load(def["icon"])
	preload("res://script/visual_style.gd").style_icon(icon, upgrade_id)
	if def.has("modulate"):
		icon.modulate = def["modulate"]
	icon_wrap.add_child(icon)

	var level_label: = Label.new()
	level_label.text = "Lv.%d" % level
	UiFonts.apply_to_label(level_label, UI_FONT_SIZE)
	level_label.add_theme_color_override("font_color", LEVEL_COLOR)
	level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	root.add_child(icon_wrap)
	root.add_child(level_label)
	slot_list.add_child(root)

	_slots[upgrade_id] = {
		"root": root, 
		"icon": icon, 
		"icon_wrap": icon_wrap, 
		"level_label": level_label, 
		"level": level, 
		"juice_tween": null
	}
	_fit_equipment()

	if juice:
		_play_new_slot_juice(upgrade_id)

func _kill_slot_tween(upgrade_id: String) -> void :
	if not _slots.has(upgrade_id):
		return
	var tw: Tween = _slots[upgrade_id].get("juice_tween")
	if tw != null and tw.is_valid():
		tw.kill()
	_slots[upgrade_id]["juice_tween"] = null

func _prepare_control_pivot(node: Control) -> void :
	node.pivot_offset = node.size * 0.5

func _play_level_up_juice(upgrade_id: String) -> void :
	if not _slots.has(upgrade_id):
		return
	_kill_slot_tween(upgrade_id)

	var label: Label = _slots[upgrade_id]["level_label"]
	var icon_wrap: Control = _slots[upgrade_id]["icon_wrap"]

	label.rotation = 0.0
	label.scale = Vector2.ONE
	label.modulate = Color.WHITE
	icon_wrap.scale = Vector2.ONE

	_prepare_control_pivot(label)
	_prepare_control_pivot(icon_wrap)

	var tween: = create_tween()
	_slots[upgrade_id]["juice_tween"] = tween


	tween.tween_property(label, "rotation", 0.22, 0.04)
	tween.tween_property(label, "rotation", -0.22, 0.04)
	tween.tween_property(label, "rotation", 0.14, 0.035)
	tween.tween_property(label, "rotation", -0.1, 0.035)
	tween.tween_property(label, "rotation", 0.0, 0.04)


	tween.tween_callback( func():
		label.modulate = Color(1.0, 1.0, 0.86)
		icon_wrap.scale = Vector2(1.08, 1.08)
	)
	tween.set_parallel(true)
	tween.tween_property(label, "scale", Vector2(1.55, 1.55), 0.1)\
	.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(icon_wrap, "scale", Vector2(1.2, 1.2), 0.1)\
	.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	tween.set_parallel(true)
	tween.tween_property(label, "scale", Vector2.ONE, 0.22)\
	.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(icon_wrap, "scale", Vector2.ONE, 0.22)\
	.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate", Color.WHITE, 0.22)

func _play_new_slot_juice(upgrade_id: String) -> void :
	if not _slots.has(upgrade_id):
		return
	_kill_slot_tween(upgrade_id)

	var icon_wrap: Control = _slots[upgrade_id]["icon_wrap"]
	var label: Label = _slots[upgrade_id]["level_label"]

	icon_wrap.scale = Vector2(0.15, 0.15)
	icon_wrap.modulate.a = 0.0
	icon_wrap.rotation = -0.35
	label.scale = Vector2(0.15, 0.15)
	label.modulate = Color(LEVEL_COLOR.r, LEVEL_COLOR.g, LEVEL_COLOR.b, 0.0)
	label.rotation = 0.25


	await get_tree().process_frame
	if not _slots.has(upgrade_id):
		return

	_prepare_control_pivot(icon_wrap)
	_prepare_control_pivot(label)

	var tween: = create_tween()
	_slots[upgrade_id]["juice_tween"] = tween
	tween.set_parallel(true)
	tween.tween_property(icon_wrap, "modulate:a", 1.0, 0.12)
	tween.tween_property(label, "modulate:a", 1.0, 0.12)
	tween.tween_property(icon_wrap, "rotation", 0.0, 0.16)\
	.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "rotation", 0.0, 0.16)\
	.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(icon_wrap, "scale", Vector2(1.28, 1.28), 0.14)\
	.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2(1.4, 1.4), 0.14)\
	.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	tween.set_parallel(true)
	tween.tween_property(icon_wrap, "scale", Vector2.ONE, 0.24)\
	.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2.ONE, 0.24)\
	.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate", Color.WHITE, 0.2)
