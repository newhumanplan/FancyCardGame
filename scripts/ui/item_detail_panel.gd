class_name ItemDetailPanel
extends Panel

## 物品详情面板
## 鼠标悬停物品时显示 Bazaar 风格的黑金 tips。

signal close_requested()

const ItemDataClass = preload("res://scripts/data/item_data.gd")
const LinearInventoryClass = preload("res://scripts/data/linear_inventory.gd")

const PANEL_SIZE: Vector2 = Vector2(420, 300)
const COLOR_GOLD: Color = Color(0.86, 0.64, 0.30, 1.0)
const COLOR_TEXT: Color = Color(0.94, 0.90, 0.82, 1.0)
const COLOR_MUTED: Color = Color(0.72, 0.66, 0.56, 1.0)
const COLOR_WEAPON: Color = Color(1.0, 0.36, 0.32, 1.0)
const COLOR_SHIELD: Color = Color(0.42, 0.72, 1.0, 1.0)
const COLOR_HEAL: Color = Color(0.45, 1.0, 0.52, 1.0)
const COLOR_UTILITY: Color = Color(0.86, 0.62, 1.0, 1.0)

var title_label: Label
var tag_row: HBoxContainer
var stats_vbox: VBoxContainer
var special_effects_label: Label
var description_label: Label
var synergy_label: Label

var item: ItemDataClass = null
var inventory: LinearInventoryClass = null

func _ready() -> void:
	custom_minimum_size = PANEL_SIZE
	size = PANEL_SIZE
	z_index = 300
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_style()
	_create_ui()
	gui_input.connect(_on_panel_input)

func _update_style() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.035, 0.02, 0.96)
	style.border_color = COLOR_GOLD
	style.set_border_width_all(3)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(16)
	add_theme_stylebox_override("panel", style)

func _create_ui() -> void:
	var main_vbox: VBoxContainer = VBoxContainer.new()
	main_vbox.name = "MainVBox"
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.offset_left = 16.0
	main_vbox.offset_top = 14.0
	main_vbox.offset_right = -16.0
	main_vbox.offset_bottom = -14.0
	main_vbox.add_theme_constant_override("separation", 10)
	add_child(main_vbox)

	var header: HBoxContainer = HBoxContainer.new()
	header.name = "Header"
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 12)
	main_vbox.add_child(header)

	title_label = Label.new()
	title_label.name = "Title"
	title_label.text = "物品"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.65))
	title_label.add_theme_constant_override("outline_size", 2)
	header.add_child(title_label)

	tag_row = HBoxContainer.new()
	tag_row.name = "TagRow"
	tag_row.add_theme_constant_override("separation", 6)
	main_vbox.add_child(tag_row)

	main_vbox.add_child(_create_divider())

	stats_vbox = VBoxContainer.new()
	stats_vbox.name = "StatsVBox"
	stats_vbox.add_theme_constant_override("separation", 6)
	main_vbox.add_child(stats_vbox)

	description_label = _create_body_label("Description", COLOR_TEXT, 16)
	description_label.visible = false
	main_vbox.add_child(description_label)

	special_effects_label = _create_body_label("SpecialEffects", Color(1.0, 0.84, 0.42, 1.0), 16)
	special_effects_label.visible = false
	main_vbox.add_child(special_effects_label)

	synergy_label = _create_body_label("Synergy", Color(0.68, 1.0, 0.78, 1.0), 16)
	synergy_label.visible = false
	main_vbox.add_child(synergy_label)

func set_item(item_data: ItemDataClass, inv: LinearInventoryClass = null) -> void:
	item = item_data
	inventory = inv

	if item == null or title_label == null:
		return

	title_label.text = item.item_name
	title_label.add_theme_color_override("font_color", item.get_rarity_color().lerp(Color.WHITE, 0.45))

	var style: StyleBoxFlat = get_theme_stylebox("panel") as StyleBoxFlat
	if style != null:
		style.border_color = item.get_rarity_color().lerp(COLOR_GOLD, 0.45)

	_set_tags([
		item.get_size_text(),
		item.get_type_name(),
		item.get_rarity_name()
	])
	_refresh_stat_rows()
	_refresh_description()
	_refresh_special_effects()
	_refresh_synergy()

func _set_tags(tags: Array[String]) -> void:
	for child in tag_row.get_children():
		child.queue_free()
	for tag_text in tags:
		tag_row.add_child(_create_tag(tag_text))

