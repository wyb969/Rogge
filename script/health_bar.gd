extends ProgressBar

@onready var timer: Timer = $Timer
@onready var demage_bar: ProgressBar = $DemageBar

var health=0

func set_health(new_health):
	var pre_health = health
	health = min(max_value,new_health)
	value = health
	
	if(health<=0):
		visible = false
	
	if(health < pre_health):
		timer.start()
	else:
		demage_bar.value = health



func init_health(health_val)->void:
	health = health_val
	max_value = health
	value = health
	demage_bar.max_value = health
	demage_bar.value = health




# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_timer_timeout() -> void:
	demage_bar.value = health # Replace with function body.
