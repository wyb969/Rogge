extends SceneTree

class Target extends StaticBody2D:
	var hits := 0
	var last_damage := 0.0
	func apply_hit(hit: Dictionary) -> void:
		hits += 1
		last_damage = hit.damage

var failures := 0
var checks := 0

func _init() -> void: call_deferred("_run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func target(game: Node, at: Vector2) -> Target:
	var body := Target.new()
	body.collision_layer = 8
	body.collision_mask = 0
	var collider := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 2
	collider.shape = shape
	body.add_child(collider)
	body.add_to_group("EnemyGroup")
	game.add_child(body)
	body.global_position = at
	return body

func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await main._launch_run(&"light_thorn")
	var game: Node = main.game
	var whip: Node = game.light_thorn
	check(whip.level == 3 and game.equipment_panel.get_level("light_thorn") == 3, "practice equips the independent light whip")
	whip.set_physics_process(false)
	game.player.set_physics_process(false)
	game.clear_enemies()
	await process_frame
	var origin: Vector2 = game.player.global_position
	var middle := target(game, origin+Vector2(64,0))
	var edge := target(game, origin+Vector2(80,13))
	var outside := target(game, origin+Vector2(80,20))
	await physics_frame
	await physics_frame
	check(whip.cast(), "real target triggers swing")
	# Translate the displayed strip by 20 pixels in one step. Only the swept band,
	# with its physical width and the actual target circle, can deal damage here.
	for i in range(whip.LINKS+1):
		whip.previous[i] = origin + Vector2(i*8,-10)
		whip.points[i] = origin + Vector2(i*8,10)
	whip._sweep()
	whip._sweep()
	check(middle.hits == 1, "fast sweep hits between poses once across adjacent links")
	check(edge.hits == 1 and outside.hits == 0, "visible core width and target shape determine grazing contact")
	check(is_equal_approx(middle.last_damage,whip._stats.damage),"real hit payload matches equipped damage")
	whip.clear_combat_effects()
	whip._rng.seed = 3743
	var prior := Vector2.ZERO
	var varied := false
	var hit_before: int = middle.hits
	for attempt in 6:
		check(whip.cast(), "can start next procedural cast")
		for step in 21: whip._physics_process(1.0/60.0)
		var tip: Vector2 = whip.points[whip.LINKS]
		if attempt > 0 and prior.distance_to(tip)>5: varied = true
		prior = tip
		check(absf(angle_difference(whip._angles[0],whip._angles[-1])) > 0.05,"tip lags wrist during stroke")
		for step in 32: whip._physics_process(1.0/60.0)
		check(not whip.active,"lash retracts and stops")
	check(varied and middle.hits>hit_before and middle.hits<=hit_before+6, "real trajectories vary and hit a nearby enemy at most once per cast")
	game._on_upgrade_selected("light_thorn")
	check(whip.level == 4 and whip._stats.range > whip.stats_for(3).range, "upgrade increases physical reach")
	whip.cast()
	whip.reset()
	check(not whip.active and not whip.is_physics_processing(), "removal cancels rope and further hits")
	if failures == 0: print("LIGHT THORN OK: ",checks," checks")
	quit(1 if failures else 0)
