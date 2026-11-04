extends Sprite2D

func _ready() -> void :
	start_tween()

func start_tween():

	modulate = Color(1.35, 1.35, 1.35, 0.82)
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1.2, 1.2, 1.2, 0.0), 0.22)
	tween.tween_callback(queue_free)
