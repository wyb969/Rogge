extends SceneTree

class Target extends StaticBody2D:
	var hits := 0
	var damage := 0.0
	var protected := false
	func vulnerable() -> bool: return not protected
	func apply_hit(hit: Dictionary) -> void:
		hits += 1
		damage += hit.damage

var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func place(g: Node, at: Vector2) -> Target:
	var target := Target.new()
	target.collision_layer = 8
	target.collision_mask = 0
	var shape := CircleShape2D.new()
	shape.radius = 2.0
	var collider := CollisionShape2D.new()
	collider.shape = shape
	target.add_child(collider)
	target.add_to_group("EnemyGroup")
	g.add_child(target)
	target.global_position = at
	return target

func _init() -> void: call_deferred("_run")

func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await main._launch_run(&"draw_slash")
	var g: Node = main.game
	var blade: Node = g.draw_slash
	g.spawner.stop_run()
	g.player.set_physics_process(false)
	blade.set_physics_process(false)
	g.clear_enemies()
	await process_frame
	var origin: Vector2 = g.player.global_position
	var rank: Dictionary = blade._stats
	check(blade.level == 3 and g.equipment_panel.get_level("draw_slash") == 3, "practice equips rank three")
	blade._physics_process(3.0)
	check(blade._windup < 0.0, "empty arena does not trigger an attack")
	var crowd: Array[Target] = []
	for i in 72:
		crowd.append(place(g, origin + Vector2.from_angle(i * TAU / 72.0) * (rank.radius - 15.0)))
	var boundary := place(g, origin + Vector2.RIGHT * (rank.radius + 7.0))
	var outside := place(g, origin + Vector2.DOWN * (rank.radius + 6.0))
	var protected := place(g, origin)
	protected.protected = true
	await physics_frame
	await physics_frame
	blade._physics_process(0.16)
	check(blade._windup > 0.0 and blade._fx.visible, "nearby enemies trigger a visible draw")
	blade._physics_process(0.03)
	check(crowd[0].hits == 0, "no damage during preparation")
	g.player.global_position += Vector2(6,0)
	blade._physics_process(0.031)
	check(all_hit_once(crowd, rank.damage), "all 72 opponents receive exactly one direct hit at all angles")
	check(boundary.hits == 1 and outside.hits == 0, "actual body edge overlaps the moving cast center")
	check(protected.hits == 0, "protected trial actor takes no damage")
	check(blade._fx.global_position == g.player.global_position, "cut is drawn at its damage center")
	g.player.global_position += Vector2(16,0)
	blade._physics_process(0.31)
	check(crowd[0].hits == 1 and blade._fx.global_position != g.player.global_position, "afterimage cannot follow or hit again")
	blade._physics_process(2.0)
	check(blade._windup > 0, "cooldown rearms the next cut")
	g.variety.clear_combat_effects()
	blade._physics_process(0.08)
	check(crowd[0].hits == 1 and not blade._fx.visible and blade.level == 3, "transition cancels pending strike and preserves rank")
	for i in range(1,5):
		var a: Dictionary = blade.stats_for(i)
		var b: Dictionary = blade.stats_for(i+1)
		check(b.damage > a.damage and b.radius > a.radius and b.interval < a.interval, "damage and radius rise as cooldown falls")
	blade.reset()
	check(blade.level == 0 and not blade.is_physics_processing(), "reset unequips and silences weapon")
	if not failures: print("DRAW SLASH OK: ", checks, " checks")
	quit(1 if failures else 0)

func all_hit_once(crowd: Array[Target], expected: float) -> bool:
	for target in crowd:
		if target.hits != 1 or not is_equal_approx(target.damage, expected): return false
	return true
