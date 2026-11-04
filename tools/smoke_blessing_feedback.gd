extends SceneTree
var failures: Array[String] = []
func _init() -> void : call_deferred("_run")
func _expect(ok: bool, message: String) -> void :
	if not ok: failures.append(message)
func _run() -> void :
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	await main._launch_run(&"")
	var game: Node = main.game
	game.diagnostic_mode = "blessing_test"
	game.spawner.set_process(false)
	game.spawner.timer.stop()
	game.spawner.get_node("Elite").stop()
	game.player.set_physics_process(false)
	for name in ["HandWeapon", "CircleWeapon", "Weapon", "DroneController", "MolotovController", "FreezeController"]:
		game.get_node(name).process_mode = Node.PROCESS_MODE_DISABLED
	var powers: Node = game.beast_powers
	powers.set_process(false)
	var audio: Node = root.get_node("AudioManager")
	var sound_nodes: = audio.get_child_count()
	var ui_nodes: int = powers._canvas.get_child_count()
	for i in 4: powers.unlock(i)
	for voice in audio._beast_players:
		_expect(voice.bus == "SFX" and voice.playback_type == AudioServer.PLAYBACK_TYPE_STREAM and voice.max_polyphony == 1, "each cached skill voice uses the existing Safari-compatible SFX mixer")
	var streams: = {}
	for i in 4:
		streams[audio._beast_players[i].stream.resource_path] = true
		game.player.player_health = game.player.max_player_health * 0.4
		if i == 2: game._spawn_xp_coin_now(Vector2(8000, 6000), 2)
		var cues: int = audio.beast_cues_played[i]
		var casts: int = powers.blessing_fx.casts_started
		_expect(powers.cast(i), "each earned power casts through its actual gameplay path")
		_expect(powers.blessing_fx.kind == i and powers.blessing_fx.casts_started == casts + 1 and audio.beast_cues_played[i] == cues + 1, "one successful cast selects its own rune and own sound exactly once")
		_expect( not powers.cast(i) and powers.blessing_fx.casts_started == casts + 1 and audio.beast_cues_played[i] == cues + 1, "cooldown taps cannot replay feedback")
		powers._process(0.055)
		var rising: float = powers._screen_veil.color.a
		_expect(rising > 0 and rising < 0.035, "green picture tint fades in instead of hard flashing")
		powers._process(0.1)
		var peak: float = powers._screen_veil.color.a
		_expect(peak > rising and peak <= 0.0351, "screen tint remains faint and bounded")
		powers._process(0.37)
		_expect(powers._screen_veil.color.a < peak, "the same picture tint fades out")
		paused = true
		var age: float = powers.blessing_fx.age
		powers._process(1)
		_expect(powers.blessing_fx.age == age and not powers.cast(i), "reward pauses freeze skill feedback and reject new casts")
		paused = false
		powers._process(0.4)
		_expect(powers.blessing_fx.opacity() == 0 and powers._screen_veil.color.a == 0, "a finished blessing leaves no veil or continuous glow")
	_expect(streams.size() == 4 and audio.get_child_count() == sound_nodes and powers._canvas.get_child_count() == ui_nodes, "four distinct sounds and a reusable screen layer allocate no per-cast audio/UI nodes")
	_expect(powers._screen_veil.mouse_filter == Control.MOUSE_FILTER_IGNORE and game.damage_flash.layer > powers._canvas.layer, "the green fade cannot steal input or cover the stronger red hurt warning")
	powers.cooldowns[0] = 0
	game.player.player_health = game.player.max_player_health
	var cues_before: Array = audio.beast_cues_played.duplicate()
	var casts_before: int = powers.blessing_fx.casts_started
	_expect( not powers.cast(0) and powers.blessing_fx.casts_started == casts_before and audio.beast_cues_played == cues_before, "a full-health healing no-op has no sound or false blessing")
	game.clear_run_objects()
	await process_frame
	await process_frame
	powers.cooldowns[2] = 0
	_expect( not powers.cast(2) and powers.blessing_fx.casts_started == casts_before and audio.beast_cues_played == cues_before, "an empty-map gather no-op also has no false feedback")
	var effect_nodes: = powers.get_child_count()
	for i in 500:
		powers.blessing_fx.play(i % 4)
		powers._process(0.02)
	_expect(powers.get_child_count() == effect_nodes and powers._canvas.get_child_count() == ui_nodes and powers._screen_veil.color.a <= 0.0351, "rapid stacked cosmetic activations replace one aura and never stack screen brightness or nodes")
	main.show_main_menu()
	_expect(powers.blessing_fx.opacity() == 0 and powers._screen_veil.color.a == 0, "return hides and resets every blessing effect")
	var stopped: = true
	for voice in audio._beast_players: stopped = stopped and not voice.playing
	_expect(stopped, "return stops short skill cues without cutting music or other SFX")
	await main._launch_run(&"blessings")
	_expect(main.game.beast_powers.unlocked.size() == 4 and main.game._healing_actors.size() > 0 and main.game._xp_actors.size() > 0, "actual blessing Debug equips all four skills and supplies a map-wide pickup target")
	main.show_main_menu()
	if failures.is_empty(): print("BLESSING FEEDBACK OK: real four skill casts, distinct cached stream SFX, green fade-in/out, cooldown/no-op/pause, input/red hurt priority, 500 bounded replacements and teardown")
	else:
		for message in failures: push_error(message)
	paused = false
	quit(0 if failures.is_empty() else 1)
