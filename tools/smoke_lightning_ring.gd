extends SceneTree
var failures: Array[String] = []
var main: Node
func _init() -> void :
	call_deferred("_run")
func _expect(ok: bool, message: String) -> void :
	if not ok: failures.append(message)
func _fixture() -> Node:
	await main._launch_run(&"")
	var game: Node = main.game
	game.level_manager.signal_level_up.disconnect(game.on_level_up)
	game.player.set_physics_process(false)
	game.spawner.set_process(false)
	game.spawner.timer.stop()
	game.spawner.get_node("Elite").stop()
	game.lightning_ring.set_process(false)
	for name in ["HandWeapon", "CircleWeapon", "Weapon", "DroneController", "MolotovController", "FreezeController"]:
		game.get_node(name).process_mode = Node.PROCESS_MODE_DISABLED
	return game
func _enemy(game: Node, position: Vector2) -> Node:
	var enemy: Node = load("res://scenes/enemy_shell.tscn").instantiate()
	enemy.set_enemy_data(load("res://resource/Enemy2.tres"))
	enemy.set_player_ref(game.player)
	enemy.add_to_group("EnemyGroup")
	enemy.death_signal.connect(game.spawner.on_enemy_killed.bind(enemy))
	game.add_child(enemy)
	enemy.global_position = game.player.global_position + position
	enemy.health = 1000
	enemy.defense = 0.2
	enemy.set_physics_process(false)
	return enemy
