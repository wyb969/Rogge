extends Node2D

const ENEMY: = preload("res://script/enemy_shell.gd")
const MAX_METEORS: = 5
const WARNING: = 0.75
const FALL: = 0.28
const CRATER: = 1.1
const RADIUS: = 43.0
const REWARD_PER_FRAME: = 2
const GOLD: = GamePalette.FRIENDLY_CYAN
const PAPER: = GamePalette.FRIENDLY_LIGHT
var _meteors: Array[Dictionary] = []
var _running: = false
var _rng: = RandomNumberGenerator.new()
var _next_event: = 45.0
var _age: = 0.0
var _count: = 0
var _redraw_left: = 0.0
var _reward_left: = 0
var _reward_count: = 0
var _reward_index: = 0
var _reward_healing: = false
var _reward_origin: = Vector2.ZERO
var showers_started: = 0
var impacts: = 0
var enemies_defeated: = 0
var drops_spawned: = 0
@onready var game: Node = get_parent()

func _ready() -> void :
	z_index = 7
	_rng.randomize()
	for _i in MAX_METEORS:
		_meteors.append({"at": Vector2.ZERO, "from": Vector2.ZERO, "delay": 0.0, "hit": false})
	set_process(false)

func reset() -> void :
	_running = false
	clear_combat_effects()
	showers_started = 0
	impacts = 0
	enemies_defeated = 0
	drops_spawned = 0
	set_process(false)

func begin_run() -> void :
	reset()
	_running = true
	_next_event = _rng.randf_range(35, 55)
	set_process(true)

func clear_combat_effects() -> void :
	_count = 0
	_reward_left = 0
	_age = 0
	queue_redraw()

func _combat_allowed() -> bool:
	if not _running or not game.visible or game.process_mode == Node.PROCESS_MODE_DISABLED or game.player.player_health <= 0: return false
	var spawner: Node = game.spawner
	return not (spawner._run_closed or spawner._rest_open or spawner._transitioning or spawner._boss_fight_active or spawner._endless_trial or (spawner._mini_spawned and not spawner._mini_cleared)) and not game.trials.blocks_rewards()

func eligible() -> bool:
	return _combat_allowed() and game.weather.running and (game.weather.current_weather == game.weather.Weather.OVERCAST or game.weather.daylight < 0.18)

func start_shower(center: Vector2) -> bool:
	if get_tree().paused or not eligible() or _count > 0 or _reward_left > 0: return false
	_count = _rng.randi_range(3, MAX_METEORS)
	_age = 0
	_reward_origin = center
	_reward_count = _rng.randi_range(3, 10)
	_reward_index = 0
	_reward_healing = _rng.randf() < 0.35
	for i in _count:
		var meteor: = _meteors[i]
		meteor.at = center if i == 0 else center + Vector2.from_angle(TAU * float(i) / _count) * _rng.randf_range(35, 65)
		meteor.from = meteor.at + Vector2(-85, -185)
		meteor.delay = float(i) * 0.16
		meteor.hit = false
	showers_started += 1
	_next_event = _rng.randf_range(75, 110)
	game.variety.notify("流星雨！金色落点会清除小怪，留下补给")
	AudioManager.play_juice("ready")
	RunDiagnostics.mark("meteor_shower", {"count": _count, "reward_count": _reward_count, "healing": _reward_healing})
	queue_redraw()
	return true

func _random_center() -> Vector2:
	var camera: = get_viewport().get_camera_2d()
	var bounds: = get_viewport().get_visible_rect()
	var half: = bounds.size / (camera.zoom if camera != null else Vector2.ONE) * 0.5
	var center: Vector2 = camera.get_screen_center_position() if camera != null else game.player.global_position
	var extent: = Vector2(maxf(0, half.x - 110), maxf(0, half.y - 110))
	return center + Vector2(_rng.randf_range( - extent.x, extent.x), _rng.randf_range( - extent.y, extent.y))

