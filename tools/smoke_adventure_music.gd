extends SceneTree

var failures: Array[String] = []
var audio: Node
var music: Node

func _init() -> void :
	call_deferred("_run")

func _settle() -> void :
	if music._fade != null:
		var tween: Tween = music._fade
		tween.custom_step(2.0)

func _normal_playing() -> int:
	var count: = 0
	for player in music._players:
		if player.playing:
			count += 1
	return count

func _run() -> void :
	audio = root.get_node("AudioManager")
	music = audio.adventure_music
	for player in music._players:
		_expect(player.playback_type == AudioServer.PLAYBACK_TYPE_STREAM, "long music uses stream playback for accurate web timing and fades")
	_expect(music.TRACKS.size() == 8, "eight new songs are available")
	var titles: = {}
	for track in music.TRACKS:
		var stream: AudioStream = track.stream
		_expect(stream is AudioStreamOggVorbis and not stream.loop, "songs use compact, nonlooping Ogg streams for playlist rotation")
		_expect(absf(stream.get_length() - 48.0) < 0.08, "each 32-bar arrangement matches the knight boss's 160 BPM without playback pitch shifting")
		titles[track.title] = true
	_expect(titles.size() == 8, "songs have distinct reviewable names")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	main._on_debug_button_pressed()
	var prepared_game: Node = main.game
	var button: Button = main.get_node("mainUI/Control/DebugCenter/VBoxContainer/DebugMusicButton")
	for index in range(8):
		button.pressed.emit()
		_expect(music.preview_mode and music.track_index == index and button.text.contains(music.title()), "real Debug button auditions each named song")
		_expect(main.game == prepared_game and paused and main.debug_page.visible, "preview does not start/replace a run or unpause")
		_expect(_normal_playing() <= 2, "rapid next-song taps cannot create extra music voices")
		_settle()
		_expect(_normal_playing() == 1, "crossfade settles to exactly one normal track")
	main._on_debug_back_pressed()
	_expect(audio.menu_audio_player.playing and _normal_playing() == 0 and not music.active, "Back restores menu music and cancels audition")


	seed(969)
	var expected: = randi()
	seed(969)
	audio.play_game_bgm(1, true)
	_expect(randi() == expected, "playlist choices do not consume gameplay RNG")
	var before_stale: int = music.track_index
	music._current.finished.emit()
	_expect(music.track_index == before_stale, "a stale finished notification cannot skip a newly playing song")
	var seen: = {}
	var last: = -1
	for turn in range(12):
		_settle()
		_expect(music.track_index in [0, 6, 7] and music.track_index != last, "stage-one bag never repeats the preceding song")
		seen[music.track_index] = true
		last = music.track_index
		if turn == 2:
			_expect(seen.size() == 3, "the first bag plays all three songs before recycling")
		music._current.stop()
		music._current.finished.emit()
	for stage in range(2, 7):
		audio.play_game_bgm(stage)
		_expect(music.stage == stage and music.track_index == stage - 1, "stage %d starts its own theme" % stage)
		var selected: AudioStreamPlayer = music._current
		var bag_size: int = music._bag.size()
		audio.play_game_bgm(stage)
		_expect(music._current == selected and music._bag.size() == bag_size, "duplicate stage notifications do not restart or skip songs")
		_settle()



	audio.play_game_bgm(1, true)
	_settle()
	audio.play_game_bgm(3)
	_settle()
	var selected: AudioStreamPlayer = music._current
	music._allow_play = false
	selected.stop()
	audio._resume_desired_bgm(true)
	_expect(music._current == selected and selected.playing and _normal_playing() == 1, "browser audio resume restarts only the selected song/player")
	music.stop()
	music.play_stage(2, true, false)
	_expect(_normal_playing() == 0 and music.active, "locked audio prepares its song without autoplay")
	audio._resume_desired_bgm(true)
	_expect(_normal_playing() == 1, "first gesture resumes the prepared song")
	audio.play_game_bgm(1, true)
	_settle()
	var before_auto: int = music.track_index
	music._current.seek(music._current.stream.get_length() - 0.5)
	await create_timer(0.2, true, false, true).timeout
	_expect(music.track_index != before_auto, "real playback near the end starts the next song before silence")
	_settle()
	audio.play_game_bgm(3)
	Engine.time_scale = 0.08
	await create_timer(1.65, true, false, true).timeout
	_expect(music._fade == null and _normal_playing() == 1 and is_equal_approx(music._current.volume_db, music.VOLUME_DB), "crossfade completes in real time through pause and heavy hitstop")
	Engine.time_scale = 1.0

	audio.play_game_bgm(1, true)
	audio.play_game_bgm(4)
	audio.play_boss_bgm(4)
	await create_timer(1.65, true, false, true).timeout
	_expect(_normal_playing() == 0 and audio.boss_audio_player.playing and audio.boss_audio_player.stream.resource_path.ends_with("beast_thunder_8bit.wav"), "boss entry cancels every normal voice and stale crossfade")
	audio.play_game_bgm(4)
	_settle()
	_expect(music.stage == 4 and not audio.boss_audio_player.playing, "post-boss/interlude music keeps the current stage context")
	var store: Node = root.get_node("SettingsStore")
	store.set_master_linear(0)
	_expect(AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")) and _normal_playing() == 1, "master mute affects music without resetting the playlist")
	store.set_master_linear(1)
	audio.play_game_over()
	audio.unlock_web_audio()
	_expect(_normal_playing() == 0 and not audio.menu_audio_player.playing and not audio.boss_audio_player.playing, "result/gesture cannot resurrect stopped BGM")
	audio.play_menu_bgm()
	await main._launch_run(&"")
	_expect(music.active and not music.preview_mode and music.stage == 1, "a real new run resets the audition/stage context")
	var first: int = music.track_index
	main.on_game_over({"victory": false})
	await main._on_game_end_ui_retry_pressed()
	_expect(music.active and music.stage == 1 and music.track_index != first, "Retry begins a fresh nonrepeating opening playlist")
	main.show_main_menu()
	if failures.is_empty():
		print("ADVENTURE MUSIC OK: eight arranged tracks, real preview/Back, bags/stages/no-repeat, isolated RNG, crossfades, browser unlock, pause/slowmo-safe switching, boss/result cancellation, volume and run/Retry")
	else:
		for failure in failures:
			push_error(failure)
	paused = false
	quit(0 if failures.is_empty() else 1)

func _expect(ok: bool, message: String) -> void :
	if not ok:
		failures.append(message)
