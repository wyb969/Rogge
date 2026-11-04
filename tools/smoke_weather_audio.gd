extends SceneTree

var failures: Array[String] = []
var audio: Node
var ambience: Node
func _init() -> void :
	call_deferred("_run")
func _expect(ok: bool, message: String) -> void :
	if not ok: failures.append(message)
func _advance(seconds: float) -> void :
	for _i in int(ceil(seconds / 0.05)):
		ambience._last_tick = Time.get_ticks_msec() - 50
		ambience._process(0.0001)
func _beds() -> int:
	var count: = 0
	for player in ambience._players:
		if player.playing: count += 1
	return count
func _run() -> void :
	audio = root.get_node("AudioManager")
	ambience = audio.weather_audio
	var store: Node = root.get_node("SettingsStore")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	_expect( not ambience.active and _beds() == 0, "menu has no leaked weather voices")
	main._on_debug_button_pressed()
	main.get_node("mainUI/Control/DebugCenter/VBoxContainer/DebugWeatherButton").pressed.emit()
	await process_frame
	await process_frame
	var game: Node = main.game
	var weather: Node = game.weather
	game.spawner.timer.stop()
	game.spawner.get_node("Elite").stop()
	game.player.set_physics_process(false)
	for name in ["HandWeapon", "CircleWeapon", "Weapon", "DroneController", "MolotovController", "FreezeController"]:
		game.get_node(name).process_mode = Node.PROCESS_MODE_DISABLED
	_expect(weather.running and ambience.active and ambience._owner.get_ref() == weather, "real protected weather preview binds its run audio")
	_expect(ambience.get_child_count() == 3, "exactly two bed voices and one event voice are allocated")
	for player in ambience.get_children():
		_expect(player.playback_type == AudioServer.PLAYBACK_TYPE_STREAM and player.max_polyphony == 1 and player.bus == "Ambience", "stream gain supports Web fades without extra polyphony")
	for stream in ambience.BEDS:
		_expect(stream is AudioStreamOggVorbis and stream.loop and stream.get_length() >= 16, "compact long beds loop without timers")
	for stream in ambience.BIRDS + ambience.THUNDER + [ambience.OWL]:
		_expect( not stream.loop and stream.get_length() < 6, "calls and thunder cannot loop endlessly")
	seed(968)
	var expected: = randi()
	seed(968)
	weather.set_preview(0, 0)
	_advance(3)
	_expect(ambience._last_event == "birds" and _beds() == 1, "clear daylight produces birds over a settled air bed")
	var current: int = ambience._current
	var count: int = ambience._event_count
	var next: float = ambience._next_event
	for _repeat in 30: weather._update_environment()
	_expect(ambience._current == current and ambience._event_count == count and ambience._next_event == next, "30 Hz lighting sync never restarts beds or resets call scheduling")
	var intervals: = {}
	for _repeat in 30:
		var interval: float = ambience._interval(false)
		_expect(interval >= 4 and interval <= 9, "bird spacing stays sparse")
		intervals[snappedf(interval, 0.1)] = true
	_expect(intervals.size() > 3, "event timing varies instead of mechanically looping calls")
	weather._buttons.get_child(1).pressed.emit()
	_advance(5)
	_expect(weather.daylight < 0.18 and ambience._last_event == "owl", "real day/night control replaces day birds with sparse quiet night calls")
	for kind in range(4):
		weather.set_preview(kind, 0)
		_advance(3)
		_expect(ambience.kind == kind and ambience._players[ambience._current].stream == ambience.BEDS[kind] and _beds() == 1, "each weather settles on its own single bed")
	for _repeat in 50:
		weather._buttons.get_child(0).pressed.emit()
		_advance(0.1)
		_expect(_beds() <= 2 and ambience.get_child_count() == 3, "rapid real next-weather taps reuse fixed voices")
	_advance(3)
	_expect(_beds() == 1 and randi() == expected, "crossfade settles and audio choices preserve gameplay RNG")
	weather.set_preview(2, 0)
	ambience._event.stop()
	ambience._next_event = 0.5
	paused = true
	count = ambience._event_count
	_advance(4)
	_expect(ambience._event_count == count and ambience._next_event == 0.5 and ambience._context_gain < 0.56, "card/rest pause quiets beds and freezes new thunder")
	paused = false
	_advance(1)
	_expect(ambience._event_count == count + 1 and ambience._last_event == "thunder" and ambience._next_event >= 15, "unpause resumes a single randomly spaced thunder voice")
	weather.set_preview(3, 0)
	_advance(0.4)
	_expect( not ambience._event.playing, "leaving rain fades out its current thunder")
	count = ambience._event_count
	_advance(8)
	_expect(ambience._event_count == count, "snow never starts stale rain thunder")
	audio.play_boss_bgm(4)
	_advance(3)
	_expect(ambience.active and ambience._context_gain < 0.49 and audio.boss_audio_player.playing, "boss music keeps weather but ducks it under combat")
	audio.play_game_bgm(4)
	Engine.time_scale = 0.08
	weather.set_preview(1, 0)
	await create_timer(2.8, true, false, true).timeout
	_expect(_beds() == 1 and ambience._context_gain > 0.99, "real-time fade ignores combat hit-stop without changing BGM tempo")
	Engine.time_scale = 1
	var bus: = AudioServer.get_bus_index("Ambience")
	store.set_ambience_linear(0.32)
	store.ambience_linear = 1
	store.load_from_disk()
	store.apply_ambience_audio()
	_expect(is_equal_approx(store.ambience_linear, 0.32) and absf(AudioServer.get_bus_volume_db(bus) - linear_to_db(0.32)) < 0.01, "independent environment volume persists and reaches its bus")
	store.set_weather_intensity(0)
	store.set_ambience_linear(0)
	_expect(AudioServer.is_bus_mute(bus) and _beds() == 1, "ambience mute retains playback position")
	store.set_ambience_linear(0.75)
	_expect( not AudioServer.is_bus_mute(bus) and ambience.active, "zero visual FX does not disable weather audio")
	store.set_master_linear(0)
	_expect(AudioServer.is_bus_mute(0) and AudioServer.get_bus_send(bus) == &"Master", "master mute also covers environment bus")
	store.set_master_linear(1)
	store.set_weather_intensity(1)

	ambience.stop()
	ambience._playback_allowed = false
	ambience.bind_environment(weather, 2, 1)
	_advance(3)
	_expect(ambience.active and _beds() == 0 and not ambience._event.playing, "locked browser prepares rain silently")
	audio.unlock_web_audio()
	_advance(3)
	_expect(_beds() == 1 and ambience._players[ambience._current].stream == ambience.BEDS[2], "first real gesture resumes only the selected weather bed")
	var other: = Node.new()
	root.add_child(other)
	ambience.detach(other)
	_expect(ambience.active, "an unrelated or stale run cannot detach current audio")
	other.free()
	weather._buttons.get_child(2).pressed.emit()
	_expect( not ambience.active and _beds() == 0 and not ambience._event.playing and audio.menu_audio_player.playing, "real preview Back stops all ambience and returns menu music")
	await main._launch_run(&"weather")
	var previous: Node = main.game.weather
	main.on_game_over({"victory": false})
	_expect( not ambience.active, "result screen cancels weather audio")
	await main._on_game_end_ui_retry_pressed()
	_expect(ambience.active and ambience._owner.get_ref() == main.game.weather and main.game.weather != previous, "Retry owns fresh weather audio after old run teardown")
	main.game.end_game()
	audio.unlock_web_audio()
	_expect( not ambience.active and _beds() == 0, "late browser gesture cannot resurrect an ended run")
	main.show_main_menu()
	if failures.is_empty(): print("WEATHER AUDIO OK: four weather beds, day/night calls, thunder timing, real preview, bounded stream crossfades, pause/boss mix, RNG, volume, unlock, Back/result/Retry ownership")
	else:
		for failure in failures: push_error(failure)
	paused = false
	quit(0 if failures.is_empty() else 1)
