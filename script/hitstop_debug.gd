extends "res://script/motion_vfx_debug.gd"

var _next_target := false

func _ready() -> void:
	super._ready()
	game.ink_surf.debug_training = false
	game.ink_surf.clear_combat_effects()
	bomber.set_elite_status()
	_panel.get_child(0).text = "命中：白闪 + 短顿帧 · 受伤：淡红 + 较强顿帧\n按钮走真实伤害流程；左侧精英 / 右侧普通怪"
	replay_button.pressed.disconnect(replay)
	dash_button.pressed.disconnect(game.player.reset_dash)
	replay_button.text = "命中敌人 · 白色"
	dash_button.text = "玩家受击 · 淡红"
	replay_button.pressed.connect(strike_enemy)
	dash_button.pressed.connect(strike_player)

func strike_enemy() -> void:
	if not _running or not game.variety._battle_active(): return
	var victim: Node2D = bomber if _next_target else target
	_next_target = not _next_target
	victim.apply_hit({"damage":10.0,"direction":(victim.global_position-game.player.global_position).normalized(),"effect":"gun"})

func strike_player() -> void:
	if not _running or not game.variety._battle_active(): return
	game.player.receive_attack(10.0,target)

func _process(_delta: float) -> void:
	# No automatic throws in this opt-in comparison preset.
	if is_instance_valid(dash_button):
		dash_button.disabled = game.player.hurt_lock>0 or game.player.is_dash_invulnerable()
