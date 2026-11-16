extends Node2D
# An optional movement reward, independent of weapons, damage and card balance.
const ENEMY := preload("res://script/enemy_shell.gd")
const REQUIRED := 18
const ROUTE_SECONDS := 8.0
const FEVER_SECONDS := 5.0
const REST_SECONDS := 35.0
const PICK_RADIUS := 24.0
const MAGNET_RADIUS := 180.0
const MAX_MAGNET_BATCH := 12
var _star_unit := PackedVector2Array([Vector2(0,-1),Vector2(0.226,-0.226),Vector2(1,0),Vector2(0.226,0.226),Vector2(0,1),Vector2(-0.226,0.226),Vector2(-1,0),Vector2(-0.226,-0.226)])
var _draw_visible := false
var charge := 0
var step := 0
var route_left := 0.0
var fever_left := 0.0
var cooldown := 0.0
var completed := 0
var stars_collected := 0
var magnet_started := 0
var _running := false
var _points := PackedVector2Array()
var _seen: Dictionary = {}
var _last_at := Vector2.ZERO
var _clock := 0.0
var _burst_at := Vector2.ZERO
var _burst_left := 0.0
var _magnet_left := 0.0
var _scan_cursor := 0
var _rng := RandomNumberGenerator.new()
var _hud: CanvasLayer
var _label: Label
var _bar: ProgressBar
var _notes: Array[float] = []
var _note_left := 0.0
var _audio: AudioStreamPlayer
var _debug_button: Button
var debug_training := false
@onready var game: Node = get_parent()

func _ready() -> void:
	z_index = 9
	_rng.randomize()
	_points.resize(3)
	_audio = AudioStreamPlayer.new()
	AudioManager.configure_sfx(_audio)
	_audio.stream = AudioManager.pick_coin_audio_player.stream
	_audio.volume_db = -21
	_audio.max_polyphony = 1
	add_child(_audio)
	_hud = CanvasLayer.new()
	_hud.layer = 52
	add_child(_hud)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_color_override("font_color", GamePalette.PLAYER_CYAN)
	_label.add_theme_color_override("font_outline_color", GamePalette.BLACK)
	_label.add_theme_constant_override("outline_size", 3)
	_hud.add_child(_label)
	_bar = ProgressBar.new()
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.show_percentage = false
	_bar.max_value = 1.0
	_bar.step = 0.001
	var track := StyleBoxFlat.new()
	track.bg_color = Color(GamePalette.UI_GREY_DARK, 0.8)
	var fill := StyleBoxFlat.new()
	fill.bg_color = GamePalette.PLAYER_CYAN
	_bar.add_theme_stylebox_override("background", track)
	_bar.add_theme_stylebox_override("fill", fill)
	_hud.add_child(_bar)
	get_viewport().size_changed.connect(_fit)
	_fit()
	reset()

func _fit() -> void:
	var vp := get_viewport().get_visible_rect().size
	var ui: float=preload("res://script/boss_hud_layout.gd").display_scale(self)
	UiFonts.apply_to_label(_label, int(12 * ui), true)
	_label.position = Vector2(vp.x-64*ui,94*ui)
	_label.size = Vector2(48*ui,20*ui)
	_label.pivot_offset = _label.size * 0.5
	var width := minf(vp.x * 0.4, 200 * ui)
	_bar.position = Vector2((vp.x - width) * 0.5, 198 * ui)
	_bar.size = Vector2(width, 3 * ui)
	if _debug_button != null:
		_debug_button.position = Vector2((vp.x - 180 * ui) * 0.5, vp.y - 72 * ui)
		_debug_button.size = Vector2(180 * ui, 48 * ui)
		UiFonts.apply_to_button(_debug_button, int(14 * ui))

func reset() -> void:
	_running = false
	debug_training = false
	if is_in_group("diagnostic_ui"): remove_from_group("diagnostic_ui")
	if _debug_button: _debug_button.hide()
	completed = 0
	stars_collected = 0
	magnet_started = 0
	cooldown = 0
	_clock = 0
	clear_combat_effects()
	set_physics_process(false)
	set_process(false)

func begin_run() -> void:
	reset()
	_running = true
	_last_at = game.player.global_position
	set_physics_process(true)
	set_process(true)

func clear_combat_effects() -> void:
	if route_left > 0 or fever_left > 0: cooldown = maxf(cooldown, REST_SECONDS)
	charge = 0
	step = 0
	route_left = 0
	fever_left = 0
	_burst_left = 0
	_seen.clear()
	if is_instance_valid(game.player): _last_at = game.player.global_position
	_notes.clear()
	_note_left = 0
	if _audio: _audio.stop()
	if _hud: _hud.hide()
	queue_redraw()

