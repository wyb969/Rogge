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

func sample_motion(whip: Node, origin: Vector2, rank: int) -> Dictionary:
	whip.reset()
	for i in rank: whip.upgrade()
	whip._rng.seed = 73081
	var seen := {}
	var prior_style := -1
	var no_repeats := true
	var tip_speed := 0.0
	var grip_speed := 0.0
	var extent := 0.0
	var spread := 0.0
	var first_sample := {}
	var last_sample := Vector2.ZERO
	for cast_index in 18:
		if not whip.cast():
			check(false, "nearby target available throughout motion sampling")
			break
		var style: int = whip._stroke
		seen[style] = true
		no_repeats = no_repeats and style != prior_style
		prior_style = style
		var dt: float = whip._duration / 100
		for step in 100:
			var tip: Vector2 = whip.points[-1]
			var grip: Vector2 = whip.points[0]
			whip._advance(dt, origin)
			tip_speed = maxf(tip_speed, tip.distance_to(whip.points[-1]) / dt)
			grip_speed = maxf(grip_speed, grip.distance_to(whip.points[0]) / dt)
			extent = maxf(extent, origin.distance_to(whip.points[-1]))
			if step == 58:
				# Remove aim, handedness, reach and tempo before comparing shapes.
				last_sample = (whip.points[-1] - origin).rotated(-whip._aim) / whip._reach
				last_sample.y *= whip._side
				if first_sample.has(style):
					spread = maxf(spread, last_sample.distance_to(first_sample[style]))
				else: first_sample[style] = last_sample
		whip.clear_combat_effects()
	check(seen.size() == 3 and no_repeats, "all three impulse families appear and cannot repeat back-to-back")
	check(spread > 0.22, "same-family trajectories still diverge after removing aim, mirroring, range and tempo")
	check(tip_speed > 4.0 * grip_speed, "whip tip outruns the wrist")
	check(extent <= whip.stats_for(rank).range + 0.02, "discrete links respect the reach cap")
	# Run the real auto-cast clock against the same standing target for 12 seconds.
	var before: int = whip.casts
	for i in 720: whip._physics_process(1.0 / 60.0)
	return {"tip_speed":tip_speed, "extent":extent, "auto_casts":whip.casts - before}

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
	whip._sweep(whip.previous, whip.points)
	whip._sweep(whip.previous, whip.points)
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
	for rank in range(1,5):
		var a: Dictionary = whip.stats_for(rank)
		var b: Dictionary = whip.stats_for(rank + 1)
		check(b.range > a.range and b.swing_time < a.swing_time and b.interval < a.interval, "all three attributes improve on each rank")
	var low := sample_motion(whip, origin, 1)
	var high := sample_motion(whip, origin, 5)
	check(high.extent > low.extent * 1.35, "actual full-rank lash extends farther")
	check(high.tip_speed > low.tip_speed * 1.25 and high.auto_casts > low.auto_casts, "full rank has faster strikes and more casts at the same target")
	print("LIGHT THORN MOTION rank 1 ", low, " rank 5 ", high)
	if failures == 0: print("LIGHT THORN OK: ",checks," checks")
	quit(1 if failures else 0)
