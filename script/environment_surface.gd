extends Node2D
# Shared weather forces: one lookup per actor, no target scans or physics bodies.
const WIND_MAX := 16.0
const REFLECTION_LIMIT := 16
const WIND_STREAK_LIMIT := 48
var wind := Vector2.ZERO
var ice_visual := 0.0
var _travel := Vector2.ZERO
var _last_clock := 0.0
@onready var weather: Node = get_parent()
@onready var game: Node = weather.get_parent()

func _ready() -> void:
	z_index = -35
	stop()

func stop() -> void:
	wind = Vector2.ZERO
	ice_visual = 0
	_travel = Vector2.ZERO
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
	if weather.elapsed < _last_clock: _travel = Vector2.ZERO
	else: _travel += wind * 5.3 * (weather.elapsed - _last_clock)
	_last_clock = weather.elapsed
	visible = weather._weights[4] > 0.001 or ice_visual > 0.001
	set_process(visible)
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

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
	var bounds: Rect2 = get_viewport().get_canvas_transform().affine_inverse()*get_viewport().get_visible_rect()
	bounds = bounds.grow(40)
	var direction := wind.normalized()
	# Fixed world cells: camera translation never drags a gust across the ground.
	var travel: Vector2 = _travel
	var cell := Vector2(210,170)
	var origin := ((bounds.position-travel)/cell).floor()
	var columns := clampi(ceili(bounds.size.x / cell.x)+1,1,8)
	var rows := mini(ceili(bounds.size.y / cell.y)+1,WIND_STREAK_LIMIT/columns)
	for y in rows:
		for x in columns:
			var grid := origin+Vector2(x,y)
			var seed := Vector2(fposmod(grid.x*0.618+grid.y*0.313,1),fposmod(grid.y*0.381+grid.x*0.217,1))
			var p: Vector2 = (grid+seed)*cell+travel
			var length := 16.0+seed.x*30
			draw_line(p,p+direction*length,Color(GamePalette.UI_GREY_ACTIVE,0.23*strength),1.2)
			draw_line(p+direction*length,p+direction*(length+6)+direction.orthogonal()*3,Color(GamePalette.UI_GREY_ACTIVE,0.35*strength),1)
