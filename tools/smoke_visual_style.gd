extends SceneTree

var failures: Array[String] = []
func _init() -> void :
	call_deferred("_run")
func _run() -> void :
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	await main._launch_run(&"")
	var game: Node = main.game
	game.spawner.timer.stop()
	game.spawner.get_node("Elite").stop()
	game.player.set_physics_process(false)
	for name in ["HandWeapon", "CircleWeapon", "Weapon", "DroneController", "MolotovController", "FreezeController"]:
		game.get_node(name).process_mode = Node.PROCESS_MODE_DISABLED
	var values: Vector2 = game.get_node("InfiniteBackground")._shader_mat.get_shader_parameter("ground_values")
	_expect(values.x + values.y <= preload("res://script/visual_style.gd").GROUND_MAX_FACTOR + 0.0001, "actual ground shader stays within the contrast budget")
	var definitions: Dictionary = game.equipment_panel.EQUIP_DEFS
	var book: Node = game.circle_weapon.get_child(0)
	var card: Node = load("res://scenes/UpgradeCard.tscn").instantiate()
	game.add_child(card)
	card.setup({"id": "circle_up", "icon": definitions.circle_up.icon})
	var lottery: Node = load("res://script/treasure_lottery.gd").new()
	game.add_child(lottery)
	lottery._set_reel(0, {"id": "circle_up", "icon": definitions.circle_up.icon})
	var material: Material = book.get_node("Sprite2D").material
	_expect(material != null and material == card.icon.material and material == lottery._reels[0].material and material == game.equipment_panel._slots.circle_up.icon.material, "world, card, equipment and lottery share one parchment treatment")
	card.setup({"id": "axe_up", "icon": definitions.axe_up.icon})
	lottery._set_reel(0, {"id": "axe_up", "icon": definitions.axe_up.icon})
	_expect(card.icon.material == null and lottery._reels[0].material == null, "reused card/reel restores the next item's original art")
	var shape: RectangleShape2D = book.get_node("Area2D/CollisionShape2D").shape
	_expect(shape.size == Vector2(29, 29), "smaller book drawing preserves the existing collision footprint")
	book.setLevel(0, 1)
	var enemy: Node = load("res://scenes/enemy_shell.tscn").instantiate()
	game.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.health = 100
	book._on_area_2d_body_entered(enemy)
	_expect(enemy.health == 95 and enemy.burn_stacks > 0, "restyled books retain real base damage and burn")
	var marker: Node = game.player.get_node("player_ring")
	var collider_scale: Vector2 = game.player.scale
	game.player.play_ring_tween()
	game.player.play_ring_tween()
	_expect(marker.texture == null and marker.scale == Vector2.ONE and game.player.scale == collider_scale, "repeated marker refresh stays flat without scaling the player collider")
	game.player.player_health = game.player.max_player_health - 100
	var health: float = game.player.player_health
	game.player.monster_necklace_level = 1
	var orb_a: Node = game.spawn_necklace_orb(Vector2(1000, 0))
	game.player.monster_necklace_level = 2
	var orb_b: Node = game.spawn_necklace_orb(Vector2(1100, 0))
	orb_a.set_physics_process(false)
	orb_b.set_physics_process(false)
	_expect(orb_a._halo.material == orb_b._halo.material and orb_a._halo.texture == orb_b._halo.texture, "quieter pickup art still shares GPU resources")
	_expect(orb_a._halo.material.blend_mode == CanvasItemMaterial.BLEND_MODE_MIX, "overlapping healing pickups cannot add bright light together")
	var gained: float = orb_a.collect() + orb_b.collect()
	_expect(is_equal_approx(gained, 15) and is_equal_approx(game.player.player_health, health + 15), "flat pickup styling preserves rank-based healing exactly")
	game.end_game()
	await process_frame
	await process_frame
	_expect(get_nodes_in_group("healing_orb").is_empty(), "restyled pickups leave no active run actors after teardown")
	if failures.is_empty(): print("VISUAL STYLE OK: shared world/card/equipment/reel palette, safe icon reuse, unchanged book collision/damage/burn, fixed footprint, shared non-additive pickups and exact healing")
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
func _expect(ok: bool, message: String) -> void :
	if not ok: failures.append(message)
