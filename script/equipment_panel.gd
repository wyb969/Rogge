extends Control

const QUALITY := preload("res://script/card_quality_style.gd")
const QUALITY_FOOTPRINT := Vector2(114, 32)
const RANK_FONT_SIZE := 26
const RANK_LEFT := 32.0
const SLOT_SIZE: = Vector2(48, 48)
const ICON_SIZE: = Vector2(36, 36)
const UI_FONT_SIZE: = 16
const SLOT_FOOTPRINT := Vector2(64, 60)
const LEVEL_COLOR: = preload("res://script/visual_style.gd").TEXT

@onready var slot_list: GridContainer = $SlotList

var _slots: Dictionary = {}
var dragon_active := false
var pocket_active := false
var dimension_active := false
var crimson_active := false
var _arsenal_label: Label
var _growth_label: Label
const COMBOS := preload("res://script/equipment_combos.gd")
const COMBO_BORDER := preload("res://script/equipment_combo_border.gd")
const ARSENAL_HINT := COMBOS.ARSENAL_HINT
var _active_combo_borders: Array[Control] = []
var _combo_clock := 0.0
var _border_tick_left := 0.0

const EQUIP_DEFS: = {
	"light_thorn": {"title": "光之荆棘", "icon": "res://rogge_art/icons/skills-equipment/light-thorn.png", "start_level": 0, "max_level": 5},
	"ice_wave": {"title": "冰刃波", "icon": "res://rogge_art/icons/skills-equipment/ice-wave.png", "start_level": 0, "max_level": 5},
	"ghost_dash": {"title": "鬼影步", "icon": "res://rogge_art/combat-fx/ghost-dash/icon.png", "start_level": 0, "max_level": 5},
	"solar_flare": {"title":"太阳拳", "icon":"res://rogge_art/combat-fx/toon/solar_flare.png", "start_level":0, "max_level":5},
	"kienzan": {"title":"气圆斩", "icon":"res://rogge_art/combat-fx/toon/kienzan.png", "start_level":0, "max_level":5},
	"kamehameha": {"title":"龟派气功", "icon":"res://rogge_art/combat-fx/toon/kamehameha.png", "start_level":0, "max_level":5},
	"small_light": {"title":"缩小灯", "icon":"res://rogge_art/combat-fx/toon/small_light.png", "start_level":0, "max_level":5},
	"air_cannon": {"title":"空气炮", "icon":"res://rogge_art/combat-fx/toon/air_cannon.png", "start_level":0, "max_level":5},
	"big_light": {"title":"放大灯", "icon":"res://rogge_art/combat-fx/toon/big_light.png", "start_level":0, "max_level":5},
	"portal_gun": {"title": "传送枪", "icon": "res://rogge_art/combat-fx/dimension/portal_gun.png", "start_level": 0, "max_level": 5},
	"errand_box": {"title": "Meeseeks 盒子", "icon": "res://rogge_art/combat-fx/dimension/errand_box.png", "start_level": 0, "max_level": 5},
	"micro_cell": {"title": "微宇宙电池", "icon": "res://rogge_art/combat-fx/dimension/micro_cell.png", "start_level": 0, "max_level": 5},
	"blood_vortex": {"title": "嗜魂封魔斩", "icon": "res://rogge_art/combat-fx/blood-vortex/icon.png", "start_level": 0, "max_level": 5},
	"draw_slash": {"title": "拔刀斩", "icon": "res://rogge_art/combat-fx/draw-slash/icon.png", "start_level": 0, "max_level": 5},
	"thorn_whip": {"title": "荆棘鞭", "icon": "res://rogge_art/icons/skills-equipment/A026.png", "start_level": 0, "max_level": 5},
	"rune_bolt": {"title": "符文飞弹", "icon": "res://rogge_art/icons/skills-equipment/A027.png", "start_level": 0, "max_level": 5},
	"pulse_aura": {"title": "脉冲法阵", "icon": "res://rogge_art/icons/skills-equipment/A028.png", "start_level": 0, "max_level": 5},
	"silver_knife": {"title": "银翼飞刀", "icon": "res://rogge_art/icons/skills-equipment/A029.png", "start_level": 0, "max_level": 5},
	"cross_blade": {"title": "回旋十字刃", "icon": "res://rogge_art/icons/skills-equipment/A030.png", "start_level": 0, "max_level": 5},
	"holy_water": {"title": "净化圣水", "icon": "res://rogge_art/icons/skills-equipment/A031.png", "start_level": 0, "max_level": 5},
	"bomb": {"title": "炸弹", "icon": "res://rogge_art/icons/skills-equipment/A032.png", "start_level": 0, "max_level": 5},
	"critical_glasses": {"title": "暴击眼镜", "icon": "res://rogge_art/icons/skills-equipment/A033.png", "start_level": 0, "max_level": 5},
	"banana_fan": {"title": "芭蕉扇", "icon": "res://rogge_art/icons/skills-equipment/A034.png", "start_level": 0, "max_level": 5},
	"black_hole": {"title": "黑洞", "icon": "res://rogge_art/icons/skills-equipment/A035.png", "start_level": 0, "max_level": 5},
	"poison_trail": {"title": "剧毒踪迹", "icon": "res://rogge_art/icons/skills-equipment/A036.png", "start_level": 0, "max_level": 5}, 
	"wind_emblem": {"title": "踏风徽记", "icon": "res://rogge_art/icons/skills-equipment/A037.png", "start_level": 0}, 
	"echo_ember": {"title": "回响火种", "icon": "res://rogge_art/icons/skills-equipment/A038.png", "start_level": 0}, 
	"lightning_ring": {
		"title": "闪电戒指", 
		"icon": "res://rogge_art/icons/skills-equipment/A039.png", 
		"start_level": 0
	}, 
	"monster_necklace": {
		"title": "怪物项链", 
		"icon": "res://rogge_art/icons/skills-equipment/A040.png", 
		"start_level": 0
	}, 
	"axe_up": {
		"title": "斧头", 
		"icon": "res://rogge_art/icons/skills-equipment/A041.png", 
		"start_level": 1
	}, 
	"circle_up": {
		"title": "书本", 
		"icon": "res://rogge_art/icons/skills-equipment/A042.png", 
		"start_level": 1
	}, 
	"gun_up": {
		"title": "枪支", 
		"icon": "res://rogge_art/icons/skills-equipment/A043.png", 
		"start_level": 0
	}, 
	"pickup_up": {
		"title": "拾取", 
		"icon": "res://rogge_art/icons/skills-equipment/A044.png", 
		"start_level": 0
	}, 
	"speed_up": {
		"title": "移速", 
		"icon": "res://rogge_art/icons/skills-equipment/A045.png", 
		"start_level": 0
	}, 
	"left_fist": {
		"title": "左拳", 
		"icon": "res://rogge_art/icons/skills-equipment/A046.png", 
		"start_level": 0
	}, 
	"right_fist": {
		"title": "右拳", 
		"icon": "res://rogge_art/icons/skills-equipment/A047.png", 
		"start_level": 0
	}, 
	"drone_up": {
		"title": "无人机", 
		"icon": "res://rogge_art/icons/skills-equipment/A048.png", 
		"start_level": 0
	}, 
	"molotov_up": {
		"title": "汽油瓶", 
		"icon": "res://rogge_art/icons/skills-equipment/A049.png", 
		"start_level": 0
	}, 
	"freeze_up": {
		"title": "寒冰", 
		"icon": "res://rogge_art/icons/skills-equipment/A050.png", 
		"start_level": 0
	}, 
	"regen_up": {
		"title": "回复", 
		"icon": "res://rogge_art/icons/skills-equipment/A051.png", 
		"start_level": 0
	}, 
	"lifesteal_up": {
		"title": "吸血", 
		"icon": "res://rogge_art/icons/skills-equipment/A052.png", 
		"start_level": 0
	}, 
	"shield_up": {
		"title": "玉佩", 
		"icon": "res://rogge_art/icons/skills-equipment/A053.png", 
		"start_level": 0
	}
}

