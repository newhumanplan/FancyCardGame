class_name SellService
extends RefCounted

const BazaarContentClass = preload("res://scripts/data/bazaar_content.gd")
const ItemAcquisitionClass = preload("res://scripts/data/item_acquisition.gd")
const ItemDataClass = preload("res://scripts/data/item_data.gd")
const LinearInventoryClass = preload("res://scripts/data/linear_inventory.gd")
const WikiMonsterCatalogClass = preload("res://scripts/data/wiki_monster_catalog.gd")

const _EXPLICIT_SELL_VALUES := {
	"bar_of_gold": [5, 10, 20, 40],
	"bag_of_jewels": [3, 6, 12, 24],
	"chunk_of_gold": [3, 6, 9, 12],
	"pelt": [2, 4, 6, 8],
	"spare_change": [1, 2, 3, 4],
}

const _MAX_HEALTH_GAINS := {
	"arken_s_ring": [0],
	"bluenanas": [20, 60, 120, 200],
	"chocolate_bar": [10, 20, 30, 40],
	"coconut": [10, 20, 30, 40],
	"green_gumball": [10, 20, 30, 40],
}

const _XP_GAINS := {
	"vial_of_blood": [1, 2, 3],
}

const _PRESTIGE_GAINS := {
	"arken_s_ring": [5],
}

const _LEFTMOST_ITEM_CRIT := {
	"eagle_talisman": [5, 10, 15, 20],
}

const _ALL_ITEMS_CRIT := {
	"agility_boots": [1, 2, 3, 4],
	"blue_gumball": [1, 2, 3, 4],
}

const _LEFTMOST_WEAPON_DAMAGE := {
	"magnifying_glass": [5, 15, 30, 50],
	"old_sword": [4, 6, 8, 10],
	"rune_axe": [1, 2, 3, 4],
	"sharpening_stone": [5, 10, 15, 20],
}

const _ALL_WEAPON_DAMAGE := {
	"junkyard_club": [4, 6, 8, 10],
	"lifting_gloves": [3, 6, 9, 12],
	"red_gumball": [1, 2, 3, 4],
}

const _LEFTMOST_SHIELD_GAIN := {
	"marble_scalemail": [3, 6, 9, 12],
	"scrap": [3, 6, 12, 24],
}

const _ALL_SHIELD_GAIN := {
	"yellow_gumball": [1, 2, 3, 4],
}

const _LEFTMOST_HEAL_GAIN := {
	"hot_springs": [10, 20, 30, 40],
	"junkyard_repairbot": [5, 15, 30, 50],
	"med_kit": [5, 10, 20, 40],
}

const _LEFTMOST_BURN_GAIN := {
	"cinders": [1, 2, 3, 4],
	"salamander_pup": [3, 4, 5, 6],
}

const _LEFTMOST_POISON_GAIN := {
	"extract": [1, 2, 3, 4],
	"trained_spider": [1, 2, 3, 4],
}

const _ALL_ITEM_COOLDOWN_REDUCTION := {
	"clockwork_blades": [1, 2, 3, 4],
	"insect_wing": [3, 6, 9],
}

const _LEFTMOST_AMMO_GAIN := {
	"gunpowder": [1, 2, 3],
}

const _SELL_SMALL_DAMAGE_OBSERVERS := {
	"dog": [3, 6, 9, 12],
}

const _SELL_SMALL_SHIELD_OBSERVERS := {
	"temporary_shelter": [5, 10, 15, 20],
}

const _SELL_NON_WEAPON_SHIELD_OBSERVERS := {
	"silk_scarf": [6, 12, 18, 24],
}

const _SELL_TOOL_AMMO_OBSERVERS := {
	"gearnola_bar": [1],
}

static func calculate_sell_price(item: ItemDataClass) -> int:
	if item == null:
		return 0
	if _has_no_base_value(item):
		return 0
	var source_id: String = item.source_id.to_lower()
	if _EXPLICIT_SELL_VALUES.has(source_id):
		return _item_value_for_rarity(item, _EXPLICIT_SELL_VALUES[source_id])
	return maxi(item.buy_price, 0)

