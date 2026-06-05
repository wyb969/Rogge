extends Node2D
@export var player:Node2D
@export var relative_pos:Vector2
@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var area_2d: Area2D = $Area2D



var start_pos:Vector2
var target_pos:Vector2
var weapon_demage:float = 10.0

var flying_out:bool = false
var returning:bool = false
var speed = 800.0
#############################
var max_speed:int=200
var max_distance:int=200
var rotate_speed:float=4.0
var fly_dir:Vector2

func _ready() -> void:
	area_2d.monitoring = false
	if player:
		global_position = player.global_position + relative_pos
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if not flying_out and not returning and player:
		global_position = player.global_position + relative_pos

	if flying_out or returning:
		if returning:
			fly_dir = ((player.global_position + relative_pos) - global_position).normalized()
		global_position = global_position + max_speed*delta*fly_dir
		rotation += rotate_speed*delta


	if flying_out and ((start_pos - global_position).length()>=max_distance):
		flying_out = false
		returning = true

	if returning and ((global_position -  (player.global_position + relative_pos)).length()<=20):
		flying_out = false
		returning = false
		rotation = 0
		area_2d.monitoring = false



func _physics_process(delta: float) -> void:
	pass


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body and body.has_method("get_hit"):
		body.get_hit((body.global_position -global_position).normalized(),weapon_demage)



func _on_attack_timer_timeout() -> void:
	start_attack()


func get_nearest_enemy():
	var enemies = get_tree().get_nodes_in_group("EnemyGroup")
	var nearest = null
	for e in enemies:
		if e:
			nearest = e
			break
	return nearest

func start_attack():
	if flying_out or returning:
		return
	var target_enemy = get_nearest_enemy()
	if not target_enemy:
		return
	start_pos = global_position
	fly_dir = (target_enemy.global_position - global_position).normalized()
	flying_out = true
	returning = false
	area_2d.monitoring = true

func handle_level_up(level:int):
	weapon_demage = weapon_demage * (1.0 + 0.12 * level + 0.015 * level * level)
	max_speed = max_speed * (1.0 + 0.12 * level + 0.015 * level * level)
