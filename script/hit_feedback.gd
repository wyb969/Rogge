extends Node2D

# One fixed overlay batch and one owner of combat time scale. Never extend a
# pause on repeated hits; real-time deadlines recover even while simulation slows.
const MAX_FLASHES := 48 # Slot zero is reserved for the player.
const ENEMY_FLASH_US := 85000
const PLAYER_FLASH_US := 115000
const FLASH_GAP_US := 140000
const ENEMY_STOP_US := 28000
const PLAYER_STOP_US := 65000
const STOP_GAP_US := 200000
const STOP_SCALE := 0.05
var records: Array[Dictionary] = []
var indices := {}
var flashes := 0
var stops := 0
var _armed := false
var _slot := 1
var _owns_scale := false
var _stop_until := 0
var _stop_started := 0
var _ready_at := 0
var _player_ready_at := 0
var _player_priority := false
@onready var feedback: Node = get_parent()
@onready var game: Node = feedback.get_parent()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_as_relative = false
	z_index = 15
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var silhouette := ShaderMaterial.new()
	silhouette.shader = preload("res://shaders/dash_ghost.gdshader")
	material = silhouette
	for _i in MAX_FLASHES:
		records.append({"id":0,"actor":null,"sprite":null,"texture":null,
			"rect":Rect2(),"source":Rect2(),"transform":Transform2D.IDENTITY,
			"end":0,"ready":0,"player":false,"region":false})
	reset()

func begin_run() -> void:
	reset()
	_armed = true

func reset() -> void:
	_armed = false
	flashes = 0
	stops = 0
	clear_combat_effects()

func clear_combat_effects() -> void:
	_release_scale()
	for record in records: _clear(record)
	indices.clear()
	_slot = 1
	_ready_at = 0
	_player_ready_at = 0
	set_process(false)
	queue_redraw()

func _exit_tree() -> void:
	_release_scale()

func _active() -> bool:
	return _armed and feedback.is_processing() and game.variety._battle_active()

func pulse(actor: Node2D, sprite: Node2D, player_hurt: bool = false, stop: bool = true) -> bool:
	if not _active() or not is_instance_valid(actor) or not is_instance_valid(sprite): return false
	if not (sprite is Sprite2D or sprite is AnimatedSprite2D): return false
	if sprite is Sprite2D and sprite.texture == null: return false
	if sprite is AnimatedSprite2D and (sprite.sprite_frames == null or sprite.sprite_frames.get_frame_count(sprite.animation) == 0): return false
	var now := Time.get_ticks_usec()
	var id := actor.get_instance_id()
	var index: int = indices.get(id,-1)
	if index >= 0 and now < int(records[index].ready): return false
	if index < 0:
		index = 0 if player_hurt else _slot
		if not player_hurt: _slot = 1 + _slot % (MAX_FLASHES-1)
		indices.erase(records[index].id)
	var record: Dictionary = records[index]
	record.id = id
	record.actor = weakref(actor)
	record.sprite = weakref(sprite)
	record.player = player_hurt
	record.end = now + (PLAYER_FLASH_US if player_hurt else ENEMY_FLASH_US)
	record.ready = now + FLASH_GAP_US
	_capture(record,sprite)
	indices[id] = index
	flashes += 1
	if stop: request_stop(player_hurt)
	set_process(true)
	queue_redraw()
	return true

func request_stop(player_hurt: bool = false) -> void:
	if not _active() or get_tree().has_meta("player_death_slowmo"): return
	# Timed trials keep their real-time lock/dodge windows; they still get flashes.
	if game.trials != null and game.trials.active_fight(): return
	var now := Time.get_ticks_usec()
	if _owns_scale:
		if player_hurt and not _player_priority and is_equal_approx(Engine.time_scale,STOP_SCALE):
			_stop_until = mini(now+PLAYER_STOP_US,_stop_started+PLAYER_STOP_US)
			_player_priority = true
			_player_ready_at = now + 400000
		return
	if now < (_player_ready_at if player_hurt else _ready_at) or not is_equal_approx(Engine.time_scale,1.0): return
	_stop_started = now
	_stop_until = now + (PLAYER_STOP_US if player_hurt else ENEMY_STOP_US)
	_ready_at = now + STOP_GAP_US
	_player_priority = player_hurt
	if player_hurt: _player_ready_at = now + 400000
	_owns_scale = true
	Engine.time_scale = STOP_SCALE
	stops += 1
	set_process(true)

func _release_scale() -> void:
	# A death sequence or another owner may already have replaced our scale.
	if _owns_scale and is_equal_approx(Engine.time_scale,STOP_SCALE): Engine.time_scale = 1.0
	_owns_scale = false
	_stop_until = 0

func _clear(record: Dictionary) -> void:
	record.id = 0
	record.actor = null
	record.sprite = null
	record.texture = null
	record.end = 0
	record.ready = 0

func _capture(record: Dictionary, sprite: Node2D) -> void:
	var transform := global_transform.affine_inverse() * sprite.global_transform
	if sprite is AnimatedSprite2D:
		var animated := sprite as AnimatedSprite2D
		record.texture = animated.sprite_frames.get_frame_texture(animated.animation,animated.frame)
		var size: Vector2 = record.texture.get_size()
		record.rect = Rect2(animated.offset-size*0.5 if animated.centered else animated.offset,size)
		record.region = false
		transform = transform.scaled_local(Vector2(-1 if animated.flip_h else 1, -1 if animated.flip_v else 1))
	else:
		var image := sprite as Sprite2D
		if image.texture == null: return
		record.texture = image.texture
		var region := image.region_rect if image.region_enabled else Rect2(Vector2.ZERO,image.texture.get_size())
		var cell := region.size / Vector2(image.hframes,image.vframes)
		record.source = Rect2(region.position+Vector2(image.frame_coords)*cell,cell)
		record.rect = image.get_rect()
		record.region = true
		transform = transform.scaled_local(Vector2(-1 if image.flip_h else 1, -1 if image.flip_v else 1))
	record.transform = transform

func _process(_delta: float) -> void:
	if not _active():
		clear_combat_effects()
		return
	var now := Time.get_ticks_usec()
	if _owns_scale and (now >= _stop_until or not is_equal_approx(Engine.time_scale,STOP_SCALE)):
		_release_scale()
	var active := _owns_scale
	for record in records:
		if record.id == 0: continue
		if now >= int(record.ready):
			indices.erase(record.id)
			_clear(record)
		else: active = true
	queue_redraw()
	if not active: set_process(false)

func _draw() -> void:
	var now := Time.get_ticks_usec()
	for record in records:
		if now >= int(record.end) or record.texture == null: continue
		var actor: Node2D = record.actor.get_ref()
		var sprite: Node2D = record.sprite.get_ref()
		if is_instance_valid(actor) and not actor.is_queued_for_deletion() and is_instance_valid(sprite) and sprite.is_visible_in_tree():
			_capture(record,sprite)
		# A lethal hit keeps its captured frame briefly after the enemy is freed.
		var tint: Color = GamePalette.HURT_FLASH_RED if record.player else GamePalette.HIT_FLASH_WHITE
		tint.a = (0.88 if record.player else 0.98) * clampf(float(record.end-now)/40000.0,0,1)
		draw_set_transform_matrix(record.transform)
		if record.region: draw_texture_rect_region(record.texture,record.rect,record.source,tint)
		else: draw_texture_rect(record.texture,record.rect,false,tint)
	draw_set_transform_matrix(Transform2D.IDENTITY)