static func sell_item(item: ItemDataClass, inventory: LinearInventoryClass, related_inventory: LinearInventoryClass = null) -> Dictionary:
	var result: Dictionary = {
		"success": false,
		"sell_price": 0,
		"effects_applied": [],
		"unsupported": [],
		"sold_item_name": "" if item == null else item.item_name,
	}
	if item == null or inventory == null or not inventory.has_item(item):
		result["unsupported"].append("invalid_sale_target")
		return result

	var sell_price: int = calculate_sell_price(item)
	result["sell_price"] = sell_price

	if not inventory.remove_item(item):
		result["unsupported"].append("inventory_remove_failed")
		return result

	if sell_price > 0:
		RewardService.apply_reward({"gold": sell_price}, "sell_base_%s" % item.source_id)
		result["effects_applied"].append("gold:+%d" % sell_price)

	var touched: Array[LinearInventoryClass] = [inventory]
	if related_inventory != null and related_inventory != inventory:
		touched.append(related_inventory)

	_apply_direct_sell_effects(item, inventory, related_inventory, result)
	_apply_sell_observer_effects(item, inventory, related_inventory, result)
	_emit_inventory_updates(touched)

	result["success"] = true
	return result

static func _apply_direct_sell_effects(item: ItemDataClass, inventory: LinearInventoryClass, related_inventory: LinearInventoryClass, result: Dictionary) -> void:
	if item == null:
		return
	var source_id: String = item.source_id.to_lower()

	if source_id == "catalyst":
		if not _transform_leftmost_small_item(item.rarity, inventory, related_inventory):
			result["unsupported"].append("catalyst_transform_missing_target")
		else:
			result["effects_applied"].append("catalyst_transform")

	if _MAX_HEALTH_GAINS.has(source_id):
		var max_health_gain: int = _item_value_for_rarity(item, _MAX_HEALTH_GAINS[source_id])
		if max_health_gain > 0:
			RewardService.apply_reward({"max_health": max_health_gain}, "sell_%s" % source_id)
			result["effects_applied"].append("max_health:+%d" % max_health_gain)

	if _XP_GAINS.has(source_id):
		var xp_gain: int = _item_value_for_rarity(item, _XP_GAINS[source_id])
		if xp_gain > 0:
			RewardService.apply_reward({"xp": xp_gain}, "sell_%s" % source_id)
			result["effects_applied"].append("xp:+%d" % xp_gain)

	if _PRESTIGE_GAINS.has(source_id):
		var prestige_gain: int = _item_value_for_rarity(item, _PRESTIGE_GAINS[source_id])
		if prestige_gain > 0:
			RunStateService.add_prestige(prestige_gain)
			result["effects_applied"].append("prestige:+%d" % prestige_gain)

	if _LEFTMOST_ITEM_CRIT.has(source_id):
		_apply_crit_to_item(_find_leftmost_item(inventory, related_inventory), _item_value_for_rarity(item, _LEFTMOST_ITEM_CRIT[source_id]), result)

	if _ALL_ITEMS_CRIT.has(source_id):
		_apply_crit_to_items(_collect_owned_items(inventory, related_inventory), _item_value_for_rarity(item, _ALL_ITEMS_CRIT[source_id]), result)

	if _LEFTMOST_WEAPON_DAMAGE.has(source_id):
		_apply_damage_to_item(_find_leftmost_matching_item(inventory, related_inventory, "weapon"), _item_value_for_rarity(item, _LEFTMOST_WEAPON_DAMAGE[source_id]), result)

	if _ALL_WEAPON_DAMAGE.has(source_id):
		_apply_damage_to_items(_collect_matching_items(inventory, related_inventory, "weapon"), _item_value_for_rarity(item, _ALL_WEAPON_DAMAGE[source_id]), result)

	if _LEFTMOST_SHIELD_GAIN.has(source_id):
		_apply_shield_to_item(_find_leftmost_matching_item(inventory, related_inventory, "shield"), _item_value_for_rarity(item, _LEFTMOST_SHIELD_GAIN[source_id]), result)

	if _ALL_SHIELD_GAIN.has(source_id):
		_apply_shield_to_items(_collect_matching_items(inventory, related_inventory, "shield"), _item_value_for_rarity(item, _ALL_SHIELD_GAIN[source_id]), result)

	if _LEFTMOST_HEAL_GAIN.has(source_id):
		_apply_heal_to_item(_find_leftmost_matching_item(inventory, related_inventory, "heal"), _item_value_for_rarity(item, _LEFTMOST_HEAL_GAIN[source_id]), result)

	if _LEFTMOST_BURN_GAIN.has(source_id):
		_apply_burn_to_item(_find_leftmost_matching_item(inventory, related_inventory, "burn"), _item_value_for_rarity(item, _LEFTMOST_BURN_GAIN[source_id]), result)

	if _LEFTMOST_POISON_GAIN.has(source_id):
		_apply_poison_to_item(_find_leftmost_matching_item(inventory, related_inventory, "poison"), _item_value_for_rarity(item, _LEFTMOST_POISON_GAIN[source_id]), result)

	if _ALL_ITEM_COOLDOWN_REDUCTION.has(source_id):
		_reduce_cooldowns_percent(_collect_owned_items(inventory, related_inventory), _item_value_for_rarity(item, _ALL_ITEM_COOLDOWN_REDUCTION[source_id]), result)

	if _LEFTMOST_AMMO_GAIN.has(source_id):
		_apply_ammo_to_item(_find_leftmost_matching_item(inventory, related_inventory, "ammo"), _item_value_for_rarity(item, _LEFTMOST_AMMO_GAIN[source_id]), result)

	if source_id in ["upgrade_hammer", "magician_s_top_hat"]:
		if _upgrade_leftmost_item(inventory, related_inventory):
			result["effects_applied"].append("upgrade_leftmost_item")
		else:
			result["unsupported"].append("%s_missing_upgrade_target" % source_id)

	if source_id == "safe":
		var granted: int = _grant_items("spare_change", 3, item.rarity, inventory, related_inventory)
		if granted > 0:
			result["effects_applied"].append("safe_spare_change:%d" % granted)
		if granted < 3:
			result["unsupported"].append("safe_spare_change_partial")

	if source_id in ["citrus", "gland", "sifting_pan", "vial_of_blood", "colossal_popsicle", "darkstone_focuser", "flamecoil_gem", "genie_lamp", "landscraper", "maitoan_altar", "thieves_guild_medallion", "tourist_chariot", "truffles"]:
		if source_id in ["citrus", "gland", "sifting_pan", "colossal_popsicle", "darkstone_focuser", "flamecoil_gem", "genie_lamp", "landscraper", "maitoan_altar", "thieves_guild_medallion", "tourist_chariot", "truffles"]:
			result["unsupported"].append("unsupported_sell_effect:%s" % source_id)

