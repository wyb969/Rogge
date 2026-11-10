extends Node2D

# Three bounded tides; this controller owns spawning, not an extra global spawner.
const DATA = [preload("res://resource/Enemy_1.tres"), preload("res://resource/Enemy2.tres")]
const CAPS = [32, 52, 72]
const INTERVALS = [0.55, 0.48, 0.38]
const BATCHES = [2, 3, 4]
var game: Node
var active := false
var wave := 0
var spawned := 0
var _spawn_left := 0.0
var _anchor := Vector2.ZERO
var _enemies: Array[WeakRef] = []
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	z_index = -1
	_rng.randomize()
	set_process(false)
	hide()

func begin(owner_game: Node) -> void:
	stop()
	game = owner_game
	_anchor = game.player.global_position
	global_position = _anchor
	active = true
	wave = 0
	spawned = 0
	_spawn_left = 0.25
	show()
	queue_redraw()

func _prune() -> void:
	var i := 0
	while i < _enemies.size():
		var actor = _enemies[i].get_ref()
		if not is_instance_valid(actor) or actor.is_queued_for_deletion() or actor._death_started:
			_enemies[i] = _enemies.back()
			_enemies.pop_back()
		else:
			i += 1

func advance(delta: float, seconds: float) -> void:
	if not active or get_tree().paused: return
	wave = mini(2, int(seconds / 20.0))
	_spawn_left -= delta
	if _spawn_left > 0.0: return
	_spawn_left = INTERVALS[wave]
	_prune()
	# A stalled frame never replays missed batches. At most four instances per update.
	for _i in mini(BATCHES[wave], maxi(0, CAPS[wave] - _enemies.size())):
		var actor: Node2D = game.spawner.enemy.instantiate()
		actor.set_player_ref(game.player)
		actor.set_enemy_data(DATA[spawned % DATA.size()])
		actor.setHealth((270.0 + wave * 130.0) * game.run_difficulty.health_scale)
		actor.defense = 0.04
		actor.contact_damage = 14.0 + wave * 4.0
		actor.contact_cooldown = 0.95
		actor.speed = 56.0 + wave * 14.0
		actor.add_to_group("EnemyGroup")
		actor.add_to_group("wooden_trial_enemy")
		actor.death_signal.connect(_on_enemy_killed.bind(actor))
		game.add_child(actor)
		var angle := _rng.randf_range(0, TAU)
		actor.global_position = _anchor + Vector2.from_angle(angle) * _rng.randf_range(235.0, 285.0)
		actor.reset_physics_interpolation()
		_enemies.append(weakref(actor))
		spawned += 1

func _on_enemy_killed(actor: Node2D) -> void:
	actor.remove_from_group("wooden_trial_enemy")
	game.spawner.on_enemy_killed(actor)

func stop() -> void:
	active = false
	for reference in _enemies:
		var actor = reference.get_ref()
		if not is_instance_valid(actor): continue
		actor.remove_from_group("EnemyGroup")
		actor.remove_from_group("wooden_trial_enemy")
		actor.set_physics_process(false)
		actor.queue_free()
	_enemies.clear()
	hide()

func alive_count() -> int:
	_prune()
	return _enemies.size()

func _draw() -> void:
	if not active: return
	# Local ground mark only: no particles, lights, or full-screen haze.
	draw_circle(Vector2.ZERO, 30, Color(0.04, 0.06, 0.07, 0.5))
	draw_arc(Vector2.ZERO, 32, 0, TAU, 40, Color(0.8, 0.64, 0.37, 0.7), 2.0, false)
	for i in 8:
		var direction := Vector2.from_angle(float(i) * TAU / 8.0)
		draw_line(direction * 35, direction * 41, Color(0.9, 0.77, 0.5, 0.7), 2, false)
