extends SceneTree

var checks := 0
var errors := 0
var ui: CanvasLayer

func _init() -> void: call_deferred("run")

func expect(value: bool, description: String) -> void:
	checks += 1
	if not value:
		push_error(description)
		errors += 1

func frames(count: int) -> void:
	for i in count: await process_frame

func press(point: Vector2, down: bool, touch := false, canceled := false) -> void:
	var event: InputEvent
	if touch:
		event = InputEventScreenTouch.new()
		event.index = 0
	else:
		event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.pressed = down
	event.canceled = canceled
	root.push_input(event,true)

func move(point: Vector2, touch: bool) -> void:
	var event: InputEvent
	if touch:
		event = InputEventScreenDrag.new()
		event.index = 0
	else:
		event = InputEventMouseMotion.new()
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.position = point
	root.push_input(event,true)

func drag(source: Vector2, target: Vector2, touch := false) -> void:
	press(source,true,touch)
	move(source+Vector2(0,-20),touch)
	move(target,touch)
	press(target,false,touch)

func spot(index: int) -> Vector2:
	var button: Button = ui.fan_buttons[index]
	return button.get_global_transform() * (button.size * Vector2(0.32,0.47))

func slot(index: int) -> Vector2:
	return ui.slot_buttons[index].get_global_rect().get_center()

