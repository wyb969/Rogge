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


func show_heal(amount_text: String) -> void:
	if label:
		label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.48, 1))
		label.add_theme_color_override("font_outline_color", Color(0.04, 0.22, 0.08, 1))
	show_damage(amount_text, Vector2.ZERO, 0, 0)

func show_damage(text:String,startPos:Vector2,height:float,spread:float):
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
 
