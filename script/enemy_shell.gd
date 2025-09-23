extends CharacterBody2D
@export var player_reference:CharacterBody2D

var direction:Vector2
var speed : float = 50
var knockback: Vector2 = Vector2.ZERO
var knockback_decay: float = 10.0  # 衰减速度

func set_enemy_data(data:EnemyData)->void:
	var desired_size := Vector2(20, 20)
	$Sprite2D.texture = data.sprite
 
	var tex_size = data.sprite.get_size()         
	if tex_size.x > 0 and tex_size.y > 0:    
		$Sprite2D.scale = desired_size / tex_size
	
func set_elite_status()->void:
	$Sprite2D.material = load("res://shaders/rainbow_outline.tres")
	scale = Vector2(1.25,1.25)

func set_player_ref(player_ref:CharacterBody2D)->void:
	player_reference = player_ref
	
func _physics_process(delta: float) -> void:
	velocity = (player_reference.position - position).normalized()*speed
	
	if knockback.length() > 0.1:
		velocity += knockback
		knockback = knockback.move_toward(Vector2.ZERO, knockback_decay * delta)
	var collision = move_and_collide(velocity*delta)
	if collision:
		if collision.get_collider() is CharacterBody2D:
			var other = collision.get_collider()
			var dir = (global_position - other.global_position).normalized()
			knockback = dir * 10.0   # 击退力度
 
