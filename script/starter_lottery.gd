extends "res://script/treasure_lottery.gd"

signal loadout_claimed(loadout: Dictionary)

const QUALITY := preload("res://script/card_quality_style.gd")
const MAX_REROLLS := 3
const EQUIPMENT := preload("res://script/equipment_panel.gd").EQUIP_DEFS
const COMBOS := preload("res://script/equipment_combos.gd")
const FOIL := preload("res://shaders/starter_foil.gdshader")
# Each of these can deal damage on its own at rank one.
const WEAPONS := ["axe_up", "circle_up", "gun_up", "drone_up", "bomb", "rune_bolt",
	"silver_knife", "cross_blade", "holy_water", "pulse_aura", "thorn_whip", "light_thorn", "ice_wave", "ghost_dash", "blood_vortex", "draw_slash", "lightning_ring"]
var loadout: Dictionary = {}
var rerolls_left := MAX_REROLLS
var _reroll: Button
var foil := ShaderMaterial.new()
var previous_icons: Array[TextureRect] = []
var roll_tweens: Array[Tween] = []
var tier_labels: Array[Label] = []

func reel_capacity() -> int:
	return 4

static func draw_loadout(perk: String, percentile: int) -> Dictionary:
	var cards: Array[String] = []
	var group := ""
	var backup := ""
	var weapons := WEAPONS.duplicate()
	weapons.erase(perk)
	if percentile < 30:
		if percentile < 10:
			group = "growth"
			cards.assign(COMBOS.GROWTH_MEMBERS)
			if perk not in WEAPONS:
				backup = weapons.pick_random()
		elif percentile < 20:
			group = "arsenal"
			cards.assign(COMBOS.ARSENAL_MEMBERS)
		else:
			group = "crimson"
			cards.assign(COMBOS.CRIMSON_MEMBERS)
	else:
		cards.append(weapons.pick_random())
		var candidates := EQUIPMENT.keys()
		candidates.shuffle()
		for id: String in candidates:
			if id == perk or id in cards: continue
			var owned := cards + [perk, id]
			if COMBOS.GROWTH_MEMBERS.all(func(item): return item in owned): continue
			if COMBOS.CRIMSON_MEMBERS.all(func(item): return item in owned): continue
			if COMBOS.ARSENAL_MEMBERS.all(func(item): return item in owned): continue
			cards.append(id)
			if cards.size() == 3: break
	var tiers := {}
	var awarded := cards.duplicate()
	if not backup.is_empty(): awarded.append(backup)
	for id in awarded:
		var roll := randi_range(0, 99)
		tiers[id] = 0 if roll < 80 else (1 if roll < 98 else 2)
	return {"cards": cards, "group": group, "backup": backup, "perk": perk, "tiers": tiers}

func _ready() -> void:
	super._ready()
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	_box.add_child(actions)
	_reroll = Button.new()
	_reroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reroll.add_theme_stylebox_override("normal", _style(Color("#28374a"), Color("#809bb3")))
	_reroll.add_theme_stylebox_override("disabled", _style(Color("#35383b"), Color("#575a5d")))
	_reroll.add_theme_color_override("font_disabled_color", Color("#aaadb0"))
	_reroll.pressed.connect(_on_reroll_pressed)
	actions.add_child(_reroll)
	_button.reparent(actions, false)
	_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fit()
	foil.shader = FOIL
	_burst.set_process(false)
	for i in _reels.size():
		var window := Control.new()
		window.mouse_filter = Control.MOUSE_FILTER_IGNORE
		window.clip_contents = true
		_reel_panels[i].add_child(window)
		var icon := _reels[i]
		icon.reparent(window, false)
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var previous := icon.duplicate() as TextureRect
		window.add_child(previous)
		previous.hide()
		var badge := Label.new()
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		badge.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		badge.add_theme_constant_override("outline_size", 4)
		badge.add_theme_color_override("font_outline_color", Color("#191a24"))
		window.add_child(badge)
		badge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		badge.hide()
		tier_labels.append(badge)
		previous_icons.append(previous)
		roll_tweens.append(null)
	_fit()
	for id: String in EQUIPMENT:
		var card: Dictionary = EQUIPMENT[id].duplicate()
		card.id = id
		_pool.append(card)

func _fit() -> void:
	super._fit()
	for badge in tier_labels:
		UiFonts.apply_to_label(badge, maxi(10, _detail.get_theme_font_size("font_size")-1), true)
	if _reel_panels.size() == 4 and _reel_panels[3].visible:
		var reel_size := minf(_reel_panels[0].custom_minimum_size.x, (_panel.custom_minimum_size.x - 70.0) / 4.0)
		for panel in _reel_panels: panel.custom_minimum_size = Vector2.ONE * reel_size
	if _reroll:
		UiFonts.apply_to_button(_reroll, _button.get_theme_font_size("font_size"))
		_reroll.custom_minimum_size.y = _button.custom_minimum_size.y

