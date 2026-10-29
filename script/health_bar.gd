extends ProgressBar

@onready var timer: Timer = $Timer
@onready var demage_bar: ProgressBar = $DemageBar

var health = 0.0
var _shield: float = 0.0
var _max_hp: float = 0.0
var shield_fill: ColorRect

func set_health(new_health) -> void:
	var pre_health = health
	health = new_health
	if health <= 0:
		visible = false
		if shield_fill:
			shield_fill.visible = false
	if health < pre_health:
		timer.start()
	else:
		demage_bar.value = health
	_apply_shield_layout()

func set_shield(amount: float, max_hp: float) -> void:
	_shield = maxf(0.0, amount)
	if max_hp > 0.0:
		_max_hp = max_hp
	_apply_shield_layout()

func init_health(health_val) -> void:
	health = health_val
	_max_hp = float(health_val)
	max_value = health
	value = health
	demage_bar.max_value = health
	demage_bar.value = health
	_apply_shield_layout()

func _apply_shield_layout() -> void:
	if shield_fill == null or demage_bar == null:
		return
	var max_hp := _max_hp if _max_hp > 0.0 else float(max_value)
	var hp := maxf(0.0, float(health))
	if max_hp > 0.0:
		max_value = max_hp
		demage_bar.max_value = max_hp
		value = minf(hp, max_hp)
	if _shield <= 0.05 or hp <= 0.0 or max_hp <= 0.0:
		shield_fill.visible = false
		return
	shield_fill.visible = true
	var width := size.x
	if width < 1.0:
		width = 26.0
	var hp_w := width * (minf(hp, max_hp) / max_hp)
	# Small shields still paint a visible tip. The value itself is not capped.
	var sh_w := clampf(width * (_shield / max_hp), 3.0, width * 2.5)
	shield_fill.position = Vector2(hp_w, 0.0)
	shield_fill.size = Vector2(sh_w, maxf(size.y, 4.0))

func _ready() -> void:
	shield_fill = ColorRect.new()
	shield_fill.name = "ShieldFill"
	shield_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shield_fill.color = Color(0.98, 0.84, 0.18, 0.95)
	shield_fill.visible = false
	shield_fill.z_index = 1
	add_child(shield_fill)

func _process(_delta: float) -> void:
	pass

func _on_timer_timeout() -> void:
	demage_bar.value = health
	_apply_shield_layout()
