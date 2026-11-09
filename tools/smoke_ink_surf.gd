extends SceneTree
const INK := preload("res://script/death_stains.gd")
var checks := 0
var failures: Array[String] = []
var game: Node
var main: Node
var surf: Node
var stains: Node
class Shielded:
	extends Node2D
	var health := 100.0
	var hit_count := 0
	func vulnerable() -> bool: return false
	func apply_hit(_data: Dictionary) -> void: hit_count += 1
func _init() -> void: call_deferred("_run")
func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
func _enemy(at: Vector2, hp: float = 300.0) -> Node:
	var actor: Node=load("res://scenes/enemy_shell.tscn").instantiate()
	actor.set_enemy_data(load("res://resource/Enemy_1.tres"))
	actor.set_player_ref(game.player)
	actor.health=hp
	actor.defense=0
	actor.add_to_group("EnemyGroup")
	actor.death_signal.connect(game.spawner.on_enemy_killed.bind(actor))
	game.add_child(actor)
	actor.global_position=at
	actor.set_physics_process(false)
	return actor
func _plant(count: int = 3, age: float = 0.6) -> void:
	stains.reset()
	for i in count:
		stains.splat(Vector2(20+i*30,0),INK.color_for(&"chaser"),Vector2.RIGHT)
		stains.stamps[i].age=age
	stains.set_process(false)
func _dash(to: Vector2) -> void:
	game.player.global_position=Vector2.ZERO
	game.player.reset_dash()
	game.player._start_dash(Vector2.RIGHT)
	game.player.global_position=to
	surf._physics_process(1.0/60)
	game.player._on_dashing_timer_timeout()
func _run() -> void:
	main=load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene=main
	await process_frame
	await process_frame
	await main._launch_run(&"")
	game=main.game
	surf=game.ink_surf
	stains=game.combat_feedback.death_stains
	game.level_manager.signal_level_up.disconnect(game.on_level_up)
	game.spawner.timer.stop()
	game.spawner.get_node("Elite").stop()
	game.spawner.set_process(false)
	game.weather.stop()
	game.meteors.set_process(false)
	game.variety._courier_left=99999
	for path in ["HandWeapon","CircleWeapon","Weapon","DroneController","MolotovController","FreezeController"]: game.get_node(path).process_mode=Node.PROCESS_MODE_DISABLED
	game.player.set_physics_process(false)
	surf.set_physics_process(false)
	surf.set_process(false)
	_expect(surf._running and not surf.debug_training and surf.charge==0, "normal runs get the mechanic without Debug ink or a card")
	_plant()
	game.player.global_position=Vector2(90,0)
	var registry: Node=root.get_node("CombatTargets")
	var queries: int=registry.queries
	surf._physics_process(0.016)
	_expect(surf.charge==0 and stains.active_count==3 and registry.queries==queries, "walking cannot collect ink or scan enemies")
	var target: Node=_enemy(Vector2(110,0))
	var far: Node=_enemy(Vector2(220,0))
	var shield:=Shielded.new()
	shield.add_to_group("EnemyGroup")
	game.add_child(shield)
	shield.global_position=Vector2(115,0)
	for _i in 5: game.player.add_critical_glasses_level()
	game.player.lifesteal_level=5
	game.player.player_health=300
	game.molotov_controller.level=8
	var rng_before: int=game.player._critical_rng.state
	_dash(Vector2(90,0))
	_expect(surf.surges==1 and surf.absorbed==3 and surf.charge==0 and stains.active_count==0, "one swept dash consumes three distinct landed splashes and releases one surge")
	_expect(target.health==240 and far.health==300 and shield.hit_count==0, "single radius query hits each in-range vulnerable target once and respects shields")
	_expect(target._blast_left>0 and target._blast_velocity.x>0, "surviving enemies receive outward resisted knockback")
	_expect(game.player.player_health==300 and game.player._critical_rng.state==rng_before and target.burn_stacks==0, "surge cannot crit, lifesteal or proc equipped burn")
	_expect(registry.queries==queries+1 and surf.cooldown==6.0, "one enemy query per surge with a gate set before damage")
	surf._on_dash_completed(Vector2(90,0))
	_expect(surf.surges==1 and target.health==240, "duplicate completion cannot replay damage")
	_plant()
	_dash(Vector2(90,0))
	_expect(stains.active_count==3 and surf.surges==1 and surf.absorbed==3, "cooldown dashes do not waste ink or release another pulse")
	paused=true
	surf._process(10)
	_expect(surf.cooldown==6, "pause freezes the cooldown")
	paused=false
	surf._process(6)
	surf.set_process(false)
	_expect(surf.cooldown==0, "cooldown completes in active gameplay")
	_plant(2)
	_dash(Vector2(90,0))
	_expect(surf.charge==2 and surf.surges==1, "partial charge persists between dashes")
	_plant(1)
	var victim: Node=_enemy(Vector2(95,2),1)
	var kills: int=game.spawner.enemy_killed_num
	_dash(Vector2(90,0))
	_expect(surf.surges==2 and surf.charge==0 and game.spawner.enemy_killed_num==kills+1, "next dash completes charge and real deaths still award one kill")
	_expect(stains.active_count==1 and surf.absorbed==6, "surge-created blood cannot recursively recharge or cast itself")
	game.player.reset_critical_glasses()
	game.player.lifesteal_level=0
	game.molotov_controller.level=0
	for age in [0.0,2.2]:
		surf.clear_combat_effects()
		_plant(3,age)
		_dash(Vector2(90,0))
		_expect(surf.charge==0 and stains.active_count==3, "airborne/fading ink cannot be harvested")
	surf.clear_combat_effects()
	_plant()
	_dash(Vector2(500,0))
	_expect(surf.charge==0 and stains.active_count==3, "teleports cannot harvest ink across the map")
	surf.cooldown=2
	game.spawner._rest_open=true
	surf._process(8)
	_expect(surf.cooldown==2, "rest screens do not run the battle cooldown")
	game.spawner._rest_open=false
	surf.clear_combat_effects()
	_plant()
	game.player.set_movement_locked(true)
	game.player._start_dash(Vector2.RIGHT)
	_expect(not game.player.dashing and not surf._active() and surf.charge==0, "wooden-trial movement lock cannot be bypassed")
	game.player.set_movement_locked(false)
	surf.charge=2
	surf.cooldown=2
	game.variety.clear_combat_effects()
	_expect(surf.charge==0 and surf.cooldown==0 and stains.active_count==0, "stage transitions clear all transient ink states")
	main.fullscreen_toggle.home_button.pressed.emit()
	await process_frame
	await process_frame
	_expect(not main.game.ink_surf._running and main.game.ink_surf.charge==0, "Home leaves a fresh inactive controller")
	await main._launch_run(&"ink_surf")
	_expect(main.game.ink_surf.debug_training and main._test_mode==&"ink_surf", "real Debug preset enables a renewable practice path")
	await main._launch_run(&"")
	_expect(not main.game.ink_surf.debug_training and main.game.ink_surf.surges==0, "new normal runs never inherit Debug paths or charge")
	if failures.is_empty(): print("INK SURF OK: %d checks; actual dash signals/sweeps, charge/cooldown, once-only reward/proc bounds, radius/shields/knockback, pause/transitions/Home and Debug isolation" % checks)
	else:
		for message in failures: push_error(message)
	quit(0 if failures.is_empty() else 1)
