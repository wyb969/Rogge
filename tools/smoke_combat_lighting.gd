extends SceneTree
var failures: Array[String] = []
func _init() -> void : call_deferred("_run")
func _expect(ok: bool, message: String) -> void :
	if not ok: failures.append(message)
func _run() -> void :
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	await main._launch_run(&"")
	var game: Node = main.game
	game.diagnostic_mode = "light_test"
	game.spawner.set_process(false)
	game.spawner.timer.stop()
	game.spawner.get_node("Elite").stop()
	game.player.set_physics_process(false)
	game.level_manager.signal_level_up.disconnect(game.on_level_up)
	game.level_manager.level_need_coin_number = 100000
	for name in ["HandWeapon", "CircleWeapon", "Weapon", "DroneController", "MolotovController", "FreezeController"]:
		game.get_node(name).process_mode = Node.PROCESS_MODE_DISABLED
	var lights: Node = game.combat_lighting
	_expect(lights.get_child_count() == 3 and lights.find_children("*", "PointLight2D", true, false).is_empty(), "three fixed batches provide light/shadow without per-source realtime lights")
	_expect(lights._fields[0].z_index < lights._fields[1].z_index and lights._fields[2].z_index < 0, "ground and halo layers remain below opaque actors, warnings and hostile shots")
	var texture: Texture2D = lights.glow_texture()
	_expect(texture.get_width() == 64 and texture == load("res://script/combat_lighting.gd").glow_texture(), "all local lights and shadows share one small cached texture")
	var enemy: Node = load("res://scenes/enemy_shell.tscn").instantiate()
	enemy.set_enemy_data(load("res://resource/Enemy_1.tres"))
	enemy.set_player_ref(game.player)
	enemy.add_to_group("EnemyGroup")
	game.add_child(enemy)
	enemy.global_position = Vector2(120, 0)
	enemy.health = 10000
	enemy.set_physics_process(false)
	var drone: Node = load("res://scenes/drone.tscn").instantiate()
	game.effect_container.add_child(drone)
	drone.setup(game.player, 8, 1, 10, 0)
	drone.set_process(false)
	drone.global_position = Vector2(40, 0)
	var before_hp: float = enemy.health
	drone._start_laser()
	drone._update_laser(0.1)
	_expect(enemy.health == before_hp - 16 and lights._drones.has(drone), "lit laser retains the original actual damage ticks")
	var points: int = drone.laser_line.get_point_count()
	for _i in 100: drone._draw_laser_to(enemy.global_position)
	_expect(points == 2 and drone.laser_line.get_point_count() == 2 and drone.get_child_count() == 2, "laser core reuses two points and adds no per-drone glow nodes")
	game.gun_weapon.upgrade()
	game.gun_weapon.auto_attack_timer.stop()
	game.gun_weapon.cool_down = true
	game.gun_weapon.shoot()
	var bullet: Node = game.effect_container.get_children().back()
	_expect(bullet.is_in_group("player_projectile") and lights._bullets.has(bullet) and bullet.SPEED == 1200 and bullet.pierce == 3, "real shooting registers cosmetic light without changing projectile speed or piercing")
	var flashes: = 0
	for flash in lights._flashes:
		if flash.left > 0: flashes += 1
	_expect(flashes == 1, "one actual shot emits one pooled muzzle flash")
	bullet.set_physics_process(false)
	bullet.monitoring = false
	for i in 80:
		var extra: Node = load("res://scenes/bullet.tscn").instantiate()
		game.effect_container.add_child(extra)
		extra.global_position = Vector2(80 + i * 4, 30)
		extra.set_physics_process(false)
		extra.monitoring = false
	_expect(lights._bullets.size() == 64, "cosmetic projectile registration has a fixed cap even for larger shot storms")
	for i in 200:
		var orb: Node = game.spawn_healing_orb(Vector2(-100 + i % 8 * 30, 80 + float(i / 8) * 30), 5)
		orb.set_physics_process(false)
	lights._process(0.11)
	_expect(lights._orb_count <= 8 and game._healing_actors.size() == 96, "many healing drops keep the pickup cap and a separate small glow budget")
	_expect(lights._pickup_shadow_count <= 32 and lights._pickup_shadows.size() == 32, "pickup shadows use a fixed cache independent of drop count")
	for i in lights._orb_count:
		for j in i: _expect(lights._cells[i] != lights._cells[j], "healing lights cluster by ground cell instead of stacking into a wash")
	var node_count: int = lights.get_child_count()
	var slots: Array = lights._flashes.duplicate()
	for _i in 500: lights.muzzle(Vector2.ZERO, Vector2.RIGHT)
	var reused: = true
	for i in slots.size(): reused = reused and is_same(slots[i], lights._flashes[i])
	_expect(reused and lights.get_child_count() == node_count and slots.size() == 8, "500 muzzle bursts recycle fixed records without adding nodes")

	var audio: Node = root.get_node("AudioManager")
	var glow: Node = game.level_manager.pickup_glow
	audio.reset_pickup_combo()
	var previous: = 0.0
	var xp: int = game.level_manager.coin_number
	for i in 6:
		if i > 0: audio._pickup_stamp = Time.get_ticks_msec() - 80
		audio.play_pickup()
		_expect(is_equal_approx(glow.pitch, audio.pick_coin_audio_player.pitch_scale) and glow.peak > previous and glow.peak <= 1, "every higher admitted note produces a brighter matching XP pulse")
		previous = glow.peak
		var stamp: int = audio._pickup_stamp
		audio.play_pickup()
		_expect(glow.peak == previous and audio._pickup_stamp == stamp, "same-frame suppressed pickup sounds cannot artificially pump the XP glow")
	_expect(glow.pitch == 2 and game.level_manager.coin_number == xp, "the audible octave peak maps to full glow without granting fake XP")
	paused = true
	await create_timer(0.65, true, false, true).timeout
	_expect( not glow.visible and glow.energy == 0, "XP glow fades away through a reward pause and stops processing")
	paused = false
	audio.play_pickup()
	_expect(glow.pitch == 1 and is_equal_approx(glow.peak, 0.18), "a gap resets both audible pitch and visual brightness")
	game.level_manager.coin_number = 50000
	game.level_manager._process(0)
	_expect(game.level_manager.progress_bar.value == 50 and game.level_manager.progress_bar.modulate == Color.WHITE, "new HUD glow preserves exact progress and avoids unbounded level-color modulation")
	var expired: Node = game.spawn_healing_orb(Vector2(80, 90), 5)
	expired.set_physics_process(false)
	lights._process(0.11)
	expired.free()
	enemy.free()
	_expect( not lights._visible(expired) and not lights._visible(enemy), "cached pickups/targets may disappear between source refresh and drawing without dereferencing freed objects")
	await process_frame
	await process_frame
	drone.queue_free()
	await process_frame
	await process_frame
	_expect(lights._drones.is_empty(), "source deletion unregisters beam lights synchronously")
	main.show_main_menu()
	_expect( not lights._running and lights._bullets.is_empty() and lights._drones.is_empty() and not glow.visible, "return clears all cached sources and XP illumination")
	await main._launch_run(&"lighting")
	_expect(main.game.gun_weapon.level == 3 and main.game.drone_controller.level == 3 and main.game._healing_actors.size() > 0, "real lighting Debug equips the intended attack and pickup examples")
	main.show_main_menu()
	if failures.is_empty(): print("COMBAT LIGHTING OK: fixed batches/shared texture/layers, real drone/gun behavior, stable beam points, bounded projectile/orb/muzzle storms, exact audible-pitch XP glow/no-op/gap/pause/progress, deletion/Debug/return")
	else:
		for message in failures: push_error(message)
	paused = false
	quit(0 if failures.is_empty() else 1)
