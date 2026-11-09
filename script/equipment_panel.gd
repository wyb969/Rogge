extends Control

const SLOT_SIZE: = Vector2(48, 48)
const ICON_SIZE: = Vector2(36, 36)
const UI_FONT_SIZE: = 16
const SLOT_FOOTPRINT := Vector2(64, 60)
const LEVEL_COLOR: = preload("res://script/visual_style.gd").TEXT

@onready var slot_list: GridContainer = $SlotList

var _slots: Dictionary = {}
var _arsenal_label: Label
var _growth_label: Label
const COMBOS := preload("res://script/equipment_combos.gd")
const COMBO_BORDER := preload("res://script/equipment_combo_border.gd")
const ARSENAL_HINT := COMBOS.ARSENAL_HINT
var _active_combo_borders: Array[Control] = []
var _combo_clock := 0.0
var _border_tick_left := 0.0

const EQUIP_DEFS: = {
	"bomb": {"title": "炸弹", "icon": "res://assest/sprites/bomb.svg", "start_level": 0, "max_level": 5},
	"critical_glasses": {"title": "暴击眼镜", "icon": "res://assest/sprites/critical_glasses.svg", "start_level": 0, "max_level": 5},
	"banana_fan": {"title": "芭蕉扇", "icon": "res://assest/sprites/banana_fan.svg", "start_level": 0, "max_level": 5},
	"black_hole": {"title": "黑洞", "icon": "res://assest/sprites/black_hole.svg", "start_level": 0, "max_level": 5},
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
	_arsenal_label = Label.new()
	_arsenal_label.size = Vector2(125, 20)
	UiFonts.apply_to_label(_arsenal_label, 12)
	_arsenal_label.tooltip_text = ARSENAL_HINT
	add_child(_arsenal_label)
	_growth_label = Label.new()
	_growth_label.size = Vector2(125, 20)
	UiFonts.apply_to_label(_growth_label, 12)
	_growth_label.tooltip_text = COMBOS.GROWTH_HINT
	_growth_label.modulate = COMBOS.GROWTH_COLOR
	add_child(_growth_label)
	get_viewport().size_changed.connect(_fit_equipment)
	reset_equipment()

func _fit_equipment() -> void :
	var vp: = get_viewport().get_visible_rect().size
	var count: = _slots.size()
	slot_list.columns = 2 if count > 1 else 1
	var rows: = int(ceil(float(count) / slot_list.columns))
	var status_rows := int(_arsenal_label.visible) + int(_growth_label.visible)
	var icon_height := rows * (SLOT_FOOTPRINT.y + 10.0)
	var height: = icon_height + status_rows * 20.0 + (4.0 if status_rows > 0 else 0.0)
	var budget: = maxf(180, vp.y - 240)
	var factor: = minf(1.0, budget / maxf(height, 1))
	var grid_width := SLOT_FOOTPRINT.x * slot_list.columns + 8.0 * (slot_list.columns - 1)
	var width: = maxf(grid_width, 128.0 if status_rows > 0 else 0.0)
	scale = Vector2.ONE * factor
	global_position = Vector2(vp.x - width * factor - 18, 120)
	slot_list.position.x = width - grid_width
	slot_list.size = Vector2(grid_width, icon_height)
	_arsenal_label.position = Vector2(0, icon_height + 4)
	_growth_label.position = Vector2(0, icon_height + 4 + (20 if _arsenal_label.visible else 0))

func reset_equipment() -> void :
	reset_combo_effects()
	for child in slot_list.get_children():
		child.queue_free()
	_slots.clear()
	set_arsenal_status(0, false, 0.0)
	set_growth_status(0, false)

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
	refresh_combo_borders()

func get_level(upgrade_id: String) -> int:
	if _slots.has(upgrade_id):
		return int(_slots[upgrade_id]["level"])
	return 0

func set_arsenal_status(owned: int, active: bool, seconds: float) -> void:
	if _arsenal_label == null: return
	var was_visible := _arsenal_label.visible
	_arsenal_label.visible = owned > 0
	_arsenal_label.text = ("无敌护盾 %.1fs" % seconds if active else "军械护盾 %.1fs" % seconds) if owned == 3 else "军械组合 %d/3" % owned
	_arsenal_label.modulate = COMBOS.ARSENAL_COLOR.lightened(0.2 if active else 0.0) if owned == 3 else LEVEL_COLOR
	if was_visible != _arsenal_label.visible: _fit_equipment()

func set_growth_status(owned: int, active: bool) -> void:
	if _growth_label == null: return
	var was_visible := _growth_label.visible
	_growth_label.visible = owned > 0
	_growth_label.text = "生机组合 已激活" if active else "生机组合 %d/3" % owned
	if was_visible != _growth_label.visible: _fit_equipment()

func reset_combo_effects() -> void:
	for slot in _slots.values():
		var border: Control = slot.get("combo_border")
		if is_instance_valid(border): border.visible = false
	_active_combo_borders.clear()
	_combo_clock = 0.0
	_border_tick_left = 0.0
	set_process(false)

func refresh_combo_borders() -> void:
	var growth := COMBOS.owned_count(self, COMBOS.GROWTH_MEMBERS) == COMBOS.GROWTH_MEMBERS.size()
	var arsenal := COMBOS.owned_count(self, COMBOS.ARSENAL_MEMBERS) == COMBOS.ARSENAL_MEMBERS.size()
	_active_combo_borders.clear()
	for id in _slots:
		var border: Control = _slots[id].get("combo_border")
		if not is_instance_valid(border): continue
		var group := COMBOS.group_for(id)
		var active := growth if group == "growth" else arsenal
		border.configure(group, COMBOS.color_for(group), active)
		if active: _active_combo_borders.append(border)
	_apply_combo_phases()
	set_process(not _active_combo_borders.is_empty())

func _apply_combo_phases() -> void:
	for border in _active_combo_borders:
		var period := 2.4 if border.combo_group == "growth" else 3.0
		border.set_phase(fposmod(_combo_clock / period, 1.0))

func _process(delta: float) -> void:
	if get_tree().paused or not is_visible_in_tree() or _active_combo_borders.is_empty(): return
	_combo_clock = fposmod(_combo_clock + delta, 12.0)
	_border_tick_left -= delta
	if _border_tick_left <= 0.0:
		_border_tick_left = 1.0 / 30.0
		_apply_combo_phases()

func _add_or_set_level(upgrade_id: String, level: int, juice: bool = false) -> void :
	if level <= 0:
		return
	var def: Dictionary = EQUIP_DEFS[upgrade_id]
	if _slots.has(upgrade_id):
		_slots[upgrade_id]["level"] = level
		var label: Label = _slots[upgrade_id]["level_label"]
		label.text = str(level)
		if juice:
			_play_level_up_juice(upgrade_id)
		return

	var root: = Control.new()
	root.custom_minimum_size = SLOT_FOOTPRINT
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon_wrap: = Panel.new()
	icon_wrap.position = Vector2(6, 6)
	icon_wrap.size = SLOT_SIZE
	icon_wrap.mouse_filter = Control.MOUSE_FILTER_PASS

	var icon: = TextureRect.new()
	icon.custom_minimum_size = ICON_SIZE
	icon.position = Vector2(6, 6)
	icon.size = ICON_SIZE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = load(def["icon"])
	var combo_hint := COMBOS.hint_for(upgrade_id)
	icon_wrap.tooltip_text = str(def.title) + ("\n" + combo_hint if not combo_hint.is_empty() else "")
	preload("res://script/visual_style.gd").style_icon(icon, upgrade_id)
	if def.has("modulate"):
		icon.modulate = def["modulate"]
	icon_wrap.add_child(icon)
	var combo_border: Control
	if not COMBOS.group_for(upgrade_id).is_empty():
		combo_border = COMBO_BORDER.new()
		combo_border.name = "ComboBorder"
		combo_border.visible = false
		icon_wrap.add_child(combo_border)

	var level_label: = Label.new()
	level_label.text = str(level)
	UiFonts.apply_to_label(level_label, UI_FONT_SIZE, true)
	level_label.position = Vector2(32, 32)
	level_label.size = Vector2(18, 20)
	level_label.z_index = 2
	level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	level_label.add_theme_color_override("font_outline_color", GamePalette.INK)
	level_label.add_theme_constant_override("outline_size", 2)
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
		"combo_border": combo_border,
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
		label.modulate = Color.WHITE
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
