extends SceneTree

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func _mouse(point: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	root.push_input(event, true)

func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	var game: Node = main.game
	var zoom: Vector2 = game.player.get_node("Camera2D").zoom
	main._on_debug_button_pressed()
	var link: Button = main.debug_page.entries[0]
	check(link.name == "DebugSpriteScaleButton", "test reachable on the first debug page")
	link.pressed.emit()
	var page: Control = main.get_node("mainUI/Control/SpriteScaleTest")
	await process_frame
	check(paused and not game.visible and page.specimen.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "preview runs in the paused menu with combat's sampler")
	var prototype: Node = game.spawner.enemy.instantiate()
	for series in page.Families.size():
		page.family.select(series)
		for row in 10:
			page.species.select(row)
			page.species.item_selected.emit(row)
			var slot: int = page.Art.SPECIES[series].find(row + 1)
			if slot >= 8: slot -= 8
			for data in game.spawner.enemy_array:
				if page.Art.ROLE_SLOT.get(data.title) != slot: continue
				prototype.set_enemy_data(data)
				prototype.set_walk_sheet(page.Art.SHEETS[series], row, page.Art.SOURCE_FACING[series][row], 0)
				var live: Sprite2D = prototype.get_node("Sprite2D")
				check(page.specimen.texture == live.texture and page.specimen.get_rect().size == live.get_rect().size and page.specimen.scale.is_equal_approx(live.scale * prototype.scale * zoom), "combat size and texture for %d/%d" % [series,row])
	prototype.free()
	page.play.button_pressed = true
	var still: int = page.specimen.frame
	page._process(0.4)
	check(still == page.specimen.frame, "pause locks exact animation frame")
	page.play.button_pressed = false
	page._process(0.2)
	check(still != page.specimen.frame, "play resumes the authored walk")
	for dims in [Vector2i(390,844), Vector2i(844,390), Vector2i(320,568)]:
		root.size = dims
		await process_frame
		await process_frame
		var slider: HSlider = page.sliders[0]
		var bounds := root.get_visible_rect()
		check(bounds.encloses(slider.get_global_rect()) and bounds.encloses(page.play.get_global_rect()) and page.field.size.y > 64, "usable portrait and landscape controls")
		var rect := slider.get_global_rect()
		var a := rect.position + rect.size * Vector2(0.1,0.5)
		var b := rect.position + rect.size * Vector2(0.81,0.5)
		_mouse(a, true)
		var motion := InputEventMouseMotion.new()
		motion.position = b
		motion.relative = b - a
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(motion, true)
		_mouse(b, false)
		check(slider.value > 3.0 and slider.value < 3.9, "actual drag moves slider")
	var monster_factor: float = page.sliders[0].value
	page.boss_tab.pressed.emit()
	for i in page.BossIds.size():
		page.encounter.select(i)
		page.encounter.item_selected.emit(i)
		check(page.specimen.texture.resource_path.ends_with("/%s/poses.png" % page.BossIds[i]), "boss combat atlas %d" % i)
	var baseline: Vector2 = page.specimen.scale
	page.sliders[1].value = 2.0
	check(page.specimen.scale.is_equal_approx(baseline * 2), "boss slider doubles the displayed sprite")
	page.reset_scale()
	check(page.specimen.scale.is_equal_approx(baseline) and page.sliders[0].value == monster_factor, "reset leaves the other slider alone")
	page.closed.emit()
	await process_frame
	check(paused and main.debug_page.visible and main.game == game and get_node_count_in_group("EnemyGroup") == 0, "return retains menu state and no combat actors")
	main._on_debug_back_pressed()
	await main._launch_run(&"")
	check(main.game == game and not paused and game.player.get_node("Camera2D").zoom == zoom, "normal play retains its exact camera and world")
	if failures.is_empty(): print("SPRITE SCALE OK: 80 monsters, 8 boss atlases, physical drag, independent scales, frozen poses, layouts, and normal entry")
	for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
