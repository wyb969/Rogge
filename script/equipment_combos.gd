extends RefCounted

const GROWTH_MEMBERS: Array[String] = ["pickup_up", "speed_up", "regen_up"]
const ARSENAL_MEMBERS: Array[String] = ["gun_up", "drone_up", "bomb"]
const CRIMSON_MEMBERS: Array[String] = ["ice_wave", "draw_slash", "ghost_dash", "blood_vortex"]
const CRIMSON_COLOR := Color("#ff4059")
const CRIMSON_DAMAGE := 1.30
const CRIMSON_SIZE := 1.30
const CRIMSON_CD := 0.70
const CRIMSON_TITLE := "绯刃四式"
const CRIMSON_BONUS := "四技伤害 +30% · 冷却 −30% · 范围 +30%"
const CRIMSON_HINT := "绯刃四式：冰刃波、拔刀斩、鬼影步、嗜魂封魔斩。集齐后四技伤害与范围增加30%，冷却缩短30%。"
const GROWTH_COLOR := GamePalette.PLAYER_CYAN
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
	if id in CRIMSON_MEMBERS: return "crimson"
	if id in GROWTH_MEMBERS: return "growth"
	if id in ARSENAL_MEMBERS: return "arsenal"
	return ""

static func color_for(group: String) -> Color:
	if group == "crimson": return CRIMSON_COLOR
	return GROWTH_COLOR if group == "growth" else ARSENAL_COLOR

static func hint_for(id: String) -> String:
	match group_for(id):
		"crimson": return L10n.text(CRIMSON_HINT)
		"growth": return L10n.text(GROWTH_HINT)
		"arsenal": return L10n.text(ARSENAL_HINT)
	return ""

# Apply once, after rank and card quality. The blood vortex interval is its
# damage beat. Its separate recovery is the cooldown between casts.
static func combat_stats(id: String, base: Dictionary, active: bool) -> Dictionary:
	if not active or id not in CRIMSON_MEMBERS: return base
	var stats := base.duplicate()
	stats.damage *= CRIMSON_DAMAGE
	for key in ["range", "radius"]:
		if stats.has(key): stats[key] *= CRIMSON_SIZE
	var cooldown := "recovery" if id == "blood_vortex" else "interval"
	stats[cooldown] *= CRIMSON_CD
	return stats

static func completes_crimson(panel: Control, added: String) -> bool:
	for id in CRIMSON_MEMBERS:
		if id != added and panel.get_level(id) == 0: return false
	return true