func _run() -> void :
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	var game: Node = await _fixture()
	var ring: Node = game.lightning_ring
	_expect(ring.strike() == 0, "unowned ring cannot attack")
	var entry: Dictionary = {}
	var full_pool: Array = game.pause_menu.upgrade_pool.duplicate()
	for candidate in game.pause_menu.upgrade_pool:
		if candidate.id == "lightning_ring": entry = candidate
	_expect( not entry.is_empty(), "ring is in the normal card and treasure pool")
	if entry.is_empty():
		quit(1)
		return
	game.pause_menu.upgrade_pool = [entry]
	game.pause_menu.show_upgrade_options()
	var card: Node = game.pause_menu.h_box_container.get_child(0)
	_expect(card.desc_label.text.contains("30") and card.desc_label.text.contains("180") and card.icon.texture != null, "real card shows its next stats and original icon")
	card.selected.emit("lightning_ring")
	_expect(ring.level == 1 and game.equipment_panel.get_level("lightning_ring") == 1 and game.spawner._offense_cards == 1, "card selection unlocks controller, HUD and offense scaling together")
	var one: Node = _enemy(game, Vector2(50, 0))
	var two: Node = _enemy(game, Vector2(100, 0))
	var third: Node = _enemy(game, Vector2(190, 0))
	game.player.get_node("Camera2D").reset_smoothing()
	await process_frame
	_expect(ring.strike() == 2, "level one strikes two different nearby targets")
	_expect(is_equal_approx(one.health, 976) and is_equal_approx(two.health, 976) and third.health == 1000, "damage uses actual mitigation and respects the 180 range")
	var effect: Node = get_nodes_in_group("lightning_fx")[-1]
	_expect(effect.tint == game.LIGHTNING_FX.VIOLET and effect.tint != game.LIGHTNING_FX.GOLD and effect.bolts.size() == 2, "ring reuses branched skill lightning in a distinct violet palette")
	_expect(ring._audio.playing, "successful pulse plays its own electric sound")
	var hp: float = one.health
	effect._process(0.1)
	_expect(one.health == hp, "visual restrikes never apply repeat damage")
	game.pause_menu.show_upgrade_options()
	card = game.pause_menu.h_box_container.get_child(0)
	_expect(card.desc_label.text.contains("44") and card.desc_label.text.contains("204"), "next card reflects stronger damage and wider range")
	card.selected.emit("lightning_ring")
	_expect(ring.level == 2 and game.equipment_panel.get_level("lightning_ring") == 2, "repeated selection upgrades the same item")
	_expect(ring.strike() == 3 and is_equal_approx(third.health, 964.8), "level two adds a third bolt and reaches the previously distant enemy")
	ring.strike_left = 2
	hp = one.health
	paused = true
	ring._process(5)
	_expect(ring.strike() == 0 and ring.strike_left == 2 and one.health == hp, "paused card and rest screens freeze automatic attacks and cooldown")
	paused = false
	ring._process(1)
	_expect(one.health == hp, "cooldown blocks early pulses")
	ring._process(1.1)
	_expect(one.health < hp and ring.strike_left == 3, "automatic clock fires one pulse after its cooldown")
	game.spawner._rest_open = true
	hp = one.health
	_expect(ring.strike() == 0 and one.health == hp, "ordinary rest cannot be farmed with automatic lightning")
	game.spawner._rest_open = false
	game._on_upgrade_selected("monster_necklace")
	one.health = 1
	var kills: int = game.spawner.enemy_killed_num
	ring.strike()
	_expect(game.spawner.enemy_killed_num == kills + 1 and get_nodes_in_group("healing_orb").size() == 1, "real ring kill grants one kill and one necklace orb")

	game.clear_enemies()
	await process_frame
	var distant: Node = _enemy(game, Vector2(700, 0))
	ring.level = 30
	_expect(ring.strike() == 0 and distant.health == 1000, "even a high-level ring cannot snipe offscreen enemies")
	ring.level = 2
	game.spawner._mini_cleared = true
	game._on_treasure_earned()
	await process_frame
	await process_frame
	var lottery: Node = game.treasure_lottery
	lottery.bonus_levels = 3
	lottery._reveal()
	lottery._button.pressed.emit()
	lottery._button.pressed.emit()
	_expect(ring.level == 5 and game.equipment_panel.get_level("lightning_ring") == 5 and game.spawner._offense_cards == 5, "real lottery upgrades all ring stats three times and claims only once")
	game.pause_menu.upgrade_pool = full_pool
	for size in [Vector2i(390, 844), Vector2i(900, 500)]:
		root.size = size
		await process_frame
		game.pause_menu.show_upgrade_options()
		await process_frame
		await process_frame
		var screen: = Rect2(Vector2.ZERO, root.get_visible_rect().size)
		_expect(game.pause_menu.h_box_container.get_child_count() == 3, "normal draw still offers three cards")
		for option in game.pause_menu.h_box_container.get_children():
			_expect(screen.encloses(option.get_global_rect()) and option.get_global_rect().encloses(option.desc_label.get_global_rect()), "three-card layout and descriptions fit portrait/landscape")
	game.pause_menu.hide()
	paused = false
	await main._launch_run(&"beast_6")
	game = main.game
	game.player.set_physics_process(false)
	for name in ["HandWeapon", "CircleWeapon", "Weapon", "DroneController", "MolotovController", "FreezeController"]:
		game.get_node(name).process_mode = Node.PROCESS_MODE_DISABLED
	game._on_upgrade_selected("lightning_ring")
	game.lightning_ring.set_process(false)
	var beast: Node = get_nodes_in_group("beast_boss")[0]
	beast.set_physics_process(false)
	beast.global_position = game.player.global_position + Vector2(100, 0)
	var before: float = beast.boss_current_health
	_expect(game.lightning_ring.strike() == 1 and beast.boss_current_health == before - 30, "one boss receives one flat-damage bolt, not every unused bolt")
	await main._launch_run(&"trial_speed")
	game = main.game
	game._on_upgrade_selected("lightning_ring")
	game.lightning_ring.set_process(false)
	game.player.set_physics_process(false)
	for name in ["HandWeapon", "CircleWeapon", "Weapon", "DroneController", "MolotovController", "FreezeController"]:
		game.get_node(name).process_mode = Node.PROCESS_MODE_DISABLED
	game.trials.start_button.pressed.emit()
	game.trials.set_process(false)
	var wizard: Node = game.trials.enemy
	wizard.set_physics_process(false)
	before = wizard.boss_current_health
	game.lightning_ring.strike()
	_expect(wizard.boss_current_health == before, "ring respects the speed wizard's closed barrier")
	wizard.teleport_near_player()
	game.player._start_dash(Vector2.RIGHT)
	wizard._physics_process(0.51)
	wizard._physics_process(0.17)
	game.player._on_dashing_timer_timeout()
	game.lightning_ring.strike()
	_expect(game.lightning_ring.level == 1 and wizard.boss_current_health == before - 30, "retained ring works during active trials and real counterattack openings")
	await main._launch_run(&"lightning")
	_expect(main.game.lightning_ring.level == 1 and main.game.beast_powers.unlocked.has(1), "Debug comparison opens with the ring and golden skill")
	await main._launch_run(&"")
	_expect(main.game.lightning_ring.level == 0 and main.game.equipment_panel.get_level("lightning_ring") == 0 and get_nodes_in_group("lightning_fx").is_empty(), "fresh runs retain no ring level, audio or old bolts")
	if failures.is_empty(): print("LIGHTNING RING OK: real cards/stats, unique targets, range, mitigation, cooldown, color/audio, kill drops, lottery, bosses/trials and run reset")
	else:
		for failure in failures: push_error(failure)
	paused = false
	quit(0 if failures.is_empty() else 1)
