extends CanvasLayer

@export var card_scene: PackedScene
@onready var h_box_container: GridContainer = $Panel / HBoxContainer

signal upgrade_selected(upgrade_id: String)

const DRAW_COUNT: = 3
const PREVIEW := preload("res://script/card_preview.gd")
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
var _card_scroll: ScrollContainer

var upgrade_pool: = [
	{"id": "bomb", "title": "炸弹", "desc": "", "icon": "res://assest/sprites/bomb.svg", "max_level": 5},
	{"id": "critical_glasses", "title": "暴击眼镜", "desc": "", "icon": "res://assest/sprites/critical_glasses.svg", "max_level": 5},
	{"id": "banana_fan", "title": "芭蕉扇", "desc": "", "icon": "res://assest/sprites/banana_fan.svg", "max_level": 5},
	{"id": "black_hole", "title": "黑洞", "desc": "", "icon": "res://assest/sprites/black_hole.svg", "max_level": 5},
	{"id": "poison_trail", "title": "剧毒踪迹", "desc": "", "icon": "res://assest/sprites/poison_trail.svg", "max_level": 5},
	{"id": "wind_emblem", "title": "踏风徽记", "desc": "", "icon": "res://assest/sprites/wind_emblem.svg"},
	{"id": "echo_ember", "title": "回响火种", "desc": "", "icon": "res://assest/sprites/echo_ember.svg"},
	{
		"id": "lightning_ring", 
		"title": "闪电戒指",
		"desc": "", 
		"icon": "res://assest/sprites/lightning_ring.svg"
	}, 
	{
		"id": "axe_up", 
		"title": "斧头",
		"desc": "提高斧头攻击力", 
		"icon": "res://assest/sprites/axe.png"
	}, 
	{
		"id": "circle_up", 
		"title": "书本",
		"desc": "增加书本并提高伤害\n最多12本，之后继续强化伤害", 
		"icon": "res://assest/sprites/book.png"
	}, 
	{
		"id": "gun_up", 
		"title": "枪支",
		"desc": "提高枪支属性", 
		"icon": "res://assest/weaponR1.png"
	}, 
	{
		"id": "pickup_up", 
		"title": "拾取",
		"desc": "提高拾取范围", 
		"icon": "res://assest/bullet.png"
	}, 
	{
		"id": "speed_up", 
		"title": "移速",
		"desc": "提高移动速度", 
		"icon": "res://assest/sprites/Speedup.png"
	}, 
	{
		"id": "left_fist", 
		"title": "左拳",
		"desc": "", 
		"icon": "res://assest/sprites/fist_left.svg"
	}, 
	{
		"id": "right_fist", 
		"title": "右拳",
		"desc": "", 
		"icon": "res://assest/sprites/fist_right.svg"
	}, 
	{
		"id": "drone_up", 
		"title": "无人机",
		"desc": "", 
		"icon": "res://assest/sprites/drone.svg"
	}, 
	{
		"id": "molotov_up", 
		"title": "汽油瓶",
		"desc": "", 
		"icon": "res://assest/sprites/molotov.svg"
	}, 
	{
		"id": "freeze_up", 
		"title": "寒冰",
		"desc": "", 
		"icon": "res://assest/sprites/freeze.svg"
	}, 
	{
		"id": "regen_up", 
		"title": "回复",
		"desc": "", 
		"icon": "res://assest/sprites/regen_sprout.svg"
	}, 
	{
		"id": "lifesteal_up", 
		"title": "吸血",
		"desc": "", 
		"icon": "res://assest/sprites/crimson_fang.svg"
	}, 
	{
		"id": "monster_necklace", 
		"title": "怪物项链",
		"desc": "", 
		"icon": "res://assest/sprites/monster_necklace.png"
	}, 
	{
		"id": "shield_up", 
		"title": "玉佩",
		"desc": "", 
		"icon": "res://assest/sprites/jade_guard.svg"
	}
]

func _ready():
	layer = 140
	visible = false
	_card_scroll = ScrollContainer.new()
	_card_scroll.name = "CardScroll"
	_card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_card_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	$Panel.add_child(_card_scroll)
	h_box_container.reparent(_card_scroll)
	_draft_rng.randomize()
	growth_hint = Label.new()
	growth_hint.name = "GrowthHint"
	growth_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	growth_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	growth_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	growth_hint.add_theme_color_override("font_color", GamePalette.PLAYER_DAMAGE_WHITE)
	$Panel.add_child(growth_hint)
	reroll_button = Button.new()
	reroll_button.name = "RerollButton"
	reroll_button.pressed.connect(_on_reroll)
	$Panel.add_child(reroll_button)
	var style: = StyleBoxFlat.new()
	style.bg_color = GamePalette.UI_GREY_BASE
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
	reroll_hint.modulate = GamePalette.UI_GREY_BORDER
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