func run() -> void:
	root.size = Vector2i(900,600)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await frames(6)
	main.find_child("DebugButton").pressed.emit()
	main.find_child("DebugForgeButton").pressed.emit()
	await frames(25)
	var audio := root.get_node("AudioManager")
	expect(audio._desired_bgm == audio.BgmKind.FORGE and audio.boss_audio_player.playing, "practice uses the same forge score")
	ui = main.game.forge_screen
	var forge: Variant = main.game.forge
	# Web enables the combat joystick even when the user plays with a mouse.
	ui.hide()
	main.mobile_controls.visible = true
	root.get_node("MobileInput").controls_enabled = true
	main.mobile_controls._layout_controls()
	var left_card := spot(0)
	expect(main.mobile_controls._near_stick_zone(left_card),"leftmost card overlaps the combat joystick capture zone")
	ui.open_for(main.game)
	await frames(3)
	expect(not main.mobile_controls.visible and not root.get_node("MobileInput").controls_enabled,"forge owns input above combat controls")
	var inputs: Node = ui.inputs
	expect(inputs.owns_cursor and not inputs.hand_closed,"forge opens with an open hand")
	var first: int = ui.groups[0].uids[0]
	var second: int = ui.groups[1].uids[0]
	var fx: Control = ui.feedback
	move(spot(0),false)
	var face: Control = ui.fan_buttons[0].get_node("CardFace")
	expect(inputs.light.visible and inputs.light.get_parent() == face and face.rotation != 0.0,"hover lights and tilts the first card")
	var tilt: Vector2 = inputs.light_material.get_shader_parameter("tilt")
	move(spot(0)+Vector2(15,4),false)
	expect(tilt != inputs.light_material.get_shader_parameter("tilt"),"light follows pointer position on the same card")
	move(Vector2.ZERO,false)
	expect(not inputs.light.visible and face.rotation == 0.0,"leaving returns the face to rest")
	for tier in [1,2,3]:
		fx.reveal("up",Rect2(0,0,80,100),tier)
		var seconds: float = [2.04,2.52,3.30][tier-1]
		expect(absf(fx._duration-seconds)<0.01 and is_equal_approx(fx._duration,fx._voice.stream.get_length()),"success timing matches its doubled chime")
	for outcome in ["down","stay"]:
		fx.reveal(outcome,Rect2(),1)
		expect(fx._voice.playing and fx._voice.stream == (fx.DOWNGRADE if outcome=="down" else fx.HOLD),"unsuccessful outcomes each sound")
	fx.cancel_fx()
	press(spot(0),true)
	press(spot(0),false)
	expect(fx._card_voice.stream == fx.TAP and ui.main_uid == first,"tap-to-seat plays its combined cue")
	ui._remove_slot(0)
	for i in 3:
		var source := spot(0)
		press(source,true)
		expect(inputs.hand_closed and inputs.pointer == inputs.MOUSE,"leftmost mouse-down closes hand on the card")
		move(source.lerp(slot(i),0.45),false)
		press(slot(i),false)
		expect(ui._slot_uid(i) == first and not inputs.hand_closed,"release assigns leftmost card to any slot and opens hand")
		ui._remove_slot(i)
		press(source,true,true)
		move(source+Vector2(24,-2),true)
		move(slot(i),true)
		press(slot(i),false,true)
		expect(ui._slot_uid(i) == first and not inputs.hand_closed,"shallow swipe then lift still carries the original first card")
		ui._remove_slot(i)
	press(spot(0),true)
	inputs._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	expect(inputs.pointer == inputs.IDLE and not inputs.hand_closed,"focus loss cancels grip")
	press(spot(0),false)
	main.session_menu.open_menu()
	expect(not inputs.owns_cursor,"pause menu releases forge cursor")
	main.session_menu.close_menu()
	expect(inputs.owns_cursor and not inputs.hand_closed,"returning to forge restores the open hand")
	drag(spot(0),slot(0))
	expect(ui.main_uid == first,"mouse deck to main")
	drag(spot(1),slot(1),true)
	expect(ui.sub_uids[0] == second,"touch deck to offering")
	var prior_cue = fx._card_voice.get_stream_playback()
	press(slot(1),true)
	move(slot(1)+Vector2(0,20),false)
	expect(fx._card_voice.get_stream_playback() == prior_cue,"starting a slot transfer emits no extra pickup")
	move(slot(0),false)
	press(slot(0),false)
	expect(fx._card_voice.stream == fx.SEAT and fx._card_voice.get_stream_playback() != prior_cue,"exchange plays one new seating sound")
	expect(ui.main_uid == second and ui.sub_uids[0] == first,"occupied slot exchange")
	drag(slot(1),slot(2),true)
	expect(ui.sub_uids == [-1,first],"touch move to empty slot")
	drag(slot(0),spot(0))
	expect(ui.main_uid == -1 and forge.cards.size() == 9,"return from main to fan keeps ownership")
	drag(slot(2),slot(0))
	drag(spot(1),slot(1))
	var offered: int = ui.sub_uids[0]
	drag(slot(0),Vector2.ZERO,true)
	expect(ui.main_uid == first and ui.sub_uids[0] == offered,"outside drop cancels")
	press(slot(0),true,true)
	move(slot(2),true)
	press(slot(2),false,true,true)
	expect(ui.main_uid == first and ui.sub_uids[1] == -1,"touch cancellation rolls back")
	root.size = Vector2i(390,844)
	await frames(8)
	var start := spot(1)
	press(start,true,true)
	move(start-Vector2(73,2),true)
	press(start-Vector2(93,2),false,true)
	expect(ui.inventory_scroll.scroll_horizontal > 0 and ui.main_uid == first and ui.sub_uids[0] == offered,"horizontal swipe scrolls without moving cards")
	var cost: int = forge.preview(first,[offered]).cost
	var wallet: int = forge.wallet
	var level: int = forge.furnace_level
	ui.action_button.pressed.emit()
	ui._attempt()
	ui._upgrade()
	ui.supply_button.pressed.emit()
	ui._finish()
	drag(slot(1),slot(0))
	expect(ui.working and ui.visible and ui.quit_button.disabled and ui.action_button.disabled,"all mutation and exit paths lock")
	expect(ui.main_uid == first and ui.sub_uids[0] == offered and forge.furnace_level == level,"locked inputs preserve the quoted attempt")
	await create_timer(0.72,true,false,true).timeout
	expect(ui.working and forge.wallet == wallet and forge.cards.size() == 9,"materials are intact mid-forge")
	root.size = Vector2i(844,390)
	await create_timer(0.84,true,false,true).timeout
	expect(not ui.working and forge.wallet == wallet-cost and forge.cards.size() == 8,"one settlement after 1.5s, including resize")
	expect(ui.result_visible and ui.result_title.text.contains(ui._tier_name(ui._card(first).tier)),"display actual forged card")
	expect(ui.sub_uids == [-1,-1] and not ui.action_button.disabled and not ui.quit_button.disabled,"controls restored")
	ui._attempt()
	ui.hide()
	expect(not inputs.owns_cursor,"leaving forge restores project cursor")
	await create_timer(1.6,true,false,true).timeout
	expect(forge.wallet == wallet-cost and forge.cards.size() == 8,"hiding cancels outstanding work")
	ui.show()
	var balance: int = forge.wallet
	var income: int = forge.stage_income
	var original: int = forge.cards.size()
	var offer_price: int = forge.preview(first,[]).cost
	for size in [Vector2i(390,844),Vector2i(844,390)]:
		root.size = size
		await frames(5)
		var point: Vector2 = ui.supply_button.get_global_rect().get_center()
		expect(root.get_visible_rect().has_point(point) and not ui.quit_button.get_global_rect().has_point(point),"refill has its own reachable space")
		press(point,true)
		press(point,false)
	expect(forge.wallet == balance+1200 and forge.cards.size() == original+12,"both button presses grant fresh gold and cards")
	var tiers := [0,0,0,0]
	for card in forge.cards.slice(original): tiers[card.tier] += 1
	expect(tiers == [4,4,4,0],"each supply has two cards of each non-orange quality")
	expect(forge.stage_income == income and forge.preview(first,[]).cost == offer_price and ui.main_uid == first,"top-ups preserve the quote and main card")
	if errors == 0: print("FORGE GESTURES OK: %d checks" % checks)
	quit(int(errors > 0))
