extends Node2D

@export var weapon_scene: PackedScene
@export var num_weapons: = 3
@export var radius: = 40.0
@export var rotation_speed: = 1.0
@export var player: CharacterBody2D
const MAX_WEAPONS: = 12
const MAX_ROTATION_SPEED: = 5.0
var current_level: = 0
var card_level: = 1
var _base_count: = 3
var _base_rotation: = 1.0

func _ready() -> void :
	_base_count = clampi(num_weapons, 1, MAX_WEAPONS)
	_base_rotation = rotation_speed
	spawn_weapons()

func spawn_weapons() -> void :
	num_weapons = clampi(num_weapons, 1, MAX_WEAPONS)
	while get_child_count() > num_weapons:
		var excess: = get_child(get_child_count() - 1)
		remove_child(excess)
		excess.queue_free()
	while get_child_count() < num_weapons:
		add_child(weapon_scene.instantiate())
	for i in range(get_child_count()):
		var book: = get_child(i) as Node2D
		book.position = Vector2.RIGHT.rotated(TAU * i / num_weapons) * radius
		book.setLevel(current_level, card_level)

func _process(delta: float) -> void :
	if not is_instance_valid(player):
		return
	rotation = fposmod(rotation + rotation_speed * delta, TAU)
	global_position = player.global_position

func handle_level_up(character_level: int) -> void :
	card_level += 1
	current_level = maxi(current_level, character_level)
	num_weapons = mini(_base_count + card_level - 1, MAX_WEAPONS)
	rotation_speed = minf(_base_rotation * (1.0 + 0.1 * (card_level - 1)), MAX_ROTATION_SPEED)
	spawn_weapons()
