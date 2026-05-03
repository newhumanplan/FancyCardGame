class_name RewardChoiceView
extends Control

## Bazaar shell state view for reward and level-up selections.

signal option_selected(index: int)

@onready var title_label: Label = $Layout/Header/TitleLabel
@onready var subtitle_label: Label = $Layout/Header/SubtitleLabel
@onready var option_row: HBoxContainer = $Layout/OptionRow

var _choice: Dictionary = {}

func _ready() -> void:
	if not _choice.is_empty():
		_refresh_choice()

func set_choice(choice: Dictionary) -> void:
	_choice = choice.duplicate(true)
	if is_node_ready():
		_refresh_choice()

func get_option_count() -> int:
	var options: Array = _choice.get("options", [])
	return mini(options.size(), 3)

func _refresh_choice() -> void:
	title_label.text = str(_choice.get("title", "Choose Reward"))
	subtitle_label.text = str(_choice.get("subtitle", "Pick one reward."))
	for child in option_row.get_children():
		child.queue_free()

	if get_option_count() <= 0:
		_add_empty_state()
		return

	var options: Array = _choice.get("options", [])
	for index in range(get_option_count()):
		var option: Dictionary = {}
		if options[index] is Dictionary:
			option = (options[index] as Dictionary).duplicate(true)
		option_row.add_child(_create_option_card(option, index))

func _create_option_card(option: Dictionary, index: int) -> Control:
	var badge_text: String = str(option.get("badge", "REWARD"))
	var title_text: String = str(option.get("label", "Reward"))
	var summary_text: String = str(option.get("summary", ""))
	var palette: Dictionary = _get_palette(str(option.get("kind", "")))

	var card: Panel = Panel.new()
	card.name = "RewardOptionCard%d" % index
	card.custom_minimum_size = Vector2(190, 176)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card.add_theme_stylebox_override("panel", _make_card_style(palette))

	var margin: MarginContainer = MarginContainer.new()
	margin.name = "CardMargin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	card.add_child(margin)

	var content: VBoxContainer = VBoxContainer.new()
	content.name = "CardContent"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)

	var badge: Label = Label.new()
	badge.name = "BadgeLabel"
	badge.text = badge_text
	badge.add_theme_font_size_override("font_size", 12)
	badge.add_theme_color_override("font_color", palette["accent"])
	badge.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.72))
	badge.add_theme_constant_override("outline_size", 1)
	content.add_child(badge)

	var title: Label = Label.new()
	title.name = "TitleLabel"
	title.text = title_text
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.97, 0.92, 0.80, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.75))
	title.add_theme_constant_override("outline_size", 1)
	content.add_child(title)

	var summary: Label = Label.new()
	summary.name = "SummaryLabel"
	summary.text = summary_text
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.size_flags_vertical = Control.SIZE_EXPAND_FILL
	summary.add_theme_font_size_override("font_size", 14)
	summary.add_theme_color_override("font_color", Color(0.88, 0.90, 0.94, 0.92))
	content.add_child(summary)

	var hit_button: Button = Button.new()
	hit_button.name = "RewardOptionButton%d" % index
	hit_button.text = "Choose"
	hit_button.custom_minimum_size = Vector2(0, 38)
	hit_button.focus_mode = Control.FOCUS_NONE
	hit_button.add_theme_color_override("font_color", Color(0.08, 0.08, 0.10, 1.0))
	hit_button.add_theme_stylebox_override("normal", _make_button_style(palette, 0.96))
	hit_button.add_theme_stylebox_override("hover", _make_button_style(palette, 1.06))
	hit_button.add_theme_stylebox_override("pressed", _make_button_style(palette, 0.88))
	hit_button.pressed.connect(_on_option_pressed.bind(index))
	content.add_child(hit_button)

	return card

func _add_empty_state() -> void:
	var label: Label = Label.new()
	label.name = "EmptyRewardLabel"
	label.text = "No rewards available."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.80, 0.82, 0.88, 0.76))
	label.custom_minimum_size = Vector2(280, 120)
	option_row.add_child(label)

func _get_palette(kind: String) -> Dictionary:
	match kind:
		"item":
			return {
				"fill": Color(0.20, 0.12, 0.08, 0.94),
				"border": Color(0.95, 0.68, 0.28, 0.95),
				"accent": Color(0.98, 0.84, 0.44, 1.0),
			}
		"skill":
			return {
				"fill": Color(0.10, 0.14, 0.22, 0.94),
				"border": Color(0.46, 0.74, 0.96, 0.95),
				"accent": Color(0.64, 0.88, 1.00, 1.0),
			}
		"upgrade", "enchant":
			return {
				"fill": Color(0.17, 0.11, 0.21, 0.94),
				"border": Color(0.82, 0.54, 0.98, 0.95),
				"accent": Color(0.92, 0.74, 1.00, 1.0),
			}
		_:
			return {
				"fill": Color(0.11, 0.18, 0.13, 0.94),
				"border": Color(0.60, 0.84, 0.54, 0.95),
				"accent": Color(0.78, 0.96, 0.72, 1.0),
			}

func _make_card_style(palette: Dictionary) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = palette["fill"]
	style.border_color = palette["border"]
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.28)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 4)
	return style

func _make_button_style(palette: Dictionary, brightness: float) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(
		clampf(float(palette["accent"].r) * brightness, 0.0, 1.0),
		clampf(float(palette["accent"].g) * brightness, 0.0, 1.0),
		clampf(float(palette["accent"].b) * brightness, 0.0, 1.0),
		0.94
	)
	style.border_color = Color(0.08, 0.08, 0.10, 0.45)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	return style

func _on_option_pressed(index: int) -> void:
	option_selected.emit(index)
