## 物品详情提示框
class_name ItemTooltipUI
extends Control

## 背景面板
@onready var panel: Panel = $Panel

## 物品名称
@onready var name_label: Label = $Panel/VBox/NameLabel

## 物品类型
@onready var type_label: Label = $Panel/VBox/TypeLabel

## 物品描述
@onready var description_label: RichTextLabel = $Panel/VBox/DescriptionLabel

## 稀有度
@onready var rarity_label: Label = $Panel/VBox/RarityLabel

## 效果值
@onready var effect_label: Label = $Panel/VBox/EffectLabel

## 初始化
func _ready() -> void:
	# 设置自动换行
	description_label.bbcode_enabled = true

## 设置物品
func set_item(item: Item) -> void:
	if not item:
		return
	
	# 名称
	name_label.text = item.name
	name_label.modulate = item.get_rarity_color()
	
	# 类型
	type_label.text = item.get_type_name()
	
	# 描述
	description_label.text = item.get_description()
	
	# 稀有度
	rarity_label.text = "稀有度: %s" % item.get_rarity_name()
	rarity_label.modulate = item.get_rarity_color()
	
	# 效果值
	if item.effect_value > 0:
		match item.type:
			Item.ItemType.WEAPON:
				effect_label.text = "攻击力: +%d" % item.effect_value
			Item.ItemType.ARMOR:
				effect_label.text = "防御力: +%d" % item.effect_value
			Item.ItemType.CONSUMABLE:
				effect_label.text = "效果: +%d" % item.effect_value
			_:
				effect_label.text = ""
		effect_label.visible = true
	else:
		effect_label.visible = false
	
	# 调整面板大小
	_adjust_size()

## 调整大小
func _adjust_size() -> void:
	await get_tree().process_frame  # 等待布局完成
	
	var content_height = 0
	for child in $Panel/VBox.get_children():
		if child is Control:
			content_height += child.size.y + 4
	
	panel.custom_minimum_size.y = content_height + 16
