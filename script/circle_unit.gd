extends Node2D

var self_rotate_degree:float = 2.0
var weapon_demage:float = 5.0
var current_level:int = 0

func _ready() -> void:
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	rotation = rotation + self_rotate_degree*delta

func set_rotate_degree(degree:float):
	self_rotate_degree = degree

func setLevel(lev:int):
	if(current_level == lev):
		return
	current_level = lev
	weapon_demage = weapon_demage  * (1.0 + 0.12 * current_level + 0.015 * current_level * current_level)

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body and body.has_method("get_hit"):
		body.get_hit((body.global_position -global_position).normalized(),weapon_demage)
