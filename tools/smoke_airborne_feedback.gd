extends SceneTree
var failures: Array[String] = []
var checks := 0
var g: Node
func _init() -> void: call_deferred("run")
func expect(ok: bool, text: String) -> void:
	checks += 1
	if not ok: failures.append(text)
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
	g.weather.set_process(false)
	g.variety.set_process(false)
	g.meteors.set_process(false)
	g.combat_feedback.set_process(false)
	var p: Node = g.player
	p.set_physics_process(false)
	p.set_process(false)
	for path in ["HandWeapon","CircleWeapon","Weapon","DroneController","MolotovController","FreezeController"]: g.get_node(path).process_mode = Node.PROCESS_MODE_DISABLED
	var field: Node = g.weather.minefield
	field.set_physics_process(false)
	field._physics_process(0.01)
	var marker: Node = p.player_ring
	expect(marker.position==Vector2(0,17) and marker.z_index<p.animated_sprite_2d.z_index,"gradient sits at feet below body")
	expect(marker.texture==null and marker._gradient.width==64 and marker._gradient.fill==GradientTexture2D.FILL_RADIAL,"single cached radial texture replaces old diamond")
	expect(marker._gradient.gradient.colors[4].a==0 and marker._gradient.gradient.colors[2].a<=0.35,"gradient has transparent edge and bounded brightness")
	var at: Vector2 = field.mines[4].at
	p.global_position = at-field.FOOT+Vector2(-8,0)
	p.hurt_lock = 0
	p.shield = 0
	p.damage_reduction = 0
	p.beast_damage_scale = 1
	var hp: float = p.player_health
	field._clock = 2
	field._snapshot()
	var selected: Array[int] = [4]
	field._blast_batch(selected)
	expect(p.player_health==hp-24 and p.terrain_impulse.visual_age==0,"actual surviving mine hit launches visual flight")
	expect(g.combat_feedback._shake==5,"launch requests a bounded strong screen shake")
	var ground: Vector2 = p.global_position
	var shape: Node2D = p.get_node("Area2D/CollisionShape2D")
	var collider_position: Vector2 = shape.position
	var body_base: Vector2 = p._visual_base_position
	p._tick_visuals(0.22)
	expect(is_equal_approx(p.terrain_impulse.height(),42),"player reaches visible 42-unit apex")
	expect(p.animated_sprite_2d.position==body_base+Vector2(0,-42),"sprite lifts above ground")
	expect(p.global_position==ground and shape.position==collider_position and p.scale==Vector2.ONE,"cosmetic Z never changes collider/root")
	expect(marker.position==Vector2(0,17),"ground gradient cannot follow airborne body upward")
	expect(p.health_bar.position==p._health_base_position+Vector2(0,-42),"health bar follows body instead of covering raised sprite")
	g.combat_feedback._shake = 0
	p._tick_visuals(0.22)
	expect(p.animated_sprite_2d.position==body_base and g.combat_feedback._shake==2.7,"landing restores body and triggers one smaller shake")
	g.combat_feedback._shake = 0
	p._tick_visuals(0.06)
	expect(g.combat_feedback._shake==0 and p.terrain_impulse.landing_strength()>0.99,"landing cue is not repeated; squash pulse peaks")
	p._tick_visuals(0.2)
	expect(p.terrain_impulse.height()==0 and p.terrain_impulse.landing_left==0,"landing visual finishes cleanly")
	# Existing camera comfort setting controls both new impulses through the single mixer.
	var settings: Node = root.get_node("SettingsStore")
	var comfort: float = settings.camera_shake
	settings.camera_shake = 0
	g.combat_feedback.terrain_launch(Vector2.RIGHT)
	g.combat_feedback._process(0.016)
	expect(g.combat_feedback._camera.offset==g.combat_feedback._origin,"shake-disabled setting remains respected")
	settings.camera_shake = comfort
	p.clear_terrain_impulse()
	p.apply_terrain_impulse(Vector2.RIGHT*260)
	p._tick_visuals(0.15)
	p.set_movement_locked(true)
	expect(p.animated_sprite_2d.position==body_base and not p.terrain_impulse.is_active(),"trial lock immediately clears flying visual")
	p.set_movement_locked(false)
	# All archetypes use world-space height even when root body_scale differs.
	for resource in ["Enemy_1","Enemy_3","Enemy_4","Enemy_5"]:
		var actor = load("res://scenes/enemy_shell.tscn").instantiate()
		actor.set_enemy_data(load("res://resource/"+resource+".tres"))
		actor.set_player_ref(p)
		g.add_child(actor)
		actor.set_physics_process(false)
		actor.global_position = ground+Vector2(300,0)
		actor.apply_terrain_impulse(Vector2.RIGHT*360)
		actor.set_process(false)
		actor._process(0.22)
		expect(actor.sprite_2d.position.y*actor.body_scale<-23,"visible body-scaled enemy lift: "+resource)
		actor.apply_electric_stun(1)
		expect(is_zero_approx(actor.sprite_2d.position.y) and not actor.terrain_impulse.is_active(),"electric interrupt cannot strand an enemy in the air")
		actor.clear_terrain_impulse()
		expect(is_zero_approx(actor.sprite_2d.position.y) and not actor.is_processing(),"enemy cleanup restores pose and disables idle render work")
		actor.queue_free()
	for path in ["boss","knight_boss","beast_boss"]:
		var boss = load("res://scenes/"+path+".tscn").instantiate()
		boss.set_player(p)
		g.add_child(boss)
		boss.set_process(false)
		boss.set_physics_process(false)
		boss.global_position = ground+Vector2(-300,0)
		boss.apply_terrain_impulse(Vector2.RIGHT*360)
		boss._process(0.22)
		expect(is_equal_approx(boss.terrain_impulse.height(),22) and boss.sprite_2d.position.y<-19,"boss body visibly rises: "+path)
		if path=="knight_boss":
			expect(is_equal_approx(boss._sword.position.y-boss.sprite_2d.position.y,16),"knight sword stays attached while airborne")
		boss.clear_terrain_impulse()
		expect(boss.sprite_2d.position==boss._terrain_base_position,"boss cleanup restores exact base position")
		boss.queue_free()
	# Display frame rate affects sampling, never the flight duration or ground hit geometry.
	for step in [1.0/30,1.0/60,1.0/120,0.1]:
		var impulse = load("res://script/terrain_impulse.gd").new()
		impulse.start(Vector2.RIGHT*260,0.28,42)
		var elapsed := 0.0
		var landings := 0
		var peak := 0.0
		while elapsed<0.8:
			if impulse.advance_visual(step): landings += 1
			peak = maxf(peak,impulse.height())
			elapsed += step
		expect(landings==1 and impulse.height()==0 and peak>=41,"single smooth parabola at display step "+str(step))
	p.apply_terrain_impulse(Vector2.RIGHT*260)
	p.terrain_impulse.tick(p,0.3)
	p._tick_visuals(0.32)
	expect(p.terrain_impulse.left==0 and p.terrain_impulse.is_active(),"cosmetic flight outlives ground impulse without extending control lock")
	field._pushed[p.get_instance_id()] = weakref(p)
	field._physics_process(0.01)
	expect(field._pushed.has(p.get_instance_id()),"mine retains cleanup ownership through cosmetic flight tail")
	g.end_game()
	expect(p.animated_sprite_2d.position==body_base and not p.terrain_impulse.is_active(),"end-game cleanup never leaves player floating")
	main.queue_free()
	await process_frame
	if failures.is_empty(): print("AIRBORNE FEEDBACK OK: ",checks," checks")
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
