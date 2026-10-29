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
@onready var hud_layer: CanvasLayer = $HudLayer
@onready var dash_cooldown_ring: Node2D = $HudLayer/DashCooldownRing
@onready var equipment_panel: Control = $HudLayer/EquipmentPanel
@onready var drone_controller: Node2D = $DroneController
@onready var molotov_controller: Node2D = $MolotovController
@onready var freeze_controller: Node2D = $FreezeController

var current_level: int = 1
signal game_over(stats: Dictionary)

func _ready() -> void:
	level_manager.signal_level_up.connect(on_level_up)
	pause_menu.upgrade_selected.connect(_on_upgrade_selected)
	player.player_died.connect(on_player_died)
	spawner.boss_defeated.connect(on_boss_defeated)
	if spawner.has_signal("stage_advanced"):
		spawner.stage_advanced.connect(_on_stage_advanced)
	if player.has_method("set_dash_cooldown_ui"):
		player.set_dash_cooldown_ui(dash_cooldown_ring)
	if equipment_panel and equipment_panel.has_method("reset_equipment"):
		equipment_panel.reset_equipment()
	_reset_skill_controllers()

func prepare_game() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	if level_ui:
		level_ui.hide()
	else:
		print(" level ui null")
	if spawner_ui:
		spawner_ui.hide()
	if hud_layer:
		hud_layer.hide()
	_reset_skill_controllers()

func start_game() -> void:
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	if level_ui:
		level_ui.show()
	if spawner_ui:
		spawner_ui.show()
	if hud_layer:
		hud_layer.show()
	if player.has_method("set_dash_cooldown_ui"):
		player.set_dash_cooldown_ui(dash_cooldown_ring)
	if equipment_panel and equipment_panel.has_method("reset_equipment"):
		equipment_panel.reset_equipment()
	_reset_skill_controllers()

func end_game() -> void:
	clear_run_objects()
	_reset_skill_controllers()
	process_mode = Node.PROCESS_MODE_DISABLED
	if level_ui:
		level_ui.hide()
	if spawner_ui:
		spawner_ui.hide()
	if hud_layer:
		hud_layer.hide()
	clear_enemies()
	hide()

func _reset_skill_controllers() -> void:
	if drone_controller and drone_controller.has_method("reset"):
		drone_controller.reset()
	if molotov_controller and molotov_controller.has_method("reset"):
		molotov_controller.reset()
	if freeze_controller and freeze_controller.has_method("reset"):
		freeze_controller.reset()

func clear_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("EnemyGroup"):
		if is_instance_valid(enemy):
			enemy.queue_free()

func _process(_delta: float) -> void:
	pass

func on_level_up(level: int) -> void:
	current_level = level
	spawner.handle_level_up(current_level)
	pause_menu.show_upgrade_options()

func _on_timer_timeout() -> void:
	pass

func _on_upgrade_selected(upgrade_id: String):
	match upgrade_id:
		"axe_up":
			hand_weapon.handle_level_up(current_level)
		"circle_up":
			circle_weapon.handle_level_up(current_level)
		"speed_up":
			player.speed_up(20)
		"gun_up":
			gun_weapon.upgrade()
		"pickup_up":
			player.pick_up_upgrade(1.2)
		"left_fist":
			player.upgrade_left_fist()
		"right_fist":
			player.upgrade_right_fist()
		"drone_up":
			drone_controller.upgrade()
		"molotov_up":
			molotov_controller.upgrade()
		"freeze_up":
			freeze_controller.upgrade()

	if equipment_panel and equipment_panel.has_method("apply_upgrade"):
		equipment_panel.apply_upgrade(upgrade_id)

func on_coin_collected(amount: int = 2) -> void:
	level_manager.add_coin(amount)

func on_player_died():
	Engine.time_scale = 1.0
	var stats := _build_run_stats(false)
	game_over.emit(stats)

func on_boss_defeated() -> void:
	Engine.time_scale = 1.0
	clear_enemies()
	var stats := _build_run_stats(true)
	game_over.emit(stats)

func _on_stage_advanced(next_stage: int) -> void:
	Engine.time_scale = 1.0
	var bg := get_node_or_null("InfiniteBackground")
	if bg != null and bg.has_method("set_stage_tint"):
		if next_stage >= 2:
			bg.set_stage_tint(Color(0.46, 0.2, 0.24, 1.0))
	if AudioManager.has_method("play_game_bgm"):
		AudioManager.play_game_bgm()

func _build_run_stats(victory: bool) -> Dictionary:
	var stage_num := 1
	if spawner != null and "stage" in spawner:
		stage_num = int(spawner.stage)
	return {
		"minutes": spawner.minute,
		"seconds": spawner.second,
		"kills": spawner.enemy_killed_num,
		"level": current_level,
		"stage": stage_num,
		"victory": victory
	}

func clear_container(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()

func clear_run_objects() -> void:
	clear_container(pickup_container)
	clear_container(effect_container)
