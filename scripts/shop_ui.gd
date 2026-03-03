## 商店 UI 管理器
class_name ShopUI
extends Control

## 商店物品网格容器
@onready var shop_grid: GridContainer = $Panel/VBox/ShopScroll/ShopGrid

## 玩家背包网格容器
@onready var inventory_grid: GridContainer = $Panel/VBox/InventoryScroll/InventoryGrid

## 金币显示标签
@onready var gold_label: Label = $Panel/VBox/Header/HBox/GoldLabel

## 面板
@onready var panel: Panel = $Panel

## 商店数据
var shop
var inventory
var gold_manager

## 商店格子数组
var shop_slot_controls: Array[Control] = []

## 背包格子数组
var inventory_slot_controls: Array[Control] = []

## 格子大小
const SLOT_SIZE: int = 64

## 初始化
func _ready() -> void:
	# 连接关闭按钮
	var close_button = $Panel/VBox/Header/CloseButton
	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)
	
	# 刷新显示
	refresh()

## 设置商店数据
func set_data(shop_ref, inventory_ref, gold_ref) -> void:
	shop = shop_ref
	inventory = inventory_ref
	gold_manager = gold_ref
	
	# 连接信号
	if shop and not shop.shop_updated.is_connected(_on_shop_updated):
		shop.shop_updated.connect(_on_shop_updated)
	
	if inventory and not inventory.inventory_changed.is_connected(_on_inventory_changed):
		inventory.inventory_changed.connect(_on_inventory_changed)
	
	if gold_manager and not gold_manager.gold_changed.is_connected(_on_gold_changed):
		gold_manager.gold_changed.connect(_on_gold_changed)
	
	refresh()

## 刷新显示
func refresh() -> void:
	_refresh_shop()
	_refresh_inventory()
	_update_gold_display()

## 刷新商店物品显示
func _refresh_shop() -> void:
	if not shop:
		return
	
	# 清空现有格子
	for child in shop_grid.get_children():
		child.queue_free()
	shop_slot_controls.clear()
	
	# 创建商店格子
	for i in range(shop.shop_items.size()):
		var slot := _create_shop_slot(i)
		shop_grid.add_child(slot)
		shop_slot_controls.append(slot)

## 刷新背包物品显示
func _refresh_inventory() -> void:
	if not inventory:
		return
	
	# 清空现有格子
	for child in inventory_grid.get_children():
		child.queue_free()
	inventory_slot_controls.clear()
	
	# 创建背包格子
	for i in range(inventory.TOTAL_SLOTS):
		var slot := _create_inventory_slot(i)
		inventory_grid.add_child(slot)
		inventory_slot_controls.append(slot)

## 创建商店格子
func _create_shop_slot(index: int) -> Control:
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	
	# 背景
	var bg := Panel.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	slot.add_child(bg)
	_setup_slot_style(bg, Color(0.15, 0.15, 0.2, 0.9))
	
	# 物品
	var shop_item = shop.shop_items[index]
	if shop_item:
		# 物品图标区域
		var icon := Label.new()
		icon.text = _get_item_emoji(shop_item.type)
		icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.add_theme_font_size_override("font_size", 24)
		slot.add_child(icon)
		
		# 购买按钮
		var buy_button := Button.new()
		buy_button.text = "买"
		buy_button.custom_minimum_size = Vector2(30, 20)
		buy_button.set_anchors_preset(Control.PRESET_CENTER)
		buy_button.position = Vector2(-15, 20)
		buy_button.pressed.connect(func(): _on_buy_pressed(index))
		
		# 检查是否可以购买
		if not shop_item.has_stock() or not gold_manager or not gold_manager.can_afford(shop_item.price):
			buy_button.disabled = true
		
		slot.add_child(buy_button)
		
		# 价格标签
		var price_label := Label.new()
		price_label.text = str(shop_item.price)
		price_label.add_theme_color_override("font_color", Color(1, 0.84, 0, 1))  # 金色
		price_label.add_theme_font_size_override("font_size", 10)
		price_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		price_label.position = Vector2(-10, -8)
		slot.add_child(price_label)
	
	return slot

## 创建背包格子（用于出售）
func _create_inventory_slot(index: int) -> Control:
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	
	# 背景
	var bg := Panel.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	slot.add_child(bg)
	_setup_slot_style(bg, Color(0.2, 0.2, 0.25, 0.9))
	
	# 物品
	var item = inventory.get_item(index)
	if item:
		# 物品图标
		var icon := Label.new()
		icon.text = _get_item_emoji(item.type)
		icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.add_theme_font_size_override("font_size", 24)
		slot.add_child(icon)
		
		# 出售按钮
		var sell_button := Button.new()
		sell_button.text = "卖"
		sell_button.custom_minimum_size = Vector2(30, 20)
		sell_button.set_anchors_preset(Control.PRESET_CENTER)
		sell_button.position = Vector2(-15, 0)
		sell_button.pressed.connect(func(): _on_sell_pressed(index))
		slot.add_child(sell_button)
		
		# 计算并显示出售价格
		var sell_price := _calculate_sell_price(item)
		var price_label := Label.new()
		price_label.text = "+%d" % sell_price
		price_label.add_theme_color_override("font_color", Color(0.5, 1, 0.5, 1))  # 绿色
		price_label.add_theme_font_size_override("font_size", 10)
		price_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		price_label.position = Vector2(-15, -8)
		slot.add_child(price_label)
	
	return slot

## 设置格子样式
func _setup_slot_style(panel: Panel, color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.4, 0.4, 0.5, 1.0)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", style)

## 获取物品类型对应的 Emoji
func _get_item_emoji(type) -> String:
	match type:
		0: return "⚔️"  # WEAPON
		1: return "🛡️"  # ARMOR
		2: return "🧪"  # CONSUMABLE
		3: return "💎"  # MATERIAL
		_: return "📦"

## 计算出售价格
func _calculate_sell_price(item) -> int:
	if not shop:
		return 0
	var base_price := 10
	match item.type:
		0: base_price = 10 + item.effect_value * 3  # WEAPON
		1: base_price = 10 + item.effect_value * 3  # ARMOR
		2: base_price = 5 + item.effect_value  # CONSUMABLE
		3: base_price = 5  # MATERIAL
	base_price *= (1 + item.rarity * 0.2)
	return int(base_price * 0.5)

## 更新金币显示
func _update_gold_display() -> void:
	if gold_manager:
		gold_label.text = "金币: %d" % gold_manager.get_gold()

## 购买按钮按下
func _on_buy_pressed(index: int) -> void:
	if shop and inventory and gold_manager:
		shop.buy_item(index, inventory, gold_manager)
		refresh()

## 出售按钮按下
func _on_sell_pressed(index: int) -> void:
	if shop and inventory and gold_manager:
		shop.sell_item(index, inventory, gold_manager)
		refresh()

## 商店更新回调
func _on_shop_updated() -> void:
	_refresh_shop()

## 背包更新回调
func _on_inventory_changed(_slot_index: int) -> void:
	_refresh_inventory()

## 金币变化回调
func _on_gold_changed(_amount: int) -> void:
	_update_gold_display()
	_refresh_shop()  # 刷新购买按钮状态

## 商店格子悬停
func _on_shop_slot_hover(index: int) -> void:
	# 可以添加提示框显示物品详情
	pass

## 格子取消悬停
func _on_slot_unhover() -> void:
	pass

## 关闭按钮
func _on_close_button_pressed() -> void:
	visible = false
	# 发送关闭信号
	if has_signal("shop_closed"):
		emit_signal("shop_closed")
