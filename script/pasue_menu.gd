extends CanvasLayer

@export var card_scene:PackedScene
@onready var h_box_container: HBoxContainer = $Panel/HBoxContainer

signal upgrade_selected(upgrade_id: String)

var upgrade_options := [
	{
		"id": "axe_up",
		"title": "斧头 +1级",
		"desc": "提高斧头攻击力"
	},
	{
		"id": "circle_up",
		"title": "书本 +1级",
		"desc": "提高书本旋转速度"
	},
	{
		"id": "speed_up",
		"title": "移速 +10%",
		"desc": "提高移动速度"
	}
]

func _ready():
	# 初始隐藏暂停菜单
	visible = false


func show_upgrade_options():
	get_tree().paused =true
	visible = true
	for child in h_box_container.get_children():
		child.queue_free()

	for data in upgrade_options:
		var card = card_scene.instantiate()
		h_box_container.add_child(card)
		card.setup(data)
		card.selected.connect(on_card_selected)


func on_card_selected(upgrade_id:String):
	upgrade_selected.emit(upgrade_id)
	visible = false
	get_tree().paused = false


# 点击“继续”按钮时执行
func _on_button_pressed():
	get_tree().paused = false        # 解除暂停
	visible = false
