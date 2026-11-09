extends Node2D

const MAX_LEVEL := 5
const MAX_BOMBS := 4
const MAX_BLASTS := 6
const THROW_SECONDS := 0.42
const FUSE_SECONDS := 0.68
const BLAST_SECONDS := 0.36
const CAST_RANGE := 310.0
const ICON_PATH := "res://assest/sprites/bomb.svg"
const STYLE := preload("res://script/visual_style.gd")
var level := 0
var casts := 0
var detonations := 0
var hits := 0
var _cooldown := 0.0
var _redraw_left := 0.0
var _generation := 0
var _blast_slot := 0
var _had_draw := false
var _bombs: Array[Dictionary] = []
var _blasts: Array[Dictionary] = []
var _targets: Array[Node2D] = []
var _stats := stats_for(1)
var _audio: AudioStreamPlayer
var _icon: Texture2D
@onready var game: Node = get_parent()

static func stats_for(rank: int) -> Dictionary:
	var step := clampi(rank, 1, MAX_LEVEL) - 1
	return {"damage": 50.0 + 15.0 * step, "radius": 70.0 + 12.0 * step,
		"interval": 4.8 * pow(0.85, step), "push_speed": 380.0 + 20.0 * step}

func _ready() -> void:
	z_index = 10
	_icon = load(ICON_PATH)
	for _i in MAX_BOMBS:
		_bombs.append({"active": false, "age": 0.0, "from": Vector2.ZERO, "at": Vector2.ZERO,
			"damage": 0.0, "radius": 0.0, "push_speed": 0.0})
	for _i in MAX_BLASTS:
		_blasts.append({"left": 0.0, "at": Vector2.ZERO, "radius": 0.0, "phase": 0.0})
	_audio = AudioStreamPlayer.new()
	AudioManager.configure_sfx(_audio)
	_audio.stream = preload("res://assest/sounds/bomb_burst.wav")
	_audio.volume_db = -15.0
	_audio.max_polyphony = 1
	add_child(_audio)
	reset()

func upgrade() -> void:
	level = mini(level + 1, MAX_LEVEL)
	_stats = stats_for(level)
	_cooldown = minf(_cooldown, float(_stats.interval)) if level > 1 else 0.35
	set_physics_process(true)

func reset() -> void:
	clear_combat_effects()
	level = 0
	casts = 0
	detonations = 0
	hits = 0
	_cooldown = 0.0
	set_physics_process(false)

func clear_combat_effects() -> void:
	_generation += 1
	for bomb in _bombs: bomb.active = false
	for blast in _blasts: blast.left = 0.0
	_targets.clear()
	for entry in CombatTargets._entries:
		var actor: Node2D = entry.actor
		if is_instance_valid(actor) and game.is_ancestor_of(actor) and actor.has_method("clear_blast_impulse"):
			actor.clear_blast_impulse()
	if _audio != null: _audio.stop()
	_had_draw = false
	queue_redraw()

func cast() -> bool:
	if level <= 0 or not game.variety._battle_active(): return false
	var slot := -1
	for i in _bombs.size():
		if not _bombs[i].active:
			slot = i
			break
	if slot < 0: return false
	_targets.clear()
	CombatTargets.fill_in_radius(game.player.global_position, CAST_RANGE * CAST_RANGE, game, _targets)
	var target: Node2D
	var best := INF
	for actor in _targets:
		if not actor.has_method("apply_hit") or (actor.has_method("vulnerable") and not actor.vulnerable()): continue
		var distance: float = game.player.global_position.distance_squared_to(actor.global_position)
		if distance < best:
			best = distance
			target = actor
	if target == null: return false
	var origin: Vector2 = game.player.global_position
	var bomb: Dictionary = _bombs[slot]
	bomb.active = true
	bomb.age = 0.0
	bomb.from = origin
	# Land at a fixed ground point, so a dead target cannot retain a node or move the blast.
	bomb.at = origin + (target.global_position - origin).limit_length(240.0)
	bomb.damage = _stats.damage
	bomb.radius = _stats.radius
	bomb.push_speed = _stats.push_speed
	_cooldown = float(_stats.interval)
	casts += 1
	_had_draw = true
	queue_redraw()
	return true

func _physics_process(delta: float) -> void:
	if level <= 0 or get_tree().paused: return
	if not game.variety._battle_active():
		if _had_draw: clear_combat_effects()
		return
	var generation := _generation
	var active := false
	for blast in _blasts:
		blast.left = maxf(0.0, float(blast.left) - delta)
		active = active or blast.left > 0.0
	for bomb in _bombs:
		if not bomb.active: continue
		bomb.age += delta
		if bomb.age >= FUSE_SECONDS:
			_detonate(bomb)
			if generation != _generation: return
		active = true
	_cooldown -= delta
	if _cooldown <= 0.0 and not cast(): _cooldown = 0.25
	for bomb in _bombs: active = active or bool(bomb.active)
	if active or _had_draw:
		_redraw_left -= delta
		if _redraw_left <= 0.0:
			_redraw_left = 1.0 / 30.0
			queue_redraw()
	_had_draw = active

