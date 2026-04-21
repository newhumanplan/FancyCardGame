class_name ItemDetailPanel
extends Panel

## 物品详情面板
## 显示物品的详细属性

## 信号
signal close_requested()

## 预加载
const ItemDataClass = preload("res://scripts/data/item_data.gd")
const LinearInventoryClass = preload("res://scripts/data/linear_inventory.gd")

## UI 组件引用
var title_label: Label
var rarity_label: Label
var type_label: Label
var size_label: Label
var stats_vbox: VBoxContainer
var special_effects_label: Label
var synergy_label: Label

## 当前物品
var item: ItemDataClass = null
var inventory: LinearInventoryClass = null

## 样式颜色
const COLOR_WEAPON = Color(1.0, 0.4, 0.4)
const COLOR_SHIELD = Color(0.4, 0.6, 1.0)
const COLOR_HEAL = Color(0.4, 1.0, 0.4)
const COLOR_UTILITY = Color(0.8, 0.6, 1.0)

func _ready() -> void:
	# 设置面板大小
	custom_minimum_size = Vector2(330, 300)
	
	# 添加样式
	_update_style()
	
	# 创建 UI
	_create_ui()
	
	# 连接输入事件
	gui_input.connect(_on_panel_input)

func _update_style() -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.95)
	style.border_color = Color(0.3, 0.3, 0.4)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	add_theme_stylebox_override("panel", style)

func _create_ui() -> void:
	# 主容器
	var main_vbox = VBoxContainer.new()
	main_vbox.name = "MainVBox"
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 6)
	main_vbox.add_theme_constant_override("margin_top", 12)
	main_vbox.add_theme_constant_override("margin_bottom", 12)
	main_vbox.add_theme_constant_override("margin_left", 12)
	main_vbox.add_theme_constant_override("margin_right", 12)
	add_child(main_vbox)
	
	# 标题
	title_label = Label.new()
	title_label.name = "Title"
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.text = "物品名称"
	main_vbox.add_child(title_label)
	
	# 稀有度和类型行
	var info_hbox = HBoxContainer.new()
	info_hbox.add_theme_constant_override("separation", 15)
	main_vbox.add_child(info_hbox)
	
	rarity_label = Label.new()
	rarity_label.name = "Rarity"
	rarity_label.add_theme_font_size_override("font_size", 18)
	rarity_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	rarity_label.text = "稀有度: 普通"
	info_hbox.add_child(rarity_label)
	
	type_label = Label.new()
	type_label.name = "Type"
	type_label.add_theme_font_size_override("font_size", 18)
	type_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	type_label.text = "类型: 武器"
	info_hbox.add_child(type_label)
	
	# 尺寸
	size_label = Label.new()
	size_label.name = "Size"
	size_label.add_theme_font_size_override("font_size", 18)
	size_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	size_label.text = "尺寸: 小 (1槽位)"
	main_vbox.add_child(size_label)
	
	# 分隔线
	var separator = HSeparator.new()
	separator.name = "Separator"
	main_vbox.add_child(separator)
	
	# 属性容器
	stats_vbox = VBoxContainer.new()
	stats_vbox.name = "StatsVBox"
	stats_vbox.add_theme_constant_override("separation", 4)
	main_vbox.add_child(stats_vbox)
	
	# 特殊效果
	special_effects_label = Label.new()
	special_effects_label.name = "SpecialEffects"
	special_effects_label.add_theme_font_size_override("font_size", 16)
	special_effects_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
	special_effects_label.text = ""
	special_effects_label.visible = false
	main_vbox.add_child(special_effects_label)
	
	# 协同加成
	synergy_label = Label.new()
	synergy_label.name = "Synergy"
	synergy_label.add_theme_font_size_override("font_size", 16)
	synergy_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	synergy_label.text = ""
	synergy_label.visible = false
	main_vbox.add_child(synergy_label)
	
	# 描述
	var desc_label = Label.new()
	desc_label.name = "Description"
	desc_label.add_theme_font_size_override("font_size", 16)
	desc_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	desc_label.text = "点击空白处关闭"
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(desc_label)

## 设置物品数据
func set_item(item_data: ItemDataClass, inv: LinearInventoryClass = null) -> void:
	item = item_data
	inventory = inv
	
	if item == null:
		return
	
	# 更新标题
	title_label.text = item.item_name
	title_label.add_theme_color_override("font_color", item.get_rarity_color())
	
	# 更新边框颜色
	var style = get_theme_stylebox("panel")
	if style:
		style.border_color = item.get_rarity_color()
	
	# 更新稀有度
	rarity_label.text = "稀有度: %s" % item.get_rarity_name()
	rarity_label.add_theme_color_override("font_color", item.get_rarity_color())
	
	# 更新类型
	type_label.text = "类型: %s" % item.get_type_name()
	type_label.add_theme_color_override("font_color", _get_type_color(item.type))
	
	# 更新尺寸
	size_label.text = "尺寸: %s (%d槽位)" % [item.get_size_text(), item.get_slot_count()]
	
	# 清空旧属性
	for child in stats_vbox.get_children():
		child.queue_free()
	
	# 添加属性
	_add_stat_row("攻击", item.damage, COLOR_WEAPON)
	_add_stat_row("防御", item.shield, COLOR_SHIELD)
	_add_stat_row("治疗", item.heal, COLOR_HEAL)
	
	if item.cooldown > 0:
		var cooldown_row = _create_stat_label("冷却: %.1f秒" % item.cooldown, Color(0.6, 0.6, 0.8))
		stats_vbox.add_child(cooldown_row)
	
	if item.crit_chance > 0:
		var crit_row = _create_stat_label("暴击: %.1f%%" % (item.crit_chance * 100), Color(1.0, 0.6, 0.6))
		stats_vbox.add_child(crit_row)
	
	# 特殊效果
	if item.has_special_effect():
		special_effects_label.text = "特殊效果: %s" % item.get_special_effect_description()
		special_effects_label.visible = true
	else:
		special_effects_label.visible = false
	
	# 协同加成
	if inventory != null:
		var synergy = inventory.get_item_synergy_bonus(item)
		if synergy["damage"] > 0 or synergy["defense"] > 0 or synergy["heal"] > 0:
			var bonus_text = "协同加成: "
			if synergy["damage"] > 0:
				bonus_text += "伤害+%d " % synergy["damage"]
			if synergy["defense"] > 0:
				bonus_text += "防御+%d " % synergy["defense"]
			if synergy["heal"] > 0:
				bonus_text += "治疗+%d " % synergy["heal"]
			synergy_label.text = bonus_text
			synergy_label.visible = true
		else:
			synergy_label.visible = false
	else:
		synergy_label.visible = false

## 添加属性行
func _add_stat_row(name: String, value: int, color: Color) -> void:
	if value <= 0:
		return
	
	var label = _create_stat_label("%s: %d" % [name, value], color)
	stats_vbox.add_child(label)

## 创建属性标签
func _create_stat_label(text: String, color: Color) -> Label:
	var label = Label.new()
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", color)
	label.text = text
	return label

## 获取类型颜色
func _get_type_color(type: int) -> Color:
	match type:
		ItemDataClass.Type.WEAPON: return COLOR_WEAPON
		ItemDataClass.Type.SHIELD: return COLOR_SHIELD
		ItemDataClass.Type.HEAL: return COLOR_HEAL
		ItemDataClass.Type.UTILITY: return COLOR_UTILITY
		_: return Color.WHITE

## 面板输入处理
func _on_panel_input(event: InputEvent) -> void:
	# 阻止事件穿透到背景
	pass
