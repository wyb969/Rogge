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
	await main._launch_run(&"")
	var game: Node = main.game
	game.spawner.set_process(false)
	game.spawner.timer.stop()
	game.spawner.get_node("Elite").stop()
	game.player.set_physics_process(false)
	for name in ["HandWeapon", "CircleWeapon", "Weapon", "DroneController", "MolotovController", "FreezeController"]: game.get_node(name).process_mode = Node.PROCESS_MODE_DISABLED
	var audio: Node = root.get_node("AudioManager")
	for cue in audio.GUN_CUES:
		expect(cue is AudioStreamWAV and cue.get_length() >= 0.05 and cue.get_length() <= 0.065 and cue.loop_mode == 0, "original gun ticks have short nonlooping tails fitting the admission gap")
	var gun: Node = game.gun_weapon
	audio.stop_gun_audio()
	var count: int = audio.gun_cues_played
	gun.cool_down = false
	var children: int = game.effect_container.get_child_count()
	for _i in 100: gun.shoot()
	expect(game.effect_container.get_child_count() == children and audio.gun_cues_played == count, "cooldown-blocked shooting emits neither a projectile nor a phantom gun sound")
	gun.cool_down = true
	gun.shoot()
	expect(audio.gun_cues_played == count + 1 and audio.shoot_audio_player.playing, "an actual admitted shot plays its short gun cue")
	var variant: int = audio._gun_variant
	for _i in 100: audio.play_shoot()
	expect(audio._gun_variant == variant and audio.gun_cues_played == count + 1, "same-frame storms cannot restart the tail or advance inaudible variants")
	var streams: Array = []
	var first_gain: = 0.0
	for i in 7:
		audio._last_shot_msec = Time.get_ticks_msec() - 100
		audio._focus_until_msec = 0
		audio.play_shoot()
		streams.append(audio.shoot_audio_player.stream)
		if i == 0: first_gain = audio.shoot_audio_player.volume_db
		expect(audio._focus_until_msec == 0 and audio.shoot_audio_player.bus == &"SFX" and audio.shoot_audio_player.max_polyphony == 1, "continuous fire uses one SFX voice without permanently ducking the music")
		if i > 0: expect(streams[i] != streams[i - 1], "round-robin textures keep adjacent admitted shots different")
	expect(audio.shoot_audio_player.volume_db < first_gain, "long continuous bursts ease their gain instead of becoming an ever-louder noise bed")
	audio._last_enemy_hurt_msec = -1000
	audio.play_enemy_hurt()
	expect(audio.enemy_hurt_audio_player.volume_db == -14, "rapid-fire impact clicks also yield headroom instead of hiding the lighter gun texture")
	audio._pickup_stamp = Time.get_ticks_msec() - 40
	audio._pickup_note = 4
	audio._last_shot_msec = Time.get_ticks_msec() - 100
	audio.play_shoot()
	expect(is_equal_approx(audio.shoot_audio_player.volume_db, -13.0 - audio._gun_chain * 0.5 - 3), "rapid high pickup melody takes audible priority over gun clicks")
	var glow: Node = game.level_manager.pickup_glow
	audio.reset_pickup_combo()
	glow.reset()
	var xp: int = game.level_manager.coin_number
	var heat_six: = 0.0
	for i in 30:
		if i > 0: audio._pickup_stamp = Time.get_ticks_msec() - 80
		audio.play_pickup()
		if i == 5: heat_six = glow.heat
		expect(glow.combo == i + 1 and glow.pitch == audio.pick_coin_audio_player.pitch_scale, "only actual admitted pickup notes increment the displayed combo")
	expect(glow.tier == 3 and glow.combo == 30 and glow.heat > heat_six and glow._combo_label.text.contains("30 COMBO"), "combo keeps escalating to hot/fever after the melody reaches its octave cap")
	expect(glow._shader.get_shader_parameter("heat") == 1 and glow._shader.get_shader_parameter("kick") == 1 and glow._combo_label.scale.x > 1.1, "real combo drives fire/flow/ember and a bounded punched label")
	audio.play_pickup()
	expect(glow.combo == 30 and game.level_manager.coin_number == xp, "suppressed sound cannot fake extra combo or gameplay XP")
	for size in [Vector2i(390, 844), Vector2i(1920, 1080)]:
		root.size = size
		await process_frame
		await process_frame
		expect(Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses(glow._combo_label.get_global_rect()), "combo stays inside both portrait and landscape HUDs")
	paused = true
	await create_timer(0.65, true, false, true).timeout
	expect( not glow.visible and glow.combo == 0 and not glow._combo_label.visible, "fire/label cool off through a paused reward page and stop drawing")
	paused = false
	audio.play_pickup()
	expect(glow.combo == 1 and glow.heat == 0 and glow.pitch == 1, "after a gap both melody and visual streak restart together")
	main.show_main_menu()
	expect( not audio.shoot_audio_player.playing and audio._gun_variant == 0 and glow.combo == 0, "return clears gun tail/variation and combo animation")
	await main._launch_run(&"juice")
	game = main.game
	var fixture: Node = game.get_node("FeedbackPlayground")
	expect(game.gun_weapon.level == 8 and fixture.coins_left == 32, "real Debug equips rapid fire and a finite normal-coin demonstration")
	await create_timer(1.15, true, false, true).timeout
	expect(game.level_manager.coin_number > 80 and fixture.coins_left < 32, "Debug actually collects staggered coins and awards normal XP")
	fixture._buttons.get_child(0).pressed.emit()
	expect(fixture.coins_left == 32 and game.level_manager.coin_number == 80, "real replay button restarts the visible fixture")
	fixture._buttons.get_child(1).pressed.emit()
	await process_frame
	await process_frame
	expect(main.menu_page.visible and not is_instance_valid(fixture), "Debug Back removes its canvas controls and queued demonstrations")
	if failures.is_empty(): print("COMBO/GUN OK: short original cues, successful-shot-only audio, no restart storms, varied quiet bursts/pickup priority/shared mix, real-note 30 combo/fever beyond pitch cap, zero fake XP, portrait/landscape/pause and return")
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
