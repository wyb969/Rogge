extends Area2D
const SPEED = 300
var bullet_demage:int = 10
@onready var cpu_particles_2d: CPUParticles2D = $CPUParticles2D
@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D

var velocity:Vector2 = Vector2(10,0)
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	global_position = global_position + velocity

func setVelocity(v:Vector2)->void:
	velocity = v
	global_rotation = velocity.angle()

func setBulletDemage(d:int)->void:
	bullet_demage = d 

func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free() # Replace with function body.


func _on_body_entered(body: Node2D) -> void:
	cpu_particles_2d.emitting = true
	sprite_2d.visible = false
	velocity = Vector2.ZERO
	collision_shape_2d.set_deferred("set_disabled",true)
	if body.has_method("get_hit"):
		body.get_hit(velocity.normalized(),bullet_demage)

func _on_cpu_particles_2d_finished() -> void:
	queue_free()
