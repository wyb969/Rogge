extends Node2D
@onready var label: Label = $Label
var tween:Tween

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if tween and !tween.is_running():
		queue_free()


func show_demage(text:String,startPos:Vector2,height:float,spread:float):
	label.text = text
	#animation_player.play("show_number")
	tween = get_tree().create_tween()
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_loops(1)
	#var end_pos = Vector2(randf_range(-spread,spread),-height) + startPos
	#tween.tween_property(label,"position",startPos,0.5).from(startPos)
	tween.parallel().tween_property(label,"scale",Vector2.ONE,0.5).from(Vector2(1.2,1.2))
	tween.finished.connect(Callable(self,"queue_free"))
 
