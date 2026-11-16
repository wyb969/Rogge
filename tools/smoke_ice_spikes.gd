extends SceneTree
var failures: Array[String] = []
var checks := 0
var g: Node
var spikes: Node
func _init() -> void: call_deferred("_run")
func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
func enemy(at: Vector2, hp: float = 1000) -> Node:
	var e = load("res://scenes/enemy_shell.tscn").instantiate()
	e.set_enemy_data(load("res://resource/Enemy_1.tres"))
	e.set_player_ref(g.player)
	e.add_to_group("EnemyGroup")
	g.add_child(e)
	e.health = hp
	e.defense = 0.6
	e.global_position = at-spikes.FOOT_OFFSET
	e.set_physics_process(false)
	return e
func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await main._launch_run(&"ice_scene")
	g = main.game
	g.spawner.timer.stop()
	g.spawner.get_node("Elite").stop()
	g.spawner.set_process(false)
	g.player.set_physics_process(false)
	g.weather.set_process(false)
	g.variety.set_process(false)
	g.meteors.set_process(false)
	g.banana_fan.set_physics_process(false)
	g.black_hole.set_physics_process(false)
	for path in ["HandWeapon","CircleWeapon","Weapon","DroneController","MolotovController","FreezeController"]: g.get_node(path).process_mode = Node.PROCESS_MODE_DISABLED
	spikes = g.weather.spikes
	spikes.set_physics_process(false)
	spikes.stop()
	spikes._seed = 969
	spikes._physics_process(0.016)
	expect(spikes._running and spikes.visible and spikes._cells.size()>0,"real ice Debug activates terrain")
	expect(spikes.get_child_count()==0 and spikes._points.size()==128 and spikes._teeth.size()==12,"fixed pools and reused mesh shapes; no per-spike nodes")
	var count := 0
	for y in range(-50,50):
		for x in range(-50,50):
			if spikes.occupied(Vector2i(x,y)): count += 1
	expect(count>900 and count<1100,"10 percent occupancy across 10000 signed world cells: %d" % count)
	var first: Vector2i = spikes._cells.keys()[0]
	var at: Vector2 = spikes.point_for(first)
	expect(not spikes.occupied(Vector2i((g.player.global_position/96).floor())),"safe opening disk excludes spawn cell")
	var camera: Camera2D = g.player.get_node("Camera2D")
	var old_camera: Vector2 = camera.global_position
	var old_player: Vector2 = g.player.global_position
	for i in 12:
		g.player.global_position = old_player+Vector2(1000*(i+1),-1000)
		camera.global_position = g.player.global_position
		camera.force_update_scroll()
		spikes._refresh()
		expect(spikes._cells.size()<=128,"exploration retains bounded visible terrain")
	g.player.global_position = old_player
	camera.global_position = old_camera
	camera.force_update_scroll()
	spikes._refresh()
	expect(spikes._cells.has(first) and spikes.point_for(first)==at,"returning restores exactly the same world obstacle")
	var settings: Node = root.get_node("SettingsStore")
	var old_intensity: float = settings.weather_intensity
	settings.weather_intensity = 0
	spikes._physics_process(0.016)
	expect(spikes.visible,"zero cosmetic FX cannot hide harmful terrain")
	settings.weather_intensity = old_intensity
	var p: Node = g.player
	p.global_position = at-spikes.FOOT_OFFSET
	p.damage_reduction = 0
	p.shield = 0
	p.beast_damage_scale = 1
	p.hurt_lock = 0
	var hp: float = p.player_health
	spikes._touch_player()
	expect(p.player_health==hp,"newly revealed ice surface has an arming warning")
	spikes._clock = 2
	spikes._touch_player()
	expect(p.player_health==hp-12,"first-stage player contact takes 12")
	p.hurt_lock = 0
	spikes._touch_player()
	expect(p.player_health==hp-12,"terrain cooldown works even without generic hurt lock")
	spikes._clock += 1.01
	spikes._touch_player()
	expect(p.player_health==hp-24,"remaining on terrain hurts once per second")
	p.hurt_lock = 0
	spikes._clock += 1.01
	p.dashing = true
	spikes._touch_player()
	expect(p.player_health==hp-24,"dash is immune to terrain")
	p.dashing = false
	p.dash_grace_left = 0.5
	spikes._touch_player()
	expect(p.player_health==hp-24,"post-dash grace is immune too")
	p.dash_grace_left = 0
	p.arsenal_shield_active = true
	spikes._touch_player()
	expect(p.player_health==hp-24,"arsenal invulnerability remains effective")
	p.arsenal_shield_active = false
	p.shield = 20
	spikes._touch_player()
	expect(p.player_health==hp-24 and p.shield==8,"ordinary shield absorbs terrain damage")
	p.shield = 0
	p.hurt_lock = 0
	spikes._clock += 1.01
	spikes._player_at = at-Vector2(65,0)
	p.global_position = at+Vector2(65,0)-spikes.FOOT_OFFSET
	spikes._touch_player()
	expect(p.player_health==hp-36,"sweep catches crossing with both endpoints outside")
	p.global_position = old_player
	var e := enemy(at)
	for i in 5: g._on_upgrade_selected("critical_glasses")
	var queries: int = root.get_node("CombatTargets").queries
	spikes._scan_enemies()
	expect(root.get_node("CombatTargets").queries==queries+1,"single batched registry query for all patches")
	expect(e.health==964,"enemy takes three times player damage; player crit/side bonuses and enemy armor do not alter final terrain damage")
	spikes._scan_enemies()
	expect(e.health==964,"many overlapping contacts cannot multiply a tick")
	spikes._clock += 1.01
	spikes._scan_enemies()
	expect(e.health==928,"standing enemy receives next terrain tick")
	e.global_position = at-Vector2(65,0)-spikes.FOOT_OFFSET
	spikes._scan_enemies()
	spikes._clock += 1.01
	var previous: float = e.health
	e.global_position = at+Vector2(65,0)-spikes.FOOT_OFFSET
	spikes._scan_enemies()
	expect(e.health==previous-36,"fast enemy/control displacement sweeps across spikes")
	var dying := enemy(at,10)
	spikes._scan_enemies()
	expect(dying._death_started and not dying.is_in_group("EnemyGroup"),"terrain kills use normal death/removal path")
	await process_frame
	spikes._scan_enemies()
	expect(spikes._contacts.size()<=1,"dead target history is pruned")
	g.spawner._rest_open = true
	spikes._physics_process(1)
	expect(not spikes._running and spikes._contacts.is_empty(),"rest clears terrain contact state")
	g.spawner._rest_open = false
	g.weather.set_preview(0,0)
	spikes._physics_process(1)
	expect(not spikes.visible,"other weather removes harmful spikes")
	g.weather.set_preview(5,0)
	spikes._physics_process(0.016)
	expect(spikes.point_for(first)==at,"switching back preserves the stage layout")
	g.spawner._transitioning = true
	spikes._physics_process(1)
	expect(not spikes._running,"transition is safe")
	g.spawner._transitioning = false
	g.weather.stage = 6
	expect(spikes.player_damage()==22 and spikes.enemy_damage()==66,"later stages scale gently and keep 3:1 ratio")
	seed(241)
	var random_expected := randi()
	seed(241)
	spikes.reset_run()
	expect(randi()==random_expected and spikes._origins.is_empty() and spikes._contacts.is_empty(),"new-run reset is independent of combat RNG and clears caches")
	g.weather.stop()
	expect(not spikes.visible,"end-game/weather stop clears terrain")
	print("SPIKE DENSITY: %d / 10000 cells" % count)
	if failures.is_empty(): print("ICE SPIKES OK: %d checks; density/stable regeneration/safe spawn/pools, actual damage/cooldown/dash/shield, swept player and enemy contacts, death pruning, FX and lifecycle" % checks)
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
