extends CharacterBody2D
@export var player:CharacterBody2D
@onready var rush_timer: Timer = $RushTimer
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var health_bar: ProgressBar = $HealthBar

var charge_speed: float = 600.0  # 冲撞速度
var is_charging: bool = false
var charge_direction: Vector2 = Vector2.ZERO
var target_position: Vector2 = Vector2.ZERO

var health_max_value: float = 2000.0
var boss_current_health:float = 2000.0
var line:Line2D

func _ready() -> void:
	health_bar.init_health(health_max_value)# why not remind!!

func _process(delta: float) -> void:
	if is_charging:
		# 冲撞过程中移动
		velocity = charge_direction * charge_speed
		move_and_slide()

		# 判断是否到达预定地点（或超出距离，结束冲撞）
		if global_position.distance_to(target_position) < 20.0:
			stop_charge()

func start_charge_attack() -> void:
	if not is_instance_valid(player):
		return

	# 锁定当前玩家的位置作为冲撞终点
	target_position = player.global_position
	charge_direction = (target_position - global_position).normalized()

	# 根据玩家位置更新 Boss 动画朝向
	update_facing_direction(target_position)

	# 画预警线并等待结束后开始冲撞
	show_warning_line_and_then_charge(target_position)

func update_facing_direction(target_pos: Vector2) -> void:
	if target_pos.x < global_position.x:
		sprite_2d.flip_h = true   # 玩家在左侧，向左翻转
	else:
		sprite_2d.flip_h = false   # 玩家在右侧，保持默认

# 3. 绘制 Line2D 并用 Tween 连贯控制
func show_warning_line_and_then_charge(target_pos: Vector2) -> void:
	# 创建预警线
	line = Line2D.new()
	line.width = 12.0
	line.default_color = Color(1.0, 0.0, 0.0, 0.8) # 红色带透明度
	line.add_point(global_position)
	line.add_point(target_pos)

	line.z_index = 1
	# 添加到场景中（建议添加到 main 场景或根节点，避免跟随 Boss 移动而变形）
	get_tree().current_scene.add_child(line)

	# 创建 Tween 动画
	var tween = create_tween()
	# 阶段 A: 线条停留预警 (例如 0.4 秒)
	tween.tween_interval(0.6)
	# 阶段 B: 线条渐变淡出 (0.2 秒)
	tween.tween_property(line, "modulate:a", 0.0, 0.2)
	# 阶段 C: 清理线条节点
	tween.tween_callback(line.queue_free)
	# 阶段 D: 预警结束，立刻开始冲撞！
	tween.tween_callback(start_moving_charge)

# 4. 开始物理冲撞
func start_moving_charge() -> void:
	is_charging = true
	# 这里可以播放 Boss 的“冲撞”动画：
	animation_player.play("chase")

# 5. 停止冲撞
func stop_charge() -> void:
	is_charging = false
	animation_player.play("idle")
	velocity = Vector2.ZERO
	# 播放 Boss “后摇/僵直” 动画
	await get_tree().create_timer(0.6).timeout
	rush_timer.start()

func set_player(player_var:Node2D)->void:
	player = player_var

func _on_rush_timer_timeout() -> void:
	print("rush timer out")
	if not player:
		return
	start_charge_attack()

func show_charge_indicator(target_position: Vector2):
	# 1. 创建并配置 Line2D
	var line = Line2D.new()
	line.width = 20.0
	line.default_color = Color.RED
	# 设置路径点 (起点: Boss 当前坐标，终点: 目标坐标)
	line.add_point(global_position)
	line.add_point(target_position)
	line.z_index = 1
	# 添加到场景中（建议添加到 main 场景或根节点，避免跟随 Boss 移动而变形）
	get_tree().current_scene.add_child(line)

	var tween = create_tween()
	# 阶段一：线保持显示 0.3 秒（给玩家反应时间）
	tween.tween_interval(0.5)
	tween.tween_property(line, "modulate:a", 0.0, 0.8)
	tween.tween_callback(line.queue_free)

func apply_hit(hit_data: Dictionary) -> void:
	AudioManager.play_enemy_hurt()
	var damage_value = hit_data.get("damage", 0)
	var damage_dir: Vector2 = hit_data.get("direction", Vector2.ZERO)
	boss_current_health -= damage_value
	play_boss_hurt_tween()
	if boss_current_health<=0:
		queue_free()
		if line: line.queue_free()
	health_bar.set_health(boss_current_health)

func play_boss_hurt_tween()->void:
	var tween = get_tree().create_tween()
	tween.set_loops(1)
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite_2d, "modulate", Color.RED, 0.2)
	tween.tween_property(sprite_2d, "modulate", Color.WHITE, 0.1)
	tween.tween_property(sprite_2d, "scale",Vector2(1.16*8.0,1.16*8.0), 0.2)
	tween.tween_property(sprite_2d, "scale",Vector2(8.0, 8.0), 0.1)