func open_for(perk: String, crimson_practice := false) -> void:
	rerolls_left = MAX_REROLLS
	_reroll.hide()
	claimed = false
	_prepare_roll(perk, crimson_practice)
	get_tree().paused = true
	root_clear_movement()
	show()
	_button.grab_focus()

func _prepare_roll(perk: String, crimson_practice := false) -> void:
	loadout = draw_loadout(perk, 20 if crimson_practice else randi_range(0, 99))
	_reel_panels[3].hide()
	_fit()
	_reroll.disabled = true
	_reroll.text = L10n.text("重摇（%d）") % rerolls_left
	spinning = false
	revealed = false
	spin_time = 0.0
	_tick_left = 0.0
	_burst.strength = 0
	_panel.material = null
	_title.remove_theme_color_override("font_color")
	_box.get_child(0).text = L10n.text("出发前的补给")
	_title.text = L10n.text("开局老虎机")
	_result.text = L10n.text("转动三轴，领取开局装备")
	_result.add_theme_color_override("font_color", Color.WHITE)
	_detail.text = L10n.text("角色自带：%s · 完整套装概率 30%%") % item_name(perk)
	for i in _reels.size():
		tier_labels[i].hide()
		_set_reel(i, _pool.pick_random())
		_reel_panels[i].modulate = Color.WHITE
		_reel_panels[i].material = null
	_button.text = L10n.text("转动老虎机")
	_button.disabled = false

func _on_reroll_pressed() -> void:
	if not visible or claimed or not revealed or spinning or rerolls_left <= 0: return
	rerolls_left -= 1
	_prepare_roll(loadout.perk)
	super._on_button()

func item_name(id: String) -> String:
	return L10n.text(EQUIPMENT[id].title)

func _set_reel(i: int, data: Dictionary) -> void:
	var icon := _reels[i]
	var previous := previous_icons[i]
	if roll_tweens[i]: roll_tweens[i].kill()
	previous.texture = icon.texture
	previous.material = icon.material
	super._set_reel(i, data)
	if not spinning:
		icon.position.y = 0
		previous.hide()
		return
	var height := icon.size.y
	icon.position.y = -height
	previous.position.y = 0
	previous.show()
	var motion := create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	roll_tweens[i] = motion
	motion.tween_property(icon, "position:y", 0.0, _tick_left)
	motion.tween_property(previous, "position:y", height, _tick_left)

func _stopped_reel(i: int) -> void:
	if roll_tweens[i]: roll_tweens[i].kill()
	previous_icons[i].hide()
	_reels[i].position.y = 0
	var id: String = loadout.cards[i]
	_reels[i].texture = load(EQUIPMENT[id].icon)
	preload("res://script/visual_style.gd").style_icon(_reels[i], id)

func _reveal() -> void:
	spinning = false
	revealed = true
	var names := PackedStringArray()
	var crimson: bool = loadout.group == "crimson"
	_reel_panels[3].visible = crimson
	_fit()
	for i in loadout.cards.size():
		if crimson: _reel_panels[i].modulate = Color.WHITE
		_stopped_reel(i)
		names.append(item_name(loadout.cards[i]))
		var tier := int(loadout.get("tiers", {}).get(loadout.cards[i], 0))
		tier_labels[i].text = QUALITY.tier_name(tier)
		tier_labels[i].add_theme_color_override("font_color", QUALITY.COLORS[tier])
		tier_labels[i].show()
	var jackpot: bool = loadout.group != ""
	if jackpot:
		foil.set_shader_parameter("crimson", crimson)
		_panel.material = foil
		for reel in _reel_panels: reel.material = foil
	_title.text = L10n.text("开局装备已就绪")
	if jackpot:
		_title.text = L10n.text("生机套装！") if loadout.group == "growth" else L10n.text("军械套装！")
	if crimson:
		_title.text = L10n.text(COMBOS.CRIMSON_TITLE)
		_title.add_theme_color_override("font_color", COMBOS.CRIMSON_COLOR.lightened(0.38))
	_result.text = "  ·  ".join(names)
	_detail.text = L10n.text("角色自带：%s") % item_name(loadout.perk)
	if crimson: _detail.text += "\n" + L10n.text(COMBOS.CRIMSON_BONUS)
	if loadout.backup != "":
		_detail.text += "\n" + L10n.text("随行武器：%s") % (QUALITY.tier_name(loadout.get("tiers", {}).get(loadout.backup,0))+" · "+item_name(loadout.backup))
	_reroll.show()
	_reroll.disabled = rerolls_left == 0
	_button.text = L10n.text("确定并出发")
	_button.disabled = false
	_fanfare.pitch_scale = 1.15 if jackpot else 1.0
	_fanfare.play()
	_button.grab_focus()

func _on_button() -> void:
	if spinning or claimed or not visible: return
	if not revealed:
		super._on_button()
		return
	claimed = true
	hide()
	loadout_claimed.emit(loadout)
