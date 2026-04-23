class_name LinearInventory
extends Resource
const ItemDataClass = preload("res://scripts/data/item_data.gd")

## 总槽位数
const TOTAL_SLOTS: int = 10

## 槽位数组:-1 表示空,>=0 表示物品索引
var slots: Array[int] = []

## 物品数组
var items: Array[ItemDataClass] = []

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
func can_place_item(item: ItemDataClass, start_slot: int) -> bool:
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
func place_item(item: ItemDataClass, start_slot: int) -> bool:
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
func remove_item(item: ItemDataClass) -> bool:
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

	# 重建槽位映射(因为索引变化了)
	_rebuild_slot_mapping()

	inventory_changed.emit()
	return true

## 重建槽位映射(当物品被移除后)
func _rebuild_slot_mapping() -> void:
	# 清空所有槽位
	slots.fill(-1)

	# 重新标记所有物品的槽位
	for item_index in range(items.size()):
		var item: ItemDataClass = items[item_index]
		if item != null and item.slot_index != -1:
			var slot_count: int = item.get_slot_count()
			for i in range(slot_count):
				slots[item.slot_index + i] = item_index

## ============ 查询相关方法 ============

## 获取指定槽位的物品
## slot: 槽位索引
## 返回: 槽位上的物品(如果没有返回 null)
func get_item_at(slot: int) -> ItemDataClass:
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
func get_item_slots(item: ItemDataClass) -> Array[int]:
	if item == null or item.slot_index == -1:
		return []

	var result: Array[int] = []
	var slot_count: int = item.get_slot_count()
	for i in range(slot_count):
		result.append(item.slot_index + i)
	return result

## 获取指定物品的左相邻物品
## item: 物品
## 返回: 左相邻物品(如果没有返回 null)
func get_left_adjacent_item(item: ItemDataClass) -> ItemDataClass:
	if item == null or item.slot_index == -1:
		return null

	var left_slot: int = item.slot_index - 1
	if left_slot < 0:
		return null

	return get_item_at(left_slot)

## 获取指定物品的右相邻物品
## item: 物品
## 返回: 右相邻物品(如果没有返回 null)
func get_right_adjacent_item(item: ItemDataClass) -> ItemDataClass:
	if item == null or item.slot_index == -1:
		return null

	# 右相邻是物品结束槽位 + 1
	var right_slot: int = item.slot_index + item.get_slot_count()
	if right_slot >= TOTAL_SLOTS:
		return null

	return get_item_at(right_slot)

## 获取相邻物品(左相邻 + 右相邻)
## item: 物品
## 返回: 相邻物品数组
func get_adjacent_items(item: ItemDataClass) -> Array[ItemDataClass]:
	var result: Array[ItemDataClass] = []

	var left_item: ItemDataClass = get_left_adjacent_item(item)
	if left_item != null:
		result.append(left_item)

	var right_item: ItemDataClass = get_right_adjacent_item(item)
	if right_item != null:
		result.append(right_item)

	return result

## 获取最左边的物品
## 返回: 最左边的物品(如果没有返回 null)
func get_leftmost_item() -> ItemDataClass:
	# 从左到右遍历,找到第一个非空槽位
	for slot in range(TOTAL_SLOTS):
		var item: ItemDataClass = get_item_at(slot)
		if item != null:
			return item
	return null

## 获取最右边的物品
## 返回: 最右边的物品(如果没有返回 null)
func get_rightmost_item() -> ItemDataClass:
	# 从右到左遍历,找到第一个非空槽位
	for i in range(TOTAL_SLOTS - 1, -1, -1):
		var item: ItemDataClass = get_item_at(i)
		if item != null:
			return item
	return null

## 查找可以放置指定尺寸物品的空槽位列表
## size: 物品尺寸(槽位数)
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

## 创建临时物品用于检查(不实际创建)
func _create_dummy_item(slot_count: int) -> ItemDataClass:
	var dummy := ItemDataClass.new()
	match slot_count:
		1:
			dummy.size = ItemDataClass.Size.SMALL
		2:
			dummy.size = ItemDataClass.Size.MEDIUM
		_:
			dummy.size = ItemDataClass.Size.LARGE
	return dummy

## ============ 实用工具方法 ============

## 获取所有物品
func get_all_items() -> Array[ItemDataClass]:
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

## ============ 物品协同效果 ============

## 协同加成类型
enum SynergyType {
	DAMAGE_BOOST,    # 伤害加成
	DEFENSE_BOOST,   # 防御加成
	HEAL_BOOST,      # 治疗加成
	COOLDOWN_REDUCTION  # 冷却减少
}

