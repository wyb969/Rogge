extends SceneTree
var failures: Array[String] = []
func _init() -> void :
	call_deferred("_run")
func _run() -> void :
	var game: Node = load("res://scenes/game.tscn").instantiate()
	game.add_to_group("game")
	root.add_child(game)
	game.spawner.timer.stop()
	game.spawner.get_node("Elite").stop()
	game.player.set_physics_process(false)
	for name in ["HandWeapon", "CircleWeapon", "Weapon", "DroneController", "MolotovController", "FreezeController"]:
		game.get_node(name).process_mode = Node.PROCESS_MODE_DISABLED
	game.run_difficulty = load("res://script/run_difficulty.gd").new(0)
	game.level_manager.level_need_coin_number = 1000000
	var expected: = 0
	var raw_total: = 0
	for index in range(1000):
		var xp: = 5 if index % 2 else 2
		expected += game.run_difficulty.experience_for(xp)
		raw_total += xp
		game._spawn_xp_coin_now(Vector2(1000 + index % 10, 0), xp)
	var coins: = get_nodes_in_group("xp_coin")
	_expect(coins.size() == 256, "a thousand uncollected drops use only 256 coin actors")
	var actual_raw: = 0
	var prepared: = 0
	for coin in coins:
		coin.monitoring = false
		actual_raw += coin.xp_value
		prepared += coin.prepared_xp
		coin.collect_coin()
	_expect(actual_raw == raw_total and prepared == expected, "coin merging preserves raw XP and per-kill easy-mode rounding")


	var deadline: = Time.get_ticks_msec() + 1500
	while not get_nodes_in_group("xp_coin").is_empty() and Time.get_ticks_msec() < deadline:
		await process_frame
	_expect(game.level_manager.coin_number == expected, "real collection awards consolidated XP exactly once (got %d, expected %d, remaining %d)" % [game.level_manager.coin_number, expected, get_nodes_in_group("xp_coin").size()])
	game.player.monster_necklace_level = 3
	for index in range(500):
		game.spawn_necklace_orb(Vector2(1000 + index % 10, 0))
	var orbs: = get_nodes_in_group("healing_orb")
	_expect(orbs.size() == 96, "five hundred uncollected healing drops consolidate into 96 actors")
	var healing: = 0.0
	for orb in orbs:
		healing += orb.heal_amount
		_expect(orb._halo.texture == orbs[0]._halo.texture and orb._halo.material == orbs[0]._halo.material, "all orbs share their glow texture/material")
	_expect(healing == 500 * 15.0, "healing consolidation keeps the complete stored heal amount")

	var bullet: Node = load("res://scenes/bullet.tscn").instantiate()
	game.effect_container.add_child(bullet)
	bullet._physics_process(3.1)
	_expect(bullet.is_queued_for_deletion(), "player projectiles expire without a screen-exit notification")
	game.gun_weapon.cool_down = true
	game.gun_weapon.shoot()
	var shot: Node = get_nodes_in_group("player_projectile").back()
	_expect(game.effect_container.is_ancestor_of(shot), "gun bullets belong to the run, not persistent main")
	var enemy: Node = load("res://scenes/enemy_shell.tscn").instantiate()
	game.add_child(enemy)
	enemy.set_physics_process(false)
	for index in range(300):
		enemy.show_damage_text(10)
	_expect(get_nodes_in_group("damage_popup").size() <= 6, "burst hits respect the per-frame floating-text budget")
	var bottle: Node = load("res://script/molotov_bottle.gd").new()
	game.effect_container.add_child(bottle)
	game.combat_feedback.start()
	enemy.add_to_group("EnemyGroup")
	var before_hp: float = enemy.health
	bottle._explode()
	var shards: int = game.combat_feedback.shards.size()
	bottle._explode()
	_expect(enemy.health == before_hp - 4.5 and shards > 0 and game.combat_feedback.shards.size() == shards, "one bottle deals one explosion and emits one reused burst across multiple callbacks")
	for effect in game.effect_container.get_children():
		_expect( not effect is CPUParticles2D, "bottle impacts do not allocate particle nodes")
	game.end_game()
	await process_frame
	await process_frame
	_expect(game.effect_container.get_child_count() == 0 and game.pickup_container.get_child_count() == 0, "all consolidated drops and effects clear when the run ends")
	if failures.is_empty():
		print("RESOURCE BOUNDS OK: 1000 coins/500 orbs preserve rewards, shared GPU resources, projectile ownership/TTL, cosmetic budgets, single explosions and teardown")
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
func _expect(ok: bool, message: String) -> void :
	if not ok: failures.append(message)
