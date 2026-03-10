class_name InventoryUI
extends Control

## Inventory UI - 10 槽位线性布局
## 基于 LinearInventory 类

## 预加载类
const LinearInventoryClass = preload("res://scripts/data/linear_inventory.gd")
const ItemDataClass = preload("res://scripts/data/item_data.gd")

## 常量
const SLOT_SIZE: int = 72
const TOTAL_SLOTS: int = 10
const SLOT_SPACING: int = 8

## Inventory 数据
var inventory: LinearInventory

## 槽位节点数组
var slot_panels: Array[Panel] = []
var item_panels: Array[Control] = []

## 当前拖拽
var dragging_item: ItemData = null
var dragging_panel: Control = null
var drag_start_slot: int = -1
var is_dragging: bool = false

## 槽位容器
@onready var slot_container: HBoxContainer = $Panel/VBox/SlotContainer

## 物品显示容器层（覆盖在槽位上）
var item_display_layer: Control

signal item_placed(item: ItemData, slot: int)
signal item_removed(item: ItemData)
signal item_drag_started(item: ItemData)
signal item_drag_ended(item: ItemData)

func _ready() -> void:
	# 创建 Inventory 实例
	inventory = LinearInventory.new()
	
	# 连接信号
	inventory.inventory_changed.connect(_on_inventory_changed)
	
	# 创建槽位 UI
	_create_slots()
	
	# 创建物品显示层
	_create_item_display_layer()
	
	# 添加测试物品
	_add_test_items()

## 创建槽位
func _create_slots() -> void:
	slot_container.add_theme_constant_override("separation", SLOT_SPACING)
	
	for i in range(TOTAL_SLOTS):
		var slot = _create_slot(i)
		slot_container.add_child(slot)
		slot_panels.append(slot)

## 创建单个槽位
func _create_slot(index: int) -> Panel:
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	panel.name = "Slot_%d" % index
	
	# 添加背景样式
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2)
	style.border_color = Color(0.35, 0.35, 0.45)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	
	# 添加槽位编号标签
	var label = Label.new()
	label.name = "SlotLabel"
	label.text = str(index + 1)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	label.position = Vector2(0, 4)
	panel.add_child(label)
	
	# 添加鼠标输入处理
	panel.gui_input.connect(_on_slot_input.bind(index))
	
	return panel

## 创建物品显示层
func _create_item_display_layer() -> void:
	item_display_layer = Control.new()
	item_display_layer.name = "ItemDisplayLayer"
	item_display_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	item_display_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 放在槽位容器之后（上层）
	if slot_container.get_parent().has_node("ItemDisplayLayer"):
		pass
	else:
		slot_container.get_parent().add_child(item_display_layer)
		item_display_layer.z_index = 10  # 放在上层

## 库存变化回调
func _on_inventory_changed() -> void:
	_refresh_display()

## 刷新物品显示
func _refresh_display() -> void:
	# 清除所有物品显示
	for child in item_display_layer.get_children():
		child.queue_free()
	item_panels.clear()
	
	# 遍历所有物品并显示
	for item in inventory.items:
		if item != null and item.slot_index >= 0:
			_display_item(item)

## 显示物品
func _display_item(item: ItemData) -> void:
	var slot_count: int = item.get_slot_count()
	var start_slot: int = item.slot_index
	
	# 创建物品面板（跨越多个槽位）
	var item_panel = Control.new()
	item_panel.name = "Item_%s" % item.item_name
	item_panel.custom_minimum_size = Vector2(
		slot_count * SLOT_SIZE + (slot_count - 1) * SLOT_SPACING - 8,
		SLOT_SIZE - 8
	)
	
	# 计算位置（基于起始槽位）
	var slot_pos = slot_panels[start_slot].global_position
	item_panel.global_position = slot_pos + Vector2(4, 4)
	
	# 添加背景样式
	var bg = Panel.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var style = StyleBoxFlat.new()
	style.bg_color = _get_item_color(item) * 0.4
	style.border_color = _get_item_color(item)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	bg.add_theme_stylebox_override("panel", style)
	item_panel.add_child(bg)
	
	# 添加物品名称标签
	var label = Label.new()
	label.name = "ItemName"
	label.text = item.item_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.position.y -= 8  # 给 Cooldown 留出空间
	item_panel.add_child(label)
	
	# 如果物品有 Cooldown，添加进度条
	if item.cooldown > 0:
		var cooldown_bar = _create_cooldown_bar(item)
		cooldown_bar.name = "CooldownBar"
		item_panel.add_child(cooldown_bar)
	
	# 添加鼠标输入（拖拽）
	item_panel.gui_input.connect(_on_item_input.bind(item, item_panel))
	
	# 添加鼠标悬停效果
	item_panel.mouse_entered.connect(_on_item_hover.bind(item, item_panel, true))
	item_panel.mouse_exited.connect(_on_item_hover.bind(item, item_panel, false))
	
	item_display_layer.add_child(item_panel)
	item_panels.append(item_panel)

## 创建 Cooldown 进度条
func _create_cooldown_bar(item: ItemData) -> ProgressBar:
	var bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 6)
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = 20
	bar.offset_bottom = 26
	bar.custom_minimum_size.y = 6
	
	# 设置样式
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1)
	style.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("background", style)
	
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.2, 0.6, 1.0)
	fill_style.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("fill", fill_style)
	
	# 设置值（如果有 current_cooldown，显示剩余时间，否则显示满）
	if item.current_cooldown > 0:
		bar.max_value = item.cooldown
		bar.value = item.current_cooldown
	else:
		bar.max_value = 1
		bar.value = 1
	
	return bar

