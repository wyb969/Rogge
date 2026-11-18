extends SceneTree

var failures: Array[String] = []
var actors: Array[Node] = []
var player: Node

func _init() -> void :
	call_deferred("_run")

func _run() -> void :
	seed(4321)
	var game: Node = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.spawner.timer.stop()
	game.spawner.get_node("Elite").stop()
	for name in ["HandWeapon", "CircleWeapon", "Weapon", "DroneController", "MolotovController", "FreezeController"]:
		game.get_node(name).process_mode = Node.PROCESS_MODE_DISABLED
	player = game.player
	player.set_physics_process(false)
	player.player_health = 100000.0
	for i in range(24):
		var enemy: Node = load("res://scenes/enemy_shell.tscn").instantiate()
		enemy.set_enemy_data(load("res://resource/Enemy_5.tres"))
		enemy.set_player_ref(player)
		enemy.add_to_group("EnemyGroup")
		game.add_child(enemy)
		enemy.set_physics_process(false)
		enemy.collision_mask = 0
		enemy.collision_layer = 0
		actors.append(enemy)
	var first_timers: Array[float] = []
	for enemy in actors:
		first_timers.append(enemy.dash_timer)
	first_timers.sort()
	_expect(first_timers.back() - first_timers.front() > 0.4, "same-wave first charges are staggered")

	var dasher: Node = actors[0]
	for dt in [1.0 / 30.0, 1.0 / 60.0, 0.5]:
		dasher.global_position = Vector2.ZERO
		player.global_position = Vector2(110, 0)
		dasher.dash_timer = 0.0
		dasher._physics_process(0.01)
		_expect(is_equal_approx(dasher.dash_windup, 0.6) and dasher.velocity.is_zero_approx(), "leap starts with a stationary 0.6-second tracking/lock warning")
		player.global_position = Vector2(0, 110)
		dasher._physics_process(0.2)
		_expect( not dasher.is_dashing and dasher.global_position.is_zero_approx() and dasher.dash_dir.y > 0.9, "red arrow smoothly follows aim while the body stays still")
		dasher._physics_process(0.2)
		var locked_dir: Vector2 = dasher.dash_dir
		_expect(dasher.dash_warning_locked() and not dasher.is_dashing, "arrow stops for the final 0.2-second lock beat")
		player.global_position = Vector2(20, 0)
		player.hurt_lock = 0.0
		var warning_hp: float = player.player_health
		dasher.contact_timer = 0.0
		dasher._physics_process(0.1)
		_expect(dasher.dash_dir.is_equal_approx(locked_dir) and player.player_health == warning_hp and not dasher.is_dashing, "locked arrow cannot retarget or inflict warning contact damage")
		player.global_position = Vector2(0, -110)
		dasher._physics_process(0.1)
		_expect(dasher.is_dashing and dasher.dash_dir.is_equal_approx(locked_dir), "leap begins only after the fixed arrow's hold ends")
		var steps: = 0
		while dasher.is_dashing and steps < 30:
			dasher._physics_process(dt)
			steps += 1
		_expect(dasher.global_position.is_equal_approx(locked_dir * 57.2), "locked leap distance is capped at 57.2 even with delta %.3f (actual %s)" % [dt, dasher.global_position])
		_expect(dasher.dash_timer >= 2.0 and dasher.dash_timer <= 2.4, "charge cooldown is 2.0–2.4 seconds")

	dasher.is_dashing = true
	dasher.dash_time_left = dasher.DASH_SECONDS * 0.5
	dasher._apply_move_juice(0.01)
	_expect(is_equal_approx(dasher.dash_jump_height(), 14.0) and dasher.sprite_2d.position.y < -14.0, "leap lifts the body above its ground shadow at midpoint")
	dasher._finish_dash()
	_expect(is_zero_approx(dasher.dash_jump_height()), "landing restores zero jump height")
	dasher.dash_windup = 0.1
	dasher.freeze_time = 1.0
	dasher._physics_process(0.2)
	_expect( not dasher.is_dashing and dasher.dash_windup == 0.0 and dasher.dash_timer >= 2.0, "freeze cancels warning and releases its charge reservation")
	dasher.freeze_time = 0.0
	dasher.is_dashing = true
	dasher.contact_timer = 0.0
	player.hurt_lock = 0.0
	var hp: float = player.player_health
	dasher._try_contact(20.0)
	_expect(is_equal_approx(hp - player.player_health, 92.5), "baseline charge damage drops from 125.8 to 92.5")
	player.hurt_lock = 0.0
	dasher._try_contact(20.0)
	_expect(is_equal_approx(hp - player.player_health, 92.5) and dasher.contact_timer >= 0.65, "charge does not shorten the repeat-contact cooldown")
	dasher.contact_timer = 0.0
	player.dashing = true
	hp = player.player_health
	dasher._try_contact(20.0)
	_expect(player.player_health == hp, "player dash immunity still avoids charge damage")
	player.dashing = false

	for enemy in actors:
		enemy.is_dashing = false
		enemy.dash_windup = 0.0
		enemy.dash_timer = 0.0
	var charged: = {}
	var max_committed: = 0



	for frame in range(1200):
		for enemy in actors:
			enemy._steer_dasher(1.0 / 60.0, Vector2.RIGHT, 100.0, enemy.speed)
			if enemy.is_dashing:
				charged[enemy.get_instance_id()] = true
		var committed: = 0
		for enemy in actors:
			if enemy.is_dashing or enemy.dash_windup > 0.0:
				committed += 1
		max_committed = maxi(max_committed, committed)
	_expect(max_committed == 3, "a 24-dasher theme has at most three warnings/charges at once (actual %d)" % max_committed)
	_expect(charged.size() == actors.size(), "charge budget rotates through the whole crowd without starvation")
	for enemy in actors:
		enemy.is_dashing = false
		enemy.dash_windup = 0.0
	for i in range(3):
		actors[i].dash_windup = 0.4
	_expect( not actors[3]._dash_slot_available(), "three living warnings reserve the charge budget")
	actors[0]._death_started = true
	_expect(actors[3]._dash_slot_available(), "a killed enemy releases its reservation immediately")
	actors[0]._death_started = false
	actors[0].queue_free()
	_expect(actors[3]._dash_slot_available(), "queued cleanup cannot leave a stale charge reservation")

	if failures.is_empty():
		print("DASHER BALANCE OK: smooth tracking/red-arrow lock, harmless warning, jump/landing, 30/60 FPS and slow-frame distance, stagger, damage, immunity, freeze and 24-enemy charge budget")
	else:
		for failure in failures:
			push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _expect(ok: bool, message: String) -> void :
	if not ok:
		failures.append(message)
