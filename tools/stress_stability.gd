extends SceneTree

func _init() -> void :
	call_deferred("_run")
func _run() -> void :
	var seconds: = 180.0
	var speed: = 6.0
	var path: = "user://rogge-stability-soak.json"
	var weather_kind: = -1
	var moving: = false
	for arg in OS.get_cmdline_user_args():
		if arg == "--moving": moving = true
		if arg.begins_with("--seconds="): seconds = float(arg.split("=")[1])
		if arg.begins_with("--speed="): speed = float(arg.split("=")[1])
		if arg.begins_with("--report="): path = arg.trim_prefix("--report=")
		if arg.begins_with("--weather="): weather_kind = clampi(int(arg.split("=")[1]), 0, 3)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	await main._launch_run(&"stability")
	var test: Node = main.game.get_node("StabilityTest")
	if weather_kind >= 0:
		main.game.weather.set_preview(weather_kind)
	test.duration = seconds
	Engine.time_scale = speed
	var last: = Time.get_ticks_msec()
	while not test._done:
		await process_frame
		if moving:
			var input: Node = root.get_node("MobileInput")
			input.controls_enabled = true
			input.set_move_vector(Vector2.from_angle(test.elapsed * 0.5))
		if paused and not test._done:
			push_error("Stress fixture paused before completion; inspect boss/reward state in diagnostics")
			quit(1)
			return
		if Time.get_ticks_msec() - last >= 2000:
			last = Time.get_ticks_msec()
			print("STABILITY SAMPLE ", JSON.stringify({"elapsed": test.elapsed, "nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT), "effects": main.game.effect_container.get_child_count(), "pickups": main.game.pickup_container.get_child_count(), "books": main.game.circle_weapon.get_child_count()}))
		if main.game.circle_weapon.get_child_count() > 12 or Performance.get_monitor(Performance.OBJECT_NODE_COUNT) > 12000:
			push_error("Soak exceeded its safety bound")
			quit(1)
			return
	var diag: Node = root.get_node("RunDiagnostics")
	print("STABILITY PEAKS ", JSON.stringify(diag.report.peaks))
	var file: = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Unable to save soak report")
		quit(1)
		return
	file.store_string(JSON.stringify(diag.latest(), "\t"))
	file.close()
	test.stop()
	await process_frame
	await process_frame
	print("STABILITY SOAK OK: ", seconds, " simulated seconds; report ", path)
	paused = false
	quit()
