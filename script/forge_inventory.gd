extends RefCounted

const STATS := preload("res://script/forge_stats.gd")
const STYLE := preload("res://script/card_quality_style.gd")
const COLORS = STYLE.COLORS
const COMBOS := preload("res://script/equipment_combos.gd")
const STARTER := preload("res://script/starter_lottery.gd")
const OTHER_ATTACKS := ["molotov_up", "black_hole", "poison_trail", "banana_fan", "wind_emblem"]
const PRACTICE_GOLD := 600
const PRACTICE_CARDS := [["pickup_up",0],["speed_up",0],["gun_up",1],["regen_up",1],["axe_up",2],["shield_up",2]]
const PROFILE := "user://rogge_forge.cfg"
const FLOORS := [12, 16, 20, 24, 28, 32]
const PAR_SECONDS := [90, 75, 90, 90, 100, 115]

var game: Node
var enabled := false
var training := false
var cards: Array[Dictionary] = []
var wallet := 0
var stage_income := 0
var materials := 0
var furnace_level := 1
var run_materials := 0
var victory_materials := 0
var last_reward: Dictionary = {}
var _next_uid := 1
var _stage_start := 0.0
var _stage_duration := 0.0
var _sealed_stage := 0
var _settled_stage := 0
var _standard_cost := 1

func begin(owner_game: Node, practice := false) -> void:
	game = owner_game
	enabled = true
	training = practice
	if not training:
		var profile := ConfigFile.new()
		if profile.load(PROFILE) == OK:
			materials = maxi(0, int(profile.get_value("forge","materials",0)))
			furnace_level = maxi(1, int(profile.get_value("forge","level",1)))
	begin_stage()

func _store(balance: int, level: int) -> bool:
	if not training:
		var profile := ConfigFile.new()
		profile.set_value("forge","materials",balance)
		profile.set_value("forge","level",level)
		var pending := PROFILE + ".tmp"
		if profile.save(pending) != OK: return false
		if DirAccess.rename_absolute(ProjectSettings.globalize_path(pending), ProjectSettings.globalize_path(PROFILE)) != OK: return false
		game.get_node("/root/SettingsStore")._sync_web_filesystem()
	materials = balance
	furnace_level = level
	return true

static func weight(tier: int) -> float:
	match tier:
		0: return 0.8
		1: return 1.2
		2: return 2.0
	return 4.0 + 0.5 * (tier - 3)

func refresh_level_stats() -> void:
	for id in ["axe_up","circle_up"]:
		var s := _summary(id,cards)
		if s.n > 0: STATS.apply(game,id,s.n,s.n,s.power,s.power,s.peak)

func draft_tier() -> int:
	return 1 if randi_range(0,99) < 20 else 0

func begin_stage() -> void:
	stage_income = 0
	_stage_start = game.spawner.run_seconds
	_sealed_stage = 0

func earn(amount: int) -> void:
	wallet += amount
	stage_income += amount

func seal_stage() -> bool:
	var stage: int = game.spawner.stage
	if stage <= _settled_stage or stage == _sealed_stage: return false
	_sealed_stage = stage
	_stage_duration = maxf(1.0, game.spawner.run_seconds - _stage_start)
	_standard_cost = maxi(FLOORS[clampi(stage-1,0,5)], roundi(stage_income / 3.0))
	return true

func counts(id: String) -> Array[int]:
	var bins: Array[int] = [0,0,0,0]
	for card in cards:
		if card.id == id: bins[mini(3,card.tier)] += 1
	return bins

func _summary(id: String, inventory: Array) -> Dictionary:
	var n := 0
	var power := 0.0
	var peak := 0.0
	for card in inventory:
		if card.id == id:
			n += 1
			var value := weight(card.tier)
			power += value
			peak = maxf(peak,value)
	return {"n":n, "power":power, "peak":peak}

func _apply(id: String, old: Dictionary) -> void:
	var now := _summary(id,cards)
	game.equipment_panel.set_card_count(id,now.n)
	STATS.apply(game,id,old.n,now.n,old.power,now.power,now.peak)

