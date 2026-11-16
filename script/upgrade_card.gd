extends PanelContainer

signal selected(upgrade_id: String)
var upgrade_id: String = ""
var hover_tween: Tween
var _press_at := Vector2.ZERO
var _tracking_press := false
var _dragged := false

const CARD_SIZE: = Vector2(280, 270)
var stats_label: RichTextLabel

@onready var title_label: Label = $VBoxContainer / TitleLabel
@onready var desc_label: RichTextLabel = $VBoxContainer / DescLabel
@onready var icon: TextureRect = $VBoxContainer / Icon

func _ready() -> void :
	# Keep readable card panels after removing the old global recoloring theme.
	var style := GamePalette.neutral_surface(GamePalette.UI_SLOT, GamePalette.UI_GREY_BORDER)
	for side in ["left","right","top","bottom"]: style.set("content_margin_"+side,0)
	add_theme_stylebox_override("panel", style)
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	call_deferred("_init_pivot")

	mouse_entered.connect(_on_mouse_enter)
	mouse_exited.connect(_on_mouse_exited)

	_configure_labels()
	stats_label = RichTextLabel.new()
	stats_label.bbcode_enabled = true
	stats_label.fit_content = false
	stats_label.scroll_active = false
	stats_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	$VBoxContainer.add_child(stats_label)

func _configure_labels() -> void :
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	L10n.title_overflow(title_label)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.custom_minimum_size.y = 40
	UiFonts.apply_to_label(title_label, 16)

	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_label.custom_minimum_size = Vector2(CARD_SIZE.x - 24.0, 0.0)
	desc_label.fit_content = false
	_style_description(14)

	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	$VBoxContainer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

func setup(data: Dictionary):
	upgrade_id = data["id"]

	title_label.tooltip_text = L10n.text(str(data.get("title", "")))
	# Keep the rank comparison visible instead of truncating it after a long name.
	title_label.text = title_label.tooltip_text.replace(" · ", "\n")
	desc_label.text = str(data.get("short_desc",CodexData.summary(upgrade_id)))
	stats_label.text = str(data.get("compact_stats",CodexData.compact_stats(data.get("rows",[]))))
	icon.texture = load(data["icon"])
	preload("res://script/visual_style.gd").style_icon(icon, upgrade_id)
	set_display_width(CARD_SIZE.x)

func set_display_width(width: float, ui_scale: float = 1.0, compact: bool = false) -> void:
	set_display_size(Vector2(width,CARD_SIZE.y*ui_scale),ui_scale,compact)

func set_display_size(dimensions: Vector2, ui: float, row_layout: bool) -> void:
	custom_minimum_size = dimensions
	size = dimensions
	pivot_offset = size*0.5
	var small := dimensions.y/ui < 160 if row_layout else dimensions.y/ui < 235
	var font_size := 11 if small else 12
	var icon_size := (60.0 if small else 72.0)*ui
	var text_x := (82.0 if small else 94.0)*ui if row_layout else 12*ui
	var text_width := dimensions.x-text_x-12*ui
	var title_y := 10*ui if row_layout else icon_size+16*ui
	var title_height := 32*ui if small else 40*ui
	var stats_height := (32.0 if small else 40.0)*ui
	var stats_y := dimensions.y-10*ui-stats_height
	var desc_y := title_y+title_height+3*ui
	UiFonts.apply_to_label(title_label,int((11 if small else 14)*ui))
	_style_description(int(font_size*ui))
	stats_label.add_theme_font_override("normal_font",UiFonts.ui())
	stats_label.add_theme_font_override("bold_font",UiFonts.ui_bold())
	stats_label.add_theme_font_size_override("normal_font_size",int(font_size*ui))
	stats_label.add_theme_font_size_override("bold_font_size",int(font_size*ui))
	for label in [title_label,desc_label,stats_label]:
		label.custom_minimum_size=Vector2.ZERO
		label.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT if row_layout else HORIZONTAL_ALIGNMENT_CENTER
	title_label.position=Vector2(text_x,title_y)
	title_label.size=Vector2(text_width,title_height)
	desc_label.position=Vector2(text_x,desc_y)
	desc_label.size=Vector2(text_width,maxf(1,stats_y-desc_y-4*ui))
	stats_label.position=Vector2(text_x,stats_y)
	stats_label.size=Vector2(text_width,stats_height)
	icon.custom_minimum_size=Vector2.ZERO
	icon.size=Vector2.ONE*icon_size
	icon.position=Vector2(10*ui,(dimensions.y-icon_size)*0.5) if row_layout else Vector2((dimensions.x-icon_size)*0.5,10*ui)

func _on_selected_pressed():
	selected.emit(upgrade_id)

func _gui_input(event: InputEvent) -> void :
	if event is InputEventScreenDrag or event is InputEventMouseMotion:
		if _tracking_press and event.position.distance_to(_press_at) > 10.0:
			_dragged = true
	elif event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		if event.pressed:
			_press_at = event.position
			_tracking_press = true
			_dragged = false
		else:
			var choose := _tracking_press and not _dragged and Rect2(Vector2.ZERO,size).has_point(event.position)
			_tracking_press = false
			if choose:
				selected.emit(upgrade_id)
				accept_event()

func _on_mouse_enter() -> void :
	play_hover_tween(Vector2(1.02, 1.02), Color(1.1, 1.1, 1.1), 0.12)

func _on_mouse_exited() -> void :
	play_hover_tween(Vector2.ONE, Color.WHITE, 0.12)

func play_hover_tween(target_scale: Vector2, target_color: Color, duration: float):
	if hover_tween != null and hover_tween.is_valid():
		hover_tween.kill()

	hover_tween = create_tween()
	hover_tween.set_trans(Tween.TRANS_BACK)
	hover_tween.set_ease(Tween.EASE_OUT)
	hover_tween.tween_property(self, "scale", target_scale, duration)
	hover_tween.parallel().tween_property(self, "modulate", target_color, duration)

func _init_pivot():
	pivot_offset = size / 2.0

func _style_description(font_size: int) -> void:
	desc_label.add_theme_font_override("normal_font",UiFonts.ui())
	desc_label.add_theme_font_override("bold_font",UiFonts.ui_bold())
	desc_label.add_theme_font_size_override("normal_font_size",font_size)
	desc_label.add_theme_font_size_override("bold_font_size",font_size)
	desc_label.add_theme_color_override("default_color",GamePalette.PLAYER_DAMAGE_WHITE)
