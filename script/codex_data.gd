class_name CodexData
extends RefCounted

const EQUIPMENT = preload("res://script/equipment_panel.gd")
const PREVIEW = preload("res://script/card_preview.gd")
const POWERS = preload("res://script/beast_powers.gd")
const TRIALS = preload("res://script/trials.gd")
const CATEGORIES = ["装备", "怪物", "首领", "试炼", "技能与组合"]
const CARDS = {
	"axe_up": {
		"summary": "回旋斧穿过敌群，往返各命中一次。",
		"detail": "斧头沿投掷路径往返，同一轮去程和回程分别命中。升级提高基础伤害与飞行速度；不会附带汽油瓶的范围燃烧。"
	},
	"circle_up": {
		"summary": "书本环绕身体，持续保护近身范围。",
		"detail": "书本绕玩家旋转，接触敌人造成伤害。升级增加数量、伤害与环绕速度；最多十二本，达到数量上限后仍可强化伤害。"
	},
	"gun_up": {
		"summary": "自动射击，穿透前方的敌人。",
		"detail": "枪支自动发射子弹。升级影响伤害、射击间隔和穿透；实际冷却还受休整奖励影响。与无人机、炸弹组成军械护盾组合。"
	},
	"pickup_up": {
		"summary": "扩大拾取范围，轻松收集补给。",
		"detail": "增加拾取半径，让附近金币和补给更容易被吸引。金币用于获得经验。集齐拾取、移速、回复后激活生机组合。"
	},
	"speed_up": {
		"summary": "提高移动速度，更轻松走位。",
		"detail": "每次升级增加二十点基础移动速度，并受当前移速倍率影响。它不改变冲刺方向规则。与拾取、回复组成生机组合。"
	},
	"left_fist": {
		"summary": "强化左侧攻击；双拳一起装备更强。",
		"detail": "强化玩家左侧的直接伤害。只装备单侧时另一侧有伤害惩罚；左右拳同时装备后取消该惩罚。升级对比会体现当前双持状态。"
	},
	"right_fist": {
		"summary": "强化右侧攻击；双拳一起装备更强。",
		"detail": "强化玩家右侧的直接伤害。只装备单侧时另一侧有伤害惩罚；左右拳同时装备后取消该惩罚。升级对比会体现当前双持状态。"
	},
	"drone_up": {
		"summary": "无人机自动发射激光支援。",
		"detail": "无人机自动攻击附近敌人。升级改善激光伤害、射击间隔、数量与存活时间。与枪支、炸弹组成军械护盾组合。"
	},
	"molotov_up": {
		"summary": "投掷火瓶，在敌群中附加灼烧。",
		"detail": "汽油瓶爆炸并施加灼烧，持续伤害按时间结算。升级提高灼烧强度、层数、爆炸范围并缩短投掷间隔；芭蕉扇可让已有灼烧追加一跳，不重复传播。"
	},
	"freeze_up": {
		"summary": "命中有几率冰冻敌人，减缓威胁。",
		"detail": "直接命中有几率触发冰冻。升级影响触发几率、持续时间、减速与冻伤增伤。它是一张命中增益卡，不会单独发射武器。"
	},
	"regen_up": {
		"summary": "定时回血，提高持续作战能力。",
		"detail": "按固定间隔恢复生命，升级提高回复量并缩短间隔。实际治疗受难度和生机组合倍率影响。与拾取、移速组成生机组合。"
	},
	"lifesteal_up": {
		"summary": "直接攻击回复生命，持续伤害不吸血。",
		"detail": "符合条件的直接命中会回复生命，包含比例、固定回复和单次上限。持续伤害不触发吸血，低于门槛的伤害也不触发。"
	},
	"shield_up": {
		"summary": "击杀积累护盾，停手后逐渐衰减。",
		"detail": "每次击杀增加护盾，停止积累一段时间后逐渐衰减。升级增加每杀护盾并改善衰减等待和速度。它与神兽减伤、军械无敌护盾是不同效果。"
	},
	"monster_necklace": {
		"summary": "击杀掉落回血球，拾取后治疗。",
		"detail": "击杀敌人后掉落绿色回血球，拾取时才恢复生命。一级每球回复五点，升级提高回复量；实际治疗受治疗倍率影响。满血时仍可留意地上补给。"
	},
	"lightning_ring": {
		"summary": "闪电自动跳向附近多个敌人。",
		"detail": "周期性选择附近不同目标并落雷。升级提高伤害、目标数量和范围。同次攻击选择不同敌人，适合清理分散目标。"
	},
	"critical_glasses": {
		"summary": "直接攻击有几率暴击，满级必定暴击。",
		"detail": "每级增加百分之二十暴击率，最高五级。一级至四级暴击为百分之一百五十伤害，五级为百分之二百。持续伤害不暴击，暴击使用更大的伤害数字。"
	},
	"banana_fan": {
		"summary": "吹退前方敌人，并追加一跳已有异常。",
		"detail": "沿移动方向吹出伤害气流，击退扇形范围内敌人。升级扩大距离、提高伤害并缩短冷却。已有灼烧或中毒可追加一跳，同次吹风不重复触发，也不会递归传播。"
	},
	"black_hole": {
		"summary": "周期生成黑洞，把敌人聚拢并持续伤害。",
		"detail": "自动生成持续三秒的小黑洞，牵引范围内敌人并按时间造成伤害。升级提高范围和伤害并缩短冷却，最高五级；适合配合范围攻击。"
	},
	"poison_trail": {
		"summary": "移动留下紫色毒雾，满级附加减速。",
		"detail": "移动留下持续四秒的毒雾，敌人在里面持续受毒伤。升级提高每秒伤害，五级增加百分之二十五减速。重叠毒雾不叠加伤害，中毒不会触发直接命中暴击。"
	},
	"bomb": {
		"summary": "自动抛出炸弹，范围爆炸并击飞。",
		"detail": "周期性向敌人投掷炸弹，落点爆炸造成范围伤害并击飞。升级提高伤害、爆炸范围并缩短冷却，最高五级。与无人机、枪支组成军械护盾组合。"
	},
	"wind_emblem": {
		"summary": "冲刺结束释放风压，推开附近敌人。",
		"detail": "冲刺结束时向周围释放风压并造成伤害。升级强化风压表现对应的实际伤害和作用范围。适合用冲刺主动切入或脱离敌群。"
	},
	"echo_ember": {
		"summary": "积累击杀，在最后击杀处引爆回响。",
		"detail": "击杀为回响火种充能，达到阈值后在最后击杀的位置引爆。升级改善伤害、范围与所需击杀数，适合持续清理密集怪群。"
	},
	"silver_knife": {
		"summary": "自动瞄准附近敌人，飞刀穿透目标。",
		"detail": "飞刀自动瞄准附近敌人，不要求玩家朝向敌人。每把飞刀对同一目标命中一次。升级提高伤害、数量、飞行距离并改善攻击间隔，最高五级。"
	},
	"cross_blade": {
		"summary": "十字刃往返飞行，两程都能命中。",
		"detail": "十字刃自动瞄准后沿固定路径飞出并返回，去程和回程分别命中。升级强化伤害、距离与攻击节奏，最高五级。"
	},
	"holy_water": {
		"summary": "在敌人脚下留下持续伤害的净化区。",
		"detail": "在敌人脚下制造净化区域，每半秒结算一次伤害。重叠区域不会叠加伤害，也不触发暴击或异常传播。每个区域持续三秒；升级提高每秒伤害、范围和出现频率，最高五级。"
	},
	"thorn_whip": {
		"summary": "自动瞄准，以近身鞭击横扫敌群。",
		"detail": "以一百二十度扇形横扫近身敌人。升级提高伤害和攻击距离，并改善触发间隔，最高五级。靠近敌群时更容易发挥效果。"
	},
	"rune_bolt": {
		"summary": "符文飞弹反弹并穿透区域内敌人。",
		"detail": "飞弹在固定符文区域边界内反弹并穿透敌人。同一飞弹对同一敌人的再次命中至少间隔零点三五秒。升级提高数量、伤害、范围并缩短攻击间隔，最高五级。"
	},
	"pulse_aura": {
		"summary": "玩家周围周期释放伤害脉冲。",
		"detail": "以玩家为中心周期性伤害附近敌人。升级提高伤害、半径并缩短间隔，最高五级。脉冲不暴击，也不传播异常伤害。"
	}
}
const EXTRA = [
	{
		"id": "chaser",
		"category": 1,
		"title": "追击怪",
		"icon": "resource:Enemy_1",
		"detail": "持续靠近玩家，以接触攻击造成伤害。保持移动，避免被多只包围。",
		"frames": 1
	},
	{
		"id": "brute",
		"category": 1,
		"title": "重装追击怪",
		"icon": "resource:Enemy2",
		"detail": "比普通追击怪更耐打，移动稍慢。可用击退和范围武器控制它与其他怪物的距离。",
		"frames": 1
	},
	{
		"id": "tank",
		"category": 1,
		"title": "重甲箱怪",
		"icon": "resource:Enemy_3",
		"detail": "体型大、生命与减伤较高，移动缓慢。不要长时间贴身，让它追着你进入范围攻击区域。",
		"frames": 1
	},
	{
		"id": "ranged",
		"category": 1,
		"title": "远程眼怪",
		"icon": "resource:Enemy_4",
		"detail": "保持一定距离发射红色子弹。移动走位躲弹，别把敌弹误当成金币。",
		"frames": 1
	},
	{
		"id": "dasher",
		"category": 1,
		"title": "敏捷突击怪",
		"icon": "resource:Enemy_5",
		"detail": "移动快但生命低。红色方向提示锁定后发起突击，命中玩家后会短暂停顿；利用攻击间隙脱离。",
		"frames": 1
	},
	{
		"id": "mantis",
		"category": 1,
		"title": "刃螳",
		"icon": "resource:BladeMantis",
		"detail": "靠近后蓄力进行扇形斩击。红色范围锁定后移出，冰冻、击退等控制可以打断它的攻击。",
		"frames": 1
	},
	{
		"id": "imp",
		"category": 1,
		"title": "回旋镖妖",
		"icon": "resource:BoomerangImp",
		"detail": "远程投出回旋攻击，去程和回程都需要注意。不要只躲开第一段就立刻回到原位。",
		"frames": 1
	},
	{
		"id": "spore",
		"category": 1,
		"title": "孢子炮手",
		"icon": "resource:SporeBomber",
		"detail": "向玩家附近抛出孢子炸弹。留意地面红色落点提示，提前离开爆炸区域。",
		"frames": 1
	},
	{
		"id": "courier",
		"category": 1,
		"title": "宝囊精",
		"icon": "resource:LootCourier",
		"detail": "限时逃跑的奖励怪物，不主动造成接触伤害。击败它可获得经验并补充重抽；重抽已满时转为额外经验。",
		"frames": 1
	},
	{
		"id": "dino",
		"category": 2,
		"title": "狂奔巨蜥",
		"icon": "res://rogge_art/bosses/lizard/poses.png",
		"detail": "第一关首领以追踪蓄力和冲锋压迫玩家。预警锁定后横向闪避，在冲锋后的硬直反击；二阶段要注意连续冲锋。",
		"frames": 4
	},
	{
		"id": "knight",
		"category": 2,
		"title": "钢铁骑士",
		"icon": "res://rogge_art/bosses/knight/poses.png",
		"detail": "第二关首领用冲刺接近并挥剑斩击。红色扇形表示剑的危险范围，注意冲刺后的连招；二阶段攻击频率更快。",
		"frames": 4
	},
	{
		"id": "tide",
		"category": 2,
		"title": "潮汐巨象",
		"icon": "res://rogge_art/bosses/tide/poses.png",
		"detail": "水属性神兽使用潮涌冲锋、水泡落点和水道攻击。离开红色区域，利用移动后的恢复期输出。击败后获得潮汐复苏。",
		"frames": 4
	},
	{
		"id": "thunder",
		"category": 2,
		"title": "雷鬃狮王",
		"icon": "res://rogge_art/bosses/thunder/poses.png",
		"detail": "雷属性神兽用跳跃突袭和落雷追击。交叉预警会留下安全空隙，避免沿危险路线直跑。击败后获得雷霆裁决，并进入力量试炼。",
		"frames": 4
	},
	{
		"id": "gale",
		"category": 2,
		"title": "苍风双隼",
		"icon": "res://rogge_art/bosses/wind-ranged/poses.png",
		"detail": "风之战由远程术隼和近战猎隼共同参与。术隼施放风刃，猎隼俯冲突袭；保持两者都在视野内，注意不同预警。击败后获得苍风牵引。",
		"frames": 4
	},
	{
		"id": "aegis",
		"category": 2,
		"title": "熔岩玄龟",
		"icon": "res://rogge_art/bosses/aegis/poses.png",
		"detail": "防御型神兽使用熔壳滚动、熔岩环和火种坠落。别长时间站在近身危险区；二阶段更紧凑。击败后获得玄岩壁垒，随后进入速度试炼。",
		"frames": 4
	},
	{
		"id": "treasure",
		"category": 2,
		"title": "宝藏守卫",
		"icon": "res://rogge_art/bosses/guardian/poses.png",
		"detail": "中途出现的精英奖励敌人，生命较多，会预警后重击周围。击败后获得老虎机奖励：随机一张卡通常升两级，少量情况升三级或一级。",
		"frames": 4
	},
	{
		"id": "trial_power",
		"category": 3,
		"title": "力量试炼",
		"icon": "res://assest/sprites/trials/clockwork_octopus.svg",
		"trial": "power"
	},
	{
		"id": "trial_speed",
		"category": 3,
		"title": "速度试炼",
		"icon": "res://assest/sprites/trials/blink_wizard.svg",
		"trial": "speed"
	},
	{
		"id": "trial_wooden",
		"category": 3,
		"title": "木头人挑战",
		"icon": "res://rogge_art/icons/skills-equipment/A057.png",
		"trial": "wooden"
	},
	{
		"id": "power_tide",
		"category": 4,
		"power": 0,
		"icon": "res://rogge_art/icons/skills-equipment/A054.png"
	},
	{
		"id": "power_thunder",
		"category": 4,
		"power": 1,
		"icon": "res://rogge_art/icons/skills-equipment/A055.png"
	},
	{
		"id": "power_gale",
		"category": 4,
		"power": 2,
		"icon": "res://rogge_art/icons/skills-equipment/A056.png"
	},
	{
		"id": "power_aegis",
		"category": 4,
		"power": 3,
		"icon": "res://rogge_art/icons/skills-equipment/A057.png"
	},
	{
		"id": "combo_growth",
		"category": 4,
		"title": "生机组合",
		"icon": "equipment:pickup_up",
		"detail": "同时装备拾取、移速和回复：经验获取增加百分之三十，移动速度与治疗效果增加百分之二十。同组装备边缘同步发光。",
		"frames": 1
	},
	{
		"id": "combo_arsenal",
		"category": 4,
		"title": "军械组合",
		"icon": "equipment:bomb",
		"detail": "同时装备无人机、枪支和炸弹：每三秒获得一秒无敌护盾。装备边缘以同频金色流光表示组合已生效。",
		"frames": 1
	}
]

