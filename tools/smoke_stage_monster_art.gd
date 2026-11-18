extends SceneTree

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func expect(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func _run() -> void:
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
				actor._apply_move_juice(1.0 / 60.0)
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
		print("PASS stage monster art: six stages, normal and elite spawns, four gait poses, all seven rosters")
	else:
		push_error(str(failures.slice(0, 10)))
	quit(0 if failures.is_empty() else 1)