func _ready() -> void :
	_arsenal_label = Label.new()
	_arsenal_label.size = Vector2(125, 20)
	UiFonts.apply_to_label(_arsenal_label, 12)
	_arsenal_label.tooltip_text = L10n.text(ARSENAL_HINT)
	add_child(_arsenal_label)
	_growth_label = Label.new()
	_growth_label.size = Vector2(125, 20)
	UiFonts.apply_to_label(_growth_label, 12)
	_growth_label.tooltip_text = L10n.text(COMBOS.GROWTH_HINT)
	_growth_label.modulate = COMBOS.GROWTH_COLOR
	add_child(_growth_label)
	get_viewport().size_changed.connect(_fit_equipment)
	reset_equipment()

# Invoked on inventory changes, never in the per-frame HUD pass.
func _quality_inventory() -> Variant:
	var host := get_parent().get_parent()
	var inventory: Variant = host.get("forge") if host else null
	return inventory if inventory != null and inventory.enabled else null

func _fit_equipment() -> void :
	if _quality_inventory() != null:
		_fit_quality_equipment()
		return
	var vp: = get_viewport().get_visible_rect().size
	var count: = _slots.size()
	slot_list.columns = 2 if count > 1 else 1
	var rows: = int(ceil(float(count) / slot_list.columns))
	var status_rows := int(_arsenal_label.visible) + int(_growth_label.visible)
	var icon_height := rows * (SLOT_FOOTPRINT.y + 10.0)
	var height: = icon_height + status_rows * 20.0 + (4.0 if status_rows > 0 else 0.0)
	var hud_ui: float=preload("res://script/boss_hud_layout.gd").display_scale(self)
	var top := (preload("res://script/boss_hud_layout.gd").header_top(self)+154)*hud_ui
	var budget := maxf(1.0, vp.y - top - 12 * hud_ui)
	var factor: = minf(1.0, budget / maxf(height, 1))
	var grid_width := SLOT_FOOTPRINT.x * slot_list.columns + 8.0 * (slot_list.columns - 1)
	var width: = maxf(grid_width, 128.0 if status_rows > 0 else 0.0)
	scale = Vector2.ONE * factor
	global_position = Vector2(vp.x - width * factor - 18, top)
	slot_list.position.x = width - grid_width
	slot_list.size = Vector2(grid_width, icon_height)
	_arsenal_label.position = Vector2(0, icon_height + 4)
	_growth_label.position = Vector2(0, icon_height + 4 + (20 if _arsenal_label.visible else 0))

