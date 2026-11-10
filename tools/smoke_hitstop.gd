extends SceneTree

var checks := 0
var failures: Array[String] = []
var game: Node
func _init() -> void: call_deferred("_run")
func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
func wall_seconds(seconds: float) -> void:
	var until := Time.get_ticks_usec() + int(seconds*1000000)
	while Time.get_ticks_usec()<until: await process_frame
func enemy(at: Vector2 = Vector2(300,0)) -> Node2D:
	var actor: Node2D = game.spawner.enemy.instantiate()
	actor.set_enemy_data(load("res://resource/Enemy_1.tres"))
	actor.set_player_ref(game.player)
	actor.add_to_group("EnemyGroup")
	actor.death_signal.connect(game.spawner.on_enemy_killed.bind(actor))
	game.add_child(actor)
	actor.global_position = at
	actor.health = 10000
	actor.set_physics_process(false)
	return actor
func _run() -> void:
	Engine.max_fps = 120
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	main.debug_page.get_node("VBoxContainer/DebugHitstopButton").pressed.emit()
	await process_frame
	await process_frame
	game = main.game
	var sandbox: Node = game.get_node("MotionVfxDebug")
	var fx: Node = game.combat_feedback.impact_feedback
	var player: Node = game.player
	player.set_physics_process(false)
	var actor: Node = sandbox.target
	var material: Material = actor.sprite_2d.material
	var body_scale: Vector2 = actor.scale
	var before: float = actor.health
	sandbox.replay_button.pressed.emit()
	expect(main._test_mode==&"hitstop" and actor.health==before-10,"actual first-page Debug button and real enemy damage route")
	expect(fx.flashes==1 and fx.stops==1 and is_equal_approx(Engine.time_scale,0.05),"direct hit requests a white flash and short global stop")
	var end: int = fx._stop_until
	var index: int = fx.indices[actor.get_instance_id()]
	expect(not fx.records[index].player and fx.records[index].texture!=null,"white enemy snapshot contains its actual current frame")
	for _i in 100: actor.apply_hit({"damage":1.0})
	expect(actor.health==before-110,"rapid hits retain exact damage")
	expect(fx.flashes==1 and fx.stops==1 and fx._stop_until==end,"rapid hits neither extend stop nor keep refreshing the same flash")
	expect(actor.sprite_2d.material==material and actor.scale==body_scale,"overlay never replaces shared body/status material or collider scale")
	await wall_seconds(0.105)
	expect(is_equal_approx(Engine.time_scale,1.0) and not fx._owns_scale,"stop recovers on real time despite slowed simulation")
	var other: Node = sandbox.bomber
	other.apply_hit({"damage":1.0})
	expect(fx.stops==1 and is_equal_approx(Engine.time_scale,1.0),"global cooldown suppresses another stop while still allowing hit coloring")
	await wall_seconds(0.17)
	expect(fx.indices.is_empty() and not fx.is_processing(),"all short snapshots retire and idle processing stops")
	fx.clear_combat_effects()
	var count: int = fx.flashes
	actor.apply_hit({"damage":5.0,"effect":"poison_trail","from_status":true})
	actor._take_status_damage(5)
	expect(fx.flashes==count and is_equal_approx(Engine.time_scale,1.0),"poison and periodic burn do not trigger hitstop loops")
	var mortal := enemy()
	mortal.health = 1
	var id := mortal.get_instance_id()
	mortal.apply_hit({"damage":2.0})
	index = fx.indices[id]
	await process_frame
	expect(not is_instance_valid(mortal) and fx.records[index].texture!=null,"lethal hit preserves a bounded last-frame flash after enemy deletion")
	expect(game.combat_feedback.death_stains.stamps[0].age<0.06,"starting hitstop cannot fast-forward a new death splat by dividing stale delta")
	fx.clear_combat_effects()
	player.hurt_lock = 0
	player.shield = 20
	player.player_health = 500
	count = fx.flashes
	player.receive_attack(10,actor)
	expect(player.player_health==500 and player.shield==10 and fx.flashes==count,"fully absorbed shield damage does not flash the player red")
	player.shield = 0
	player.hurt_lock = 0
	sandbox.dash_button.pressed.emit()
	expect(player.player_health==490 and fx.records[0].player and fx.records[0].region==false,"actual accepted player damage captures the animated pale-red frame in reserved slot0")
	expect(fx.records[0].texture.get_size()==fx.records[0].rect.size,"player flash uses a clipped animation frame, not the entire atlas")
	count = fx.flashes
	end = fx._stop_until
	player.receive_attack(10,actor)
	expect(player.player_health==490 and fx.flashes==count and fx._stop_until==end,"hurt immunity does not retrigger or extend feedback")
	fx.clear_combat_effects()
	player.hurt_lock = 0
	player.reset_dash()
	player._start_dash(Vector2.UP)
	player.receive_attack(10,actor)
	expect(player.player_health==490 and fx.indices.is_empty(),"dash immunity produces no false red flash")
	player.reset_dash()
	player.arsenal_shield_active = true
	player.receive_attack(10,actor)
	expect(fx.indices.is_empty(),"arsenal invulnerability produces no false red flash")
	player.arsenal_shield_active = false
	fx.pulse(actor,actor.sprite_2d)
	Engine.time_scale = 0.08
	fx._process(0)
	expect(is_equal_approx(Engine.time_scale,0.08) and not fx._owns_scale,"death/external slow-motion supersedes the short stop")
	fx.clear_combat_effects()
	expect(is_equal_approx(Engine.time_scale,0.08),"reset never overwrites another time-scale owner")
	Engine.time_scale = 1
	fx.pulse(actor,actor.sprite_2d)
	paused = true
	await process_frame
	await process_frame
	expect(is_equal_approx(Engine.time_scale,1.0) and fx.indices.is_empty(),"pause releases owned scale and transient overlays")
	paused = false
	game.trials.flow = game.trials.TrialFlow.ACTIVE
	fx.pulse(actor,actor.sprite_2d)
	expect(not fx.indices.is_empty() and is_equal_approx(Engine.time_scale,1.0),"timed trials keep colored impact but preserve real-time attack/dodge windows")
	game.trials.flow = game.trials.TrialFlow.IDLE
	fx.clear_combat_effects()
	var boss: Node = load("res://scenes/boss.tscn").instantiate()
	boss.set_player(player)
	game.add_child(boss)
	boss.rush_timer.stop()
	boss.set_physics_process(false)
	boss.global_position = Vector2(300,-100)
	before = boss.boss_current_health
	count = fx.flashes
	boss.apply_hit({"damage":10.0})
	expect(boss.boss_current_health==before-10 and fx.flashes==count+1,"real boss damage uses the same white overlay")
	expect(is_equal_approx(Engine.time_scale,0.05),"boss delegates to the shared stop owner")
	fx.clear_combat_effects()
	count = fx.flashes
	boss.apply_hit({"damage":5.0,"from_status":true})
	boss.apply_hit({"damage":0.0})
	expect(fx.flashes==count and is_equal_approx(Engine.time_scale,1.0),"boss status ticks and zero damage cannot start hitstop")
	boss.queue_free()
	for i in 80:
		var crowd := enemy(Vector2(1000+i*4,0))
		crowd.apply_hit({"damage":1.0})
	expect(fx.records.size()==48 and fx.indices.size()<=47 and fx.get_child_count()==0,"crowd hits reuse a fixed overlay pool with no per-hit nodes")
	player.hurt_lock = 0
	player.receive_attack(1,actor)
	expect(fx.records[0].player and fx.indices.size()<=48,"crowd saturation preserves the player's red slot")
	game.variety.clear_combat_effects()
	expect(fx.indices.is_empty() and is_equal_approx(Engine.time_scale,1.0),"stage/rest cleanup retires snapshots and restores owned time")
	for record in fx.records: expect(record.texture==null,"cleared pool releases cached frame references")
	main._on_game_end_ui_retry_pressed()
	await process_frame
	await process_frame
	expect(main._test_mode==&"hitstop" and main.game.combat_feedback.impact_feedback.flashes==0,"Retry creates a fresh matching preset")
	main.fullscreen_toggle.home_button.pressed.emit()
	await process_frame
	await process_frame
	await main._launch_run(&"")
	expect(not main.game.has_node("MotionVfxDebug") and main.game.combat_feedback.impact_feedback.indices.is_empty() and is_equal_approx(Engine.time_scale,1.0),"ordinary Start inherits no Debug UI, flash or stopped time")
	if failures.is_empty(): print("HITSTOP OK: %d checks; real damage/white-red frames, anti-chain bounds, status/immunity/shields, death clock ownership, pause/trials, crowd pool and Debug lifecycle" % checks)
	else:
		for message in failures: push_error(message)
	quit(0 if failures.is_empty() else 1)
