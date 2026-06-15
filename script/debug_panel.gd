extends CanvasLayer
@onready var debug_label: Label = $PanelContainer/DebugLabel
@onready var level_manager: Node2D = $"../LevelManager"
@onready var spawner: Node2D = $"../Spawner"

@export var player:Node
@export var enemy_group_name:="EnemyGroup"

func _ready() -> void:
	visible = false

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("Debug"):
		visible = !visible

	if visible:
		update_text()

func update_text()->void:
	if player == null:
		return

	var enemy_count := get_tree().get_nodes_in_group(enemy_group_name).size()

	debug_label.text = \
		"DEBUG\n" + \
		"Level: %s\n" % level_manager.level + \
		"HP: %s / %s\n" % [player.player_health, player.max_player_health] + \
		"MoveSpeed: %s\n" % player.SPEED + \
		"Enemy Killed: %s\n" % spawner.enemy_killed_num + \
		"Enemy Alive: %s\n" % enemy_count
