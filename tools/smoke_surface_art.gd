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
	w.spikes.set_physics_process(false)
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
	s._gust_rng.seed = 241
	s._gust_live = false
	seed(969)
	var expected := randi()
	seed(969)
	s.sync()
	expect(randi()==expected,"visual gust RNG cannot alter combat rolls")
	expect(s._gusts.size()==18 and s._gust_live,"wind uses eighteen reusable curves")
	var signs: Dictionary = {}
	var lengths: Dictionary = {}
	for gust in s._gusts:
		expect(gust.points.size()==25 and gust.points[24].distance_to(gust.points[9])>3,"every gust has a curved rolled tip")
		signs[signf(gust.points[14].y)] = true
		lengths[int(gust.points[9].x)] = true
	expect(signs.size()==2 and lengths.size()>6,"curl handedness and lengths vary")
	var gust: Dictionary = s._gusts[0]
	var before: Vector2 = gust.at
	var camera: Camera2D = g.player.get_node("Camera2D")
	camera.global_position += Vector2(8,0)
	camera.force_update_scroll()
	s.sync()
	expect(gust.at == before,"camera motion cannot drag a live world gust")
	gust.age = 0.1
	gust.life = 4
	var points: PackedVector2Array = gust.points
	w.elapsed += 0.25
	s.sync()
	expect(gust.at.is_equal_approx(before+s.wind*5.3*0.25) and gust.points==points,"wind advects the cached curve without rebuilding it per frame")
	var nodes: int = s.get_child_count()
	var queries: int = root.get_node("CombatTargets").queries
	for i in 200:
		w.elapsed += 0.2
		s.sync()
	expect(s._gusts.size()==18 and s.get_child_count()==nodes and root.get_node("CombatTargets").queries==queries,"long wind animation adds neither nodes nor crowd queries")
	var settings: Node = root.get_node("SettingsStore")
	var old: float = settings.weather_intensity
	settings.weather_intensity = 0
	s.sync()
	expect(not s._gust_live and s.wind_velocity().length()>0,"zero cosmetic quality clears curves but preserves wind forces")
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
	expect(not s._gust_live and s._ice_tilt==Vector2.ZERO,"stop resets visual state")
	if failures.is_empty(): print("SURFACE ART OK: %d assertions; upright/reused decor, varied pooled curls, world anchoring/RNG/budget, actual four-direction optical input, idle/pause/FX/reset" % checks)
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
