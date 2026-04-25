class_name TimeSelectView
extends Control

## Bazaar shell state view for choosing the next hour option.

signal option_selected(index: int)

const EVENT_CARD_BG: String = "res://assets/art/ui/ui_event_card_bg.png"
const SHOP_CARD_BG: String = "res://assets/art/ui/ui_shop_card_bg.png"

@onready var option_row: HBoxContainer = $OptionRow

var _options: Array[Dictionary] = []

func _ready() -> void:
	if not _options.is_empty():
		_refresh_options()

func set_options(options: Array[Dictionary]) -> void:
	_options = options.duplicate(true)
	if is_node_ready():
		_refresh_options()

func get_option_count() -> int:
	return mini(_options.size(), 3)

func _refresh_options() -> void:
	for child in option_row.get_children():
		child.queue_free()

	if _options.is_empty():
		_add_empty_state()
		return

	for index in range(get_option_count()):
		option_row.add_child(_create_option_card(_options[index], index))

func _create_option_card(option: Dictionary, index: int) -> Control:
	var option_type: String = str(option.get("type", "random_event"))
	var title: String = str(option.get("text", "Option"))
	var palette: Dictionary = _get_option_palette(option_type)

	var card: Panel = Panel.new()
	card.name = "OptionCard%d" % index
	card.custom_minimum_size = Vector2(210, 150)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.add_theme_stylebox_override("panel", _make_card_style(palette))

	var bg: TextureRect = TextureRect.new()
	bg.name = "CardArt"
	bg.texture = load(SHOP_CARD_BG if option_type == "shop" else EVENT_CARD_BG)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.modulate = palette["bg_modulate"]
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.add_child(bg)

	var tint: ColorRect = ColorRect.new()
	tint.name = "CardTint"
	tint.color = palette["tint"]
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.add_child(tint)

	var margin: MarginContainer = MarginContainer.new()
	margin.name = "ContentMargin"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)

	var stack: VBoxContainer = VBoxContainer.new()
	stack.name = "CardContent"
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 5)
	margin.add_child(stack)

	var badge: Label = Label.new()
	badge.name = "TypeBadge"
	badge.text = str(palette["badge"])
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 13)
	badge.add_theme_color_override("font_color", palette["accent"])
	stack.add_child(badge)

	var portrait: Panel = Panel.new()
	portrait.name = "PortraitDisk"
	portrait.custom_minimum_size = Vector2(76, 58)
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	portrait.add_theme_stylebox_override("panel", _make_portrait_style(palette))
	stack.add_child(portrait)

	var icon_label: Label = Label.new()
	icon_label.name = "IconLabel"
	icon_label.text = str(palette["icon"])
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 26)
	icon_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait.add_child(icon_label)

	var title_label: Label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.clip_text = true
	title_label.custom_minimum_size = Vector2(178, 42)
	title_label.add_theme_font_size_override("font_size", 17)
	title_label.add_theme_color_override("font_color", Color(0.96, 0.91, 0.78, 1.0))
	stack.add_child(title_label)

	var hit_button: Button = Button.new()
	hit_button.name = "OptionHitButton%d" % index
	hit_button.text = ""
	hit_button.flat = true
	hit_button.focus_mode = Control.FOCUS_NONE
	hit_button.tooltip_text = title
	hit_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hit_button.pressed.connect(_on_option_pressed.bind(index))
	card.add_child(hit_button)

	return card

func _add_empty_state() -> void:
	var label: Label = Label.new()
	label.name = "EmptyOptionsLabel"
	label.text = "No options"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.80, 0.82, 0.88, 0.72))
	label.custom_minimum_size = Vector2(280, 120)
	option_row.add_child(label)

func _get_option_palette(option_type: String) -> Dictionary:
	match option_type:
		"shop":
			return {
				"badge": "MERCHANT",
				"icon": "S",
				"accent": Color(0.96, 0.78, 0.38, 1.0),
				"border": Color(0.92, 0.62, 0.25, 0.92),
				"fill": Color(0.22, 0.14, 0.10, 0.90),
				"tint": Color(0.28, 0.16, 0.06, 0.26),
				"bg_modulate": Color(1.00, 0.88, 0.68, 0.90)
			}
		"monster", "pvp":
			return {
				"badge": "BATTLE",
				"icon": "X",
				"accent": Color(0.94, 0.36, 0.32, 1.0),
				"border": Color(0.86, 0.25, 0.22, 0.92),
				"fill": Color(0.20, 0.08, 0.08, 0.90),
				"tint": Color(0.34, 0.06, 0.06, 0.28),
				"bg_modulate": Color(1.00, 0.72, 0.68, 0.88)
			}
		"treasure":
			return {
				"badge": "REWARD",
				"icon": "+",
				"accent": Color(0.42, 0.92, 0.74, 1.0),
				"border": Color(0.28, 0.70, 0.58, 0.92),
				"fill": Color(0.06, 0.18, 0.16, 0.90),
				"tint": Color(0.04, 0.28, 0.20, 0.26),
				"bg_modulate": Color(0.72, 1.00, 0.84, 0.86)
			}
		"camp":
			return {
				"badge": "REST",
				"icon": "*",
				"accent": Color(0.56, 0.78, 1.00, 1.0),
				"border": Color(0.34, 0.58, 0.88, 0.92),
				"fill": Color(0.07, 0.12, 0.22, 0.90),
				"tint": Color(0.04, 0.14, 0.30, 0.24),
				"bg_modulate": Color(0.72, 0.84, 1.00, 0.86)
			}
		_:
			return {
				"badge": "EVENT",
				"icon": "?",
				"accent": Color(0.86, 0.70, 1.00, 1.0),
				"border": Color(0.62, 0.44, 0.88, 0.92),
				"fill": Color(0.16, 0.10, 0.22, 0.90),
				"tint": Color(0.20, 0.10, 0.36, 0.24),
				"bg_modulate": Color(0.88, 0.76, 1.00, 0.86)
			}

func _make_card_style(palette: Dictionary) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = palette["fill"]
	style.border_color = palette["border"]
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 4)
	return style

func _make_portrait_style(palette: Dictionary) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.05, 0.60)
	style.border_color = palette["accent"]
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	return style

func _on_option_pressed(index: int) -> void:
	option_selected.emit(index)
