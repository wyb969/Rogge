extends Node

# Opt-in presentation sandbox. Uses the real bomb, mortar and Ink Surf controllers.
var game: Node
var target: Node2D
var bomber: Node2D
var replay_button: Button
var dash_button: Button
var _panel: VBoxContainer
var _layer: CanvasLayer
var _left := 0.4
var _running := true

func _ready() -> void:
	game = get_parent()
	add_to_group("diagnostic_ui")
	game.spawner.timer.stop()
	game.spawner.get_node("Elite").stop()
	game.spawner.set_process(false)
	game.weather.stop()
	game.meteors.set_process(false)
	game.variety._courier_left = 99999
	for path in ["HandWeapon","CircleWeapon","Weapon","DroneController","MolotovController","FreezeController"]:
		game.get_node(path).process_mode = Node.PROCESS_MODE_DISABLED
	game._on_upgrade_selected("bomb")
	game.bomb_controller._cooldown = 99999
	game.ink_surf.enable_debug_training()
	game.ink_surf.charge = 1
	target = _actor("Enemy_1", Vector2(145,10))
	bomber = _actor("SporeBomber", Vector2(-195,-30))
	bomber.projectile_damage = 0 # Harmless practice; normal presets retain real damage.
	_layer = CanvasLayer.new()
	_layer.layer = 105
	add_child(_layer)
	_panel = VBoxContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_panel)
	var caption := Label.new()
	caption.text = "纵向移动看彩墨 · 冲刺看残影\n左侧敌方投弹 / 右侧玩家投弹（无伤练习）"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.add_theme_color_override("font_color",GamePalette.UI_TEXT)
	caption.add_theme_color_override("font_outline_color",GamePalette.BLACK)
	caption.add_theme_constant_override("outline_size",3)
	_panel.add_child(caption)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(row)
	for title in ["重放投弹", "重置冲刺"]:
		var button := Button.new()
		button.text = title
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for state in ["normal","hover","pressed","focus"]:
			button.add_theme_stylebox_override(state,GamePalette.surface(GamePalette.UI_BUTTON,GamePalette.UI_BORDER))
		row.add_child(button)
	replay_button = row.get_child(0)
	dash_button = row.get_child(1)
	replay_button.pressed.connect(replay)
	dash_button.pressed.connect(game.player.reset_dash)
	get_viewport().size_changed.connect(_fit)
	_fit()

func _actor(resource_name: String, offset: Vector2) -> Node2D:
	var actor: Node2D = game.spawner.enemy.instantiate()
	actor.set_enemy_data(load("res://resource/%s.tres" % resource_name))
	actor.set_player_ref(game.player)
	actor.add_to_group("EnemyGroup")
	actor.death_signal.connect(game.spawner.on_enemy_killed.bind(actor))
	game.add_child(actor)
	actor.global_position = game.player.global_position + offset
	actor.health = 100000
	actor.set_physics_process(false)
	return actor

func replay() -> void:
	if not _running or not game.variety._battle_active(): return
	game.enemy_attacks.clear_combat_effects()
	game.bomb_controller.clear_combat_effects()
	# Recenter existing actors rather than allocating another wave on every replay.
	target.global_position = game.player.global_position + Vector2(145,10)
	bomber.global_position = game.player.global_position + Vector2(-195,-30)
	target.clear_blast_impulse()
	bomber.clear_blast_impulse()
	game.bomb_controller.cast()
	game.bomb_controller._cooldown = 99999
	var mortar = game.enemy_attacks.cast(bomber,&"mortar")
	# Land below the hero so the warning does not obscure the underfoot HUD.
	if mortar != null: mortar.target += Vector2(0,90)
	_left = 2.0

func _process(delta: float) -> void:
	if not _running or get_tree().paused or not game.variety._battle_active(): return
	_left -= delta
	if _left <= 0: replay()
	if game.ink_surf.charge == 0 and game.ink_surf.cooldown <= 0 and not game.player.dashing:
		game.ink_surf.charge = 1

func owns_pointer(point: Vector2) -> bool:
	return _running and (replay_button.get_global_rect().has_point(point) or dash_button.get_global_rect().has_point(point))

func stop() -> void:
	_running = false
	_layer.hide()
	set_process(false)

func _fit() -> void:
	var vp := get_viewport().get_visible_rect().size
	var physical := get_viewport().get_final_transform().get_scale().x
	var ratio := 1.0
	if OS.has_feature("web"):
		var css: Variant = JavaScriptBridge.eval("document.getElementById('canvas').getBoundingClientRect().width",true)
		if (css is float or css is int) and float(css) > 0:
			ratio = float(get_tree().root.size.x) / float(css)
	var ui := ratio / maxf(physical,0.1)
	_panel.position = Vector2((vp.x-minf(330*ui,vp.x-16*ui))*0.5,90*ui)
	_panel.size.x = minf(330*ui,vp.x-16*ui)
	UiFonts.apply_to_label(_panel.get_child(0),int(11*ui),true)
	for button in [replay_button,dash_button]:
		button.custom_minimum_size = Vector2(0,40*ui)
		UiFonts.apply_to_button(button,int(13*ui))
