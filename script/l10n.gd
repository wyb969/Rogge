class_name L10n
extends RefCounted

# Source text is the stable key in locale/messages.csv. Translate BEFORE formatting.
# Godot's TranslationServer also updates scene-authored controls on locale changes.
const DEFAULT_LANGUAGE := "en"
const LANGUAGES := ["en", "zh_CN"]

static func normalized_language(value: String) -> String:
	return value if value in LANGUAGES else DEFAULT_LANGUAGE

static func text(source: String) -> String:
	return TranslationServer.translate(source)

static func button_overflow(button: Button) -> void:
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

static func title_overflow(label: Label) -> void:
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.max_lines_visible = 2
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.clip_text = true

static func tooltip(source: String, owner: Control) -> Label:
	var label := Label.new()
	label.text = text(source)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = minf(340, owner.get_viewport_rect().size.x - 40)
	UiFonts.apply_to_label(label, 14)
	return label
