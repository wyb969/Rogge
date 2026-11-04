extends SceneTree

var _main: Node
var _results: = []
var _output: = "/workspace/artifacts/runtime-baseline.json"
var _case_seconds: = 4.0
var _project_viewport: = false
func _init() -> void :
	call_deferred("_run")
func _percentile(values: Array, fraction: float) -> float:
	values.sort()
	return float(values[mini(values.size() - 1, int((values.size() - 1) * fraction))]) if not values.is_empty() else 0.0
func _case(game: Node, name: String, kind: int, viewport_mode: bool = false, lighting: bool = true, precipitation: bool = true) -> void :
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT if viewport_mode or _project_viewport else Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	game.weather.set_preview(kind, 0)
	var bg: Node = game.get_node("InfiniteBackground")
	if not lighting:
		bg.set_environment_light(Color.WHITE, 0, Vector2.RIGHT, 0, 0)
		game.weather.set_process(false)
	if not precipitation: game.weather._field.hide()
	await create_timer(0.8, true, false, true).timeout
	var wall: = []
	var process: = []
	var physics: = []
	var draw: = []
	var nodes: = []
	var stamp: = Time.get_ticks_usec()
	var deadline: = stamp + int(_case_seconds * 1000000)
	while Time.get_ticks_usec() < deadline:
		await process_frame
		var now: = Time.get_ticks_usec()
		wall.append(float(now - stamp) / 1000)
		stamp = now
		process.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000)
		physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000)
		draw.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		nodes.append(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var result: = {"case": name, "window": root.size, "render_size": root.get_texture().get_size(), "image_pixels": root.get_texture().get_image().get_size(), "logical_size": root.get_visible_rect().size, "content_factor": root.content_scale_factor, "frame_p50_ms": _percentile(wall, 0.5), "frame_p95_ms": _percentile(wall, 0.95), "frame_p99_ms": _percentile(wall, 0.99), "process_p50_ms": _percentile(process, 0.5), "process_p95_ms": _percentile(process, 0.95), "physics_p95_ms": _percentile(physics, 0.95), "draw_p50": _percentile(draw, 0.5), "nodes_p95": _percentile(nodes, 0.95), "video_bytes": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED), "static_bytes": Performance.get_monitor(Performance.MEMORY_STATIC)}
	_results.append(result)
	print("RUNTIME BENCH ", JSON.stringify(result))
	game.weather.set_process(true)
	game.weather._field.show()
func _run() -> void :
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): _output = arg.trim_prefix("--output=")
		if arg.begins_with("--seconds="): _case_seconds = float(arg.trim_prefix("--seconds="))
	Engine.max_fps = 0
	_project_viewport = ProjectSettings.get_setting("display/window/stretch/mode") == "viewport"
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size = Vector2i(1920, 1080)
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)
	current_scene = _main
	await process_frame
	await process_frame
	await _main._launch_run(&"weather")
	var game: Node = _main.game
	game.spawner.timer.stop()
	game.spawner.get_node("Elite").stop()
	game.player.set_physics_process(false)
	for name in ["HandWeapon", "CircleWeapon", "Weapon", "DroneController", "MolotovController", "FreezeController"]:
		game.get_node(name).process_mode = Node.PROCESS_MODE_DISABLED
	await _case(game, "empty-clear", 0)
	await _case(game, "empty-rain", 2)
	await _case(game, "empty-snow", 3)
	await _case(game, "rain-no-lighting", 2, false, false)
	await _case(game, "rain-no-particles", 2, false, true, false)
	await _case(game, "rain-viewport", 2, true)
	await _case(game, "snow-viewport", 3, true)
	var background: Node = game.get_node("InfiniteBackground")
	var start: = Time.get_ticks_usec()
	for _i in 1000: background._update_coverage()
	var coverage_us: = float(Time.get_ticks_usec() - start) / 1000

	for _i in 256: game._spawn_xp_coin_now(Vector2(600 + _i, 600), 2)
	game.player.monster_necklace_level = 1
	for _i in 96: game.spawn_necklace_orb(Vector2(600 + _i, 600))
	start = Time.get_ticks_usec()
	for _i in 200: game._spawn_xp_coin_now(Vector2(620, 610), 2)
	var coin_us: = float(Time.get_ticks_usec() - start) / 200
	start = Time.get_ticks_usec()
	for _i in 200: game.spawn_necklace_orb(Vector2(620, 610))
	var orb_us: = float(Time.get_ticks_usec() - start) / 200
	var micro: = {"coverage_us_per_call": coverage_us, "coin_merge_us_per_call": coin_us, "orb_merge_us_per_call": orb_us}
	print("RUNTIME MICRO ", JSON.stringify(micro))
	for item in [[0, "pressure-clear"], [2, "pressure-rain"], [3, "pressure-snow"]]:
		await _main._launch_run(&"stability")
		game = _main.game
		game.get_node("StabilityTest").duration = 1000
		await _case(game, item[1], item[0])
	var file: = FileAccess.open(_output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"cases": _results, "micro": micro}, "\t"))
	_main.show_main_menu()
	print("RUNTIME BENCH OK ", _output)
	paused = false
	quit()