func _fit_quality_equipment() -> void:
	var vp := get_viewport_rect().size
	var hud := preload("res://script/boss_hud_layout.gd")
	var ui: float = hud.display_scale(self)
	var top: float = hud.header_top(self) + 148
	var budget := maxf(90, vp.y/ui - top - 18)
	var status_rows := int(_arsenal_label.visible) + int(_growth_label.visible)
	var spacing := 3
	var rows_fit := maxi(1, floori((budget - status_rows*20) / (QUALITY_FOOTPRINT.y + spacing)))
	var max_columns := clampi(floori(vp.x/ui * 0.55 / QUALITY_FOOTPRINT.x), 2, 3)
	slot_list.columns = clampi(ceili(float(_slots.size()) / rows_fit), 1, max_columns)
	slot_list.add_theme_constant_override("h_separation", spacing)
	slot_list.add_theme_constant_override("v_separation", spacing)
	var rows := ceili(float(_slots.size()) / slot_list.columns)
	var grid_size := Vector2(slot_list.columns * (QUALITY_FOOTPRINT.x+spacing)-spacing, rows * (QUALITY_FOOTPRINT.y+spacing))
	var factor := minf(1.0, budget / maxf(1.0, grid_size.y+status_rows*20))
	var width := maxf(grid_size.x, 128.0 if status_rows else 0.0)
	scale = Vector2.ONE * factor * ui
	global_position = Vector2(vp.x - width * scale.x - 8*ui, top*ui)
	slot_list.position = Vector2(width-grid_size.x, 0)
	slot_list.size = grid_size
	for caption: Label in [_arsenal_label, _growth_label]:
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		caption.size.x = width
	_arsenal_label.position = Vector2(0, grid_size.y)
	_growth_label.position = Vector2(0, grid_size.y+(20 if _arsenal_label.visible else 0))

