extends SceneTree
var failures: Array[String] = []
var game: Node
var player: Node
var spawner: Node
var entry: Dictionary

func _init() -> void :
	call_deferred("_run")

func _run() -> void :
	game = load("res://scenes/game.tscn").instantiate()
	game.add_to_group("game")
	root.add_child(game)
	current_scene = game
	await process_frame


	game.level_manager.signal_level_up.disconnect(game.on_level_up)
	player = game.player
	spawner = game.spawner
	spawner.timer.stop()
	spawner.get_node("Elite").stop()
	player.set_physics_process(false)
	player.set_process(false)
	for name in ["HandWeapon", "CircleWeapon", "Weapon", "DroneController", "MolotovController", "FreezeController"]:
		game.get_node(name).process_mode = Node.PROCESS_MODE_DISABLED
	for candidate in game.pause_menu.upgrade_pool:
		if candidate["id"] == "monster_necklace":
			entry = candidate
	_expect( not entry.is_empty(), "new card is in normal upgrade pool")
	_expect(game.equipment_panel.EQUIP_DEFS.has("monster_necklace"), "equipment slot definition exists")
	if entry.is_empty():
		quit(1)
		return

	_kill_at(Vector2(400, 0), false)
	_expect(_orbs().is_empty(), "no item means no healing drop")
	_select_card(5)
	_expect(player.monster_necklace_level == 1 and game.equipment_panel.get_level("monster_necklace") == 1, "first card unlocks the item and equipment slot")
	_expect(spawner._offense_cards == 0, "support card does not increase enemy offense-card pressure")

	player.player_health = 100.0
	var before_kills: int = spawner.enemy_killed_num
	_kill_at(Vector2(400, 0), true)
	_expect(spawner.enemy_killed_num == before_kills + 1, "multiple same-frame lethal hits count once")
	_expect(_orbs().size() == 1, "one kill drops exactly one orb")
	var orb: Node = _orbs()[0]
	orb.set_physics_process(false)
	_expect(orb.heal_amount == 5.0 and orb.global_position.is_equal_approx(Vector2(400, -18)), "first drop has 5 healing beside the enemy XP drop")
	_expect(player.player_health == 100.0, "kill itself does not heal")
	_expect(orb._halo.material.blend_mode == CanvasItemMaterial.BLEND_MODE_MIX, "orb keeps a soft non-additive halo without stacking light")
	orb._process(0.2)
	player.pickup_range = 40.0
	orb._physics_process(1.0 / 60.0)
	_expect( not orb.attracting, "distant orbs are not collected globally")
	player.pickup_range = 500.0
	orb._physics_process(1.0 / 60.0)
	_expect(orb.attracting and orb.global_position.x < 400.0, "pickup range attracts the orb")
	for i in 200:
		if orb.collected:
			break
		orb._physics_process(1.0 / 60.0)
	_expect(player.player_health == 105.0 and orb.collected, "actual pickup grants 5 healing")
	var audio: AudioStreamPlayer = root.get_node("AudioManager/HealingPickupAudioPlayer")
	_expect(audio.playing and audio.stream.resource_path.ends_with("healing_pickup.wav"), "successful pickup plays dedicated healing sound")
	_expect(orb.collect() == 0.0 and player.player_health == 105.0, "duplicate collection cannot heal twice")

	_select_card(10)
	_kill_at(Vector2(450, 0), false)
	var old_orb: Node = _orbs()[0]
	old_orb.set_physics_process(false)
	_expect(old_orb.heal_amount == 10.0, "level two drops heal 10")
	_select_card(15)
	_kill_at(Vector2(500, 0), false)
	var newest: Node = _orbs()[-1]
	newest.set_physics_process(false)
	_expect(newest.heal_amount == 15.0 and old_orb.heal_amount == 10.0, "higher level increases new drops and preserves existing drop values")
	_expect(game.equipment_panel.get_level("monster_necklace") == 3, "equipment tracks repeated upgrades")
	player.player_health = player.max_player_health
	_expect(newest.collect() == 0.0 and newest.collected, "full health can collect without overhealing")
	_expect(newest.collect() == 0.0, "full-health pickup cannot be consumed twice")
	newest = game.spawn_necklace_orb(Vector2(500, 0))
	newest.set_physics_process(false)
	player.player_health = player.max_player_health - 2.0
	_expect(newest.collect() == 2.0 and player.player_health == player.max_player_health, "pickup caps healing at maximum health")
	player.player_health = 0.0
	_expect(old_orb.collect() == 0.0 and player.player_health == 0.0, "orbs cannot revive a dead player")
	player.full_heal()
	player.player_health = player.max_player_health

	var count_before: = _orbs().size()
	spawner.spawn(Vector2(100000, 0), false)
	spawner.remove_far_enemy()
	_expect(_orbs().size() == count_before, "despawning far enemies does not generate healing")
	await process_frame
	spawner.stage = 1
	spawner.spawn_boss()
	var boss: Node
	for enemy in get_nodes_in_group("EnemyGroup"):
		if enemy.has_signal("boss_defeated"):
			boss = enemy
	_expect(boss != null, "stage-one boss spawned for kill reward test")
	boss.apply_hit({"damage": 100000.0})
	var rest_deadline: = Time.get_ticks_msec() + 4000
	while game.rest_hub == null and Time.get_ticks_msec() < rest_deadline:
		await process_frame
	_expect(_orbs().size() == count_before + 1, "actual boss defeat also drops an orb")
	_expect(game.rest_hub != null and game.rest_hub.visible, "boss opens normal rest hub")
	if game.rest_hub == null:
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	var offered: = false
	for button in game.rest_hub._buttons:
		if button.get_meta("reward_id") == "monster_necklace":
			offered = true
	_expect(offered, "rest hub offers the same item")
	game.rest_hub._on_reward_pressed("monster_necklace")
	game.rest_hub._on_reward_pressed("monster_necklace")
	_expect(player.monster_necklace_level == 3 and game.equipment_panel.get_level("monster_necklace") == 3, "repeated rest selections do not grant rewards early")
	game.rest_hub._on_next_pressed()
	_expect(spawner.stage == 2 and player.monster_necklace_level == 4, "confirm awards one necklace rank and carries it into stage two")
	await create_timer(1.2, true, false, true).timeout
	spawner.timer.stop()
	spawner.get_node("Elite").stop()

	var expiring: Node = game.spawn_necklace_orb(Vector2(600, 0))
	expiring.set_physics_process(false)
	expiring._process(61.0)
	_expect(expiring.is_queued_for_deletion(), "old drops expire instead of accumulating forever")
	game.clear_run_objects()
	await process_frame
	_expect(_orbs().is_empty(), "run cleanup removes healing drops")
	game.queue_free()
	await process_frame
	var fresh: Node = load("res://scenes/player.tscn").instantiate()
	root.add_child(fresh)
	_expect(fresh.monster_necklace_level == 0, "new run starts with no necklace")
	fresh.free()
	if failures.is_empty():
		print("MONSTER NECKLACE OK: card selection, stacking, real kill drops, pickup/heal/audio, boss/rest/stage flow and reset")
	else:
		for failure in failures:
			push_error(failure)
	paused = false
	quit(0 if failures.is_empty() else 1)

