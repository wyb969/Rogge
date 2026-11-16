extends SceneTree
var failures: Array[String] = []
var checks := 0
func _init() -> void: call_deferred("_run")
func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
func active_marks(w: Node) -> int:
	var count := 0
	for mark in w.marks:
		if mark.left > 0: count += 1
	return count
func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	main._on_debug_button_pressed()
	main.debug_page.box.get_node("DebugWinterButton").pressed.emit()
	await process_frame
	await process_frame
	var g: Node = main.game
	g.spawner.timer.stop()
	g.spawner.get_node("Elite").stop()
	g.spawner.set_process(false)
	g.player.set_physics_process(false)
	var weather: Node = g.weather
	weather.set_process(false)
	var w: Node = weather.winter
	w.set_physics_process(false)
	w.set_process(false)
	var bg: Node = g.get_node("InfiniteBackground")
	var original_tint: Color = bg.tint
	expect(weather.current_weather == 3 and bg.snow_cover == 1 and w.visible, "real Debug opens snowy terrain and tracks")
	expect(weather._snow_positions.size() == 64 and weather._snow_field.z_index == 3, "fixed world flake pool now draws a foreground snow layer")
	expect(w.marks.size() == 128 and w.get_child_count() == 0, "tracks use fixed data without per-mark nodes")
	var p: Vector2 = g.player.global_position
	var count: int = w.stamped
	for i in 20: w._observe(p,false)
	expect(w.stamped == count, "standing still produces no snow prints")
	w.clear()
	for i in 10: w._observe(p+Vector2((i+1)*17,0),false)
	expect(active_marks(w) == 10, "movement distance creates ten footsteps")
	for i in 10:
		expect(is_equal_approx(w.marks[i].at.x,p.x+(i+1)*17), "step spacing follows real displacement")
		if i > 0: expect((w.marks[i].at.y-p.y-17)*(w.marks[i-1].at.y-p.y-17)<0, "walking feet alternate left and right")
	var cached: Vector2 = w.marks[0].at
	var camera: Camera2D = g.player.get_node("Camera2D")
	camera.global_position += Vector2(60,20)
	camera.force_update_scroll()
	expect(w.marks[0].at == cached and w.global_transform == Transform2D.IDENTITY, "camera pan cannot move ground marks")
	w.clear()
	g.player.global_position = p
	w._last_at = p
	w.set_physics_process(true)
	g.player._start_dash(Vector2.RIGHT)
	expect(w._dash_mode, "actual dash signal starts snow rut mode")
	for i in 12:
		g.player.global_position += Vector2(9,0)
		w._physics_process(1.0/60)
	g.player.dash_completed.emit(g.player.global_position)
	expect(active_marks(w) >= 12 and not w._dash_mode, "dash path produces sampled grooves and signal closes mode")
	for mark in w.marks:
		if mark.left > 0: expect(mark.dash, "dash marks use groove geometry")
	g.player.reset_dash()
	w.set_physics_process(false)
	var frozen: Vector2 = w.marks[w._slot-1].at
	var previous_count: int = w.stamped
	w._observe(g.player.global_position+Vector2(500,0),false)
	expect(w.stamped == previous_count, "teleports do not draw a line across the map")
	w._last_at = g.player.global_position
	for i in 300: w._observe(w._last_at+Vector2(17,0),false)
	expect(active_marks(w) == 128 and w.marks.size() == 128 and w.get_child_count() == 0, "long walks recycle exactly 128 slots")
	w._process(9)
	expect(active_marks(w) == 0, "old prints completely fade")
	w._observe(w._last_at+Vector2(17,0),false)
	var stamp: float = w.marks[(w._slot+127)%128].left
	paused = true
	await create_timer(0.05,true,false,true).timeout
	expect(w.marks[(w._slot+127)%128].left == stamp, "pause does not age tracks")
	paused = false
	w.clear()
	g.player.global_position = p
	w._last_at = p
	g.player.velocity = Vector2.ZERO
	root.get_node("MobileInput").controls_enabled = false
	g.player.set_physics_process(true)
	w.set_physics_process(true)
	Input.action_press("right")
	var actual_before: int = w.stamped
	for i in 45: await physics_frame
	Input.action_release("right")
	for i in 15: await physics_frame
	expect(w.stamped >= actual_before+3 and g.player.global_position.x > p.x+40, "real keyboard movement leaves distance-sampled prints")
	var still: int = w.stamped
	for i in 15: await physics_frame
	expect(w.stamped == still, "actual idle creates no extra prints")
	g.player.reset_dash()
	g.player._start_dash(Vector2.RIGHT)
	for i in 15: await physics_frame
	var grooves := 0
	for mark in w.marks:
		if mark.left > 0 and mark.dash: grooves += 1
	expect(grooves > 5 and not g.player.dashing, "real dash physics and timer leave grooves without changing dash completion")
	g.player.set_physics_process(false)
	w.set_physics_process(false)
	weather._select(0,false)
	weather._process(1.25)
	expect(bg.snow_cover > 0 and bg.snow_cover < 1 and is_equal_approx(w.coverage,bg.snow_cover), "snow surface and marks fade together during weather transition")
	weather.set_preview(0,0)
	expect(bg.snow_cover == 0 and bg.tint == original_tint and not w.visible and active_marks(w)==0, "clear weather restores original stage palette and clears snow marks")
	var store: Node = root.get_node("SettingsStore")
	var saved: float = store.weather_intensity
	store.set_weather_intensity(0)
	weather.set_preview(3,0)
	expect(bg.snow_cover == 0 and weather.snow_count == 0 and not w.visible, "weather intensity zero disables snow cover, flakes and tracks")
	store.set_weather_intensity(saved)
	weather.set_preview(3,0)
	weather.stop()
	expect(bg.snow_cover == 0 and not w.is_processing() and not w.is_physics_processing(), "weather stop removes winter processing and material uniforms")
	main.show_main_menu()
	await main._launch_run(&"")
	expect(main.game.weather.winter.stamped == 0 and active_marks(main.game.weather.winter)==0 and not main.game.weather._preview, "normal new run does not inherit Debug marks or controls")
	main.show_main_menu()
	if failures.is_empty(): print("WINTER OK: %d checks; snowy Debug/materials, world marks, spacing/alternation, dash signals, teleports, bounded reuse, fade/pause/weather/settings and new run" % checks)
	else:
		for message in failures: push_error(message)
	quit(0 if failures.is_empty() else 1)