func reset_equipment(classic_weapons := true) -> void :
	reset_combo_effects()
	for child in slot_list.get_children():
		slot_list.remove_child(child)
		child.queue_free()
	_slots.clear()
	set_arsenal_status(0, false, 0.0)
	set_growth_status(0, false)

	if not classic_weapons: return
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

func set_card_count(id: String, count: int) -> void:
	if not EQUIP_DEFS.has(id): return
	var previous := get_level(id)
	if count == previous: return
	if count > 0:
		_kill_slot_tween(id)
		_add_or_set_level(id, count, false)
		refresh_quality(id)
		if count > previous:
			_play_rank_hop(id)
	elif _slots.has(id):
		_kill_slot_tween(id)
		var slot: Control = _slots[id].root
		slot_list.remove_child(slot)
		slot.queue_free()
		_slots.erase(id)
		_fit_equipment()
	refresh_combo_borders()

func refresh_quality(id: String) -> void:
	if not _slots.has(id): return
	var inventory: Variant = _quality_inventory()
	if inventory == null: return
	var slot: Dictionary = _slots[id]
	slot.root.custom_minimum_size = QUALITY_FOOTPRINT
	slot.icon_wrap.position = Vector2(2,3)
	slot.icon_wrap.size = Vector2(26,26)
	slot.icon.custom_minimum_size = Vector2(24,24)
	slot.icon.size = Vector2(24,24)
	slot.icon.position = Vector2(1,1)
	var level := get_level(id)
	var label: Label = slot.level_label
	var digits := "+%d" % level
	var font := label.get_theme_font("font")
	var available := QUALITY_FOOTPRINT.x - RANK_LEFT - 2
	var natural_width := font.get_string_size(digits, HORIZONTAL_ALIGNMENT_LEFT, -1, RANK_FONT_SIZE).x
	var font_size := mini(RANK_FONT_SIZE, floori(RANK_FONT_SIZE * available / maxf(natural_width, 1.0)))
	label.text = digits
	label.add_theme_font_size_override("font_size", font_size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.size = Vector2(available, QUALITY_FOOTPRINT.y)
	if slot.juice_tween == null or not slot.juice_tween.is_running():
		label.position = Vector2(RANK_LEFT, roundf((QUALITY_FOOTPRINT.y - label.size.y) * 0.5))
		label.scale = Vector2.ONE
	label.pivot_offset = Vector2(0, label.size.y * 0.75)
	label.add_theme_color_override("font_color",QUALITY.COLORS[QUALITY.tier_for(level)])
	slot.icon_wrap.tooltip_text = L10n.text(EQUIP_DEFS[id].title) + "  " + label.text + "\n" + COMBOS.hint_for(id)

# Run after play resumes so the draft or forge overlay cannot swallow the hop.
func _play_rank_hop(id: String) -> void:
	var label: Label = _slots[id].level_label
	var rest_y := label.position.y
	var tween := label.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	_slots[id].juice_tween = tween
	tween.tween_property(label, "scale", Vector2(1.05, 0.84), 0.05)
	tween.tween_property(label, "position:y", rest_y - 7.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "scale", Vector2(0.95, 1.12), 0.08)
	tween.tween_property(label, "position:y", rest_y, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(label, "scale", Vector2(1.05, 0.90), 0.10)
	tween.tween_property(label, "scale", Vector2.ONE, 0.13).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func get_level(upgrade_id: String) -> int:
	if _slots.has(upgrade_id):
		return int(_slots[upgrade_id]["level"])
	return 0

func set_arsenal_status(owned: int, active: bool, seconds: float) -> void:
	if _arsenal_label == null: return
	var was_visible := _arsenal_label.visible
	_arsenal_label.visible = owned > 0
	_arsenal_label.text = (L10n.text("无敌护盾 %.1fs") % seconds if active else L10n.text("军械护盾 %.1fs") % seconds) if owned == 3 else L10n.text("军械组合 %d/3") % owned
	_arsenal_label.modulate = COMBOS.ARSENAL_COLOR.lightened(0.2 if active else 0.0) if owned == 3 else LEVEL_COLOR
	if was_visible != _arsenal_label.visible: _fit_equipment()

func set_growth_status(owned: int, active: bool) -> void:
	if _growth_label == null: return
	var was_visible := _growth_label.visible
	_growth_label.visible = owned > 0
	_growth_label.text = L10n.text("生机组合 已激活") if active else L10n.text("生机组合 %d/3") % owned
	if was_visible != _growth_label.visible: _fit_equipment()

func reset_combo_effects() -> void:
	dragon_active = false
	pocket_active = false
	dimension_active = false
	crimson_active = false
	for slot in _slots.values():
		var border: Control = slot.get("combo_border")
		if is_instance_valid(border): border.visible = false
	_active_combo_borders.clear()
	_combo_clock = 0.0
	_border_tick_left = 0.0
	set_process(false)

func refresh_combo_borders() -> void:
	dragon_active = COMBOS.owned_count(self,COMBOS.DRAGON_MEMBERS) == COMBOS.DRAGON_MEMBERS.size()
	pocket_active = COMBOS.owned_count(self,COMBOS.POCKET_MEMBERS) == COMBOS.POCKET_MEMBERS.size()
	dimension_active = COMBOS.owned_count(self, COMBOS.DIMENSION_MEMBERS) == COMBOS.DIMENSION_MEMBERS.size()
	crimson_active = COMBOS.completes_crimson(self, "")
	var growth := COMBOS.owned_count(self, COMBOS.GROWTH_MEMBERS) == COMBOS.GROWTH_MEMBERS.size()
	var arsenal := COMBOS.owned_count(self, COMBOS.ARSENAL_MEMBERS) == COMBOS.ARSENAL_MEMBERS.size()
	_active_combo_borders.clear()
	for id in _slots:
		var border: Control = _slots[id].get("combo_border")
		if not is_instance_valid(border): continue
		var group := COMBOS.group_for(id)
		var active := crimson_active if group == "crimson" else (growth if group == "growth" else arsenal)
		if group == "dragon": active = dragon_active
		if group == "pocket": active = pocket_active
		if group == "dimension": active = dimension_active
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
	icon_wrap.set_script(preload("res://script/equipment_tooltip.gd"))
	icon_wrap.position = Vector2(6, 6)
	icon_wrap.size = SLOT_SIZE
	icon_wrap.mouse_filter = Control.MOUSE_FILTER_PASS
	icon_wrap.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon_wrap.add_theme_stylebox_override("panel", preload("res://script/painted_ui.gd").MOSS)

	var icon: = TextureRect.new()
	icon.custom_minimum_size = ICON_SIZE
	icon.position = Vector2(6, 6)
	icon.size = ICON_SIZE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = load(def["icon"])
	var combo_hint := COMBOS.hint_for(upgrade_id)
	icon_wrap.tooltip_text = L10n.text(str(def.title)) + ("\n" + combo_hint if not combo_hint.is_empty() else "")
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
	level_label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.04))
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
	if _quality_inventory() != null:
		refresh_quality(upgrade_id)
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

func refresh_language() -> void:
	for id in _slots:
		if _quality_inventory() != null:
			refresh_quality(id)
			continue
		var hint:=COMBOS.hint_for(id)
		_slots[id].icon_wrap.tooltip_text=L10n.text(EQUIP_DEFS[id].title)+("\n"+hint if not hint.is_empty() else "")
