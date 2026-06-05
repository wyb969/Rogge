extends Node2D
@onready var player: CharacterBody2D = $Player
@onready var level_manager: Node2D = $LevelManager
@onready var hand_weapon: Node2D = $HandWeapon
@onready var circle_weapon: Node2D = $CircleWeapon
@onready var pause_menu: CanvasLayer = $Node2D
var current_level:int = 1

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#level_manager.signal_level_up.connect(circle_weapon.handle_level_up)
	#level_manager.signal_level_up.connect(hand_weapon.handle_level_up)
	level_manager.signal_level_up.connect(on_level_up)
	pause_menu.upgrade_selected.connect(_on_upgrade_selected)
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func on_level_up(level:int) -> void:
	current_level = level
	pause_menu.show_upgrade_options()

func _on_timer_timeout() -> void:
	pass

func _on_upgrade_selected(upgrade_id: String):
	match upgrade_id:
		"axe_up":
			hand_weapon.handle_level_up(current_level)
			print("斧头升级")

		"circle_up":
			circle_weapon.handle_level_up(current_level)
			print("书本升级")

		"speed_up":
			player.speed_up(20)
			print("移速升级")

func on_coin_collected():
	level_manager.add_coin(1)
