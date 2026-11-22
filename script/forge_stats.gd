extends RefCounted
## Project a collection of physical cards onto the existing combat controllers.
## Count controls targeting, timing and number of bodies. The strongest copy
## supplies the original unlock value and each remaining copy its rank increment.
## This keeps legacy first/rank-two tuning and never weakens a skill on acquisition.
const PASSIVES := {
	"regen_up": "regen_level", "shield_up": "shield_level", "lifesteal_up": "lifesteal_level",
	"monster_necklace": "monster_necklace_level", "critical_glasses": "critical_glasses_level",
	"left_fist": "left_fist_level", "right_fist": "right_fist_level",
}
const SINGLE_SPELLS := {
	"bomb": "bomb_controller", "banana_fan": "banana_fan", "light_thorn": "light_thorn", "ice_wave": "ice_wave", "ghost_dash": "ghost_dash", "blood_vortex": "blood_vortex", "draw_slash": "draw_slash", "black_hole": "black_hole",
	"poison_trail": "poison_trail", "lightning_ring": "lightning_ring",
}
const ARCANE := ["thorn_whip", "rune_bolt", "pulse_aura"]
const RELICS := ["silver_knife", "cross_blade", "holy_water"]
const BOOK := preload("res://script/circle_unit.gd")
const CRIT := preload("res://script/critical_glasses.gd")

static func weighted(first: float, increment: float, total: float, strongest: float) -> float:
	return first * strongest + increment * maxf(0.0, total - strongest)

static func _profile(g: Node, id: String, count: int, power: float, peak: float) -> Dictionary:
	if count <= 0: return {}
	if peak < 0.0: peak = power / count
	var p: Node = g.player
	var stats: Dictionary
	var first: Dictionary
	var second: Dictionary
	var school := preload("res://script/theme_skill_school.gd")
	if id in school.DRAGON or id in school.POCKET:
		stats = school.stats_for(id,count)
		first = school.stats_for(id,1)
		second = school.stats_for(id,2)
	elif id in preload("res://script/dimension_lab.gd").IDS:
		stats = g.dimension_lab.stats_for(id,count)
		first = g.dimension_lab.stats_for(id,1)
		second = g.dimension_lab.stats_for(id,2)
	elif id in ARCANE or id in RELICS:
		var multi: Node = g.arcane_weapons if id in ARCANE else g.relic_weapons
		stats = multi.stats_for(id, count)
		first = multi.stats_for(id, 1)
		second = multi.stats_for(id, 2)
	elif SINGLE_SPELLS.has(id):
		var controller: Node = g.get(SINGLE_SPELLS[id])
		stats = controller.stats_for(count)
		first = controller.stats_for(1)
		second = controller.stats_for(2)
	elif id == "wind_emblem" or id == "echo_ember":
		var query := Callable(g.variety, "wind_stats" if id == "wind_emblem" else "echo_stats")
		stats = query.call(count)
		first = query.call(1)
		second = query.call(2)
	if not stats.is_empty():
		var key := "dps" if stats.has("dps") else "damage"
		stats[key] = weighted(first[key], second[key] - first[key], power, peak)
		if id == "lightning_ring": stats.bolts = mini(12, stats.bolts)
		return stats
	match id:
		"axe_up":
			var axe: Node = g.hand_weapon
			var steps := count - 1
			return {"damage": weighted(14.0, 8.0 + 0.6 * clampi(g.current_level,0,30), power, peak),
				"speed": mini(axe.MAX_FLIGHT_SPEED, roundi(axe.BASE_FLIGHT_SPEED * (1.0 + 0.12 * steps + 0.015 * steps * steps)))}
		"circle_up":
			var base := BOOK.damage_for(g.current_level, 1)
			return {"damage": weighted(base, 0.15 * base, power, peak), "count": g.circle_weapon.count_for(count)}
		"gun_up":
			var gun: Node = g.gun_weapon
			var start: int = gun.damage_for_upgrade(1)
			var delta: int = gun.damage_for_upgrade(2) - start
			return {"lo": roundi(weighted(start + 5, delta, power, peak)), "hi": roundi(weighted(start + 15, delta, power, peak))}
		"drone_up":
			var d: Node = g.drone_controller
			return {"damage": weighted(d.get_damage(1),d.get_damage(2)-d.get_damage(1),power,peak), "count": mini(8, d.get_drone_count(count))}
		"molotov_up":
			var fire: Node = g.molotov_controller
			return {"dps": weighted(fire.get_burn_dps(1),fire.get_burn_dps(2)-fire.get_burn_dps(1),power,peak)}
		"freeze_up":
			var ice: Node = g.freeze_controller
			return {"vulnerability": weighted(ice.get_frozen_bonus(1),ice.get_frozen_bonus(2)-ice.get_frozen_bonus(1),power,peak)}
		"speed_up": return {"speed_bonus": p.SPEED_CARD_BONUS * power}
		"pickup_up": return {"range_bonus": (p.PICKUP_CARD_SCALE - 1.0) * power}
		"regen_up": return {"heal": weighted(p.REGEN_BASE_AMOUNT,p.REGEN_AMOUNT_STEP,power,peak)}
		"monster_necklace": return {"heal": p.necklace_base_heal(1) * power}
		"shield_up": return {"shield": weighted(p.SHIELD_GAIN_BASE,p.SHIELD_GAIN_STEP,power,peak)}
		"lifesteal_up":
			return {"percent": weighted(p.lifesteal_percent_for(1),p.LIFESTEAL_PERCENT_STEP,power,peak),
				"cap": weighted(p.lifesteal_cap_for(1),p.LIFESTEAL_CAP_STEP,power,peak), "flat": p.LIFESTEAL_FLAT * peak}
		"left_fist", "right_fist":
			return {"bonus": weighted(p.get_fist_bonus(1),p.get_fist_bonus(2)-p.get_fist_bonus(1),power,peak)}
		"critical_glasses":
			# Above guaranteed crit, additional contribution raises the bonus damage.
			var chance := power * CRIT.CHANCE_PER_LEVEL
			return {"chance": minf(chance,1.0), "crit": 1.0 + (CRIT.damage_multiplier_for(count) - 1.0) * maxf(1.0,chance)}
	return {}

