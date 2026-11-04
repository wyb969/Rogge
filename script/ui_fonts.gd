class_name UiFonts
extends RefCounted




const PIXEL_PATH: = "res://assest/fonts/PixelOperator8.ttf"
const PIXEL_BOLD_PATH: = "res://assest/fonts/PixelOperator8-Bold.ttf"
const CJK_PATH: = "res://assest/fonts/DroidSansFallback.ttf"
const SYMBOLS_PATH: = "res://assest/fonts/RoggeSymbols.ttf"


const PREWARM_CHARS: = "↑↓←→↖↗↘↙0123456789.+-%:×xXvVlL!?BOSSCOMINGSTAGE /()[]，。！？、·~休整选择一项奖励生命减伤移速冷却下一关冲刺枪设置音量按键大小透明度难度简单中等困难拖动摇杆返回玉佩护盾击杀停手每秒方向键移动触屏左侧右侧晴阴雨雪昼日夜黄昏黎明天气特效宝囊精踏风徽记回响火种重抽剩余次数经验补充范围结束释放最后引爆截获剧毒踪迹中毒减速雾重叠满级预选可改确认领已全图掉落流星金色点清除小怪留补给馈赠控制镜头震动惯性关闭额外神兽祝福音效重合观察第一关四图标体验局部光影连续拾币亮观察光束枪火点狂奔巨蜥蓄力追踪准备闪避锁定横向连冲蓄势路线硬直反击机会逼近保持距离走位预警释放二阶段潮涌锋雷跃突袭熔壳滚动水泡落点汐道交叉印火种坠扇俯再来次连击射手感点燃轻巧播COMBFEVR!"

static var _ui: Font
static var _ui_bold: Font
static var _cjk: Font
static var _symbols: Font
static var _warmed: = {}

static func symbols() -> Font:
	if _symbols == null:
		_symbols = load(SYMBOLS_PATH) as Font
	return _symbols

static func ui() -> Font:
	if _ui != null:
		return _ui
	_ui = _make_composite(PIXEL_PATH)
	return _ui

static func ui_bold() -> Font:
	if _ui_bold != null:
		return _ui_bold
	_ui_bold = _make_composite(PIXEL_BOLD_PATH)
	return _ui_bold

static func cjk() -> Font:
	if _cjk != null:
		return _cjk
	_cjk = load(CJK_PATH) as Font
	return _cjk

static func apply_to_label(label: Control, size: int = 14, bold: bool = false) -> void :
	if label == null:
		return
	var font: = ui_bold() if bold else ui()
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	_prewarm(font, size)

static func apply_to_button(button: Button, size: int = 14) -> void :
	if button == null:
		return
	var font: = ui()
	button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", size)
	_prewarm(font, size)

static func _make_composite(base_path: String) -> Font:
	var base: = load(base_path) as Font
	var cjk_font: = load(CJK_PATH) as Font
	if base == null:
		return cjk_font
	var font: = base.duplicate() as Font
	if font == null:
		font = base

	if cjk_font != null:
		var fb: Array[Font] = [symbols(), cjk_font]
		font.fallbacks = fb
	_prewarm(font, 14)
	_prewarm(font, 15)
	_prewarm(font, 16)
	return font

static func _prewarm(font: Font, size: int) -> void :
	if font == null:
		return
	var key: = "%d:%d" % [font.get_instance_id(), size]
	if _warmed.has(key):
		return
	_warmed[key] = true

	font.get_string_size(PREWARM_CHARS, HORIZONTAL_ALIGNMENT_LEFT, -1, size)

	font.get_string_size("级架秒伤害存活间隔射速Lv", HORIZONTAL_ALIGNMENT_LEFT, -1, size)