func add_card(id: String, tier: int) -> int:
	if not enabled or not game.equipment_panel.EQUIP_DEFS.has(id): return -1
	var old := _summary(id,cards)
	if old.n >= int(game.equipment_panel.EQUIP_DEFS[id].get("max_level", 2147483647)): return -1
	var uid := _next_uid
	_next_uid += 1
	cards.append({"uid":uid,"id":id,"tier":maxi(tier,0)})
	_apply(id,old)
	game.arsenal_combo.refresh_equipment()
	game._refresh_growth_combo()
	return uid

func refill_practice() -> void:
	if not enabled or not training or _sealed_stage <= _settled_stage: return
	wallet += PRACTICE_GOLD
	for card in PRACTICE_CARDS:
		add_card(card[0],card[1])

func card_preview(id: String, tier: int) -> String:
	var old := _summary(id,cards)
	var value := weight(tier)
	var before := STATS.describe(game,id,old.n,old.power,old.peak,game.equipment_panel.crimson_active)
	var after := STATS.describe(game,id,old.n+1,old.power+value,maxf(value,old.peak),COMBOS.completes_crimson(game.equipment_panel,id))
	return before + " → " + after

func _card(uid: int) -> Dictionary:
	for card in cards:
		if card.uid == uid: return card
	return {}

func _name(id: String) -> String:
	return L10n.text(game.equipment_panel.EQUIP_DEFS[id].title)

func _set_active(inventory: Array, members: Array) -> bool:
	for id in members:
		if not inventory.any(func(c): return c.id == id): return false
	return true

func _score(inventory: Array) -> int:
	var value := 0.0
	for card in inventory: value += weight(card.tier)
	return roundi(value*10)

func preview(uid: int, subs: Array) -> Dictionary:
	var out := {"valid":false,"reason":"","cost":0,"up":0,"down":0,"stay":100,"changes":"","warnings":PackedStringArray(),"score_before":_score(cards),"score_after":_score(cards)}
	var main := _card(uid)
	if main.is_empty():
		out.reason = L10n.text("请选择一张主卡")
		return out
	if subs.size() > 2:
		out.reason = L10n.text("最多放入两张副卡")
		return out
	var material_weight := 0.0
	var used: Array = []
	var changed: Array = [main.id]
	for sub_uid in subs:
		var sub := _card(sub_uid)
		if sub.is_empty() or sub_uid == uid or sub_uid in used:
			out.reason = L10n.text("请选择不同的卡片")
			return out
		used.append(sub_uid)
		material_weight += minf(weight(sub.tier),5.0)
		if sub.id not in changed: changed.append(sub.id)
	var kept := cards.filter(func(c): return not c.uid in used)
	var has_attack := kept.any(func(c): return c.id in STARTER.WEAPONS or c.id in OTHER_ATTACKS)
	var tier: int = main.tier
	var price_factor: float = [1.5,1.0,0.65][subs.size()]
	out.cost = maxi(1,roundi(_standard_cost * price_factor))
	# Stay is the common high-tier result. Better furnaces approach the ceiling gradually.
	var furnace_gain := 1.0 - 1.0 / (1.0 + 0.12*(furnace_level-1))
	var base: float
	if tier < 2:
		base = minf(91.0,(66.0 if tier == 0 else 46.0) + subs.size()*6.0 + material_weight*1.2)
		out.up = lerpf(base,98.0,furnace_gain)
	else:
		base = 13.0-mini(tier-2,7)+subs.size()*3.0+material_weight*1.4
		out.up = lerpf(base,38.0,furnace_gain)
		out.down = lerpf(7.0-subs.size(),2.0,furnace_gain)
	out.stay = 100.0-out.up-out.down
	var lines := PackedStringArray()
	var crimson_before: bool = game.equipment_panel.crimson_active
	var crimson_after := _set_active(kept,COMBOS.CRIMSON_MEMBERS)
	if game.equipment_panel.dimension_active and not _set_active(kept,COMBOS.DIMENSION_MEMBERS):
		out.warnings.append(L10n.text("跨维度外包将失效"))
	if crimson_before and not crimson_after:
		out.warnings.append(L10n.text("绯刃四式将失效"))
		for member in COMBOS.CRIMSON_MEMBERS:
			if member not in changed: changed.append(member)
	for id: String in changed:
		var before := _summary(id,cards)
		var net := _summary(id,kept)
		if id == main.id:
			var next_power: float = net.power + weight(tier+1) - weight(tier)
			var after := STATS.describe(game,id,net.n,next_power,maxf(net.peak,weight(tier+1)),crimson_after)
			var original := STATS.describe(game,id,before.n,before.power,before.peak,crimson_before)
			lines.append("%s  %s → %s" % [_name(id),original,after])
			if not subs.is_empty() or tier >= 2:
				var hold := STATS.describe(game,id,net.n,net.power,net.peak,crimson_after)
				lines.append(L10n.text("保级：%s") % hold)
			if tier >= 2:
				var lower_peak := weight(tier-1)
				for other in kept:
					if other.id == id and other.uid != uid: lower_peak = maxf(lower_peak,weight(other.tier))
				var lower_power: float = net.power-weight(tier)+weight(tier-1)
				lines.append(L10n.text("降级：%s") % STATS.describe(game,id,net.n,lower_power,lower_peak,crimson_after))
		elif net.n == 0:
			out.warnings.append(L10n.text("失去：%s") % _name(id))
		else:
			lines.append("%s  %s → %s" % [_name(id),STATS.describe(game,id,before.n,before.power,before.peak,crimson_before),STATS.describe(game,id,net.n,net.power,net.peak,crimson_after)])
	if _set_active(cards,COMBOS.GROWTH_MEMBERS) and not _set_active(kept,COMBOS.GROWTH_MEMBERS):
		out.warnings.append(L10n.text("生机套装将失效"))
	if _set_active(cards,COMBOS.ARSENAL_MEMBERS) and not _set_active(kept,COMBOS.ARSENAL_MEMBERS):
		out.warnings.append(L10n.text("军械套装将失效"))
	out.score_after = _score(kept)+roundi((weight(tier+1)-weight(tier))*10)
	lines.append_array(out.warnings)
	out.changes = "\n".join(lines)
	if not has_attack: out.reason = L10n.text("必须保留一种可以独立攻击的装备")
	elif _sealed_stage == 0 or _settled_stage >= _sealed_stage: out.reason = L10n.text("当前锻造已结束")
	elif wallet < out.cost: out.reason = L10n.text("金币不足")
	else: out.valid = true
	return out