func _refresh_stat_rows() -> void:
	for child in stats_vbox.get_children():
		child.queue_free()

	if item.damage > 0:
		_add_stat_row("造成 %d 伤害" % item.get_rarity_adjusted_damage(), COLOR_WEAPON)
	if item.shield > 0:
		_add_stat_row("获得 %d 护盾" % item.get_rarity_adjusted_shield(), COLOR_SHIELD)
	if item.heal > 0:
		_add_stat_row("恢复 %d 生命" % item.get_rarity_adjusted_heal(), COLOR_HEAL)
	if item.crit_chance > 0:
		_add_stat_row("暴击 %.0f%%" % (item.crit_chance * item.get_rarity_multiplier() * 100.0), COLOR_UTILITY)
	if item.has_ammo_limit():
		if item.current_ammo >= 0:
			_add_stat_row("弹药 %d/%d" % [item.get_current_ammo(), item.get_max_ammo()], COLOR_UTILITY)
		else:
			_add_stat_row("弹药 %d" % item.get_max_ammo(), COLOR_UTILITY)
	if item.cooldown > 0.0:
		_add_stat_row("冷却 %.1f 秒" % maxf(item.cooldown, ItemDataClass.MIN_ITEM_COOLDOWN), Color(0.82, 0.90, 1.0, 1.0))
	if stats_vbox.get_child_count() == 0:
		_add_stat_row("被动效果", COLOR_MUTED)

func _refresh_description() -> void:
	var text: String = item.description
	if text.is_empty() and not item.source_effect_text.is_empty():
		text = item.source_effect_text
	description_label.visible = not text.is_empty()
	if description_label.visible:
		description_label.text = text

func _refresh_special_effects() -> void:
	if item.has_special_effect():
		special_effects_label.text = "特殊效果: %s" % item.get_special_effect_description()
		special_effects_label.visible = true
	else:
		special_effects_label.visible = false

func _refresh_synergy() -> void:
	if inventory == null:
		synergy_label.visible = false
		return

	var synergy: Dictionary = inventory.get_item_synergy_bonus(item)
	var bonus_parts: Array[String] = []
	if int(synergy.get("damage", 0)) > 0:
		bonus_parts.append("伤害 +%d" % int(synergy["damage"]))
	if int(synergy.get("defense", 0)) > 0:
		bonus_parts.append("护盾 +%d" % int(synergy["defense"]))
	if int(synergy.get("heal", 0)) > 0:
		bonus_parts.append("治疗 +%d" % int(synergy["heal"]))

	synergy_label.visible = not bonus_parts.is_empty()
	if synergy_label.visible:
		synergy_label.text = "相邻加成: %s" % " / ".join(bonus_parts)

func _add_stat_row(text: String, color: Color) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "StatRow"
	row.add_theme_constant_override("separation", 8)
	stats_vbox.add_child(row)

	var arrow_label: Label = Label.new()
	arrow_label.text = ">"
	arrow_label.custom_minimum_size = Vector2(18, 0)
	arrow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow_label.add_theme_font_size_override("font_size", 18)
	arrow_label.add_theme_color_override("font_color", COLOR_GOLD)
	row.add_child(arrow_label)

	var label: Label = _create_body_label("StatText", color, 18)
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

func _create_tag(text: String) -> Label:
	var tag: Label = Label.new()
	tag.text = text
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tag.custom_minimum_size = Vector2(72, 26)
	tag.add_theme_font_size_override("font_size", 14)
	tag.add_theme_color_override("font_color", Color(0.94, 0.88, 0.74, 1.0))
	tag.add_theme_stylebox_override("normal", _create_tag_style())
	return tag

func _create_tag_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.08, 0.04, 0.94)
	style.border_color = Color(0.55, 0.38, 0.18, 1.0)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	return style

func _create_divider() -> ColorRect:
	var divider: ColorRect = ColorRect.new()
	divider.name = "Divider"
	divider.color = Color(0.62, 0.45, 0.22, 0.75)
	divider.custom_minimum_size = Vector2(0, 2)
	return divider

func _create_body_label(node_name: String, color: Color, font_size: int) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.65))
	label.add_theme_constant_override("outline_size", 1)
	return label

func _on_panel_input(_event: InputEvent) -> void:
	pass
