extends Area2D
const SPEED = 1200
var bullet_damage:int = 100
var has_lightning :bool = true:
	set(value):
		has_lightning  = value

@onready var cpu_particles_2d: CPUParticles2D = $CPUParticles2D
@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
@onready var lighting_chain: Node2D = $LightingChain

@export var chain_lightning_scene: PackedScene
var lightning_damage := 10.0
var lightning_chain_count := 3
var lightning_range := 160.0

var pierce := 0
var hit_enemies := {}

var velocity:Vector2 = Vector2(10,0)
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	global_position = global_position + velocity.normalized() * SPEED * delta

func setVelocity(v:Vector2)->void:
	velocity = v
	global_rotation = velocity.angle()

func setBulletDemage(d:int)->void:
	bullet_damage = d


func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free() # Replace with function body.


func _on_body_entered(body: Node2D) -> void:
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
			"direction":velocity.normalized(),
			"effect": "aws",
			"lightning_damage": bullet_damage * 0.5,
			"chain_count": 3,
			"chain_range": 180.0,
			"duration": 3.0,
			"source": self
	})

	var enemies = get_tree().get_nodes_in_group("EnemyGroup")
	#lighting_chain.cast_lightning(global_position, enemies)
	if has_lightning:
		spawn_chain_lightning(body)

func spawn_chain_lightning(first_enemy: Node2D) -> void:
	print(" chain lightning start ")
	if chain_lightning_scene == null:
		return
	var effect = chain_lightning_scene.instantiate()
	var container := get_tree().get_first_node_in_group("effect_container")
	container.add_child(effect)

	effect.start_chain(first_enemy,{
		"damage": lightning_damage,
		"chain_count": lightning_chain_count,
		"chain_range": lightning_range,
		"enemy_group": "EnemyGroup"
	})

func _on_cpu_particles_2d_finished() -> void:
	queue_free()
