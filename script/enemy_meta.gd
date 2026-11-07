extends Resource
class_name EnemyData



enum Archetype{CHASER, DASHER, TANK, RANGED}

@export var title: String = "enemy"
@export var sprite: Texture2D
@export var health: float = 34.0
@export var damage: float = 2.0
@export var archetype: Archetype = Archetype.CHASER
@export var move_speed: float = 56.0
@export var defense: float = 0.0
@export var body_scale: float = 1.0
@export var tint: Color = Color.WHITE
@export var marker_color: Color = Color(0.8, 0.8, 0.85, 1)
@export var contact_damage: float = 46.0
@export var contact_cooldown: float = 0.8
@export var contact_radius: float = 26.0
@export var dash_speed: float = 260.0
@export var dash_cooldown: float = 2.0
@export var preferred_range: float = 200.0
@export var projectile_damage: float = 36.0
@export var projectile_speed: float = 150.0
@export var attack_cooldown: float = 1.4
@export var attack_style: StringName = &""
