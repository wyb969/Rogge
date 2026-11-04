extends RefCounted

const NAMES: = ["简单", "中等", "困难"]
const HEALTH_SCALES: = [0.5, 1.0, 1.5]
const REWARD_SCALES: = [1.5, 1.0, 1.0]
const RULES: = [
	"敌人与 Boss 血量 50%\n经验、回血量 +50%\n下一局开始生效", 
	"保持当前数值\n敌人血量、经验、回血均为 100%\n下一局开始生效", 
	"敌人与 Boss 血量 150%\n经验、回血量保持 100%\n下一局开始生效"
]
var index: int
var health_scale: float
var experience_scale: float
var healing_scale: float

func _init(value: int = 1) -> void :
	index = clampi(value, 0, 2)
	health_scale = HEALTH_SCALES[index]
	experience_scale = REWARD_SCALES[index]
	healing_scale = REWARD_SCALES[index]

func experience_for(base: int) -> int:
	return maxi(0, roundi(base * experience_scale))
