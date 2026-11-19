extends Node

# A deck card starts as a tap. Horizontal motion pans the fan; upward motion lifts it.
const IDLE := -3
const MOUSE := -2
const DECK := -1
const NO_TARGET := -2
const DEADZONE := 10.0
const OPEN_HAND := preload("res://rogge_art/environment-ui/forge/hand-open.png")
const GRIP_HAND := preload("res://rogge_art/environment-ui/forge/hand-grip.png")
const HAND_HOTSPOT := Vector2(10,8)

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
var owns_cursor := false
var hand_closed := false
var light := ColorRect.new()
var light_material := ShaderMaterial.new()
var tilted_face: Control

func _ready() -> void:
	forge = get_parent()
	light_material.shader = preload("res://shaders/forge_card_glint.gdshader")
	light.material = light_material
	light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	light.hide()
	add_child(light)
	get_window().mouse_exited.connect(clear_light)

func clear_light() -> void:
	if is_instance_valid(tilted_face):
		tilted_face.scale = Vector2.ONE
		tilted_face.rotation = 0
		tilted_face.position = Vector2.ZERO
	tilted_face = null
	if light.get_parent() != self:
		light.reparent(self,false)
	light.hide()

func _light_card(surface: Control, tilt: Vector2, lift_face := false) -> void:
	if light.get_parent() != surface:
		clear_light()
		light.reparent(surface,false)
		light.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		light.show()
	if lift_face:
		tilted_face = surface
		surface.rotation = tilt.x * 0.075
		surface.scale = Vector2(1.035 - absf(tilt.x)*0.035, 1.03 - absf(tilt.y)*0.025)
		surface.position = Vector2(tilt.x*2, -3 + tilt.y*1.5)
	light_material.set_shader_parameter("tilt",tilt)

func _hover(point: Vector2) -> void:
	var button: Button
	var slot := _slot_at(point)
	if slot >= 0 and forge._slot_uid(slot) >= 0:
		button = forge.slot_buttons[slot]
	else:
		var index := _fan_index_at(point)
		if index >= 0: button = forge.fan_buttons[index]
	if button == null:
		clear_light()
		return
	var tilt := (button.make_canvas_position_local(point)/button.size*2.0-Vector2.ONE).clamp(-Vector2.ONE,Vector2.ONE)
	var face := button.get_node_or_null("CardFace") as Control
	_light_card(face if face else button,tilt,face != null)

func _menu_visible() -> bool:
	var host := get_tree().current_scene
	return is_instance_valid(host) and "session_menu" in host and is_instance_valid(host.session_menu) and host.session_menu.visible

func sync_cursor() -> void:
	if forge.visible and not _menu_visible():
		if not owns_cursor:
			owns_cursor = true
			_show_hand(false)
	else:
		cancel()
		_restore_cursor()

func _show_hand(closed: bool) -> void:
	hand_closed = closed
	if owns_cursor:
		Input.set_custom_mouse_cursor(GRIP_HAND if closed else OPEN_HAND,Input.CURSOR_ARROW,HAND_HOTSPOT)

func _restore_cursor() -> void:
	if not owns_cursor: return
	owns_cursor = false
	hand_closed = false
	var path: String = ProjectSettings.get_setting("display/mouse_cursor/custom_image","")
	var hotspot: Vector2 = ProjectSettings.get_setting("display/mouse_cursor/custom_image_hotspot",Vector2.ZERO)
	Input.set_custom_mouse_cursor(load(path) if not path.is_empty() else null,Input.CURSOR_ARROW,hotspot)

func _exit_tree() -> void:
	_restore_cursor()

func cancel() -> void:
	clear_light()
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
	if hand_closed: _show_hand(false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready():
		cancel()

func _inside(control: Control, point: Vector2) -> bool:
	return is_instance_valid(control) and control.is_visible_in_tree() and Rect2(Vector2.ZERO,control.size).has_point(control.make_canvas_position_local(point))

func _slot_at(point: Vector2) -> int:
	for i in forge.slot_buttons.size():
		if _inside(forge.slot_buttons[i],point): return i
	return NO_TARGET

func _group_at(point: Vector2) -> Dictionary:
	var index := _fan_index_at(point)
	return {} if index < 0 else forge.groups[index]

func _fan_index_at(point: Vector2) -> int:
	if not _inside(forge.inventory_scroll,point): return -1
	if _inside(forge.inventory_scroll.get_h_scroll_bar(),point): return -1
	for i in range(forge.fan_buttons.size()-1,-1,-1):
		if _inside(forge.fan_buttons[i],point): return i
	return -1

func _source_at(point: Vector2) -> bool:
	for clear_button in forge.slot_clear:
		if _inside(clear_button,point): return false
	return _slot_at(point) >= 0 or not _group_at(point).is_empty()

func _input(event: InputEvent) -> void:
	if not forge.visible: return
	if _menu_visible():
		if pointer != IDLE: cancel()
		return
	if event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and event.button_index == MOUSE_BUTTON_LEFT:
		_show_hand(event.pressed and not event.canceled)
	if event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION and hand_closed and not (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		# A mouse-up outside the canvas can be missed by Web.
		if pointer == MOUSE: cancel()
		else: _show_hand(false)
	if forge.working: return
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
	if pointer == IDLE and (event is InputEventMouseMotion or event is InputEventScreenTouch or event is InputEventMouseButton):
		_hover(point)
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
			if id == MOUSE: _hover(point)
		elif pointer == IDLE: return
	elif id == pointer:
		_move(point)
	elif pointer == IDLE: return
	get_viewport().set_input_as_handled()

func _move(point: Vector2) -> void:
	var delta: Vector2 = (point-origin) / forge.board.scale.x
	# A horizontal swipe may become a deliberate lift. Keep the original card under the finger.
	var above_fan: bool = forge.inventory_scroll.make_canvas_position_local(point).y < -DEADZONE
	if panning and above_fan:
		panning = false
		forge.inventory_scroll.scroll_horizontal = initial_scroll
	if not dragging and not panning:
		if delta.length() < DEADZONE: return
		if pointer != MOUSE and origin_slot == DECK and not above_fan and absf(delta.x) > 1.2 * absf(delta.y):
			panning = true
			clear_light()
		else:
			var uid: int = forge._slot_uid(origin_slot) if origin_slot >= 0 else source_group.uids[0]
			var card: Dictionary = forge._card(uid)
			if card.is_empty(): return
			dragging = true
			if origin_slot == DECK: forge.feedback.card_cue(forge.feedback.LIFT)
			ghost = forge._panel(forge.board,Rect2(0,0,72,84),Color("#30323bf0"),forge._tier_color(card.tier))
			ghost.z_index = 15
			forge._image(ghost,Rect2(12,5,48,48),load(forge.EQUIP[card.id].icon))
			var title: Label = forge._label(ghost,Rect2(2,54,68,24),forge._title(card.id),14,forge._tier_color(card.tier),true)
			title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if panning:
		forge.inventory_scroll.scroll_horizontal = initial_scroll-roundi(delta.x)
		return
	ghost.position = forge.board.make_canvas_position_local(point)-Vector2(36,66)
	var tilt := (delta/140.0).clamp(-Vector2.ONE,Vector2.ONE)
	ghost.pivot_offset = Vector2(36,66)
	ghost.rotation = tilt.x * 0.09
	_light_card(ghost,tilt)
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
