extends CharacterBody2D
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var cpu_particles_2d: CPUParticles2D = $CPUParticles2D
@onready var shadow = preload("res://scenes/shadow.tscn")
@onready var weapon: Node2D = $Weapon
@onready var can_dasing_timer: Timer = $Can_Dasing_Timer
@onready var dashing_timer: Timer = $Dashing_Timer
@onready var shadow_timer: Timer = $ShadowTimer
@onready var health_bar: ProgressBar = $HealthBar


var max_speed: float = 100.0  
var acceleration: float = 1000.0  
var friction: float = 600.0   
var player_health = 500.0

const SPEED = 100.0
const DASH_SPEED = 400.0
var dashing:bool = false
var can_dash:bool = true
var animation_directions = ["right", "right_down", "down","left_down","left","left_up","up","right_up"]

func _ready() -> void:
	health_bar.init_health(player_health)
	pass

func _physics_process(delta: float) -> void:
	get_input(delta)
	if Input.is_action_just_pressed("roll") and can_dash:
		can_dash = false
		dashing = true
		can_dasing_timer.start()
		dashing_timer.start()
		shadow_timer.start()
	move_and_slide()
	
func get_input(delta: float):
	var input_direction = Input.get_vector("left", "right", "up", "down")
	var direction = get_global_mouse_position() - global_position
	playAnimation(direction)
	
	if dashing:
		max_speed = DASH_SPEED
		acceleration = 1600
	else:
		max_speed = SPEED
		acceleration = 400

	input_direction = input_direction.normalized()
	
	if input_direction != Vector2.ZERO:
		velocity = velocity.move_toward(input_direction * max_speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	if velocity.x!=0 || velocity.y!=0:
		cpu_particles_2d.emitting = true
	
	if velocity.length() <= SPEED:
		shadow_timer.stop()
	
func playAnimation(direction:Vector2):
	direction = direction.normalized()
	var angle = rad_to_deg(direction.angle())
	var snap = snappedf(direction.angle(),PI/4)/ (PI/4)
	var index = wrapi(int(snap), 0, 8)
	animated_sprite_2d.play(animation_directions[index])


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


func _on_can_dasing_timer_timeout() -> void:
	can_dash = true


func _on_area_2d_body_entered(body: Node2D) -> void:
	get_hit()

func get_hit()->void:
	play_hit_tween()
	player_health = player_health - 60
	player_health = max(0,player_health)
	health_bar.set_health(player_health)
	if(player_health<=0):
		die()
	
func play_hit_tween()->void:
	var tween = get_tree().create_tween()
	tween.set_loops(3)
	tween.tween_property(animated_sprite_2d, "modulate", Color.RED, 0.2)	
	tween.tween_property(animated_sprite_2d, "modulate", Color.WHITE, 0.1)	
	tween.tween_property(animated_sprite_2d, "scale",Vector2(2.2,2.2), 0.2)	
	tween.tween_property(animated_sprite_2d, "scale",Vector2(1.68, 1.68), 0.1)	

func die()->void:
	var current_scene = get_tree().current_scene
	get_tree().reload_current_scene()
