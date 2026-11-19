extends "res://script/treasure_lottery.gd"

signal loadout_claimed(loadout: Dictionary)

const EQUIPMENT := preload("res://script/equipment_panel.gd").EQUIP_DEFS
const COMBOS := preload("res://script/equipment_combos.gd")
const FOIL := preload("res://shaders/starter_foil.gdshader")
# Each of these can deal damage on its own at rank one.
const WEAPONS := ["axe_up", "circle_up", "gun_up", "drone_up", "bomb", "rune_bolt",
	"silver_knife", "cross_blade", "holy_water", "pulse_aura", "thorn_whip", "lightning_ring"]
var loadout: Dictionary = {}
var foil := ShaderMaterial.new()
var previous_icons: Array[TextureRect] = []
var roll_tweens: Array[Tween] = []

static func draw_loadout(perk: String, percentile: int) -> Dictionary:
	var cards: Array[String] = []
	var group := ""
	var backup := ""
	var weapons := WEAPONS.duplicate()
	weapons.erase(perk)
	if percentile < 30:
		if randi_range(0, 1) == 0:
			group = "growth"
			cards.assign(COMBOS.GROWTH_MEMBERS)
			if perk not in WEAPONS:
				backup = weapons.pick_random()
		else:
			group = "arsenal"
			cards.assign(COMBOS.ARSENAL_MEMBERS)
	else:
		cards.append(weapons.pick_random())
		var candidates := EQUIPMENT.keys()
		candidates.shuffle()
		for id: String in candidates:
			if id == perk or id in cards: continue
			var owned := cards + [perk, id]
			if COMBOS.GROWTH_MEMBERS.all(func(item): return item in owned): continue
			if COMBOS.ARSENAL_MEMBERS.all(func(item): return item in owned): continue
			cards.append(id)
			if cards.size() == 3: break
	return {"cards": cards, "group": group, "backup": backup, "perk": perk}

func _ready() -> void:
	super._ready()
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
		previous_icons.append(previous)
		roll_tweens.append(null)
	for id: String in EQUIPMENT:
		var card: Dictionary = EQUIPMENT[id].duplicate()
		card.id = id
		_pool.append(card)

func open_for(perk: String) -> void:
	loadout = draw_loadout(perk, randi_range(0, 99))
	claimed = false
	spinning = false
	revealed = false
	spin_time = 0.0
	_tick_left = 0.0
	_burst.strength = 0
	_panel.material = null
	_box.get_child(0).text = L10n.text("出发前的补给")
	_title.text = L10n.text("开局老虎机")
	_result.text = L10n.text("转动三轴，领取开局装备")
	_result.add_theme_color_override("font_color", Color.WHITE)
	_detail.text = L10n.text("角色自带：%s · 完整套装概率 30%%") % item_name(perk)
	for i in _reels.size():
		_set_reel(i, _pool.pick_random())
		_reel_panels[i].modulate = Color.WHITE
		_reel_panels[i].material = null
	_button.text = L10n.text("转动老虎机")
	_button.disabled = false
	get_tree().paused = true
	root_clear_movement()
	show()
	_button.grab_focus()

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
	for i in _reels.size():
		_stopped_reel(i)
		names.append(item_name(loadout.cards[i]))
	var jackpot: bool = loadout.group != ""
	if jackpot:
		_panel.material = foil
		for reel in _reel_panels: reel.material = foil
	_title.text = L10n.text("开局装备已就绪")
	if jackpot:
		_title.text = L10n.text("生机套装！") if loadout.group == "growth" else L10n.text("军械套装！")
	_result.text = "  ·  ".join(names)
	_detail.text = L10n.text("角色自带：%s") % item_name(loadout.perk)
	if loadout.backup != "":
		_detail.text += "\n" + L10n.text("随行武器：%s") % item_name(loadout.backup)
	_button.text = L10n.text("领取并出发")
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
