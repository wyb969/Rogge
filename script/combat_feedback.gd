extends Node2D

const MAX_SHARDS: = 128
const MAX_RINGS: = 16
const MAX_GHOSTS: = 8
const MAX_BURSTS_PER_FRAME: = 8
const BURSTS_PER_SECOND: = 42.0
var shards: Array[Dictionary] = []
var rings: Array[Dictionary] = []
var ghosts: Array[Dictionary] = []
var _free_shards: Array[Dictionary] = []
var _free_rings: Array[Dictionary] = []
var _free_ghosts: Array[Dictionary] = []
var suppressed: = 0
var _rng: = RandomNumberGenerator.new()
var _camera_motion: = preload("res://script/camera_motion.gd").new()
var _camera: Camera2D
var _origin: = Vector2.ZERO
var _shake: = 0.0
var _kick: = Vector2.ZERO
var _clock: = 0.0
var _tokens: = BURSTS_PER_SECOND
var _stamp: = 0
var _frame: = -1
var _in_frame: = 0
var _last_reward: = -1000

static func find(actor: Node) -> Node:
	if not actor.is_inside_tree(): return null
	var owner: = actor.get_parent()
	while owner != null:
		if owner.has_meta(&"rogge_feedback"):
			var reference: = owner.get_meta(&"rogge_feedback") as WeakRef
			if reference != null: return reference.get_ref()
		owner = owner.get_parent()
	return null

func _ready() -> void :
	add_to_group("combat_feedback")
	z_index = 9
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	for _i in MAX_SHARDS:
		_free_shards.append({"p": Vector2.ZERO, "v": Vector2.ZERO, "left": 0.0, "life": 0.0, "color": Color.WHITE, "size": 0.0})
	for _i in MAX_RINGS:
		_free_rings.append({"p": Vector2.ZERO, "color": Color.WHITE, "radius": 0.0, "life": 0.0, "left": 0.0})
	for _i in MAX_GHOSTS:
		_free_ghosts.append({"p": Vector2.ZERO, "scale": Vector2.ONE, "rotation": 0.0, "texture": null, "left": 0.0})
	_stamp = Time.get_ticks_msec()
	_camera = get_parent().get_node_or_null("Player/Camera2D")
	if _camera != null:
		_origin = _camera.offset
		_camera_motion.bind(_camera, get_parent().get_node("Player"))
	set_process(false)

func start() -> void :
	reset()
	_stamp = Time.get_ticks_msec()
	set_process(true)

func reset() -> void :
	while not shards.is_empty(): _free_shards.append(shards.pop_back())
	while not rings.is_empty(): _free_rings.append(rings.pop_back())
	while not ghosts.is_empty():
		var ghost_image: Dictionary = ghosts.pop_back()
		ghost_image.texture = null
		_free_ghosts.append(ghost_image)
	_shake = 0
	_kick = Vector2.ZERO
	_tokens = BURSTS_PER_SECOND
	_in_frame = 0
	_last_reward = -1000
	suppressed = 0
	if is_instance_valid(_camera):
		_camera.offset = _origin
		_camera_motion.reset()
	queue_redraw()
	set_process(false)

func _admit() -> bool:
	if not is_processing(): return false
	var frame: = Engine.get_process_frames()
	if frame != _frame:
		_frame = frame
		_in_frame = 0
	if _in_frame >= MAX_BURSTS_PER_FRAME or _tokens < 1:
		suppressed += 1
		return false
	_in_frame += 1
	_tokens -= 1
	return true

func _burst(at: Vector2, direction: Vector2, tint: Color, count: int, speed: float) -> void :
	for _i in mini(count, MAX_SHARDS - shards.size()):
		var angle: = direction.angle() + _rng.randf_range(-0.9, 0.9) if not direction.is_zero_approx() else _rng.randf() * TAU
		var duration: = _rng.randf_range(0.12, 0.24)
		var shard: Dictionary = _free_shards.pop_back()
		shard.p = to_local(at)
		shard.v = Vector2.from_angle(angle) * _rng.randf_range(speed * 0.4, speed)
		shard.left = duration
		shard.life = duration
		shard.color = tint
		shard.size = _rng.randf_range(1.0, 2.0)
		shards.append(shard)

func _ring(at: Vector2, tint: Color, radius: float, life: float) -> void :
	if rings.size() >= MAX_RINGS: return
	var ring: Dictionary = _free_rings.pop_back()
	ring.p = to_local(at)
	ring.color = tint
	ring.radius = radius
	ring.life = life
	ring.left = life
	rings.append(ring)

func spray(at: Vector2, direction: Vector2, tint: Color, count: int, speed: float) -> void :
	if _admit(): _burst(at, direction, tint, count, speed)

func hit(at: Vector2, direction: Vector2, heavy: bool = false) -> void :
	if not _admit(): return
	_burst(at, direction, Color(0.94, 0.9, 0.76), 5 if heavy else 3, 105 if heavy else 75)
	if heavy: _ring(at, Color(1, 0.93, 0.78, 0.65), 13, 0.14)

func kill(at: Vector2, tint: Color, elite: bool = false) -> void :
	if not _admit(): return
	_burst(at, Vector2.ZERO, tint.clamp(Color(0, 0, 0, 0), Color.WHITE).lightened(0.12), 9 if elite else 5, 100)
	_ring(at, Color(0.84, 0.88, 0.83, 0.42), 22 if elite else 14, 0.18)
	if elite: camera_impulse(1.8)
	AudioManager.play_juice("kill")

