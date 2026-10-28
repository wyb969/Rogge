extends CharacterBody2D
@export var player_reference: CharacterBody2D
@onready var sprite_2d: Sprite2D = $Sprite2D

@onready var damage_text = preload("res://scenes/damage_text.tscn")
@onready var coin = preload("res://scenes/coin.tscn")

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
	base_modulate = Color.WHITE
	tween = create_tween()
	tween.bind_node(self)
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_loops()
	tween.tween_property(self, "scale", Vector2(1.12, 1.12), 0.2)
	tween.tween_property(self, "scale", Vector2.ONE, 0.4)

func set_enemy_data(data: EnemyData) -> void:
	var desired_size := Vector2(20, 20)
	$Sprite2D.texture = data.sprite
	health = data.health
	damage = data.damage
	var tex_size = data.sprite.get_size()
	if tex_size.x > 0 and tex_size.y > 0:
		$Sprite2D.scale = desired_size / tex_size

func set_elite_status() -> void:
	is_elite = true
	$Sprite2D.material = load("res://shaders/rainbow_outline.tres")
	scale = Vector2(1.55, 1.55)

func setHealth(hp: float) -> void:
	health = hp

func setDamage(dg: float) -> void:
	damage = dg

func set_player_ref(player_ref: CharacterBody2D) -> void:
	player_reference = player_ref

func is_frozen() -> bool:
	return freeze_time > 0.0

func _physics_process(delta: float) -> void:
	if !is_instance_valid(player_reference):
		return

	_update_statuses(delta)

	var move_speed := speed
	if is_frozen():
		move_speed *= freeze_slow

	velocity = (player_reference.position - position).normalized() * move_speed

	if knockback.length() > 0.1:
		velocity += knockback
		knockback = knockback.move_toward(Vector2.ZERO, knockback_decay * delta)
	var collision = move_and_collide(velocity * delta)
	if collision:
		if collision.get_collider() is CharacterBody2D:
			var other = collision.get_collider()
			var dir = (global_position - other.global_position).normalized()
			knockback = dir * 10.0

func _update_statuses(delta: float) -> void:
	if freeze_time > 0.0:
		freeze_time = maxf(0.0, freeze_time - delta)
		if sprite_2d:
			sprite_2d.modulate = Color(0.55, 0.85, 1.2, 1.0)
		if freeze_time <= 0.0 and burn_stacks <= 0 and sprite_2d:
			sprite_2d.modulate = base_modulate

	if burn_stacks > 0:
		if sprite_2d and freeze_time <= 0.0:
			sprite_2d.modulate = Color(1.25, 0.55, 0.25, 1.0)
		burn_tick += delta
		if burn_tick >= 0.45:
			burn_tick = 0.0
			var tick_damage := float(burn_stacks) * burn_dps * 0.45
			_take_status_damage(tick_damage)
			_try_spread_burn()
			burn_stacks = max(burn_stacks - 1, 0)
			if burn_stacks <= 0 and freeze_time <= 0.0 and sprite_2d:
				sprite_2d.modulate = base_modulate

func receive_hit(direction: Vector2, damage_value: float):
	play_hit_tween(direction)
	show_damage_text(damage_value)
	take_damage(damage_value)

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
	if sprite_2d and freeze_time <= 0.0:
		sprite_2d.modulate = Color(1.25, 0.55, 0.25, 1.0)

func apply_freeze(hit_data: Dictionary) -> void:
	freeze_time = maxf(freeze_time, float(hit_data.get("freeze_duration", 1.2)))
	freeze_slow = float(hit_data.get("slow_factor", 0.5))
	if sprite_2d:
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
	show_damage_text(amount)
	health -= amount
	if health <= 0:
		spaw_icon()
		remove_from_group("EnemyGroup")
		death_signal.emit()
		queue_free()

func play_hit_tween(direction: Vector2):
	if not is_inside_tree():
		return
	if sprite_2d == null or not is_instance_valid(sprite_2d):
		return
	if hurt_tween != null and hurt_tween.is_valid():
		hurt_tween.kill()
	hurt_tween = get_tree().create_tween()
	hurt_tween.set_trans(Tween.TRANS_ELASTIC)
	hurt_tween.set_ease(Tween.EASE_OUT)
	hurt_tween.set_loops(1)
	hurt_tween.bind_node(self)
	hurt_tween.tween_property(self, "position", global_position + direction * 10, 0.5)
	hurt_tween.parallel().tween_property(self, "scale", Vector2.ONE, 0.5).from(Vector2(1.5, 1.5))
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
	health -= damage_value
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
