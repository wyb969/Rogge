extends SceneTree

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func expect(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func _run() -> void:
	await _check_travel()
	var game: Node = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.start_game()
	var spawner: Node = game.spawner
	var previous := {}
	for stage in range(1, spawner.FINAL_STAGE + 1):
		spawner.stage = stage
		var series: Texture2D
		for elite in [false, true]:
			var before := get_nodes_in_group("EnemyGroup")
			spawner.spawn(Vector2(120, 100), elite)
			var actors := get_nodes_in_group("EnemyGroup")
			if actors.size() != before.size() + 1:
				failures.append("stage %d did not spawn a new actor" % stage)
				continue
			var actor: Node = actors.back()
			var sprite: Sprite2D = actor.get_node("Sprite2D")
			expect(sprite.hframes == 4 and sprite.vframes == 10, "sheet grid")
			if not elite:
				series = sprite.texture
				expect(not previous.has(series), "series repeated across stages")
				previous[series] = true
			expect(series == sprite.texture, "mixed series in a stage")
			var row := sprite.frame_coords.y
			var frames := {}
			actor.velocity = Vector2.RIGHT * actor.speed
			for tick in 90:
				actor._apply_move_juice(1.0 / 60.0, actor.speed / 60.0)
				frames[sprite.frame_coords.x] = true
				expect(sprite.frame_coords.y == row, "gait changed species")
				if elite:
					var uv: Vector4 = sprite.material.get_shader_parameter("frame_uv_rect")
					expect(is_equal_approx(uv.x, sprite.frame_coords.x / 4.0) and is_equal_approx(uv.y, row / 10.0), "outline tracks current pose")
			expect(frames.size() == 4, "walk uses all four poses")
			actor.velocity = Vector2.ZERO
			for tick in 20:
				actor._apply_move_juice(1.0 / 60.0)
			expect(sprite.frame_coords == Vector2i(0, row), "rest returns to the species contact pose")
			actor.free()
	var art = spawner._monster_art
	for series in art.SPECIES:
		var ids := {}
		for id in series:
			ids[id] = true
		expect(ids.size() == 10 and series.min() == 1 and series.max() == 10, "all ten species mapped")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS stage monster art: six stages, elite UVs, four poses, dinosaur and zoo facing, slowed and blocked travel")
	else:
		push_error(str(failures.slice(0, 10)))
	quit(0 if failures.is_empty() else 1)

func _check_travel() -> void:
	var art := preload("res://script/stage_monster_art.gd")
	var target := CharacterBody2D.new()
	root.add_child(target)
	var actor: CharacterBody2D = load("res://scenes/enemy_shell.tscn").instantiate()
	actor.set_enemy_data(preload("res://resource/Enemy_1.tres"))
	actor.set_player_ref(target)
	root.add_child(actor)
	actor.set_physics_process(false)
	var sprite: Sprite2D = actor.get_node("Sprite2D")
	var dinosaurs: Texture2D = art.SHEETS.back()
	for row in 10:
		actor.set_walk_sheet(dinosaurs, row, art.SOURCE_FACING.back()[row], 0.0)
		for direction in [Vector2.RIGHT, Vector2.LEFT]:
			target.position = actor.position + direction * 500
			actor._physics_process(1.0 / 60.0)
			expect(sprite.flip_h == (direction == Vector2.RIGHT), "dinosaur %d must lead with its head" % row)
			var was_flipped := sprite.flip_h
			actor._face(Vector2(0.01, 1), false)
			expect(sprite.flip_h == was_flipped, "vertical walk retains facing")
	for row in [1, 6]: # Raised trunk and open mouth point right in the zoo source.
		actor.set_walk_sheet(art.SHEETS[5], row, art.SOURCE_FACING[5][row], 0.0)
		actor._face(Vector2.RIGHT, false)
		expect(not sprite.flip_h, "native right view should stay original")
		actor._face(Vector2.LEFT, false)
		expect(sprite.flip_h, "native right view should mirror when travelling left")

	var distance_per_run := []
	for slow in [1.0, 0.5]:
		actor.position = Vector2.ZERO
		target.position = Vector2(1000, 0)
		actor.set_walk_sheet(dinosaurs, 0, -1, 0.0)
		actor.poison_slow = slow
		var total_phase := 0.0
		for tick in 60:
			var angle: float = actor._wobble
			actor._physics_process(1.0 / 60.0)
			total_phase += fposmod(actor._wobble - angle, TAU)
		distance_per_run.append([actor.position.x, total_phase])
	expect(is_equal_approx(distance_per_run[0][0], distance_per_run[1][0] * 2), "slow halves measured ground distance")
	expect(is_equal_approx(distance_per_run[0][1], distance_per_run[1][1] * 2), "slow halves step count over equal time")
	expect(is_equal_approx(distance_per_run[0][1] / TAU, distance_per_run[0][0] / 14.0), "one complete cycle per stride")

	var wall := StaticBody2D.new()
	wall.collision_layer = 8
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(10,100)
	collider.shape = shape
	wall.add_child(collider)
	wall.position = actor.position + Vector2(30,0)
	root.add_child(wall)
	await physics_frame
	for tick in 120:
		actor._physics_process(1.0 / 60.0)
	var blocked := actor.position
	var phase: float = actor._wobble
	for tick in 20:
		actor._physics_process(1.0 / 60.0)
	expect(actor.position.is_equal_approx(blocked) and actor.velocity.x > 0, "wall blocks an actively chasing enemy")
	expect(is_equal_approx(phase, actor._wobble) and sprite.frame_coords.x == 0, "blocked enemy plants its feet")
	actor.free()
	target.free()
	wall.free()
