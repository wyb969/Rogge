extends Sprite2D
# A cached radial texture stays on the ground, below sprites and held equipment.
var _gradient: GradientTexture2D
func _ready() -> void:
	texture = null
	scale = Vector2.ONE
	position = Vector2(0,17)
	z_index = -3
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0,0.48,0.67,0.82,1])
	ramp.colors = PackedColorArray([Color(GamePalette.PLAYER_CYAN,0.03),Color(GamePalette.PLAYER_CYAN,0.09),Color(GamePalette.PLAYER_CYAN,0.32),Color(GamePalette.PLAYER_CYAN,0.12),Color(GamePalette.PLAYER_CYAN,0)])
	_gradient = GradientTexture2D.new()
	_gradient.width = 64
	_gradient.height = 64
	_gradient.gradient = ramp
	_gradient.fill = GradientTexture2D.FILL_RADIAL
	_gradient.fill_from = Vector2(0.5,0.5)
	_gradient.fill_to = Vector2(1,0.5)
	queue_redraw()
func _draw() -> void:
	if _gradient == null: return
	var impulse = get_parent().terrain_impulse
	var lift: float = impulse.height_ratio()
	var size := Vector2(19,10)*lerpf(1,0.85,lift)
	draw_texture_rect(_gradient,Rect2(-size,size*2),false)
	# Contact shadow never travels upward with the sprite.
	draw_set_transform(Vector2.ZERO,0,Vector2(1,0.38))
	draw_circle(Vector2.ZERO,lerpf(10,6.5,lift),GamePalette.shadow(lerpf(0.40,0.20,lift)))
	draw_set_transform(Vector2.ZERO)
	var landing: float = impulse.landing_strength()
	if landing>0:
		draw_set_transform(Vector2.ZERO,0,Vector2(1,0.52))
		draw_arc(Vector2.ZERO,19+(1-impulse.landing_left/impulse.LAND_SECONDS)*9,0,TAU,32,Color(GamePalette.PLAYER_CYAN,landing*0.35),1.2)
		draw_set_transform(Vector2.ZERO)
