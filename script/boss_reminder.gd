extends Node2D
@onready var label: Label = $CanvasLayer/Label

func _ready() -> void:
	label.modulate.a = 0.0

	var tween := create_tween()

	tween.tween_property(label, "modulate:a", 1.0, 0.2)
	tween.tween_interval(1.4)
	tween.tween_property(label, "modulate:a", 0.0, 0.4)

	await tween.finished
	print("boss reminder free")
	queue_free()
