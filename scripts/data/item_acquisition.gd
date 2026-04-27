class_name ItemAcquisition
extends RefCounted

const BazaarContentClass = preload("res://scripts/data/bazaar_content.gd")
const ItemDataClass = preload("res://scripts/data/item_data.gd")
const LinearInventoryClass = preload("res://scripts/data/linear_inventory.gd")

static func can_accept_item(item: ItemDataClass, primary_inventory: LinearInventoryClass, secondary_inventory: LinearInventoryClass = null, allow_secondary_place: bool = false) -> bool:
	if item == null:
		return false
	var inventories: Array = _valid_inventories(primary_inventory, secondary_inventory)
	if _can_merge_with_owned(item, inventories):
		return true
	if primary_inventory != null and not primary_inventory.find_empty_slots(item.get_slot_count()).is_empty():
		return true
	return allow_secondary_place and secondary_inventory != null and not secondary_inventory.find_empty_slots(item.get_slot_count()).is_empty()

static func can_accept_item_at_slot(
	item: ItemDataClass,
	primary_inventory: LinearInventoryClass,
	secondary_inventory: LinearInventoryClass,
	target_inventory: LinearInventoryClass,
	target_slot: int,
	allow_secondary_place: bool = false
) -> bool:
	if item == null:
		return false
	var inventories: Array = _valid_inventories(primary_inventory, secondary_inventory)
	if _can_merge_with_owned(item, inventories):
		return true
	if _is_valid_target_inventory(target_inventory, primary_inventory, secondary_inventory, allow_secondary_place):
		return target_inventory.can_insert_new_item(item, target_slot)
	return can_accept_item(item, primary_inventory, secondary_inventory, allow_secondary_place)

static func grant_item(item: ItemDataClass, primary_inventory: LinearInventoryClass, secondary_inventory: LinearInventoryClass = null, allow_secondary_place: bool = false) -> Dictionary:
	var result: Dictionary = {
		"success": false,
		"placed": false,
		"merged": false,
		"merge_count": 0,
		"final_item": null,
		"inventory": null,
	}
	if item == null:
		return result

	var inventories: Array = _valid_inventories(primary_inventory, secondary_inventory)
	var merge_result: Dictionary = _merge_into_owned(item, inventories)
	if bool(merge_result.get("merged", false)):
		result.merge(merge_result, true)
		result["success"] = true
		return result

	var placed_inventory: LinearInventoryClass = _place_in_first_available(item, primary_inventory, secondary_inventory if allow_secondary_place else null)
	if placed_inventory == null:
		return result
	result["success"] = true
	result["placed"] = true
	result["final_item"] = item
	result["inventory"] = placed_inventory
	return result

static func grant_item_at_slot(
	item: ItemDataClass,
	primary_inventory: LinearInventoryClass,
	secondary_inventory: LinearInventoryClass,
	target_inventory: LinearInventoryClass,
	target_slot: int,
	allow_secondary_place: bool = false
) -> Dictionary:
	var result: Dictionary = {
		"success": false,
		"placed": false,
		"merged": false,
		"merge_count": 0,
		"final_item": null,
		"inventory": null,
	}
	if item == null:
		return result

	var inventories: Array = _valid_inventories(primary_inventory, secondary_inventory)
	var merge_result: Dictionary = _merge_into_owned(item, inventories)
	if bool(merge_result.get("merged", false)):
		result.merge(merge_result, true)
		result["success"] = true
		return result

	if _is_valid_target_inventory(target_inventory, primary_inventory, secondary_inventory, allow_secondary_place):
		item.slot_index = -1
		if target_inventory.insert_new_item(item, target_slot):
			result["success"] = true
			result["placed"] = true
			result["final_item"] = item
			result["inventory"] = target_inventory
			return result

	return grant_item(item, primary_inventory, secondary_inventory, allow_secondary_place)

static func grant_start_of_day_items(primary_inventory: LinearInventoryClass, secondary_inventory: LinearInventoryClass = null) -> Dictionary:
	var summary: Dictionary = {
		"catalysts": 0,
		"failed": 0,
	}
	var triggers: Array[ItemDataClass] = []
	for item in collect_owned_items(primary_inventory, secondary_inventory):
		if item.source_id in ["aludel", "mortar_pestle"]:
			triggers.append(item)

	for _item in triggers:
		var catalyst: ItemDataClass = BazaarContentClass.create_item("catalyst", BazaarContentClass.RARITY_BRONZE)
		var grant_result: Dictionary = grant_item(catalyst, primary_inventory, secondary_inventory, true)
		if bool(grant_result.get("success", false)):
			summary["catalysts"] = int(summary.get("catalysts", 0)) + 1
		else:
			summary["failed"] = int(summary.get("failed", 0)) + 1
	return summary

static func collect_owned_items(primary_inventory: LinearInventoryClass, secondary_inventory: LinearInventoryClass = null) -> Array[ItemDataClass]:
	var owned: Array[ItemDataClass] = []
	for inventory in _valid_inventories(primary_inventory, secondary_inventory):
		for item in _items_left_to_right(inventory):
			owned.append(item)
	return owned

