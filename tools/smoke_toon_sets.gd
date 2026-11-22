extends SceneTree

var errors: Array[String] = []
var main: Node
var game: Node

func check(ok: bool, message: String) -> void:
	if not ok: errors.append(message)
func _init() -> void: call_deferred("run")

func claim(bucket: int, group: String,color: Color) -> void:
	main._on_theme_practice(bucket)
	var slot: Node=main.starter_lottery
	slot._on_button()
	slot._process(3)
	check(slot.loadout.group==group and slot.loadout.cards.size()==3 and slot.foil.get_shader_parameter("toon") and slot.foil.get_shader_parameter("toon_tint")==color,"three themed prizes and exact foil tint "+group)
	slot._on_button()
	await process_frame
	await process_frame
	game=main.game
	game.spawner.stop_run()
	game.weather.stop()
	for border in game.equipment_panel._active_combo_borders: check(border.tint==color,"matching equipment border")
	check(game.equipment_panel._active_combo_borders.size()==3,"three active borders")

func enemies(offsets: Array) -> Array[Node2D]:
	game._spawn_control_targets(offsets)
	await physics_frame
	await physics_frame
	var targets: Array[Node2D]=root.get_node("CombatTargets").in_radius(game.player.global_position,350*350,game)
	for actor in targets:
		actor.health=10000
		actor.set_physics_process(false)
	return targets

func sacrifice(main_id: String,sub_id: String,warning: String) -> void:
	var forge: RefCounted=game.forge
	forge.seal_stage()
	forge.wallet=10000
	var first: int=forge.cards.filter(func(card):return card.id==main_id)[0].uid
	var sub: int=forge.cards.filter(func(card):return card.id==sub_id)[0].uid
	check(L10n.text(warning) in forge.preview(first,[sub]).warnings,"preview warns of lost set")
	check(forge.attempt(first,[sub]).ok,"actual sacrifice succeeds")

func run() -> void:
	main=load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene=main
	await process_frame
	await process_frame
	var outcomes:={}
	for quarter in 400:
		var set_id: String=main.starter_lottery.draw_loadout("pickup_up",quarter*0.25).group
		outcomes[set_id]=outcomes.get(set_id,0)+1
	for group in ["growth","arsenal","crimson","dimension","dragon","pocket"]: check(outcomes.get(group)==20,"5% for "+group)
	check(outcomes.get("")==280,"70% mixed")
	await claim(10,"dragon",Color("#ff7926"))
	var turtle: Node=game.turtle_school
	turtle.set_physics_process(false)
	var actors:=await enemies([Vector2(66,0),Vector2(118,5)])
	var a: Node2D=turtle.closest(game.player.global_position,88)
	check(turtle.cast("solar_flare") and a.solar_blind_left>0 and turtle.window>0,"actual blind and dash window")
	var at: Vector2=game.player.global_position
	game.player._start_dash(Vector2.DOWN)
	check(turtle.echo_at==at and turtle.delayed>0,"normal dash captured the afterimage")
	game.player.global_position+=Vector2(0,37)
	for i in 45:turtle.advance(1.0/60.0)
	check(turtle.combo_hits.get(a.get_instance_id())==3 and a.health<9950,"disc and beam cross on one target")
	check(turtle.cast("kienzan") and turtle.cast("kamehameha"),"both independent attacks cast")
	sacrifice("kienzan","kamehameha","龟仙流反击将失效")
	check(not game.equipment_panel.dragon_active and turtle.window==0,"removing beam cancels combination")
	game.variety.clear_combat_effects()
	check(a.solar_blind_left==0 and turtle.beams.is_empty() and turtle.discs.is_empty(),"martial cleanup")
	await main._on_game_end_ui_main_menu_pressed()
	await claim(15,"pocket",Color("#009fe3"))
	var pocket: Node=game.pocket_school
	pocket.set_physics_process(false)
	actors=await enemies([Vector2(40,0),Vector2(72,0),Vector2(104,0),Vector2(138,0),Vector2(170,0),Vector2(202,0)])
	a=pocket.closest(game.player.global_position,65)
	var base_size:=a.scale
	check(pocket.cast("small_light") and a.scale.is_equal_approx(base_size*0.5),"shrink changes actor and collision scale")
	check(pocket.cast("air_cannon") and a.pocket_rolling and a.pocket_big,"air cannon launches a real enlarged enemy")
	for i in 36:pocket.advance(1.0/60.0)
	check(pocket.strike_left>0 and not a.pocket_rolling and a.get_collision_mask_value(4),"five different targets and safe landing")
	game._spawn_xp_coin_now(game.player.global_position+Vector2(100,42),7)
	await process_frame
	var coin: Node2D=game._xp_actors.back()
	var coin_at:=coin.global_position
	var amount: int=coin.prepared_xp
	check(pocket.cast("big_light") and pocket.rollers.back().coin==coin,"uses a real loose coin")
	for i in 61:pocket.advance(1.0/60.0)
	check(is_instance_valid(coin) and coin.global_position.distance_to(coin_at)>150 and coin.prepared_xp==amount and not coin._credited,"coin rolls and retains its XP for pickup")
	coin.credit_once()
	check(coin._credited,"rolled coin can still be collected")
	check(pocket.cast("big_light") and not pocket.rollers.back().gold,"pebble fallback")
	sacrifice("air_cannon","small_light","口袋保龄球将失效")
	check(not game.equipment_panel.pocket_active and a.scale.is_equal_approx(base_size),"sacrifice restores shrunken bodies")
	game.variety.clear_combat_effects()
	check(pocket.rollers.is_empty(),"stage cleanup releases all projectiles")
	for actor in actors: actor.remove_from_group("EnemyGroup")
	var boss: Node2D=load("res://scenes/boss.tscn").instantiate()
	boss.set_player(game.player)
	game.add_child(boss)
	boss.add_to_group("EnemyGroup")
	boss.global_position=game.player.global_position+Vector2(50,0)
	var boss_at:=boss.global_position
	var hp: float=boss.boss_current_health
	pocket.cast("air_cannon")
	check(boss.global_position==boss_at and boss.boss_current_health<hp and pocket.rollers.is_empty(),"boss takes direct damage in place")
	var fx: Node = game.combat_feedback.impact_feedback
	check(fx.stops == 0, "automatic themed attacks never stop the world, including on a boss")
	var offsets := []
	for i in 16: offsets.append(Vector2(-120 + i * 8, 40))
	boss.remove_from_group("EnemyGroup")
	var crowd := await enemies(offsets)
	await process_frame
	var flashes: int = fx.flashes
	var count := 0
	for mob in crowd:
		if mob == boss: continue
		var before: float = mob.health
		if count % 2: pocket.hit(mob, 10, Vector2.RIGHT)
		else: mob.apply_hit({"damage":10.0,"direction":Vector2.RIGHT})
		check(mob.health < before, "every crowded target takes damage")
		count += 1
	check(count >= 16 and fx.flashes - flashes == 4 and fx.stops == 0, "simultaneous regular and themed crowd hits share four cosmetic slots")
	for msg in errors: push_error(msg)
	if errors.is_empty(): print("TOON SETS OK: six jackpot buckets, both reveals, dash crossfire, five-body strike, real XP coin, boss and sacrifice cleanup")
	quit(0 if errors.is_empty() else 1)
