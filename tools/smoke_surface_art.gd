extends SceneTree
var failures: Array[String] = []
var checks := 0
var w: Node
var s: Node
func _init() -> void: call_deferred("run")
func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
func steps(count: int) -> void:
	for i in count:
		await physics_frame
		w.elapsed += 1.0/Engine.physics_ticks_per_second
		s.sync()
func run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await main._launch_run(&"wind_scene")
	var g: Node = main.game
	w = g.weather
	s = w.surface
	g.spawner.timer.stop()
	g.spawner.get_node("Elite").stop()
	g.spawner.set_process(false)
	g.variety.set_process(false)
	g.meteors.set_process(false)
	w.set_process(false)
	# The optical test needs uninterrupted four-direction motion.
	for hazard in [w.electric_grid,w.minefield,w.spikes]:
		hazard.stop()
		hazard.set_physics_process(false)
	g.banana_fan.set_physics_process(false)
	g.black_hole.set_physics_process(false)
	for path in ["HandWeapon","CircleWeapon","Weapon","DroneController","MolotovController","FreezeController"]: g.get_node(path).process_mode = Node.PROCESS_MODE_DISABLED
	var bg: Node = g.get_node("InfiniteBackground")
	for sprite in bg._decor_sprites: sprite.rotation = PI/2
	bg._update_decorations(Vector2.ZERO,Vector2(800,800))
	var upright := 0
	var reset := 0
	for sprite in bg._decor_sprites:
		if not sprite.visible: continue
		if sprite.texture.region.position == Vector2(0,32):
			upright += 1
			expect(is_equal_approx(sprite.rotation,PI/2),"side-facing foliage rotates upright")
		else:
			reset += 1
			expect(is_zero_approx(sprite.rotation),"recycled slots reset rotation for other art")
	expect(upright>0 and reset>0,"fixture covers foliage and other decoration types")
	var trails: Node = s.wind_trails
	trails.stop()
	trails._rng.seed = 241
	seed(969)
	var expected := randi()
	seed(969)
	s.sync()
	trails.set_process(false)
	expect(randi()==expected,"visual wind RNG cannot alter combat rolls")
	expect(trails._trails.size()==14 and trails.live,"wind uses fourteen reusable particle histories")
	var before: Vector2 = trails._trails[0].at
	var camera: Camera2D = g.player.get_node("Camera2D")
	camera.global_position += Vector2(8,0)
	camera.force_update_scroll()
	s.sync()
	trails.set_process(false)
	expect(trails._trails[0].at==before,"camera cannot drag existing wind trails")
	var nodes: int = trails.get_child_count()
	var queries: int = root.get_node("CombatTargets").queries
	for i in 200: trails.advance(1.0/60)
	expect(trails.get_child_count()==nodes and root.get_node("CombatTargets").queries==queries,"flow adds neither nodes nor crowd queries")
	var settings: Node = root.get_node("SettingsStore")
	var old: float = settings.weather_intensity
	settings.weather_intensity = 0
	s.sync()
	expect(not trails.live and s.wind_velocity().length()>0,"zero FX clears histories but preserves wind forces")
	settings.weather_intensity = old
	w.set_preview(5,0)
	root.get_node("MobileInput").controls_enabled = false
	for action in ["right","left","up","down"]:
		Input.action_press(action)
		await steps(65)
		var expected_tilt: Vector2 = {"right":Vector2.RIGHT,"left":Vector2.LEFT,"up":Vector2.UP,"down":Vector2.DOWN}[action]
		expect(s._ice_tilt.dot(expected_tilt)>0.7,"actual %s movement steers the ice viewing angle" % action)
		expect(bg._shader_mat.get_shader_parameter("ice_view_tilt")==s._ice_tilt,"shader receives smoothed actual-motion view")
		Input.action_release(action)
	await steps(125)
	expect(s._ice_tilt.length()<0.03,"idle view settles rather than continuing a wave animation")
	var view: Vector2 = bg._shader_mat.get_shader_parameter("ice_view_position")
	var tilt: Vector2 = bg._shader_mat.get_shader_parameter("ice_view_tilt")
	paused = true
	await create_timer(0.06,true,false,true).timeout
	expect(bg._shader_mat.get_shader_parameter("ice_view_position")==view and bg._shader_mat.get_shader_parameter("ice_view_tilt")==tilt,"pause freezes optical state")
	paused = false
	settings.weather_intensity = 0
	s.sync()
	expect(bg._shader_mat.get_shader_parameter("ice_gloss_strength")==0 and bg._shader_mat.get_shader_parameter("ice_cover")==1,"low FX suppresses gloss while keeping icy ground identifiable")
	settings.weather_intensity = old
	w.stop()
	expect(not trails.live and s._ice_tilt==Vector2.ZERO,"stop resets visual state")
	if failures.is_empty(): print("SURFACE ART OK: %d assertions; upright/reused decor, pooled particle-history trails, world anchoring/RNG/budget, actual four-direction optical input, idle/pause/FX/reset" % checks)
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
