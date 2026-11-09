extends Node2D
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

@onready var node_2d: Node2D = $Node2D



func _ready() -> void :
	modulate = GamePalette.FRIENDLY_LIGHT
	animated_sprite_2d.play("raise")
	animated_sprite_2d.connect("animation_finished", on_animation_finished);



func _process(delta: float) -> void :
	node_2d.rotation += 0.01

func on_animation_finished():
	if animated_sprite_2d.animation == "raise":
		animated_sprite_2d.play("start")