func _eligible() -> bool:
	return _running and game.diagnostic_mode in ["normal", "star_chain"] and game.variety._battle_active() and not game.trials.blocks_rewards() and not game.spawner._boss_fight_active and not game.spawner._endless_trial and not game.player.movement_locked

func enable_debug() -> void:
	debug_training = true
	add_to_group("diagnostic_ui")
	if _debug_button == null:
		_debug_button = Button.new()
		_debug_button.name = "ReplayStarRoute"
		_debug_button.text = L10n.text("重放星轨")
		_hud.add_child(_debug_button)
		_debug_button.pressed.connect(func():
			clear_combat_effects()
			cooldown = 0
			start_route())
	_debug_button.show()
	_fit()

func owns_pointer(point: Vector2) -> bool:
	return debug_training and _hud.visible and _debug_button != null and _debug_button.get_global_rect().has_point(point)

func note_kill(actor: Node2D) -> void:
	if not _eligible() or cooldown > 0 or route_left > 0 or fever_left > 0 or charge >= REQUIRED: return
	if not is_instance_valid(actor) or not game.is_ancestor_of(actor) or not (actor is ENEMY) or not actor._death_started or actor.has_signal("boss_defeated"): return
	var id := actor.get_instance_id()
	if _seen.has(id): return
	_seen[id] = true
	charge += 1

func start_route() -> bool:
	if not _eligible() or route_left > 0 or fever_left > 0 or cooldown > 0: return false
	charge = 0
	_seen.clear()
	step = 0
	route_left = ROUTE_SECONDS
	_last_at = game.player.global_position
	var bounds: Rect2 = (get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_visible_rect()).grow(-28)
	var heading: Vector2 = game.player.last_move_direction.normalized()
	if heading.is_zero_approx(): heading = Vector2.RIGHT
	if not bounds.has_point(_last_at + heading * 140):
		heading = _last_at.direction_to(bounds.get_center())
		if heading.length_squared() < 0.1: heading = Vector2.RIGHT if bounds.size.x > bounds.size.y else Vector2.DOWN
	var side := heading.orthogonal() * (1.0 if _rng.randf() > 0.5 else -1.0)
	for i in 3:
		var at := _last_at + heading * (42 + 48 * i) + side * (25 if i == 1 else 0)
		_points[i] = at.clamp(bounds.position, bounds.end)
	_audio.pitch_scale = 0.9
	_audio.play()
	game.variety.notify(L10n.text("星轨出现！8秒内依次触碰3颗亮星\n完成后进入吸金狂欢；不追也没有损失"))
	_update_hud()
	return true

func _collect_path(from: Vector2, to: Vector2) -> void:
	var travel := to - from
	if travel.length_squared() > 220 * 220: return # Teleports are not route completion.
	var previous_t := -1.0
	for _i in 3:
		if route_left <= 0 or step >= 3: break
		var t := clampf((_points[step] - from).dot(travel) / maxf(travel.length_squared(), 0.001), 0, 1)
		if t < previous_t or from.lerp(to, t).distance_squared_to(_points[step]) > PICK_RADIUS * PICK_RADIUS: break
		previous_t = t
		_burst_at = _points[step]
		_burst_left = 0.32
		step += 1
		stars_collected += 1
		if _notes.size() < 3: _notes.append([1.0, 1.25, 1.5][step - 1])
		game.combat_feedback.spray(_burst_at, Vector2.UP, GamePalette.PLAYER_CYAN, 6, 55)
		if step == 3: _finish_route()

func _finish_route() -> void:
	# Gate before deferred XP creation so callbacks cannot reward the same route twice.
	route_left = 0
	fever_left = FEVER_SECONDS
	cooldown = REST_SECONDS
	completed += 1
	_magnet_left = 0
	_scan_cursor = 0
	game.spawn_xp_coin(game.player.global_position, 8 + 2 * game.spawner.stage)
	game.combat_feedback.reward(game.player.global_position, true)
	AudioManager.play_juice("ready")
	game.variety.notify(L10n.text("星轨完成！吸金狂欢 5秒\n附近金币自动飞来 + 额外经验"))
	RunDiagnostics.mark("star_chain", {"completed": completed})