func _detonate(bomb: Dictionary) -> void:
	if not bomb.active or not game.variety._battle_active(): return
	bomb.active = false
	detonations += 1
	_had_draw = true
	var generation := _generation
	var at: Vector2 = bomb.at
	var radius: float = bomb.radius
	var blast: Dictionary = _blasts[_blast_slot]
	blast.at = at
	blast.radius = radius
	blast.left = BLAST_SECONDS
	blast.phase = float(detonations) * 2.399963
	_blast_slot = (_blast_slot + 1) % MAX_BLASTS
	_audio.play()
	game.combat_feedback.spray(at, Vector2.ZERO, GamePalette.FRIENDLY_CYAN, 12, 155)
	game.combat_feedback.camera_impulse(1.7)
	queue_redraw()
	_targets.clear()
	CombatTargets.fill_in_radius(at, radius * radius, game, _targets)
	for actor in _targets:
		if not is_instance_valid(actor) or actor.is_queued_for_deletion() or not actor.has_method("apply_hit"): continue
		if actor.has_method("vulnerable") and not actor.vulnerable(): continue
		var direction: Vector2 = actor.global_position - at
		if direction.is_zero_approx(): direction = actor.global_position - game.player.global_position
		if direction.is_zero_approx(): direction = Vector2.RIGHT
		direction = direction.normalized()
		# Direct damage can crit and use owned passives. There is no implicit burn or secondary blast.
		actor.apply_hit({"damage": bomb.damage, "direction": direction, "effect": "bomb", "source": self})
		hits += 1
		if generation != _generation: return
		if is_instance_valid(actor) and not actor.is_queued_for_deletion() and actor.has_method("apply_blast_impulse"):
			actor.apply_blast_impulse(direction * float(bomb.push_speed), 0.3)

func _draw() -> void:
	for bomb in _bombs:
		if not bomb.active: continue
		var progress: float = clampf(float(bomb.age) / THROW_SECONDS, 0.0, 1.0)
		var ground: Vector2 = to_local(bomb.from).lerp(to_local(bomb.at), progress)
		var lift := sin(progress * PI) * 44.0
		draw_set_transform(ground, 0.0, Vector2(1.0, 0.35))
		draw_circle(Vector2.ZERO, 6.0, GamePalette.alpha(GamePalette.INK, 0.28))
		draw_set_transform(to_local(bomb.at))
		draw_arc(Vector2.ZERO, 9.0, 0, TAU, 16, Color(STYLE.FRIENDLY, 0.45), 1.0, false)
		draw_set_transform(ground - Vector2(0, lift), progress * TAU)
		draw_texture_rect(_icon, Rect2(-11, -11, 22, 22), false)
		if bomb.age > THROW_SECONDS:
			var pulse: float = 0.4 + 0.4 * sin(float(bomb.age) * 40.0)
			draw_circle(Vector2(-2, -9), 2.0, GamePalette.alpha(GamePalette.FRIENDLY_CYAN, pulse))
		draw_set_transform(Vector2.ZERO)
	for blast in _blasts:
		if blast.left <= 0.0: continue
		var progress: float = 1.0 - float(blast.left) / BLAST_SECONDS
		var radius: float = lerpf(10, float(blast.radius), 1.0 - pow(1.0 - progress, 3.0))
		var at: Vector2 = to_local(blast.at)
		var alpha := pow(1.0 - progress, 1.5)
		# A brief local core and thin friendly ring preserve hostile red telegraphs.
		if progress < 0.32: draw_circle(at, radius * 0.52, GamePalette.alpha(GamePalette.FRIENDLY_LIGHT, alpha * 0.35))
		draw_arc(at, radius, 0, TAU, 32, Color(STYLE.FRIENDLY, alpha * 0.9), lerpf(3.0, 0.8, progress), false)
		draw_arc(at, radius * 0.72, 0, TAU, 24, GamePalette.alpha(GamePalette.FRIENDLY_CYAN, alpha * 0.6), 1.4, false)
		for i in 8:
			var direction := Vector2.from_angle(float(blast.phase) + i * TAU / 8.0)
			draw_line(at + direction * radius * 0.58, at + direction * radius * 0.9, GamePalette.alpha(GamePalette.FRIENDLY_LIGHT, alpha), 2.0, false)
