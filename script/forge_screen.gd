extends CanvasLayer

signal finished

const HEARTH := preload("res://rogge_art/environment-ui/forge/hearth.webp")
const EQUIP := preload("res://script/equipment_panel.gd").EQUIP_DEFS
const QUALITY := preload("res://script/card_quality_style.gd")
const PAPER := Color("#efe0c6")
const MUTED := Color("#b2a99a")
const GOLD := Color("#edb36b")
const PANEL := Color("#22262e")
const EDGE := Color("#6b5545")
const DARK := Color("#151a21")

var game: Node
var main_uid := -1
var sub_uids: Array = [-1, -1]
var active_slot := 0
var has_forged := false
var message := ""
var backdrop := ColorRect.new()
var board := Control.new()
var inventory_scroll: ScrollContainer
var deck: Control
var quit_button: Button
var action_button: Button
var supply_button: Button
var foil_materials: Array[ShaderMaterial] = []
var slot_foils: Array[ColorRect] = []
var result_plate: Panel
var result_foil: ColorRect
var upgrade_button: Button
var header_status: Label
var inventory_hint: Label
var outcome_label: Label
var reward_label: Label
var result_icon: TextureRect
var result_title: Label
var odds_label: Label
var changes_label: Label
var details_scroll: ScrollContainer
var slot_buttons: Array[Button] = []
var slot_icons: Array[TextureRect] = []
var slot_titles: Array[Label] = []
var slot_contents: Array[Label] = []
var slot_clear: Array[Button] = []
var fan_buttons: Array[Button] = []
var groups: Array = []
var inventory_offset := 0
var portrait := false
var working := false
var work_tween: Tween
var result_tween: Tween
var result_visible := false
var hearth: TextureRect
var preview_heading: Label
var restore_combat_controls := false
var inputs := preload("res://script/forge_drag.gd").new()
var feedback := preload("res://script/forge_feedback.gd").new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 170
	for amber in [false,true]:
		var foil := ShaderMaterial.new()
		foil.shader = preload("res://shaders/forge_foil.gdshader")
		foil.set_shader_parameter("amber",amber)
		foil_materials.append(foil)
	visible = false
	backdrop.color = Color("#11151bef")
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(board)
	board.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(inputs)
	board.add_child(feedback)
	feedback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_viewport().size_changed.connect(_resize)
	visibility_changed.connect(_visibility_changed)

func _visibility_changed() -> void:
	var host := get_tree().current_scene
	if is_instance_valid(host) and "mobile_controls" in host and is_instance_valid(host.mobile_controls):
		if visible:
			restore_combat_controls = host.mobile_controls.visible
			host.mobile_controls.hide_controls()
		elif restore_combat_controls:
			restore_combat_controls = false
			if not host._returning_home: host.mobile_controls.show_controls()
	inputs.sync_cursor()
	if not visible: _stop_effects()

func _stop_effects() -> void:
	inputs.cancel()
	if is_instance_valid(work_tween): work_tween.kill()
	if is_instance_valid(result_tween): result_tween.kill()
	working = false
	result_visible = false
	feedback.cancel_fx()

func _exit_tree() -> void:
	if is_instance_valid(work_tween): work_tween.kill()
	if is_instance_valid(result_tween): result_tween.kill()

func open_for(current_game: Node) -> void:
	_stop_effects()
	game = current_game
	var host := get_tree().current_scene
	if is_instance_valid(host) and "session_menu" in host and is_instance_valid(host.session_menu):
		if not host.session_menu.visibility_changed.is_connected(inputs.sync_cursor):
			host.session_menu.visibility_changed.connect(inputs.sync_cursor)
	main_uid = -1
	sub_uids = [-1, -1]
	active_slot = 0
	has_forged = false
	inventory_offset = 0
	message = ""
	get_tree().paused = true
	if has_node("/root/MobileInput"):
		get_node("/root/MobileInput").clear_move()
		get_node("/root/MobileInput").clear_dash()
	show()
	_build()

