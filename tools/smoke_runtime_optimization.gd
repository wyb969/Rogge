extends SceneTree
class Target extends Node2D:
	var health: = 10000.0
	var hits: = 0
	func apply_hit(data: Dictionary) -> void :
		health -= float(data.damage)
		hits += 1
var failures: Array[String] = []
func _init() -> void :
	call_deferred("_run")
func _expect(ok: bool, message: String) -> void :
	if not ok: failures.append(message)
func _run() -> void :
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	await main._launch_run(&"weather")
	var game: Node = main.game
	game.spawner.timer.stop()
	game.spawner.get_node("Elite").stop()
	game.player.set_physics_process(false)
	for name in ["HandWeapon", "CircleWeapon", "Weapon", "DroneController", "MolotovController", "FreezeController"]:
		game.get_node(name).process_mode = Node.PROCESS_MODE_DISABLED
	var targets: Array[Target] = []
	for i in 4:
		var target: = Target.new()
		game.add_child(target)
		target.position = Vector2(50 * i, 0)

		target.add_to_group("EnemyGroup")
		targets.append(target)
	var registry: Node = root.get_node("CombatTargets")
	_expect(registry.nearest(Vector2(45, 0)) == targets[1], "registry sees actors grouped after insertion in the same frame")
	targets[1].health = 0
	_expect(registry.nearest(Vector2(45, 0)) == targets[0], "zero HP is excluded without a cached-frame delay")
	targets[1].health = 10000
	targets[1].position = Vector2(1000, 0)
	_expect(registry.nearest(Vector2(45, 0)) == targets[0], "movement is read live rather than from an old spatial cell")
	targets[1].position = Vector2(50, 0)
	targets[0].remove_from_group("EnemyGroup")
	_expect(registry.nearest(Vector2.ZERO) == targets[1], "group removals are visible immediately")
	targets[0].add_to_group("EnemyGroup")
	var picked: Array[Node2D] = registry.nearest_visible(Vector2.ZERO, 40000, 2, game, Rect2(-10, -10, 300, 100), Transform2D.IDENTITY)
	_expect(picked == [targets[0], targets[1]], "limited nearest selection preserves order, radius, owner and visibility")
	seed(969)
	var expected: = randi()
	seed(969)
	var chain: Node = game.acquire_chain_lightning()
	chain.start_chain(targets[0], {"damage": 10, "chain_count": 3, "chain_range": 80})
	chain.set_process(false)
	_expect(targets[0].hits == 0 and targets[1].hits == 1 and targets[2].hits == 0, "chain's first jump remains immediate and skips its source")
	paused = true
	chain._process(1)
	_expect(targets[2].hits == 0, "paused card/reward pages cannot advance chain damage")
	paused = false
	chain._process(0.08)
	chain._process(0.08)
	_expect(targets[1].hits == 1 and targets[2].hits == 1 and targets[3].hits == 1 and chain.get_child_count() == 0, "three exact jumps hit once without timer/line child nodes")
	chain._process(1)
	_expect( not chain.active and game._idle_chains.has(chain), "completed logic returns to the run-owned bounded pool")
	var reused: Node = game.acquire_chain_lightning()
	_expect(reused == chain and game.chains_created == 1 and game.chains_reused == 1, "later hits reuse the same chain instance")
	reused.start_chain(targets[0], {"damage": 10, "chain_count": 3, "chain_range": 80})
	reused.set_process(false)
	reused._process(1)
	_expect(targets[1].hits == 2 and targets[2].hits == 2 and targets[3].hits == 2 and randi() == expected, "reuse clears hit history and preserves gameplay RNG through long frames")
	for _i in 100:
		var effect: Node = game.acquire_chain_lightning()
		effect.start_chain(targets[0], {"damage": 1, "chain_count": 3, "chain_range": 80})
		effect.set_process(false)
		effect._process(1)
	_expect(game.chains_created == 1 and game._idle_chains.size() == 1, "repeated chain storms do not keep allocating scene instances")
	game.clear_run_objects()
	var fresh: Node = game.acquire_chain_lightning()
	_expect(fresh != reused and reused.is_queued_for_deletion(), "clearing effects cannot reacquire a queued old pool entry")
	fresh.queue_free()
	var track_before: int = registry.tracked_count()
	for target in targets: target.queue_free()
	_expect(registry.nearest(Vector2.ZERO) == null, "queued removals cannot become new targets")
	await process_frame
	_expect(registry.tracked_count() == track_before - 4, "tree removal releases all registry references")
	var coin: Node = load("res://scenes/coin.tscn").instantiate()
	var orb: Node = load("res://scenes/healing_orb.tscn").instantiate()
	orb.configure(5, game.player)
	game.pickup_container.add_child(coin)
	game.pickup_container.add_child(orb)
	_expect(game._xp_actors.has(coin) and game._healing_actors.has(orb), "external/debug pickups are registered synchronously before group-ready callbacks")
	coin.queue_free()
	orb.queue_free()
	await process_frame
	_expect(game._xp_actors.is_empty() and game._healing_actors.is_empty(), "pickup deletion clears local indices")
	var fx: Node = game.combat_feedback
	for _i in 100:
		fx.hit(Vector2.ZERO, Vector2.RIGHT, true)
		fx._stamp = Time.get_ticks_msec() - 50
		fx._process(0.05)
		_expect(fx.shards.size() + fx._free_shards.size() == 128 and fx.rings.size() + fx._free_rings.size() == 16, "cosmetic records reuse their fixed warmed pools")
	fx.reset()
	_expect(fx._free_shards.size() == 128 and fx._free_rings.size() == 16 and fx._free_ghosts.size() == 8, "reset recycles every cosmetic slot without pool growth")
	var background: Node = game.get_node("InfiniteBackground")
	background._update_coverage()
	var ground: int = background.coverage_rebuilds
	var decor: int = background.decoration_rebuilds
	for _i in 100: background._update_coverage()
	_expect(background.coverage_rebuilds == ground and background.decoration_rebuilds == decor, "stationary frames do not rebuild ground polygons or decorations")
	var audio: Node = root.get_node("AudioManager")
	audio._focus_until_msec = 0
	audio._music_duck = 1
	audio._process(0)
	var writes: int = audio.mix_writes
	for _i in 100: audio._process(0)
	_expect(audio.mix_writes == writes, "steady music does not resend the same bus gain every frame")
	for size in [Vector2i(390, 844), Vector2i(1920, 1080), Vector2i(1170, 2532)]:
		root.size = size
		await process_frame
		await process_frame
		var want: = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS if size.x < 900 else Window.CONTENT_SCALE_MODE_VIEWPORT
		_expect(root.content_scale_mode == want, "small and retina windows choose their cheaper render path automatically")
		var vp: = root.get_visible_rect().size
		_expect(vp.x >= 899 and vp.y >= 599, "render budgeting preserves the design-space HUD and field of view")
	main.on_game_over({"victory": false})
	await main._on_game_end_ui_retry_pressed()
	_expect(main.game._idle_chains.is_empty() and main.game._xp_actors.is_empty(), "new runs inherit no pool entries or pickup references")
	main.show_main_menu()
	if failures.is_empty(): print("RUNTIME OPTIMIZATION OK: live target lifecycle/nearest selection, exact pooled pause-safe chains/RNG, no child effects/timers, synchronous pickup indices, fixed cosmetic slots, cached geometry/audio and clean Retry")
	else:
		for failure in failures: push_error(failure)
	paused = false
	quit(0 if failures.is_empty() else 1)
