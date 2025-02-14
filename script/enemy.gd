extends CharacterBody2D
@export var player:Node2D
const SPEED = 30.0
@onready var enemy: Node2D = $"."
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
var health:float = 100.0
@onready var demage_text = preload("res://scenes/demage_text.tscn")
@onready var demage_point: Node2D = $DemagePoint
var tween:Tween
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var coin = preload("res://scenes/coin.tscn")
@onready var health_bar: ProgressBar = $HealthBar

func _ready() -> void:
	health_bar.init_health(health)

func _physics_process(delta: float) -> void:
	if health<0:
		return
	if player:
		var pos = player.global_position
		velocity = (pos - global_position).normalized() * SPEED
		move_and_slide()
	if velocity.x <0:
		animated_sprite_2d.flip_h = true
	else:
		animated_sprite_2d.flip_h = false

func get_hit(direction:Vector2, demage:float):
	play_hit_tween(direction)
	var d = demage_text.instantiate()
	add_child(d)
	d.set_scale(Vector2(0.4,0.4))
	d.show_demage(str(demage),demage_point.position,randf_range(-3,-10),randf_range(0,90))
	take_damge(demage)

func play_hit_tween(direction:Vector2):
	tween = get_tree().create_tween()
	tween.set_loops(1)
	tween.tween_property(enemy, "position", global_position  , 0.1)
	tween.tween_property(enemy, "position", global_position + direction *8 , 0.1)
	tween.tween_property(animated_sprite_2d, "modulate", Color.RED, 0.2)	
	tween.tween_property(animated_sprite_2d, "modulate", Color.WHITE, 0.1)	


func set_player(body:Node2D):
	player = body

func take_damge(damge:float):
	health-=damge
	if health<=0:
		death()
	if health_bar:
		health_bar.set_health(int(health))

func death():
	print("death---")
	animated_sprite_2d.stop();
	animation_player.play("death")
	
	
func spawn_coin():
	var main = get_tree().current_scene
	var instance = coin.instantiate()
	instance.global_position = global_position 
	main.call_deferred("add_child",instance)
