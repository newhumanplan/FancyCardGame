## 角色面板 UI
## 整合背包和装备显示

class_name CharacterPanelUI
extends Control

## 装备面板
@onready var equipment_grid: GridContainer = $Panel/VBox/EquipmentGrid

## 背包按钮
@onready var backpack_button: Button = $Panel/VBox/HBox/BackpackButton

## 背包面板
@onready var backpack_panel: Control = $BackpackPanel

## 装备数据
var equipment: Equipment

## 背包数据
var inventory: Inventory

## 装备槽位数组
var equipment_slots: Array[Control] = []

## 初始化
func _ready() -> void:
	# 连接按钮信号
	backpack_button.pressed.connect(_on_backpack_button_pressed)
	
	# 连接背包关闭按钮
	var backpack_ui = backpack_panel as BackpackUI
	if backpack_ui:
		var close_btn = backpack_ui.find_child("CloseButton", true, false)
		if close_btn:
			close_btn.pressed.connect(_on_backpack_close)
	
	# 初始化装备槽位
	_setup_equipment_slots()
	
	# 初始状态
	backpack_panel.visible = false

## 设置装备数据
func set_equipment(eq: Equipment) -> void:
	equipment = eq
	if equipment:
		equipment.equipment_changed.connect(_on_equipment_changed)
	_refresh_equipment()

## 设置背包数据
func set_inventory(inv: Inventory) -> void:
	inventory = inv
	if inventory:
		inventory.inventory_changed.connect(_on_inventory_changed)
		
		# 设置给背包 UI
		var backpack_ui = backpack_panel as BackpackUI
		if backpack_ui:
			backpack_ui.set_inventory(inv)

## 设置装备槽位
func _setup_equipment_slots() -> void:
	# 清空
	for child in equipment_grid.get_children():
		child.queue_free()
	equipment_slots.clear()
	
	# 创建 4 个装备槽位
	var slot_names = ["武器", "护甲", "饰品", "护符"]
	for i in range(4):
		var slot = EquipmentSlotUI.new()
		slot.slot_type = i
		slot.slot_name = slot_names[i]
		slot.custom_minimum_size = Vector2(80, 80)
		equipment_grid.add_child(slot)
		equipment_slots.append(slot)

## 刷新装备显示
func _refresh_equipment() -> void:
	if not equipment:
		return
	
	var items = [
		equipment.get_weapon(),
		equipment.get_armor(),
		equipment.get_accessory(),
		equipment.get_amulet()
	]
	
	for i in range(equipment_slots.size()):
		equipment_slots[i].set_item(items[i])

## 刷新背包显示
func _refresh_inventory() -> void:
	var backpack_ui = backpack_panel as BackpackUI
	if backpack_ui:
		backpack_ui.refresh()

## 装备变化回调
func _on_equipment_changed(slot) -> void:
	_refresh_equipment()

## 背包变化回调
func _on_inventory_changed(slot_index: int) -> void:
	_refresh_inventory()

## 背包按钮点击
func _on_backpack_button_pressed() -> void:
	backpack_panel.visible = not backpack_panel.visible
	
	# 刷新背包显示
	if backpack_panel.visible:
		_refresh_inventory()

## 关闭背包
func _on_backpack_close() -> void:
	backpack_panel.visible = false