static func entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id in EQUIPMENT.EQUIP_DEFS:
		var def: Dictionary = EQUIPMENT.EQUIP_DEFS[id]
		result.append({"id":id,"category":0,"title":def.title,"icon":def.icon,"detail":CARDS[id].detail})
	for source in EXTRA:
		var entry: Dictionary = source.duplicate()
		if entry.has("power"): entry.title = POWERS.TITLES[entry.power]
		result.append(entry)
	return result

static func texture_for(entry: Dictionary) -> Texture2D:
	var path: String = entry.icon
	if path.begins_with("resource:"): return load("res://resource/"+path.trim_prefix("resource:")+".tres").sprite
	if path.begins_with("equipment:"): path = EQUIPMENT.EQUIP_DEFS[path.trim_prefix("equipment:")].icon
	var texture: Texture2D = load(path)
	if entry.get("frames",1)>1:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(0,0,texture.get_width()/float(entry.frames),texture.get_height()/float(entry.frames))
		return atlas
	return texture

static func description(entry: Dictionary, game: Node = null) -> String:
	if entry.has("trial"): return L10n.text(TRIALS.RULES[entry.trial])
	if entry.has("power"):
		return game.beast_powers.description_for(entry.power) if is_instance_valid(game) else L10n.text(POWERS.DESCRIPTIONS[entry.power])
	var body := L10n.text(entry.get("detail",""))
	if entry.category == 0:
		var cap: int = EQUIPMENT.EQUIP_DEFS[entry.id].get("max_level",0)
		body += "\n\n" + (L10n.text("最高等级：%d") % cap if cap>0 else L10n.text("可继续升级，具体数值随当前构筑变化。"))
		if is_instance_valid(game):
			if cap>0 and PREVIEW.rank_for(game,entry.id)>=cap: body += "\n"+L10n.text("已达到最高等级")
			else: body += "\n\n"+L10n.text("当前构筑 · 下一次升级")+"\n"+str(PREVIEW.build(game,entry.id).desc)
		else: body += "\n\n"+L10n.text("在对局中打开词典，可查看当前数值与升级对比。")
	return body

