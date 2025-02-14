extends Node2D
@onready var area_2d: Area2D = $Area2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_timer_timeout() -> void:
	for b in area_2d.get_overlapping_bodies():
		if b.has_method("get_hit"):
			b.get_hit(Vector2.DOWN.rotated(self.rotation),36 + randi_range(1,10)) # Replace with function body. # Replace with function body.
