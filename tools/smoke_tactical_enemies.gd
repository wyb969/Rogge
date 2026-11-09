extends SceneTree
var FIELD: Script
const PIGMENTS := preload("res://script/death_stains.gd")
var checks := 0
var failures: Array[String] = []
var main: Node
var game: Node
var field: Node
var player: Node
func _init() -> void: call_deferred("_run")
func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
func _enemy(resource_name: String, at: Vector2 = Vector2.ZERO) -> Node:
	var actor: Node=load("res://scenes/enemy_shell.tscn").instantiate()
	actor.set_enemy_data(load("res://resource/%s.tres" % resource_name))
	actor.set_player_ref(player)
	actor.add_to_group("EnemyGroup")
	actor.death_signal.connect(game.spawner.on_enemy_killed.bind(actor))
	game.add_child(actor)
	actor.global_position=at
	actor.set_physics_process(false)
	return actor
func _clean() -> void:
	field.clear_combat_effects()
	player.reset_dash()
	player.hurt_lock=0
	player.player_health=500
func _run() -> void:
	FIELD=load("res://script/enemy_attack_field.gd")
	main=load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene=main
	await process_frame
	await process_frame
	await main._launch_run(&"")
	game=main.game
	player=game.player
	field=game.enemy_attacks
	game.level_manager.signal_level_up.disconnect(game.on_level_up)
	game.spawner.timer.stop()
	game.spawner.get_node("Elite").stop()
	game.spawner.set_process(false)
	game.weather.stop()
	game.meteors.set_process(false)
	game.variety._courier_left=99999
	for path in ["HandWeapon","CircleWeapon","Weapon","DroneController","MolotovController","FreezeController"]: game.get_node(path).process_mode=Node.PROCESS_MODE_DISABLED
	player.set_physics_process(false)
	field.set_physics_process(false)
	_expect(game.spawner.enemy_array.size()==8 and field.slots.size()==12, "eight normal species use twelve fixed shared attack slots")
	var mantis: Node=_enemy("BladeMantis")
	var imp: Node=_enemy("BoomerangImp",Vector2(-160,0))
	var bomber: Node=_enemy("SporeBomber",Vector2(-160,0))
	for resource_name in ["BladeMantis","BoomerangImp","SporeBomber"]:
		var data: EnemyData=load("res://resource/%s.tres" % resource_name)
		_expect(game.spawner.enemy_array.has(data) and data.sprite!=null and data.sprite.get_width()==32, "%s is a real spawnable species with its own32px sprite" % resource_name)
		_expect(PIGMENTS.PALETTE.has(StringName(data.title)), "%s has its own fixed death pigment" % resource_name)
	_expect(mantis.archetype==EnemyData.Archetype.CHASER and imp.archetype==EnemyData.Archetype.RANGED and bomber.archetype==EnemyData.Archetype.RANGED, "new ranged species share the existing quota classification")
	_clean()
	player.global_position=Vector2(65,0)
	var slash=field.cast(mantis,&"cleave")
	_expect(slash!=null and slash.heading==Vector2.RIGHT, "real mantis cast locks its origin and heading")
	field._physics_process(0.74)
	_expect(player.player_health==500 and not slash.released, "no damage before the full0.75s slash warning")
	player.global_position=Vector2(-65,0)
	field._physics_process(0.03)
	_expect(player.player_health==500 and slash.heading==Vector2.RIGHT, "moving behind the fixed warning safely avoids slash")
	player.global_position=Vector2(65,0)
	field._physics_process(0.02)
	_expect(player.player_health==474 and slash.hit, "slash actually hurts inside its warning sector")
	player.hurt_lock=0
	field._physics_process(0.05)
	_expect(player.player_health==474, "a slash cannot apply repeated contact damage")
	_expect(not FIELD.hits_point(slash,Vector2(85,0),0.75,0.8) and not FIELD.hits_point(slash,Vector2(0,65),0.75,0.8), "actual sector boundaries exclude radius/angle misses")
	_clean()
	player.global_position=Vector2(65,0)
	slash=field.cast(mantis,&"cleave")
	player._start_dash(Vector2.RIGHT)
	field._physics_process(0.8)
	_expect(player.player_health==500 and slash.hit, "dash evades the attack and consumes its single contact")
	player.reset_dash()
	field._physics_process(0.05)
	_expect(player.player_health==500, "the same attack cannot hit again after dash invulnerability")
	for interruption in ["freeze","airflow","blast","move","death"]:
		_clean()
		var actor: Node=_enemy("BladeMantis")
		player.global_position=Vector2(65,0)
		var slot=field.cast(actor,&"cleave")
		match interruption:
			"freeze": actor.freeze_time=1
			"airflow": actor.apply_airflow(Vector2.LEFT*200,0.2)
			"blast": actor.apply_blast_impulse(Vector2.LEFT*200,0.2)
			"move": actor.global_position+=Vector2(30,0)
			"death": actor.apply_hit({"damage":10000,"direction":Vector2.LEFT})
		field._physics_process(1)
		_expect(not slot.active and player.player_health==500, "%s interrupts pending enemy damage without a ghost attack" % interruption)
		actor.queue_free()
	_clean()
	player.global_position=Vector2.ZERO
	var shell=field.cast(bomber,&"mortar")
	var aim: Vector2=shell.target
	player.global_position=Vector2(80,0)
	field._physics_process(1.12)
	_expect(shell.target==aim and player.player_health==500, "mortar target stays fixed and walking outside its circle avoids impact")
	_expect(FIELD.hits_point(shell,Vector2(43,0),1.1,1.12) and not FIELD.hits_point(shell,Vector2(45,0),1.1,1.12), "mortar damage uses the exact44-unit warning radius")
	_clean()
	player.global_position=Vector2.ZERO
	shell=field.cast(bomber,&"mortar")
	field._physics_process(1.09)
	_expect(player.player_health==500, "mortar has no early invisible damage")
	field._physics_process(0.03)
	_expect(player.player_health==470 and shell.released, "mortar lands and deals its real30 damage")
	player.hurt_lock=0
	field._physics_process(0.12)
	_expect(player.player_health==470, "mortar blast is once-only")
	_clean()
	imp.global_position=Vector2.ZERO
	player.global_position=Vector2(160,0)
	var blade=field.cast(imp,&"boomerang")
	var outgoing: Vector2=FIELD.blade_position(blade,blade.windup+blade.leg*0.5)
	var returning: Vector2=FIELD.blade_position(blade,blade.windup+blade.leg*1.5)
	_expect(outgoing.is_equal_approx(returning) and FIELD.blade_position(blade,blade.duration).is_equal_approx(blade.origin), "blade follows the same outward and return path to its launch point")
	_expect(is_equal_approx(blade.origin.distance_to(blade.target)/blade.leg,145), "new blade speed is a bounded readable145 units per second")
	field._physics_process(blade.windup-0.01)
	_expect(player.player_health==500, "blade cannot hit during the line warning")
	field._physics_process(blade.leg*0.95)
	_expect(player.player_health==476, "outbound travelling blade applies its real damage")
	player.hurt_lock=0
	field._physics_process(blade.leg)
	_expect(player.player_health==476, "return path cannot damage the same player twice in one cast")
	_clean()
	blade=field.cast(imp,&"boomerang")
	field._physics_process(blade.duration+1)
	_expect(player.player_health==476, "swept collision still detects a full out-and-back crossing during a long frame")
	_clean()
	imp.global_position=Vector2(0,400)
	player.global_position=imp.global_position+Vector2(260,0)
	imp.tactical_ai.cooldown=0
	imp._physics_process(0.016)
	_expect(not imp.tactical_ai.committed and imp.velocity.x>0, "boomerang imp approaches rather than throwing beyond its real projectile reach")
	player.global_position=imp.global_position+Vector2(210,0)
	imp._physics_process(0.016)
	_expect(imp.tactical_ai.committed, "boomerang imp throws once the player is actually in reach")
	_clean()
	player.global_position=Vector2(-65,0)
	mantis.tactical_ai.cooldown=0
	mantis._physics_process(0.016)
	_expect(mantis.tactical_ai.committed and mantis.velocity.is_zero_approx() and mantis.sprite_2d.flip_h, "actual EnemyShell dispatch starts a committed attack facing the player")
	player.global_position=Vector2(65,0)
	mantis.knockback=Vector2.RIGHT*8
	mantis._physics_process(0.05)
	_expect(mantis.sprite_2d.flip_h and mantis.tactical_ai.slot.heading.x<0, "body and locked slash heading ignore player crossing and minor crowd recoil")
	mantis.knockback=Vector2.ZERO
	field._physics_process(2)
	mantis._physics_process(0.016)
	_expect(mantis.tactical_ai.recovery>0 and mantis.velocity.is_zero_approx(), "slash recovery creates a real punish window")
	_clean()
	mantis.global_position=Vector2(0,1000)
	player.global_position=mantis.global_position+Vector2(45,0)
	mantis.tactical_ai.slot=null
	mantis.tactical_ai.recovery=0
	mantis.tactical_ai.cooldown=1
	mantis._physics_process(0.016)
	_expect(mantis.velocity.is_zero_approx() and not mantis.tactical_ai.committed, "mantis waits at readable sword distance instead of hugging the player during cooldown")
	_clean()
	var objects_before: int=Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var references: Array[int]=[]
	for slot in field.slots: references.append(slot.get_instance_id())
	for _i in 500:
		var slot=field.cast(mantis,&"cleave")
		if slot!=null: field.cancel(slot,mantis)
	_expect(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))==objects_before, "five hundred casts reuse slots/audio without adding attack nodes or timers")
	for i in field.slots.size(): _expect(field.slots[i].get_instance_id()==references[i], "all attack slots remain preallocated")
	field.clear_combat_effects()
	for kind in [&"cleave",&"boomerang",&"mortar"]:
		for _i in int(FIELD.CAPS[kind]):
			var actor: Node=_enemy("BladeMantis",Vector2(0,180))
			_expect(field.cast(actor,kind)!=null, "per-kind admitted attacks have available fixed slots")
		var extra: Node=_enemy("BladeMantis",Vector2(0,180))
		_expect(field.cast(extra,kind)==null, "per-kind warning budgets reject simultaneous overload")
	field.clear_combat_effects()
	for actor in get_nodes_in_group("EnemyGroup"): actor.queue_free()
	await process_frame
	await process_frame
	game.spawner.stage=1
	game.spawner.current_level=0
	game.spawner._stage_themes.clear()
	game.spawner._rebuild_pattern()
	var seen: Dictionary={}
	var ranged_count:=0
	var primary_count:=0
	for _i in 1200:
		var data: EnemyData=game.spawner._next_enemy_data()
		seen[data.title]=true
		if data.archetype==EnemyData.Archetype.RANGED: ranged_count+=1
		if data==game.spawner.primary_enemy_data: primary_count+=1
	_expect(seen.has("blade_mantis") and seen.has("boomerang_imp") and seen.has("spore_bomber"), "all new species are reachable through actual roster draws")
	_expect(ranged_count==60 and primary_count==900 and game.spawner.primary_enemy_data.attack_style==&"", "opening roster keeps5% shared ranged and75% familiar primary theme")
	var a: Node=_enemy("BoomerangImp",Vector2(800,0))
	var b: Node=_enemy("SporeBomber",Vector2(850,0))
	game.spawner.current_level=8
	game.spawner._pattern.assign([load("res://resource/BoomerangImp.tres"),load("res://resource/SporeBomber.tres"),load("res://resource/Enemy_4.tres"),load("res://resource/BladeMantis.tres")])
	game.spawner._pattern_i=0
	game.spawner._pattern_stage=1
	game.spawner._pattern_level=8
	_expect(game.spawner._ranged_alive_count()==2 and game.spawner._next_enemy_data().title=="blade_mantis", "both new ranged species count toward the shared stage-one cap of two")
	field.cast(a,&"boomerang")
	paused=true
	var age: float=field.slots[0].age
	field._physics_process(5)
	_expect(field.slots[0].age==age, "pause freezes attack progress")
	paused=false
	game.variety.clear_combat_effects()
	_expect(not field.is_physics_processing() and field.slots.all(func(s): return not s.active), "stage cleanup removes all warnings/projectiles and stops the renderer")
	main.fullscreen_toggle.home_button.pressed.emit()
	await process_frame
	await process_frame
	_expect(not main.game.enemy_attacks._running, "return Home leaves an inactive fresh attack manager")
	await main._launch_run(&"tactical_enemies")
	_expect(main._test_mode==&"tactical_enemies" and get_nodes_in_group("EnemyGroup").size()==3, "real Debug preset starts all three new species")
	await main._launch_run(&"")
	_expect(main.game.enemy_attacks.casts==0 and get_nodes_in_group("EnemyGroup").is_empty(), "normal new runs never inherit Debug monsters or pending attacks")
	if failures.is_empty(): print("TACTICAL ENEMIES OK: %d checks; real roster/AI, locked warning geometry, slash/mortar/blade damage, dash/interruptions, return-path sweep/once-only hits, fixed budgets, ranged caps, pause/cleanup and Debug isolation" % checks)
	else:
		for message in failures: push_error(message)
	quit(0 if failures.is_empty() else 1)