func attempt(uid: int, subs: Array) -> Dictionary:
	var plan := preview(uid,subs)
	if not plan.valid: return {"ok":false,"reason":plan.reason}
	var main := _card(uid)
	var affected := {str(main.id):_summary(main.id,cards)}
	for sub_uid in subs:
		var id: String = _card(sub_uid).id
		if not affected.has(id): affected[id] = _summary(id,cards)
	var roll := randf()*100.0
	var outcome := "stay"
	if roll < plan.up:
		main.tier += 1
		outcome = "up"
	elif roll < plan.up + plan.down:
		main.tier -= 1
		outcome = "down"
	wallet -= int(plan.cost)
	for i in range(cards.size()-1,-1,-1):
		if cards[i].uid in subs: cards.remove_at(i)
	for id: String in affected: _apply(id,affected[id])
	game.arsenal_combo.refresh_equipment()
	game._refresh_growth_combo()
	return {"ok":true,"outcome":outcome,"tier":main.tier}

func furnace_cost() -> int:
	return 55 + 15*(furnace_level-1)

func upgrade_furnace() -> bool:
	var cost := furnace_cost()
	return enabled and materials >= cost and _store(materials-cost,furnace_level+1)

func reward_preview() -> Dictionary:
	var rating := _score(cards)
	var base := maxi(1,roundi(rating/17.0))
	var stage: int = game.spawner.stage
	var pace := clampf(2.0-_stage_duration/PAR_SECONDS[clampi(stage-1,0,5)],0.0,1.0)
	var speed := roundi(base*0.12*pace)
	return {"rating":rating,"score":base,"speed":speed,"clear":maxi(5,base) if stage == game.spawner.FINAL_STAGE else 0,"total":base+speed}

func settle_stage() -> Dictionary:
	if _sealed_stage == 0 or _settled_stage >= _sealed_stage: return {}
	var reward := reward_preview()
	if not _store(materials+int(reward.total),furnace_level): return {}
	last_reward = reward
	_settled_stage = _sealed_stage
	run_materials += int(reward.total)
	return reward

func award_victory() -> void:
	if _settled_stage != game.spawner.FINAL_STAGE or victory_materials > 0: return
	var bonus := int(last_reward.get("clear",0))
	if bonus > 0 and _store(materials+bonus,furnace_level):
		victory_materials = bonus
		run_materials += bonus
