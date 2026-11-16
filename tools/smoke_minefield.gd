extends SceneTree
var checks := 0
var failures: Array[String] = []
var g: Node
var field: Node
func _init() -> void: call_deferred("run")
func expect(ok: bool, text: String) -> void:
	checks += 1
	if not ok: failures.append(text)
func enemy(at: Vector2, health: float = 1000) -> Node:
	var actor = load("res://scenes/enemy_shell.tscn").instantiate()
	actor.set_enemy_data(load("res://resource/Enemy_1.tres"))
	actor.set_player_ref(g.player)
	actor.add_to_group("EnemyGroup")
	g.add_child(actor)
	actor.health = health
	actor.defense = 0.8
	actor.global_position = at-field.FOOT
	actor.set_physics_process(false)
	return actor
func run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await main._launch_run(&"minefield")
	g = main.game
	g.spawner.timer.stop()
	g.spawner.get_node("Elite").stop()
	g.spawner.set_process(false)
	g.player.set_physics_process(false)
	g.weather.set_process(false)
	g.variety.set_process(false)
	g.meteors.set_process(false)
	for path in ["HandWeapon","CircleWeapon","Weapon","DroneController","MolotovController","FreezeController"]: g.get_node(path).process_mode = Node.PROCESS_MODE_DISABLED
	field = g.weather.minefield
	field.set_physics_process(false)
	field._physics_process(0.01)
	expect(field._running and field.mines.size()==9,"real Debug launches nine mines")
	expect(field.get_child_count()==1,"nine mines share one draw node and one audio player")
	for i in 9:
		var at: Vector2 = field.mines[i].at
		expect(at.distance_to(g.player.global_position+field.FOOT)>36,"opening does not put mines under player")
		if i%3<2: expect(at.distance_to(field.mines[i+1].at)==96,"uniform horizontal spacing")
		if i<6: expect(at.distance_to(field.mines[i+3].at)==96,"uniform vertical spacing")
	var fixed: Array = field.mines.map(func(m): return m.at)
	g.player.global_position += Vector2(20,0)
	field._physics_process(0.01)
	expect(field.mines.map(func(m): return m.at)==fixed,"small movement does not drag terrain")
	var at: Vector2 = field.mines[4].at
	var actor := enemy(at+Vector2(8,0))
	var dead := enemy(at+Vector2(0,9),10)
	var far := enemy(at+Vector2(48,48))
	var p: Node = g.player
	p.global_position = at-field.FOOT-Vector2(8,0)
	p.damage_reduction = 0
	p.beast_damage_scale = 1
	p.shield = 0
	p.hurt_lock = 0
	field._player_at = p.global_position+field.FOOT
	var hp: float = p.player_health
	field._clock = 0.5
	field._physics_process(0.01)
	expect(field.mines[4].fuse<0 and actor.health==1000,"initial warning is harmless")
	field._clock = 1.1
	field._scan_left = 0
	field._physics_process(0.01)
	var trigger: float = field._clock
	expect(field.mines[4].fuse>trigger and is_equal_approx(field.mines[4].ready,trigger+3),"contact arms fuse and exact three-second refresh")
	field._physics_process(0.08)
	expect(actor.health==1000 and p.player_health==hp,"brief fuse displays warning before damage")
	var queries: int = root.get_node("CombatTargets").queries
	field._physics_process(0.09)
	expect(root.get_node("CombatTargets").queries==queries+1,"one fresh target snapshot for explosion batch")
	expect(actor.health==928 and far.health==1000,"environmental damage bypasses player bonuses/defense, radius respected")
	expect(p.player_health==hp-24,"player takes first-stage mine damage")
	expect(actor.terrain_impulse.left>0 and p.terrain_impulse.left>0,"surviving actors receive displacement")
	expect(dead._death_started and dead.terrain_impulse.left==0,"dead enemy is not launched")
	var before: Vector2 = p.global_position
	p._physics_process(0.1)
	expect(p.global_position.x<before.x,"player physically moves away from mine")
	p._start_dash(Vector2.RIGHT)
	expect(not p.dashing,"cannot overwrite knockback with dash during short impulse")
	before = actor.global_position
	actor._physics_process(0.1)
	expect(actor.global_position.x>before.x,"monster physically moves away from mine")
	p.global_position = at+Vector2(0,250)
	actor.global_position = at+Vector2(0,250)
	field._player_at = p.global_position+field.FOOT
	field._clock = trigger+2.99
	field._trigger(4)
	expect(field.mines[4].fuse<0,"no refresh before three seconds")
	field._clock = trigger+3
	field._trigger(4)
	expect(field.mines[4].fuse>field._clock,"mine can trigger again exactly at three seconds")
	var selected: Array[int] = [4]
	# Swept trigger avoids tunneling; touching alone never damages an invulnerable player.
	expect(field._touch(at-Vector2(50,0),at+Vector2(50,0),at),"fast path crossing trigger is detected")
	expect(not field._touch(at-Vector2(500,0),at+Vector2(50,0),at),"teleport only checks arrival")
	p.reset_dash()
	p.global_position = at-field.FOOT
	p.hurt_lock = 0
	p._start_dash(Vector2.RIGHT)
	hp = p.player_health
	field._snapshot()
	field._blast_batch(selected)
	expect(p.player_health==hp and p.terrain_impulse.left==0,"dash blocks damage and knockback")
	p.reset_dash()
	p.arsenal_shield_active = true
	field._blast_batch(selected)
	expect(p.player_health==hp and p.terrain_impulse.left==0,"arsenal protection blocks damage and knockback")
	p.arsenal_shield_active = false
	p.set_movement_locked(true)
	p.apply_terrain_impulse(Vector2.RIGHT*260)
	p._physics_process(0.1)
	expect(p.terrain_impulse.left==0 and p.movement_locked,"trial lock has priority and remains owned by trial")
	p.set_movement_locked(false)
	p.global_position = at+Vector2(0,250)
	# Physical displacement does not wait until electric paralysis expires.
	actor.global_position = at+Vector2(200,0)
	actor.apply_electric_stun(1)
	actor.apply_terrain_impulse(Vector2.RIGHT*360)
	before = actor.global_position
	actor._physics_process(0.1)
	expect(actor.global_position.x>before.x and is_equal_approx(actor.electric_stun_left,0.9),"electric stun still ticks while external blast displaces actor")
	for path in ["boss","knight_boss","beast_boss"]:
		var boss = load("res://scenes/"+path+".tscn").instantiate()
		boss.set_player(p)
		g.add_child(boss)
		boss.set_physics_process(false)
		boss.global_position = at+Vector2(-350,-250)
		if path=="boss": boss.start_charge_attack()
		elif path=="knight_boss": boss._begin_slash()
		else: boss.state = boss.State.ACTIVE
		boss.apply_terrain_impulse(Vector2.RIGHT*360)
		before = boss.global_position
		boss._physics_process(0.1)
		expect(boss.global_position.x>before.x,path+" has resisted physical displacement")
		if path=="boss": expect(boss.charge_state==boss.ChargeState.RECOVER and not boss.line.visible,"charge canceled before displacement")
		elif path=="knight_boss": expect(boss.attack_state==boss.AttackState.RECOVER,"sword attack canceled before displacement")
		else: expect(boss.state==boss.State.RECOVER and boss.shapes.is_empty(),"beast stale geometry canceled")
		boss.queue_free()
	# Verify actual collision-motion integration at different frame steps.
	for step in [1.0/30,1.0/60,0.1]:
		var probe := CharacterBody2D.new()
		probe.collision_layer = 0
		probe.collision_mask = 0
		g.add_child(probe)
		probe.position = Vector2(2000,2000)
		var impulse = load("res://script/terrain_impulse.gd").new()
		impulse.start(Vector2.RIGHT*260)
		while impulse.left>0: impulse.tick(probe,step)
		expect(absf(probe.position.x-2036.4)<0.02,"same analytical throw distance at step "+str(step))
		probe.queue_free()
	var crowd: Array[Node] = []
	for i in 180: crowd.append(enemy(at+Vector2((i%15)-7,(i/15)-6)))
	var original: Vector2 = field.mines[0].at
	field.mines[0].at = at
	var pair: Array[int] = [0,4]
	queries = root.get_node("CombatTargets").queries
	field._snapshot()
	field._blast_batch(pair)
	expect(root.get_node("CombatTargets").queries==queries+1,"dense multi-mine blast uses one registry snapshot")
	for member in crowd:
		expect(member.health==928,"same-batch overlapping mines do not multiply crowd damage")
		member.queue_free()
	expect(field.mines.size()==9 and field.get_child_count()==1,"crowd explosions do not allocate effect nodes")
	field.mines[0].at = original
	await process_frame
	var time: float = field._clock
	paused = true
	field._physics_process(1)
	expect(field._clock==time,"pause freezes fuse and respawn")
	paused = false
	var settings: Node = root.get_node("SettingsStore")
	var fx: float = settings.weather_intensity
	settings.weather_intensity = 0
	field._physics_process(0.01)
	expect(field.visible,"FX zero cannot hide dangerous mines")
	settings.weather_intensity = fx
	for kind in [0,2,3,4,5]:
		g.weather.set_preview(kind,0)
		field._physics_process(0.01)
		expect(field._running and field.mines.size()==9,"minefield remains available in each weather")
	var camera: Camera2D = p.get_node("Camera2D")
	p.global_position = Vector2(3000,3000)
	camera.global_position = p.global_position
	camera.force_update_scroll()
	field._physics_process(0.01)
	expect(field.mines.size()==9 and field._bounds.get_center().distance_to(p.global_position)<150,"exploring replaces entire remote grid near screen center")
	for mine in field.mines: expect(mine.ready>field._clock and mine.fuse<0,"replacement has fresh arming period")
	g.end_game()
	expect(not field.visible and not field._running and field._pushed.is_empty(),"end game cleans effects and owned forces")
	main.queue_free()
	await process_frame
	if failures.is_empty(): print("MINEFIELD OK: ",checks," checks")
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
