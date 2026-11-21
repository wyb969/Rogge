extends SceneTree

class Target extends StaticBody2D:
	var pulses := 0
	var slashes := 0
	var damage := 0.0
	var visible_hits := 0
	func apply_hit(hit: Dictionary) -> void:
		damage += hit.damage
		if not hit.get("quiet_crowd_feedback",false): visible_hits += 1
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
	var pulse_player: AudioStreamPlayer = v._pulse_sound
	var finish_player: AudioStreamPlayer = v._finish_sound
	var pulse_clip := pulse_player.stream as AudioStreamWAV
	var finish_clip := finish_player.stream as AudioStreamWAV
	check(pulse_clip != null and finish_clip != null and pulse_clip.format == AudioStreamWAV.FORMAT_16_BITS and finish_clip.format == AudioStreamWAV.FORMAT_16_BITS, "both cues are decoded PCM bound before the first beat")
	var outer: Node2D = actors[1]
	outer.global_position = center + Vector2(88,-19)
	var dist := outer.global_position.distance_to(center)
	await physics_frame
	await physics_frame
	v._physics_process(0.1)
	check(outer.blood_vortex_source == v, "pull ownership assigned on entry")
	outer._physics_process(0.05)
	check(outer.global_position.distance_to(center) < dist, "real actor moves toward core")
	# Trap a real body against a wide static blocker, then open the path.
	var wall := StaticBody2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(8,70)
	var wall_shape := CollisionShape2D.new()
	wall_shape.shape = box
	wall.add_child(wall_shape)
	wall.collision_layer = 8
	wall.collision_mask = 0
	g.add_child(wall)
	wall.global_position = outer.global_position + Vector2(-13,0)
	await physics_frame
	await physics_frame
	for step in 4: v.pull_body(outer,0.05,1.0)
	var stopped := outer.global_position
	var id := outer.get_instance_id()
	check(v._retry_at.has(id), "blocked sweep starts a bounded retry delay")
	wall.queue_free()
	await physics_frame
	await physics_frame
	v.pull_body(outer,0.05,1.0)
	check(outer.global_position.is_equal_approx(stopped), "blocked actor skips immediate repeat sweeps")
	var before: float = v._age
	v._age += 0.17
	v.pull_body(outer,0.05,1.0)
	check(outer.global_position.distance_to(center) < stopped.distance_to(center), "pull resumes through the opened gap")
	v._age = before
	var targets: Array[Target] = []
	var crowd_size: int = v.PAGE_SIZE + 5
	for i in crowd_size: targets.append(place(g,center + Vector2.from_angle(TAU*i/crowd_size) * 29.0))
	var outside := place(g,center+Vector2.DOWN*120)
	var late := place(g,center+Vector2.UP*140)
	var near := place(g,origin+Vector2(9,3))
	var mid := place(g,center+Vector2(0,39))
	var far := place(g,origin+Vector2(247,55))
	var narrow_side := place(g,origin+Vector2(20,36))
	var past_tip := place(g,origin+Vector2(281,0))
	await physics_frame
	await physics_frame
	var interval: float = v._interval
	v._physics_process(interval-0.11)
	check(targets[0].pulses == 0, "no damage before first beat")
	paused = true
	v._physics_process(1.0)
	paused = false
	check(targets[0].pulses == 0 and is_equal_approx(v._age,interval-0.01), "pause freezes the attack clock")
	v._physics_process(0.01)
	check(targets.back().pulses == 1 and targets[0].pulses == 1, "first pulse crosses the query page boundary")
	var visible_hits := 0
	for t in targets: visible_hits += t.visible_hits
	check(visible_hits <= v.CROWD_FEEDBACK, "crowd hits cap repeated cosmetics without dropping damage")
	check(near.pulses == 1 and mid.pulses == 1 and far.pulses == 1, "sword end, middle and far mouth are damaging")
	check(narrow_side.pulses == 0 and past_tip.pulses == 0, "narrow flank and beyond mouth remain outside")
	late.global_position = center + Vector2.UP*24
	await physics_frame
	await physics_frame
	var damage: float = v._damage
	var cast_beats: int = v._beats
	v.upgrade()
	v.set_physics_process(false)
	v._physics_process(interval*2+0.04)
	check(targets[0].pulses == 3 and late.pulses == 2 and outside.damage == 0.0, "global beats include late arrivals even across long updates")
	late.global_position = center + Vector2.UP*160
	await physics_frame
	await physics_frame
	v._physics_process(interval*(cast_beats-3))
	var correct := true
	for t in targets: correct = correct and t.pulses == cast_beats-1 and t.slashes == 1 and is_equal_approx(t.damage,damage * (cast_beats+2))
	check(correct, "every target across both query pages receive the snapshotted ordinary beats and one triple finisher using the cast snapshot")
	check(late.pulses == 2 and late.slashes == 0 and outside.damage == 0, "leaving the circle avoids the last beats")
	check(not v._active and outer.blood_vortex_source == null and outer.terrain_impulse.left > 0, "release and airborne impulse on the finishing beat")
	outer._tick_airborne_visual(0.09)
	check(outer.terrain_impulse.height() > 0, "physical knockback also lifts the visible sprite")
	v._physics_process(0.5)
	check(targets[0].slashes == 1 and not v._active, "afterimage cannot repeat damage")
	for rank in range(1,6):
		var stats: Dictionary = v.stats_for(rank)
		check(stats.beats == 6+2*(rank-1) and is_equal_approx(stats.interval,0.50-0.03*(rank-1)) and is_equal_approx(stats.duration, stats.beats * stats.interval) and stats.damage == 12+3*(rank-1), "rank increases hits, frequency, duration and damage")
	check(v.cast() and v._beats == 12, "next cast uses upgraded duration")
	v._physics_process(0.15)
	g.variety.clear_combat_effects()
	check(not v._active and v._held.is_empty() and v._retry_at.is_empty() and outer.blood_vortex_source == null and not v._fx.visible and v.level == 4, "stage exit releases without a late strike")
	# Rotate a real cast toward an enemy below the player; test a complete rank-one cycle.
	for a in actors: a.global_position = origin+Vector2(-480,0)
	for t in targets: t.global_position = origin+Vector2(500,0)
	for t in [outside,late,near,mid,far,narrow_side,past_tip]: t.global_position = origin+Vector2(-500,0)
	var vertical := place(g,origin+Vector2(0,30))
	var vertical_tip := place(g,origin+Vector2(51,248))
	var wrong_axis := place(g,origin+Vector2(180,0))
	await physics_frame
	await physics_frame
	v.reset()
	v.upgrade()
	v.set_physics_process(false)
	check(v.cast() and v._heading.dot(Vector2.DOWN) > 0.99, "real cast turns the entire hit area toward the target")
	v._physics_process(0.49)
	check(vertical.pulses == 0, "rank one waits a full half second")
	for i in 5:
		v._physics_process(0.01 if i == 0 else 0.5)
		check(vertical.pulses == i+1 and vertical.slashes == 0, "first five rank-one half-second beats are ordinary")
	v._physics_process(0.499)
	check(vertical.slashes == 0, "final strike waits until three seconds")
	v._physics_process(0.001)
	check(vertical_tip.pulses == 5 and vertical_tip.slashes == 1 and wrong_axis.damage == 0 and is_equal_approx(vertical.damage,96.0), "sixth hit is a single triple finisher along the rotated helix")
	check(v._pulse_sound == pulse_player and v._finish_sound == finish_player and pulse_clip == pulse_player.stream and finish_clip == finish_player.stream, "casts reuse both players and clips")
	g.combat_feedback.impact_feedback.clear_combat_effects()
	var stops: int = g.combat_feedback.impact_feedback.stops
	var flashes: int = g.combat_feedback.impact_feedback.flashes
	v._strike({outer.get_instance_id():outer},true)
	check(g.combat_feedback.impact_feedback.stops == stops and g.combat_feedback.impact_feedback.flashes > flashes and is_equal_approx(Engine.time_scale,1.0), "enemy finisher flashes without slowing the game")
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
	check(g.combat_feedback.impact_feedback.stops == stops and is_equal_approx(Engine.time_scale,1.0), "boss finisher also keeps the world clock running")
	v.reset()
	check(not pulse_player.playing and not finish_player.playing, "teardown stops both cues")
	check(v.level == 0 and not v.is_physics_processing(), "skill resets between runs")
	if not failures: print("BLOOD VORTEX OK: ",checks," checks")
	quit(1 if failures else 0)
