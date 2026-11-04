extends Node2D


const LIFETIME: = 60.0
const COLLECT_RADIUS: = 12.0
var heal_amount: float = 5.0
var player: Node2D
var collected: bool = false
var attracting: bool = false
var age: float = 0.0
var _speed: float = 0.0
var _global_pickup_left: = 0.0
var _halo: Sprite2D
static var _shared_halo: GradientTexture2D
static var _shared_material: CanvasItemMaterial

func configure(amount: float, target: Node2D) -> void :
	heal_amount = amount
	player = target

func _ready() -> void :
	add_to_group("healing_orb")
	z_index = 1
	if _shared_halo == null:
		var gradient: = Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
		gradient.colors = PackedColorArray([Color(0.3, 0.8, 0.48, 0.12), Color(0.18, 0.6, 0.34, 0.06), Color(0.1, 0.4, 0.2, 0)])
		_shared_halo = GradientTexture2D.new()
		_shared_halo.width = 64
		_shared_halo.height = 64
		_shared_halo.fill = GradientTexture2D.FILL_RADIAL
		_shared_halo.fill_from = Vector2(0.5, 0.5)
		_shared_halo.fill_to = Vector2(1.0, 0.5)
		_shared_halo.gradient = gradient
		_shared_material = CanvasItemMaterial.new()
		_shared_material.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
	_halo = Sprite2D.new()
	_halo.texture = _shared_halo
	_halo.z_index = -1
	_halo.scale = Vector2.ONE * 0.42
	_halo.material = _shared_material
	add_child(_halo)

func _draw() -> void :
	draw_circle(Vector2.ZERO, 8.0, Color(0.025, 0.12, 0.08))
	draw_circle(Vector2.ZERO, 6.0, preload("res://script/visual_style.gd").HEAL)
	draw_circle(Vector2(-1, -2), 3.5, Color(0.5, 1.0, 0.68))
	draw_rect(Rect2(-1, -4, 2, 8), Color(0.94, 1.0, 0.94))
	draw_rect(Rect2(-4, -1, 8, 2), Color(0.94, 1.0, 0.94))

func _process(delta: float) -> void :
	age += delta
	if age >= LIFETIME:
		queue_free()
		return
	modulate.a = clampf((LIFETIME - age) / 5.0, 0.0, 1.0)

func start_global_pickup() -> void :
	attracting = true
	_global_pickup_left = 0.6
	age = minf(age, LIFETIME - 1.0)

func _physics_process(delta: float) -> void :
	if collected or (age < 0.18 and _global_pickup_left <= 0) or not is_instance_valid(player):
		return
	if player.player_health <= 0.0:
		return
	var distance: = global_position.distance_to(player.global_position)
	if distance <= COLLECT_RADIUS:
		collect()
		return
	if distance <= player.pickup_range:
		attracting = true
	if _global_pickup_left > 0:

		_speed = maxf(360, distance / maxf(_global_pickup_left, 0.016))
		_global_pickup_left = maxf(0, _global_pickup_left - delta)
		global_position = global_position.move_toward(player.global_position, _speed * delta)
	elif attracting:
		_speed = move_toward(_speed, 360.0, 720.0 * delta)
		global_position = global_position.move_toward(player.global_position, _speed * delta)

func collect() -> float:
	if collected or not is_instance_valid(player) or player.player_health <= 0.0:
		return 0.0

	collected = true
	var feedback: = preload("res://script/combat_feedback.gd").find(self)
	if feedback != null: feedback.pickup(global_position, true)
	var gained: float = player.heal(heal_amount)
	AudioManager.play_healing_pickup()
	remove_from_group("healing_orb")
	queue_free()
	return gained