static func _apply_sell_observer_effects(sold_item: ItemDataClass, inventory: LinearInventoryClass, related_inventory: LinearInventoryClass, result: Dictionary) -> void:
	var sold_small: bool = sold_item != null and sold_item.get_slot_count() == 1
	var sold_tool: bool = _matches_selector(sold_item, "tool")
	var sold_non_weapon: bool = sold_item != null and not _matches_selector(sold_item, "weapon")
	for observer in _collect_owned_items(inventory, related_inventory):
		if observer == null:
			continue
		var observer_id: String = observer.source_id.to_lower()
		if sold_small and _SELL_SMALL_DAMAGE_OBSERVERS.has(observer_id):
			_apply_damage_to_item(observer, _item_value_for_rarity(observer, _SELL_SMALL_DAMAGE_OBSERVERS[observer_id]), result)
		if sold_small and _SELL_SMALL_SHIELD_OBSERVERS.has(observer_id):
			_apply_shield_to_item(observer, _item_value_for_rarity(observer, _SELL_SMALL_SHIELD_OBSERVERS[observer_id]), result)
		if sold_non_weapon and _SELL_NON_WEAPON_SHIELD_OBSERVERS.has(observer_id):
			_apply_shield_to_item(observer, _item_value_for_rarity(observer, _SELL_NON_WEAPON_SHIELD_OBSERVERS[observer_id]), result)
		if sold_tool and _SELL_TOOL_AMMO_OBSERVERS.has(observer_id):
			_apply_ammo_to_item(observer, _item_value_for_rarity(observer, _SELL_TOOL_AMMO_OBSERVERS[observer_id]), result)
		if observer_id in ["vat_of_acid", "landscraper"]:
			result["unsupported"].append("unsupported_sell_observer:%s" % observer_id)

