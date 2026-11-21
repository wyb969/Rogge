extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(note)

func _init() -> void: call_deferred("_run")

func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await main._launch_run(&"ghost_dash")
	var g: Node = main.game
	var skill: Node = g.ghost_dash
	var p: Node = g.player
	g.spawner.timer.stop()
	g.spawner.get_node("Elite").stop()
	g.weather.stop()
	p.set_physics_process(false)
	var actors := get_nodes_in_group("EnemyGroup")
	var start: Vector2 = p.global_position
	var offsets := [Vector2(35,0),Vector2(83,6),Vector2(133,-3),Vector2(74,75),Vector2(-62,0)]
	for i in actors.size():
		actors[i].set_physics_process(false)
		actors[i].global_position = start + offsets[i]
		actors[i].health = 800.0
		actors[i].defense = 0.0
	await physics_frame
	await physics_frame
	check(skill.level == 3 and p.ghost_dash == skill, "debug equips the real dash on the player")
	for i in range(2,6):
		var a: Dictionary = skill.stats_for(i-1)
		var b: Dictionary = skill.stats_for(i)
		check(b.interval < a.interval and b.range > a.range and b.damage > a.damage,"rank changes cooldown distance and damage")
	p._start_dash(Vector2.RIGHT)
	for i in 9: p._physics_process(1.0/60)
	check(not p.dashing and is_equal_approx(p.global_position.distance_to(start), skill._stats.range), "real dash covers its ranked distance and ends")
	check(is_equal_approx(p.can_dasing_timer.wait_time,skill._stats.interval), "HUD timer uses ranked cooldown")
	check(skill.marks.size() == 3, "three path targets tagged once, flank and rear missed")
	var saved: Vector2 = actors[1].global_position
	actors[1]._physics_process(0.2)
	check(actors[1].ghost_bound and actors[1].global_position == saved and actors[1].velocity == Vector2.ZERO, "pursuit is held")
	skill.set_physics_process(false)
	await physics_frame
	await physics_frame
	skill._physics_process(0.52)
	check(actors[0].ghost_bound and actors[0].health == 800, "no damage before expiry")
	check(skill._fx.mark_opacity(0,1) == 0 and skill._fx.mark_opacity(0.1,1) < 1 and skill._fx.mark_opacity(0.5,1) == 1 and skill._fx.mark_opacity(0.9,1) < 1 and skill._fx.mark_opacity(1,1) == 0, "skull fades in and out within control")
	actors[1].apply_electric_stun(0.45)
	skill._physics_process(0.49)
	for i in 3:
		check(not actors[i].ghost_bound and is_equal_approx(actors[i].health,800.0 - skill._stats.damage), "release delivers exactly one delayed hit")
	check(actors[1].electric_stun_left > 0 and skill.marks.is_empty(), "independent stun stays active")
	skill.begin_pass()
	skill.sweep(start,start+Vector2(150,0))
	g.variety.clear_combat_effects()
	check(skill.marks.is_empty() and not actors[0].ghost_bound and skill.level == 3, "transition releases marks without cashing them")
	# Two quick passes refresh control and pay each cast at its original deadline.
	p.apply_rest_cooldown(0.5)
	p.reset_dash()
	p._start_dash(Vector2.UP)
	check(is_equal_approx(p.can_dasing_timer.wait_time,skill._stats.interval * 0.5), "rest bonus applies to ranked dash cooldown")
	p.reset_dash()
	var hp_before: float = actors[0].health
	skill.begin_pass()
	skill.sweep(start,start+Vector2(50,0))
	skill.set_physics_process(false)
	await physics_frame
	await physics_frame
	skill._physics_process(0.72)
	skill.begin_pass()
	skill.sweep(start,start+Vector2(50,0))
	skill.set_physics_process(false)
	await physics_frame
	await physics_frame
	skill._physics_process(0.30)
	check(actors[0].ghost_bound and is_equal_approx(actors[0].health,hp_before-skill._stats.damage), "first pass pays during a refreshed hold")
	skill._physics_process(0.71)
	check(not actors[0].ghost_bound and is_equal_approx(actors[0].health,hp_before-2*skill._stats.damage), "second pass pays once at its own deadline")
	g.spawner.stage = 1
	g.spawner.spawn_boss()
	var boss: Node = g.spawner._active_bosses[0]
	boss.set_physics_process(false)
	boss.global_position = start
	await physics_frame
	await physics_frame
	skill.begin_pass()
	skill.sweep(start,start+Vector2(4,0))
	check(boss.ghost_bound, "boss is susceptible before reaching the control limit")
	boss.control_time = 2.98
	boss._tick_environment_control(0.03)
	check(not boss.ghost_bound and boss.is_control_immune(), "boss guard breaks the hold")
	skill.clear_combat_effects()
	skill.begin_pass()
	skill.sweep(start,start+Vector2(4,0))
	check(skill.marks.has(boss.get_instance_id()) and not skill.marks[boss.get_instance_id()].controlled, "immune boss still receives delayed damage mark without a false skull")
	skill.set_physics_process(false)
	await physics_frame
	await physics_frame
	var hp: float = boss.boss_current_health
	skill._physics_process(1.01)
	check(boss.boss_current_health < hp, "control immunity preserves damage")
	# A real solid wall must truncate the sweep before a target behind it.
	var wall := StaticBody2D.new()
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(12, 160)
	collider.shape = shape
	wall.add_child(collider)
	g.add_child(wall)
	wall.global_position = start + Vector2(0, -320)
	p.global_position = wall.global_position - Vector2(100,0)
	actors[4].global_position = wall.global_position + Vector2(55,0)
	await physics_frame
	await physics_frame
	p.reset_dash()
	p._start_dash(Vector2.RIGHT)
	for i in 9: p._physics_process(1.0/60)
	check(p.global_position.x < wall.global_position.x and not actors[4].ghost_bound, "a wall stops movement and marks")
	skill.reset()
	p.reset_dash()
	p._start_dash(Vector2.UP)
	check(p.dashing_timer.time_left > 0 and is_equal_approx(p.can_dasing_timer.wait_time,p.DASH_COOLDOWN * p.cooldown_scale) and is_equal_approx(p.velocity.length(),p.DASH_SPEED), "unequipping restores original dash")
	if not failures: print("GHOST DASH OK: ",checks," checks")
	quit(1 if failures else 0)
