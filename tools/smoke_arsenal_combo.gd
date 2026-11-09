extends SceneTree

var failures: Array[String] = []
var checks := 0
var main: Node
var game: Node

func _init() -> void: call_deferred("_run")
func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _isolate() -> void:
	game.spawner.timer.stop()
	game.spawner.get_node("Elite").stop()
	game.spawner.set_process(false)
	game.player.set_physics_process(false)
	game.player.global_position = Vector2.ZERO
	game.weather.stop()
	game.variety._courier_left = 99999
	game.bomb_controller.set_physics_process(false)
	game.arsenal_combo.set_physics_process(false)
	for node_name in ["HandWeapon", "CircleWeapon", "Weapon", "DroneController", "MolotovController", "FreezeController"]:
		game.get_node(node_name).process_mode = Node.PROCESS_MODE_DISABLED

func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	await main._launch_run(&"")
	game = main.game
	_isolate()
	var combo: Node = game.arsenal_combo
	var player: Node = game.player
	combo._physics_process(100)
	_expect(not combo.unlocked and not player.arsenal_shield_active and combo.pulses == 0, "normal starting equipment cannot grant a phantom combo")
	game._on_upgrade_selected("gun_up")
	game._on_upgrade_selected("bomb")
	_isolate()
	combo._physics_process(10)
	_expect(combo.owned_count == 2 and not combo.unlocked and game.equipment_panel._arsenal_label.text.contains("2/3"), "two actual cards show progress without granting invulnerability")
	game._on_upgrade_selected("drone_up")
	_isolate()
	_expect(combo.unlocked and combo.owned_count == 3 and not player.arsenal_shield_active, "the third equipped card starts a fresh three-second cycle")
	combo._physics_process(2.99)
	_expect(not player.arsenal_shield_active, "no shield before the first three-second interval")
	combo._physics_process(0.01)
	_expect(player.arsenal_shield_active and is_equal_approx(combo.shield_left, 1.0) and combo.pulses == 1, "three seconds grants exactly one second of invulnerability")
	player.shield_level = 1
	player.shield = 40.0
	player.damage_reduction = 0
	player.beast_damage_scale = 1
	player.hurt_lock = 0
	var hp: float = player.player_health
	for _i in 8: player.receive_attack(1000)
	_expect(player.player_health == hp and player.shield == 40 and player.hurt_lock == 0, "repeated attacks during the window consume neither health, jade shield nor hurt lock")
	_expect(not player.dashing and not player.is_dash_invulnerable(), "combo immunity does not pretend to be a dash or pass a dash-only trial")
	combo._physics_process(0.4)
	var left: float = combo.shield_left
	paused = true
	combo._physics_process(20)
	_expect(combo.shield_left == left and player.arsenal_shield_active, "card-selection pause freezes the shield and cycle")
	paused = false
	combo._physics_process(0.6)
	_expect(not player.arsenal_shield_active and combo.shield_left == 0, "the shield ends after one active second")
	player.receive_attack(80)
	_expect(player.player_health == hp - 40 and player.shield == 0, "damage resumes immediately after expiry and normal jade absorption remains")
	player.hurt_lock = 0
	combo._physics_process(1.99)
	_expect(not player.arsenal_shield_active, "the vulnerable gap continues until the next three-second boundary")
	combo._physics_process(0.01)
	_expect(player.arsenal_shield_active and combo.pulses == 2, "subsequent shields start at six seconds, not four seconds")
	combo._physics_process(0.1)
	var phase: float = combo._elapsed
	game._on_upgrade_selected("bomb")
	_isolate()
	_expect(is_equal_approx(combo._elapsed, phase) and combo.shield_left < 1, "upgrading a member cannot reset or refresh an active shield")
	player.dash_grace_left = 0.35
	combo.clear_combat_effects()
	_expect(not player.arsenal_shield_active and is_equal_approx(player.dash_grace_left, 0.35), "clearing combo effects preserves dash grace")
	combo._physics_process(3)
	combo._physics_process(1)
	player.hurt_lock = 0
	var protected_health: float = player.player_health
	player.receive_attack(50)
	_expect(player.player_health == protected_health, "dash grace independently protects after combo expires")
	player.dash_grace_left = 0
	combo.clear_combat_effects()
	combo._physics_process(4.2)
	_expect(not player.arsenal_shield_active and combo.shield_left == 0 and is_equal_approx(combo._elapsed, 1.2), "a long frame consumes past shield time rather than adding stale immunity")
	combo._physics_process(1.8)
	_expect(player.arsenal_shield_active, "a long frame leaves the next pulse correctly scheduled")
	game.spawner._rest_open = true
	combo._physics_process(0.1)
	_expect(not player.arsenal_shield_active and combo._elapsed == 0 and combo.unlocked, "rest suspends invulnerability and keeps the owned set")
	game.spawner._rest_open = false
	combo._physics_process(2.9)
	_expect(not player.arsenal_shield_active, "returning from rest starts a full fresh charging interval")
	game.variety.clear_combat_effects()
	_expect(combo.unlocked and game.bomb_controller.level == 2 and not player.arsenal_shield_active and combo._elapsed == 0, "stage cleanup preserves cards and combo eligibility but clears active immunity")
	game.equipment_panel.reset_equipment()
	combo.refresh_equipment()
	_expect(not combo.unlocked and combo.owned_count == 0 and not player.arsenal_shield_active, "loss of the equipped set removes eligibility immediately")
	main.show_main_menu()
	await main._launch_run(&"arsenal")
	game = main.game
	_isolate()
	combo = game.arsenal_combo
	_expect(combo.unlocked and game.bomb_controller.level == 5 and game.equipment_panel.get_level("gun_up") == 1 and game.equipment_panel.get_level("drone_up") == 1, "combo Debug grants exactly the three intended equipment types")
	combo._physics_process(3)
	game.player.player_health = 0
	combo._physics_process(0)
	_expect(not game.player.arsenal_shield_active and combo.shield_left == 0, "death clears immunity without reviving the player")
	await main._on_game_end_ui_retry_pressed()
	game = main.game
	_expect(game.arsenal_combo.unlocked and game.arsenal_combo.pulses == 0, "Debug retry clears old windows and restores the chosen set")
	await main._launch_run(&"")
	game = main.game
	_expect(not game.arsenal_combo.unlocked and not game.player.arsenal_shield_active and game.bomb_controller.level == 0, "new normal runs inherit no Debug ownership or shield time")
	main.show_main_menu()
	if failures.is_empty(): print("ARSENAL COMBO OK: %d checks; real three-card ownership, exact 3s/1s cadence, damage/shield isolation, dash coexistence, pause/lag/rest/death/reset and Debug retry" % checks)
	else:
		for message in failures: push_error(message)
	quit(0 if failures.is_empty() else 1)