func _resize() -> void:
	if visible and is_instance_valid(game):
		_build()

func _place(node: Control, parent: Control, rect: Rect2) -> void:
	parent.add_child(node)
	node.position = rect.position
	node.size = rect.size

func _box(fill: Color, rim: Color, border := 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = rim
	style.set_border_width_all(border)
	style.set_corner_radius_all(4)
	return style

func _panel(parent: Control, rect: Rect2, fill := PANEL, rim := EDGE) -> Panel:
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", _box(fill, rim))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(panel, parent, rect)
	return panel

func _label(parent: Control, rect: Rect2, value: String, font_size: int, color := PAPER, bold := false) -> Label:
	var label := Label.new()
	label.text = value
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiFonts.apply_to_label(label, font_size, bold)
	label.add_theme_color_override("font_color", color)
	_place(label, parent, rect)
	return label

func _btn(parent: Control, rect: Rect2, value: String, callback: Callable, accent := false) -> Button:
	var button := Button.new()
	var fill := Color("#8b461e") if accent else Color("#313541")
	var rim := GOLD if accent else Color("#786b5d")
	button.text = value
	UiFonts.apply_to_button(button, 17)
	button.add_theme_stylebox_override("normal", _box(fill, rim))
	button.add_theme_stylebox_override("hover", _box(fill.lightened(0.12), GOLD))
	button.add_theme_stylebox_override("pressed", _box(fill.darkened(0.15), GOLD))
	button.add_theme_stylebox_override("disabled", _box(Color("#303238"), Color("#575655")))
	button.add_theme_color_override("font_disabled_color", Color("#a19a90"))
	button.pressed.connect(callback)
	_place(button, parent, rect)
	return button

func _image(parent: Control, rect: Rect2, texture: Texture2D = null) -> TextureRect:
	var image := TextureRect.new()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	image.texture = texture
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(image, parent, rect)
	return image

func _foil(parent: Control) -> ColorRect:
	var face := ColorRect.new()
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(face)
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	face.offset_left = 4
	face.offset_top = 4
	face.offset_right = -4
	face.offset_bottom = -4
	return face

func _foil_tier(face: ColorRect, tier: int) -> void:
	face.visible = tier >= 2
	if face.visible: face.material = foil_materials[1 if tier >= 3 else 0]

func _build() -> void:
	inputs.cancel()
	var last_view := get_viewport().get_visible_rect().size
	portrait = last_view.y > last_view.x
	if is_instance_valid(inventory_scroll) and inventory_scroll.is_inside_tree():
		inventory_offset = inventory_scroll.scroll_horizontal
	for child in board.get_children():
		if child == feedback: continue
		board.remove_child(child)
		child.queue_free()
	slot_buttons.clear()
	slot_icons.clear()
	slot_foils.clear()
	slot_titles.clear()
	slot_contents.clear()
	slot_clear.clear()
	fan_buttons.clear()
	var design := Vector2(396, 750) if portrait else Vector2(900, 532)
	var factor := minf(last_view.x / design.x, last_view.y / design.y)
	board.scale = Vector2.ONE * factor
	board.size = design
	board.position = (last_view - design * factor) * 0.5
	_panel(board, Rect2(Vector2.ZERO, design), Color("#191d24"), EDGE)
	_label(board, Rect2(14, 4, 220, 34), L10n.text("关后锻造"), 25, PAPER, true)
	quit_button = _btn(board, Rect2(design.x-112, 6, 100, 36), "", _finish)
	header_status = _label(board, Rect2(14 if portrait else 255, 44 if portrait else 6, design.x-160 if portrait else 384, 32), "", 16, GOLD)
	upgrade_button = _btn(board, Rect2(design.x-154 if portrait else 610, 44 if portrait else 6, 142 if portrait else 158, 34), "", _upgrade)
	supply_button = null
	if game.forge.training:
		var supply_rect := Rect2(128,3,150,42) if portrait else Rect2(445,3,154,42)
		supply_button = _btn(board,supply_rect,L10n.text("+%d 金币 · +%d 卡") % [game.forge.PRACTICE_GOLD,game.forge.PRACTICE_CARDS.size()],_refill_practice)
		UiFonts.apply_to_button(supply_button,15)
		supply_button.tooltip_text = L10n.text("领取六张白卡，各为对应技能增加一级。")
	var left := _panel(board, Rect2(10,85,376,166) if portrait else Rect2(12,54,457,198))
	var art_width := 97 if portrait else 149
	hearth = _image(left, Rect2(2,2,art_width,left.size.y-4), HEARTH)
	hearth.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	hearth.clip_contents = true
	hearth.pivot_offset = Vector2(hearth.size.x * 0.5, hearth.size.y * 0.9)
	var sx := art_width + 9
	var sw := (left.size.x - sx - 14) / 3.0
	for i in 3:
		_build_slot(left, Rect2(sx + i * sw, 15, sw-4, left.size.y-29), i)
	var result := _panel(board, Rect2(10,258,376,166) if portrait else Rect2(478,54,410,198))
	preview_heading = _label(result, Rect2(12,5,160,24), L10n.text("锻造预览"), 15, MUTED)
	result_plate = _panel(result,Rect2(12,34,82,112),DARK,EDGE)
	result_foil = _foil(result_plate)
	result_icon = _image(result, Rect2(11,36,48,48) if portrait else Rect2(13,37,58,58))
	result_title = _label(result, Rect2(68,27,result.size.x-76,36), "", 20, PAPER, true)
	odds_label = _label(result, Rect2(68,62,result.size.x-76,28), "", 14, GOLD)
	details_scroll = ScrollContainer.new()
	details_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_place(details_scroll, result, Rect2(12,88,result.size.x-24,result.size.y-95))
	changes_label = Label.new()
	changes_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	changes_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiFonts.apply_to_label(changes_label, 15)
	changes_label.add_theme_color_override("font_color", PAPER)
	details_scroll.add_child(changes_label)
	var action_y := 432 if portrait else 260
	var action_width := 178 if portrait else 251
	action_button = _btn(board, Rect2(12,action_y,action_width,44), "", _attempt, true)
	outcome_label = _label(board, Rect2(action_width+24, action_y-1, design.x-action_width-35, 47), "", 15, MUTED)
	outcome_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var reward_y := 485 if portrait else 310
	reward_label = _label(board, Rect2(14,reward_y,design.x-28,46 if portrait else 28), "", 15, GOLD)
	reward_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var head_y := 539 if portrait else 343
	inventory_hint = _label(board, Rect2(14,head_y,design.x-114,34), "", 16, PAPER, true)
	_btn(board, Rect2(design.x-99,head_y,40,34), "‹", _scroll_deck.bind(-1))
	_btn(board, Rect2(design.x-53,head_y,40,34), "›", _scroll_deck.bind(1))
	inventory_scroll = ScrollContainer.new()
	inventory_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	inventory_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inventory_scroll.scroll_deadzone = 6
	_place(inventory_scroll, board, Rect2(10,head_y+39,design.x-20,design.y-head_y-47))
	deck = Control.new()
	inventory_scroll.add_child(deck)
	board.move_child(feedback,-1)
	_refresh(true)
	if result_visible: feedback.move_target(_result_rect())

func _build_slot(parent: Control, rect: Rect2, index: int) -> void:
	var button := _btn(parent, rect, "", _select_slot.bind(index))
	slot_buttons.append(button)
	slot_foils.append(_foil(button))
	var title := _label(button, Rect2(2,2,rect.size.x-4,24), "", 14, MUTED)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_titles.append(title)
	var side := minf(rect.size.x-18, 62)
	slot_icons.append(_image(button, Rect2((rect.size.x-side)*0.5, (rect.size.y-side)*0.48,side,side)))
	var content := _label(button, Rect2(2,rect.size.y-43,rect.size.x-4,40), "", 14)
	content.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	slot_contents.append(content)
	if index > 0:
		var clear := _btn(parent, Rect2(rect.end.x-23,rect.position.y-10,27,27), "×", _clear_sub.bind(index-1))
		slot_clear.append(clear)

func _card(uid: int) -> Dictionary:
	for card: Dictionary in game.forge.cards:
		if int(card.uid) == uid: return card
	return {}

func _subs() -> Array:
	return sub_uids.filter(func(uid): return uid >= 0)

func _title(id: String) -> String:
	return L10n.text(str(EQUIP.get(id, {}).get("title", id)))

func _tier_name(tier: int) -> String:
	return QUALITY.tier_name(tier)

func _tier_color(tier: int) -> Color:
	return QUALITY.COLORS[clampi(tier, 0, 3)]

func _slot_uid(index: int) -> int:
	return main_uid if index == 0 else int(sub_uids[index-1])

func _assign(index: int, uid: int) -> void:
	if index == 0: main_uid = uid
	else: sub_uids[index-1] = uid

func _selection_changed(index: int) -> void:
	if result_visible:
		result_visible = false
		result_tween.kill()
		feedback.cancel_fx()
	active_slot = index
	message = ""
	_refresh(false)

func _select_slot(index: int) -> void:
	if working: return
	_selection_changed(index)
	if _slot_uid(index) >= 0: feedback.card_cue(feedback.LIFT)

func _remove_slot(index: int) -> void:
	if working: return
	_assign(index,-1)
	_selection_changed(index)

func _clear_sub(index: int) -> void:
	_remove_slot(index+1)

func _exchange(source: int, target: int) -> void:
	if working or source == target: return
	var moving := _slot_uid(source)
	if moving < 0: return
	_assign(source,_slot_uid(target))
	_assign(target,moving)
	_selection_changed(target)
	feedback.card_cue(feedback.SEAT)

func _drop_group(group: Dictionary, target: int) -> void:
	if working: return
	var current := _slot_uid(target)
	for uid: int in group.uids:
		if uid == current or (uid != main_uid and uid not in sub_uids):
			_assign(target,uid)
			_selection_changed(target)
			if uid != current: feedback.card_cue(feedback.SEAT)
			return
	# Every copy is already in a slot. Move the first one and swap any displaced card.
	for index in 3:
		if _slot_uid(index) in group.uids:
			_exchange(index,target)
			return

func _pick(group: Dictionary) -> void:
	if working: return
	var current := _slot_uid(active_slot)
	for uid: int in group.uids:
		if uid == current or (uid != main_uid and uid not in sub_uids):
			_assign(active_slot,uid)
			_selection_changed(active_slot)
			if uid != current: feedback.card_cue(feedback.TAP)
			return
	message = L10n.text("这张卡已在炉中。")
	_refresh(false)

func _attempt() -> void:
	if not visible or working or main_uid < 0: return
	var offerings := _subs()
	var plan: Dictionary = game.forge.preview(main_uid,offerings)
	if not plan.valid:
		message = plan.reason
		_refresh(false)
		return
	inputs.cancel()
	if is_instance_valid(result_tween): result_tween.kill()
	result_visible = false
	working = true
	message = ""
	_refresh(false)
	feedback.start_work()
	work_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_ignore_time_scale(true)
	work_tween.tween_method(_shake_hearth,0.0,1.5,1.5)
	work_tween.tween_callback(_resolve.bind(main_uid,offerings))

func _shake_hearth(seconds: float) -> void:
	# Three fast impacts with a damped tail. Only the furnace art moves.
	var phase := fposmod(seconds-0.10,0.50)
	var force := exp(-phase*13.0) if seconds >= 0.10 else 0.0
	hearth.position = Vector2(2,2) + Vector2(roundf(sin(phase*78.0)*5.0*force),-roundf(4.0*force))
	hearth.rotation = sin(phase*62.0)*0.035*force

func _resolve(uid: int, offerings: Array) -> void:
	if not working or not visible: return
	working = false
	hearth.position = Vector2(2,2)
	hearth.rotation = 0.0
	var result: Dictionary = game.forge.attempt(uid,offerings)
	if not result.get("ok",false):
		message = L10n.text(str(result.get("reason","")))
		_refresh(false)
		return
	message = "%s · Lv.%d" % [game.forge.outcome_label(result.outcome, not offerings.is_empty()), result.level]
	sub_uids = [-1,-1]
	has_forged = true
	active_slot = 0
	result_visible = true
	_refresh(true)
	feedback.reveal(result.outcome,_result_rect(),result.tier)
	result_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_ignore_time_scale(true)
	if result.outcome == "up":
		var peak := 1.20 if int(result.tier) >= 3 else 1.12
		_scale_result_icon(0.78)
		result_tween.tween_method(_scale_result_icon,0.78,peak,0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		result_tween.tween_method(_scale_result_icon,peak,1.0,0.19).set_trans(Tween.TRANS_SINE)
		result_tween.tween_interval(maxf(1.15,feedback.reveal_seconds(result.tier)+0.12)-0.32)
	else:
		result_tween.tween_interval(1.15)
	result_tween.tween_callback(_end_reveal)

func _scale_result_icon(factor: float) -> void:
	result_icon.pivot_offset = result_icon.size * 0.5
	result_icon.scale = Vector2.ONE * factor

func _result_rect() -> Rect2:
	var local_pos := feedback.get_global_transform().affine_inverse() * result_plate.global_position
	return Rect2(local_pos,result_plate.size)

func _end_reveal() -> void:
	result_visible = false
	_refresh(false)

func _refill_practice() -> void:
	if not visible or working or not game.forge.training: return
	game.forge.refill_practice()
	_refresh(true)

func _upgrade() -> void:
	if working: return
	if game.forge.upgrade_furnace():
		message = L10n.text("炉子已升级，成功率提高。")
	_refresh(false)

func _finish() -> void:
	if working or not visible: return
	hide()
	finished.emit()

func _refresh(rebuild_deck: bool) -> void:
	if not visible: return
	var forge: Variant = game.forge
	header_status.text = L10n.text("炉 Lv.%d  ·  金币 %d") % [forge.furnace_level, forge.wallet]
	upgrade_button.text = L10n.text("升炉  %d/%d") % [forge.materials, forge.furnace_cost()]
	upgrade_button.tooltip_text = L10n.text("消耗无尽的永恒，永久提升锻造成功率。")
	quit_button.disabled = working
	if is_instance_valid(supply_button): supply_button.disabled = working
	upgrade_button.disabled = working or forge.materials < forge.furnace_cost()
	quit_button.text = L10n.text("完成锻造") if has_forged else L10n.text("跳过")
	var card := _card(main_uid)
	for i in 3:
		slot_buttons[i].disabled = working
		if i > 0: slot_clear[i-1].disabled = working
		var assigned := card if i == 0 else _card(sub_uids[i-1])
		var tint: Color = GOLD if i == active_slot else EDGE
		slot_buttons[i].add_theme_stylebox_override("normal", _box(Color("#36302b") if i == active_slot else DARK, tint))
		_foil_tier(slot_foils[i],int(assigned.get("tier",-1)))
		slot_titles[i].text = L10n.text("主卡") if i == 0 else L10n.text("副卡 %d") % i
		if assigned.is_empty():
			slot_icons[i].texture = null
			slot_contents[i].text = L10n.text("点选") if i == 0 else L10n.text("可选")
			slot_contents[i].add_theme_color_override("font_color", MUTED)
		else:
			slot_icons[i].texture = load(EQUIP[assigned.id].icon)
			slot_contents[i].text = ("Lv.%d" % assigned.level) + " " + _title(assigned.id)
			slot_contents[i].add_theme_color_override("font_color", _tier_color(assigned.tier))
		if i > 0: slot_clear[i-1].visible = not assigned.is_empty()
	var info: Dictionary = forge.preview(main_uid, _subs()) if not card.is_empty() else {}
	_fill_preview(card, info)
	var reward: Dictionary = forge.reward_preview()
	reward_label.text = L10n.text("本关无尽的永恒 +%d   ·   装备 +%d   速度 +%d") % [reward.get("total",0),reward.get("score",0),reward.get("speed",0)]
	if reward.get("clear", 0) > 0:
		reward_label.text += L10n.text("   ·   通关另奖 +%d") % reward.clear

	inventory_hint.text = L10n.text("选主卡") if active_slot == 0 else L10n.text("选副卡 %d") % active_slot
	inventory_hint.text += L10n.text(" · 拖卡入槽，槽间可互换")
	if rebuild_deck: _build_deck()
	else: _update_fan_selection()
	for button in fan_buttons: button.disabled = working

func _fill_preview(card: Dictionary, info: Dictionary) -> void:
	var has_main := not card.is_empty()
	var pane_width: float = result_plate.get_parent().size.x
	result_plate.visible = result_visible and has_main
	if result_plate.visible:
		var tier: int = card.tier
		result_plate.add_theme_stylebox_override("panel",_box(DARK,_tier_color(tier)))
		_foil_tier(result_foil,tier)
		result_icon.position = Vector2(25,62)
		result_icon.size = Vector2(56,56)
		result_title.position.x = 108
		result_title.size.x = pane_width-116
		details_scroll.position.x = 108
		details_scroll.size.x = pane_width-120
	else:
		result_icon.scale = Vector2.ONE
		result_icon.position = Vector2(11,36) if portrait else Vector2(13,37)
		result_icon.size = Vector2(48,48) if portrait else Vector2(58,58)
		result_title.position.x = 68
		result_title.size.x = pane_width-76
		details_scroll.position.x = 12
		details_scroll.size.x = pane_width-24
	outcome_label.add_theme_color_override("font_color", MUTED)
	preview_heading.text = L10n.text("锻造结果") if result_visible else L10n.text("锻造预览")
	action_button.disabled = working or not info.get("valid", false)
	action_button.text = L10n.text("开始锻造 · %d 金币") % int(info.get("cost",0)) if has_main else L10n.text("开始锻造")
	if working: action_button.text = L10n.text("锻造中…")
	if result_visible and has_main:
		result_icon.texture = load(EQUIP[card.id].icon)
		result_title.text = ("Lv.%d" % card.level) + "   " + _title(card.id)
		result_title.add_theme_color_override("font_color",_tier_color(card.tier))
		odds_label.text = ""
		changes_label.text = message
		changes_label.tooltip_text = message
		outcome_label.text = message
		outcome_label.tooltip_text = message
		return
	if not has_main:
		result_icon.texture = null
		result_title.text = L10n.text("从下方选一张主卡")
		result_title.add_theme_color_override("font_color", PAPER)
		odds_label.text = ""
		changes_label.text = ""
		outcome_label.text = message
		return
	result_icon.texture = load(EQUIP[card.id].icon)
	result_title.text = "%s   Lv.%d" % [_title(card.id),card.level]
	result_title.add_theme_color_override("font_color",_tier_color(card.tier))
	odds_label.text = "+1 %.1f%%   = %.1f%%   −1 %.1f%%" % [info.get("up",0),info.get("stay",0),info.get("down",0)]
	changes_label.text = str(info.get("changes", ""))
	changes_label.tooltip_text = changes_label.text
	var reason := str(info.get("reason",""))
	outcome_label.text = L10n.text(reason) if not reason.is_empty() else message
	var warnings: PackedStringArray = info.get("warnings", PackedStringArray())
	if reason.is_empty() and not warnings.is_empty():
		outcome_label.text = warnings[0]
		outcome_label.add_theme_color_override("font_color", Color("#ffc390"))
	if outcome_label.text.is_empty():
		outcome_label.text = L10n.text("装备评分 %d") % info.get("score_before",0)
		if not _subs().is_empty():
			outcome_label.text += " · " + L10n.text("副卡技能将全部消耗")
	outcome_label.tooltip_text = "\n".join(warnings) if not warnings.is_empty() else outcome_label.text

func _build_deck() -> void:
	inputs.clear_light()
	if deck.get_child_count() > 0:
		inventory_offset = inventory_scroll.scroll_horizontal
	for child in deck.get_children():
		deck.remove_child(child)
		child.queue_free()
	fan_buttons.clear()
	groups.clear()
	var by_kind := {}
	for card: Dictionary in game.forge.cards:
		var key := "%s/%d" % [card.id,card.tier]
		if not by_kind.has(key):
			by_kind[key] = groups.size()
			groups.append({"id":card.id,"tier":card.tier,"level":card.level,"uids":[]})
		groups[int(by_kind[key])].uids.append(card.uid)
	var count := groups.size()
	var card_w := 94.0 if portrait else 102.0
	var card_h := 106.0 if portrait else 109.0
	var visible_width := inventory_scroll.size.x
	var step := clampf((visible_width-card_w-26)/maxi(count-1,1), card_w*0.68, card_w+8)
	var total := (count-1)*step + card_w
	var start := maxf(12, (visible_width-total)*0.5)
	deck.custom_minimum_size = Vector2(maxf(visible_width-1, total+26), card_h+28)
	for i in count:
		var group: Dictionary = groups[i]
		var t := (float(i)/maxi(count-1,1)-0.5)*2.0 if count > 1 else 0.0
		var button := _btn(deck, Rect2(start+i*step,5+absf(t)*9,card_w,card_h), "", _pick.bind(group))
		button.mouse_filter = Control.MOUSE_FILTER_PASS
		button.pivot_offset = Vector2(card_w*0.5,card_h)
		button.rotation = deg_to_rad(t*4.5)
		button.tooltip_text = ("Lv.%d" % group.level)+" "+_title(group.id)
		# Keep the hit rectangle still while its visible face lifts toward the light.
		var face := _panel(button,Rect2(Vector2.ZERO,button.size))
		face.name = "CardFace"
		face.pivot_offset = button.size * 0.5
		if group.tier >= 2: _foil_tier(_foil(face),group.tier)
		var top := _label(face, Rect2(5,1,card_w-10,22), ("Lv.%d" % group.level), 13, _tier_color(group.tier), true)
		top.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		if group.uids.size() > 1:
			var copies := _label(face, Rect2(card_w-40,1,34,22), "×%d"%group.uids.size(), 13)
			copies.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_image(face, Rect2((card_w-44)*0.5,23,44,44), load(EQUIP[group.id].icon))
		var name_label := _label(face, Rect2(3,69,card_w-6,37), _title(group.id), 14, PAPER, true)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fan_buttons.append(button)
	_update_fan_selection()
	inventory_scroll.set_deferred("scroll_horizontal", inventory_offset)

func _update_fan_selection() -> void:
	for i in fan_buttons.size():
		var group: Dictionary = groups[i]
		var chosen: bool = main_uid in group.uids
		for uid in sub_uids:
			if uid in group.uids: chosen = true
		var rim := _tier_color(group.tier)
		var fill := Color("#453c32") if chosen else Color("#242c36")
		var style := _box(fill, rim, 4 if chosen else 2)
		fan_buttons[i].get_node("CardFace").add_theme_stylebox_override("panel",style)

func _scroll_deck(direction: int) -> void:
	inventory_scroll.scroll_horizontal += direction * int(inventory_scroll.size.x * 0.67)
	inventory_offset = inventory_scroll.scroll_horizontal
