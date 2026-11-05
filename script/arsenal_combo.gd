extends Node2D

const MEMBERS: Array[String] = ["gun_up", "drone_up", "bomb"]
const CYCLE_SECONDS := 3.0
const SHIELD_SECONDS := 1.0
const STYLE := preload("res://script/visual_style.gd")
var unlocked := false
var owned_count := 0
var pulses := 0
var shield_left := 0.0
var _elapsed := 0.0
var _ui_left := 0.0
var _audio: AudioStreamPlayer
var _hex := PackedVector2Array()
var _hex_fill := PackedVector2Array()
@onready var game: Node = get_parent()

func _ready() -> void:
	z_index = 12
	for i in 6: _hex_fill.append(Vector2.from_angle(-PI * 0.5 + float(i) * TAU / 6.0) * 24.0)
	_hex = _hex_fill.duplicate()
	_hex.append(_hex[0])
	_audio = AudioStreamPlayer.new()
	AudioManager.configure_sfx(_audio)
	_audio.stream = preload("res://assest/sounds/arsenal_shield.wav")
	_audio.volume_db = -19.0
	_audio.max_polyphony = 1
	add_child(_audio)
	reset()

func reset() -> void:
	clear_combat_effects()
	unlocked = false
	owned_count = 0
	pulses = 0
	_update_hud()
	set_physics_process(false)

func refresh_equipment() -> void:
	owned_count = 0
	for id in MEMBERS:
		if game.equipment_panel.get_level(id) > 0: owned_count += 1
	var complete := owned_count == MEMBERS.size()
	if complete != unlocked:
		clear_combat_effects()
		unlocked = complete
		if unlocked: game.variety.notify("军械护盾组合已激活\n每3秒获得1秒无敌 · 无人机 + 枪支 + 炸弹")
	set_physics_process(unlocked)
	_update_hud()

func clear_combat_effects() -> void:
	_elapsed = 0.0
	shield_left = 0.0
	_ui_left = 0.0
	if is_instance_valid(game.player): game.player.arsenal_shield_active = false
	if _audio != null: _audio.stop()
	_update_hud()
	queue_redraw()

func _update_hud() -> void:
	if is_instance_valid(game.equipment_panel):
		game.equipment_panel.set_arsenal_status(owned_count, shield_left > 0.0, shield_left if shield_left > 0 else CYCLE_SECONDS - _elapsed)

func _physics_process(delta: float) -> void:
	if not unlocked or get_tree().paused: return
	global_position = game.player.global_position
	if not game.variety._battle_active():
		if _elapsed > 0.0 or shield_left > 0.0: clear_combat_effects()
		return
	var was_active := shield_left > 0.0
	shield_left = maxf(0.0, shield_left - delta)
	if shield_left < 0.000001: shield_left = 0.0
	_elapsed += delta
	if _elapsed >= CYCLE_SECONDS - 0.000001:
		_elapsed = fmod(maxf(0.0, _elapsed - CYCLE_SECONDS), CYCLE_SECONDS)
		# Overshoot consumes elapsed shield time; a long frame cannot grant a fresh stale second.
		shield_left = maxf(0.0, SHIELD_SECONDS - _elapsed)
		pulses += 1
		if shield_left > 0.0: _audio.play()
	game.player.arsenal_shield_active = shield_left > 0.0
	_ui_left -= delta
	if _ui_left <= 0.0 or was_active != (shield_left > 0.0):
		_ui_left = 1.0 / 20.0
		_update_hud()
		queue_redraw()

func _draw() -> void:
	if not unlocked or not game.variety._battle_active(): return
	var at: Vector2 = to_local(game.player.global_position)
	if shield_left <= 0.0:
		draw_arc(at, 21.0, -PI * 0.5, -PI * 0.5 + TAU * _elapsed / CYCLE_SECONDS, 28, Color(STYLE.FRIENDLY, 0.28), 1.0, false)
		return
	var envelope := minf(1.0, (SHIELD_SECONDS - shield_left) / 0.09) * minf(1.0, shield_left / 0.16)
	draw_set_transform(at, 0.0, Vector2.ONE * lerpf(0.92, 1.0, envelope))
	draw_colored_polygon(_hex_fill, Color(STYLE.FRIENDLY, 0.055 * envelope))
	draw_polyline(_hex, Color(STYLE.INK, 0.7 * envelope), 4.0, false)
	draw_polyline(_hex, Color(STYLE.FRIENDLY, 0.95 * envelope), 2.0, false)
	draw_arc(Vector2.ZERO, 28.0, -PI * 0.5, -PI * 0.5 + TAU * shield_left / SHIELD_SECONDS, 28, Color(0.86, 0.96, 0.94, envelope * 0.7), 1.2, false)
	draw_set_transform(Vector2.ZERO)
