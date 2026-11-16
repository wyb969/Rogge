extends SceneTree
var failures: Array[String] = []
func _init() -> void:
	call_deferred("_run")
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func _run() -> void:
	var game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.process_mode = Node.PROCESS_MODE_DISABLED
	var axe = game.hand_weapon
	var gun = game.gun_weapon
	var spawner = game.spawner
	var chaser = load("res://resource/Enemy_1.tres")
	var tank = load("res://resource/Enemy_3.tres")
	check(ceil(chaser.health / axe.weapon_demage) == 3, "opening chaser needs three axe contacts")
	check(ceil(tank.health / (axe.weapon_demage * (1.0 - tank.defense))) <= 9, "opening tank is durable without twenty-plus contacts")
	var rows: Array = []
	for stage in range(1, 7):
		var character_level: int = [0, 4, 8, 12, 16, 20][stage-1]
		if stage > 1:
			game.current_level = character_level
			game._on_upgrade_selected("axe_up")
		game._on_upgrade_selected("gun_up")
		var pressure: float = spawner.threat_hp_multiplier_for(character_level, 60.0, character_level, stage)
		var gun_mean: float = gun.damage + 10.0
		var hits: float = ceil(chaser.health * pressure / gun_mean)
		check(hits >= 2 and hits <= 7, "balanced gun/chaser contact budget stage %d" % stage)
		var boss_hp: float = [2000, 3200, 3600, 4200, 4800, 5600][stage-1]
		# Analytic gun-only estimate, 60% target uptime; not a measured playthrough.
		var boss_seconds: float = boss_hp / (gun_mean / gun.fire_interval * 0.6)
		if stage >= 2: check(boss_seconds >= 20 and boss_seconds <= 90, "gun-only Boss estimate remains bounded stage %d" % stage)
		rows.append({"stage": stage, "level": character_level, "hp_multiplier":pressure, "chaser_hp":chaser.health*pressure, "axe_damage":axe.weapon_demage,"gun_damage_mean":gun_mean,"gun_interval":gun.fire_interval,"chaser_gun_hits":hits,"boss_gun_only_seconds_at_60pct_uptime":boss_seconds})
	var before: float = axe.weapon_demage
	for i in 30: axe.handle_level_up(100)
	check(axe.weapon_demage > before and axe.weapon_demage < before+800, "repeat high-level axe cards cannot exponentiate")
	check(spawner.threat_hp_multiplier_for(100,36000,100,6) < 25, "endless HP pressure has a finite ceiling")
	check(is_equal_approx(spawner.threat_hp_multiplier_for(20,600,20,6),spawner.threat_hp_multiplier_for(20,36000,20,6)), "waiting alone cannot make enemies infinitely durable")
	gun.apply_cooldown_scale(0.45)
	for i in 30: gun.upgrade()
	check(gun.fire_interval >= 0.12 and gun.damage < 400, "late gun retains growth without extreme fire/damage escalation")
	print("BALANCE_ROWS "+JSON.stringify(rows))
	if failures.is_empty(): print("COMBAT BALANCE OK: six stage budgets, real card dispatch, boss estimates and extreme progression bounds")
	for message in failures: push_error(message)
	quit(0 if failures.is_empty() else 1)
