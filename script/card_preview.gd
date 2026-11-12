extends RefCounted

const FAN := preload("res://script/banana_fan.gd")
const HOLE := preload("res://script/black_hole.gd")
const POISON := preload("res://script/poison_trail.gd")
const BOMB := preload("res://script/bomb_controller.gd")
const RING := preload("res://script/lightning_ring.gd")
const VARIETY := preload("res://script/run_variety.gd")
const CRIT := preload("res://script/critical_glasses.gd")
const BOOK := preload("res://script/circle_unit.gd")
const COMBOS := preload("res://script/equipment_combos.gd")

static func _row(rows: Array[Dictionary], label: String, before: float, after: float, unit: String = "", relative: bool = true, cost: bool = false) -> void:
	rows.append(CardNumbers.change(label,before,after,unit,relative,cost))

static func rank_for(game: Node, id: String) -> int:
	match id:
		"axe_up": return game.hand_weapon.level
		"circle_up": return game.circle_weapon.card_level
		"gun_up": return game.gun_weapon.level
		"drone_up": return game.drone_controller.level
		"molotov_up": return game.molotov_controller.level
		"freeze_up": return game.freeze_controller.level
		"regen_up": return game.player.regen_level
		"lifesteal_up": return game.player.lifesteal_level
		"shield_up": return game.player.shield_level
		"monster_necklace": return game.player.monster_necklace_level
		"critical_glasses": return game.player.critical_glasses_level
		"left_fist": return game.player.left_fist_level
		"right_fist": return game.player.right_fist_level
		"wind_emblem": return game.variety.wind_level
		"echo_ember": return game.variety.echo_level
		"bomb": return game.bomb_controller.level
		"banana_fan": return game.banana_fan.level
		"black_hole": return game.black_hole.level
		"poison_trail": return game.poison_trail.level
		"lightning_ring": return game.lightning_ring.level
	return game.equipment_panel.get_level(id)

