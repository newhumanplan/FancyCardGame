## 装备系统
## 管理英雄的装备（武器、护甲、饰品）

class_name Equipment
extends Node

## 装备槽位类型
enum EquipmentSlot {
	WEAPON,    # 武器
	ARMOR,     # 护甲
	ACCESSORY, # 饰品
	AMULET     # 护符
}

## 装备数据
var slots: Dictionary = {
	EquipmentSlot.WEAPON: null,
	EquipmentSlot.ARMOR: null,
	EquipmentSlot.ACCESSORY: null,
	EquipmentSlot.AMULET: null
}

## 信号：装备变化
signal equipment_changed(slot: EquipmentSlot)

## 构造函数
func _init() -> void:
	pass

## 获取装备
func get_equipment(slot: EquipmentSlot) -> Item:
	return slots.get(slot, null)

## 获取武器
func get_weapon() -> Weapon:
	return slots.get(EquipmentSlot.WEAPON, null) as Weapon

## 获取护甲
func get_armor() -> Armor:
	return slots.get(EquipmentSlot.ARMOR, null) as Armor

## 获取饰品
func get_accessory() -> Item:
	return slots.get(EquipmentSlot.ACCESSORY, null)

## 获取护符
func get_amulet() -> Item:
	return slots.get(EquipmentSlot.AMULET, null)

## 装备物品
func equip_item(item: Item) -> bool:
	if not item:
		return false
	
	var slot := _get_slot_for_item(item)
	if slot == null:
		return false
	
	# 卸下旧装备
	var old_item = slots[slot]
	slots[slot] = item
	
	equipment_changed.emit(slot)
	return true

## 卸下装备
func unequip_item(slot: EquipmentSlot) -> Item:
	var item = slots.get(slot, null)
	slots[slot] = null
	equipment_changed.emit(slot)
	return item

## 切换装备（从背包格子）
func swap_equipment(slot: EquipmentSlot, inventory: Inventory, inventory_slot: int) -> bool:
	var current_item = slots.get(slot, null)
	var new_item = inventory.get_item(inventory_slot)
	
	# 检查新物品是否适合这个槽位
	if new_item and not _can_equip_to_slot(new_item, slot):
		return false
	
	# 交换
	slots[slot] = new_item
	inventory.slots[inventory_slot] = current_item
	
	equipment_changed.emit(slot)
	inventory.inventory_changed.emit(inventory_slot)
	return true

## 获取物品对应的槽位
func _get_slot_for_item(item: Item) -> EquipmentSlot:
	match item.type:
		Item.ItemType.WEAPON:
			return EquipmentSlot.WEAPON
		Item.ItemType.ARMOR:
			return EquipmentSlot.ARMOR
		Item.ItemType.CONSUMABLE, Item.ItemType.MATERIAL:
			return EquipmentSlot.ACCESSORY  # 暂不支持
	return EquipmentSlot.ACCESSORY

## 检查物品是否可以装备到指定槽位
func _can_equip_to_slot(item: Item, slot: EquipmentSlot) -> bool:
	match slot:
		EquipmentSlot.WEAPON:
			return item is Weapon
		EquipmentSlot.ARMOR:
			return item is Armor
		EquipmentSlot.ACCESSORY, EquipmentSlot.AMULET:
			return item.type == Item.ItemType.MATERIAL
	return false

## 计算总攻击力加成
func get_attack_bonus() -> int:
	var bonus := 0
	if get_weapon():
		bonus += get_weapon().effect_value
	return bonus

## 计算总防御力加成
func get_defense_bonus() -> int:
	var bonus := 0
	if get_armor():
		bonus += get_armor().effect_value
	return bonus

## 获取所有装备
func get_all_equipment() -> Array[Item]:
	var items: Array[Item] = []
	for slot in slots.values():
		if slot:
			items.append(slot)
	return items

## 清空所有装备
func clear() -> void:
	for slot in slots.keys():
		slots[slot] = null
	equipment_changed.emit(EquipmentSlot.WEAPON)
	equipment_changed.emit(EquipmentSlot.ARMOR)
	equipment_changed.emit(EquipmentSlot.ACCESSORY)
	equipment_changed.emit(EquipmentSlot.AMULET)
