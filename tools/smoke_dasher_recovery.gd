extends SceneTree
var failures: Array[String] = []
var game: Node
var player: Node
func _init() -> void :
	call_deferred("_run")
func _expect(ok: bool, message: String) -> void :
	if not ok: failures.append(message)
func _spawn() -> Node:
	var enemy: Node = load("res://scenes/enemy_shell.tscn").instantiate()
	enemy.set_enemy_data(load("res://resource/Enemy_5.tres"))
	enemy.set_player_ref(player)
	game.add_child(enemy)
	enemy.collision_layer = 0
	enemy.collision_mask = 0
	enemy.set_physics_process(false)
	enemy.contact_timer = 0
	return enemy
func _run() -> void :
	game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	game.spawner.timer.stop()
	game.spawner.get_node("Elite").stop()
	for name in ["HandWeapon", "CircleWeapon", "Weapon", "DroneController", "MolotovController", "FreezeController"]:
		game.get_node(name).process_mode = Node.PROCESS_MODE_DISABLED
	player = game.player
	player.set_physics_process(false)
	player.max_player_health = 100000
	player.player_health = 100000
	for step in [1.0 / 60.0, 1.0 / 30.0, 0.5]:
		for dash_hit in [false, true]:
			var enemy: Node = _spawn()
			player.global_position = Vector2(20, 0)
			player.hurt_lock = 0
			enemy.is_dashing = dash_hit
			enemy.dash_time_left = 0.2
			enemy.velocity = Vector2.RIGHT * 260
			enemy.knockback = Vector2(100, 30)
			var hp: float = player.player_health
			enemy._try_contact(20)
			_expect(is_equal_approx(hp - player.player_health, 92.5 if dash_hit else 74), "ordinary/dash contact retains its actual damage")
			_expect(enemy.contact_recovery_left == 0.9 and not enemy.is_dashing and enemy.velocity.is_zero_approx(), "contact immediately lands and stops the fast attacker")
			_expect(enemy.contact_timer >= 0.9 and enemy.dash_timer >= 2, "recovery prevents repeat contact and an immediate new charge")
			var anchor: Vector2 = enemy.global_position
			var elapsed: = 0.0
			var steps: = 0
			while enemy.contact_recovery_left > 0 and steps < 200:
				player.hurt_lock = 0
				enemy.contact_timer = 0
				enemy.knockback = Vector2(100, 30)
				enemy._physics_process(step)
				if enemy.contact_recovery_left > 0: enemy._try_contact(20)
				elapsed += step
				steps += 1
				_expect(enemy.global_position.is_equal_approx(anchor) and enemy.velocity.is_zero_approx(), "recovery remains stationary under movement/crowd knockback at every tested frame rate")
				_expect(player.player_health == hp - (92.5 if dash_hit else 74), "recovering enemy cannot deal damage even when contact cooldown is forced ready")
			_expect(elapsed >= 0.9 - 1e-05 and elapsed <= 0.9 + step + 1e-05, "recovery duration is frame-rate independent and bounded")

			player.global_position = anchor + Vector2(100, 0)
			enemy._physics_process(0.02)
			_expect(enemy.global_position.x > anchor.x and not enemy.is_dashing and enemy.dash_windup == 0, "chasing resumes after the opening without skipping the charge cooldown")
			enemy.free()
	var missed: Node = _spawn()
	player.dashing = true
	var hp: float = player.player_health
	missed.is_dashing = true
	missed._try_contact(20)
	_expect(player.player_health == hp and missed.contact_recovery_left == 0.9 and not missed.is_dashing, "a player dash avoids damage but still earns the attacker's recovery opening")
	player.dashing = false
	missed.free()
	var guarded: Node = _spawn()
	player.shield = 100
	player.hurt_lock = 0
	guarded._try_contact(20)
	_expect(player.player_health == hp and guarded.contact_recovery_left > 0, "a shielded contact also stops the attacker")
	player.shield = 0
	guarded.free()
	var escape: Node = _spawn()
	player.hurt_lock = 0
	player.global_position = Vector2(20, 0)
	escape._try_contact(20)
	var start: Vector2 = escape.global_position
	for _frame in 50:
		player.global_position += Vector2.RIGHT * 100 / 60.0
		escape._physics_process(1.0 / 60.0)
	_expect(escape.global_position == start and player.global_position.distance_to(escape.global_position) > 100, "normal walking creates a meaningful escape gap during the stationary window")
	escape.burn_stacks = 1
	escape.burn_dps = 100
	escape._physics_process(0.5)
	_expect(escape.is_queued_for_deletion(), "status damage still ticks and can kill a recovering enemy")
	var normal: Node = _spawn()
	normal.set_enemy_data(load("res://resource/Enemy_1.tres"))
	normal.contact_timer = 0
	player.hurt_lock = 0
	normal._try_contact(20)
	_expect(normal.contact_recovery_left == 0, "ordinary chasers do not inherit the dasher-only recovery")
	if failures.is_empty(): print("DASHER RECOVERY OK: normal/charge contacts, 0.9-second stationary opening at 30/60 FPS and slow frames, no duplicate hits/knockback bypass, chase resumption, dash/shield, walking escape, status death and archetype isolation")
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
