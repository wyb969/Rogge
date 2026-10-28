extends Node2D

@export var player: CharacterBody2D
@export var drone_scene: PackedScene

var level: int = 0
var summon_timer: float = 0.0
var active_drones: Array[Node] = []

func upgrade() -> void:
	level += 1
	# Immediately refresh a pack on upgrade so the player feels the power spike.
	_summon_wave()

func reset() -> void:
	level = 0
	summon_timer = 0.0
	_clear_drones()

func _process(delta: float) -> void:
	if level <= 0:
		return
	if not is_instance_valid(player):
		return
	_prune_drones()
	summon_timer -= delta
	if summon_timer <= 0.0:
		_summon_wave()

func _summon_wave() -> void:
	if level <= 0 or drone_scene == null or not is_instance_valid(player):
		return
	_prune_drones()
	var want := get_drone_count()
	var need := want - active_drones.size()
	if need <= 0:
		summon_timer = get_respawn_interval()
		return

	var base_angle := randf() * TAU
	for i in range(need):
		var drone: Node2D = drone_scene.instantiate()
		var container := get_tree().get_first_node_in_group("effect_container")
		if container:
			container.add_child(drone)
		else:
			get_tree().current_scene.add_child(drone)
		drone.setup(
			player,
			get_damage(),
			get_fire_cd(),
			get_lifetime(),
			base_angle + TAU * float(i) / float(want)
		)
		active_drones.append(drone)

	summon_timer = get_respawn_interval()

func _prune_drones() -> void:
	active_drones = active_drones.filter(func(d): return is_instance_valid(d))

func _clear_drones() -> void:
	for d in active_drones:
		if is_instance_valid(d):
			d.queue_free()
	active_drones.clear()

func get_lifetime() -> float:
	# Lv1 7s → grows with level
	return 6.0 + float(level) * 1.6

func get_fire_cd() -> float:
	# Cooldown between laser bursts.
	return maxf(0.28, 0.95 - float(level) * 0.08)

func get_damage() -> float:
	# Per laser tick while the beam is active.
	return 4.5 + float(level) * 3.2

func get_drone_count() -> int:
	return 1 + int((level - 1) / 3)

func get_respawn_interval() -> float:
	# After drones expire, wait a bit then resummon. Higher level = faster recall.
	return maxf(2.5, 7.0 - float(level) * 0.55)
