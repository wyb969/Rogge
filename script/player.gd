extends CharacterBody2D
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var cpu_particles_2d: CPUParticles2D = $CPUParticles2D
@onready var shadow = preload("res://scenes/shadow.tscn")
@onready var weapon: Node2D = $Weapon
@onready var can_dasing_timer: Timer = $Can_Dasing_Timer
@onready var dashing_timer: Timer = $Dashing_Timer
@onready var shadow_timer: Timer = $ShadowTimer

const SPEED = 100.0
const DASH_SPEED = 400.0
var dashing:bool = false
var can_dash:bool = true


func _physics_process(delta: float) -> void:
	get_input()
	
	if Input.is_action_just_pressed("roll") and can_dash:
		can_dash = false
		dashing = true
		can_dasing_timer.start()
		dashing_timer.start()
		shadow_timer.start()
	move_and_slide()
	
func get_input():
	var input_direction = Input.get_vector("left", "right", "up", "down")
	var direction = get_global_mouse_position() - global_position
	playAnimation(direction)
	if dashing:
		velocity = input_direction * DASH_SPEED
	else:
		velocity = input_direction * SPEED		

	if velocity.x!=0 || velocity.y!=0:
		cpu_particles_2d.emitting = true
	
func playAnimation(direction:Vector2):
	direction = direction.normalized()
	var angle = rad_to_deg(direction.angle())
	var snap = snappedf(direction.angle(),PI/6)
	if angle>=-30 and angle<=30:
		animated_sprite_2d.play("right")
	elif angle>=30 and angle<=60:
		animated_sprite_2d.play("right_down")
	elif angle>=60 and angle<=120:
		animated_sprite_2d.play("down")
	elif angle>=120 and angle<=150:
		animated_sprite_2d.play("left_down")
	elif angle>=150 and angle<=180:
		animated_sprite_2d.play("left")
	elif angle>=-180 and angle<=-150:
		animated_sprite_2d.play("left")
	elif angle>=-60 and angle<=-30:
		animated_sprite_2d.play("right_up")
	elif  angle>=-120 and angle<=-60:
		animated_sprite_2d.play("up")
	elif angle>=-150 and angle<=-120:
		animated_sprite_2d.play("left_up")


func _on_shadow_timer_timeout() -> void:
	if velocity.length()<=0.00001:
		return
	var sh = shadow.instantiate()
	get_tree().root.add_child(sh)
	sh.texture = animated_sprite_2d.sprite_frames.get_frame_texture(animated_sprite_2d.animation, animated_sprite_2d.frame)
	sh.global_position = animated_sprite_2d.global_position
	sh.scale =animated_sprite_2d.scale
	var weapon_shadow = shadow.instantiate()
	get_tree().root.add_child(weapon_shadow)
	weapon_shadow.texture = weapon.get_texture()
	weapon_shadow.global_position = weapon.sprite_2d.global_position	
	weapon_shadow.scale = weapon.sprite_2d.scale * weapon.scale
	weapon_shadow.rotation = weapon.sprite_2d.rotation
	weapon_shadow.flip_v = weapon.sprite_2d.flip_v
	weapon_shadow.start_tween()
	sh.start_tween()


func _on_dashing_timer_timeout() -> void:
	dashing = false
	shadow_timer.stop()


func _on_can_dasing_timer_timeout() -> void:
	can_dash = true
