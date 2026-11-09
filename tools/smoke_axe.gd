extends SceneTree

class Target extends CharacterBody2D:
	var health: = 100000.0
	var hits: = 0
	var last_hit: = {}
	func apply_hit(data: Dictionary) -> void :
		hits += 1
		last_hit = data
		health -= float(data.damage)

var failures: Array[String] = []
var game: Node
var axe: Node
var player: Node

func _init() -> void :
	call_deferred("_run")

func _run() -> void :
	game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.spawner.timer.stop()
	game.spawner.get_node("Elite").stop()
	for name in ["HandWeapon", "CircleWeapon", "Weapon", "DroneController", "MolotovController", "FreezeController"]:
		game.get_node(name).set_process(false)
		game.get_node(name).set_physics_process(false)
	player = game.player
	player.set_physics_process(false)
	player.global_position = Vector2(0, 1000)
	axe = game.hand_weapon
	axe.get_node("AttackTimer").stop()
	axe.relative_pos = Vector2.ZERO
	axe.global_position = player.global_position
	game.current_level = 5
	for i in range(4):
		game._on_upgrade_selected("axe_up")
	_expect(game.equipment_panel.get_level("axe_up") == 5, "four real cards reach axe level five")
	_expect(axe.max_speed > 200 and axe.max_speed <= 600, "level-five speed remains visible and bounded (actual %s)" % axe.max_speed)
	var level_five_damage: float = axe.weapon_demage
	for i in range(16):
		game._on_upgrade_selected("axe_up")
	_expect(axe.max_speed <= 600 and axe.weapon_demage > level_five_damage, "later card stacks keep speed bounded and damage increasing")

	var far: = _target(Vector2(180, 1000))
	var near: = _target(Vector2(80, 1000))
	_expect(axe.get_nearest_enemy() == near, "aim chooses the nearest live target")
	near.health = 0.0
	_expect(axe.get_nearest_enemy() == far, "dead targets cannot consume a throw")
	near.health = 100000.0
	far.position.x = 140.0
	var off_path: = _target(Vector2(80, 1040))

	await physics_frame
	await process_frame
	axe.max_speed = 600
	axe.weapon_demage = 10.0
	axe.start_attack()
	axe._physics_process(0.5)
	_expect(near.hits == 1 and far.hits == 1, "one slow frame hits every enemy crossed on the outward path")
	_expect(off_path.hits == 0, "swept damage does not hit enemies outside the flight corridor")
	_expect(axe.global_position.is_equal_approx(Vector2(200, 1000)), "outward flight clips exactly at maximum range")
	_expect(axe.returning and not axe.flying_out, "maximum range begins a return")
	for i in range(60):
		axe._physics_process(1.0 / 60.0)
	_expect(near.hits == 2 and far.hits == 2, "each enemy takes one hit per leg, with no overlap spam")
	_expect( not axe.returning and not axe.flying_out and axe.global_position.is_equal_approx(player.global_position), "return clamps to the hand without oscillating")
	_expect(near.last_hit.get("effect", "") == "" and near.last_hit.get("source") == axe, "physical axe hits keep their source without granting an unowned burn effect")
	var hits_before: int = near.hits
	axe._physics_process(0.5)
	_expect(near.hits == hits_before, "idle axe cannot deal phantom damage")

	axe.start_attack()
	axe._physics_process(0.5)
	player.global_position = Vector2(30, 1060)
	axe._physics_process(0.5)
	_expect( not axe.returning and axe.global_position.is_equal_approx(player.global_position), "large return step catches a moving player's current hand")
	far.queue_free()
	near.queue_free()
	off_path.queue_free()
	await process_frame
	axe.start_attack()
	_expect( not axe.flying_out and not axe.returning, "no target leaves axe ready at the hand")
	player.global_position = Vector2(0, 1000)
	var real_target: Node = _enemy(Vector2(80, 1000))
	var neighbor: Node = _enemy(Vector2(80, 1055))
	await physics_frame
	await process_frame
	axe.start_attack()
	axe._physics_process(0.5)
	axe._physics_process(0.5)
	_expect(real_target.health == 980 and real_target.burn_stacks == 0, "real enemies receive two physical axe hits without being ignited")
	real_target._update_statuses(0.9)
	_expect(real_target.health == 980 and neighbor.health == 1000 and neighbor.burn_stacks == 0, "an unowned gasoline effect cannot deal delayed or spreading damage to the crowd")
	var book: Node = game.circle_weapon.get_child(0)
	book._on_area_2d_body_entered(real_target)
	book._on_area_2d_body_entered(real_target)
	real_target._update_statuses(0.9)
	_expect(real_target.health == 970 and real_target.burn_stacks == 0 and neighbor.health == 1000, "starting books cannot reintroduce the same unowned burn during axe attacks")
	if failures.is_empty():
		print("AXE OK: real level-five/later cards, nearest live aim, swept hits/return, no idle damage and no unowned burn/spread from either starting weapon")
	else:
		for failure in failures:
			push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _target(at: Vector2) -> Target:
	var target: = Target.new()
	target.collision_layer = 8
	target.collision_mask = 0
	target.position = at
	for offset in [Vector2(-2, 0), Vector2(2, 0)]:
		var collider: = CollisionShape2D.new()
		var shape: = CircleShape2D.new()
		shape.radius = 8.0
		collider.shape = shape
		collider.position = offset
		target.add_child(collider)
	target.add_to_group("EnemyGroup")
	game.add_child(target)
	return target

func _enemy(at: Vector2) -> Node:
	var actor: Node = load("res://scenes/enemy_shell.tscn").instantiate()
	actor.set_player_ref(player)
	actor.set_enemy_data(load("res://resource/Enemy_1.tres"))
	actor.health = 1000
	actor.defense = 0.0
	actor.add_to_group("EnemyGroup")
	game.add_child(actor)
	actor.global_position = at
	actor.set_physics_process(false)
	return actor

func _expect(ok: bool, message: String) -> void :
	if not ok:
		failures.append(message)
