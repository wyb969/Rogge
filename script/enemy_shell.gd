extends CharacterBody2D
@export var player_reference: CharacterBody2D
@onready var sprite_2d: Sprite2D = $Sprite2D

@onready var damage_text = preload("res://scenes/damage_text.tscn")
@onready var coin = preload("res://scenes/coin.tscn")
const PROJECTILE_SCENE := preload("res://scenes/enemy_projectile.tscn")

var direction: Vector2
var speed: float = 50
var knockback: Vector2 = Vector2.ZERO
var knockback_decay: float = 10.0
var health: float = 10
var damage: float = 2
var is_elite: bool = false
var tween: Tween
var hurt_tween: Tween
signal death_signal

var archetype: EnemyData.Archetype = EnemyData.Archetype.CHASER
var defense: float = 0.0
var body_scale: float = 1.0
var contact_damage: float = 46.0
var contact_cooldown: float = 0.8
var contact_radius: float = 26.0
var contact_timer: float = 0.15
var dash_speed: float = 340.0
var dash_cooldown: float = 1.25
var dash_timer: float = 0.4
var dash_windup: float = 0.0
var dash_time_left: float = 0.0
var is_dashing: bool = false
var dash_dir: Vector2 = Vector2.ZERO
var preferred_range: float = 200.0
var projectile_damage: float = 36.0
var projectile_speed: float = 240.0
var attack_cooldown: float = 1.4
var attack_timer: float = 0.55
var shot_windup: float = 0.0
var shots_fired: int = 0
var slam_windup: float = 0.0
var slam_time_left: float = 0.0
var slam_dir: Vector2 = Vector2.ZERO
var marker_color: Color = Color(0.8, 0.8, 0.85, 1)
var tag_text: String = "MOB"

# --- Status: burn ---
var burn_stacks: int = 0
var burn_dps: float = 2.0
var burn_tick: float = 0.0
const MAX_BURN_STACKS := 10
const BURN_SPREAD_RADIUS := 78.0

# --- Status: freeze ---
var freeze_time: float = 0.0
var freeze_slow: float = 0.5
var base_modulate: Color = Color.WHITE

func _ready() -> void:
	_build_tag()
	queue_redraw()
	var base := Vector2(body_scale, body_scale)
	scale = base
	if sprite_2d:
		sprite_2d.modulate = base_modulate
	tween = create_tween()
	tween.bind_node(self)
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_loops()
	tween.tween_property(self, "scale", base * 1.08, 0.2)
	tween.tween_property(self, "scale", base, 0.4)

func _draw() -> void:
	draw_circle(Vector2(0, 14), 3.4, marker_color)

func deals_own_contact() -> bool:
	return true

func _build_tag() -> void:
	if has_node("ArchetypeTag"):
		return
	var tag := Label.new()
	tag.name = "ArchetypeTag"
	tag.text = ("!" if is_elite else "") + tag_text
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.z_index = 30
	tag.position = Vector2(-22, -32)
	var inv := 1.0 / maxf(body_scale, 0.2)
	tag.scale = Vector2(inv, inv)
	UiFonts.apply_to_label(tag, 12, true)
	tag.add_theme_color_override("font_color", marker_color)
	tag.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	tag.add_theme_constant_override("outline_size", 4)
	add_child(tag)

func set_enemy_data(data: EnemyData) -> void:
	if data == null:
		return
	var desired_size := Vector2(20, 20)
	if data.sprite:
		$Sprite2D.texture = data.sprite
		var tex_size = data.sprite.get_size()
		if tex_size.x > 0 and tex_size.y > 0:
			$Sprite2D.scale = desired_size / tex_size
	health = data.health
	damage = data.damage
	archetype = data.archetype
	speed = data.move_speed
	defense = clampf(data.defense, 0.0, 0.75)
	body_scale = maxf(data.body_scale, 0.4)
	base_modulate = data.tint
	marker_color = data.marker_color
	tag_text = data.tag_text()
	contact_damage = data.contact_damage
	contact_cooldown = data.contact_cooldown
	contact_radius = data.contact_radius
	dash_speed = data.dash_speed
	dash_cooldown = data.dash_cooldown
	preferred_range = data.preferred_range
	projectile_damage = data.projectile_damage
	projectile_speed = data.projectile_speed
	attack_cooldown = data.attack_cooldown
	attack_timer = minf(0.55, attack_cooldown)
	dash_timer = 0.35