static func build(game: Node, id: String) -> Dictionary:
	var rows: Array[Dictionary] = []
	if game == null: return {"rows":rows,"desc":"进入对局后显示当前数值","rich_desc":"进入对局后显示当前数值"}
	var player: Node = game.player
	var rank: int = rank_for(game,id)
	var next: int = rank + 1
	var hint := ""
	var growth_after: bool = true
	for member in COMBOS.GROWTH_MEMBERS:
		if game.equipment_panel.get_level(member) + (1 if member == id else 0) <= 0: growth_after = false
	var next_heal_scale: float = player.healing_multiplier * (COMBOS.HEAL_MULTIPLIER if growth_after else 1.0)
	match id:
		"speed_up":
			var after: float = player.move_speed_for(player.SPEED+player.SPEED_CARD_BONUS,COMBOS.MOVE_MULTIPLIER if growth_after else 1.0)
			_row(rows,"移速",player.effective_move_speed(),after)
		"pickup_up":
			_row(rows,"拾取半径",player.pickup_range,player.pickup_range * player.PICKUP_CARD_SCALE)
		"axe_up":
			var weapon: Node = game.hand_weapon
			var stats: Dictionary = weapon.upgrade_preview(game.current_level)
			_row(rows,"基础伤害",weapon.weapon_demage,stats.damage)
			_row(rows,"飞行速度",weapon.max_speed,stats.speed)
			hint = "往返各命中一次 · 不附带灼烧"
		"circle_up":
			var weapon: Node = game.circle_weapon
			var old_damage: float = weapon.get_child(0).weapon_demage
			_row(rows,"每本伤害",old_damage,BOOK.damage_for(maxi(weapon.current_level,game.current_level),next))
			_row(rows,"书本数量",weapon.num_weapons,weapon.count_for(next),"",false)
			_row(rows,"环绕速度",weapon.rotation_speed,weapon.rotation_for(next))
			hint = "最多12本 · 达上限后继续增伤"
		"gun_up":
			var gun: Node = game.gun_weapon
			var damage: float = gun.damage_for_upgrade(next)
			_row(rows,"单弹下限",gun.damage + 5 if rank > 0 else 0,damage + 5)
			_row(rows,"单弹上限",gun.damage + 15 if rank > 0 else 0,damage + 15)
			_row(rows,"射击间隔",gun.interval_for(rank) if rank > 0 else 0,gun.interval_for(next),"s")
			_row(rows,"穿透",gun.pierce if rank > 0 else 0,3 if next == 1 else next + 3,"",false)
		"drone_up":
			var drone: Node = game.drone_controller
			_row(rows,"激光伤害",drone.get_damage(rank) if rank > 0 else 0,drone.get_damage(next))
			_row(rows,"射击间隔",drone.get_fire_cd(rank) if rank > 0 else 0,drone.get_fire_cd(next),"s")
			_row(rows,"无人机数",drone.get_drone_count(rank) if rank > 0 else 0,drone.get_drone_count(next),"",false)
			_row(rows,"存活时间",drone.get_lifetime(rank) if rank > 0 else 0,drone.get_lifetime(next),"s")
		"molotov_up":
			var fire: Node = game.molotov_controller
			_row(rows,"每层秒伤",fire.get_burn_dps(rank) if rank > 0 else 0,fire.get_burn_dps(next))
			_row(rows,"燃烧层数",fire.get_burn_stacks(rank) if rank > 0 else 0,fire.get_burn_stacks(next),"",false)
			_row(rows,"投掷间隔",fire.get_throw_interval(rank) if rank > 0 else 0,fire.get_throw_interval(next),"s")
			_row(rows,"爆炸半径",fire.get_explode_radius(rank) if rank > 0 else 0,fire.get_explode_radius(next))
			hint = "命中附燃几率 " + CardNumbers.number(fire.get_on_hit_chance(next)*100) + "%"
		"freeze_up":
			var ice: Node = game.freeze_controller
			_row(rows,"冰冻几率",ice.get_on_hit_chance(rank)*100 if rank > 0 else 0,ice.get_on_hit_chance(next)*100,"%",false)
			_row(rows,"持续时间",ice.get_freeze_duration(rank) if rank > 0 else 0,ice.get_freeze_duration(next),"s")
			_row(rows,"减速幅度",(1-ice.get_slow_factor(rank))*100 if rank > 0 else 0,(1-ice.get_slow_factor(next))*100,"%",false)
			_row(rows,"冻伤增伤",ice.get_frozen_bonus(rank)*100 if rank > 0 else 0,ice.get_frozen_bonus(next)*100,"%",false)
		"regen_up":
			_row(rows,"每次回复",player.effective_heal_amount(player.regen_amount_for(rank)),player.regen_amount_for(next)*next_heal_scale,"",false)
			_row(rows,"回复间隔",player.regen_interval_for(rank) if rank > 0 else 0,player.regen_interval_for(next),"s")
		"monster_necklace":
			_row(rows,"每球回复",player.effective_heal_amount(player.monster_necklace_heal_for(rank)),player.monster_necklace_heal_for(next)*next_heal_scale,"",false)
			hint = "击杀掉落回血球 · 拾取时生效"
		"lifesteal_up":
			_row(rows,"命中回复比例",player.lifesteal_percent_for(rank)*player.total_healing_multiplier()*100 if rank > 0 else 0,player.lifesteal_percent_for(next)*next_heal_scale*100,"%",false)
			_row(rows,"固定回复",player.LIFESTEAL_FLAT*player.total_healing_multiplier() if rank > 0 else 0,player.LIFESTEAL_FLAT*next_heal_scale,"",false)
			_row(rows,"每次回复上限",player.effective_heal_amount(player.lifesteal_cap_for(rank)) if rank > 0 else 0,player.lifesteal_cap_for(next)*next_heal_scale,"",false)
			hint = "直接命中伤害至少8 · 持续伤害不吸血"
		"shield_up":
			_row(rows,"每杀护盾",player.shield_gain_for(rank),player.shield_gain_for(next),"",false)
			_row(rows,"衰减等待",player.shield_idle_for(rank) if rank > 0 else 0,player.shield_idle_for(next),"s")
			_row(rows,"每秒衰减",player.shield_decay_for(rank) if rank > 0 else 0,player.shield_decay_for(next),"",false)
		"critical_glasses":
			_row(rows,"暴击率",CRIT.chance_for(rank)*100,CRIT.chance_for(next)*100,"%",false)
			_row(rows,"暴击伤害",CRIT.damage_multiplier_for(rank)*100,CRIT.damage_multiplier_for(next)*100,"%",false)
			hint = "最高5级 · 直接攻击生效\n满级暴击伤害200% · 持续伤害不暴击"
		"left_fist", "right_fist":
			var left: int = player.left_fist_level
			var right: int = player.right_fist_level
			var new_left: int = left + (1 if id == "left_fist" else 0)
			var new_right: int = right + (1 if id == "right_fist" else 0)
			for side in [true,false]:
				var before: float = player.side_multiplier_for(side,left,right)*100
				var after: float = player.side_multiplier_for(side,new_left,new_right)*100
				_row(rows,"左侧伤害" if side else "右侧伤害",before,after,"%",false,after < before)
			hint = "双持取消另一侧伤害惩罚"
		"bomb", "banana_fan", "black_hole", "poison_trail", "lightning_ring", "wind_emblem", "echo_ember":
			var source: Script = {"bomb":BOMB,"banana_fan":FAN,"black_hole":HOLE,"poison_trail":POISON,"lightning_ring":RING}.get(id,VARIETY)
			var before: Dictionary = source.wind_stats(maxi(rank,1)) if id == "wind_emblem" else (source.echo_stats(maxi(rank,1)) if id == "echo_ember" else source.stats_for(maxi(rank,1)))
			var after: Dictionary = source.wind_stats(next) if id == "wind_emblem" else (source.echo_stats(next) if id == "echo_ember" else source.stats_for(next))
			for key in ["damage","dps","radius","range","interval","bolts","kills"]:
				if not after.has(key): continue
				var label: String = {"damage":"基础伤害","dps":"每秒伤害","radius":"作用半径","range":"作用距离","interval":"触发间隔","bolts":"闪电目标","kills":"所需击杀"}[key]
				_row(rows,label,float(before[key]) if rank > 0 else 0,float(after[key]),"s" if key == "interval" else "",key not in ["bolts","kills"])
			hint = {"bomb":"爆炸击飞 · 最高5级","banana_fan":"气流击退 · 最高5级\n已有灼烧/中毒追加一跳，不传播","black_hole":"牵引聚怪 · 持续3秒 · 最高5级","poison_trail":"移动留雾 · 持续4 秒\n最高5级减速25% · 重叠不叠伤","lightning_ring":"同时击中不同目标","wind_emblem":"冲刺结束释放风压","echo_ember":"最后击杀处引爆回响"}[id]
	var combo: String = COMBOS.hint_for(id)
	if not combo.is_empty(): hint += ("\n" if not hint.is_empty() else "") + combo
	var suffix := ("\n" + hint) if not hint.is_empty() else ""
	return {"rows":rows,"desc":CardNumbers.join(rows)+suffix,"rich_desc":CardNumbers.join(rows,true)+suffix}
