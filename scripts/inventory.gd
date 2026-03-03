## 背包系统
## 8x6 网格背包管理

class_name Inventory
extends Node

## 背包网格宽度
const GRID_WIDTH: int = 8

## 背包网格高度
const GRID_HEIGHT: int = 6

## 背包总格子数
const TOTAL_SLOTS: int = GRID_WIDTH * GRID_HEIGHT

## 背包数据：数组，每个元素可以是 null 或 Item
var slots = []

## 信号：背包变化
signal inventory_changed(slot_index: int)

## 构造函数
func _init() -> void:
	slots.resize(TOTAL_SLOTS)
	slots.fill(null)

## 检查背包是否已满
func is_full() -> bool:
	for slot in slots:
		if slot == null:
			return false
	return true

## 查找第一个空格子
func find_empty_slot() -> int:
	for i in range(slots.size()):
		if slots[i] == null:
			return i
	return -1

## 添加物品到背包
func add_item(item) -> bool:
	var slot_index := find_empty_slot()
	if slot_index == -1:
		return false  # 背包已满
	
	slots[slot_index] = item
	inventory_changed.emit(slot_index)
	return true

## 移除指定格子的物品
func remove_item(slot_index: int) -> Item:
	if slot_index < 0 or slot_index >= slots.size():
		return null
	
	var item: Item = slots[slot_index]
	slots[slot_index] = null
	inventory_changed.emit(slot_index)
	return item

## 获取指定格子的物品
func get_item(slot_index: int) -> Item:
	if slot_index < 0 or slot_index >= slots.size():
		return null
	return slots[slot_index]

## 交换两个格子的物品
func swap_items(slot_a: int, slot_b: int) -> bool:
	if slot_a < 0 or slot_a >= slots.size() or slot_b < 0 or slot_b >= slots.size():
		return false
	
	var temp: Item = slots[slot_a]
	slots[slot_a] = slots[slot_b]
	slots[slot_b] = temp
	
	inventory_changed.emit(slot_a)
	inventory_changed.emit(slot_b)
	return true

## 使用格子中的物品
func use_item(slot_index: int, target) -> bool:
	var item = get_item(slot_index)
	if item == null or not item.usable:
		return false
	
	var success: bool = item.use(target)
	if success and item.uses_remaining <= 0:
		remove_item(slot_index)
	
	return success

## 获取背包物品数量
func get_item_count() -> int:
	var count := 0
	for slot in slots:
		if slot != null:
			count += 1
	return count

## 获取所有物品列表
func get_all_items():
	var items = []
	for slot in slots:
		if slot != null:
			items.append(slot)
	return items

## 清空背包
func clear() -> void:
	slots.fill(null)
	inventory_changed.emit(-1)  # -1 表示全部变化

## 获取格子坐标
static func get_slot_position(slot_index: int) -> Vector2i:
	if slot_index < 0 or slot_index >= TOTAL_SLOTS:
		return Vector2i(-1, -1)
	return Vector2i(slot_index % GRID_WIDTH, slot_index / GRID_WIDTH)

## 从坐标获取格子索引
static func get_slot_index(x: int, y: int) -> int:
	if x < 0 or x >= GRID_WIDTH or y < 0 or y >= GRID_HEIGHT:
		return -1
	return y * GRID_WIDTH + x

## 检查坐标是否在背包范围内
static func is_valid_position(x: int, y: int) -> bool:
	return x >= 0 and x < GRID_WIDTH and y >= 0 and y < GRID_HEIGHT

## 获取背包信息（调试用）
func get_inventory_info() -> String:
	var info := "背包: %d/%d\n" % [get_item_count(), TOTAL_SLOTS]
	for i in range(slots.size()):
		if slots[i] != null:
			info += "格子 %d: %s\n" % [i, slots[i].name]
	return info
