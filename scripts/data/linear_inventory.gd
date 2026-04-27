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

## 判断物品是否属于当前物品栏
func has_item(item: ItemDataClass) -> bool:
	return item != null and items.has(item)

## 预检查将物品移动到目标物品栏/槽位是否可行，不产生实际变更
func can_move_item_to_inventory(item: ItemDataClass, target_inventory: LinearInventory, target_slot: int) -> bool:
	return _move_item_to_inventory_internal(item, target_inventory, target_slot, false)

## Bazaar 风格移动物品：
## 1. 目标区域空则直接放下。
## 2. 目标区域被占用则尝试把右侧物品整体顺延。
## 3. 顺延失败时，尝试把目标跨度内的一组物品整体换回源位置。
func move_item_to_inventory(item: ItemDataClass, target_inventory: LinearInventory, target_slot: int) -> bool:
	return _move_item_to_inventory_internal(item, target_inventory, target_slot, true)

func move_item_to_slot(item: ItemDataClass, target_slot: int) -> bool:
	return move_item_to_inventory(item, self, target_slot)

## 预检查把一个尚未属于任何物品栏的新物品插入到指定槽位。
func can_insert_new_item(item: ItemDataClass, target_slot: int) -> bool:
	return _insert_new_item_internal(item, target_slot, false)

## 把一个尚未属于任何物品栏的新物品按 Bazaar 插入规则放入指定槽位。
func insert_new_item(item: ItemDataClass, target_slot: int) -> bool:
	return _insert_new_item_internal(item, target_slot, true)

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

	var item_a: ItemDataClass = _get_item_at_slot(slot_a)
	if item_a == null:
		return true
	return move_item_to_slot(item_a, slot_b)

func _move_item_to_inventory_internal(item: ItemDataClass, target_inventory: LinearInventory, target_slot: int, commit: bool) -> bool:
	if item == null or target_inventory == null:
		return false
	if not has_item(item):
		return false
	if target_slot < 0 or target_slot >= TOTAL_SLOTS:
		return false
	if target_slot + item.get_slot_count() > TOTAL_SLOTS:
		return false

	var same_inventory: bool = target_inventory == self
	var source_snapshot: Dictionary = _capture_state()
	var target_snapshot: Dictionary = {} if same_inventory else target_inventory._capture_state()

	var success: bool = _try_insert_move(item, target_inventory, target_slot)
	if not success:
		_restore_state(source_snapshot)
		if not same_inventory:
			target_inventory._restore_state(target_snapshot)
		success = _try_group_swap_move(item, target_inventory, target_slot)

	if not success or not commit:
		_restore_state(source_snapshot)
		if not same_inventory:
			target_inventory._restore_state(target_snapshot)
		return success

	_normalize_layout()
	if not same_inventory:
		target_inventory._normalize_layout()
		target_inventory.inventory_changed.emit()
	inventory_changed.emit()
	return true

func _insert_new_item_internal(item: ItemDataClass, target_slot: int, commit: bool) -> bool:
	if item == null or has_item(item):
		return false
	if target_slot < 0 or target_slot >= TOTAL_SLOTS:
		return false
	if target_slot + item.get_slot_count() > TOTAL_SLOTS:
		return false

	var snapshot: Dictionary = _capture_state()
	item.slot_index = -1
	var success: bool = false
	if can_place_item(item, target_slot):
		success = _place_existing_item_no_emit(item, target_slot)
	else:
		success = _pack_with_insert_no_emit(item, target_slot)

	if not success or not commit:
		_restore_state(snapshot)
		if not has_item(item):
			item.slot_index = -1
		return success

	_normalize_layout()
	inventory_changed.emit()
	return true

func _try_insert_move(item: ItemDataClass, target_inventory: LinearInventory, target_slot: int) -> bool:
	if not _remove_existing_item_no_emit(item):
		return false

	if target_inventory.can_place_item(item, target_slot):
		return target_inventory._place_existing_item_no_emit(item, target_slot)

	return target_inventory._pack_with_insert_no_emit(item, target_slot)

func _try_group_swap_move(item: ItemDataClass, target_inventory: LinearInventory, target_slot: int) -> bool:
	var source_slot: int = item.slot_index
	var dragged_size: int = item.get_slot_count()
	var target_group: Array[ItemDataClass] = target_inventory._get_items_in_span(target_slot, dragged_size)

	if target_group.is_empty():
		return false
	if target_group.has(item):
		return false

	var group_slot_count: int = _get_total_slot_count(target_group)
	if group_slot_count > dragged_size:
		return false
	if source_slot < 0 or source_slot + group_slot_count > TOTAL_SLOTS:
		return false

	if not _remove_existing_item_no_emit(item):
		return false
	for target_item in target_group:
		if not target_inventory._remove_existing_item_no_emit(target_item):
			return false

	if not target_inventory._place_existing_item_no_emit(item, target_slot):
		return false

	var cursor: int = source_slot
	for target_item in target_group:
		if not _place_existing_item_no_emit(target_item, cursor):
			return false
		cursor += target_item.get_slot_count()

	return true

