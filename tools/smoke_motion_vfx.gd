extends SceneTree
const ARC := preload("res://script/arc_motion.gd")
var checks := 0
var failures: Array[String] = []
func _init() -> void: call_deferred("_run")
func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	main.debug_page.get_node("VBoxContainer/DebugMotionVfxButton").pressed.emit()
	await process_frame
	await process_frame
	var game: Node = main.game
	var player: Node = game.player
	var surf: Node = game.ink_surf
	var feedback: Node = game.combat_feedback
	var sandbox: Node = game.get_node("MotionVfxDebug")
	_expect(main._test_mode == &"motion_vfx" and game.bomb_controller.level == 1 and surf.charge == 1,"real first-page Debug button launches the complete presentation sandbox")
	_expect(not game.spawner.is_processing() and sandbox.bomber.projectile_damage == 0,"sandbox stops waves and uses harmless actual mortar attacks")
	player.set_physics_process(false)
	surf.set_process(false)
	surf.set_physics_process(false)
	sandbox.set_process(false)
	game.bomb_controller.set_physics_process(false)
	game.enemy_attacks.set_physics_process(false)
	var foot: Node2D = player.get_node("InkFootHud")
	_expect(foot.get_parent() == player and surf._caption.get_parent() == foot,"meter and text share the actual player transform")
	for direction in [Vector2.UP,Vector2.DOWN,Vector2(1,1).normalized()]:
		player.reset_dash()
		player._start_dash(direction)
		for i in 12:
			player.global_position += direction * 7.5
			player.animated_sprite_2d.scale = Vector2(1.8,1.4)
			_expect((surf._caption.global_position-player.global_position).is_equal_approx(Vector2(-50,32)),"HUD stays locked through vertical/diagonal dash, independent of sprite squash")
		player._on_dashing_timer_timeout()
	# The same 109-unit path gives evenly spaced silhouettes at any sampling rate.
	for fps in [30,60,120]:
		feedback.start()
		player.reset_dash()
		player.global_position = Vector2.ZERO
		player._start_dash(Vector2.RIGHT)
		var previous := 0.0
		var samples := ceili(0.14 * fps)
		for step in samples:
			var next := minf(109.0,109.0*(step+1)/samples)
			player.global_position = Vector2(next,0)
			player._emit_dash_ghosts(Vector2(previous,0),Vector2(next,0))
			previous = next
		_expect(feedback.ghosts.size() == 7,"30/60/120Hz path produces the same seven silhouettes")
		for index in range(1,feedback.ghosts.size()):
			_expect(is_equal_approx(feedback.ghosts[index].p.x-feedback.ghosts[index-1].p.x,18),"ghosts are evenly spaced in world coordinates")
		for _i in 30: player._on_shadow_timer_timeout()
		_expect(feedback.ghosts.size() <= 8,"stress never grows the fixed eight-ghost pool")
		player._on_dashing_timer_timeout()
	feedback.reset()
	_expect(feedback.ghosts.is_empty() and feedback._free_ghosts.size()==8,"reset releases all silhouette textures to the fixed pool")
	for fps in [30,60,120]:
		var endpoint := Vector2(160,70)
		var last := -1.0
		for frame in range(ceili(0.42*fps)+1):
			var elapsed := minf(frame/float(fps),0.42)
			# 60Hz authoritative state pair, sampled at each display frame.
			var tick := floorf(elapsed*60)/60.0
			var fraction := fposmod(elapsed*60,1)
			var age := ARC.render_age(tick,tick+1.0/60,fraction)
			var at := ARC.position_at(Vector2.ZERO,endpoint,age,0.42,44)
			_expect(at.x >= last and at.is_finite(),"arc advances continuously at each render cadence")
			last = at.x
		_expect(ARC.position_at(Vector2.ZERO,endpoint,0.42,0.42,44).is_equal_approx(endpoint),"arc lands exactly at its locked target at every cadence")
	_expect(ARC.position_at(Vector2.ZERO,Vector2(100,0),0.21,0.42,44).is_equal_approx(Vector2(50,-44)),"shared parabolic arc has stable midpoint height")
	_expect(is_equal_approx(ARC.render_age(0.2,0.3,0.5),0.25),"two render frames interpolate distinct completed physics states")
	# Actual engine frames, not just arithmetic: a 120Hz idle loop samples 30Hz physics.
	var saved_fps := Engine.max_fps
	var saved_ticks := Engine.physics_ticks_per_second
	Engine.max_fps = 120
	Engine.physics_ticks_per_second = 30
	feedback.start()
	player.reset_dash()
	sandbox.replay()
	game.bomb_controller.set_physics_process(true)
	game.enemy_attacks.set_physics_process(true)
	var previous_states := {}
	var moving_pairs := {"player":0,"enemy":0}
	for _i in 120:
		await process_frame
		var states := {}
		for bomb in game.bomb_controller._bombs:
			if bomb.active and bomb.age < 0.42:
				states.player = Vector2(bomb.age,ARC.render_age(bomb.previous_age,bomb.age))
		for slot in game.enemy_attacks.slots:
			if slot.active and slot.age > 0.25 and slot.age < 1.1:
				states.enemy = Vector2(slot.age,ARC.render_age(slot.previous_age,slot.age))
		for kind in states:
			if previous_states.has(kind) and is_equal_approx(previous_states[kind].x,states[kind].x) and states[kind].y > previous_states[kind].y:
				moving_pairs[kind] += 1
		previous_states = states
	_expect(moving_pairs.player > 10 and moving_pairs.enemy > 10,"actual 120Hz render frames advance both arcs between 30Hz physics ticks")
	Engine.max_fps = saved_fps
	Engine.physics_ticks_per_second = saved_ticks
	game.bomb_controller.set_physics_process(false)
	game.enemy_attacks.set_physics_process(false)
	sandbox.replay_button.pressed.emit()
	_expect(game.bomb_controller.is_processing() and game.enemy_attacks.is_processing(),"both real throws enable render-frame updates")
	var bomb_age: float = game.bomb_controller._bombs[0].age
	var enemy_age: float = game.enemy_attacks.slots[0].age
	for _i in 100:
		game.bomb_controller._process(1.0/120)
		game.enemy_attacks._process(1.0/120)
	_expect(game.bomb_controller._bombs[0].age==bomb_age and game.enemy_attacks.slots[0].age==enemy_age,"render refresh never advances fuses, hit clocks or enemy warning timing")
	game.bomb_controller.clear_combat_effects()
	game.enemy_attacks.clear_combat_effects()
	_expect(not game.bomb_controller.is_processing() and not game.enemy_attacks.is_processing(),"idle pools stop rendering callbacks")
	surf.clear_combat_effects()
	_expect(not foot.visible,"transition hides the entire underfoot display immediately")
	sandbox.dash_button.pressed.emit()
	_expect(player.can_dash and not player.dashing,"sandbox reset uses the actual dash reset API")
	main._on_game_end_ui_retry_pressed()
	await process_frame
	await process_frame
	_expect(main._test_mode==&"motion_vfx" and main.game.has_node("MotionVfxDebug"),"Retry creates a fresh matching Debug preset")
	main.fullscreen_toggle.home_button.pressed.emit()
	await process_frame
	await process_frame
	await main._launch_run(&"")
	_expect(not main.game.has_node("MotionVfxDebug") and main.game.bomb_controller.level==0 and not main.game.ink_surf.debug_training,"Home and ordinary Start never inherit sandbox gear, charge or UI")
	if failures.is_empty(): print("MOTION VFX OK: %d checks; player-bound HUD, distance ghosts, 30/60/120Hz arcs, render-only clocks, fixed pools and actual Debug/retry/Home isolation" % checks)
	else:
		for message in failures: push_error(message)
	quit(0 if failures.is_empty() else 1)
