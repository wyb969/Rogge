extends Node2D
@onready var player: CharacterBody2D = $Player
@onready var level_manager: Node2D = $LevelManager
@onready var hand_weapon: Node2D = $HandWeapon
@onready var circle_weapon: Node2D = $CircleWeapon
@onready var pause_menu: CanvasLayer = $Node2D
@onready var gun_weapon: Node2D = $Weapon
@onready var level_ui = $LevelManager/UI
@onready var spawner_ui = $Spawner/UI
@onready var spawner: Node2D = $Spawner
@onready var pickup_container: Node2D = $PickupContainer
@onready var effect_container: Node2D = $EffectContainer

var current_level:int = 1
signal game_over(stats: Dictionary)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#level_manager.signal_level_up.connect(circle_weapon.handle_level_up)
	#level_manager.signal_level_up.connect(hand_weapon.handle_level_up)
	level_manager.signal_level_up.connect(on_level_up)
	pause_menu.upgrade_selected.connect(_on_upgrade_selected)
	player.player_died.connect(on_player_died)
	pass

func prepare_game() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	if level_ui:
		level_ui.hide()
	else:
		print(" level ui null")
	if spawner_ui:
		spawner_ui.hide()

func start_game() -> void:
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	if level_ui:
		level_ui.show()
	if spawner_ui:
		spawner_ui.show()

func end_game() -> void:
	clear_run_objects()
	process_mode = Node.PROCESS_MODE_DISABLED
	if level_ui:
		level_ui.hide()
	if spawner_ui:
		spawner_ui.hide()
	clear_enemies()
	hide()

func clear_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("EnemyGroup"):
		if is_instance_valid(enemy):
			enemy.queue_free()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func on_level_up(level:int) -> void:
	current_level = level
	spawner.handle_level_up(current_level)
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

		"gun_up":
			gun_weapon.upgrade()
			print("枪支升级")
		"pickup_up":
			player.pick_up_upgrade(1.2)
			print("拾取升级")

func on_coin_collected():
	level_manager.add_coin(1)

func on_player_died():
	print("player died")
	var stats := {
		"minutes":spawner.minute,
		"seconds": spawner.second,
		"kills": spawner.enemy_killed_num,
		"level": current_level
	}
	game_over.emit(stats)

func clear_container(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()

func clear_run_objects() -> void:
	#clear_container(enemy_container)
	clear_container(pickup_container)
	clear_container(effect_container)
