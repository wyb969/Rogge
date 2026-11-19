extends Node

# A deck card starts as a tap. Horizontal motion pans the fan; upward motion lifts it.
const IDLE := -3
const MOUSE := -2
const DECK := -1
const NO_TARGET := -2
const DEADZONE := 10.0

var forge: CanvasLayer
var pointer := IDLE
var origin_slot := DECK
var source_group: Dictionary = {}
var origin := Vector2.ZERO
var initial_scroll := 0
var dragging := false
var panning := false
var ghost: Panel
var outline: Panel
var target_slot := NO_TARGET

func _ready() -> void:
	forge = get_parent()

func cancel() -> void:
	for control in [ghost, outline]:
		if is_instance_valid(control):
			control.hide()
			control.queue_free()
	ghost = null
	outline = null
	pointer = IDLE
	source_group = {}
	dragging = false
	panning = false
	target_slot = NO_TARGET

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and pointer != IDLE:
		cancel()

func _inside(control: Control, point: Vector2) -> bool:
	return is_instance_valid(control) and control.is_visible_in_tree() and Rect2(Vector2.ZERO,control.size).has_point(control.make_canvas_position_local(point))

func _slot_at(point: Vector2) -> int:
	for i in forge.slot_buttons.size():
		if _inside(forge.slot_buttons[i],point): return i
	return NO_TARGET

func _group_at(point: Vector2) -> Dictionary:
	if not _inside(forge.inventory_scroll,point): return {}
	if _inside(forge.inventory_scroll.get_h_scroll_bar(),point): return {}
	for i in range(forge.fan_buttons.size()-1,-1,-1):
		if _inside(forge.fan_buttons[i],point): return forge.groups[i]
	return {}

func _source_at(point: Vector2) -> bool:
	for clear_button in forge.slot_clear:
		if _inside(clear_button,point): return false
	return _slot_at(point) >= 0 or not _group_at(point).is_empty()

func _input(event: InputEvent) -> void:
	if not forge.visible or forge.working: return
	var host := get_tree().current_scene
	if is_instance_valid(host) and host.get("session_menu") != null and host.session_menu.active:
		if pointer != IDLE: cancel()
		return
	if event is InputEventKey:
		if event.keycode == KEY_ESCAPE and event.pressed and pointer != IDLE:
			cancel()
			get_viewport().set_input_as_handled()
		return
	if not (event is InputEventMouseButton or event is InputEventMouseMotion or event is InputEventScreenTouch or event is InputEventScreenDrag): return
	var point: Vector2 = event.position
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		if pointer != IDLE or _source_at(point): get_viewport().set_input_as_handled()
		return
	var id := MOUSE
	if event is InputEventScreenTouch or event is InputEventScreenDrag: id = event.index
	if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT: return
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.canceled and id == pointer:
			cancel()
		elif event.pressed and pointer == IDLE:
			if not _source_at(point): return
			origin_slot = _slot_at(point)
			source_group = _group_at(point)
			if origin_slot < 0: origin_slot = DECK
			pointer = id
			origin = point
			initial_scroll = forge.inventory_scroll.scroll_horizontal
		elif not event.pressed and id == pointer:
			_move(point)
			if dragging: _drop(point)
			elif not panning and _source_at(point):
				if origin_slot >= 0 and _slot_at(point) == origin_slot: forge._select_slot(origin_slot)
				elif origin_slot == DECK and _group_at(point) == source_group: forge._pick(source_group)
			cancel()
		elif pointer == IDLE: return
	elif id == pointer:
		_move(point)
	elif pointer == IDLE: return
	get_viewport().set_input_as_handled()

func _move(point: Vector2) -> void:
	var delta: Vector2 = (point-origin) / forge.board.scale.x
	if not dragging and not panning:
		if delta.length() < DEADZONE: return
		if pointer != MOUSE and origin_slot == DECK and absf(delta.x) > 1.2 * absf(delta.y):
			panning = true
		else:
			var uid: int = forge._slot_uid(origin_slot) if origin_slot >= 0 else source_group.uids[0]
			var card: Dictionary = forge._card(uid)
			if card.is_empty(): return
			dragging = true
			ghost = forge._panel(forge.board,Rect2(0,0,72,84),Color("#30323bf0"),forge._tier_color(card.tier))
			ghost.z_index = 15
			forge._image(ghost,Rect2(12,5,48,48),load(forge.EQUIP[card.id].icon))
			var title: Label = forge._label(ghost,Rect2(2,54,68,24),forge._title(card.id),14,forge._tier_color(card.tier),true)
			title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if panning:
		forge.inventory_scroll.scroll_horizontal = initial_scroll-roundi(delta.x)
		return
	ghost.position = forge.board.make_canvas_position_local(point)-Vector2(36,66)
	var target := _slot_at(point)
	if target == target_slot: return
	target_slot = target
	if is_instance_valid(outline):
		outline.hide()
		outline.queue_free()
		outline = null
	if target >= 0:
		var slot: Button = forge.slot_buttons[target]
		outline = forge._panel(slot,Rect2(Vector2.ZERO,slot.size),Color("#ffc86b19"),Color("#ffcf75"))
		outline.z_index = 3

func _drop(point: Vector2) -> void:
	var target := _slot_at(point)
	if target >= 0:
		if origin_slot >= 0: forge._exchange(origin_slot,target)
		else: forge._drop_group(source_group,target)
	elif origin_slot >= 0 and _inside(forge.inventory_scroll,point):
		forge._remove_slot(origin_slot)
