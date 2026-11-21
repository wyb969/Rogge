extends SceneTree

var checks := 0
var failures: Array[String] = []

func _init() -> void: call_deferred("_run")

func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok: failures.append(note)

func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await main._launch_run(&"ice_wave")
	var g: Node = main.game
	var wave: Node = g.ice_wave
	g.spawner.timer.stop()
	g.spawner.get_node("Elite").stop()
	g.weather.stop()
	g.player.set_physics_process(false)
	wave.set_physics_process(false)
	var targets := get_nodes_in_group("EnemyGroup")
	var origin: Vector2 = g.player.global_position
	var offsets := [Vector2(45,0), Vector2(130,0), Vector2(188,0), Vector2(90,90), Vector2(-110,0)]
	for i in targets.size():
		targets[i].set_physics_process(false)
		targets[i].health = 1000.0
		targets[i].defense = 0.0
		targets[i].global_position = origin + offsets[i % offsets.size()]
	await physics_frame
	await physics_frame
	check(wave.level == 3 and g.equipment_panel.get_level("ice_wave") == 3, "real practice loadout")
	check(wave.cast(), "nearest target starts a wave")
	var near := 2
	var far := 3
	var gap_rest: float = wave._plate_center(near,0.05).distance_to(wave._plate_center(far,0.05-wave.FRONT_DELAY))
	var gap_jam: float = wave._plate_center(near,0.175).distance_to(wave._plate_center(far,0.175-wave.FRONT_DELAY))
	var gap_release: float = wave._plate_center(near,0.30).distance_to(wave._plate_center(far,0.30-wave.FRONT_DELAY))
	check(gap_jam < gap_rest * 0.75 and gap_release > gap_jam * 1.75, "adjacent plates compress and then separate")
	# Check the real movement in arena coordinates, including straight vertical casts.
	var saved_heading: Vector2 = wave._heading
	for heading in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN, Vector2(1,1).normalized()]:
		wave._heading = heading
		var leftmost := 0.0
		var rightmost := 0.0
		var last_forward := -INF
		var forward_only := true
		var start: Vector2 = wave._plate_center(2, 0.045)
		for frame in range(3, 26):
			var offset: Vector2 = wave._plate_center(2, frame / 60.0) - wave._origin
			var side: float = offset.dot(heading.orthogonal())
			leftmost = minf(leftmost, side)
			rightmost = maxf(rightmost, side)
			var along: float = offset.dot(heading)
			forward_only = forward_only and along >= last_forward - 0.01
			last_forward = along
		check(leftmost < -0.15 * wave._radius and rightmost > 0.15 * wave._radius, "peak crosses both sides of its heading")
		check(forward_only and (wave._plate_center(2,0.41) - start).dot(heading) > wave._radius, "peak travels outward during the whole sway")
	wave._heading = saved_heading
	check(wave._shell_frame(0.28,0) != wave._shell_frame(0.50,0) and wave._shell_frame(1.20,0) == wave._shell_frame(0.28,0), "frozen shell highlights cycle after the initial freeze")
	for rank in range(1,6):
		check(is_equal_approx(wave.stats_for(rank).freeze_chance, (40 + 8 * (rank - 1)) * 0.01), "freeze chance tracks real combat rank")
	wave._chance = 1.0
	wave._physics_process(0.055)
	check(targets[0].health == 1000, "crack telegraphs before hit")
	wave._physics_process(0.044)
	check(targets[0].blade_ice != null and targets[1].health == 1000, "front propagates and freezes on first impact")
	wave._physics_process(0.78)
	for i in 3:
		check(is_equal_approx(targets[i].health, 1000.0-wave._damage) and targets[i].blade_ice != null, "each pierced target takes one hit per wave")
	check(targets[3].health == 1000 and targets[4].health == 1000, "off-axis and behind remain safe")
	var actor: Node = targets[0]
	var at: Vector2 = actor.global_position
	actor._physics_process(0.12)
	check(actor.global_position == at and actor.velocity == Vector2.ZERO, "encased target cannot move")
	actor.apply_hit({"damage": 3, "from_status": true})
	actor.apply_hit({"damage": 0})
	check(actor.blade_ice != null and wave._bursts.is_empty(), "ticks and zero hits do not shatter")
	var hp: float = actor.health
	actor.apply_hit({"damage": 10})
	check(is_equal_approx(hp-actor.health, 10 + 0.60 * wave._damage), "follow-up adds correct shatter damage once")
	check(actor.blade_ice == null and wave._bursts.size()==1, "shatter releases and emits chips")
	hp = actor.health
	actor.apply_hit({"damage": 10})
	check(is_equal_approx(hp-actor.health, 10), "third hit gets no second bonus")
	actor.apply_freeze({"freeze_duration":4,"slow_factor":0.4})
	wave._freeze(actor)
	actor._physics_process(2.16)
	check(actor.blade_ice == null and actor.freeze_time > 0 and wave._bursts.size() == 1, "natural thaw leaves passive slow and deals no break damage")
	check(wave.cast(), "new wave after recovery")
	wave._chance = 1.0
	wave._physics_process(0.68)
	check(targets[1].blade_ice == null and targets[2].blade_ice == null, "next wave shatters earlier shells and cannot re-freeze on the same hit")
	g.variety.clear_combat_effects()
	check(wave._shells.is_empty() and wave._bursts.is_empty() and actor.blade_ice == null and wave.level == 3, "transition releases pending wave and active shells")
	for i in range(1,5):
		var low: Dictionary = wave.stats_for(i)
		var high: Dictionary = wave.stats_for(i+1)
		check(high.damage > low.damage and high.radius > low.radius and high.range > low.range and high.freeze_chance > low.freeze_chance, "all four upgrade values rise")
	g.spawner.stage = 1
	g.spawner.spawn_boss()
	var boss: Node = g.spawner._active_bosses[0]
	boss.set_physics_process(false)
	wave._freeze(boss)
	check(boss.blade_ice != null and is_equal_approx(boss.blade_ice.left,0.85), "boss receives shorter ice")
	boss.control_time = 2.9
	boss._tick_environment_control(0.11)
	check(boss.blade_ice == null and boss.is_control_immune(), "continuous boss control releases shell")
	wave._freeze(boss)
	check(boss.blade_ice == null, "immune boss rejects shell")
	for note in failures: push_error(note)
	if failures.is_empty(): print("ICE WAVE OK: ",checks," checks")
	quit(1 if not failures.is_empty() else 0)