func set_elite_status() -> void:
	is_elite = true
	var sprite: Sprite2D = $Sprite2D
	var mat: ShaderMaterial = load("res://shaders/rainbow_outline.tres").duplicate()
	var hf := maxi(1, sprite.hframes)
	var vf := maxi(1, sprite.vframes)
	# Single-frame / full-texture elites keep default (0) and use REGION_RECT.
	if hf > 1 or vf > 1:
		var fw := 1.0 / float(hf)
		var fh := 1.0 / float(vf)
		mat.set_shader_parameter("frame_uv_rect", Vector4(0.0, 0.0, fw, fh))
	sprite.material = mat
	body_scale *= 1.28
	health *= 1.75
	contact_damage *= 1.2
	projectile_damage *= 1.15
	tag_text = "!" + tag_text

func setHealth(hp: float) -> void:
	health = hp

func setDamage(dg: float) -> void:
	damage = dg

func scale_offense(mult: float) -> void:
	damage *= mult
	contact_damage *= mult
	projectile_damage *= mult

func set_player_ref(player_ref: CharacterBody2D) -> void:
	player_reference = player_ref

func is_frozen() -> bool:
	return freeze_time > 0.0

func _physics_process(delta: float) -> void:
	if !is_instance_valid(player_reference):
		return

	_update_statuses(delta)
	contact_timer = maxf(0.0, contact_timer - delta)

	var to_player := player_reference.global_position - global_position
	var dist := to_player.length()
	var dir := to_player / dist if dist > 0.001 else Vector2.ZERO
	var move_speed := speed
	if is_frozen():
		move_speed *= freeze_slow

	match archetype:
		EnemyData.Archetype.DASHER:
			_steer_dasher(delta, dir, dist, move_speed)
		EnemyData.Archetype.TANK:
			_steer_tank(delta, dir, dist, move_speed)
		EnemyData.Archetype.RANGED:
			_steer_ranged(delta, dir, dist, move_speed)
		_:
			_steer_chaser(dir, move_speed)

	if knockback.length() > 0.1:
		velocity += knockback
		knockback = knockback.move_toward(Vector2.ZERO, knockback_decay * delta)
	var collision = move_and_collide(velocity * delta)
	if collision:
		if collision.get_collider() is CharacterBody2D:
			var other = collision.get_collider()
			var away = (global_position - other.global_position).normalized()
			knockback = away * 10.0

	if is_instance_valid(player_reference):
		_try_contact(global_position.distance_to(player_reference.global_position))
	_face(dir)

func _steer_chaser(dir: Vector2, move_speed: float) -> void:
	velocity = dir * move_speed

func _steer_dasher(delta: float, dir: Vector2, dist: float, move_speed: float) -> void:
	if is_dashing:
		dash_time_left -= delta
		var dash_mul := freeze_slow if is_frozen() else 1.0
		velocity = dash_dir * dash_speed * dash_mul
		if sprite_2d:
			sprite_2d.modulate = Color(1.7, 0.55, 0.35, 1)
		if dash_time_left <= 0.0:
			is_dashing = false
			dash_timer = dash_cooldown
			if sprite_2d and freeze_time <= 0.0 and burn_stacks <= 0:
				sprite_2d.modulate = base_modulate
		return

	if dash_windup > 0.0:
		dash_windup -= delta
		velocity = dir * move_speed * 0.15
		if sprite_2d:
			sprite_2d.modulate = Color(1.4, 0.85, 0.4, 1)
		if dash_windup <= 0.0 and not is_frozen():
			is_dashing = true
			dash_time_left = 0.26
			dash_dir = dir
		elif dash_windup <= 0.0:
			dash_timer = 0.35
			if sprite_2d:
				sprite_2d.modulate = base_modulate
		return

	dash_timer -= delta
	velocity = dir * move_speed
	if dash_timer <= 0.0 and dist < 280.0 and dist > 46.0 and not is_frozen():
		dash_windup = 0.16
		dash_dir = dir

