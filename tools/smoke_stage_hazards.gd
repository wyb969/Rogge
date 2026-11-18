extends SceneTree
var failures: Array[String] = []
var checks := 0
var g: Node
func _init() -> void: call_deferred("run")
func expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await main._launch_run(&"minefield")
	g = main.game
	g.spawner.timer.stop()
	g.spawner.get_node("Elite").stop()
	g.spawner.set_process(false)
	g.player.set_physics_process(false)
	g.player.set_process(false)
	g.weather.set_process(false)
	g.variety.set_process(false)
	g.meteors.set_process(false)
	for path in ["HandWeapon","CircleWeapon","Weapon","DroneController","MolotovController","FreezeController"]: g.get_node(path).process_mode = Node.PROCESS_MODE_DISABLED
	var w: Node = g.weather
	var fields: Array = [w.minefield,w.electric_grid,w.spikes]
	for field in fields: field.set_physics_process(false)
	w._hazard_profiles.clear()
	w._hazard_bag.clear()
	w._hazard_rng.seed = 497
	var selected: Array[int] = []
	for stage in range(1,31):
		w.apply_stage(stage,true)
		selected.append(w.hazard_kind)
		for kind in 6:
			w.set_preview(kind,0)
			for field in fields: field._physics_process(0.01)
			var active := 0
			for field in fields: active += int(field._running)
			expect(active==1 and fields[w.hazard_kind]._running,"exactly one hazard in every weather, stage "+str(stage))
		var saved: int = w.hazard_kind
		w.apply_stage(stage,true)
		expect(w.hazard_kind==saved,"stage revisit does not reroll")
	for i in range(0,30,3):
		expect(selected.slice(i,i+3).has(0) and selected.slice(i,i+3).has(1) and selected.slice(i,i+3).has(2),"every shuffled bag contains all three hazards")
	for i in range(1,30): expect(selected[i]!=selected[i-1],"avoid consecutive repeated hazards")
	w.apply_stage(1,true)
	w.set_hazard(0)
	var mine: Node = w.minefield
	mine._physics_process(0.01)
	mine._clock = 2
	var at: Vector2 = mine.mines[4].at
	g.player.global_position = at+Vector2(400,0)
	var chosen: Array[int] = [4]
	# Actual mine damage, not just calling an impulse method, must launch every survivor.
	for specimen in range(7):
		var path: String = ["enemy_shell","boss","knight_boss","beast_boss","beast_boss","beast_boss","beast_boss"][specimen]
		var actor = load("res://scenes/"+path+".tscn").instantiate()
		if path=="enemy_shell":
			actor.set_enemy_data(load("res://resource/Enemy_3.tres"))
			actor.set_player_ref(g.player)
		else:
			if specimen>=3: actor.configure_stage(specimen)
			actor.set_player(g.player)
		actor.add_to_group("EnemyGroup")
		g.add_child(actor)
		actor.set_process(false)
		actor.set_physics_process(false)
		actor.global_position = at-mine.FOOT+Vector2(8,0)
		var before: float
		if path=="enemy_shell":
			actor.health = 10000
			before = actor.health
		else:
			actor.boss_current_health = 10000
			before = actor.boss_current_health
		mine._snapshot()
		mine._blast_batch(chosen)
		var after: float = actor.health if path=="enemy_shell" else actor.boss_current_health
		expect(after==before-72 and actor.terrain_impulse.is_active(),"survivor really damaged and launched: "+path)
		actor._process(0.22)
		actor.set_process(false)
		expect(actor.sprite_2d.position.y*actor.scale.y<-30,"clear mine apex: "+path)
		if path=="enemy_shell":
			actor._apply_move_juice(1.0/60)
			expect(actor.sprite_2d.position.y*actor.scale.y<-30,"physics pose cannot erase render flight")
		actor.clear_terrain_impulse()
		w.electric_grid._zap(actor)
		expect(not actor.sprite_2d.visible,"survivor source art hidden for shock: "+str(specimen))
		w.electric_grid.stop()
		expect(actor.sprite_2d.visible,"source art restored without changing status tint: "+str(specimen))
		actor.queue_free()
	await process_frame
	w.set_hazard(1)
	var grid: Node = w.electric_grid
	grid._physics_process(0.01)
	grid.zones.assign([grid.make_zone(Rect2(-30,-30,60,60),false)])
	g.player.global_position = Vector2(400,0)
	var victim = load("res://scenes/enemy_shell.tscn").instantiate()
	victim.set_enemy_data(load("res://resource/Enemy_1.tres"))
	victim.set_player_ref(g.player)
	victim.add_to_group("EnemyGroup")
	g.add_child(victim)
	victim.health = 10000
	victim.global_position = -grid.FOOT
	victim.set_physics_process(false)
	grid._clock = 0.75
	grid._cycle = 0
	grid._scan_enemies()
	expect(victim.health==9946 and not victim.sprite_2d.visible,"shock hides source art while skeleton shows")
	var voices: int = grid.audio_events
	for step in 5: grid._scan_enemies()
	expect(grid.audio_events==voices and grid._zaps.size()==1,"same batch dedups audio and skeleton")
	grid._scan_left = 0
	grid._physics_process(0.49)
	expect(victim.health==9946,"no damage before 0.5 second cooldown")
	grid._scan_left = 0
	grid._physics_process(0.01)
	expect(victim.health==9892 and grid._zaps.size()==1,"next hit at exactly 0.5 seconds, no duplicate skeleton")
	expect(grid._audio.bus==mine._audio.bus and grid._audio.max_polyphony==1 and mine._audio.max_polyphony==1,"shared SFX routing and bounded terrain voices")
	expect(grid._audio.stream.get_length()<0.25 and mine._audio.stream.get_length()<0.4,"short distinct terrain cues")
	# Player safety is stun 1 second + a real free half-second, not repeated stun-lock.
	g.player.global_position = -grid.FOOT
	g.player.hurt_lock = 0
	g.player.shield = 0
	g.player.damage_reduction = 0
	g.player.beast_damage_scale = 1
	grid._player_at = Vector2.ZERO
	var hp: float = g.player.player_health
	grid._touch_player()
	expect(g.player.player_health==hp-18 and not g.player.animated_sprite_2d.visible,"player art also replaced by skeleton")
	for i in 2:
		g.player._physics_process(0.5)
		grid._scan_left = 1
		grid._physics_process(0.5)
	expect(g.player.player_health==hp-18 and g.player.electric_stun_left<=0,"two intervening pulses cannot extend player paralysis")
	grid._physics_process(0.01)
	expect(g.player.animated_sprite_2d.visible,"original player art returns when paralysis ends")
	w.set_hazard(2)
	expect(victim.sprite_2d.visible and grid._zaps.is_empty() and not grid._audio.playing,"hazard switch restores art and clears owned audio/effects")
	victim.queue_free()
	g.end_game()
	for field in fields: expect(not field._running,"end-game stops hazard")
	main.queue_free()
	await process_frame
	if failures.is_empty(): print("STAGE HAZARDS OK: ",checks," checks")
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
