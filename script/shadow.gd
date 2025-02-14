extends Sprite2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	start_tween()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func start_tween():
	var tween = create_tween()
	tween.tween_property(self,"modulate",Color(1,1,1,0.3),0.8)
	tween.tween_property(self,"modulate",Color(0,0,0,0),0.8)
