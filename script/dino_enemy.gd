extends CharacterBody2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sprite_2d: Sprite2D = $Sprite2D


const SPEED = 300.0
const JUMP_VELOCITY = -400.0

func _physics_process(delta: float) -> void:
	if velocity.length()>0:
		animation_player.play("walk")
	
	if velocity.x < 0:
		sprite_2d.flip_h = true
	else:
		sprite_2d.flip_h = false
	move_and_slide()


func get_hit(direction:Vector2, demage:float):
	animation_player.play("hurt")