func _steer_tank(delta: float, dir: Vector2, dist: float, move_speed: float) -> void:
	if slam_time_left > 0.0:
		slam_time_left -= delta
		velocity = slam_dir * move_speed * 3.4
		if sprite_2d:
			sprite_2d.modulate = Color(0.75, 0.85, 1.5, 1)
		if slam_time_left <= 0.0 and sprite_2d and freeze_time <= 0.0 and burn_stacks <= 0:
			sprite_2d.modulate = base_modulate
		return

	if slam_windup > 0.0:
		slam_windup -= delta
		velocity = Vector2.ZERO
		if sprite_2d:
			sprite_2d.modulate = Color(0.45, 0.6, 1.35, 1)
		if slam_windup <= 0.0 and not is_frozen():
			slam_time_left = 0.22
			slam_dir = dir if dir.length_squared() > 0.001 else Vector2.RIGHT
		elif slam_windup <= 0.0 and sprite_2d:
			sprite_2d.modulate = base_modulate
		return

	attack_timer -= delta
	velocity = dir * move_speed
	if attack_timer <= 0.0 and dist < 120.0 and not is_frozen():
		slam_windup = 0.36
		attack_timer = maxf(attack_cooldown, 1.35)

func _steer_ranged(delta: float, dir: Vector2, dist: float, move_speed: float) -> void:
	if shot_windup > 0.0:
		shot_windup -= delta
		velocity = -dir * move_speed * 0.35
		if sprite_2d:
			sprite_2d.modulate = Color(1.45, 1.35, 0.45, 1)
		if shot_windup <= 0.0:
			if not is_frozen():
				_fire_projectile(dir)
			if sprite_2d and freeze_time <= 0.0 and burn_stacks <= 0:
				sprite_2d.modulate = base_modulate
		return

	attack_timer -= delta
	var inner := preferred_range * 0.72
	var outer := preferred_range * 1.28
	if dist < inner:
		velocity = -dir * move_speed
	elif dist > outer:
		velocity = dir * move_speed * 0.9
	else:
		var strafe := Vector2(-dir.y, dir.x)
		if int(Time.get_ticks_msec() / 1300) % 2 == 0:
			strafe = -strafe
		var correct := clampf(preferred_range - dist, -40.0, 40.0) / 40.0
		velocity = strafe * move_speed * 0.85 + dir * correct * move_speed * 0.35

	if attack_timer <= 0.0 and dist < preferred_range + 150.0 and dist > 70.0 and not is_frozen():
		shot_windup = 0.2
		attack_timer = attack_cooldown

func _fire_projectile(dir: Vector2) -> void:
	if dir.length_squared() < 0.001:
		return
	var shot := PROJECTILE_SCENE.instantiate()
	var aim := dir.normalized()
	var container := get_tree().get_first_node_in_group("effect_container")
	if container == null:
		container = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	container.add_child(shot)
	shot.launch(global_position + aim * 16.0, aim, projectile_speed, projectile_damage, marker_color)
	shots_fired += 1

func _try_contact(dist: float) -> void:
	if archetype == EnemyData.Archetype.RANGED:
		return
	if contact_timer > 0.0 or not is_instance_valid(player_reference):
		return
	var radius := contact_radius
	var dmg := contact_damage
	var cd := contact_cooldown
	if archetype == EnemyData.Archetype.DASHER and is_dashing:
		radius += 8.0
		dmg *= 1.7
		cd *= 0.45
	if archetype == EnemyData.Archetype.TANK and slam_time_left > 0.0:
		radius = maxf(radius, 48.0)
		dmg *= 1.8
		cd = 0.4
	if dist > radius:
		return
	if not player_reference.has_method("receive_attack"):
		return
	player_reference.receive_attack(dmg, self)
	contact_timer = cd