func _process(delta: float) -> void :
	if not _running or get_tree().paused: return
	if not _combat_allowed():
		if _count > 0 or _reward_left > 0: clear_combat_effects()
		return
	if _count > 0:
		_age += delta
		var all_hit: = true
		for i in _count:
			var meteor: = _meteors[i]
			if not meteor.hit and _age >= meteor.delay + WARNING + FALL:
				meteor.hit = true
				_impact(meteor.at)
			all_hit = all_hit and meteor.hit
		if all_hit and _reward_index == 0 and _reward_left == 0:
			_reward_left = _reward_count
		if _age >= float(_count - 1) * 0.16 + WARNING + FALL + CRATER:
			_count = 0
			queue_redraw()
		_redraw_left -= delta
		if _redraw_left <= 0:
			_redraw_left = 1.0 / 30
			queue_redraw()
	if _reward_left > 0:
		for _i in mini(REWARD_PER_FRAME, _reward_left): _spawn_reward()
	if _count == 0 and _reward_left == 0 and game.diagnostic_mode in ["normal", "meteor"] and eligible():
		_next_event -= delta
		if _next_event <= 0: start_shower(_random_center())

func _impact(at: Vector2) -> void :
	impacts += 1
	var killed: = 0
	for actor in CombatTargets.in_radius(at, RADIUS * RADIUS, game):


		if actor.get_script() != ENEMY: continue
		actor.receive_hit((actor.global_position - at).normalized(), maxf(actor.health, 0) * 4 + 4)
		if actor.health <= 0: killed += 1
	enemies_defeated += killed
	game.combat_feedback.spray(at, Vector2.UP, GOLD, 5, 65)
	game.combat_feedback.camera_impulse(0.7)
	AudioManager.play_juice("kill")
	RunDiagnostics.mark("meteor_impact", {"kills": killed})

func _spawn_reward() -> void :
	var angle: = float(_reward_index) * 2.399963
	var at: = _reward_origin + Vector2.from_angle(angle) * (5 + sqrt(float(_reward_index)) * 8)
	if _reward_healing:
		game.spawn_healing_orb(at, 5)
	else:
		game._spawn_xp_coin_now(at, 2)
	_reward_left -= 1
	_reward_index += 1
	drops_spawned += 1
	if _reward_left == 0:
		game.variety.notify("流星馈赠 · %s ×%d" % ["回血球" if _reward_healing else "金币", _reward_count])

func _draw() -> void :
	for i in _count:
		var meteor: = _meteors[i]
		var elapsed: float = _age - meteor.delay
		if elapsed < 0: continue
		var at: Vector2 = to_local(meteor.at)
		if elapsed < WARNING + FALL:
			draw_circle(at, RADIUS, Color(GOLD, 0.035))
			draw_arc(at, RADIUS, 0, TAU, 28, Color(GOLD, 0.7), 1.2, false)
			var tick: = 4 + sin(elapsed * 9) * 1.5
			draw_line(at - Vector2(tick, 0), at + Vector2(tick, 0), PAPER, 1, false)
			draw_line(at - Vector2(0, tick), at + Vector2(0, tick), PAPER, 1, false)
			if elapsed >= WARNING:
				var t: = clampf((elapsed - WARNING) / FALL, 0, 1)
				var head: Vector2 = to_local(meteor.from.lerp(meteor.at, t * t))
				draw_line(head - Vector2(18, 40), head, Color(0.48, 0.78, 0.84, 0.35), 5, false)
				draw_line(head - Vector2(18, 40), head, Color(PAPER, 0.9), 1.6, false)
				draw_circle(head, 5, GOLD)
				draw_circle(head, 2.5, PAPER)
		else:
			var age: float = elapsed - WARNING - FALL
			var alpha: = clampf(1 - age / CRATER, 0, 1)
			draw_set_transform(at, 0, Vector2(1, 0.45))
			draw_circle(Vector2.ZERO, 11, Color(0.04, 0.06, 0.07, alpha * 0.55))
			draw_set_transform(Vector2.ZERO)
			if age < 0.28:
				draw_arc(at, lerpf(7, RADIUS, age / 0.28), 0, TAU, 28, Color(GOLD, (1 - age / 0.28) * 0.7), 1.5, false)
				for spark in 4:
					var direction: = Vector2.from_angle(float(spark) * TAU / 4 + 0.4)
					draw_line(at + direction * (9 + age * 55), at + direction * (14 + age * 65), Color(PAPER, (1 - age / 0.28) * 0.8), 1.5, false)
