class_name LinearInventory
extends Resource

## 总槽位数
const TOTAL_SLOTS: int = 10

## 槽位数组：-1 表示空，>=0 表示物品索引
var slots: Array[int] = []

## 物品数组
var items: Array[ItemData] = []

## 背包变化信号
signal inventory_changed()

func _init():
	# 初始化槽位数组
	slots.resize(TOTAL_SLOTS)
	slots.fill(-1)

## ============ 放置相关方法 ============

## 检查是否可以在指定槽位放置物品
## item: 要放置的物品
## start_slot: 起始槽位索引
## 返回: 是否可以放置
func can_place_item(item: ItemData, start_slot: int) -> bool:
	if item == null:
		return false
	
	var slot_count: int = item.get_slot_count()
	
	# 检查起始槽位是否超出边界
	if start_slot < 0 or start_slot >= TOTAL_SLOTS:
		return false
	
	# 检查是否会超出右边界
	if start_slot + slot_count > TOTAL_SLOTS:
		return false
	
	# 检查连续槽位是否为空
	for i in range(slot_count):
		var slot_idx: int = start_slot + i
		if slots[slot_idx] != -1:
			return false
	
	return true

## 放置物品到指定槽位
## item: 要放置的物品
## start_slot: 起始槽位索引
## 返回: 是否放置成功
func place_item(item: ItemData, start_slot: int) -> bool:
	if not can_place_item(item, start_slot):
		return false
	
	var slot_count: int = item.get_slot_count()
	var item_index: int = items.size()
	
	# 将物品添加到数组
	items.append(item)
	item.slot_index = start_slot
	
	# 标记占用的槽位
	for i in range(slot_count):
		slots[start_slot + i] = item_index
	
	inventory_changed.emit()
	return true

## ============ 移除相关方法 ============

## 移除物品
## item: 要移除的物品
## 返回: 是否移除成功
func remove_item(item: ItemData) -> bool:
	if item == null or item.slot_index == -1:
		return false
	
	var item_index: int = -1
	
	# 找到物品在数组中的索引
	for i in range(items.size()):
		if items[i] == item:
			item_index = i
			break
	
	if item_index == -1:
		return false
	
	var slot_count: int = item.get_slot_count()
	var start_slot: int = item.slot_index
	
	# 清空占用的槽位
	for i in range(slot_count):
		slots[start_slot + i] = -1
	
	# 移除物品
	items.remove_at(item_index)
	item.slot_index = -1
	
	# 重建槽位映射（因为索引变化了）
	_rebuild_slot_mapping()
	
	inventory_changed.emit()
	return true

## 重建槽位映射（当物品被移除后）
func _rebuild_slot_mapping() -> void:
	# 清空所有槽位
	slots.fill(-1)
	
	# 重新标记所有物品的槽位
	for item_index in range(items.size()):
		var item: ItemData = items[item_index]
		if item != null and item.slot_index != -1:
			var slot_count: int = item.get_slot_count()
			for i in range(slot_count):
				slots[item.slot_index + i] = item_index

## ============ 查询相关方法 ============

## 获取指定槽位的物品
## slot: 槽位索引
## 返回: 槽位上的物品（如果没有返回 null）
func get_item_at(slot: int) -> ItemData:
	if slot < 0 or slot >= TOTAL_SLOTS:
		return null
	
	var item_index: int = slots[slot]
	if item_index == -1:
		return null
	
	if item_index >= 0 and item_index < items.size():
		return items[item_index]
	
	return null

## 获取物品占据的所有槽位
## item: 物品
## 返回: 槽位索引数组
func get_item_slots(item: ItemData) -> Array[int]:
	if item == null or item.slot_index == -1:
		return []
	
	var result: Array[int] = []
	var slot_count: int = item.get_slot_count()
	for i in range(slot_count):
		result.append(item.slot_index + i)
	return result

