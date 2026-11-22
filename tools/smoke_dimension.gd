extends SceneTree
var errors: Array[String] = []

func check(value: bool, message: String) -> void:
	if not value: errors.append(message)

func _init() -> void: call_deferred("run")

func run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	main._on_dimension_practice()
	var slot: Node = main.starter_lottery
	slot._on_button()
	slot._process(3)
	check(slot.loadout.group == "dimension" and slot.loadout.cards.size()==3 and slot.foil.get_shader_parameter("dimension"),"guaranteed yellow three-card reel")
	slot._on_button()
	await process_frame
	await process_frame
	var g: Node = main.game
	g.spawner.stop_run()
	g.weather.stop()
	var lab: Node = g.dimension_lab
	lab.set_physics_process(false)
	lab.clear_combat_effects()
	var p: Node2D = g.player
	var panel: Node = g.equipment_panel
	check(panel.dimension_active and panel._active_combo_borders.size()==3,"yellow set equipped")
	for border in panel._active_combo_borders: check(border.tint == Color("#fff36a"),"Morty shirt border")
	g._spawn_control_targets([Vector2(35,0),Vector2(160,0),Vector2(170,32)])
	await physics_frame
	await physics_frame
	var a: Node2D = lab._nearest(p.global_position,70)
	check(is_instance_valid(a),"real horde actor")
	var b: Node2D = lab._nearest(p.global_position+Vector2(160,0),40)
	var c: Node2D = lab._nearest(p.global_position+Vector2(170,32),25)
	for mob in [a,b,c]: mob.set_physics_process(false)
	var hp: float = a.health
	var original: Vector2 = a.global_position
	lab._open(p.global_position,a)
	lab._scan_gate()
	check(a.global_position.distance_to(original)>55 and a.health<hp and lab.flights.size()==1,"portal actually transits and damages a normal body")
	var other_hp: float = b.health
	for i in 12:
		a._tick_environment_control(1.0/60.0)
		lab._tick_flights(1.0/60.0)
	check(b.health < other_hp,"launched body collides and damages its neighbor")
	lab.last_position = p.global_position
	lab.gate_cd=99
	lab.box_cd=99
	for i in 60:
		p.global_position += Vector2.RIGHT*4.1
		lab._physics_process(1.0/60.0)
	check(is_equal_approx(lab.charge,1),"actual movement fully charges and reserves the cell")
	lab.box_cd=0
	lab._physics_process(0.02)
	check(lab.working and lab.powered and lab.charge==0,"next dispatched helper carries the cell")
	var marked: Node2D = lab.worker
	var marked_hp: float = marked.health
	for i in 46: lab._tick_worker(1.0/60.0)
	check(lab.landed and lab.arcs.size()>=2 and marked.health < marked_hp,"powered delivery hits the marked target and nearby enemies")
	var forge: RefCounted = g.forge
	var main_uid: int = forge.cards.filter(func(card): return card.id == "micro_cell")[0].uid
	var gun_uid: int = forge.cards.filter(func(card): return card.id == "portal_gun")[0].uid
	forge.wallet = 5000
	forge.seal_stage()
	check(L10n.text("跨维度外包将失效") in forge.preview(main_uid,[gun_uid]).warnings,"last-copy sacrifice warns")
	check(forge.attempt(main_uid,[gun_uid]).ok and not panel.dimension_active,"sacrifice disables synergy")
	lab.clear_combat_effects()
	lab.charge=1
	lab.box_cd=99
	lab._physics_process(.016)
	check(lab.charge==0 and lab.arcs.size()>0,"battery operates alone after breaking the set")
	lab.box_cd=0
	lab._physics_process(.016)
	check(lab.working and not lab.powered,"normal helper dispatch")
	var victim: Node2D = lab.worker
	hp = victim.health
	for i in 60: lab._tick_worker(.016)
	check(victim.health<hp,"normal delivery punch deals damage")
	g.forge.add_card("portal_gun",0)
	lab.clear_combat_effects()
	for mob in [a,b,c]: mob.remove_from_group("EnemyGroup")
	var boss: Node2D = load("res://scenes/boss.tscn").instantiate()
	boss.set_player(p)
	g.add_child(boss)
	boss.global_position=p.global_position+Vector2(0,32)
	boss.add_to_group("EnemyGroup")
	boss.set_physics_process(false)
	var boss_at := boss.global_position
	lab._open(p.global_position,boss)
	var boss_hp: float=boss.boss_current_health
	lab._scan_gate()
	check(boss.global_position.is_equal_approx(boss_at) and boss.boss_current_health<boss_hp,"boss takes gate damage in place")
	boss_hp=boss.boss_current_health
	lab._dispatch(boss,true)
	for i in 46: lab._tick_worker(1.0/60.0)
	check(boss.boss_current_health<boss_hp and lab.arcs.size()>0,"powered landing damages a boss")
	g.variety.clear_combat_effects()
	check(not lab.working and lab.flights.is_empty() and lab.gate_left==0 and lab.charge==0 and lab.arcs.is_empty(),"stage cleanup clears all transients")
	for msg in errors: push_error(msg)
	if errors.is_empty(): print("DIMENSION SET OK: real portal collision, solo casts, movement charge, powered dispatch, boss combat, set loss and cleanup")
	quit(0 if errors.is_empty() else 1)