func _face(dir: Vector2) -> void:
	if sprite_2d == null:
		return
	var face := velocity if absf(velocity.x) > 2.0 else dir
	if absf(face.x) > 0.01:
		sprite_2d.flip_h = face.x < 0.0

func _update_statuses(delta: float) -> void:
	if freeze_time > 0.0:
		freeze_time = maxf(0.0, freeze_time - delta)
		if sprite_2d and not is_dashing and slam_windup <= 0.0 and shot_windup <= 0.0:
			sprite_2d.modulate = Color(0.55, 0.85, 1.2, 1.0)
		if freeze_time <= 0.0 and burn_stacks <= 0 and sprite_2d:
			sprite_2d.modulate = base_modulate

	if burn_stacks > 0:
		if sprite_2d and freeze_time <= 0.0 and not is_dashing and shot_windup <= 0.0 and slam_windup <= 0.0:
			sprite_2d.modulate = Color(1.25, 0.55, 0.25, 1.0)
		burn_tick += delta
		if burn_tick >= 0.45:
			burn_tick = 0.0
			var tick_damage := float(burn_stacks) * burn_dps * 0.45
			_take_status_damage(tick_damage)
			_try_spread_burn()
			burn_stacks = max(burn_stacks - 1, 0)
			if burn_stacks <= 0 and freeze_time <= 0.0 and sprite_2d and not is_dashing:
				sprite_2d.modulate = base_modulate

func _mitigate(raw: float) -> float:
	var dealt := raw * (1.0 - clampf(defense, 0.0, 0.75))
	if raw > 0.0:
		dealt = maxf(dealt, 1.0)
	return dealt

func receive_hit(direction: Vector2, damage_value: float):
	var dealt := _mitigate(damage_value)
	play_hit_tween(direction)
	show_damage_text(dealt)
	AudioManager.play_enemy_hurt()
	_apply_health_loss(dealt)

func apply_hit(hit_data: Dictionary) -> void:
	var damage_value = float(hit_data.get("damage", 0))
	var damage_dir: Vector2 = hit_data.get("direction", Vector2.ZERO)
	var player_node := get_tree().get_first_node_in_group("player")
	if player_node != null and player_node.has_method("get_side_damage_multiplier"):
		damage_value *= player_node.get_side_damage_multiplier(global_position)

	# Bonus vs frozen targets.
	var game := get_tree().get_first_node_in_group("game")
	if is_frozen() and game != null and game.get("freeze_controller") != null:
		var fc = game.freeze_controller
		if fc != null and fc.level > 0:
			damage_value *= 1.0 + fc.get_frozen_bonus()

	receive_hit(damage_dir, damage_value)

	var effect_type = hit_data.get("effect", "")
	match effect_type:
		"burn":
			apply_burn(hit_data)
		"freeze":
			apply_freeze(hit_data)
		"shock":
			apply_shock(hit_data)
		"lightning":
			apply_lightning(hit_data)

	# Passive procs from gasoline / frost cards.
	if game != null:
		_try_passive_procs(game, hit_data)

func _try_passive_procs(game: Node, hit_data: Dictionary) -> void:
	# Don't double-proc from status tick pseudo-hits.
	if hit_data.get("from_status", false):
		return
	var mc = game.get("molotov_controller")
	if mc != null and mc.level > 0 and randf() < mc.get_on_hit_chance():
		apply_burn({
			"burn_stacks": mc.get_on_hit_stacks(),
			"burn_dps": mc.get_burn_dps() * 0.65
		})
	var fc = game.get("freeze_controller")
	if fc != null and fc.level > 0 and randf() < fc.get_on_hit_chance():
		apply_freeze({
			"freeze_duration": fc.get_freeze_duration(),
			"slow_factor": fc.get_slow_factor()
		})

func apply_lightning(hit_data: Dictionary) -> void:
	var source = hit_data.get("source", null)
	if source == null:
		return
	if not source.has_method("trigger_chain_lightning"):
		return
	source.trigger_chain_lightning(self, hit_data)

