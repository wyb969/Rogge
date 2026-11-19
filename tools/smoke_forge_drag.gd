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
	ui = main.game.forge_screen
	var forge: Variant = main.game.forge
	var first: int = ui.groups[0].uids[0]
	var second: int = ui.groups[1].uids[0]
	drag(spot(0),slot(0))
	expect(ui.main_uid == first,"mouse deck to main")
	drag(spot(1),slot(1),true)
	expect(ui.sub_uids[0] == second,"touch deck to offering")
	drag(slot(1),slot(0))
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
