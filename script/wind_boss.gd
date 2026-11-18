extends "res://script/beast_boss.gd"

enum Role{RANGED, MELEE}
const WIND_BLADE: = preload("res://scenes/wind_blade.tscn")
const ROLE_HP: = [2200.0, 2600.0]
const ROLE_NAMES: = ["苍风术隼 · 远程", "疾羽猎隼 · 近程"]
const ROLE_COLORS: = [Color(0.38, 0.78, 1.0), Color(0.98, 0.85, 0.38)]
var role: Role = Role.RANGED
var coordinator: Node
var _shots_fired: = 0
var _orbit_sign: = 1.0

func _death_stain_kind() -> StringName:
	return &"gale_ranged" if role == Role.RANGED else &"gale_melee"

func configure_wind_role(value: int, host: Node) -> void :
	role = value as Role
	coordinator = host
	_orbit_sign = 1.0 if role == Role.RANGED else -1.0

func boss_art_id() -> String:
	return "wind-ranged" if role == Role.RANGED else "wind-melee"

func pose_action() -> StringName:
	if is_dying: return &"defeat"
	if electric_stun_left > 0 or terrain_impulse.left > 0: return &"stun"
	if state == State.WARN: return &"fan_warn" if role == Role.RANGED else &"dive_warn"
	if state == State.ACTIVE:
		if role == Role.RANGED: return &"wind_blades"
		return &"second_dive" if phase == 2 and _extra_dives == 0 else &"dive"
	return super.pose_action()

func _ready() -> void :
	super._ready()
	health_max_value = ROLE_HP[role]
	boss_current_health = health_max_value
	health_bar.init_health(health_max_value)
	state_left = 0.65 if role == Role.RANGED else 1.2
	var fill: = StyleBoxFlat.new()
	fill.bg_color = ROLE_COLORS[role]
	health_bar.add_theme_stylebox_override("fill", fill)
	_update_title()
	_layout_hud()

func _update_title() -> void :
	_title.text = L10n.text(ROLE_NAMES[role]) + (" / II" if phase == 2 else " / I")
	_title.add_theme_color_override("font_color", ROLE_COLORS[role])

func _physics_process(delta: float) -> void :
	if get_tree().paused or is_dying or not is_instance_valid(coordinator) or coordinator._run_closed or not is_instance_valid(player) or player.player_health <= 0:
		return
	if _tick_environment_control(delta): return
	if state == State.APPROACH:
		state_left -= delta
		_move_in_role(delta)
		if state_left <= 0 and coordinator.request_wind_attack(self, role):
			begin_attack()
		queue_redraw()
		return

	if role == Role.RANGED and state == State.ACTIVE:
		state_left -= delta
		if state_left <= 0:
			shapes.clear()
			state = State.RECOVER
			state_left = 0.9 if phase == 2 else 1.15
			coordinator.release_wind_attack(self, role)
		_update_attack_visual()
		queue_redraw()
		return
	if state == State.RECOVER:
		_move_in_role(delta)
	var previous: = state
	super._advance_battle(delta)
	if role == Role.RANGED and previous == State.WARN and state == State.ACTIVE:
		_fire_wind_blades()
	if previous == State.ACTIVE and state == State.RECOVER:
		coordinator.release_wind_attack(self, role)

func _move_in_role(_delta: float) -> void :
	var offset: = player.global_position - global_position
	var distance: = offset.length()
	var dir: = offset.normalized() if distance > 0.01 else Vector2.RIGHT
	var orbit: = dir.orthogonal() * _orbit_sign
	if role == Role.RANGED:
		if distance > 235:
			velocity = dir * 90.0 + orbit * 24.0
		elif distance < 175:
			velocity = - dir * 82.0 + orbit * 22.0
		else:
			velocity = orbit * 62.0
	else:
		velocity = dir * (100.0 if phase == 1 else 118.0) if distance > 72 else orbit * 74.0 - dir * 12.0
	velocity *= poison_slow
	move_and_slide()

func roaming_seconds() -> float:
	return 0.3 if phase == 2 else 0.5

func begin_attack() -> void :
	update_facing_direction(player.global_position)
	shapes.clear()
	dive = false
	_extra_dives = 0
	_move_name = L10n.text("风刃扇击") if role == Role.RANGED else L10n.text("俯冲突袭")
	_orbit_sign = (1.0 if role == Role.RANGED else -1.0) * (1.0 if pattern_index % 2 == 0 else -1.0)
	if role == Role.RANGED:
		var aim: = (player.global_position - global_position).normalized()
		if aim.is_zero_approx():
			aim = Vector2.DOWN
		var count: = 5 if phase == 2 else 3
		for i in count:
			var dir: = aim.rotated((float(i) - float(count - 1) * 0.5) * 0.19)
			shapes.append({"kind": "lane", "a": global_position + dir * (20 * Dimensions.BOSS), "b": global_position + dir * 365, "width": 18.0})
	else:
		_extra_dives = 1 if phase == 2 else 0
		_prepare_dive(player.global_position)
	pattern_index += 1
	_attack_hit = false
	state = State.WARN
	state_left = warning_seconds()
	velocity = Vector2.ZERO
	_update_attack_visual(true)
	queue_redraw()

func warning_seconds() -> float:
	return 0.85 if phase == 2 else 1.05

func _fire_wind_blades() -> void :
	for shape in shapes:
		var blade: = WIND_BLADE.instantiate() as Node2D
		var container: = get_tree().get_first_node_in_group("effect_container")
		if container == null:
			container = get_parent()
		container.add_child(blade)
		var dir: Vector2 = (shape.b - shape.a).normalized()
		blade.launch(shape.a, dir, 165.0 if phase == 2 else 145.0, 58.0 if phase == 2 else 48.0, ROLE_COLORS[role])


		blade.life = (shape.b - shape.a).length() / blade.velocity.length()
		_shots_fired += 1

func _hit() -> void :
	_attack_hit = true
	player.receive_attack(88.0 if phase == 2 else 74.0, self)

func apply_hit(data: Dictionary) -> void :
	var before: = phase
	super.apply_hit(data)
	if (is_dying or before != phase) and is_instance_valid(coordinator):
		coordinator.release_wind_attack(self, role)
	if not is_dying:
		_update_title()

func _layout_hud() -> void :
	if _hud == null or _title == null:
		return
	preload("res://script/boss_hud_layout.gd").fit(_hud,health_bar,_title,_action_label,role)

func refresh_language() -> void:
	super.refresh_language()
	_update_title()

func _cancel_controlled_attack() -> void:
	super._cancel_controlled_attack()
	if is_instance_valid(coordinator): coordinator.release_wind_attack(self,role)
