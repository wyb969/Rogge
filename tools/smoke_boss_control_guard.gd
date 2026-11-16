extends SceneTree
var failures: Array[String]=[]
var checks:=0
func _init() -> void:call_deferred("run")
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok: failures.append(note)
func settle() -> void:
	for i in 4:await process_frame
func run() -> void:
	var main=load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene=main
	await settle()
	for stage in range(1,7):
		await main._launch_run(&"")
		var g: Node=main.game
		g.spawner.timer.stop()
		g.spawner.get_node("Elite").stop()
		g.weather.stop()
		g.player.set_physics_process(false)
		g.player.player_health=100000
		for path in ["HandWeapon","CircleWeapon","Weapon","DroneController","MolotovController","FreezeController"]:g.get_node(path).process_mode=Node.PROCESS_MODE_DISABLED
		g.spawner.stage=stage
		g.spawner.spawn_boss()
		for boss in g.spawner._active_bosses:boss.set_physics_process(false)
		await settle()
		for size in [Vector2i(900,600),Vector2i(390,844),Vector2i(844,390)]:
			root.size=size
			await settle()
			for boss in g.spawner._active_bosses:
				var bar: Control=boss.health_bar
				expect(bar.is_visible_in_tree(),"boss HUD visible stage "+str(stage))
				expect(Rect2(Vector2.ZERO,root.get_visible_rect().size).encloses(bar.get_global_rect()),"health bar in screen")
				var scale: float=(root.get_final_transform()*Vector2.DOWN-root.get_final_transform()*Vector2.ZERO).length()
				expect(bar.size.y*scale>=11.5,"health bar physical size")
		for boss in g.spawner._active_bosses:
			var start: Vector2=boss.position
			for i in 30:
				if i%5==0:boss.apply_electric_stun(1)
				boss._physics_process(0.1)
				if i<29:expect(boss.position==start,"every boss including both wind roles stops during shock")
			expect(boss.is_control_immune() and boss.electric_stun_left==0,"3s continuous control releases boss")
			expect(is_equal_approx(boss.control_immunity_left,3),"full three-second immunity")
			expect(boss.health_bar.is_visible_in_tree(),"shock never tears down health HUD")
			var hp: float=boss.boss_current_health
			boss.apply_hit({"damage":1,"damage_is_final":true,"from_status":true,"effect":"electric_grid"})
			Engine.time_scale=1
			for i in 20:
				boss.apply_electric_stun(1)
				boss.apply_terrain_impulse(Vector2(200,0))
				boss.set_poison_exposure(true,0.5,Color.WHITE)
				boss._physics_process(0.1)
				expect(boss.electric_stun_left==0 and boss.terrain_impulse.left==0 and boss.poison_slow==1,"immune to shock, terrain push and slow")
			expect(boss.boss_current_health==hp-1,"control immunity is not damage immunity")
			expect(boss.position.distance_to(start)>1,"boss can move away during immunity")
			var left: float=boss.control_immunity_left
			paused=true
			boss._physics_process(1)
			paused=false
			expect(boss.control_immunity_left==left,"pause does not consume immunity")
			boss._tick_environment_control(left)
			boss.apply_electric_stun(1)
			expect(boss.electric_stun_left>0 and not boss.is_control_immune(),"can be controlled after immunity expires")
			boss._tick_environment_control(1)
			boss._tick_environment_control(0.01)
			expect(boss.control_time==0,"free gap resets continuous-control counter")
			boss.apply_electric_stun(1)
			g.pause_menu.show_upgrade_options()
			await settle()
			main.session_menu.open_menu()
			main.session_menu.close_menu()
			g.pause_menu.h_box_container.get_child(0).selected.emit(g.pause_menu.h_box_container.get_child(0).upgrade_id)
			await settle()
			expect(boss.health_bar.is_visible_in_tree(),"health HUD survives card/menu round-trip")
			boss.suspend_feedback()
			expect(not boss.health_bar.is_visible_in_tree() and boss.control_time==0 and not boss.is_control_immune(),"real teardown still hides HUD and clears guard")
		main.show_main_menu()
	if failures.is_empty():print("BOSS CONTROL GUARD OK: %d checks; seven boss actors, visible HUD, control 3s/immunity 3s, damage retained, pause and teardown"%checks)
	else:
		for f in failures:push_error(f)
	quit(0 if failures.is_empty() else 1)
