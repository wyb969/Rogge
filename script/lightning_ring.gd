extends Node2D

var level: = 0
var strike_left: = 0.0
var game: Node
var player: Node2D
var _audio: AudioStreamPlayer

static func stats_for(value: int) -> Dictionary:
	var rank: = maxi(1, value)
	return {"damage": 30.0 + 14.0 * (rank - 1), "bolts": rank + 1, "range": 180.0 + 24.0 * (rank - 1), "interval": 3.0}

func _ready() -> void :
	game = get_parent()
	player = game.get_node("Player")
	_audio = AudioStreamPlayer.new()
	AudioManager.configure_sfx(_audio)
	_audio.stream = preload("res://assest/sounds/lightning_ring.wav")
	_audio.volume_db = -13
	add_child(_audio)

func upgrade() -> void :
	level += 1
	if level == 1:
		strike_left = 0.35

func reset() -> void :
	level = 0
	strike_left = 0
	if is_instance_valid(_audio):
		_audio.stop()

func _can_attack() -> bool:
	if level <= 0 or get_tree().paused or not game.visible or not is_instance_valid(player) or player.player_health <= 0:
		return false
	if game.spawner._run_closed or game.spawner._transitioning:
		return false
	return not game.spawner._rest_open or game.trials.active_fight()

func _process(delta: float) -> void :
	if not _can_attack():
		return
	strike_left -= delta
	if strike_left <= 0:
		strike_left = stats_for(level).interval if strike() > 0 else 0.15

func targets_in_range() -> Array[Node2D]:
	var stats: = stats_for(level)
	return CombatTargets.nearest_visible(player.global_position, stats.range * stats.range, stats.bolts, game, get_viewport().get_visible_rect(), get_viewport().get_canvas_transform())

func strike() -> int:
	if not _can_attack():
		return 0
	var targets: = targets_in_range()
	if targets.is_empty():
		return 0
	var positions: Array[Vector2] = []
	var stats: = stats_for(level)
	for target in targets:
		positions.append(target.global_position)

		target.apply_hit({"damage": stats.damage, "direction": Vector2.ZERO, "effect": "lightning_ring", "source": self})
	game.show_lightning_strikes(positions, game.LIGHTNING_FX.VIOLET)
	_audio.play()
	return positions.size()