## 获取物品颜色（基于稀有度）
func _get_item_color(item: ItemData) -> Color:
	match item.rarity:
		1: return Color(0.6, 0.6, 0.6)  # 普通 - 灰色
		2: return Color(0.2, 0.8, 0.2)  # 优秀 - 绿色
		3: return Color(0.2, 0.5, 0.9)  # 精良 - 蓝色
		4: return Color(0.7, 0.4, 0.9)  # 史诗 - 紫色
		5: return Color(1.0, 0.7, 0.2)  # 传说 - 橙色
		_: return Color.WHITE

## 槽位输入处理
func _on_slot_input(event: InputEvent, slot_index: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# 检查该槽位是否有物品可以拖动
				var item = _get_item_at_slot(slot_index)
				if item == null:
					# 尝试放置拖拽中的物品
					_on_slot_clicked_for_place(slot_index)
			else:
				# 释放鼠标
				if is_dragging:
					_end_drag(slot_index)

## 物品输入处理（拖拽）
func _on_item_input(event: InputEvent, item: ItemData, panel: Control) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_start_drag(item, panel)
		elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_end_drag(item.slot_index)

## 物品悬停效果
func _on_item_hover(item: ItemData, panel: Control, hovering: bool) -> void:
	var style = panel.get_child(0).get_theme_stylebox("panel")
	if style != null:
		if hovering:
			style.border_width_left = 3
			style.border_width_right = 3
			style.border_width_top = 3
			style.border_width_bottom = 3
		else:
			style.border_width_left = 2
			style.border_width_right = 2
			style.border_width_top = 2
			style.border_width_bottom = 2

## 开始拖拽
func _start_drag(item: ItemData, panel: Control) -> void:
	is_dragging = true
	dragging_item = item
	dragging_panel = panel
	drag_start_slot = item.slot_index
	
	# 隐藏原始面板
	panel.visible = false
	
	# 创建拖拽中的面板
	var drag_panel = panel.duplicate()
	drag_panel.name = "DragPanel"
	drag_panel.visible = true
	drag_panel.modulate.a = 0.8
	item_display_layer.add_child(drag_panel)
	dragging_panel = drag_panel
	
	# 发送信号
	item_drag_started.emit(item)

## 结束拖拽
func _end_drag(target_slot: int) -> void:
	if not is_dragging or dragging_item == null:
		return
	
	# 移除拖拽面板
	if dragging_panel != null and dragging_panel.name == "DragPanel":
		dragging_panel.queue_free()
	
	# 恢复原始面板显示
	for child in item_display_layer.get_children():
		if child.name == "Item_%s" % dragging_item.item_name:
			child.visible = true
	
	# 尝试放置物品到新位置
	var slot_count: int = dragging_item.get_slot_count()
	
	# 先移除物品
	inventory.remove_item(dragging_item)
	
	# 尝试放置到新槽位
	if inventory.can_place_item(dragging_item, target_slot):
		inventory.place_item(dragging_item, target_slot)
		item_placed.emit(dragging_item, target_slot)
	else:
		# 放回原位
		inventory.place_item(dragging_item, drag_start_slot)
	
	# 重置拖拽状态
	is_dragging = false
	dragging_item = null
	dragging_panel = null
	drag_start_slot = -1
	
	# 刷新显示
	_refresh_display()
	
	# 发送信号
	if dragging_item != null:
		item_drag_ended.emit(dragging_item)

## 槽位点击放置
func _on_slot_clicked_for_place(slot_index: int) -> void:
	# 这个方法可以用于从商店拖入物品到背包
	pass

## 获取指定槽位的物品
func _get_item_at_slot(slot_index: int) -> ItemData:
	for item in inventory.items:
		if item != null and item.slot_index == slot_index:
			return item
	return null

## 添加测试物品
func _add_test_items() -> void:
	# 创建一个 Small 物品 (1 槽位)
	var item1 = ItemDataClass.new()
	item1.item_name = "铁剑"
	item1.size = ItemDataClass.Size.SMALL
	item1.damage = 15
	item1.rarity = 1  # 普通
	item1.cooldown = 3.0
	item1.current_cooldown = 0.0
	
	# 创建一个 Medium 物品 (2 槽位)
	var item2 = ItemDataClass.new()
	item2.item_name = "盾牌"
	item2.size = ItemDataClass.Size.MEDIUM
	item2.shield = 20
	item2.rarity = 2  # 优秀
	item2.cooldown = 5.0
	item2.current_cooldown = 2.0
	
	# 创建一个 Large 物品 (3 槽位)
	var item3 = ItemDataClass.new()
	item3.item_name = "大斧"
	item3.size = ItemDataClass.Size.LARGE
	item3.damage = 35
	item3.rarity = 3  # 稀有
	item3.cooldown = 8.0
	item3.current_cooldown = 0.0
	
	# 放置物品
	inventory.place_item(item1, 0)
	inventory.place_item(item2, 2)
	inventory.place_item(item3, 5)

## 更新 Cooldown 显示（每帧调用）
func _process(delta: float) -> void:
	# 更新所有物品的 Cooldown
	for item in inventory.items:
		if item.current_cooldown > 0:
			item.current_cooldown = max(0, item.current_cooldown - delta)
	
	# 刷新显示以更新进度条
	_refresh_display()

## 获取库存实例（供外部使用）
func get_inventory() -> LinearInventory:
	return inventory
