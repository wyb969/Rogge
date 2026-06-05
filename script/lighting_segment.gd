extends Node2D

@export var lifetime := 0.15    # 闪电持续时间
@export var jitter_strength := 4.0

var start_node: Node2D
var end_node: Node2D
var line: Line2D

func _ready():
	line = Line2D.new()
	line.width = 3
	line.default_color = Color(0.7, 0.5, 1.0)
	add_child(line)

	# 自动销毁
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func setup(_start: Node2D, _end: Node2D):
	start_node = _start
	end_node = _end

func _process(delta):
	if not is_instance_valid(start_node) or not is_instance_valid(end_node):
		queue_free()
		return

	var from_pos = start_node.global_position
	var to_pos = end_node.global_position

	# 绘制随机闪电路径
	line.points = []
	var mid_count = 6
	line.add_point(from_pos)
	for i in range(1, mid_count):
		var t = float(i) / mid_count
		var pos = from_pos.lerp(to_pos, t)
		pos += Vector2(randf() * jitter_strength - jitter_strength / 2,
					   randf() * jitter_strength - jitter_strength / 2)
		line.add_point(pos)
	line.add_point(to_pos)
