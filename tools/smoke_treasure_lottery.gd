extends SceneTree
var failures: Array[String] = []
const LOTTERY: = preload("res://script/treasure_lottery.gd")

func _init() -> void :
	call_deferred("_run")

func _expect(ok: bool, message: String) -> void :
	if not ok:
		failures.append(message)

func _run() -> void :
	var distribution: = {1: 0, 2: 0, 3: 0}
	for roll in 100:
		distribution[LOTTERY.bonus_for_roll(roll)] += 1
	_expect(distribution == {1: 5, 2: 80, 3: 15}, "exact 5/80/15 probability intervals")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	main.get_node("mainUI/Control/MenuCenter/VBoxContainer/DebugButton").pressed.emit()
	main._launch_run(&"treasure")
	await process_frame
	await process_frame
	var game: Node = main.game
	var spawner: Node = game.spawner
	var player: Node = game.player
	for name in ["HandWeapon", "CircleWeapon", "Weapon", "DroneController", "MolotovController", "FreezeController"]:
		game.get_node(name).process_mode = Node.PROCESS_MODE_DISABLED
	player.set_physics_process(false)
	spawner.timer.stop()
	spawner.get_node("Elite").stop()
	spawner.set_process(false)
	_expect(spawner.stage == 3 and not paused, "legacy treasure preset starts stage three")
	_expect(get_nodes_in_group("treasure_guardian").size() == 1, "exactly one guardian spawns")
	var guardian: Node = get_nodes_in_group("treasure_guardian")[0]
	guardian.set_physics_process(false)
	_expect(guardian.health >= 240 and guardian.health <= 720 and guardian.body_scale == 1.85, "guardian is bigger and tougher but far below a stage boss")
	_expect(spawner.spawn_treasure_guardian() == null, "cannot spawn twice")
	guardian.global_position = Vector2.ZERO
	player.global_position = Vector2(50, 0)
	guardian.attack_left = 0.0
	guardian.contact_timer = 10.0
	guardian._physics_process(0.01)
	var hp: float = player.player_health
	guardian._physics_process(0.4)
	_expect(player.player_health == hp and guardian.warning_left > 0.0, "red slam warning is harmless")
	player.hurt_lock = 0.0
	guardian._physics_process(0.5)
	_expect(player.player_health < hp and guardian.impact_left > 0.0, "warned circle deals actual damage")
	hp = player.player_health
	guardian._physics_process(0.05)
	_expect(player.player_health == hp, "slam cannot hit twice")

	guardian.global_position = Vector2(5000, 5000)
	spawner.remove_far_enemy()
	_expect( not guardian.is_queued_for_deletion(), "running far away cannot despawn the guardian")

	game.on_level_up(7)
	_expect(game.pause_menu.visible and paused, "ordinary level-up opens first")
	guardian.take_damage(1000000)
	guardian.take_damage(1000000)
	await process_frame
	_expect(spawner._mini_cleared and game._lottery_pending and not is_instance_valid(game.treasure_lottery), "death awards one queued chest without overlapping level-up")
	game.pause_menu.on_card_selected("monster_necklace")
	await process_frame
	await process_frame
	var lottery: Node = game.treasure_lottery
	_expect(is_instance_valid(lottery) and lottery.visible and paused, "chest opens after level selection and pauses combat")
	_expect( not game.pause_menu.visible and not game._lottery_pending, "no overlapping reward menus")
	lottery.set_process(false)
	var chosen_id: = str(lottery.reward.id)
	var chosen_bonus: int = lottery.bonus_levels
	var before: int = game.equipment_panel.get_level(chosen_id)
	lottery._button.pressed.emit()
	lottery._button.pressed.emit()
	_expect(lottery.spinning and lottery._button.disabled, "spin button cannot double spin")
	for i in 31:
		lottery._process(0.1)
	_expect(lottery.revealed and not lottery.spinning and str(lottery.reward.id) == chosen_id and lottery.bonus_levels == chosen_bonus, "animation reveals the original draw without reroll")
	_expect(game.equipment_panel.get_level(chosen_id) == before, "no stats granted until claim")
	_expect(lottery._burst.strength == chosen_bonus, "gold rays and sparkle density increase with prize tier")
	for reel in lottery._reels:
		_expect(reel.texture.resource_path == str(lottery.reward.icon), "all three reels stop on the reward card")
	for size in [Vector2i(390, 844), Vector2i(900, 500)]:
		root.size = size
		await process_frame
		await process_frame
		var bounds: = Rect2(Vector2.ZERO, root.get_visible_rect().size)
		_expect(bounds.encloses(lottery._panel.get_global_rect()), "lottery panel fits %s" % size)
		_expect(bounds.encloses(lottery._button.get_global_rect()), "claim fits %s" % size)
	lottery._button.pressed.emit()
	lottery._button.pressed.emit()
	_expect(game.equipment_panel.get_level(chosen_id) == before + chosen_bonus, "claim grants exactly N real upgrade levels once")
	_expect( not paused and not lottery.visible, "claim resumes combat")

	var necklace_data: Dictionary
	for card in game.pause_menu.upgrade_pool:
		if card.id == "monster_necklace":
			necklace_data = card
	for tier in [1, 2, 3]:
		var old: int = player.monster_necklace_level
		lottery.open_lottery([necklace_data], game.equipment_panel)
		lottery.bonus_levels = tier
		lottery._reveal()
		lottery._button.pressed.emit()
		_expect(player.monster_necklace_level == old + tier, "tier %d changes the actual necklace stat" % tier)
		_expect(player.monster_necklace_heal_for(player.monster_necklace_level) == (old + tier) * 5, "healing scales for tier %d" % tier)

	lottery.open_lottery([necklace_data], game.equipment_panel)
	game.on_level_up(8)
	_expect( not game.pause_menu.visible, "lottery defers a later level-up")
	lottery._reveal()
	lottery._button.pressed.emit()
	await process_frame
	_expect(game.pause_menu.visible and paused, "queued level-up opens after claim")
	game.pause_menu.on_card_selected("monster_necklace")
	await process_frame

	spawner.stage = 2
	spawner._rest_open = false
	spawner._boss_fight_active = true
	spawner._on_boss_defeated()
	await process_frame
	_expect(game.rest_hub.visible and paused, "second-stage clear now opens rest instead of victory")
	game.rest_hub._on_reward_pressed("max_hp")
	game.rest_hub._on_next_pressed()
	await create_timer(1.25).timeout
	_expect(spawner.stage == 3 and not paused and spawner.stage_boss_countdown > 0, "rest Next enters stage three with normal pressure and a final timer")

	spawner._mini_spawned = false
	spawner._mini_cleared = false
	spawner._mini_countdown = 0.1
	spawner._process(0.04)
	_expect(get_nodes_in_group("treasure_guardian").is_empty(), "guardian does not spawn before its mid-stage timer")
	spawner._process(0.07)
	_expect(get_nodes_in_group("treasure_guardian").size() == 1, "normal third-stage timer spawns the guardian")
	spawner.stage_boss_countdown = 0.05
	spawner._process(0.1)
	_expect( not spawner._boss_fight_active, "final boss waits if the guardian has not been defeated")
	var second_guardian: Node = get_nodes_in_group("treasure_guardian")[0]
	second_guardian.take_damage(1000000)
	await process_frame
	await process_frame
	lottery._reveal()
	lottery._button.pressed.emit()
	await process_frame

	var result: = {"victory": false}
	game.game_over.connect( func(stats: Dictionary): result.victory = stats.get("victory", false))
	spawner._on_boss_defeated()
	await process_frame
	await process_frame
	_expect( not result.victory and game.beast_powers._pending_reward == 3, "third-stage clear opens an earned blessing before settlement")
	game.beast_powers.reward_claim.pressed.emit()
	_expect(game.beast_powers.unlocked.has(0), "stage-three blessing unlocks the healing power")
	if failures.is_empty():
		print("TREASURE LOTTERY OK: third stage, real mini-boss, safe warning, one reward, probability intervals, actual stacked stats, pause ordering, responsive UI and victory")
	else:
		for failure in failures:
			push_error(failure)
	paused = false
	quit(0 if failures.is_empty() else 1)
