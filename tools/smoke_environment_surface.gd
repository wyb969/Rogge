extends SceneTree
var failures: Array[String] = []
var checks := 0
var main: Node
var g: Node
var p: Node
var w: Node
func _init() -> void: call_deferred("_run")
func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
func steps(count: int) -> void:
	for i in count: await physics_frame
func enemy(path: String) -> Node:
	var e = load("res://scenes/enemy_shell.tscn").instantiate()
	e.set_enemy_data(load(path))
	e.set_player_ref(p)
	e.health = 10000
	e.add_to_group("EnemyGroup")
	g.add_child(e)
	e.set_physics_process(false)
	e.collision_layer = 0
	e.collision_mask = 0
	e.global_position = p.global_position+Vector2(100,100)
	return e
func isolate() -> void:
	g = main.game
	p = g.player
	w = g.weather
	g.spawner.timer.stop()
	g.spawner.get_node("Elite").stop()
	g.spawner.set_process(false)
	g.clear_enemies()
	# Measure free travel without terrain hits or level-up pauses.
	g.level_manager.signal_level_up.disconnect(g.on_level_up)
	for hazard in [w.spikes, w.electric_grid, w.minefield]:
		hazard.process_mode = Node.PROCESS_MODE_DISABLED
	g.variety.set_process(false)
	g.meteors.set_process(false)
	for path in ["HandWeapon","CircleWeapon","Weapon","DroneController","MolotovController","FreezeController","BananaFan","BlackHole"]:
		if g.has_node(path): g.get_node(path).process_mode = Node.PROCESS_MODE_DISABLED
	g.banana_fan.set_physics_process(false)
	g.black_hole.set_physics_process(false)
	root.get_node("MobileInput").controls_enabled = false
