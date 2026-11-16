extends Node2D
# Shared weather forces: one lookup per actor, no target scans or physics bodies.
const WIND_MAX := 16.0
const REFLECTION_LIMIT := 16
const WIND_STREAK_LIMIT := 18
const GUST_POINTS := 25
var wind := Vector2.ZERO
var ice_visual := 0.0
var _last_clock := 0.0
var _gusts: Array[Dictionary] = []
var _gust_rng := RandomNumberGenerator.new()
var _gust_live := false
var _ice_tilt := Vector2.ZERO
@onready var weather: Node = get_parent()
@onready var game: Node = weather.get_parent()

func _ready() -> void:
	z_index = -35
	_gust_rng.randomize()
	for i in WIND_STREAK_LIMIT:
		var points := PackedVector2Array()
		points.resize(GUST_POINTS)
		_gusts.append({"at":Vector2.ZERO,"angle":0.0,"phase":0.0,"age":0.0,"life":1.0,"opacity":0.0,"points":points})
	stop()

func stop() -> void:
	wind = Vector2.ZERO
	_gust_live = false
	_ice_tilt = Vector2.ZERO
	ice_visual = 0
	_last_clock = weather.elapsed
	hide()
	set_process(false)
	queue_redraw()

func active() -> bool:
	return not get_tree().paused and weather.running and game.visible and game.process_mode != Node.PROCESS_MODE_DISABLED and game.player.player_health > 0 and not game.trials.blocks_rewards() and not game.spawner._rest_open and not game.spawner._transitioning

func ice_amount() -> float:
	return weather._weights[5] if active() else 0.0

func wind_velocity(weight: float = 1.0) -> Vector2:
	return wind * weight if active() else Vector2.ZERO

func sync() -> void:
	if not weather.running:
		stop()
		return
	ice_visual = weather._weights[5] * SettingsStore.weather_intensity
	var direction := Vector2.RIGHT.rotated(weather.stage * 2.399 + sin(weather.elapsed*0.04)*0.15)
	var gust := 0.45 + 0.55 * (0.5 + 0.5*sin(weather.elapsed*0.9))
	wind = direction * WIND_MAX * gust * weather._weights[4]
	if weather.elapsed < _last_clock:
		_gust_live = false
	var dt: float = maxf(0,weather.elapsed-_last_clock)
	_advance_gusts(dt)
	if weather._weights[5]>0.001: _update_ice_view(dt)
	_last_clock = weather.elapsed
	visible = weather._weights[4] > 0.001 or ice_visual > 0.001
	set_process(visible)
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

func _update_ice_view(delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	var center: Vector2 = camera.get_screen_center_position() if camera != null else game.player.global_position
	var movement: Vector2 = game.player.get_real_velocity()/maxf(100,game.player.effective_move_speed())
	_ice_tilt = _ice_tilt.lerp(movement.limit_length(1),1.0-exp(-7.0*delta))
	weather._background.set_ice_view(center,_ice_tilt,SettingsStore.weather_intensity)

func _spawn_gust(gust: Dictionary, bounds: Rect2, initial: bool = false) -> void:
	gust.at = bounds.position+Vector2(_gust_rng.randf(),_gust_rng.randf())*bounds.size
	gust.angle = wind.angle()+_gust_rng.randf_range(-0.18,0.18)
	gust.phase = _gust_rng.randf_range(0,TAU)
	gust.life = _gust_rng.randf_range(2.4,4.2)
	gust.age = _gust_rng.randf()*gust.life if initial else 0.0
	gust.opacity = _gust_rng.randf_range(0.22,0.42)
	var length := _gust_rng.randf_range(46,88)
	var radius := _gust_rng.randf_range(8,18)
	var hand := 1.0 if _gust_rng.randf()>0.5 else -1.0
	var bend := hand*_gust_rng.randf_range(5,16)
	var turns := _gust_rng.randf_range(0.72,1.10)
	var points: PackedVector2Array = gust.points
	for i in 10:
		var t := float(i)/9.0
		points[i] = Vector2(t*length,pow(sin(t*PI),2)*bend)
	for i in 15:
		var t := float(i+1)/15.0
		var angle := -PI*0.5+t*TAU*turns
		var r := radius*lerpf(1.0,0.36,t)
		points[i+10] = Vector2(length+cos(angle)*r,hand*(radius+sin(angle)*r))
	gust.points = points

func _advance_gusts(delta: float) -> void:
	if weather._weights[4]*SettingsStore.weather_intensity <= 0.001:
		_gust_live = false
		return
	var bounds: Rect2 = get_viewport().get_canvas_transform().affine_inverse()*get_viewport().get_visible_rect()
	bounds = bounds.grow(80)
	for gust in _gusts:
		if not _gust_live: _spawn_gust(gust,bounds,true)
		else:
			gust.age += delta
			gust.at += wind*5.3*delta
			if gust.age >= gust.life or not bounds.grow(160).has_point(gust.at): _spawn_gust(gust,bounds)
	_gust_live = true

func _reflection(canvas: Node2D, sprite: Node2D, feet: Vector2, alpha: float) -> void:
	if not is_instance_valid(sprite) or not sprite.is_visible_in_tree(): return
	var texture: Texture2D
	var region: Rect2
	var flip := false
	if sprite is Sprite2D:
		texture = sprite.texture
		if texture == null: return
		var frame_size: Vector2 = texture.get_size()/Vector2(sprite.hframes,sprite.vframes)
		region = sprite.region_rect if sprite.region_enabled else Rect2(Vector2(sprite.frame_coords)*frame_size,frame_size)
		flip = sprite.flip_h
	elif sprite is AnimatedSprite2D:
		texture = sprite.sprite_frames.get_frame_texture(sprite.animation,sprite.frame)
		if texture == null: return
		region = Rect2(Vector2.ZERO,texture.get_size())
		flip = sprite.flip_h
	else: return
	var size := region.size * sprite.global_scale.abs()
	canvas.draw_set_transform_matrix(Transform2D(Vector2(-1 if flip else 1,0),Vector2(0,-0.45),feet))
	canvas.draw_texture_rect_region(texture,Rect2(Vector2(-size.x*0.5,-size.y),size),region,Color(GamePalette.ICE_REFLECTION,alpha))
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)

func _draw() -> void:
	if not weather.running: return
	if ice_visual > 0.001 and game.get("combat_lighting") != null:
		_reflection(self,game.player.animated_sprite_2d,game.player.global_position+Vector2(0,17),0.28*ice_visual)
		var lights: Node = game.combat_lighting
		for i in mini(REFLECTION_LIMIT,lights._shadow_count):
			var actor: Node2D = lights._shadows[i]
			if not lights._visible(actor): continue
			_reflection(self,lights._shadow_sprites[i],actor.global_position+Vector2(0,lights._shadow_feet[i]),0.2*ice_visual)
	var strength: float = weather._weights[4] * SettingsStore.weather_intensity
	if strength <= 0.001: return
	for gust in _gusts:
		var t: float = clampf(gust.age/gust.life,0,1)
		var fade: float = smoothstep(0.0,0.18,t)*(1.0-smoothstep(0.68,1.0,t))
		var angle: float = gust.angle+sin(gust.phase+gust.age*1.7)*0.12
		draw_set_transform(gust.at,angle)
		draw_polyline(gust.points,Color(GamePalette.UI_GREY_ACTIVE,gust.opacity*fade*strength),1.2,true)
	draw_set_transform(Vector2.ZERO)
