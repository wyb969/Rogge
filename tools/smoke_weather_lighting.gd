extends SceneTree
var failures: Array[String] = []
var checks := 0
func _init() -> void: call_deferred("_run")
func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	main._on_debug_button_pressed()
	main.debug_page.box.get_node("DebugWeatherLightButton").pressed.emit()
	await process_frame
	await process_frame
	var g: Node = main.game
	var w: Node = g.weather
	var fx: Node = w.lighting
	g.spawner.timer.stop()
	g.spawner.get_node("Elite").stop()
	g.spawner.set_process(false)
	g.player.set_physics_process(false)
	var store: Node = root.get_node("SettingsStore")
	var saved: float = store.weather_intensity
	store.set_weather_intensity(1)
	w.set_preview(0, 0)
	expect(w._preview.visible and fx.sun_amount == 1 and fx.shafts.visible and not fx.lamp.enabled, "actual new Debug starts clear daytime shafts, no rain lamp")
	expect(fx.get_child_count() == 3 and fx.lamp is PointLight2D and not fx.lamp.shadow_enabled, "one fixed lamp and two batches without shadow maps")
	expect(fx.lamp.texture == g.combat_lighting.glow_texture() and fx.lamp.texture.get_width() == 64, "reuse small light texture")
	expect(fx.shafts.z_index < 0 and fx.scenery.z_index < -30 and fx.lamp.range_z_max == 0, "actors and UI remain above shafts, decor above its shadows")
	var a: Vector3 = fx.projection_at(Vector2(-100,0))
	var b: Vector3 = fx.projection_at(Vector2(100,0))
	expect(a == b and Vector2(a.x,a.y).is_equal_approx(w.sun_direction), "sunlight gives all objects the same projection direction")
	w.set_preview(0, 0.5)
	expect(fx.sun_amount == 0 and not fx.shafts.visible and not fx.lamp.enabled, "no sunlight at night")
	w.set_preview(2, 0.5)
	expect(fx.rain_amount == 1 and fx.lamp.enabled and is_equal_approx(fx.lamp.energy,0.8) and not fx.shafts.visible, "rain switches on bounded lamp")
	var center: Vector2 = fx.lamp.global_position
	a = fx.projection_at(center + Vector2(40,0))
	b = fx.projection_at(center + Vector2(-40,0))
	expect(a.x > 0.99 and b.x < -0.99 and a.z > 0, "rain shadows point away from player on opposite sides")
	expect(fx.projection_at(center + Vector2(400,0)).z == 0, "distant objects get no fake lantern cast shadow")
	expect(fx.projection_at(center, false).z == 0, "player does not cast self-shadow away from its own lamp")
	g.player.global_position += Vector2(80,30)
	fx._process(0.001)
	expect(fx.lamp.global_position.is_equal_approx(g.player.global_position+Vector2(0,4)), "lamp follows actual player every render frame")
	var at: Vector2 = g.player.global_position + Vector2(40,0)
	a = fx.projection_at(at)
	g.player.global_position.x += 80
	fx._process(0.001)
	b = fx.projection_at(at)
	expect(a.x > 0 and b.x < 0, "moving past object reverses its shadow, not tied to camera")
	paused = true
	var clock: float = w.elapsed
	await create_timer(0.06, true, false, true).timeout
	expect(w.elapsed == clock, "pause freezes sunlight animation")
	paused = false
	var child_count: int = fx.get_child_count()
	var lamp_id: int = fx.lamp.get_instance_id()
	for i in 40:
		w.set_preview(i % 4, 0)
		fx._process(0.016)
	expect(fx.get_child_count() == child_count and fx.lamp.get_instance_id() == lamp_id, "repeated weather changes reuse all nodes and textures")
	w.set_preview(2, 0)
	w._select(0, false)
	w._process(1.25)
	expect(fx.sun_amount > 0 and fx.sun_amount < 1 and fx.rain_amount > 0 and fx.rain_amount < 1, "weather transitions crossfade, not snap")
	store.set_weather_intensity(0)
	w._update_environment()
	expect(fx.sun_amount == 0 and fx.rain_amount == 0 and not fx.lamp.enabled and not fx.shafts.visible, "zero weather setting disables new illumination")
	var spawned: Array[Node] = []
	for i in 80:
		var enemy = load("res://scenes/enemy_shell.tscn").instantiate()
		enemy.set_enemy_data(load("res://resource/Enemy_1.tres"))
		enemy.set_player_ref(g.player)
		enemy.add_to_group("EnemyGroup")
		g.add_child(enemy)
		enemy.global_position = g.player.global_position + Vector2(i % 10 * 5, i / 10 * 5)
		enemy.set_physics_process(false)
		spawned.append(enemy)
	g.combat_lighting._process(0.11)
	expect(g.combat_lighting._shadow_count == 64 and g.combat_lighting._shadow_sprites.size() == 64, "80 enemies stay within fixed 64 silhouette slots")
	var total_nodes := get_node_count()
	for i in 120: fx._process(0.016)
	expect(get_node_count() == total_nodes, "crowd light updates do not create per-enemy nodes")
	var freed = spawned[0]
	freed.free()
	expect(not g.combat_lighting._visible(freed), "deleted actor cannot enter shadow drawing")
	store.set_weather_intensity(saved)
	w.stop()
	expect(not fx.is_processing() and not fx.lamp.enabled and not fx.scenery.visible and not fx.shafts.visible, "weather stop clears light and shadow effects")
	main.show_main_menu()
	await main._launch_run(&"")
	expect(not main.game.weather._preview or not main.game.weather._preview.visible, "normal new run has no Debug controls")
	main.show_main_menu()
	if failures.is_empty(): print("WEATHER LIGHTING OK: %d checks; real Debug, shared lamp/bounds, solar/radial shadows, movement, pause, crossfade, zero intensity, stop and reset" % checks)
	else:
		for message in failures: push_error(message)
	quit(0 if failures.is_empty() else 1)
