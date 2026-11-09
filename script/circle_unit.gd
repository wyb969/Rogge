extends Node2D

var self_rotate_degree: float = 2.0
var weapon_demage: float = 5.0
var current_level: int = 0

func _ready() -> void :
	$Sprite2D.material = preload("res://script/visual_style.gd").book_material()
	$Sprite2D.scale = Vector2.ONE * 0.75


func _process(delta: float) -> void :
	rotation = rotation + self_rotate_degree * delta

func set_rotate_degree(degree: float):
	self_rotate_degree = degree

func setLevel(lev: int, cards: int = 1) -> void :
	current_level = maxi(0, lev)


	weapon_demage = 5.0 * (1.0 + 0.12 * current_level + 0.015 * current_level * current_level) * (1.0 + 0.15 * maxi(cards - 1, 0))

func _on_area_2d_body_entered(body: Node2D) -> void :
	if body.has_method("apply_hit"):
		body.apply_hit({
			"damage": weapon_demage, 
			"direction": (body.global_position - global_position).normalized(), 
			"source": self
	})
