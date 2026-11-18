extends Node

var clips: SpriteFrames
var sprite: Sprite2D
var actor: CharacterBody2D
var current: StringName
var elapsed := 0.0
var stride := 40.0
var previous: Vector2
var sampled := false
var hurt_left := 0.0

func setup(host: CharacterBody2D, body: Sprite2D, art: String, zoom: float, foot_y: float) -> void:
	actor = host
	sprite = body
	sprite.material = null
	sprite.modulate = Color.WHITE
	clips = load("res://rogge_art/bosses/%s/animations.tres" % art)
	var neutral := clips.get_frame_texture(&"idle", 0) as AtlasTexture
	sprite.frame = 0
	sprite.texture = neutral.atlas
	sprite.hframes = 4
	sprite.vframes = 4
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE * zoom
	sprite.offset.y = foot_y / zoom - 21.0
	stride = 12.0 * zoom * host.scale.x
	host.add_child(self)

func _physics_process(delta: float) -> void:
	var travel := actor.global_position - previous if sampled else Vector2.ZERO
	previous = actor.global_position
	sampled = true
	var action: StringName = actor.pose_action()
	if action == &"approach":
		if travel.length_squared() < 0.0001: action = &"idle"
		elif absf(travel.x) > maxf(0.002, absf(travel.y)*0.12): sprite.flip_h = travel.x < 0
	if hurt_left > 0 and action in [&"idle", &"approach", &"recover"]: action = &"hurt"
	hurt_left = maxf(0, hurt_left-delta)
	if current != action:
		current = action
		elapsed = 0
	var count := clips.get_frame_count(action)
	if action == &"approach":
		elapsed += travel.length() * count / stride
	else:
		var clip_delta := delta / maxf(Engine.time_scale, 0.005) if action == &"defeat" else delta
		elapsed += clip_delta * clips.get_animation_speed(action)
	var index := floori(elapsed) % count if clips.get_animation_loop(action) else mini(floori(elapsed), count-1)
	var tile := clips.get_frame_texture(action,index) as AtlasTexture
	var cell := Vector2i(tile.region.position / 48.0)
	if sprite.frame_coords != cell: sprite.frame_coords = cell