func _select_card(amount: int) -> void :
	var menu: Node = game.pause_menu
	menu.upgrade_pool = [entry]
	menu.show_upgrade_options()
	var card: Node = menu.h_box_container.get_child(0)
	_expect(card.icon.texture != null, "card icon loads")
	_expect(card.desc_label.text.contains(CardNumbers.number(amount)), "card description previews next healing value")
	var event: = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	card._gui_input(event)
	event.pressed = false
	card._gui_input(event)
	_expect( not paused and not menu.visible, "selecting card resumes gameplay")

func _kill_at(pos: Vector2, double_hit: bool) -> void :
	spawner.spawn(pos, false)
	for enemy in get_nodes_in_group("EnemyGroup"):
		if not enemy.is_queued_for_deletion() and enemy.global_position.is_equal_approx(pos):
			enemy.set_physics_process(false)
			enemy.take_damage(100000.0)
			if double_hit:
				enemy.take_damage(100000.0)
			return
	_expect(false, "enemy spawned for kill test")

func _orbs() -> Array[Node]:
	var result: Array[Node] = []
	for orb in get_nodes_in_group("healing_orb"):
		if not orb.is_queued_for_deletion():
			result.append(orb)
	return result

func _expect(ok: bool, message: String) -> void :
	if not ok:
		failures.append(message)