static func _grant_items(item_id: String, count: int, rarity: int, inventory: LinearInventoryClass, related_inventory: LinearInventoryClass) -> int:
	var granted: int = 0
	for _index in range(maxi(count, 0)):
		var item: ItemDataClass = BazaarContentClass.create_item(item_id, rarity)
		if item == null:
			continue
		var grant_result: Dictionary = ItemAcquisitionClass.grant_item(item, inventory, related_inventory, related_inventory != null)
		if bool(grant_result.get("success", false)):
			granted += 1
	return granted

static func _upgrade_leftmost_item(inventory: LinearInventoryClass, related_inventory: LinearInventoryClass) -> bool:
	var target: ItemDataClass = _find_leftmost_item(inventory, related_inventory)
	if target == null or target.rarity >= BazaarContentClass.RARITY_DIAMOND:
		return false
	return BazaarContentClass.apply_rarity_to_item(target, target.rarity + 1)

static func _transform_leftmost_small_item(rarity: int, inventory: LinearInventoryClass, related_inventory: LinearInventoryClass) -> bool:
	var target: ItemDataClass = _find_leftmost_matching_item(inventory, related_inventory, "small")
	if target == null:
		return false
	var target_inventory: LinearInventoryClass = _find_inventory_containing(target, inventory, related_inventory)
	if target_inventory == null:
		return false
	var start_slot: int = target.slot_index
	var replacement: ItemDataClass = BazaarContentClass.create_random_mak_day1_item(rarity, "Small", "", false)
	if replacement == null:
		return false
	if not target_inventory.remove_item(target):
		return false
	if target_inventory.place_item(replacement, start_slot):
		return true
	target_inventory.place_item(target, start_slot)
	return false

static func _apply_damage_to_item(item: ItemDataClass, amount: int, result: Dictionary) -> void:
	if item == null or amount <= 0:
		return
	item.damage += amount
	result["effects_applied"].append("%s damage:+%d" % [item.item_name, amount])

static func _apply_damage_to_items(items: Array[ItemDataClass], amount: int, result: Dictionary) -> void:
	if amount <= 0:
		return
	for item in items:
		_apply_damage_to_item(item, amount, result)

static func _apply_shield_to_item(item: ItemDataClass, amount: int, result: Dictionary) -> void:
	if item == null or amount <= 0:
		return
	item.shield += amount
	result["effects_applied"].append("%s shield:+%d" % [item.item_name, amount])

static func _apply_shield_to_items(items: Array[ItemDataClass], amount: int, result: Dictionary) -> void:
	if amount <= 0:
		return
	for item in items:
		_apply_shield_to_item(item, amount, result)

static func _apply_heal_to_item(item: ItemDataClass, amount: int, result: Dictionary) -> void:
	if item == null or amount <= 0:
		return
	item.heal += amount
	result["effects_applied"].append("%s heal:+%d" % [item.item_name, amount])

static func _apply_poison_to_item(item: ItemDataClass, amount: int, result: Dictionary) -> void:
	if item == null or amount <= 0:
		return
	item.poison_damage += float(amount)
	result["effects_applied"].append("%s poison:+%d" % [item.item_name, amount])

static func _apply_burn_to_item(item: ItemDataClass, amount: int, result: Dictionary) -> void:
	if item == null or amount <= 0:
		return
	item.burn_damage += float(amount)
	result["effects_applied"].append("%s burn:+%d" % [item.item_name, amount])

static func _apply_crit_to_item(item: ItemDataClass, amount: int, result: Dictionary) -> void:
	if item == null or amount <= 0:
		return
	item.crit_chance = clampf(item.crit_chance + float(amount) / 100.0, 0.0, 3.0)
	result["effects_applied"].append("%s crit:+%d%%" % [item.item_name, amount])

static func _apply_crit_to_items(items: Array[ItemDataClass], amount: int, result: Dictionary) -> void:
	if amount <= 0:
		return
	for item in items:
		_apply_crit_to_item(item, amount, result)

