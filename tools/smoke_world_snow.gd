extends SceneTree
var failures: Array[String] = []
func _init() -> void : call_deferred("_run")
func expect(ok: bool, message: String) -> void :
	if not ok: failures.append(message)
func _run() -> void :
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	await main._launch_run(&"weather")
	var game: Node = main.game
	game.player.set_physics_process(false)
	game.spawner.set_process(false)
	game.spawner.timer.stop()
	var weather: Node = game.weather
	weather.set_process(false)
	weather.set_preview(3, 0)
	weather._process(0.1)
	var camera: Camera2D = game.player.get_node("Camera2D")
	camera.position_smoothing_enabled = false
	camera.force_update_scroll()
	var snow_id: int = weather._snow_field.get_instance_id()
	var before: PackedVector2Array = weather._snow_positions.duplicate()
	var canvas_before: = root.get_canvas_transform()
	camera.global_position += Vector2(68, -35)
	camera.force_update_scroll()
	var canvas_after: = root.get_canvas_transform()

	expect(weather._snow_field.global_transform == Transform2D.IDENTITY, "snow never receives the inverse-camera transform of screen-space rain")
	for i in before.size():
		expect(weather._snow_positions[i] == before[i], "camera-only movement cannot move a cached world flake")
		var shift: Vector2 = canvas_after * before[i] - canvas_before * before[i]
		expect(shift.distance_to((canvas_after.origin - canvas_before.origin)) < 0.001, "snow receives full world-camera displacement, including between 30-Hz redraws")
	weather._redraw_left = 0
	weather._process(0)
	var bounds: Rect2 = weather._snow_bounds()
	var preserved: = 0
	for i in before.size():
		if bounds.has_point(before[i]):
			preserved += 1
			expect(weather._snow_positions[i].distance_to(before[i]) < 0.001, "on-screen flakes stay fixed when offscreen wrapping follows the camera")
	expect(preserved > 40, "camera pan keeps most of the same world flakes")
	before = weather._snow_positions.duplicate()
	var clock: float = weather.elapsed
	weather._redraw_left = 0
	weather._process(0.1)
	for i in before.size():
		var seed: Vector4 = weather._snow[i]
		var expected: Vector2 = before[i] + Vector2((10 + seed.z * 12) * 0.1 + (sin((clock + 0.1) * 0.7 + seed.w * TAU) - sin(clock * 0.7 + seed.w * TAU)) * 14, (32 + seed.z * 42) * 0.1) / camera.zoom
		expected = bounds.position + (expected - bounds.position).posmodv(bounds.size)
		expect(expected.distance_to(weather._snow_positions[i]) < 0.001, "flake movement comes only from its wind/sway/fall velocity")
	for size in [Vector2i(390, 844), Vector2i(1170, 2532), Vector2i(1920, 1080)]:
		root.size = size
		await process_frame
		await process_frame
		camera.force_update_scroll()
		weather._redraw_left = 0
		weather._process(0)
		expect(weather._snow_field.get_instance_id() == snow_id and weather._snow_positions.size() == 64, "orientation/Retina reuse the same world field and fixed flake pool")
		for point in weather._snow_positions: expect(weather._snow_bounds().grow(0.01).has_point(point), "wrapped flakes cover the current world-space viewport")
	paused = true
	clock = weather.elapsed
	await create_timer(0.06, true, false, true).timeout
	expect(weather.elapsed == clock, "reward pauses cannot move the world snow")
	paused = false
	main.show_main_menu()
	expect( not weather._field.visible and not weather._snow_field.visible, "return hides rain and world snow together")
	if failures.is_empty(): print("WORLD SNOW OK: camera/subframe independence, exact wind/fall, only offscreen recycling, portrait/Retina reuse, pause and return")
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
