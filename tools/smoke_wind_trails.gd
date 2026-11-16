extends SceneTree
var failures: Array[String] = []
var checks := 0
func _init() -> void: call_deferred("run")
func expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await main._launch_run(&"wind_scene")
	var g: Node = main.game
	var w: Node = g.weather
	var s: Node = w.surface
	var t: Node = s.wind_trails
	g.spawner.timer.stop()
	g.spawner.get_node("Elite").stop()
	g.spawner.set_process(false)
	w.set_process(false)
	g.player.set_physics_process(false)
	g.variety.set_process(false)
	g.meteors.set_process(false)
	for field in [w.spikes,w.electric_grid,w.minefield]: field.set_physics_process(false)
	for path in ["HandWeapon","CircleWeapon","Weapon","DroneController","MolotovController","FreezeController"]: g.get_node(path).process_mode = Node.PROCESS_MODE_DISABLED
	t.stop()
	t._rng.seed = 241
	seed(969)
	var expected := randi()
	seed(969)
	s.sync()
	t.set_process(false)
	expect(randi()==expected,"flow RNG is isolated from gameplay")
	expect(t.live and t._trails.size()==14 and t.get_child_count()==14,"fixed fourteen line pool")
	var texture: Texture2D = t._trails[0].line.texture
	for trail in t._trails:
		expect(trail.history.size()==64 and trail.display.size()==64,"fixed reusable 64-sample history")
		expect(trail.line.texture==texture and trail.line.texture_filter==CanvasItem.TEXTURE_FILTER_LINEAR,"shared smooth cross-section, no per-trail texture")
		expect(trail.line.width_curve.sample(0)==0 and trail.line.width_curve.sample(1)==0,"taper both ends")
		expect(trail.line.modulate.a<=0.58,"no additive blinding wind")
	var vortex: Dictionary = t._vortices[0]
	var a: Vector2 = t.flow(vortex.at+Vector2(20,0))
	var b: Vector2 = t.flow(vortex.at-Vector2(20,0))
	expect(a.distance_to(b)>70,"spatial field bends opposite sides of a vortex differently")
	var head: Vector2 = t._trails[0].at
	var history: PackedVector2Array = t._trails[0].history.duplicate()
	var camera: Camera2D = g.player.get_node("Camera2D")
	camera.global_position += Vector2(10,8)
	camera.force_update_scroll()
	s.sync()
	t.set_process(false)
	expect(t._trails[0].at==head and t._trails[0].history==history,"moving camera does not move existing history")
	t.advance(t.STEP)
	expect(t._trails[0].at!=head and t._trails[0].history!=history,"particle head advects and records a new history sample")
	# Newest head interpolates on 120 Hz display frames without a physics tick.
	var cursor: int = t._trails[0].cursor
	var displayed: Vector2 = t._trails[0].display[63]
	t.advance(t.STEP*0.5)
	expect(t._trails[0].cursor==cursor and t._trails[0].display[63]!=displayed,"substep display interpolation avoids frame-stepping")
	var reference := PackedVector2Array()
	for hz in [30,60,120]:
		t.stop()
		t._rng.seed = 241
		t.sync(1,s.wind)
		t.set_process(false)
		for i in hz*2: t.advance(1.0/hz)
		for i in t.COUNT:
			if hz==30: reference.append(t._trails[i].at)
			else: expect(reference[i].distance_to(t._trails[i].at)<0.02,"same trajectory at "+str(hz)+" Hz")
	var queries: int = root.get_node("CombatTargets").queries
	for i in 1800: t.advance(1.0/60)
	expect(t.get_child_count()==14 and t._vortices.size()==3 and root.get_node("CombatTargets").queries==queries,"long simulation bounded with no crowd scans")
	t.advance(10)
	expect(t.steps_last<=8,"long frame cannot cause unbounded catch-up")
	var at: Vector2 = t._trails[0].at
	paused = true
	t.advance(1)
	expect(t._trails[0].at==at,"pause freezes wind history")
	paused = false
	var force: Vector2 = s.wind_velocity()
	var settings: Node = root.get_node("SettingsStore")
	var old: float = settings.weather_intensity
	settings.weather_intensity = 0
	s.sync()
	expect(not t.live and not t.visible and s.wind_velocity()==force,"FX off stops visuals without changing force")
	for trail in t._trails: expect(trail.line.points.is_empty(),"zero FX clears visible ribbon")
	settings.weather_intensity = 0.3
	s.sync()
	t.set_process(false)
	var shown := 0
	for trail in t._trails: shown += int(trail.line.visible)
	expect(shown<=5,"low quality draws fewer trails")
	settings.weather_intensity = old
	g.spawner._rest_open = true
	t._process(0.01)
	expect(not t.live,"rest cleans transient wind field")
	g.spawner._rest_open = false
	s.sync()
	expect(t.live,"resume initializes clean histories")
	w.set_preview(5,0)
	expect(not t.live and s.ice_amount()==1,"weather change removes wind without affecting ice")
	w.set_preview(4,0)
	g.end_game()
	expect(not t.live and not t.is_processing(),"run exit releases visual work")
	main.queue_free()
	await process_frame
	if failures.is_empty(): print("WIND TRAILS OK: ",checks," checks")
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
