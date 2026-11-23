extends SceneTree

var game: Node
var stats: Script
var errors := 0
var checks := 0

func _init() -> void:
	call_deferred("_run")

func expect(result: bool, message: String) -> void:
	checks += 1
	if not result:
		errors += 1
		push_error(message)

func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for frame in 4: await process_frame
	stats = load("res://script/forge_stats.gd")
	game = main.game
	game.hand_weapon.start_unequipped()
	game.circle_weapon.start_unequipped()
	for id: String in game.equipment_panel.EQUIP_DEFS:
		var previous := 0
		var inventory = game.forge
		for rank: int in [1,2,3,6,8,9,12,21]:
			stats.apply(game,id,previous,rank,inventory.power_for(previous),inventory.power_for(rank),1.0)
			expect(stats.describe(game,id,rank,inventory.power_for(rank),1.0) != "—", "%s lacks preview at level %d" % [id,rank])
			expect((game.player.awakened.has(id) or game.player.orange_weapons.has(id)) == (rank >= 9), "orange mechanic threshold for "+id)
			previous = rank
		stats.apply(game,id,previous,0,inventory.power_for(previous),0.0,0.0)
		expect(not game.player.awakened.has(id) and not game.player.orange_weapons.has(id), "sacrifice removes orange mechanic for "+id)
	var player: Node = game.player
	var base_cd: float = player.dash_base_cooldown()
	stats.apply(game,"speed_up",0,9,0.0,game.forge.power_for(9),1.0)
	expect(is_equal_approx(player.dash_base_cooldown(),base_cd*0.75), "awakened movement changes the live dash cooldown")
	stats.apply(game,"speed_up",9,0,game.forge.power_for(9),0,0)
	expect(is_equal_approx(player.dash_base_cooldown(),base_cd), "sacrifice restores the original dash cooldown")
	stats.apply(game,"critical_glasses",0,9,0,game.forge.power_for(9),1.0)
	var normal_crit: float = player.forged_passives.critical_glasses.crit
	for i in 5:
		expect(player.roll_critical_multiplier({"damage":10,"from_status":true}) == 1.0, "periodic damage does not advance the fifth critical hit")
		expect(is_equal_approx(player.roll_critical_multiplier({"damage":10}), normal_crit*(2 if i==4 else 1)), "every fifth direct critical hit doubles")
	stats.apply(game,"critical_glasses",9,0,game.forge.power_for(9),0,0)
	var speed: float = player.SPEED
	var radius: float = player.pickup_range
	stats.apply(game, "speed_up", 0, 1, 0.0, 0.8, 0.8)
	expect(is_equal_approx(player.SPEED, speed + 16.0), "one cyan speed card grants sixteen movement speed")
	player.speed_up(15.0)
	stats.apply(game, "speed_up", 1, 0, 0.8, 0.0, 0.0)
	expect(is_equal_approx(player.SPEED, speed + 15.0), "sacrificing speed preserves external movement upgrades")
	stats.apply(game, "pickup_up", 0, 1, 0.0, 4.0, 4.0)
	player.pick_up_upgrade(1.3)
	stats.apply(game, "pickup_up", 1, 0, 4.0, 0.0, 0.0)
	expect(is_equal_approx(player.pick_shape.shape.radius, radius * 1.3), "pickup sacrifice preserves other pickup multipliers")
	stats.apply(game, "shield_up", 0, 1, 0.0, 4.0, 4.0)
	player.notify_enemy_killed()
	expect(is_equal_approx(player.shield, 8.0), "orange shield actually adds eight points per kill")
	stats.apply(game, "shield_up", 1, 0, 4.0, 0.0, 0.0)
	expect(is_zero_approx(player.shield) and player.shield_level == 0, "sacrificing shield removes its remaining capacity")

	stats.apply(game, "axe_up", 0, 1, 0.0, 4.0, 4.0)
	expect(game.hand_weapon.visible and is_equal_approx(game.hand_weapon.weapon_demage, 56.0), "orange axe is visible and applies four times its base damage")
	stats.apply(game, "axe_up", 1, 2, 4.0, 4.8, 4.0)
	expect(game.hand_weapon.weapon_demage > 56.0, "adding a weak duplicate cannot reduce an orange weapon's damage")
	stats.apply(game, "axe_up", 2, 1, 4.8, 0.8, 0.8)
	expect(is_equal_approx(game.hand_weapon.weapon_demage, 11.2), "consuming the orange copy leaves the cyan copy")
	stats.apply(game, "axe_up", 1, 0, 0.8, 0.0, 0.0)
	expect(not game.hand_weapon.visible and game.hand_weapon.get_node("AttackTimer").is_stopped(), "last axe disables its hit loop")
	stats.apply(game, "gun_up", 0, 1, 0.0, 2.0, 2.0)
	game.gun_weapon.shoot()
	var bullet: Node = game.effect_container.get_child(-1)
	expect("bullet_damage" in bullet and bullet.bullet_damage >= 60 and bullet.bullet_damage <= 80, "actual pink projectile rolled in the displayed range")
	stats.apply(game, "gun_up", 1, 0, 2.0, 0.0, 0.0)
	expect(game.gun_weapon.auto_attack_timer.is_stopped(), "sacrificing the gun stops spawning bullets")
	stats.apply(game, "drone_up", 0, 1, 0.0, 4.0, 4.0)
	var drone: Node = game.drone_controller.active_drones[0]
	expect(is_equal_approx(drone.damage, 30.8), "spawned orange drone uses its ranked damage")
	stats.apply(game, "drone_up", 1, 1, 4.0, 2.0, 2.0)
	expect(is_equal_approx(drone.damage, 15.4), "quality downgrade updates the surviving drone immediately")
	stats.apply(game, "drone_up", 1, 0, 2.0, 0.0, 0.0)
	expect(drone.is_queued_for_deletion() and game.drone_controller.active_drones.is_empty(), "consumed drones disappear")
	if errors == 0: print("FORGE COMBAT OK: %d checks across all card IDs, projectile rolls and reversible bonuses" % checks)
	quit(0 if errors == 0 else 1)