func _pack_with_insert_no_emit(item: ItemDataClass, target_slot: int) -> bool:
	var item_size: int = item.get_slot_count()
	if target_slot < 0 or target_slot + item_size > TOTAL_SLOTS:
		return false

	var kept_left: Array[Dictionary] = []
	var shifted_right: Array[Dictionary] = []
	for existing in items:
		if existing == null or existing == item or existing.slot_index < 0:
			continue
		var existing_end: int = existing.slot_index + existing.get_slot_count()
		var entry: Dictionary = {"item": existing, "slot": existing.slot_index}
		if existing_end <= target_slot:
			kept_left.append(entry)
		else:
			shifted_right.append(entry)

	kept_left.sort_custom(Callable(self, "_sort_item_entries_by_slot"))
	shifted_right.sort_custom(Callable(self, "_sort_item_entries_by_slot"))

	_clear_slot_mapping_no_emit()
	for left_entry in kept_left:
		var left_item: ItemDataClass = left_entry.get("item", null) as ItemDataClass
		var left_slot: int = int(left_entry.get("slot", -1))
		if not _place_existing_item_no_emit(left_item, left_slot):
			return false

	if not _place_existing_item_no_emit(item, target_slot):
		return false

	var cursor: int = target_slot + item_size
	for shifted_entry in shifted_right:
		var shifted_item: ItemDataClass = shifted_entry.get("item", null) as ItemDataClass
		cursor = _next_free_slot(cursor)
		if cursor < 0 or cursor + shifted_item.get_slot_count() > TOTAL_SLOTS:
			return false
		if not _place_existing_item_no_emit(shifted_item, cursor):
			return false
		cursor += shifted_item.get_slot_count()

	return true

func _capture_state() -> Dictionary:
	var item_slots: Array[Dictionary] = []
	for item in items:
		if item != null:
			item_slots.append({"item": item, "slot": item.slot_index})
	return {
		"items": items.duplicate(),
		"slots": slots.duplicate(),
		"item_slots": item_slots,
	}

func _restore_state(snapshot: Dictionary) -> void:
	items.clear()
	var snapshot_items: Array = snapshot.get("items", [])
	for item in snapshot_items:
		items.append(item)

	slots.clear()
	var snapshot_slots: Array = snapshot.get("slots", [])
	for slot_value in snapshot_slots:
		slots.append(int(slot_value))

	var item_slots: Array = snapshot.get("item_slots", [])
	for entry in item_slots:
		var item: ItemDataClass = entry.get("item", null) as ItemDataClass
		if item != null:
			item.slot_index = int(entry.get("slot", -1))

func _remove_existing_item_no_emit(item: ItemDataClass) -> bool:
	if item == null or not items.has(item):
		return false

	items.erase(item)
	item.slot_index = -1
	_rebuild_slot_mapping()
	return true

func _place_existing_item_no_emit(item: ItemDataClass, start_slot: int) -> bool:
	if item == null:
		return false
	if not can_place_item(item, start_slot):
		return false

	if not items.has(item):
		items.append(item)
	item.slot_index = start_slot
	_rebuild_slot_mapping()
	return true

func _clear_slot_mapping_no_emit() -> void:
	for item in items:
		if item != null:
			item.slot_index = -1
	items.clear()
	slots.fill(-1)

func _get_items_in_span(start_slot: int, slot_count: int) -> Array[ItemDataClass]:
	var result: Array[ItemDataClass] = []
	var end_slot: int = mini(start_slot + slot_count, TOTAL_SLOTS)
	for slot in range(start_slot, end_slot):
		var item: ItemDataClass = _get_item_at_slot(slot)
		if item != null and not result.has(item):
			result.append(item)
	result.sort_custom(Callable(self, "_sort_items_by_slot"))
	return result

func _get_total_slot_count(group: Array[ItemDataClass]) -> int:
	var total: int = 0
	for item in group:
		if item != null:
			total += item.get_slot_count()
	return total

func _next_free_slot(start_slot: int) -> int:
	for slot in range(maxi(start_slot, 0), TOTAL_SLOTS):
		if slots[slot] == -1:
			return slot
	return -1

func _normalize_layout() -> void:
	items.sort_custom(Callable(self, "_sort_items_by_slot"))
	_rebuild_slot_mapping()

func _sort_items_by_slot(a: ItemDataClass, b: ItemDataClass) -> bool:
	if a == null:
		return false
	if b == null:
		return true
	return a.slot_index < b.slot_index

func _sort_item_entries_by_slot(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("slot", 0)) < int(b.get("slot", 0))
