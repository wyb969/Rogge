extends SceneTree

var errors: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func check(ok: bool, reason: String) -> void:
	if not ok: errors.append(reason)

func _probe(actor: Node2D, local_x: float) -> bool:
	var box: CollisionShape2D = actor.get_node("CollisionShape2D")
	var query := PhysicsPointQueryParameters2D.new()
	query.position = box.to_global(Vector2(local_x, 0))
	query.collision_mask = 8
	for hit in actor.get_world_2d().direct_space_state.intersect_point(query):
		if hit.collider == actor: return true
	return false

func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	await main._launch_run(&"")
	var game: Node = main.game
	var spawner: Node = game.spawner
	spawner.timer.stop()
	spawner.get_node("Elite").stop()
	var actors: Array[Node2D] = []
	for elite in [false, true]:
		spawner.spawn(Vector2(510, 450 if elite else 270), elite)
		var mob: Node2D = get_nodes_in_group("EnemyGroup").back()
		mob.set_physics_process(false)
		mob.health = 10000.0 # Keep random stage hazards from killing the physics probe.
		actors.append(mob)
		check(is_equal_approx(mob.sprite_2d.scale.x, 2.25), "normal and elite art is exactly three times the old 0.75")
		var box: CollisionShape2D = mob.get_node("CollisionShape2D")
		check(is_equal_approx(box.global_scale.x * box.shape.size.x, mob.body_scale * 60.0), "solid spans three original body widths")
	var boss: Node2D = load("res://scenes/boss.tscn").instantiate()
	boss.set_player(game.player)
	game.add_child(boss)
	boss.position = Vector2(-420, -270)
	boss.set_physics_process(false)
	boss.rush_timer.stop()
	check(is_equal_approx(boss.sprite_2d.scale.x, 7.10), "lizard sprite is exactly double")
	check(boss.collision_shape_2d.shape.size == Vector2(170, 250), "lizard hurtbox is double on both axes")
	await physics_frame
	await physics_frame
	for actor in actors + [boss]:
		var box: CollisionShape2D = actor.get_node("CollisionShape2D")
		var half: float = box.shape.size.x / 2
		check(_probe(actor,half - 0.2) and not _probe(actor,half + 0.2), "physics query crosses the enlarged body's edge")
	var targets: Node = root.get_node("CombatTargets")
	var mob := actors[0]
	var box: CollisionShape2D = mob.get_node("CollisionShape2D")
	var edge := box.to_global(Vector2(box.shape.size.x / 2, 0))
	check(targets.in_radius(edge + Vector2.RIGHT * 4.9,25,game).has(mob), "blast overlaps the new flank before reaching center")
	check(not targets.in_radius(edge + Vector2.RIGHT * 5.1,25,game).has(mob), "blast outside the flank misses")
	boss.target_position = boss.global_position + Vector2.RIGHT * 240
	boss.rush_feedback.path_changed()
	var boundary: Vector2 = (boss.global_position + boss.target_position) / 2 + boss.rush_feedback.center_offset + Vector2.DOWN * boss.rush_feedback.half_size.y
	for step in [-1,1]:
		var point: Vector2 = boundary + Vector2.DOWN * step
		check(boss.rush_feedback.sweep_hits(boss.global_position,boss.target_position,point) == (step < 0) and Geometry2D.is_point_in_polygon(point,boss.rush_feedback._polygon) == (step < 0), "rush warning and its swept hit change on the same pixel")
	for message in errors: push_error(message)
	if errors.is_empty(): print("COMBAT SIZE OK: normal, elite and boss art; live physics hit/miss edges, blast flank and rush warning")
	quit(0 if errors.is_empty() else 1)
