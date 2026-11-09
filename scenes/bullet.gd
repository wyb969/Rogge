extends Area2D
const SPEED = 1200
var bullet_damage: int = 100
var has_lightning: bool = true:
	set(value):
		has_lightning = value

@onready var cpu_particles_2d: CPUParticles2D = $CPUParticles2D
@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
@onready var lighting_chain: Node2D = $LightingChain

@export var chain_lightning_scene: PackedScene
var lightning_damage: = 10.0
var lightning_chain_count: = 3
var lightning_range: = 160.0

var pierce: = 0
var hit_enemies: = {}
var life_left: = 3.0
var _light_owner: Node

var velocity: Vector2 = Vector2(10, 0)

func _ready() -> void :
	$Sprite2D.material = GamePalette.ramp_material(&"friendly")
	add_to_group("player_projectile")
	_light_owner = preload("res://script/combat_lighting.gd").find(self)
	if _light_owner != null: _light_owner.register_bullet(self)



func _exit_tree() -> void :
	if is_instance_valid(_light_owner): _light_owner.unregister(self)

func _process(delta: float) -> void :
	pass

func _physics_process(delta: float) -> void :
	life_left -= delta
	if life_left <= 0.0:
		queue_free()
		return
	global_position = global_position + velocity.normalized() * SPEED * delta

func setVelocity(v: Vector2) -> void :
	velocity = v
	global_rotation = velocity.angle()

func setBulletDemage(d: int) -> void :
	bullet_damage = d


func _on_visible_on_screen_notifier_2d_screen_exited() -> void :
	queue_free()


func _on_body_entered(body: Node2D) -> void :
	if body.is_queued_for_deletion():
		return
	if not body.is_in_group("EnemyGroup"):
		return

	if hit_enemies.has(body):
		return
	hit_enemies[body] = true
	if pierce <= 0:
		queue_free()
	else:
		pierce -= 1
	cpu_particles_2d.emitting = true

	if body.has_method("apply_hit"):
		body.apply_hit({
			"damage": bullet_damage, 
			"direction": velocity.normalized(), 
			"effect": "aws", 
			"lightning_damage": bullet_damage * 0.5, 
			"chain_count": 3, 
			"chain_range": 180.0, 
			"duration": 3.0, 
			"source": self
	})

	if has_lightning:
		spawn_chain_lightning(body)

func spawn_chain_lightning(first_enemy: Node2D) -> void :
	if chain_lightning_scene == null:
		return
	var container: = get_tree().get_first_node_in_group("effect_container")
	if container == null: return
	var owner: = container.get_parent()
	var effect: Node2D
	if owner.has_method("acquire_chain_lightning"):
		effect = owner.acquire_chain_lightning()
	else:
		effect = chain_lightning_scene.instantiate()
		container.add_child(effect)
	if effect == null: return

	effect.start_chain(first_enemy, {
		"damage": lightning_damage, 
		"chain_count": lightning_chain_count, 
		"chain_range": lightning_range, 
		"enemy_group": "EnemyGroup"
	})

func _on_cpu_particles_2d_finished() -> void :
	queue_free()
