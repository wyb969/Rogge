extends SceneTree
const BLOOD := preload("res://script/death_stains.gd")
var failures: Array[String] = []
var checks := 0
func _init() -> void: call_deferred("_run")
func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
func _enemy(game: Node, at: Vector2) -> Node:
	var actor: Node = load("res://scenes/enemy_shell.tscn").instantiate()
	actor.set_enemy_data(load("res://resource/Enemy2.tres"))
	actor.set_player_ref(game.player)
	actor.health=1
	actor.add_to_group("EnemyGroup")
	actor.death_signal.connect(game.spawner.on_enemy_killed.bind(actor))
	game.add_child(actor)
	actor.global_position=at
	actor.set_physics_process(false)
	return actor
func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene=main
	await process_frame
	await process_frame
	await main._launch_run(&"")
	var game: Node = main.game
	game.level_manager.signal_level_up.disconnect(game.on_level_up)
	game.spawner.timer.stop()
	game.spawner.get_node("Elite").stop()
	game.spawner.set_process(false)
	game.weather.stop()
	game.meteors.set_process(false)
	game.variety._courier_left=99999
	for path in ["HandWeapon","CircleWeapon","Weapon","DroneController","MolotovController","FreezeController"]:
		game.get_node(path).process_mode=Node.PROCESS_MODE_DISABLED
	var stains: Node = game.combat_feedback.death_stains
	_expect(stains.stamps.size()==128 and stains.multimesh.instance_count==128 and not stains.is_processing(), "fixed128-slot instanced renderer sleeps when empty")
	_expect(stains.z_index==-3 and not stains.z_as_relative and stains.process_mode==Node.PROCESS_MODE_PAUSABLE, "stains lie below actors/pickups and freeze on pause")
	var samples_before: int = BLOOD.textures_sampled
	for _i in 100: BLOOD.texture_color(load("res://resource/Enemy2.tres").sprite)
	_expect(BLOOD.textures_sampled==samples_before and BLOOD._texture_colors.size()<=BLOOD.TEXTURE_CACHE_LIMIT, "prewarmed monster pigments never resample textures on death")
	var drops_before: int = game.pickup_container.get_child_count()
	var kills: int = game.spawner.enemy_killed_num
	var actor: Node = _enemy(game,Vector2(77,43))
	var expected: Color = BLOOD.color_for(actor._blood_body_tint*actor.base_modulate)
	actor.apply_hit({"damage":1000,"direction":Vector2.RIGHT})
	_expect(stains.emitted==1 and stains.stamps[0].tint.is_equal_approx(Color(expected,stains.stamps[0].tint.a)), "actual lethal hit leaves the monster's body pigment, not its white hit flash")
	actor.apply_hit({"damage":1000})
	_expect(stains.emitted==1 and game.spawner.enemy_killed_num==kills+1, "repeated hits on a dead target cannot duplicate the stain or reward")
	await process_frame
	await process_frame
	_expect(game.spawner.enemy_killed_num==kills+1 and game.pickup_container.get_child_count()==drops_before+1, "blood does not alter kill/XP rewards (kills=%s, drops=%s)" % [game.spawner.enemy_killed_num,game.pickup_container.get_child_count()])
	for effect in [&"burn",&"poison_trail",&"freeze",&"lightning",&"bomb",&"black_hole"]:
		stains.reset()
		actor=_enemy(game,Vector2(20,10))
		actor.apply_hit({"damage":1000,"effect":effect,"from_status":true})
		var color: Color = stains.stamps[0].tint
		_expect(stains.emitted==1 and color.is_equal_approx(Color(BLOOD.color_for(Color.WHITE,effect),color.a)), "fatal %s damage selects its own pigment" % effect)
	stains.reset()
	actor=_enemy(game,Vector2.ZERO)
	actor.freeze_time=1
	actor.apply_hit({"damage":1000})
	_expect(stains.stamps[0].tint.b==BLOOD.FROST.b, "ordinary hit on a frozen body leaves a cold stain")
	stains.reset()
	actor=_enemy(game,Vector2.ZERO)
	actor.set_poison_exposure(true,1,Color(1.2,0.5,1.2))
	actor.apply_hit({"damage":1000})
	_expect(stains.stamps[0].tint.r==BLOOD.POISON.r, "poison exposure supplies a pigment for an ordinary lethal hit")
	stains.reset()
	actor=_enemy(game,Vector2.ZERO)
	actor.burn_stacks=1
	actor._take_status_damage(1000)
	_expect(stains.stamps[0].tint.r==BLOOD.BURN.r, "real burn tick uses the burn death path")
	stains.reset()
	var references: Array[int] = []
	for stamp in stains.stamps: references.append(stamp.get_instance_id())
	var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	seed(969)
	var next_random:=randi()
	seed(969)
	for _i in 1000: stains.splat(Vector2(50,25),Color(0.7,0.2,0.4))
	_expect(randi()==next_random, "cosmetic randomness never consumes gameplay RNG")
	_expect(stains.emitted==20 and stains.suppressed==980 and stains.active_count==20, "mass same-frame deaths have a strict admission budget")
	_expect(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))==nodes, "one thousand deaths allocate no new effect nodes")
	var variants: Dictionary={}
	var sizes: Dictionary={}
	for i in 20:
		var value: float = float(stains.stamps[i].variant)/float(stains.VARIANTS-1)
		variants[snappedf(value,0.001)]=true
		sizes[stains.stamps[i].size]=true
		_expect(value>=0 and value<=1, "atlas variation uses normalized portable instance data")
	_expect(variants.size()>3 and sizes.size()>3, "splashes vary atlas pattern, rotation and stretch")
	stains.set_process(false)
	for _frame in 8:
		await process_frame
		stains.set_process(false)
		for _i in 20: stains.splat(Vector2(13,17),Color(0.2,0.5,0.7))
		stains.set_process(false)
	for i in 128: _expect(stains.stamps[i].get_instance_id()==references[i], "dense scenes reuse every slot")
	_expect(stains.active_count==128 and stains.stamps.size()==128 and stains.multimesh.instance_count==128, "pool reuse remains bounded after wraparound")
	stains.reset()
	stains.splat(Vector2(100,80),Color(0.7,0.2,0.4))
	stains.set_process(false)
	var position: Vector2 = stains.stamps[0].at
	var camera: Camera2D = game.player.get_node("Camera2D")
	camera.global_position+=Vector2(180,-100)
	camera.force_update_scroll()
	_expect(stains.stamps[0].at==position and stains.to_global(position)==Vector2(100,80), "camera motion cannot drag world-bound blood")
	var alpha: float = stains.opacity_at(stains.stamps[0].age)
	stains._process(1.9)
	_expect(stains.opacity_at(stains.stamps[0].age)==alpha and stains.active_count==1, "stain stays opaque for the two-second hold")
	paused=true
	stains._process(10)
	_expect(is_equal_approx(stains.stamps[0].age,1.9), "pause freezes stain age")
	paused=false
	Engine.time_scale=0.1
	stains._process(0.02)
	Engine.time_scale=1
	_expect(stains.opacity_at(stains.stamps[0].age)<alpha and stains.opacity_at(stains.stamps[0].age)>0, "blood fades after2s even during hitstop")
	stains._process(0.5)
	_expect(stains.active_count==0 and stains.multimesh.visible_instance_count==0 and not stains.is_processing(), "stain vanishes by2.5s and renderer sleeps")
	stains.splat(Vector2.ZERO,Color.RED)
	game.variety.clear_combat_effects()
	_expect(stains.active_count==0 and stains.emitted==0, "stage/transient cleanup clears every stain")
	await main._launch_run(&"boss1")
	game=main.game
	stains=game.combat_feedback.death_stains
	var boss: Node = get_nodes_in_group("EnemyGroup")[0]
	boss.boss_current_health=1
	boss.apply_hit({"damage":1000,"effect":"poison_trail","from_status":true})
	_expect(stains.emitted==1 and stains.stamps[0].tint.r==BLOOD.POISON.r, "actual Boss damage/death uses the same fatal-effect colors")
	Engine.time_scale=1
	main.fullscreen_toggle.home_button.pressed.emit()
	await process_frame
	await process_frame
	_expect(main.game.combat_feedback.death_stains.active_count==0 and not main.game.combat_feedback.is_processing(), "return Home leaves no old stain or running cosmetic timer")
	if failures.is_empty(): print("DEATH STAINS OK: %d checks; lethal paths/pigments/rewards, fixed instanced pool, burst bounds, RNG, random variation, world anchoring, pause/hitstop/hold/fade, Boss and lifecycle" % checks)
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
