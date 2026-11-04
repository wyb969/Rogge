extends SceneTree
var failures: Array[String] = []
func _init() -> void :
	call_deferred("_run")
func _expect(ok: bool, message: String) -> void :
	if not ok: failures.append(message)
func _run() -> void :
	var store: Node = root.get_node("SettingsStore")
	var audio: Node = root.get_node("AudioManager")

	var legacy: = ConfigFile.new()
	legacy.set_value("audio", "ambience", 0.75)
	legacy.save(store.PATH)
	store.load_from_disk()
	store.apply_mix()
	_expect(store.ambience_linear == 0.35 and store.music_linear == 0.55 and store.sfx_linear == 1, "old browser preferences migrate to a quieter environmental mix")
	store.set_ambience_linear(0.6)
	store.set_music_linear(0.4)
	store.set_sfx_linear(0.8)
	store.load_from_disk()
	_expect(store.ambience_linear == 0.6 and store.music_linear == 0.4 and store.sfx_linear == 0.8, "new intentional volume changes survive later reloads without repeated migration")
	for name in ["Music", "SFX", "Ambience"]:
		var bus: = AudioServer.get_bus_index(name)
		_expect(bus >= 0 and AudioServer.get_bus_send(bus) == &"Master", "three independent channels all route through Master")
	for child in audio.get_children():
		if not child is AudioStreamPlayer: continue
		_expect(child.playback_type == AudioServer.PLAYBACK_TYPE_STREAM and child.bus in [&"Music", &"SFX"], "persistent effects and BGM use the same stream mixer on Web")
	for player in audio._juice_players.values():
		_expect(player.bus == &"SFX" and player.max_polyphony == 1 and player.playback_type == AudioServer.PLAYBACK_TYPE_STREAM, "action cues stay bounded and use the effect channel")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	await main._launch_run(&"weather")
	var game: Node = main.game
	game.spawner.timer.stop()
	game.spawner.get_node("Elite").stop()
	for name in ["HandWeapon", "CircleWeapon", "Weapon", "DroneController", "MolotovController", "FreezeController"]:
		game.get_node(name).process_mode = Node.PROCESS_MODE_DISABLED
	game.weather.set_preview(2, 0)
	_expect(game.lightning_ring._audio.bus == &"SFX" and game.lightning_ring._audio.playback_type == AudioServer.PLAYBACK_TYPE_STREAM, "card lightning uses the same effect mixer")
	main._on_setting_button_pressed()
	var page: Node = main.settings_page
	page.music_slider.value = 0
	page.ambience_slider.value = 0
	page.sfx_slider.value = 0.9
	_expect(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")) and AudioServer.is_bus_mute(AudioServer.get_bus_index("Ambience")) and not AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")), "actual settings can silence both backgrounds while leaving gameplay effects audible")
	audio._last_shot_msec = -1000
	audio.play_shoot()
	audio.play_hit()
	audio.play_healing_pickup()
	_expect(audio.shoot_audio_player.playing and audio.hurt_audio_player.playing and audio.healing_pickup_audio_player.playing, "shoot/hurt/heal voices play even with both background channels muted")
	var shot_stamp: int = audio._last_shot_msec
	for _repeat in 100: audio.play_shoot()
	_expect(audio._last_shot_msec == shot_stamp, "same-frame shot storms cannot continuously restart/cut off the short cue")
	page.music_slider.value = 0.55
	page.ambience_slider.value = 0.35
	page.sfx_slider.value = 1
	page.close_page()
	paused = false
	audio.focus_sfx(0.4)
	await create_timer(0.15, true, false, true).timeout
	_expect(audio._music_duck < 0.65 and AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")) < linear_to_db(0.55) - 3, "critical gameplay cues briefly lower music without changing its tempo")
	await create_timer(1.5, true, false, true).timeout
	_expect(audio._music_duck > 0.99, "music smoothly returns after effects finish")
	var env: Node = audio.weather_audio
	for _repeat in 50:
		game.weather.set_preview(_repeat % 4, 0)
		var count: = 0
		for player in env._players:
			if player.playing: count += 1
		_expect(count <= 2, "weather switches never accumulate a stack of background loops")
	game.weather.set_preview(2, 0)
	await create_timer(2.8, true, false, true).timeout
	_expect(env.describe().bed_voices == 1 and env.BED_DB[2] <= -22 and env.BEDS[2].get_length() > 25, "rain settles into one quiet recorded loop")
	store.set_master_linear(0)
	_expect(AudioServer.is_bus_mute(0), "Master mute still covers every channel")
	store.set_master_linear(1)
	main.on_game_over({"victory": false})
	_expect( not env.active and env.describe().bed_voices == 0, "ending the run cancels weather, including a pending crossfade")
	await main._on_game_end_ui_retry_pressed()
	_expect(env.active and env._owner.get_ref() == main.game.weather, "Retry owns only the new run's weather")
	main.show_main_menu()
	if failures.is_empty(): print("AUDIO MIX OK: legacy migration/new settings, independent buses, shared Web stream backend, muted backgrounds/live SFX, bounded cue restarts, music focus/recovery and weather loop ownership")
	else:
		for failure in failures: push_error(failure)
	paused = false
	quit(0 if failures.is_empty() else 1)