static func apply(g: Node, id: String, old_count: int, count: int, old_power: float, power: float, peak := -1.0) -> void:
	var p: Node = g.player
	var data := _profile(g, id, count, power, peak)
	if PASSIVES.has(id):
		p.set(PASSIVES[id],count)
		if count > 0: p.forged_passives[id] = data
		else: p.forged_passives.erase(id)
		if id == "shield_up" and count == 0:
			p.shield = 0.0
			p._sync_shield_visuals()
		if id == "regen_up" and count == 0: p._regen_acc = 0.0
		return
	var school := preload("res://script/theme_skill_school.gd")
	if id in school.DRAGON or id in school.POCKET:
		var owner: Node = g.turtle_school if id in school.DRAGON else g.pocket_school
		owner.set_forged_stats(id,count,data)
		return
	if id in preload("res://script/dimension_lab.gd").IDS:
		g.dimension_lab.set_forged_stats(id,count,data)
		return
	if id in ARCANE or id in RELICS:
		var multi: Node = g.arcane_weapons if id in ARCANE else g.relic_weapons
		multi.set_forged_stats(id, count, data)
		return
	if SINGLE_SPELLS.has(id):
		var controller: Node = g.get(SINGLE_SPELLS[id])
		if count <= 0: controller.reset()
		else:
			if count > old_count: controller.upgrade()
			controller.level = count
			if id == "lightning_ring": controller.forged_stats = data
			else: controller._stats = data
		return
	match id:
		"axe_up":
			var axe: Node = g.hand_weapon
			if count == 0:
				axe.start_unequipped()
				axe.flying_out = false
				axe.returning = false
				axe.rotation = 0.0
			else:
				if old_count == 0: axe.handle_level_up(g.current_level)
				axe.level = count
				axe.weapon_demage = data.damage
				axe.max_speed = data.speed
		"circle_up":
			var book: Node = g.circle_weapon
			if count == 0: book.start_unequipped()
			else:
				book.current_level = g.current_level
				book.card_level = count
				book.num_weapons = data.count
				book.rotation_speed = book.rotation_for(count)
				book.set_process(true)
				book.spawn_weapons()
				for unit in book.get_children(): unit.weapon_demage = data.damage
		"gun_up": g.gun_weapon.set_forged_rank(count, data)
		"drone_up": g.drone_controller.set_forged_rank(count, data)
		"molotov_up":
			var fire: Node = g.molotov_controller
			if count > old_count: fire.upgrade()
			fire.level = count
			fire.forged_dps = data.get("dps", -1.0)
		"freeze_up":
			g.freeze_controller.level = count
			g.freeze_controller.forged_bonus = data.get("vulnerability", -1.0)
		"speed_up": p.speed_up(p.SPEED_CARD_BONUS * (power - old_power))
		"pickup_up":
			var base: float = p.PICKUP_CARD_SCALE - 1.0
			p.pick_up_upgrade((1.0 + base * power) / (1.0 + base * old_power))
		"wind_emblem", "echo_ember":
			g.variety.set_forged_stats(id, count, data)

static func describe(g: Node, id: String, count: int, power: float, peak := -1.0, crimson := false) -> String:
	if count <= 0: return "—"
	var data := preload("res://script/equipment_combos.gd").combat_stats(id,_profile(g,id,count,power,peak),crimson)
	if data.has("lo"): return "%s %d–%d" % [L10n.text("基础伤害"), data.lo, data.hi]
	if data.has("chance"):
		return "%s %s%% · ×%s" % [L10n.text("暴击率"), CardNumbers.number(100.0 * data.chance),CardNumbers.number(data.crit)]
	var attributes := [
		["damage","单次伤害",1.0], ["dps","每秒伤害",1.0], ["speed_bonus","移速",1.0],
		["range_bonus","拾取半径",100.0], ["vulnerability","冻伤增伤",100.0],
		["heal","每次回复",1.0], ["shield","每杀护盾",1.0], ["bonus","基础伤害",100.0],
		["cap","每次回复上限",1.0]]
	for attribute in attributes:
		if data.has(attribute[0]):
			var plus := "+" if attribute[0] in ["speed_bonus","range_bonus","bonus"] else ""
			var suffix := "%" if attribute[2] == 100.0 else ""
			var summary := "%s %s%s%s" % [L10n.text(attribute[1]),plus,CardNumbers.number(data[attribute[0]] * attribute[2]),suffix]
			if data.has("count"): summary += " ×%d" % data.count
			return summary
	return "—"
