extends RefCounted

# Color is derived from the ONE rank owned for each skill. White is reserved
# for all unclaimed draft cards; forge entries show the actual owned tier.
const COLORS := [Color("#65d9ea"), Color("#b491ff"), Color("#ff80c8"), Color("#ffac49")]
const NAMES := ["青色", "紫色", "粉色", "橙色"]

static func tier_for_level(level: int) -> int:
	if level >= 9: return 3
	if level >= 6: return 2
	if level >= 3: return 1
	return 0

static func color_for_level(level: int) -> Color:
	return COLORS[tier_for_level(level)]

static func tier_name(tier: int) -> String:
	return L10n.text(NAMES[clampi(tier, 0, 3)])

static func level_name(level: int) -> String:
	return "Lv.%d · %s" % [level, tier_name(tier_for_level(level))]
