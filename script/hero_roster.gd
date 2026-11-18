extends RefCounted

const TITLES := ["游方客", "风信使", "机修师", "星灯学徒"]
const START_CARDS := ["pickup_up", "speed_up", "drone_up", "rune_bolt"]
const FRAMES: Array[SpriteFrames] = [
	preload("res://rogge_art/players/A/animations.tres"),
	preload("res://rogge_art/players/B/animations.tres"),
	preload("res://rogge_art/players/C/animations.tres"),
	preload("res://rogge_art/players/D/animations.tres"),
]
