extends Node2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var label: Label = $LabelContainer/Label
@onready var label_container: Node2D = $LabelContainer
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
	animation_player.play("show_number")
	tween = get_tree().create_tween()
	tween.set_loops(1)
	var end_pos = Vector2(randf_range(-spread,spread),-height) + startPos
	tween.tween_property(label_container,"position",end_pos,0.5).from(startPos)
 
