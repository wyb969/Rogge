extends SceneTree

var failures: Array[String] = []
func _init() -> void :
	call_deferred("_run")
func _run() -> void :
	var game: Node = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	game.spawner.timer.stop()
	game.spawner.get_node("Elite").stop()
	var books: Node = game.circle_weapon
	game.current_level = 12
	var previous_damage: = 0.0
	for card in range(50):
		game._on_upgrade_selected("circle_up")
		if books.num_weapons > 12:
			failures.append("book cards exceed the mobile-safe count at card %d: %d books" % [card + 1, books.num_weapons])
			break
		if books.get_child_count() > 12:
			failures.append("same-frame bonus cards leave multiple generations of book colliders alive")
			break
		var damage: float = books.get_child(0).weapon_demage
		if not is_finite(damage) or damage <= previous_damage:
			failures.append("later book cards must still improve damage after the count cap")
		previous_damage = damage
		if books.rotation_speed > 5.0:
			failures.append("book orbit speed compounds beyond readable limits")
	var ids: = []
	for book in books.get_children():
		ids.append(book.get_instance_id())
	if failures.is_empty():
		books.spawn_weapons()
		var after: = []
		for book in books.get_children():
			after.append(book.get_instance_id())
		if ids != after:
			failures.append("unchanged book count should reuse existing nodes")
	if failures.is_empty():
		print("BOOK GROWTH OK: fifty actual cards including same-frame stacks, bounded count/speed, increasing finite damage and stable collider reuse")
	else:
		for failure in failures:
			push_error(failure)
	quit(0 if failures.is_empty() else 1)