static func _valid_inventories(primary_inventory: LinearInventoryClass, secondary_inventory: LinearInventoryClass) -> Array:
	var inventories: Array = []
	if primary_inventory != null:
		inventories.append(primary_inventory)
	if secondary_inventory != null and secondary_inventory != primary_inventory:
		inventories.append(secondary_inventory)
	return inventories

static func _is_valid_target_inventory(
	target_inventory: LinearInventoryClass,
	primary_inventory: LinearInventoryClass,
	secondary_inventory: LinearInventoryClass,
	allow_secondary_place: bool
) -> bool:
	if target_inventory == null:
		return false
	if target_inventory == primary_inventory:
		return true
	return allow_secondary_place and target_inventory == secondary_inventory

static func _items_left_to_right(inventory: LinearInventoryClass) -> Array[ItemDataClass]:
	var result: Array[ItemDataClass] = []
	if inventory == null:
		return result
	var seen: Dictionary = {}
	for slot in range(LinearInventoryClass.TOTAL_SLOTS):
		var item: ItemDataClass = inventory.get_item_at(slot)
		if item == null:
			continue
		var item_id: int = item.get_instance_id()
		if seen.has(item_id):
			continue
		seen[item_id] = true
		result.append(item)
	return result

static func _can_merge_with_owned(item: ItemDataClass, inventories: Array) -> bool:
	if item == null or item.rarity >= BazaarContentClass.RARITY_DIAMOND:
		return false
	for owned in _collect_matching_items(item, inventories):
		if owned != item:
			return true
	return false

static func _merge_into_owned(item: ItemDataClass, inventories: Array) -> Dictionary:
	var result: Dictionary = {
		"merged": false,
		"merge_count": 0,
		"final_item": null,
		"inventory": null,
	}
	if item == null:
		return result

	var current_item: ItemDataClass = item
	while current_item != null and current_item.rarity < BazaarContentClass.RARITY_DIAMOND:
		var matching_items: Array[ItemDataClass] = _collect_matching_items(current_item, inventories)
		if not _is_item_owned(current_item, inventories):
			if matching_items.is_empty():
				break
			var keep_item: ItemDataClass = matching_items[0]
			_upgrade_item(keep_item, inventories)
			result["merged"] = true
			result["merge_count"] = int(result.get("merge_count", 0)) + 1
			result["final_item"] = keep_item
			result["inventory"] = _find_inventory_containing(keep_item, inventories)
			current_item = keep_item
			continue

		if matching_items.size() < 2:
			break
		var survivor: ItemDataClass = matching_items[0]
		var consumed: ItemDataClass = matching_items[1]
		_remove_owned_item(consumed, inventories)
		_upgrade_item(survivor, inventories)
		result["merged"] = true
		result["merge_count"] = int(result.get("merge_count", 0)) + 1
		result["final_item"] = survivor
		result["inventory"] = _find_inventory_containing(survivor, inventories)
		current_item = survivor
	return result

static func _collect_matching_items(item: ItemDataClass, inventories: Array) -> Array[ItemDataClass]:
	var matches: Array[ItemDataClass] = []
	if item == null:
		return matches
	for inventory in inventories:
		for owned in _items_left_to_right(inventory):
			if _same_item_identity(owned, item) and owned.rarity == item.rarity and owned.rarity < BazaarContentClass.RARITY_DIAMOND:
				matches.append(owned)
	return matches

static func _same_item_identity(a: ItemDataClass, b: ItemDataClass) -> bool:
	if a == null or b == null:
		return false
	if not a.source_id.is_empty() or not b.source_id.is_empty():
		return a.source_id == b.source_id
	return a.item_name == b.item_name

static func _upgrade_item(item: ItemDataClass, inventories: Array) -> void:
	if item == null or item.rarity >= BazaarContentClass.RARITY_DIAMOND:
		return
	BazaarContentClass.apply_rarity_to_item(item, item.rarity + 1)
	var inventory: LinearInventoryClass = _find_inventory_containing(item, inventories)
	if inventory != null:
		inventory.inventory_changed.emit()

static func _is_item_owned(item: ItemDataClass, inventories: Array) -> bool:
	return _find_inventory_containing(item, inventories) != null

static func _find_inventory_containing(item: ItemDataClass, inventories: Array) -> LinearInventoryClass:
	for inventory in inventories:
		if inventory != null and inventory.has_item(item):
			return inventory
	return null

static func _remove_owned_item(item: ItemDataClass, inventories: Array) -> bool:
	var inventory: LinearInventoryClass = _find_inventory_containing(item, inventories)
	return inventory != null and inventory.remove_item(item)

static func _place_in_first_available(item: ItemDataClass, primary_inventory: LinearInventoryClass, secondary_inventory: LinearInventoryClass = null) -> LinearInventoryClass:
	for inventory in [primary_inventory, secondary_inventory]:
		if inventory == null:
			continue
		var empty_slots: Array[int] = inventory.find_empty_slots(item.get_slot_count())
		if empty_slots.is_empty():
			continue
		item.slot_index = -1
		if inventory.place_item(item, empty_slots[0]):
			return inventory
	return null
