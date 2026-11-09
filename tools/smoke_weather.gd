extends SceneTree
var failures: Array[String] = []
func _init() -> void :
	call_deferred("_run")
func _expect(ok: bool, message: String) -> void :
	if not ok: failures.append(message)
func _run() -> void :
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	_expect( not main.game.weather.running and not main.game.weather._caption.visible, "prepared main menu has no gameplay weather leak")
	main._on_debug_button_pressed()
	main._launch_run(&"weather")
	await process_frame
	await process_frame
	var game: Node = main.game
	var weather: Node = game.weather
	var bg: Node = game.get_node("InfiniteBackground")
	game.spawner.timer.stop()
	game.spawner.get_node("Elite").stop()
	game.player.set_physics_process(false)
	for name in ["HandWeapon", "CircleWeapon", "Weapon", "DroneController", "MolotovController", "FreezeController"]:
		game.get_node(name).process_mode = Node.PROCESS_MODE_DISABLED
	_expect(weather.running and weather._preview.visible and game.player.max_player_health == 50000, "legacy debug preset starts a playable protected weather preview")
	var field_id: int = weather._field.get_instance_id()
	var child_count: int = weather.get_child_count()
	seed(969)
	var expected: = randi()
	seed(969)
	weather.begin_run()
	var seen: = {}
	var last: = -1
	for stage in range(1, 13):
		weather.apply_stage(stage, true)
		var chosen: int = weather.current_weather
		_expect(chosen != last, "adjacent normal stages avoid repeating the same weather")
		if stage <= 4: seen[chosen] = true
		for _repeat in 3: weather.apply_stage(stage)
		_expect(weather.current_weather == chosen, "same-stage notifications preserve their cached weather")
		last = chosen
	_expect(seen.size() == 4 and randi() == expected, "four-weather bag is fresh and isolated from gameplay RNG")
	for stage in range(1, 13):
		var saved: int = weather._stage_profiles[stage]
		weather.apply_stage(stage, true)
		_expect(weather.current_weather == saved, "revisiting a stage restores its cached weather")
	var last_open: = -1
	for _run_id in 40:
		weather.begin_run()
		_expect(weather.current_weather != last_open, "new opening rolls avoid the previous opening")
		last_open = weather.current_weather
	weather.set_preview(weather.Weather.CLEAR, 0)
	var day: Color = weather.ambient
	var day_sun: float = weather.sun_strength
	weather.set_preview(weather.Weather.CLEAR, 0.5)
	_expect(weather.ambient.r < day.r and weather.ambient.g < day.g and weather.sun_strength == 0 and day_sun > 0, "day/night changes scenery light and turns solar shafts off at night")
	var before: float = weather.solar_phase
	weather._process(10)
	_expect( not is_equal_approx(weather.solar_phase, before), "day/night advances with active gameplay")
	paused = true
	var clock: float = weather.elapsed
	await create_timer(0.06, true, false, true).timeout
	_expect(weather.elapsed == clock, "card/rest pauses freeze the weather clock")
	paused = false
	var store: Node = root.get_node("SettingsStore")
	var saved_intensity: float = store.weather_intensity
	store.set_weather_intensity(1)
	game.spawner._boss_fight_active = false
	weather.set_preview(weather.Weather.RAIN, 0)
	_expect(weather.rain_count == 96 and weather.snow_count == 0, "rain uses its fixed bounded drawing pool")
	weather._select(weather.Weather.SNOW, false)
	for _frame in range(60):
		weather._process(0.05)
		_expect(weather.rain_count + weather.snow_count <= 96, "crossfading weather cannot double the particle budget")
	_expect(weather.snow_count == 64 and weather.rain_count == 0, "rain transitions fully into the snow pool")
	game.spawner._boss_fight_active = true
	weather._update_environment()
	_expect(weather.snow_count < 64, "busy boss encounters automatically reduce precipitation density")
	game.spawner._boss_fight_active = false
	for kind in range(4):
		for phase in [0.0, 0.125, 0.25, 0.5, 0.75]:
			weather.set_preview(kind, phase)
			_expect(weather.ambient.r <= 1 and weather.ambient.g <= 1 and weather.ambient.b <= 1, "scenery multiplier stays within the established floor-contrast bound")
			_expect(game.player.modulate == Color.WHITE and game.effect_container.modulate == Color.WHITE and weather._field.z_index < 0, "weather cannot recolor or cover actors, attack warnings or pickups")
	var atlas_ids: = []
	for atlas in bg._decor_atlases: atlas_ids.append(atlas.get_instance_id())
	for _frame in 30: bg._update_coverage()
	_expect(bg._decor_atlases.size() == 6 and atlas_ids == bg._decor_atlases.map( func(atlas): return atlas.get_instance_id()), "background decorations reuse six atlases instead of reallocating them each frame")
	for _change in 100:
		weather.set_preview(_change % 4, fmod(_change * 0.1, 1))
	_expect(weather._rain.size() == 96 and weather._snow.size() == 64 and weather.get_child_count() == child_count and weather._field.get_instance_id() == field_id, "weather switches reuse fixed data and scene nodes")
	main._on_setting_button_pressed()
	main.settings_page.weather_slider.value = 0
	store.weather_intensity = 1
	store.load_from_disk()
	weather.set_preview(weather.Weather.RAIN, 0)
	_expect(store.weather_intensity == 0 and weather.rain_count == 0 and weather.sun_strength == 0 and weather.cloud_strength == 0, "real weather FX slider persists and disables rain/sun/cloud decoration")
	main.settings_page.close_page()
	store.set_weather_intensity(saved_intensity)
	for size in [Vector2i(390, 844), Vector2i(900, 500)]:
		root.size = size
		await process_frame
		await process_frame
		var bounds: = Rect2(Vector2.ZERO, root.get_visible_rect().size)
		_expect(bounds.encloses(weather._caption.get_global_rect()), "weather/time caption stays inside the viewport")
		for button in weather._buttons.get_children():
			_expect(bounds.encloses(button.get_global_rect()), "all preview buttons fit both orientations")
		var touch: = InputEventScreenTouch.new()
		touch.pressed = true
		touch.position = weather._buttons.get_child(0).get_global_rect().get_center()
		_expect( not main.mobile_controls._handle_touch(touch), "touch joystick yields to weather preview controls")
	weather._buttons.get_child(2).pressed.emit()
	_expect(main.menu_page.visible and paused and not weather.running and not weather._caption.visible and not weather._field.visible, "preview Back fully clears weather and returns to the original menu")
	if failures.is_empty(): print("WEATHER OK: legacy preset/settings/touch/Back, per-stage cached nonrepeating weather, independent RNG, continuous paused-safe solar cycle, bounded rain/snow crossfades, protected combat colors/layers, shared atlases and lifecycle")
	else:
		for failure in failures: push_error(failure)
	paused = false
	quit(0 if failures.is_empty() else 1)
