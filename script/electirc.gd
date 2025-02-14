extends Node2D
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

@onready var node_2d: Node2D = $Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	animated_sprite_2d.play("raise")
	animated_sprite_2d.connect("animation_finished",on_animation_finished);


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	node_2d.rotation +=0.01

func on_animation_finished():
	if animated_sprite_2d.animation == "raise":
		animated_sprite_2d.play("start")
	