func _fit_cards() -> void:
	_fit_pending = false
	if h_box_container == null or h_box_container.get_child_count() == 0: return
	var vp := get_viewport().get_visible_rect().size
	var transform := get_viewport().get_final_transform()
	var ratio := 1.0
	if OS.has_feature("web"):
		var css: Variant = JavaScriptBridge.eval("(function(){var c=document.getElementById('canvas');return c?c.getBoundingClientRect().width:window.innerWidth;})()",true)
		if (css is float or css is int) and float(css) > 0: ratio = float(get_tree().root.size.x) / float(css)
	var ui := ratio / maxf((transform * Vector2.RIGHT - transform * Vector2.ZERO).length(),0.1)
	var portrait := vp.y > vp.x
	var compact := portrait or vp.y / ui < 460
	var count := h_box_container.get_child_count()
	h_box_container.columns = 1 if portrait else count
	var gap := 10.0 * ui
	var width := minf((vp.x-48*ui-gap*(h_box_container.columns-1))/h_box_container.columns, (420.0 if portrait else 280.0)*ui)
	for card in h_box_container.get_children(): card.set_display_width(width,ui,compact)
	h_box_container.add_theme_constant_override("h_separation",int(gap))
	h_box_container.add_theme_constant_override("v_separation",int(gap))
	var content := h_box_container.get_combined_minimum_size()
	h_box_container.set_anchors_preset(Control.PRESET_TOP_LEFT)
	h_box_container.scale = Vector2.ONE
	h_box_container.size = content
	var body_height := maxf(90*ui,vp.y-192*ui)
	_card_scroll.position = Vector2((vp.x-content.x-16*ui)*0.5,96*ui+maxf(0,(body_height-content.y)*0.5))
	_card_scroll.size = Vector2(content.x+16*ui,minf(content.y,body_height))
	h_box_container.position = Vector2.ZERO
	UiFonts.apply_to_label(growth_hint,int(13*ui))
	growth_hint.position = Vector2(16*ui,56*ui)
	growth_hint.size = Vector2(vp.x-32*ui,40*ui)
	UiFonts.apply_to_button(reroll_button,int(16*ui))
	reroll_button.position = Vector2((vp.x-260*ui)*0.5,vp.y-84*ui)
	reroll_button.size = Vector2(260,44)*ui
	UiFonts.apply_to_label(reroll_hint,int(11*ui))
	reroll_hint.position = reroll_button.position + Vector2(-40,48)*ui
	reroll_hint.size = Vector2(340,24)*ui
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
	var result := data.duplicate(true)
	var game := _get_game()
	var id: String = result.get("id", "")
	result.merge(PREVIEW.build(game, id), true)
	if game != null:
		var rank: int = PREVIEW.rank_for(game,id)
		result.title = str(game.equipment_panel.EQUIP_DEFS[id].title) + " · %d → %d级" % [rank, rank + 1]
	return result


func _get_game() -> Node:
	return get_tree().get_first_node_in_group("game")


func _fist_desc(is_left: bool) -> String:
	return PREVIEW.build(_get_game(), "left_fist" if is_left else "right_fist").desc

func _drone_desc() -> String: return PREVIEW.build(_get_game(), "drone_up").desc
func _molotov_desc() -> String: return PREVIEW.build(_get_game(), "molotov_up").desc
func _regen_desc() -> String: return PREVIEW.build(_get_game(), "regen_up").desc
func _lifesteal_desc() -> String: return PREVIEW.build(_get_game(), "lifesteal_up").desc
func _shield_desc() -> String: return PREVIEW.build(_get_game(), "shield_up").desc
func _freeze_desc() -> String: return PREVIEW.build(_get_game(), "freeze_up").desc


func on_card_selected(upgrade_id: String):
	if not visible: return
	visible = false
	upgrade_selected.emit(upgrade_id)
	get_tree().paused = false


func _on_button_pressed():
	get_tree().paused = false
	visible = false

func _monster_necklace_desc() -> String: return PREVIEW.build(_get_game(), "monster_necklace").desc
func _heal_number(amount: float) -> String: return CardNumbers.number(amount)
func _lightning_ring_desc() -> String: return PREVIEW.build(_get_game(), "lightning_ring").desc
