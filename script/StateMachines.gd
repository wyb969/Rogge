extends Node
class_name State_Machines

@export var initial_state:State
var state_collection = {}
var current_state:State


func _ready() -> void:
	var children = get_children()
	for child in children:
		print(child.name)
		state_collection[child.name] = child
		child.connect("transition",on_transition_state)
	if initial_state:
		current_state = initial_state
		current_state.enter()
	
	
func _physics_process(delta: float) -> void:
	if(current_state):
		current_state.Physics_process(delta)
	
	
func _update(delta:float) ->void:
	if(current_state):
		current_state.Update(delta)
	
	
func on_transition_state(state:State, new_state_name:String):
	print(new_state_name)
	if(state != current_state):
		return
	
	var new_state = state_collection[new_state_name]
	if new_state:
		current_state.exit()
		current_state = new_state
		current_state.enter()
		print("change state success")
		
	
	
	