static func summary(id: String) -> String:
	return L10n.text(CARDS.get(id,{}).get("summary",""))

static func compact_stats(rows: Array) -> String:
	var lines := PackedStringArray()
	# Draft cards show the primary damage/utility stat; full comparisons remain in the Codex.
	var selected: Array = rows.slice(0,mini(1,rows.size()))
	for row in selected:
		lines.append(L10n.text(row.label)+"\n[b]"+CardNumbers.value_pair(row.before,row.after,row.unit)+"[/b]")
	return "\n".join(lines)

const DRAFT_LINES = {"axe_up": "穿透 %s伤", "circle_up": "环绕 %s伤", "gun_up": "射击≥%s伤", "pickup_up": "拾取 %s", "speed_up": "移速 %s", "left_fist": "左侧 %s%%", "right_fist": "右侧 %s%%", "drone_up": "激光 %s伤", "molotov_up": "灼烧 %s/秒", "freeze_up": "冰冻 %s%%", "regen_up": "回复 %s生命", "lifesteal_up": "吸血 %s%%", "shield_up": "击杀+%s盾", "monster_necklace": "拾取回%s血", "lightning_ring": "雷击 %s伤", "critical_glasses": "暴击 %s%%", "banana_fan": "击退 %s伤", "black_hole": "聚怪 %s/秒", "poison_trail": "中毒 %s/秒", "bomb": "爆炸 %s伤", "wind_emblem": "风压 %s伤", "echo_ember": "回响 %s伤", "silver_knife": "飞刀 %s伤", "cross_blade": "回旋 %s伤", "holy_water": "净化 %s/秒", "thorn_whip": "横扫 %s伤", "rune_bolt": "反弹 %s伤", "pulse_aura": "脉冲 %s伤"}

static func draft_line(id: String, rows: Array) -> String:
	if rows.is_empty(): return ""
	var row: Dictionary=rows[1] if id=="right_fist" else rows[0]
	return L10n.text(DRAFT_LINES[id]) % CardNumbers.number(row.after)
