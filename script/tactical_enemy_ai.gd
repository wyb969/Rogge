extends RefCounted

var kind: StringName
var slot: RefCounted
var cooldown := 1.0
var recovery := 0.0
var facing := Vector2.RIGHT
var committed := false

func setup(style: StringName, identity: int) -> void:
	kind = style
	cooldown = 0.8+float(identity%9)*0.09

func steer(actor: Node2D, delta: float, dir: Vector2, distance: float, speed: float) -> void:
	var game: Node = actor._game_owner()
	if game==null or game.get("enemy_attacks")==null:
		actor.velocity = dir*speed
		return
	var field: Node2D = game.enemy_attacks
	cooldown = maxf(0,cooldown-delta)
	recovery = maxf(0,recovery-delta)
	if actor.is_frozen() or actor._airflow_left>0 or actor._blast_left>0:
		if slot!=null: field.cancel(slot,actor)
		slot = null
		committed = false
		recovery = 0.6
		actor.velocity = Vector2.ZERO
		return
	if slot!=null:
		if slot.active and slot.source_id==actor.get_instance_id():
			committed = true
			facing = slot.heading
			actor.velocity = Vector2.ZERO
			return
		slot = null
		recovery = maxf(recovery,0.6)
	committed = false
	facing = dir
	if recovery>0:
		actor.velocity = Vector2.ZERO
		return
	if kind==&"cleave":
		actor.velocity = dir*speed if distance>58.0 else Vector2.ZERO
	else:
		var preferred: float = actor.preferred_range
		if distance<preferred*0.78: actor.velocity = -dir*speed
		elif distance>preferred*1.18: actor.velocity = dir*speed
		else: actor.velocity = dir.orthogonal()*speed*0.55*(1.0 if actor.get_instance_id()%2==0 else -1.0)
	var reach := 220.0 if kind==&"boomerang" else 280.0
	var in_range := distance<=94.0 if kind==&"cleave" else distance>65.0 and distance<=reach
	if cooldown>0 or not in_range or dir.is_zero_approx(): return
	slot = field.cast(actor,kind)
	if slot==null:
		cooldown = 0.35
		return
	cooldown = actor.attack_cooldown
	committed = true
	facing = slot.heading
	actor.velocity = Vector2.ZERO
