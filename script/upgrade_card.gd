extends PanelContainer

signal selected(upgrade_id: String)
var upgrade_id: String = ""
var hover_tween: Tween
var _press_at := Vector2.ZERO
var _tracking_press := false
var _dragged := false

const CARD_SIZE: = Vector2(190, 154)
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
	title_label.text = title_label.tooltip_text.split(" · ")[0]
	title_label.max_lines_visible = 1
	tooltip_text = title_label.tooltip_text+"\n"+str(data.get("short_desc",""))+"\n"+str(data.get("desc",""))
	desc_label.text = str(data.get("draft_line",CodexData.draft_line(upgrade_id,data.get("rows",[]))))
	stats_label.text = ""
	stats_label.hide()
	icon.texture = load(data["icon"])
	preload("res://script/visual_style.gd").style_icon(icon, upgrade_id)
	set_display_width(CARD_SIZE.x)

func set_display_width(width: float, ui_scale: float = 1.0, compact: bool = false) -> void:
	set_display_size(Vector2(width,CARD_SIZE.y*ui_scale),ui_scale,compact)

func set_display_size(dimensions: Vector2, ui: float, row_layout: bool) -> void:
	custom_minimum_size = dimensions
	size = dimensions
	pivot_offset = size*0.5
	var narrow := dimensions.x/ui < 135
	var text_width := dimensions.x-12*ui
	var icon_size := minf((48.0 if narrow else 64.0)*ui,text_width)
	var title_height := 19*ui
	var body_height := 18*ui
	var block_height := icon_size+8*ui+title_height+body_height
	var top := maxf(8*ui,(dimensions.y-block_height)*0.5)
	UiFonts.apply_to_label(title_label,int((10 if narrow else 13)*ui))
	var font_size := int((10 if narrow else 12)*ui)
	# Fit one brief factual line without changing card geometry or overflowing neighbours.
	while font_size>int(8*ui) and UiFonts.ui().get_string_size(desc_label.get_parsed_text(),HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x>text_width:
		font_size-=1
	_style_description(font_size)
	for label in [title_label,desc_label,stats_label]: label.custom_minimum_size=Vector2.ZERO
	title_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	title_label.position=Vector2(6*ui,top+icon_size+8*ui)
	title_label.size=Vector2(text_width,title_height)
	desc_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode=TextServer.AUTOWRAP_OFF
	desc_label.position=title_label.position+Vector2(0,title_height)
	desc_label.size=Vector2(text_width,body_height)
	stats_label.size=Vector2(text_width,body_height)
	icon.custom_minimum_size=Vector2.ZERO
	icon.size=Vector2.ONE*icon_size
	icon.position=Vector2((dimensions.x-icon_size)*0.5,top)

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
