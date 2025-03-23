extends Node
class_name State

func enter()->void:
	pass
	
func exit()->void:
	pass
	
func Physics_process(delta: float) -> void:
	pass
	
func Update(delta: float) -> void:
	pass
	
signal transition(from: State, new_state_name: String)
