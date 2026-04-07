class_name BackpackGrid
extends Resource

## 背包网格 - 《大巴扎》的核心玩法
## 6x6 网格，物品占用不同大小的格子

## 预加载 Item 类
const ItemClass = preload("res://resources/item.gd")

const GRID_WIDTH: int = 6
const GRID_HEIGHT: int = 6

## 背包网格数据 (-1 = 空, >= 0 = 物品索引)
var grid: Array = []

## 背包中的物品列表
var items: Array = []

## 信号
signal backpack_changed()

func _init() -> void:
	clear()

## 清空背包
func clear() -> void:
	grid = []
	for y in range(GRID_HEIGHT):
		var row: Array = []
		for x in range(GRID_WIDTH):
			row.append(-1)
		grid.append(row)
	items.clear()
	backpack_changed.emit()

## 检查位置是否在网格内
func is_valid_position(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < GRID_WIDTH and pos.y >= 0 and pos.y < GRID_HEIGHT

## 检查物品是否可以放置在指定位置
func can_place_item(item, pos: Vector2i) -> bool:
	# 检查位置是否有效
	for dy in range(item.size.y):
		for dx in range(item.size.x):
			var check_pos = Vector2i(pos.x + dx, pos.y + dy)
			if not is_valid_position(check_pos):
				return false
			if grid[check_pos.y][check_pos.x] != -1:
				return false
	return true

## 放置物品
func place_item(item, pos: Vector2i) -> bool:
	if not can_place_item(item, pos):
		return false
	
	# 添加到物品列表
	var item_index = items.size()
	items.append(item)
	item.grid_position = pos
	
	# 在网格中标记
	for dy in range(item.size.y):
		for dx in range(item.size.x):
			var mark_pos = Vector2i(pos.x + dx, pos.y + dy)
			grid[mark_pos.y][mark_pos.x] = item_index
	
	backpack_changed.emit()
	return true

## 移除物品
func remove_item(item) -> bool:
	var item_index = items.find(item)
	if item_index == -1:
		return false
	
	# 从网格中清除
	for dy in range(item.size.y):
		for dx in range(item.size.x):
			var clear_pos = Vector2i(item.grid_position.x + dx, item.grid_position.y + dy)
			grid[clear_pos.y][clear_pos.x] = -1
	
	# 从列表中移除
	items.erase(item)
	item.grid_position = Vector2i(-1, -1)
	
	# 重新索引网格（因为删除了中间的物品）
	_reindex_grid()
	backpack_changed.emit()
	return true

## 重新索引网格
func _reindex_grid() -> void:
	# 清空网格
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			grid[y][x] = -1
	
	# 重新放置所有物品
	for i in range(items.size()):
		var item = items[i]
		for dy in range(item.size.y):
			for dx in range(item.size.x):
				var pos = Vector2i(item.grid_position.x + dx, item.grid_position.y + dy)
				if is_valid_position(pos):
					grid[pos.y][pos.x] = i

## 获取指定位置的物品
func get_item_at(pos: Vector2i):
	if not is_valid_position(pos):
		return null
	var item_index = grid[pos.y][pos.x]
	if item_index == -1 or item_index >= items.size():
		return null
	return items[item_index]

## 获取所有物品
func get_all_items() -> Array:
	return items

## 获取总伤害加成
func get_total_attack() -> int:
	var total := 0
	for item in items:
		total += item.damage
	return total

## 获取总护盾加成
func get_total_defense() -> int:
	var total := 0
	for item in items:
		total += item.shield
	return total

## 查找空位（用于自动放置）
func find_empty_slot(item) -> Vector2i:
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var pos = Vector2i(x, y)
			if can_place_item(item, pos):
				return pos
	return Vector2i(-1, -1)
