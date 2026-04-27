class_name TimeSelectView
extends Control

## Bazaar shell state view for choosing the next hour option.

signal option_selected(index: int)

const ItemArtCatalogClass = preload("res://scripts/data/item_art_catalog.gd")

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
	var summary: String = str(option.get("summary", ""))
	var art_path: String = str(option.get("art_path", ""))
	var palette: Dictionary = _get_option_palette(option_type)

	var card: Panel = Panel.new()
	card.name = "OptionCard%d" % index
	card.custom_minimum_size = Vector2(184, 168)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.add_theme_stylebox_override("panel", _make_card_style(palette))

	var bg: TextureRect = TextureRect.new()
	bg.name = "CardArt"
	var wiki_texture: Texture2D = ItemArtCatalogClass.load_texture(art_path)
	bg.texture = wiki_texture if wiki_texture != null else load(SHOP_CARD_BG if option_type == "shop" else EVENT_CARD_BG)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.add_child(bg)

	var tint: ColorRect = ColorRect.new()
	tint.name = "CardTint"
	tint.color = Color(0.0, 0.0, 0.0, 0.12)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.add_child(tint)

	var badge: Label = Label.new()
	badge.name = "TypeBadge"
	badge.text = str(palette["badge"])
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 12)
	badge.add_theme_color_override("font_color", palette["accent"])
	badge.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.72))
	badge.add_theme_constant_override("outline_size", 1)
	badge.anchor_left = 0.0
	badge.anchor_top = 0.0
	badge.anchor_right = 1.0
	badge.anchor_bottom = 0.0
	badge.offset_left = 8.0
	badge.offset_top = 7.0
	badge.offset_right = -8.0
	badge.offset_bottom = 28.0
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(badge)

	var title_ribbon: ColorRect = ColorRect.new()
	title_ribbon.name = "TitleRibbon"
	title_ribbon.color = Color(0.02, 0.02, 0.03, 0.58)
	title_ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_ribbon.anchor_left = 0.0
	title_ribbon.anchor_top = 1.0
	title_ribbon.anchor_right = 1.0
	title_ribbon.anchor_bottom = 1.0
	title_ribbon.offset_left = 0.0
	title_ribbon.offset_top = -50.0
	title_ribbon.offset_right = 0.0
	title_ribbon.offset_bottom = 0.0
	card.add_child(title_ribbon)

	var title_label: Label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.clip_text = true
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color(0.96, 0.91, 0.78, 1.0))
	title_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.80))
	title_label.add_theme_constant_override("outline_size", 2)
	title_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_label.offset_left = 8.0
	title_label.offset_top = 116.0
	title_label.offset_right = -8.0
	title_label.offset_bottom = -6.0
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(title_label)

	var hit_button: Button = Button.new()
	hit_button.name = "OptionHitButton%d" % index
	hit_button.text = ""
	hit_button.flat = true
	hit_button.focus_mode = Control.FOCUS_NONE
	hit_button.tooltip_text = title if summary.is_empty() else "%s\n%s" % [title, summary]
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
				"accent": Color(0.96, 0.78, 0.38, 1.0),
				"border": Color(0.92, 0.62, 0.25, 0.92),
				"fill": Color(0.22, 0.14, 0.10, 0.90),
			}
		"monster", "pvp":
			return {
				"badge": "BATTLE",
				"accent": Color(0.94, 0.36, 0.32, 1.0),
				"border": Color(0.86, 0.25, 0.22, 0.92),
				"fill": Color(0.20, 0.08, 0.08, 0.90),
			}
		_:
			return {
				"badge": "EVENT",
				"accent": Color(0.86, 0.70, 1.00, 1.0),
				"border": Color(0.62, 0.44, 0.88, 0.92),
				"fill": Color(0.16, 0.10, 0.22, 0.90),
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

func _on_option_pressed(index: int) -> void:
	option_selected.emit(index)