func _magnet_batch() -> void:
	var actors: Array[Node2D] = game._xp_actors
	if actors.is_empty(): return
	var admitted := 0
	# Incremental scan, no scene-tree search or per-target nearest-neighbor work.
	for _i in mini(48, actors.size()):
		_scan_cursor %= actors.size()
		var coin: Node2D = actors[_scan_cursor]
		_scan_cursor += 1
		if not is_instance_valid(coin) or coin.is_queued_for_deletion() or coin.is_collecting or coin.start_pick: continue
		if coin.global_position.distance_squared_to(game.player.global_position) > MAGNET_RADIUS * MAGNET_RADIUS: continue
		coin.player_body = game.player
		coin.start_pickup()
		admitted += 1
		magnet_started += 1
		if admitted >= MAX_MAGNET_BATCH: break

func _physics_process(delta: float) -> void:
	if not _running or get_tree().paused: return
	if not _eligible():
		if charge > 0 or route_left > 0 or fever_left > 0 or _burst_left > 0: clear_combat_effects()
		_last_at = game.player.global_position
		return
	cooldown = maxf(0, cooldown - delta)
	_clock += delta
	if charge >= REQUIRED and cooldown <= 0: start_route()
	if route_left > 0:
		# Only the active portion of a long frame may collect; expiry cannot grant a late reward.
		var before: Vector2 = _last_at
		var after: Vector2 = game.player.global_position
		var fraction := minf(1.0, route_left / maxf(delta, 0.001))
		_collect_path(before, before.lerp(after, fraction))
		if route_left > 0:
			route_left = maxf(0, route_left - delta)
			if route_left <= 0:
				cooldown = REST_SECONDS
				game.variety.notify(L10n.text("星轨散去了，下次再试"))
	elif fever_left > 0:
		fever_left = maxf(0, fever_left - delta)
		_magnet_left -= delta
		if fever_left > 0 and _magnet_left <= 0:
			_magnet_left = 0.12
			_magnet_batch()
	_last_at = game.player.global_position
	_update_hud()

func _update_hud() -> void:
	var activity := charge > 0 or route_left > 0 or fever_left > 0
	_hud.visible = _eligible() and (activity or debug_training)
	_label.visible = route_left > 0 or fever_left > 0
	_bar.visible = false
	_bar.value = route_left / ROUTE_SECONDS if route_left > 0 else (fever_left / FEVER_SECONDS if fever_left > 0 else float(charge) / REQUIRED)
	_label.text = "%.1f" % (route_left if route_left>0 else fever_left) if route_left>0 or fever_left>0 else ""

func _process(delta: float) -> void:
	_note_left = maxf(0, _note_left - delta)
	if not _notes.is_empty() and _note_left <= 0:
		_audio.pitch_scale = _notes.pop_front()
		_audio.play()
		_note_left = 0.075
	_burst_left = maxf(0, _burst_left - delta)
	_label.scale = Vector2.ONE * (1.0 + 0.2 * _burst_left)
	var active := route_left > 0 or fever_left > 0 or _burst_left > 0
	if active or _draw_visible: queue_redraw()
	_draw_visible = active

func _draw_star(at: Vector2, radius: float, color: Color) -> void:
	draw_set_transform(at, 0.0, Vector2.ONE * radius)
	draw_colored_polygon(_star_unit, color)
	draw_set_transform(Vector2.ZERO)

func _draw() -> void:
	if not _running: return
	if route_left > 0:
		for i in range(step, 3):
			var at: Vector2 = to_local(_points[i])
			if i < 2: draw_dashed_line(at, to_local(_points[i + 1]), Color(GamePalette.PLAYER_CYAN, 0.22), 1, 6)
			var active := i == step
			var color := Color(GamePalette.PLAYER_CYAN, 0.95 if active else 0.3)
			var size := (10.0 + sin(_clock * 5) * 1.3) if active else 7.0
			_draw_star(at, size, color)
			if active:
				_draw_star(at, 4, Color.WHITE)
				draw_arc(at, 17, -PI/2, -PI/2 + TAU * route_left / ROUTE_SECONDS, 28, Color(GamePalette.PLAYER_CYAN,0.7), 1.5)
	if _burst_left > 0:
		var t := 1.0 - _burst_left / 0.32
		for i in 8:
			var direction := Vector2.UP.rotated(TAU * i / 8)
			var tip := to_local(_burst_at) + direction * (12 + 28 * t)
			draw_line(tip - direction * 7, tip, Color(GamePalette.PLAYER_CYAN,1-t), 2)
	if fever_left > 0:
		var at := to_local(game.player.global_position)
		for i in 3:
			var theta := _clock * 2.5 + TAU * i / 3
			_draw_star(at + Vector2(cos(theta)*27, sin(theta)*11+10), 4, GamePalette.PLAYER_CYAN)