## 获取指定物品的左相邻物品
## item: 物品
## 返回: 左相邻物品（如果没有返回 null）
func get_left_adjacent_item(item: ItemData) -> ItemData:
	if item == null or item.slot_index == -1:
		return null
	
	var left_slot: int = item.slot_index - 1
	if left_slot < 0:
		return null
	
	return get_item_at(left_slot)

## 获取指定物品的右相邻物品
## item: 物品
## 返回: 右相邻物品（如果没有返回 null）
func get_right_adjacent_item(item: ItemData) -> ItemData:
	if item == null or item.slot_index == -1:
		return null
	
	# 右相邻是物品结束槽位 + 1
	var right_slot: int = item.slot_index + item.get_slot_count()
	if right_slot >= TOTAL_SLOTS:
		return null
	
	return get_item_at(right_slot)

## 获取相邻物品（左相邻 + 右相邻）
## item: 物品
## 返回: 相邻物品数组
func get_adjacent_items(item: ItemData) -> Array[ItemData]:
	var result: Array[ItemData] = []
	
	var left_item: ItemData = get_left_adjacent_item(item)
	if left_item != null:
		result.append(left_item)
	
	var right_item: ItemData = get_right_adjacent_item(item)
	if right_item != null:
		result.append(right_item)
	
	return result

## 获取最左边的物品
## 返回: 最左边的物品（如果没有返回 null）
func get_leftmost_item() -> ItemData:
	# 从左到右遍历，找到第一个非空槽位
	for slot in range(TOTAL_SLOTS):
		var item: ItemData = get_item_at(slot)
		if item != null:
			return item
	return null

## 获取最右边的物品
## 返回: 最右边的物品（如果没有返回 null）
func get_rightmost_item() -> ItemData:
	# 从右到左遍历，找到第一个非空槽位
	for i in range(TOTAL_SLOTS - 1, -1, -1):
		var item: ItemData = get_item_at(i)
		if item != null:
			return item
	return null

## 查找可以放置指定尺寸物品的空槽位列表
## size: 物品尺寸（槽位数）
## 返回: 可用起始槽位索引数组
func find_empty_slots(size: int) -> Array[int]:
	var result: Array[int] = []
	
	if size <= 0 or size > TOTAL_SLOTS:
		return result
	
	# 遍历所有可能的起始位置
	for start_slot in range(TOTAL_SLOTS - size + 1):
		if can_place_item(_create_dummy_item(size), start_slot):
			result.append(start_slot)
	
	return result

## 创建临时物品用于检查（不实际创建）
func _create_dummy_item(slot_count: int) -> ItemData:
	# 这是一个辅助方法，用于 can_place_item 检查
	# 实际使用时应该传入真实的 ItemData
	var dummy := ItemData.new()
	dummy.size = ItemData.Size.SMALL  # 默认小
	return dummy

## ============ 实用工具方法 ============

## 获取所有物品
func get_all_items() -> Array[ItemData]:
	return items.duplicate()

## 获取物品数量
func get_item_count() -> int:
	return items.size()

## 检查背包是否为空
func is_empty() -> bool:
	return items.is_empty()

## 检查背包是否已满
func is_full() -> bool:
	# 检查是否还有足够的连续空槽位放最小的物品
	return find_empty_slots(1).is_empty()

## 清空背包
func clear() -> void:
	items.clear()
	slots.fill(-1)
	inventory_changed.emit()

## 获取槽位总数
func get_total_slots() -> int:
	return TOTAL_SLOTS

## 获取指定槽位的信息
## 返回: 字典 { "occupied": bool, "item": ItemData or null, "item_slots": Array[int] }
func get_slot_info(slot: int) -> Dictionary:
	if slot < 0 or slot >= TOTAL_SLOTS:
		return { "occupied": false, "item": null, "item_slots": [] }
	
	var item_index: int = slots[slot]
	var occupied: bool = item_index != -1
	var item: ItemData = null
	var item_slots: Array[int] = []
	
	if occupied and item_index >= 0 and item_index < items.size():
		item = items[item_index]
		if item != null:
			item_slots = get_item_slots(item)
	
	return {
		"occupied": occupied,
		"item": item,
		"item_slots": item_slots
	}
