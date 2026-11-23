extends RefCounted

const COLORS := [Color("#65d9ea"), Color("#b491ff"), Color("#ff80c8"), Color("#ffac49")]
const NAMES := ["青色", "紫色", "粉色", "橙色"]

static func tier_name(tier: int) -> String:
	var name := L10n.text(NAMES[clampi(tier, 0, 3)])
	if tier > 3:
		return name + " +" + str(tier - 3)
	return name

static func tier_for(level: int) -> int:
	return mini(3, floori(level / 3.0))
