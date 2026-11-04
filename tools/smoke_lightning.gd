extends SceneTree
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
	await main._launch_run(&"beast_6")
	var game: Node = main.game
	game.player.set_physics_process(false)
	for name in ["HandWeapon", "CircleWeapon", "Weapon", "DroneController", "MolotovController", "FreezeController"]:
		game.get_node(name).process_mode = Node.PROCESS_MODE_DISABLED
	var beast: Node = get_nodes_in_group("beast_boss")[0]
	beast.set_physics_process(false)
	beast.global_position = game.player.global_position + Vector2(100, 0)
	var before: float = beast.boss_current_health
	game.beast_powers.select(1)
	_expect(game.beast_powers.cast_selected(), "real full-screen thunder can be cast")
	_expect(is_equal_approx(beast.boss_current_health, before - beast.health_max_value * 0.06), "random artwork preserves the original boss damage budget")
	var effect: Node2D = get_nodes_in_group("lightning_fx")[0]
	effect.set_process(false)
	_expect(effect.tint == game.LIGHTNING_FX.GOLD and effect.get_parent() == game.effect_container, "gold skill effect belongs to this run")
	var bolt: Dictionary = effect.bolts[0]
	_expect(bolt.frames[0].trunk != bolt.frames[1].trunk and bolt.frames[1].trunk != bolt.frames[2].trunk, "restrikes have different silhouettes")
	_expect(bolt.frames[0].branches.size() >= 2, "visible lightning has secondary branches")
	for frame in bolt.frames:
		_expect(effect.to_global(frame.trunk[-1]).is_equal_approx(beast.global_position), "every random silhouette still ends at the real impact position")
	var end: Vector2 = effect.to_global(bolt.end)
	game.player.global_position += Vector2(70, 0)
	game.beast_powers._process(0.1)
	_expect(effect.to_global(bolt.end) == end, "moving the player does not drag the strike")
	var positions: Array[Vector2] = [end]
	seed(969)
	var expected: = randi()
	seed(969)
	var other: Node = game.show_lightning_strikes(positions, game.LIGHTNING_FX.GOLD)
	other.set_process(false)
	_expect(randi() == expected, "cosmetic random branches do not consume combat/loot RNG")
	_expect(other.bolts[0].frames[0].trunk != bolt.frames[0].trunk, "separate casts generate new shapes")
	var age: float = effect.age
	paused = true
	await process_frame
	_expect(effect.age == age, "upgrade pause holds the lightning artwork")
	paused = false
	effect._process(0.5)
	_expect(effect.is_queued_for_deletion(), "short afterglow cleans itself up")
	await main._launch_run(&"")
	_expect(get_nodes_in_group("lightning_fx").is_empty(), "restarting leaves no old flashes or targets")
	if failures.is_empty(): print("LIGHTNING OK: real skill damage, random branches/restrikes, anchored endpoints, isolated cosmetic RNG, pause and cleanup")
	else:
		for failure in failures: push_error(failure)
	paused = false
	quit(0 if failures.is_empty() else 1)