static func _apply_ammo_to_item(item: ItemDataClass, amount: int, result: Dictionary) -> void:
	if item == null or amount <= 0:
		return
	item.ammo += amount
	item.current_max_ammo = maxi(item.current_max_ammo, item.ammo) if item.current_max_ammo >= 0 else item.current_max_ammo
	result["effects_applied"].append("%s ammo:+%d" % [item.item_name, amount])

static func _reduce_cooldowns_percent(items: Array[ItemDataClass], percent: int, result: Dictionary) -> void:
	if percent <= 0:
		return
	for item in items:
		if item == null or item.cooldown <= 0.0:
			continue
		var ratio: float = clampf(1.0 - float(percent) / 100.0, 0.1, 1.0)
		item.cooldown = maxf(item.cooldown * ratio, ItemDataClass.MIN_ITEM_COOLDOWN)
		if item.current_cooldown > 0.0:
			item.current_cooldown = minf(item.current_cooldown, item.cooldown)
		result["effects_applied"].append("%s cooldown:-%d%%" % [item.item_name, percent])

static func _find_leftmost_item(inventory: LinearInventoryClass, related_inventory: LinearInventoryClass) -> ItemDataClass:
	var items: Array[ItemDataClass] = _collect_owned_items(inventory, related_inventory)
	return null if items.is_empty() else items[0]

static func _find_leftmost_matching_item(inventory: LinearInventoryClass, related_inventory: LinearInventoryClass, selector: String) -> ItemDataClass:
	for item in _collect_owned_items(inventory, related_inventory):
		if _matches_selector(item, selector):
			return item
	return null

static func _collect_matching_items(inventory: LinearInventoryClass, related_inventory: LinearInventoryClass, selector: String) -> Array[ItemDataClass]:
	var matches: Array[ItemDataClass] = []
	for item in _collect_owned_items(inventory, related_inventory):
		if _matches_selector(item, selector):
			matches.append(item)
	return matches

static func _collect_owned_items(inventory: LinearInventoryClass, related_inventory: LinearInventoryClass) -> Array[ItemDataClass]:
	var collected: Array[ItemDataClass] = []
	for item in ItemAcquisitionClass.collect_owned_items(inventory, related_inventory):
		if item is ItemDataClass:
			collected.append(item as ItemDataClass)
	return collected

static func _find_inventory_containing(item: ItemDataClass, inventory: LinearInventoryClass, related_inventory: LinearInventoryClass) -> LinearInventoryClass:
	for candidate in [inventory, related_inventory]:
		if candidate != null and candidate.has_item(item):
			return candidate
	return null

static func _emit_inventory_updates(inventories: Array[LinearInventoryClass]) -> void:
	for inventory in inventories:
		if inventory != null:
			inventory.inventory_changed.emit()

static func _matches_selector(item: ItemDataClass, selector: String) -> bool:
	if item == null:
		return false
	match selector:
		"ammo":
			return item.ammo > 0
		"burn":
			return _has_tag(item, "burn") or item.burn_damage > 0.0
		"heal":
			return _has_tag(item, "heal") or item.heal > 0
		"poison":
			return _has_tag(item, "poison") or item.poison_damage > 0.0
		"shield":
			return _has_tag(item, "shield") or item.shield > 0
		"small":
			return item.get_slot_count() == 1
		"tool":
			return _has_tag(item, "tool")
		"weapon":
			return _has_tag(item, "weapon") or item.type == ItemDataClass.Type.WEAPON
		_:
			return false

static func _has_tag(item: ItemDataClass, tag: String) -> bool:
	var needle: String = tag.to_lower()
	for item_tag in item.tags:
		if item_tag.to_lower() == needle:
			return true
	return false

static func _item_value_for_rarity(item: ItemDataClass, values: Array) -> int:
	if item == null or values.is_empty():
		return 0
	var index: int = clampi(item.rarity - 1, 0, values.size() - 1)
	return int(values[index])

static func _has_no_base_value(item: ItemDataClass) -> bool:
	if item == null:
		return false
	var text: String = "%s %s" % [item.description, item.source_effect_text]
	var wiki_spec: Dictionary = WikiMonsterCatalogClass.find_item_spec(item.source_id)
	if not wiki_spec.is_empty():
		text += " %s" % str(wiki_spec.get("effect", ""))
	return "no base value" in text.to_lower()
