extends Node2D

const COURIER: = preload("res://scenes/loot_courier.tscn")
const COURIER_DATA: = preload("res://resource/LootCourier.tres")
const MAX_PULSES: = 8
var wind_level: = 0
var echo_level: = 0
var echo_charge: = 0
var _last_kill_at: = Vector2.ZERO
var pulses_cast: = 0
var couriers_defeated: = 0
var _running: = false
var _generation: = 0
var _in_echo: = false
var _pending_echoes: Array[Vector2] = []
var _courier: WeakRef
var _courier_left: = 35.0
var _rng: = RandomNumberGenerator.new()
var _pulses: Array[Dictionary] = []
var _slot: = 0
var _redraw_left: = 0.0
var _notice_left: = 0.0
var _notice: Label
var _charge_label: Label
var _hud: CanvasLayer
@onready var game: Node = get_parent()

static func wind_stats(rank: int) -> Dictionary:
	return {"damage": 32.0 + 16.0 * maxi(rank - 1, 0), "radius": minf(100 + 8 * maxi(rank - 1, 0), 172)}

static func echo_stats(rank: int) -> Dictionary:
	return {"damage": 40.0 + 18.0 * maxi(rank - 1, 0), "radius": minf(112 + 8 * maxi(rank - 1, 0), 176), "kills": maxi(5, 9 - rank)}

func _ready() -> void :
	z_index = 8
	_rng.randomize()
	for _i in MAX_PULSES: _pulses.append({"at": Vector2.ZERO, "radius": 0.0, "left": 0.0, "wind": false})
	_hud = CanvasLayer.new()
	_hud.layer = 51
	add_child(_hud)
	_notice = Label.new()
	_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice.add_theme_color_override("font_color", Color(0.68, 1, 0.94))
	_notice.add_theme_color_override("font_outline_color", Color(0.02, 0.035, 0.06))
	_notice.add_theme_constant_override("outline_size", 3)
	_hud.add_child(_notice)
	_charge_label = Label.new()
	_charge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_charge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_charge_label.add_theme_color_override("font_color", Color(1, 0.79, 0.56))
	_charge_label.add_theme_color_override("font_outline_color", Color(0.02, 0.035, 0.06))
	_charge_label.add_theme_constant_override("outline_size", 3)
	_hud.add_child(_charge_label)
	get_viewport().size_changed.connect(_fit)
	_fit()
	reset()

func _fit() -> void :
	var vp: = get_viewport().get_visible_rect().size
	var ui_scale: = 2 if vp.y > vp.x else 1
	UiFonts.apply_to_label(_notice, 16 * ui_scale, true)
	_notice.position = Vector2(vp.x * 0.14, 84 * ui_scale)
	_notice.size = Vector2(vp.x * 0.72, 64 * ui_scale)
	UiFonts.apply_to_label(_charge_label, 12 * ui_scale)
	_charge_label.position = Vector2(vp.x * 0.25, 84 * ui_scale)
	_charge_label.size = Vector2(vp.x * 0.5, 24 * ui_scale)

func reset() -> void :
	_generation += 1
	_running = false
	wind_level = 0
	echo_level = 0
	echo_charge = 0
	_last_kill_at = Vector2.ZERO
	pulses_cast = 0
	couriers_defeated = 0
	_in_echo = false
	_pending_echoes.clear()
	for pulse in _pulses: pulse.left = 0.0
	if _courier != null:
		var actor: Object = _courier.get_ref()
		if is_instance_valid(actor): actor.queue_free()
	_courier = null
	_notice_left = 0
	_refresh_charge()
	_hud.hide()
	queue_redraw()
	set_process(false)

func begin_run() -> void :
	reset()
	_running = true
	_courier_left = _rng.randf_range(28, 42)
	_hud.show()
	_notice.hide()
	set_process(true)

func _battle_active() -> bool:
	if not _running or get_tree().paused or not game.visible or game.process_mode == Node.PROCESS_MODE_DISABLED or game.player.player_health <= 0: return false


	if game.trials.active_fight(): return true
	return not game.spawner._rest_open and not game.spawner._transitioning and not game.trials.blocks_rewards()

func upgrade(id: String) -> void :
	if id == "wind_emblem": wind_level += 1
	if id == "echo_ember":
		echo_level += 1


		if echo_charge >= int(echo_stats(echo_level).kills):
			echo_charge = 0
			_pending_echoes.append(_last_kill_at)
	_refresh_charge()

func _refresh_charge() -> void :
	_charge_label.text = "回响火种  %d / %d" % [echo_charge, int(echo_stats(echo_level).kills)] if echo_level > 0 else ""
	_charge_label.visible = echo_level > 0 and _notice_left <= 0

func clear_combat_effects() -> void :
	if game.get("enemy_attacks")!=null: game.enemy_attacks.clear_combat_effects()
	if game.get("ink_surf")!=null: game.ink_surf.clear_combat_effects()
	if game.get("combat_feedback") != null and game.combat_feedback.death_stains != null:
		game.combat_feedback.death_stains.reset()
	if game.get("burn_spread") != null: game.burn_spread.reset()
	if game.get("combat_lighting") != null: game.combat_lighting.clear_flashes()
	if game.get("meteors") != null: game.meteors.clear_combat_effects()
	if game.get("poison_trail") != null: game.poison_trail.clear_combat_effects()
	if game.get("banana_fan") != null: game.banana_fan.clear_combat_effects()
	if game.get("black_hole") != null: game.black_hole.clear_combat_effects()
	if game.get("bomb_controller") != null: game.bomb_controller.clear_combat_effects()
	if game.get("arsenal_combo") != null: game.arsenal_combo.clear_combat_effects()
	_pending_echoes.clear()
	for pulse in _pulses: pulse.left = 0.0
	queue_redraw()