func apply_burn(hit_data: Dictionary) -> void:
	var add_stacks: int = int(hit_data.get("burn_stacks", 1))
	burn_stacks = mini(burn_stacks + add_stacks, MAX_BURN_STACKS)
	burn_dps = maxf(burn_dps, float(hit_data.get("burn_dps", burn_dps)))
	if sprite_2d and freeze_time <= 0.0 and not is_dashing:
		sprite_2d.modulate = Color(1.25, 0.55, 0.25, 1.0)

func apply_freeze(hit_data: Dictionary) -> void:
	freeze_time = maxf(freeze_time, float(hit_data.get("freeze_duration", 1.2)))
	freeze_slow = float(hit_data.get("slow_factor", 0.5))
	if sprite_2d and not is_dashing:
		sprite_2d.modulate = Color(0.55, 0.85, 1.2, 1.0)

func apply_shock(_hit_data: Dictionary) -> void:
	pass

func _try_spread_burn() -> void:
	if burn_stacks < 2:
		return
	if randf() > 0.4:
		return
	for enemy in get_tree().get_nodes_in_group("EnemyGroup"):
		if enemy == self or not is_instance_valid(enemy):
			continue
		if not (enemy is Node2D):
			continue
		if global_position.distance_to(enemy.global_position) > BURN_SPREAD_RADIUS:
			continue
		if enemy.has_method("apply_burn"):
			enemy.apply_burn({
				"burn_stacks": 1,
				"burn_dps": burn_dps * 0.85,
				"from_spread": true
			})

func _take_status_damage(amount: float) -> void:
	if amount <= 0.0:
		return
	var dealt := _mitigate(amount)
	show_damage_text(dealt)
	_apply_health_loss(dealt)

func play_hit_tween(direction: Vector2):
	if not is_inside_tree():
		return
	if sprite_2d == null or not is_instance_valid(sprite_2d):
		return
	if hurt_tween != null and hurt_tween.is_valid():
		hurt_tween.kill()
	var resting := Vector2(body_scale, body_scale)
	hurt_tween = get_tree().create_tween()
	hurt_tween.set_trans(Tween.TRANS_ELASTIC)
	hurt_tween.set_ease(Tween.EASE_OUT)
	hurt_tween.set_loops(1)
	hurt_tween.bind_node(self)
	hurt_tween.tween_property(self, "position", global_position + direction * 10, 0.5)
	hurt_tween.parallel().tween_property(self, "scale", resting, 0.5).from(resting * 1.25)
	hurt_tween.parallel().tween_property(sprite_2d, "modulate", Color.RED, 0.4)
	hurt_tween.tween_callback(func():
		if not is_instance_valid(sprite_2d):
			return
		if freeze_time > 0.0:
			sprite_2d.modulate = Color(0.55, 0.85, 1.2, 1.0)
		elif burn_stacks > 0:
			sprite_2d.modulate = Color(1.25, 0.55, 0.25, 1.0)
		else:
			sprite_2d.modulate = base_modulate
	)

func take_damage(damage_value: float) -> void:
	AudioManager.play_enemy_hurt()
	_apply_health_loss(_mitigate(damage_value))

func _apply_health_loss(dealt: float) -> void:
	health -= dealt
	if health <= 0:
		spaw_icon()
		remove_from_group("EnemyGroup")
		death_signal.emit()
		queue_free()

func show_damage_text(damage_value: float) -> void:
	var d = damage_text.instantiate()
	var container := get_tree().get_first_node_in_group("effect_container")
	if container == null:
		return
	container.add_child(d)
	d.position = self.position
	d.show_damage(str(floor(damage_value)), self.global_position, randf_range(0, 0), randf_range(0, 1))

func spaw_icon() -> void:
	var container := get_tree().get_first_node_in_group("pickup_container")
	var game = get_tree().get_first_node_in_group("game")
	if container == null || game == null:
		return
	var instance = coin.instantiate()
	instance.xp_value = 5 if is_elite else 2
	if instance.has_signal("coin_collected"):
		instance.connect("coin_collected", Callable(game, "on_coin_collected"))
	container.call_deferred("add_child", instance)
	instance.global_position = global_position
