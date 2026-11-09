extends Node2D

const MAX_BULLETS: = 64
const MAX_DRONES: = 16
const BULLET_LIGHTS: = 8
const BEAM_LIGHTS: = 4
const ORB_LIGHTS: = 8
const MAX_SHADOWS: = 64
const MAX_FLASHES: = 8
const MAX_RINGS: = 6
const ENEMY: = preload("res://script/enemy_shell.gd")
const INK: = GamePalette.INK
const CYAN: = GamePalette.FRIENDLY_CYAN
const GOLD: = GamePalette.FRIENDLY_CYAN
static var _texture: GradientTexture2D
static var _additive: CanvasItemMaterial
var _bullets: Array[Node2D] = []
var _drones: Array[Node2D] = []
var _orbs: Array[Node2D] = []
var _cells: Array[Vector2i] = []
var _shadows: Array[Node2D] = []
var _shadow_sizes: = PackedVector2Array()
var _shadow_feet: = PackedFloat32Array()
var _flashes: Array[Dictionary] = []
var _shadow_count: = 0
var _orb_count: = 0
var _flash_slot: = 0
var _refresh_left: = 0.0
var _running: = false
var _bounds: = Rect2()
var _canvas: = Transform2D.IDENTITY
var _sun: = Vector2(0.9, 0.35)
var _shadow_alpha: = 0.24
var _emission: = 1.0
var light_quads_last: = 0
var beams_last: = 0
var rings_last: = 0
var shadows_last: = 0
var _fields: Array[Node2D] = []
@onready var game: Node = get_parent()

class Field:
	extends Node2D
	var owner_light: Node2D
	var kind: = 0
	func _draw() -> void : owner_light.draw_field(self, kind)

static func find(actor: Node) -> Node:
	var feedback: = preload("res://script/combat_feedback.gd").find(actor)
	return feedback.get_parent().get("combat_lighting") if feedback != null else null

static func glow_texture() -> Texture2D:
	if _texture == null:
		var gradient: = Gradient.new()
		gradient.offsets = PackedFloat32Array([0, 0.22, 0.55, 1])
		gradient.colors = PackedColorArray([GamePalette.alpha(GamePalette.PLAYER_DAMAGE_WHITE, 1), GamePalette.alpha(GamePalette.PLAYER_DAMAGE_WHITE, 0.65), GamePalette.alpha(GamePalette.PLAYER_DAMAGE_WHITE, 0.15), GamePalette.alpha(GamePalette.PLAYER_DAMAGE_WHITE, 0)])
		_texture = GradientTexture2D.new()
		_texture.width = 64
		_texture.height = 64
		_texture.fill = GradientTexture2D.FILL_RADIAL
		_texture.fill_from = Vector2(0.5, 0.5)
		_texture.fill_to = Vector2(1, 0.5)
		_texture.gradient = gradient
	return _texture

func _ready() -> void :
	glow_texture()
	if _additive == null:
		_additive = CanvasItemMaterial.new()
		_additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_orbs.resize(ORB_LIGHTS)
	_cells.resize(ORB_LIGHTS)
	_shadows.resize(MAX_SHADOWS)
	_shadow_sizes.resize(MAX_SHADOWS)
	_shadow_feet.resize(MAX_SHADOWS)
	for _i in MAX_FLASHES: _flashes.append({"at": Vector2.ZERO, "direction": Vector2.RIGHT, "anchor": null, "left": 0.0})
	for kind in 3:
		var field: = Field.new()
		field.kind = kind
		field.owner_light = self
		field.z_index = [-8, -6, -1][kind]
		if kind == 2: field.material = _additive
		add_child(field)
		_fields.append(field)
	reset()

func register_bullet(actor: Node2D) -> void :
	if _bullets.size() < MAX_BULLETS: _bullets.append(actor)
func register_drone(actor: Node2D) -> void :
	if _drones.size() < MAX_DRONES: _drones.append(actor)
func unregister(actor: Node2D) -> void :
	_bullets.erase(actor)
	_drones.erase(actor)

func reset() -> void :
	_running = false
	_bullets.clear()
	_drones.clear()
	clear_flashes()
	_flash_slot = 0
	light_quads_last = 0
	beams_last = 0
	rings_last = 0
	shadows_last = 0
	_shadow_count = 0
	_orb_count = 0
	for i in MAX_SHADOWS: _shadows[i] = null
	for i in ORB_LIGHTS: _orbs[i] = null
	for field in _fields:
		field.hide()
		field.queue_redraw()
	set_process(false)