func notify(text_value: String) -> void :
	_notice.text = text_value
	_notice_left = 3.3
	_notice.modulate.a = 1
	_notice.show()
	_charge_label.hide()

func _process(delta: float) -> void :
	if not _running or get_tree().paused: return
	if _notice_left > 0:
		_notice_left = maxf(0, _notice_left - delta)
		_notice.modulate.a = minf(1, _notice_left / 0.5)
		if _notice_left <= 0:
			_notice.hide()
			_refresh_charge()
	var was_visible: = false
	for pulse in _pulses:
		if pulse.left > 0:
			was_visible = true
			pulse.left = maxf(0, pulse.left - delta)
	_redraw_left -= delta
	if was_visible and _redraw_left <= 0:
		_redraw_left = 1.0 / 30
		queue_redraw()
	if not _battle_active(): return


	for _i in mini(2, _pending_echoes.size()): _release_echo(_pending_echoes.pop_front(), _generation)
	if game.spawner._boss_fight_active or game.spawner._endless_trial or game.trials.blocks_rewards(): return
	if game.diagnostic_mode not in ["normal", "variety"]: return
	_courier_left -= delta
	if _courier_left <= 0:
		spawn_courier()
		_courier_left = _rng.randf_range(48, 68)

func on_dash_completed(at: Vector2) -> void :
	if wind_level <= 0 or not _battle_active(): return
	var stats: = wind_stats(wind_level)
	_hit_area(at, stats, true)

func note_kill(actor: Node2D) -> void :
	if echo_level <= 0 or _in_echo or not _battle_active() or not is_instance_valid(actor): return
	_last_kill_at = actor.global_position
	echo_charge += 1
	if echo_charge >= int(echo_stats(echo_level).kills):
		echo_charge = 0
		_pending_echoes.append(actor.global_position)
	_refresh_charge()

func _release_echo(at: Vector2, generation: int) -> void :
	if generation != _generation or echo_level <= 0 or not _battle_active(): return
	_in_echo = true
	_hit_area(at, echo_stats(echo_level), false)
	_in_echo = false

func _hit_area(at: Vector2, stats: Dictionary, wind: bool) -> void :
	pulses_cast += 1
	var pulse: = _pulses[_slot]
	pulse.at = at
	pulse.radius = stats.radius
	pulse.left = 0.32
	pulse.wind = wind
	_slot = (_slot + 1) % MAX_PULSES
	queue_redraw()
	for actor in CombatTargets.in_radius(at, stats.radius * stats.radius, game):
		actor.apply_hit({"damage": stats.damage, "direction": (actor.global_position - at).normalized(), "effect": "wind_emblem" if wind else "echo_ember", "source": self})
	game.combat_feedback.spray(at, Vector2.ZERO, Color(0.5, 1, 0.95) if wind else Color(1, 0.68, 0.4), 8, 68)
	AudioManager.play_juice("dash" if wind else "kill")

func spawn_courier() -> Node2D:
	var old: Object = _courier.get_ref() if _courier != null else null
	if not _battle_active() or game.spawner._boss_fight_active or game.spawner._endless_trial or game.trials.blocks_rewards() or is_instance_valid(old): return null
	var actor: Node2D = COURIER.instantiate()
	actor.set_player_ref(game.player)
	actor.set_enemy_data(COURIER_DATA)
	actor.health *= (1 + 0.12 * (game.spawner.stage - 1) + 0.03 * game.current_level) * game.run_difficulty.health_scale
	actor.death_signal.connect(game.spawner.on_enemy_killed.bind(actor))

	var half: Vector2 = get_viewport().get_visible_rect().size / game.player.get_node("Camera2D").zoom * 0.5
	var direction: = Vector2.from_angle(_rng.randf_range(0, TAU))
	var reach: = minf(210, minf(half.x, half.y) * 0.7)
	game.add_child(actor)
	actor.global_position = game.player.global_position + direction * maxf(reach, 110)
	_courier = weakref(actor)
	notify("宝囊精出现！追上它获得经验和重抽次数")
	AudioManager.play_juice("ready")
	RunDiagnostics.mark("courier_spawn", {"stage": game.spawner.stage})
	return actor

func reward_courier(at: Vector2) -> void :
	if not _battle_active(): return
	couriers_defeated += 1
	var added: bool = game.pause_menu.grant_reroll()
	game.spawn_xp_coin(at, 14 + 4 * game.spawner.stage + (0 if added else 8))
	game.combat_feedback.reward(at)
	AudioManager.play_upgrade()
	notify("截获宝囊！经验 + 重抽 1 次" if added else "截获宝囊！重抽已满，转为额外经验")
	RunDiagnostics.mark("courier_defeated", {"reroll_added": added})

func _draw() -> void :
	for pulse in _pulses:
		if pulse.left <= 0: continue
		var alpha: float = pulse.left / 0.32
		var tint: = Color(0.45, 1, 0.91) if pulse.wind else Color(1, 0.65, 0.38)
		var at: Vector2 = to_local(pulse.at)

		draw_arc(at, pulse.radius, 0, TAU, 40, Color(tint, alpha * 0.3), 1.0, false)
		draw_arc(at, pulse.radius * (1 - alpha * 0.7), 0, TAU * 0.8, 28, Color(tint, alpha * 0.65), 1.5, false)
		for i in 3:
			var dir: = Vector2.from_angle(float(i) * TAU / 3)
			draw_line(at + dir * pulse.radius * 0.82, at + dir * pulse.radius, Color(tint, alpha * 0.6), 1, false)
