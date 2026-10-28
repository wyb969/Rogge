class_name UiFonts
extends RefCounted
## Shared UI font for web + desktop.
## PixelOperator8 provides reliable Latin/digits on HTML5;
## DroidSansFallback covers Chinese when a glyph is missing.

const PIXEL_PATH := "res://assest/fonts/PixelOperator8.ttf"
const PIXEL_BOLD_PATH := "res://assest/fonts/PixelOperator8-Bold.ttf"
const CJK_PATH := "res://assest/fonts/DroidSansFallback.ttf"

## Chars that must never tofu on web (digits / punctuation / level tags).
const PREWARM_CHARS := "0123456789.+-%:×xXvVlL /()[]，。！？、·~"

static var _ui: Font
static var _ui_bold: Font
static var _cjk: Font

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

static func apply_to_label(label: Control, size: int = 14, bold: bool = false) -> void:
	if label == null:
		return
	var font := ui_bold() if bold else ui()
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	_prewarm(font, size)

static func apply_to_button(button: Button, size: int = 14) -> void:
	if button == null:
		return
	var font := ui()
	button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", size)
	_prewarm(font, size)

static func _make_composite(base_path: String) -> Font:
	var base := load(base_path) as Font
	var cjk_font := load(CJK_PATH) as Font
	if base == null:
		return cjk_font
	var font := base.duplicate() as Font
	if font == null:
		font = base
	# Missing CJK glyphs fall through to DroidSansFallback.
	if cjk_font != null:
		var fb: Array[Font] = [cjk_font]
		font.fallbacks = fb
	_prewarm(font, 14)
	_prewarm(font, 15)
	_prewarm(font, 16)
	return font

static func _prewarm(font: Font, size: int) -> void:
	if font == null:
		return
	# Force glyph atlas generation for digits / ASCII used in format strings.
	font.get_string_size(PREWARM_CHARS, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	# Also touch a tiny Chinese sample so fallback path is initialized on web.
	font.get_string_size("级架秒伤害存活间隔射速Lv", HORIZONTAL_ALIGNMENT_LEFT, -1, size)
