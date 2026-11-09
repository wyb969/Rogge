extends "res://script/enemy_shell.gd"

const LIFETIME: = 22.0
var age: = 0.0
var _caption: Label
var _caption_second: = -1
var _maximum_health: = 1.0

func _ready() -> void :
	super._ready()
	_maximum_health = health
	add_to_group("EnemyGroup")
	add_to_group("loot_courier")
	_caption = Label.new()
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.position = Vector2(-65, -32)
	_caption.size = Vector2(130, 22)
	_caption.add_theme_color_override("font_color", GamePalette.FRIENDLY_LIGHT)
	_caption.add_theme_color_override("font_outline_color", GamePalette.INK)
	_caption.add_theme_constant_override("outline_size", 2)
	UiFonts.apply_to_label(_caption, 10, true)
	add_child(_caption)
	_sync_caption()

func _draw() -> void :
	super._draw()
	draw_rect(Rect2(-15, -18, 30, 3), GamePalette.alpha(GamePalette.INK, 0.95))
	draw_rect(Rect2(-14, -17, 28 * clampf(health / maxf(_maximum_health, 1), 0, 1), 1), GamePalette.FRIENDLY_CYAN)

func _sync_caption() -> void :
	var left: = maxi(0, int(ceil(LIFETIME - age)))
	if left == _caption_second: return
	_caption_second = left
	_caption.text = "宝囊精 · %ds" % left

func _physics_process(delta: float) -> void :
	if _death_started or not is_instance_valid(player_reference): return
	var owner: = _game_owner()
	if owner != null and (owner.spawner._boss_fight_active or owner.spawner._rest_open or owner.trials.blocks_rewards()):
		queue_free()
		return
	_update_statuses(delta)
	if _death_started: return
	age += delta
	if age >= LIFETIME:
		queue_free()
		return
	_sync_caption()


	var away: = global_position - player_reference.global_position
	var dist: = away.length()
	var dir: = away.normalized() if dist > 0.01 else Vector2.UP
	var steering: = dir if dist < 185 else dir.orthogonal() * sin(age * 2.0)
	if dist > 255: steering = - dir * 0.5
	velocity = steering.limit_length() * speed * status_move_scale()
	if age < 0.8: velocity = Vector2.ZERO
	_apply_crowd_motion(delta)
	move_and_collide(velocity * delta)
	_face( - dir)
	_apply_move_juice(delta)
	queue_redraw()

func spaw_icon() -> void :
	var owner: = _game_owner()
	if owner != null: owner.variety.reward_courier(global_position)
