extends Node2D
# Ground marks only. No walking emitter, collision change or per-step nodes.
const MAX_MARKS := 128
const LIFETIME := 8.0
const WALK_SPACING := 17.0
const DASH_SPACING := 9.0
var marks: Array[Dictionary] = []
var coverage := 0.0
var stamped := 0
var _slot := 0
var _stride := 0.0
var _foot := 1.0
var _last_at := Vector2.ZERO
var _dash_mode := false
var _redraw_left := 0.0
@onready var weather: Node = get_parent()
@onready var game: Node = weather.get_parent()

func _ready() -> void:
	z_index = -36 # Above ground (-50), below vegetation (-30) and combat.
	for i in MAX_MARKS:
		marks.append({"at":Vector2.ZERO,"angle":0.0,"left":0.0,"dash":false})
	game.player.dash_started.connect(_on_dash_started)
	game.player.dash_completed.connect(_on_dash_completed)
	clear()
	set_process(false)
	set_physics_process(false)

func clear() -> void:
	for mark in marks: mark.left = 0.0
	_stride = 0
	_dash_mode = false
	_last_at = game.player.global_position
	queue_redraw()

func sync(amount: float) -> void:
	var was_active := coverage > 0.01
	coverage = amount
	var active: bool = weather.running and coverage > 0.01
	if active and not was_active:
		_last_at = game.player.global_position
		_stride = 0
	if not active and (was_active or is_processing()): clear()
	visible = active
	set_process(active)
	set_physics_process(active)

func _on_dash_started(at: Vector2) -> void:
	if not is_physics_processing(): return
	_observe(at, false)
	_stride = 0
	_dash_mode = true

func _on_dash_completed(at: Vector2) -> void:
	if not is_physics_processing(): return
	_observe(at, true)
	_dash_mode = false
	_stride = 0

func _physics_process(_delta: float) -> void:
	if not weather.running or game.player.movement_locked or game.player.player_health <= 0:
		_last_at = game.player.global_position
		_stride = 0
		return
	_observe(game.player.global_position, _dash_mode or game.player.dashing)

func _observe(at: Vector2, dash: bool) -> void:
	var before := _last_at
	_last_at = at
	var distance := before.distance_to(at)
	if distance < 0.001: return
	if distance > 220:
		_stride = 0
		return
	var direction := before.direction_to(at)
	var spacing := DASH_SPACING if dash else WALK_SPACING
	var along := spacing - _stride
	for i in 16:
		if along > distance: break
		var mark: Dictionary = marks[_slot]
		_slot = (_slot + 1) % MAX_MARKS
		var feet := before.lerp(at, along / distance) + Vector2(0, 17)
		mark.at = feet if dash else feet + direction.orthogonal() * _foot * 3.5
		mark.angle = direction.angle()
		mark.dash = dash
		mark.left = LIFETIME
		if not dash: _foot *= -1.0
		stamped += 1
		along += spacing
	_stride = fposmod(_stride + distance, spacing)
	queue_redraw()

func _process(delta: float) -> void:
	var changing := false
	for mark in marks:
		if mark.left > 0:
			mark.left = maxf(0, float(mark.left) - delta)
			changing = true
	_redraw_left -= delta
	if changing and _redraw_left <= 0:
		_redraw_left = 1.0 / 30.0
		queue_redraw()

func _draw() -> void:
	for mark in marks:
		if mark.left <= 0: continue
		var alpha := minf(1.0, float(mark.left) / 3.0) * coverage
		draw_set_transform(to_local(mark.at), mark.angle)
		if mark.dash:
			for side in [-1.0, 1.0]:
				draw_line(Vector2(-5, side*3.5), Vector2(5, side*3.5), Color(GamePalette.SNOW_TRACK, alpha*0.48), 2.5)
				draw_line(Vector2(-5, side*5.2), Vector2(5, side*5.2), Color(GamePalette.SNOW_FLAKE, alpha*0.5), 1)
		else:
			draw_rect(Rect2(-3, -1.7, 6, 3.4), Color(GamePalette.SNOW_TRACK, alpha*0.58))
			draw_rect(Rect2(1, -1.4, 2.5, 2.8), Color(GamePalette.SNOW_TRACK, alpha*0.24))
			draw_line(Vector2(-2, 2), Vector2(3, 2), Color(GamePalette.SNOW_FLAKE, alpha*0.55), 1)
		draw_set_transform(Vector2.ZERO)
