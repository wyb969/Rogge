extends Node

var game: Node
var coins_left: = 0
var _left: = 0.0
var _buttons: HBoxContainer
func _ready() -> void :
	game = get_parent()
	add_to_group("diagnostic_ui")
	var layer: = CanvasLayer.new()
	layer.layer = 95
	add_child(layer)
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 12)
	layer.add_child(_buttons)
	for text in ["再来一次连击", "返回主页"]:
		var button: = Button.new()
		button.text = text
		_buttons.add_child(button)
	_buttons.get_child(0).pressed.connect(restart)
	_buttons.get_child(1).pressed.connect( func(): get_tree().current_scene.show_main_menu())
	get_viewport().size_changed.connect(_fit)
	_fit()
	restart()
func restart() -> void :
	game.level_manager.level_need_coin_number = 320
	game.level_manager.coin_number = 80
	game.level_manager.reset_feedback()
	coins_left = 32
	_left = 0.5
	set_process(true)
func _process(delta: float) -> void :
	if get_tree().paused: return
	_left -= delta
	if _left > 0: return
	var before: int = game._xp_actors.size()
	game._spawn_xp_coin_now(game.player.global_position + Vector2(14, 0), 2)
	if game._xp_actors.size() > before:
		var coin: Node = game._xp_actors.back()
		coin.player_body = game.player
		coin.start_pickup()
	coins_left -= 1
	_left += 0.09
	if coins_left <= 0: set_process(false)
func stop() -> void :
	_buttons.hide()
	set_process(false)
	queue_free()
func owns_pointer(point: Vector2) -> bool:
	for button in _buttons.get_children():
		if button.get_global_rect().has_point(point): return true
	return false
func _fit() -> void :
	var vp: = get_viewport().get_visible_rect().size
	var portrait: = vp.y > vp.x
	var width: = minf(700, vp.x - 40)
	var height: = 96.0 if portrait else 48.0
	_buttons.position = Vector2((vp.x - width) * 0.5, vp.y - height - 20)
	for button in _buttons.get_children():
		button.custom_minimum_size = Vector2((width - 12) * 0.5, height)
		UiFonts.apply_to_button(button, 24 if portrait else 16)
