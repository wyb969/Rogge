extends Node2D
# One lamp, one world-space shaft pass and one decoration batch. No shadow maps.
const LIGHT_RADIUS := 135.0
const MAX_DECOR_SHADOWS := 32
const GLOW := preload("res://script/combat_lighting.gd")
var lamp: PointLight2D
var shafts: Field
var scenery: Field
var shader_material: ShaderMaterial
var sun_amount := 0.0
var rain_amount := 0.0
var decor_shadows_last := 0
var sun_direction := Vector2(0.65, 0.76)
@onready var weather: Node = get_parent()
@onready var game: Node = weather.get_parent()

class Field:
	extends Node2D
	var lighting: Node2D
	var is_scenery := false
	func _draw() -> void:
		if is_scenery: lighting.draw_scenery(self)
		else:
			var bounds: Rect2 = get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_visible_rect()
			draw_rect(bounds.grow(8), Color.WHITE)

func _ready() -> void:
	lamp = PointLight2D.new()
	lamp.name = "RainLantern"
	lamp.texture = GLOW.glow_texture()
	lamp.texture_scale = LIGHT_RADIUS / 32.0
	lamp.color = GamePalette.WEATHER_LAMP
	lamp.shadow_enabled = false
	lamp.range_z_min = -60
	lamp.range_z_max = 0
	add_child(lamp)
	shafts = Field.new()
	shafts.lighting = self
	shafts.z_index = -4 # Under enemies, player and all attack warnings.
	shader_material = ShaderMaterial.new()
	shader_material.shader = preload("res://shaders/weather_shafts.gdshader")
	shader_material.set_shader_parameter("shaft_color", GamePalette.WEATHER_SUN)
	shafts.material = shader_material
	add_child(shafts)
	scenery = Field.new()
	scenery.lighting = self
	scenery.is_scenery = true
	scenery.z_index = -32 # Ground is -50; decoration art is -30.
	add_child(scenery)
	stop()

func stop() -> void:
	sun_amount = 0
	rain_amount = 0
	lamp.enabled = false
	shafts.hide()
	scenery.hide()
	set_process(false)

func sync() -> void:
	if not weather.running:
		stop()
		return
	var intensity: float = SettingsStore.weather_intensity
	sun_amount = weather._weights[0] * weather.daylight * intensity
	rain_amount = weather._weights[2] * intensity
	sun_direction = weather.sun_direction
	lamp.enabled = rain_amount > 0.001
	lamp.energy = 0.8 * rain_amount
	shader_material.set_shader_parameter("strength", sun_amount)
	shader_material.set_shader_parameter("sun_direction", sun_direction)
	shafts.visible = sun_amount > 0.001
	scenery.show()
	set_process(true)
	_process(0)

func _process(_delta: float) -> void:
	# Position follows the real actor every render frame; no 10 Hz lamp stepping.
	lamp.global_position = game.player.global_position + Vector2(0, 4)
	shader_material.set_shader_parameter("clock", weather.elapsed)
	if shafts.visible: shafts.queue_redraw()
	scenery.queue_redraw()

func projection_at(at: Vector2, allow_lamp: bool = true) -> Vector3:
	var offset: Vector2 = at - lamp.global_position
	var radial := rain_amount * (1.0 - smoothstep(35.0, LIGHT_RADIUS, offset.length())) if allow_lamp else 0.0
	var direction := sun_direction
	if radial > 0.001 and offset.length_squared() > 1.0: direction = offset.normalized()
	return Vector3(direction.x, direction.y, maxf(sun_amount, radial))

func project_sprite(canvas: Node2D, sprite: Node2D, feet: Vector2, allow_lamp: bool = true) -> void:
	if not is_instance_valid(sprite) or not sprite.is_visible_in_tree(): return
	var projection := projection_at(feet, allow_lamp)
	if projection.z <= 0.001: return
	var texture: Texture2D
	var region: Rect2
	var flip := false
	if sprite is Sprite2D:
		texture = sprite.texture
		if texture == null: return
		var size: Vector2 = texture.get_size() / Vector2(sprite.hframes, sprite.vframes)
		region = sprite.region_rect if sprite.region_enabled else Rect2(Vector2(sprite.frame_coords) * size, size)
		flip = sprite.flip_h
	elif sprite is AnimatedSprite2D:
		texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
		if texture == null: return
		region = Rect2(Vector2.ZERO, texture.get_size())
		flip = sprite.flip_h
	else: return
	var size := region.size * sprite.global_scale.abs()
	var direction := Vector2(projection.x, projection.y)
	var side := Vector2(direction.y, -direction.x)
	if flip: side *= -1.0
	# Clamp tall bosses; contact shadow stays separately anchored beneath each actor.
	var length := clampf(size.y * 0.95, 12.0, 70.0)
	canvas.draw_set_transform_matrix(Transform2D(side, -direction * length / maxf(size.y, 1.0), feet))
	canvas.draw_texture_rect_region(texture, Rect2(Vector2(-size.x * 0.5, -size.y), size), region, GamePalette.shadow(0.34 * projection.z))
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)

func draw_scenery(canvas: Node2D) -> void:
	decor_shadows_last = 0
	for sprite in weather._background._decor_sprites:
		if not sprite.visible: continue
		project_sprite(canvas, sprite, sprite.global_position + Vector2(0, 9) * sprite.global_scale)
		decor_shadows_last += 1
		if decor_shadows_last >= MAX_DECOR_SHADOWS: break
