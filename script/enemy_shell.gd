extends CharacterBody2D
@export var player_reference:CharacterBody2D
@onready var sprite_2d: Sprite2D = $Sprite2D

@onready var demage_text = preload("res://scenes/demage_text.tscn")
@onready var coin = preload("res://scenes/coin.tscn")

var direction:Vector2
var speed : float = 50
var knockback: Vector2 = Vector2.ZERO
var knockback_decay: float = 10.0  # 衰减速度
var health: float = 10
var demage: float = 2
var tween:Tween
var hurt_tween:Tween

func _ready() -> void:
	tween = create_tween()
	tween.bind_node(self)
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_loops()
	tween.tween_property(self, "scale", Vector2(1.12, 1.12), 0.2)
	tween.tween_property(self, "scale", Vector2.ONE, 0.4)
	
func set_enemy_data(data:EnemyData)->void:
	var desired_size := Vector2(20, 20)
	$Sprite2D.texture = data.sprite
	health = data.health 
	demage = data.demage
	var tex_size = data.sprite.get_size()         
	if tex_size.x > 0 and tex_size.y > 0:    
		$Sprite2D.scale = desired_size / tex_size
	
func set_elite_status()->void:
	$Sprite2D.material = load("res://shaders/rainbow_outline.tres")
	scale = Vector2(1.25,1.25)

func set_player_ref(player_ref:CharacterBody2D)->void:
	player_reference = player_ref
	
func _physics_process(delta: float) -> void:
	velocity = (player_reference.position - position).normalized()*speed
	
	if knockback.length() > 0.1:
		velocity += knockback
		knockback = knockback.move_toward(Vector2.ZERO, knockback_decay * delta)
	var collision = move_and_collide(velocity*delta)
	if collision:
		if collision.get_collider() is CharacterBody2D:
			var other = collision.get_collider()
			var dir = (global_position - other.global_position).normalized()
			knockback = dir * 10.0   # 击退力度
 

func get_hit(direction:Vector2, demage:float):
	play_hit_tween(direction)
	show_demage_text(demage)
	take_demage(demage)

func play_hit_tween(direction:Vector2):
	hurt_tween = get_tree().create_tween()
	hurt_tween.set_trans(Tween.TRANS_ELASTIC)
	hurt_tween.set_ease(Tween.EASE_OUT)
	hurt_tween.set_loops(1)
	hurt_tween.bind_node(self)
	hurt_tween.tween_property(self, "position", global_position + direction *10 , 0.5)
	hurt_tween.parallel().tween_property(self, "scale", Vector2.ONE, 0.5).from(Vector2(1.5,1.5))
	hurt_tween.parallel().tween_property(sprite_2d, "modulate", Color.RED, 0.4)	
	hurt_tween.tween_property(sprite_2d, "modulate", Color.WHITE, 0.1)	
 

func take_demage(demage:float)->void:
	health -= demage
	if(health<=0):
		spaw_icon()
		queue_free()

func show_demage_text(demage:float)->void:
	var d = demage_text.instantiate()
	get_tree().root.add_child(d)
	
	d.position = self.position
	d.show_demage(str(demage),self.global_position,randf_range(0,0),randf_range(0,1))
	
	
func spaw_icon()->void:
	var main = get_tree().current_scene
	var instance = coin.instantiate()
	instance.global_position = global_position 
	instance.connect("coin_collected", Callable(main, "on_coin_collected"))
	main.call_deferred("add_child",instance)
