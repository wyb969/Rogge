extends Node2D
@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var cool_down_timer: Timer = $CoolDownTimer
@onready var fire_point: Node2D = $Sprite2D/FirePoint
@export var bullet:PackedScene
@onready var muzzle_flash: CPUParticles2D = $Sprite2D/MuzzleFlash
@onready var bullet_shell: CPUParticles2D = $Sprite2D/BulletShell
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var line_2d: Line2D = $Line2D

var cool_down:bool = true
const BULLET_SPEED = 10
var demage:int = 8
var line_count = 10

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	line_2d.clear_points()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var mouse_pos = get_global_mouse_position()
	var sprite_pos = sprite_2d.global_position
	var dir_vector = (mouse_pos - sprite_pos).normalized()
	sprite_2d.look_at(mouse_pos)
	if dir_vector.x<0:
		sprite_2d.flip_v = true
	else:
		sprite_2d.flip_v = false	
	
	if Input.is_action_pressed("click"):
		shoot()
	line_2d.add_point(fire_point.global_position)
	if (line_2d.get_point_count()>40):
		line_2d.remove_point(0)
	
func shoot()->void:
	if(!cool_down): 
		return
	cool_down = false
	cool_down_timer.start()
	animation_player.play("shoot")
	var main = get_tree().current_scene
	var instance = bullet.instantiate()
	main.add_child(instance)
	instance.global_position = fire_point.global_position 
	var v = Vector2.RIGHT.rotated(sprite_2d.global_rotation) * BULLET_SPEED
	instance.setVelocity(v)
	instance.setBulletDemage(demage + randi_range(1,10))
	var rotation_rad = v.angle()
	muzzle_flash.angle_min = rad_to_deg(-rotation_rad)
	muzzle_flash.angle_max = rad_to_deg(-rotation_rad)
	bullet_shell.emitting = true
	muzzle_flash.emitting = true

func get_texture() -> Texture2D:
	var t = sprite_2d.texture
	return t

func _on_cool_down_timer_timeout() -> void:
	cool_down = true 