func clear_flashes() -> void :
	for flash in _flashes:
		flash.left = 0.0
		flash.anchor = null

func begin_run() -> void :
	_running = true
	_refresh_left = 0
	for field in _fields: field.show()
	set_process(true)

func muzzle(at: Vector2, direction: Vector2, anchor: Node2D = null) -> void :
	if not _running: return
	var flash: = _flashes[_flash_slot]
	flash.at = at
	flash.direction = direction
	flash.anchor = anchor
	flash.left = 0.1
	_flash_slot = (_flash_slot + 1) % MAX_FLASHES

func _visible(actor) -> bool:


	return is_instance_valid(actor) and not actor.is_queued_for_deletion() and _bounds.has_point(_canvas * actor.global_position)

func _refresh_sources() -> void :
	_orb_count = 0
	for orb in game._healing_actors:
		if not _visible(orb) or orb.collected: continue
		var cell: = Vector2i((orb.global_position / 48).floor())
		var duplicate: = false
		for i in _orb_count:
			if _cells[i] == cell: duplicate = true;break
		if duplicate: continue
		_orbs[_orb_count] = orb
		_cells[_orb_count] = cell
		_orb_count += 1
		if _orb_count == ORB_LIGHTS: break
	_shadow_count = 0
	var examined: = 0
	for entry in CombatTargets._entries:
		examined += 1
		if examined > 192: break
		var actor: Node2D = entry.actor
		if not CombatTargets._live(entry, &"EnemyGroup") or not game.is_ancestor_of(actor) or not _visible(actor): continue
		var size: = Vector2(8, 3)
		var foot: = 11.0
		if actor.get_script() == ENEMY:
			size *= clampf(absf(actor.global_scale.x), 0.5, 2)
			foot *= clampf(absf(actor.global_scale.y), 0.5, 2)
		elif actor.has_signal("boss_defeated") and actor.fight_stage <= 2:
			size = Vector2(33, 9) if actor.fight_stage == 1 else Vector2(25, 7)
			foot = 54 if actor.fight_stage == 1 else 35
		else: continue
		_shadows[_shadow_count] = actor
		_shadow_sizes[_shadow_count] = size
		_shadow_feet[_shadow_count] = foot
		_shadow_count += 1
		if _shadow_count == MAX_SHADOWS: break

func _process(delta: float) -> void :
	if not _running or get_tree().paused: return
	_bounds = get_viewport().get_visible_rect().grow(90)
	_canvas = get_viewport().get_canvas_transform()
	var daylight: float = game.weather.daylight
	_sun = Vector2(0.9, 0.35).rotated(sin(game.weather.solar_phase * TAU) * 0.35).normalized()
	_shadow_alpha = lerpf(0.15, 0.3, daylight) * (0.7 if game.weather.current_weather == 1 else 1.0)
	_emission = lerpf(1.2, 0.85, daylight)
	_refresh_left -= delta
	if _refresh_left <= 0:
		_refresh_left = 0.1
		_refresh_sources()
	for flash in _flashes:
		flash.left = maxf(0, flash.left - delta)
		if flash.left == 0: flash.anchor = null
	for field in _fields: field.queue_redraw()

func _halo(canvas: Node2D, at: Vector2, size: Vector2, color: Color) -> void :
	canvas.draw_texture_rect(_texture, Rect2(at - size, size * 2), false, color)
	light_quads_last += 1