func dash(at: Vector2, direction: Vector2) -> void :
	if not _admit(): return
	_burst(at, - direction, Color(0.48, 0.78, 0.84), 6, 80)
	_ring(at, Color(0.65, 0.96, 1, 0.65), 23, 0.18)
	camera_impulse(0.7, direction)
	AudioManager.play_juice("dash")

func ghost(sprite: AnimatedSprite2D) -> void :
	if not is_processing() or ghosts.size() >= MAX_GHOSTS: return
	var texture: = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	var ghost_image: Dictionary = _free_ghosts.pop_back()
	ghost_image.p = to_local(sprite.global_position)
	ghost_image.scale = sprite.global_scale * Vector2(-1 if sprite.flip_h else 1, 1)
	ghost_image.rotation = sprite.global_rotation - global_rotation
	ghost_image.texture = texture
	ghost_image.left = 0.18
	ghosts.append(ghost_image)

func pickup(at: Vector2, healing: bool = false) -> void :
	if not _admit(): return
	var color: = Color(0.45, 1, 0.65) if healing else Color(1, 0.87, 0.35)
	_burst(at, Vector2.UP, color, 3, 55)
	_ring(at, Color(color, 0.38), 10, 0.14)

func reward(at: Vector2, major: bool = false) -> void :
	var now: = Time.get_ticks_msec()
	if now - _last_reward < 400 or not _admit(): return
	_last_reward = now
	if not major: AudioManager.play_upgrade()
	_burst(at, Vector2.ZERO, Color(0.84, 0.88, 0.76), 14 if major else 8, 125)
	_ring(at, Color(0.7, 1, 0.9, 0.7), 75 if major else 48, 0.4)
	_ring(at, Color(1, 0.88, 0.48, 0.6), 53 if major else 32, 0.28)
	camera_impulse(2.2 if major else 1.0)

func hurt(at: Vector2, direction: Vector2, shielded: bool) -> void :

	camera_impulse(4.5 if not shielded else 2.5, - direction)
	if not _admit(): return
	_burst(at, direction, Color(1, 0.85, 0.35) if shielded else Color(1, 0.5, 0.45), 12, 115)

func camera_impulse(strength: float, direction: Vector2 = Vector2.ZERO) -> void :
	_shake = maxf(_shake, minf(strength, 5.0))
	_kick = (_kick + direction.limit_length() * 1.6).limit_length(2.4)

func _process(_delta: float) -> void :
	var now: = Time.get_ticks_msec()
	var dt: = clampf((now - _stamp) / 1000.0, 0, 0.05)
	_stamp = now
	_tokens = minf(BURSTS_PER_SECOND, _tokens + dt * BURSTS_PER_SECOND)
	_clock += dt
	_shake = move_toward(_shake, 0, dt * 19)
	_kick = _kick.lerp(Vector2.ZERO, 1.0 - exp( - dt * 20))
	if is_instance_valid(_camera):
		_camera_motion.tick(dt, get_tree().paused, SettingsStore.camera_shake)
		var vibration: = Vector2(sin(_clock * 91), sin(_clock * 117 + 1.8)) * _shake
		_camera.offset = _origin + (vibration + _kick).limit_length(6) * SettingsStore.camera_shake
	var i: = shards.size() - 1
	while i >= 0:
		var shard: = shards[i]
		shard.left -= dt
		shard.p += shard.v * dt
		shard.v *= exp( - dt * 8)
		if shard.left <= 0:
			_free_shards.append(shard)
			shards[i] = shards.back()
			shards.pop_back()
		i -= 1
	_tick_small_pool(rings, _free_rings, dt)
	_tick_small_pool(ghosts, _free_ghosts, dt, true)
	if not shards.is_empty() or not rings.is_empty() or not ghosts.is_empty() or _had_draw:
		queue_redraw()
	_had_draw = not shards.is_empty() or not rings.is_empty() or not ghosts.is_empty()

func _tick_small_pool(active: Array[Dictionary], idle: Array[Dictionary], dt: float, clear_texture: bool = false) -> void :
	var i: = active.size() - 1
	while i >= 0:
		var item: = active[i]
		item.left -= dt
		if item.left <= 0:
			if clear_texture: item.texture = null
			idle.append(item)
			active[i] = active.back()
			active.pop_back()
		i -= 1

var _had_draw: = false
func _draw() -> void :
	for ghost_image in ghosts:
		var texture: Texture2D = ghost_image.texture
		draw_set_transform(ghost_image.p, ghost_image.rotation, ghost_image.scale)
		draw_texture(texture, - texture.get_size() * 0.5, Color(0.48, 0.78, 0.84, ghost_image.left / 0.18 * 0.28))
	draw_set_transform(Vector2.ZERO)
	for ring in rings:
		var progress: float = 1.0 - ring.left / ring.life
		var color: Color = ring.color
		color.a *= 1.0 - progress
		draw_arc(ring.p, lerpf(3, ring.radius, 1.0 - pow(1.0 - progress, 3)), 0, TAU, 24, color, 1.2, false)
	for shard in shards:
		var color: Color = shard.color
		color.a *= clampf(shard.left / shard.life * 1.5, 0, 1)
		draw_line(shard.p, shard.p - shard.v.normalized() * shard.size * 2.2, color, shard.size, false)
