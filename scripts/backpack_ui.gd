## 背包 UI 管理器
class_name BackpackUI
extends Control

## 背包网格容器
@onready var grid_container: GridContainer = $Panel/VBox/GridContainer

## 背包面板
@onready var panel: Panel = $Panel

## 标题
@onready var title_label: Label = $Panel/VBox/TitleLabel

## 物品详情提示框
@onready var tooltip: Control = $ItemTooltip

## 背包数据
var inventory: Inventory

## 格子数组
var slot_controls: Array[Control] = []

## 拖拽状态
var dragging_slot: int = -1
var drag_preview: TextureRect = null

## 格子大小
const SLOT_SIZE: int = 64

## 格子间距
const SLOT_SPACING: int = 4

## 初始化
func _ready() -> void:
	# 初始化提示框
	tooltip.visible = false
	
	# 连接关闭按钮
	var close_button = $Panel/VBox/CloseButton
	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)
	
	# 连接信号（如果已连接则跳过）
	_setup_connections()
	
	# 刷新显示
	refresh()

## 连接信号
func _setup_connections() -> void:
	if inventory:
		if not inventory.inventory_changed.is_connected(_on_inventory_changed):
			inventory.inventory_changed.connect(_on_inventory_changed)

## 设置背包数据
func set_inventory(inv: Inventory) -> void:
	inventory = inv
	_setup_connections()
	refresh()

## 刷新背包显示
func refresh() -> void:
	if not inventory:
		return
	
	# 清空现有格子
	for child in grid_container.get_children():
		child.queue_free()
	slot_controls.clear()
	
	# 创建新格子
	for i in range(inventory.TOTAL_SLOTS):
		var slot := _create_slot(i)
		grid_container.add_child(slot)
		slot_controls.append(slot)

## 创建单个格子
func _create_slot(index: int) -> InventorySlot:
	# 使用 InventorySlot 类创建格子
	var slot := InventorySlot.new()
	slot.slot_index = index
	slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	
	# 设置物品
	var item = inventory.get_item(index)
	if item:
		slot.set_item(item)
	
	return slot

## 获取格子背景纹理
func _get_slot_bg_texture() -> Texture2D:
	# 使用内置的 placeholder 纹理
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.25, 0.9)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.4, 0.4, 0.5, 1.0)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	
	# 创建 1x1 纹理
	var img = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.2, 0.2, 0.25, 0.9))
	return ImageTexture.create_from_image(img)

## 物品变化回调
func _on_inventory_changed(slot_index: int) -> void:
	refresh()

## 显示物品提示框
func show_tooltip(item: Item, position: Vector2) -> void:
	if not item:
		tooltip.visible = false
		return
	
	tooltip.visible = true
	tooltip.position = position + Vector2(20, 0)
	
	# 设置提示框内容
	var tooltip_ui = tooltip as ItemTooltipUI
	if tooltip_ui:
		tooltip_ui.set_item(item)

## 隐藏物品提示框
func hide_tooltip() -> void:
	tooltip.visible = false

## 关闭背包
func _on_close_button_pressed() -> void:
	visible = false
