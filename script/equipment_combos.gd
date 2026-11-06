extends RefCounted

const GROWTH_MEMBERS: Array[String] = ["pickup_up", "speed_up", "regen_up"]
const ARSENAL_MEMBERS: Array[String] = ["gun_up", "drone_up", "bomb"]
const GROWTH_COLOR := Color(0.4, 1.0, 0.24)
const ARSENAL_COLOR := Color(1.0, 0.76, 0.22)
const MOVE_MULTIPLIER := 1.2
const HEAL_MULTIPLIER := 1.2
const XP_BONUS_TENTHS := 3
const GROWTH_HINT := "生机组合：拾取 + 移速 + 回复\n集齐：经验+30%，移速与回复效果+20%"
const ARSENAL_HINT := "军械组合：无人机 + 枪支 + 炸弹\n三件均装备后，每3秒获得1秒无敌护盾"

static func owned_count(panel: Node, members: Array[String]) -> int:
	var count := 0
	for id in members:
		if panel.get_level(id) > 0: count += 1
	return count

static func group_for(id: String) -> String:
	if id in GROWTH_MEMBERS: return "growth"
	if id in ARSENAL_MEMBERS: return "arsenal"
	return ""

static func color_for(group: String) -> Color:
	return GROWTH_COLOR if group == "growth" else ARSENAL_COLOR

static func hint_for(id: String) -> String:
	match group_for(id):
		"growth": return GROWTH_HINT
		"arsenal": return ARSENAL_HINT
	return ""
