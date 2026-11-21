extends SceneTree

class Target extends StaticBody2D:
	var pulses := 0
	var slashes := 0
	var damage := 0.0
	func apply_hit(hit: Dictionary) -> void:
		damage += hit.damage
		if hit.from_status: pulses += 1
		else: slashes += 1

var checks := 0
var failures := 0
func _init() -> void: call_deferred("_run")
func check(ok: bool, msg: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(msg)

func place(g: Node, at: Vector2) -> Target:
	var t := Target.new()
	t.collision_layer = 8
	t.collision_mask = 0
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 1.0
	col.shape = shape
	t.add_child(col)
	t.add_to_group("EnemyGroup")
	g.add_child(t)
	t.global_position = at
	return t

func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await main._launch_run(&"blood_vortex")
	var g: Node = main.game
	var v: Node = g.blood_vortex
	g.spawner.timer.stop()
	g.spawner.get_node("Elite").stop()
	g.weather.stop()
	g.player.set_physics_process(false)
	v.set_physics_process(false)
	var actors := get_nodes_in_group("EnemyGroup")
	var origin: Vector2 = g.player.global_position
	for a in actors:
		a.set_physics_process(false)
		a.health = 2000
		a.defense = 0
	check(v.level == 3 and g.equipment_panel.get_level("blood_vortex") == 3, "rank three practice equips the real card")
	check(v.cast(), "nearby target starts a vortex")
	var center: Vector2 = v.global_position
	var outer: Node2D = actors[1]
	var dist := outer.global_position.distance_to(center)
	await physics_frame
	await physics_frame
	v._physics_process(0.1)
	check(outer.blood_vortex_source == v, "pull ownership assigned on entry")
	outer._physics_process(0.05)
	check(outer.global_position.distance_to(center) < dist, "real actor moves toward core")
	var targets: Array[Target] = []
	for i in 69: targets.append(place(g,center + Vector2.from_angle(TAU*i/69.0) * 44.0))
	var outside := place(g,center+Vector2.DOWN*120)
	var late := place(g,center+Vector2.UP*140)
	await physics_frame
	await physics_frame
	v._physics_process(0.89)
	check(targets[0].pulses == 0, "no damage before first second")
	paused = true
	v._physics_process(1.0)
	paused = false
	check(targets[0].pulses == 0 and is_equal_approx(v._age,0.99), "pause freezes the attack clock")
	v._physics_process(0.01)
	check(targets[68].pulses == 1 and targets[0].pulses == 1, "first pulse crosses the 64-body page boundary")
	late.global_position = center + Vector2.UP*60
	await physics_frame
	await physics_frame
	var damage: float = v._damage
	v.upgrade()
	v.set_physics_process(false)
	v._physics_process(2.04)
	check(targets[0].pulses == 3 and late.pulses == 2 and outside.damage == 0.0, "global beats include late arrivals even across long updates")
	late.global_position = center + Vector2.UP*160
	await physics_frame
	await physics_frame
	v._physics_process(2.0)
	var correct := true
	for t in targets: correct = correct and t.pulses == 4 and t.slashes == 1 and is_equal_approx(t.damage,damage * 7)
	check(correct, "all 69 targets receive four ordinary beats and one triple finisher using the cast snapshot")
	check(late.pulses == 2 and late.slashes == 0 and outside.damage == 0, "leaving the circle avoids the last beats")
	check(not v._active and outer.blood_vortex_source == null and outer.terrain_impulse.left > 0, "release and airborne impulse on the finishing beat")
	outer._tick_airborne_visual(0.09)
	check(outer.terrain_impulse.height() > 0, "physical knockback also lifts the visible sprite")
	v._physics_process(0.5)
	check(targets[0].slashes == 1 and not v._active, "afterimage cannot repeat damage")
	for rank in range(1,6):
		var stats: Dictionary = v.stats_for(rank)
		check(stats.beats == rank+2 and stats.damage == 12+3*(rank-1), "each rank adds one second, one beat and damage")
	check(v.cast() and v._beats == 6, "next cast uses upgraded duration")
	v._physics_process(0.15)
	g.variety.clear_combat_effects()
	check(not v._active and v._held.is_empty() and outer.blood_vortex_source == null and not v._fx.visible and v.level == 4, "stage exit releases without a late strike")
	g.spawner.stage = 1
	g.spawner.spawn_boss()
	var boss: Node = g.spawner._active_bosses[0]
	check(boss.catch_blood_vortex(v), "susceptible boss can be drawn")
	boss.control_time = 2.98
	boss._tick_environment_control(0.03)
	check(boss.blood_vortex_source == null and boss.is_control_immune() and not boss.catch_blood_vortex(v), "guard breaks and rejects renewed suction")
	var hp: float = boss.boss_current_health
	v._strike({boss.get_instance_id():boss},true)
	check(boss.boss_current_health < hp and boss.terrain_impulse.left == 0, "immune boss takes damage but resists launch")
	v.reset()
	check(v.level == 0 and not v.is_physics_processing(), "skill resets between runs")
	if not failures: print("BLOOD VORTEX OK: ",checks," checks")
	quit(1 if failures else 0)