func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	main._on_debug_button_pressed()
	main.debug_page.box.get_node("DebugWindSceneButton").pressed.emit()
	for i in 3: await process_frame
	await steps(2)
	isolate()
	expect(w.current_weather == 4 and g.banana_fan.level == 3 and g.black_hole.level == 3, "real Wind Debug has wind and displacement cards")
	w.set_process(false)
	p.velocity = Vector2.ZERO
	await steps(20)
	expect(p.velocity.length() > 3 and p.velocity.length() <= 16.01 and p.velocity.normalized().dot(w.surface.wind.normalized()) > 0.99, "wind gently carries an idle player in the world wind direction")
	var e := enemy("res://resource/Enemy_1.tres")
	e.velocity = Vector2.ZERO
	e._apply_environment_motion(1.0/60,Vector2.ZERO)
	expect(e.velocity.dot(w.surface.wind) > 0 and e.velocity.length() <= 12.01, "normal enemies receive a resisted wind bias")
	e.shot_windup = 1
	e.velocity = Vector2.ZERO
	e._apply_environment_motion(1.0/60,Vector2.ZERO)
	expect(e.velocity == Vector2.ZERO, "committed warning stays stationary")
	e.shot_windup = 0
	var settings: Node = root.get_node("SettingsStore")
	var saved: float = settings.weather_intensity
	settings.weather_intensity = 0
	w.surface.sync()
	expect(w.surface.wind_velocity().length() > 0, "visual quality cannot disable wind gameplay")
	w.set_preview(5,0)
	expect(w.surface.ice_amount() == 1 and g.get_node("InfiniteBackground")._shader_mat.get_shader_parameter("ice_cover") == 1, "ice remains identifiable and slippery at zero cosmetic quality")
	settings.weather_intensity = saved
	var coast: Array[float] = []
	for kind in [0,5]:
		w.set_preview(kind,0)
		p.velocity = Vector2.ZERO
		Input.action_press("right")
		await steps(65)
		expect(is_equal_approx(p.velocity.x,100), "surface preserves ordinary maximum cruise speed")
		Input.action_release("right")
		var start: Vector2 = p.global_position
		await steps(65)
		coast.append(p.global_position.distance_to(start))
		expect(p.velocity.length() < 0.01, "player eventually stops without input")
	expect(coast[1] > coast[0]*4 and coast[1] > 40 and coast[1] < 60, "ice coast is roughly one second / fifty units instead of a quick normal stop: %s" % [coast])
	Input.action_press("right")
	await steps(30)
	Input.action_release("right")
	Input.action_press("left")
	await steps(26)
	expect(p.velocity.x < 0, "opposite input brakes and turns before a full second")
	Input.action_release("left")
	p.can_dash = true
	p._start_dash(Vector2.UP)
	await steps(2)
	expect(p.dashing and p.velocity == Vector2.UP*p.DASH_SPEED, "ice keeps explicit dash direction and speed")
	p._on_dashing_timer_timeout()
	p.dashing_timer.stop()
	await steps(10)
	expect(p.velocity.y < -100 and p.dash_grace_left > 0, "dash leaves bounded sliding momentum and original grace window")
	await steps(35)
	expect(p.dash_grace_left == 0, "sliding never extends invincibility")
	p.set_physics_process(false)
	var base: Array[float] = []
	for kind in [0,5]:
		w.set_preview(kind,0)
		e.apply_airflow(Vector2.RIGHT*1000,1)
		e.apply_gravity_pull(Vector2.RIGHT*1000,1)
		e.apply_blast_impulse(Vector2.RIGHT*1000,1)
		var values := Vector3(e._airflow_velocity.length(),e._gravity_velocity.length(),e._blast_velocity.length())
		if kind == 0:
			base.assign([values.x,values.y,values.z])
		else:
			expect(values.is_equal_approx(Vector3(base[0],base[1],base[2])*1.3), "fan, pull and blast gain exactly 30% after existing resistance/caps")
		for i in 60: e._apply_crowd_motion(1.0/60)
		expect(e._airflow_left == 0 and e._gravity_left == 0 and e._blast_left == 0, "surface cannot extend displacement forever")
	# Snapshot distance through a weather fade, and suppress post-attack ice drift.
	var d := enemy("res://resource/Enemy_5.tres")
	for change_weather in [false,true]:
		for dt in [1.0/30,1.0/60,0.5]:
			w.set_preview(5,0)
			d._finish_dash()
			d.global_position = p.global_position+Vector2(160,0)
			d.dash_timer = 0
			d._physics_process(0.01)
			expect(is_equal_approx(d._dash_surface_scale,1.25) and d.dash_windup > 0, "ice leap snapshots a 25% longer warning")
			if change_weather: w.set_preview(0,0)
			d._physics_process(d.DASH_AIM_SECONDS)
			d._physics_process(d.DASH_LOCK_SECONDS + 0.00001)
			var start: Vector2 = d.global_position
			var guard := 0
			while d.is_dashing and guard < 30:
				d._physics_process(dt)
				guard += 1
			expect(absf(d.global_position.distance_to(start)-71.5)<0.05 and d.velocity == Vector2.ZERO, "ice dash matches 71.5-unit warning without extra landing slide at delta %s / weather change %s" % [dt,change_weather])
	w.set_preview(5,0)
	e.velocity = Vector2.LEFT*100
	e._apply_environment_motion(1.0/60,Vector2.RIGHT*100)
	expect(e.velocity.x > 90, "normal monster reversals retain brief ice inertia")
	w.set_preview(4,0)
	paused = true
	expect(w.surface.wind_velocity() == Vector2.ZERO and w.surface.ice_amount() == 0, "paused surface applies no forces")
	paused = false
	g.spawner._rest_open = true
	expect(w.surface.wind_velocity() == Vector2.ZERO, "rest suppresses wind")
	g.spawner._rest_open = false
	g.spawner._transitioning = true
	expect(w.surface.wind_velocity() == Vector2.ZERO, "transition suppresses wind")
	g.spawner._transitioning = false
	w.stop()
	expect(w.surface.wind_velocity() == Vector2.ZERO and not w.surface.visible, "weather stop clears force and surface pass")
	main._on_debug_button_pressed()
	main.debug_page.box.get_node("DebugIceSceneButton").pressed.emit()
	for i in 3: await process_frame
	await steps(2)
	expect(main.game.weather.current_weather == 5 and main.game.weather.surface.ice_amount() == 1, "real Ice Debug starts a fresh icy game")
	if failures.is_empty(): print("ENVIRONMENT SURFACE OK: %d checks; wind/quality isolation, actual input/coast/brake/dash, resisted 30%% crowd impulses, 30/60Hz locked ice leaps, lifecycle and real Debug" % checks)
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
