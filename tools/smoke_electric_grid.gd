extends SceneTree
var failures: Array[String] = []
var checks := 0
var g: Node
var grid: Node
func _init() -> void: call_deferred("run")
func expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func enemy(at: Vector2, hp: float = 2000) -> Node:
	var e = load("res://scenes/enemy_shell.tscn").instantiate()
	e.set_enemy_data(load("res://resource/Enemy_1.tres"))
	e.set_player_ref(g.player)
	e.add_to_group("EnemyGroup")
	g.add_child(e)
	e.health = hp
	e.defense = 0.6
	e.global_position = at-grid.FOOT
	e.set_physics_process(false)
	return e
func run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await main._launch_run(&"electric_grid")
	g = main.game
	g.spawner.timer.stop()
	g.spawner.get_node("Elite").stop()
	g.spawner.set_process(false)
	g.player.set_physics_process(false)
	g.weather.set_process(false)
	g.variety.set_process(false)
	g.meteors.set_process(false)
	for path in ["HandWeapon","CircleWeapon","Weapon","DroneController","MolotovController","FreezeController"]: g.get_node(path).process_mode = Node.PROCESS_MODE_DISABLED
	grid = g.weather.electric_grid
	grid.set_physics_process(false)
	grid._physics_process(0.016)
	expect(grid._running and grid.strips.size()==2,"real sunny Debug activates two strips")
	for i in 100:
		grid._layout(Vector2(200,-100))
		for rect in grid.strips:
			expect(not rect.grow(60).has_point(Vector2(200,-100)),"random layout retains safe entry")
		expect(not grid.strips[0].intersects(grid.strips[1]),"random strips do not overlap")
	var fixed: Array = grid.strips.duplicate()
	g.player.global_position += Vector2(300,0)
	grid._physics_process(0.016)
	expect(grid.strips==fixed,"world layout cannot follow camera/player")
	grid.strips.assign([Rect2(-20,-100,40,200),Rect2(-20,-100,40,200)])
	var a := enemy(Vector2.ZERO)
	var b := enemy(Vector2(38,0))
	var c := enemy(Vector2(76,0))
	var d := enemy(Vector2(140,0))
	grid._clock = 0.4
	grid._scan_enemies()
	expect(a.health==2000 and b.health==2000,"warning does no damage")
	grid._clock = 0.8
	var queries: int = root.get_node("CombatTargets").queries
	grid._scan_enemies()
	expect(root.get_node("CombatTargets").queries==queries+1,"one registry query for whole batch")
	expect(grid.last_batch==3 and a.health==1946 and b.health==1946 and c.health==1946 and d.health==2000,"snapshot transitively reaches close neighbors only; ignores defense")
	expect(a.electric_stun_left==1 and b.electric_stun_left==1,"one-second stun includes conducted targets")
	grid._scan_enemies()
	expect(a.health==1946 and b.health==1946 and grid.last_batch==0,"overlapping strips and repeated scans never double-hit in cycle")
	grid._clock = 4.49
	grid._physics_process(0.32)
	expect(grid._hit_ids.is_empty(),"new cycle clears dedup")
	grid._clock = 5.3
	grid._scan_enemies()
	expect(a.health==1892 and c.health==1892,"next pulse can strike once again")
	var p: Node = g.player
	p.damage_reduction = 0
	p.beast_damage_scale = 1
	p.shield = 0
	p.global_position = -grid.FOOT
	p.hurt_lock = 0
	grid._player_at = p.global_position+grid.FOOT
	grid._clock = 1.9
	var hp: float = p.player_health
	grid._touch_player()
	expect(p.player_health==hp-18 and p.electric_stun_left==1,"player contact damage and paralysis")
	expect(is_equal_approx(grid._player_ready,5.4),"1 second stun plus 2.5 second electric grace")
	var pos: Vector2 = p.global_position
	Input.action_press("right")
	p._start_dash(Vector2.RIGHT)
	expect(not p.dashing,"cannot dash while paralyzed")
	for i in 60: p._physics_process(1.0/60)
	expect(p.global_position==pos,"movement input cannot move paralyzed player")
	p._physics_process(0.02)
	p._physics_process(0.02)
	expect(p.global_position.x>pos.x,"held input resumes movement after one second")
	for i in 45: p._physics_process(1.0/60)
	expect(not grid._crosses(p.global_position+grid.FOOT,p.global_position+grid.FOOT),"player can walk entirely out during escape window")
	Input.action_release("right")
	p.global_position = -grid.FOOT
	grid._player_at = Vector2.ZERO
	p.hurt_lock = 0
	grid._clock = 5.3
	grid._player_hit = false
	grid._touch_player()
	expect(p.player_health==hp-18,"escape grace is respected")
	grid._clock = 5.5
	p._start_dash(Vector2.RIGHT)
	grid._touch_player()
	expect(p.player_health==hp-18 and p.electric_stun_left<=0,"dash avoids stun and damage")
	p.reset_dash()
	p.hurt_lock = 0
	p.arsenal_shield_active = true
	grid._touch_player()
	expect(p.player_health==hp-18,"arsenal invulnerability respected")
	p.arsenal_shield_active = false
	grid._clock = 2.4
	grid._player_ready = 0
	grid._touch_player()
	expect(p.player_health==hp-18,"off phase harmless")
	# Real actors cancel offensive states and remain still until recovery.
	a.apply_electric_stun(1)
	var at: Vector2 = a.global_position
	a._physics_process(0.5)
	expect(a.global_position==at and is_equal_approx(a.electric_stun_left,0.5),"enemy physics frozen without moving collider")
	var tactical = load("res://scenes/enemy_shell.tscn").instantiate()
	tactical.set_enemy_data(load("res://resource/BladeMantis.tres"))
	tactical.set_player_ref(p)
	g.add_child(tactical)
	tactical.set_physics_process(false)
	tactical.global_position = p.global_position+Vector2(50,0)
	var slot = g.enemy_attacks.cast(tactical,&"cleave")
	tactical.tactical_ai.slot = slot
	tactical.tactical_ai.committed = true
	tactical.apply_electric_stun(1)
	expect(slot!=null and not slot.active and not tactical.tactical_ai.committed,"electric stun cancels pooled tactical attack at source")
	for step in [1.0/30,1.0/60,0.2]:
		a.electric_stun_left = 0
		a.apply_electric_stun(1)
		var seconds := 0.0
		while seconds<0.99:
			a._tick_electric_stun(step)
			seconds += step
		expect(a.electric_stun_left<0.00001,"enemy stun duration independent of physics step")
	tactical.queue_free()
	for path in ["boss","knight_boss","beast_boss"]:
		var boss = load("res://scenes/"+path+".tscn").instantiate()
		boss.set_player(p)
		g.add_child(boss)
		boss.set_physics_process(false)
		boss.global_position = Vector2(300,300)
		if path=="boss": boss.start_charge_attack()
		elif path=="knight_boss": boss._begin_slash()
		else: boss.state = boss.State.ACTIVE
		boss.apply_electric_stun(1)
		boss._physics_process(0.5)
		expect(boss.global_position==Vector2(300,300) and is_equal_approx(boss.electric_stun_left,0.5),path+" stops attacks/movement")
		if path=="boss": expect(boss.charge_state==boss.ChargeState.RECOVER and not boss.line.visible,"charge warning canceled")
		elif path=="knight_boss": expect(boss.attack_state==boss.AttackState.RECOVER,"sword attack canceled")
		else: expect(boss.state==boss.State.RECOVER and boss.shapes.is_empty(),"beast attack geometry canceled")
		boss._physics_process(0.5)
		boss._physics_process(0.05)
		expect(boss.electric_stun_left<=0,path+" recovers")
		boss.queue_free()
	# Dense ring: iterative flood fill terminates and each actual actor is hit once.
	for actor in [a,b,c,d]: actor.queue_free()
	await process_frame
	grid._hit_ids.clear()
	grid._previous.clear()
	grid._clock = 0.8
	var crowd: Array[Node] = []
	for i in 180: crowd.append(enemy(Vector2((i%18)*6,(i/18)*6)))
	var start := Time.get_ticks_usec()
	grid._scan_enemies()
	var micros := Time.get_ticks_usec()-start
	expect(grid.last_batch==180,"dense connected 180-actor crowd each selected once")
	grid._scan_enemies()
	for actor in crowd: expect(actor.health==1946,"dense cycle cannot recurse/double-damage")
	expect(grid._zaps.size()<=64 and grid._links.size()<=128 and grid.get_child_count()==1,"VFX node/geometry caps")
	print("electric grid 180 actors batch microseconds: ",micros)
	var settings: Node = root.get_node("SettingsStore")
	var fx: float = settings.weather_intensity
	settings.weather_intensity = 0
	grid._physics_process(0.016)
	expect(grid.visible,"FX zero never hides dangerous grid")
	settings.weather_intensity = fx
	var time: float = grid._clock
	paused = true
	grid._physics_process(1)
	expect(grid._clock==time,"pause freezes cycle")
	paused = false
	g.weather.set_preview(2,0)
	grid._physics_process(0.016)
	expect(not grid._running and grid._hit_ids.is_empty() and grid._zaps.is_empty(),"rain cancels grid and transient effects")
	for actor in crowd: expect(actor.electric_stun_left==0,"weather switch releases owned paralysis")
	g.weather.set_preview(0,0)
	grid._physics_process(0.016)
	expect(grid._running and not grid.energized(),"return to sun starts safe warning")
	g.end_game()
	expect(not grid._running and not grid.visible,"end game cleanup")
	main.queue_free()
	await process_frame
	if failures.is_empty(): print("smoke_electric_grid OK ",checks," assertions")
	else:
		for message in failures: push_error(message)
	quit(0 if failures.is_empty() else 1)
