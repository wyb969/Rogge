extends Node2D
@onready var label: Label = $Label
var tween: Tween
var _healing: = false
var _status: = false
var _critical := false
const CRITICAL_GOLD := Color(1.0, 0.79, 0.32)
const STATUS_YELLOW: = Color(1.0, 0.84, 0.25)
const STATUS_RED: = Color(1.0, 0.23, 0.12)

static func is_status_hit(data: Dictionary) -> bool:
	var effect: String = data.get("effect", "")
	return data.get("from_status", false) or effect == "burn" or effect == "freeze" or effect == "poison_trail"

func _ready() -> void :
	add_to_group("damage_popup")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.06, 0.08))
	label.add_theme_color_override("font_color", Color(1, 0.96, 0.83))
	UiFonts.apply_to_label(label, 11, true)

func show_heal(amount_text: String) -> void :
	_healing = true
	label.add_theme_color_override("font_color", Color(0.4, 1, 0.55))
	show_damage(amount_text, Vector2.ZERO, 0, 0)

func show_damage(text: String, _start_pos: Vector2, _height: float, _spread: float, status_damage: bool = false, critical: bool = false) -> void :
	if tween != null and tween.is_valid(): tween.kill()
	_status = status_damage
	_critical = critical and not _healing
	UiFonts.apply_to_label(label, 15 if _critical else 11, true)
	label.add_theme_constant_override("outline_size", 3 if _critical else 2)
	if _status:
		_healing = false
		label.add_theme_color_override("font_color", STATUS_YELLOW)
	elif not _healing: label.add_theme_color_override("font_color", CRITICAL_GOLD if _critical else Color(1, 0.96, 0.83))
	label.text = text + "!" if _critical else text
	label.position = Vector2(-30, -26) if _critical else Vector2(-24, -22)
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2.ONE * (1.28 if _critical else 1.12)
	var sideways: = float((get_instance_id() % 7) - 3) * 1.5
	tween = create_tween().set_parallel(true)
	if _status: tween.tween_property(label, "theme_override_colors/font_color", STATUS_RED, 0.24)
	tween.tween_property(label, "position", label.position + Vector2(sideways, -20 if _healing else -24), 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.13).set_delay(0.21)
	tween.chain().tween_callback(queue_free)