## 获取物品的协同加成
## item: 物品
## 返回: 协同加成字典 { "damage": int, "defense": int, "heal": int }
func get_item_synergy_bonus(item: ItemDataClass) -> Dictionary:
	var bonus = {
		"damage": 0,
		"defense": 0,
		"heal": 0,
		"cooldown_reduction": 0.0
	}

	if item == null:
		return bonus

	var adjacent = get_adjacent_items(item)

	for adj_item in adjacent:
		if adj_item == null:
			continue

		# 武器 + 武器 = 伤害+10%
		if item.type == ItemDataClass.Type.WEAPON and adj_item.type == ItemDataClass.Type.WEAPON:
			bonus["damage"] += int(float(item.damage) * 0.1)

		# 护盾 + 护盾 = 防御+10%
		if item.type == ItemDataClass.Type.SHIELD and adj_item.type == ItemDataClass.Type.SHIELD:
			bonus["defense"] += int(float(item.shield) * 0.1)

		# 治疗 + 治疗 = 治疗+10%
		if item.type == ItemDataClass.Type.HEAL and adj_item.type == ItemDataClass.Type.HEAL:
			bonus["heal"] += int(float(item.heal) * 0.1)

		# 武器 + 护盾 = 伤害+5%
		if item.type == ItemDataClass.Type.WEAPON and adj_item.type == ItemDataClass.Type.SHIELD:
			bonus["damage"] += int(float(item.damage) * 0.05)

		# 护盾 + 武器 = 防御+5%
		if item.type == ItemDataClass.Type.SHIELD and adj_item.type == ItemDataClass.Type.WEAPON:
			bonus["defense"] += int(float(item.shield) * 0.05)

	return bonus

## 获取物品的最终属性(包含协同加成)
## item: 物品
## 返回: 属性字典(已应用稀有度和协同加成)
func get_item_final_stats(item: ItemDataClass) -> Dictionary:
	if item == null:
		return {}

	var synergy = get_item_synergy_bonus(item)
	var rarity_mult = item.get_rarity_multiplier()

	return {
		"damage": int(float(item.damage) * rarity_mult) + synergy["damage"],
		"shield": int(float(item.shield) * rarity_mult) + synergy["defense"],
		"heal": int(float(item.heal) * rarity_mult) + synergy["heal"],
		"cooldown_reduction": synergy["cooldown_reduction"]
	}

## 获取所有物品的协同效果信息
## 返回: 字符串描述
func get_synergy_info() -> String:
	var info = "物品协同效果:\n"
	for item in items:
		if item != null:
			var bonus = get_item_synergy_bonus(item)
			if bonus["damage"] > 0 or bonus["defense"] > 0 or bonus["heal"] > 0:
				info += "- %s: 伤害+%d, 防御+%d, 治疗+%d\n" % [
					item.item_name, bonus["damage"], bonus["defense"], bonus["heal"]
				]
	return info

## 获取指定槽位的信息
## 返回: 字典 { "occupied": bool, "item": ItemData or null, "item_slots": Array[int] }
func get_slot_info(slot: int) -> Dictionary:
	if slot < 0 or slot >= TOTAL_SLOTS:
		return { "occupied": false, "item": null, "item_slots": [] }

	var item_index: int = slots[slot]
	var occupied: bool = item_index != -1
	var item: ItemDataClass = null
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

## 获取指定槽位上的物品（内部方法）
func _get_item_at_slot(slot: int) -> ItemDataClass:
	if slot < 0 or slot >= TOTAL_SLOTS:
		return null
	var item_index: int = slots[slot]
	if item_index < 0 or item_index >= items.size():
		return null
	return items[item_index]

## 交换两个槽位的物品
## slot_a/slot_b: 要交换的两个槽位索引
## 返回: 是否交换成功
func swap_items(slot_a: int, slot_b: int) -> bool:
	if slot_a < 0 or slot_a >= TOTAL_SLOTS or slot_b < 0 or slot_b >= TOTAL_SLOTS:
		return false
	if slot_a == slot_b:
		return true

	# 记录原始物品
	var item_a: ItemDataClass = _get_item_at_slot(slot_a)
	var item_b: ItemDataClass = _get_item_at_slot(slot_b)

	# 如果两边都为空，不处理
	if item_a == null and item_b == null:
		return true

	# 清空两个槽位
	if item_a != null:
		var slot_count_a: int = item_a.get_slot_count()
		for i in range(slot_count_a):
			slots[slot_a + i] = -1

	if item_b != null:
		var slot_count_b: int = item_b.get_slot_count()
		for i in range(slot_count_b):
			slots[slot_b + i] = -1

	# 重新放置物品到对方槽位
	if item_a != null:
		item_a.slot_index = slot_b
		var slot_count_a: int = item_a.get_slot_count()
		for i in range(slot_count_a):
			slots[slot_b + i] = items.find(item_a)

	if item_b != null:
		item_b.slot_index = slot_a
		var slot_count_b: int = item_b.get_slot_count()
		for i in range(slot_count_b):
			slots[slot_a + i] = items.find(item_b)

	_rebuild_slot_mapping()
	inventory_changed.emit()
	return true
