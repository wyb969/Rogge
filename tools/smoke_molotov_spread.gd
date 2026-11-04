extends SceneTree
var failures: Array[String] = []
var game: Node
func _init() -> void : call_deferred("_run")
func expect(ok: bool, message: String) -> void :
	if not ok: failures.append(message)
func mob(at: Vector2, parent: Node = null) -> Node:
	var actor: Node = load("res://scenes/enemy_shell.tscn").instantiate()
	actor.set_enemy_data(load("res://resource/Enemy_1.tres"))
	actor.set_player_ref(game.player)
	(parent if parent != null else game).add_child(actor)
	actor.add_to_group("EnemyGroup")
	actor.global_position = at
	actor.health = 10000
	actor.set_physics_process(false)
	return actor
func _run() -> void :
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	await main._launch_run(&"")
	game = main.game
	game.spawner.set_process(false)
	game.spawner.timer.stop()
	game.spawner.get_node("Elite").stop()
	game.player.set_physics_process(false)
	for name in ["HandWeapon", "CircleWeapon", "Weapon", "DroneController", "MolotovController", "FreezeController"]: game.get_node(name).process_mode = Node.PROCESS_MODE_DISABLED
	var near: Node = mob(Vector2(20, 0))
	var edge: Node = mob(Vector2(70, 0))
	var outside: Node = mob(Vector2(70.1, 0))
	var foreign: Node = mob(Vector2(20, 0), root)
	var dead: Node = mob(Vector2(30, 0))
	dead.health = 0
	var removed: Node = mob(Vector2(30, 0))
	removed.queue_free()
	var bottle: Node = load("res://scenes/molotov_bottle.tscn").instantiate()
	game.effect_container.add_child(bottle)
	bottle.set_physics_process(false)
	bottle.monitoring = false
	bottle.burn_dps = 6
	bottle.explode_radius = 70
	bottle._explode()
	bottle._explode()
	expect(near.health == 9991 and edge.health == 9991 and near.burn_stacks == 2, "real explosion deals exactly one 1.5x hit and burn at the inclusive radius boundary")
	expect(outside.health == 10000 and foreign.health == 10000 and dead.health == 0, "radius/live/run-owner filters exclude far, foreign, dead and queued actors")
	var picked: Array[Node2D] = []
	outside.global_position = Vector2(40, 0)
	root.get_node("CombatTargets").fill_in_radius(Vector2.ZERO, 2500, game, picked)
	expect(picked.has(outside), "explosion queries see same-frame movement without stale frame positions")
	var a: Node = load("res://scenes/molotov_bottle.tscn").instantiate()
	var b: Node = load("res://scenes/molotov_bottle.tscn").instantiate()
	game.effect_container.add_child(a)
	game.effect_container.add_child(b)
	expect(a.get_node("CollisionShape2D").shape == b.get_node("CollisionShape2D").shape and a.get_node("Sprite2D").texture == b.get_node("Sprite2D").texture, "throws reuse shared shape and sprite resources")
	a.queue_free()
	b.queue_free()
	foreign.free()
	game.clear_enemies()
	await process_frame
	await process_frame
	var resolver: Node = game.burn_spread
	resolver.set_physics_process(false)
	var actors: Array[Node] = []
	var expected_stacks: Array[int] = []
	var expected_dps: Array[float] = []
	for i in 80:
		var actor: Node = mob(Vector2(i % 10 * 30, float(i / 10) * 30))
		actor.burn_stacks = i % 5
		actor.burn_dps = 1.0 + float(i % 3) * 0.1
		actors.append(actor)
		expected_stacks.append(actor.burn_stacks)
		expected_dps.append(actor.burn_dps)
	for i in 240:
		var source: Node = actors[i % actors.size()]
		var potency: = 2.0 + float(i % 11) * 0.137
		resolver.request(source, potency)
		for j in actors.size():
			if actors[j] != source and source.global_position.distance_squared_to(actors[j].global_position) <= 78 * 78:
				expected_stacks[j] = mini(10, expected_stacks[j] + 1)
				expected_dps[j] = maxf(expected_dps[j], potency)
	paused = true
	resolver.flush()
	expect(resolver._count == 240, "reward pauses cannot resolve queued burn propagation")
	paused = false
	var node_count: = get_node_count()
	var batches: int = resolver.batches
	var writes: int = resolver.applied
	resolver.flush()
	for j in actors.size():
		expect(actors[j].burn_stacks == expected_stacks[j] and is_equal_approx(actors[j].burn_dps, expected_dps[j]), "batched radius, self exclusion, capped layers and strongest full-precision potency match the brute-force result")
	expect(resolver.batches == batches + 1 and resolver.applied - writes <= actors.size() and get_node_count() == node_count, "240 simultaneous sources use one index build/one apply per recipient and create no nodes")

	seed(969)
	var accepted: = 0
	for _i in actors.size():
		if randf() <= 0.4: accepted += 1
	var next: = randi()
	seed(969)
	for actor in actors: actor._try_spread_burn()
	expect(resolver._count == accepted and randi() == next, "real enemy spread keeps its probability and gameplay RNG sequence")
	resolver.flush()
	for _i in 600: resolver.request(actors[0], 9.4321)
	resolver.flush()
	expect(is_equal_approx(actors[1].burn_dps, 9.4321) and resolver._count == 0 and resolver._requests.size() == 512, "more than 512 requests split without lost potency or an unbounded request pool")
	resolver.request(actors[0], 20)
	actors[1].queue_free()
	resolver.flush()
	game.clear_enemies()
	await process_frame
	await process_frame

	var source: Node = mob(Vector2(-200, 0))
	var scattered: Array[Node] = []
	for i in 270:
		var actor: Node = mob(Vector2(i * 160, 500))
		scattered.append(actor)
		source.global_position = actor.global_position + Vector2(0, 1)
		resolver.request(source, 3.14159)
	resolver.flush()
	for actor in scattered: expect(actor.burn_stacks == 1 and is_equal_approx(actor.burn_dps, 3.14159), "bucket overflow retains distant-cell recipients rather than dropping spread")
	expect(resolver._buckets.size() == 256 and resolver._targets.is_empty() and resolver._cells.is_empty(), "spatial storage stays bounded and releases cached actors after every batch")
	resolver.request(source, 10)
	game.clear_enemies()
	expect(resolver._count == 0 and not resolver.is_physics_processing(), "clear/transition cancels pending propagation before the next wave")
	main.show_main_menu()
	if failures.is_empty(): print("MOLOTOV SPREAD OK: exact real explosion/live radius/owner/once, shared assets, 240-source reference equivalence, cap/potency/RNG/pause, request and bucket overflow, deletion/clear and bounded allocation")
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
