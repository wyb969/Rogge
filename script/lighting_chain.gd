extends Node2D

@export var max_chains := 4              # 最多连几个敌人
@export var chain_radius := 250.0        # 连锁范围
@export var base_damage := 40.0          # 初始伤害
@export var damage_decay := 0.8          # 每次衰减
@export var jump_delay := 0.1            # 每次跳跃延迟
@export var lightning_duration := 0.15   # 每条闪电显示时间
@export var jitter_strength := 8.0       # 闪电抖动强度


var chained_targets: Array = []
var line: Line2D
var current_damage: float

func _ready():
	line = Line2D.new()
	line.width = 3
	line.default_color = Color(0.7, 0.9, 1.0)
	add_child(line)


# 从起点施放闪电
func cast_lightning(start_pos: Vector2, enemies: Array):
	enemies.shuffle()
	var picked = enemies.slice(0, 5)
	if picked.size()<=0:
		return
	var first_target = picked[0]
	await _chain_jump(first_target, picked)  # 逐个跳跃完成
	line.points = []  # 清除最终线条


# 连锁跳跃逻辑
func _chain_jump(current_enemy, enemies):
	for i in range(enemies.size() - 1):
		var current = enemies[i]
		var next = enemies[i + 1]
		if current == null || next == null:
			return
		if current.has_method("get_hit"):
			current.get_hit(Vector2(0,0),base_damage)
		base_damage = base_damage * damage_decay
		_draw_lightning(current, next)
		# 闪电显示一段时间
		await get_tree().create_timer(lightning_duration).timeout
		line.points = []
		await get_tree().create_timer(jump_delay).timeout




func _draw_lightning(from_enemy: Node2D, to_enemy: Node2D):
	var lightning = preload("res://script/lighting_segment.gd").new()
	lightning.setup(from_enemy, to_enemy)
	get_tree().current_scene.add_child(lightning)