func draw_field(canvas: Node2D, kind: int) -> void :
	if not _running: return
	if kind == 0:
		shadows_last = 0
		var offset: = _sun * lerpf(1, 6, game.weather.daylight)
		_halo(canvas, game.player.global_position + Vector2(0, 17) + offset, Vector2(13, 4), Color(INK, _shadow_alpha))
		shadows_last += 1
		for i in _shadow_count:
			var actor: = _shadows[i]
			if not _visible(actor): continue
			if actor.get_script() == ENEMY and actor.archetype == EnemyData.Archetype.DASHER and (actor.is_dashing or actor.dash_windup > 0): continue
			_halo(canvas, actor.global_position + Vector2(0, _shadow_feet[i]) + offset, _shadow_sizes[i], Color(INK, _shadow_alpha))
			shadows_last += 1
		var flying: = 0
		for drone in _drones:
			if not _visible(drone): continue
			_halo(canvas, drone.global_position + Vector2(0, 12) + offset, Vector2(8, 2.5), Color(INK, _shadow_alpha * 0.6 * drone.modulate.a))
			shadows_last += 1
			flying += 1
			if flying == BEAM_LIGHTS: break
		return
	if kind == 1: light_quads_last = 0
	var bullets: = 0
	for actor in _bullets:
		if not _visible(actor): continue
		var p: = actor.global_position
		var scale_light: = clampf(absf(actor.global_scale.x) / 0.4, 0.75, 1.8)
		if kind == 1:
			_halo(canvas, p, Vector2(16, 10) * scale_light, GamePalette.alpha(GamePalette.FRIENDLY_CYAN, 0.11 * _emission))
		else:
			var dir: Vector2 = actor.velocity.normalized()
			canvas.draw_set_transform(p, dir.angle())
			_halo(canvas, Vector2.ZERO, Vector2(13, 5) * scale_light, GamePalette.alpha(GamePalette.FRIENDLY_LIGHT, 0.22))
			canvas.draw_line(Vector2(-7, 0), Vector2(4, 0), GamePalette.alpha(GamePalette.FRIENDLY_LIGHT, 0.7), 1.1, false)
			canvas.draw_set_transform(Vector2.ZERO)
		bullets += 1
		if bullets == BULLET_LIGHTS: break
	var beams: = 0
	for actor in _drones:
		if not _visible(actor) or actor.laser_time_left <= 0 or not actor.laser_line.visible: continue
		var a: Vector2 = actor.laser_line.get_point_position(0)
		var b: Vector2 = actor.laser_line.get_point_position(1)
		canvas.draw_line(a, b, Color(CYAN, 0.065 * _emission if kind == 1 else 0.16), 15 if kind == 1 else 6, false)
		_halo(canvas, b, Vector2.ONE * (17 if kind == 1 else 8), Color(CYAN, 0.12 if kind == 1 else 0.24))
		beams += 1
		if beams == BEAM_LIGHTS: break
	beams_last = beams
	for i in _orb_count:
		var actor: = _orbs[i]
		if not _visible(actor) or actor.collected: continue
		_halo(canvas, actor.global_position, Vector2.ONE * (23 if kind == 1 else 12), GamePalette.alpha(GamePalette.PICKUP_GREEN, (0.16 * _emission if kind == 1 else 0.2) * actor.modulate.a))
	for flash in _flashes:
		if flash.left <= 0: continue
		var at: Vector2 = flash.anchor.global_position if is_instance_valid(flash.anchor) else flash.at
		var strength: float = flash.left / 0.1
		_halo(canvas, at, Vector2.ONE * (27 if kind == 1 else 11), Color(GOLD, strength * (0.14 if kind == 1 else 0.48)))
		if kind == 2:
			var dir: Vector2 = flash.direction
			canvas.draw_line(at - dir * 3, at + dir * 10, GamePalette.alpha(GamePalette.FRIENDLY_LIGHT, strength * 0.8), 2, false)
	if kind == 2: _draw_rings(canvas)

func _ring_glow(canvas: Node2D, at: Vector2, radius: float, color: Color, alpha: float) -> void :
	canvas.draw_arc(at, radius, 0, TAU, 40, Color(color, alpha * 0.07), 8, false)
	canvas.draw_arc(at, radius, 0, TAU, 40, Color(color, alpha * 0.2), 3, false)
	canvas.draw_arc(at, radius, 0, TAU, 40, Color(color, alpha * 0.6), 1, false)

func _draw_rings(canvas: Node2D) -> void :
	rings_last = 0
	for pulse in game.variety._pulses:
		if pulse.left <= 0 or not _bounds.has_point(_canvas * pulse.at): continue
		_ring_glow(canvas, pulse.at, pulse.radius, CYAN if pulse.wind else GOLD, pulse.left / 0.32)
		rings_last += 1
		if rings_last == MAX_RINGS: return
	for ring in game.combat_feedback.rings:
		if not _bounds.has_point(_canvas * ring.p): continue
		var t: float = 1 - ring.left / ring.life
		_ring_glow(canvas, ring.p, lerpf(3, ring.radius, 1 - pow(1 - t, 3)), ring.color, (1 - t) * 0.5)
		rings_last += 1
		if rings_last == MAX_RINGS: return
