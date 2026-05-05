class_name SellService
extends RefCounted

const BazaarContentClass = preload("res://scripts/data/bazaar_content.gd")
const EnchantmentCatalogClass = preload("res://scripts/data/enchantment_catalog.gd")
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

const _SELL_REGEN_GAINS := {
	"citrus": [1, 2, 3, 4],
	"gland": [1, 2, 3, 4],
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

const _SELL_CATALYST_REGEN_OBSERVERS := {
	"sifting_pan": [1, 2, 3],
}

const _REAGENT_TRANSFORM_ENCHANTMENTS := {
	"death_caps": "toxic",
	"hemlock": "toxic",
	"mothmeal": "heavy",
	"myrrh": "restorative",
	"nightshade": "toxic",
	"shard_of_obsidian": "obsidian",
	"sulphur": "fiery",
}

const _REAGENT_TRANSFORM_BURN_OBSERVERS := {
	"calcinator": [3, 5, 7, 9],
}

const _REAGENT_TRANSFORM_POISON_OBSERVERS := {
	"retort": [3, 5, 7, 9],
}

const _REAGENT_TRANSFORM_REGEN_OBSERVERS := {
	"philosophers_stone": [2, 3, 4, 5],
	"the_tome_of_yyahan": [4, 10, 15],
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
		var transform_result: Dictionary = _transform_leftmost_small_item(item.rarity, inventory, related_inventory)
		if not bool(transform_result.get("success", false)):
			result["unsupported"].append("catalyst_transform_missing_target")
		else:
			result["effects_applied"].append("catalyst_transform")
			result["transforms"] = result.get("transforms", [])
			(result["transforms"] as Array).append(transform_result)
			for effect_entry in transform_result.get("effects_applied", []):
				result["effects_applied"].append(str(effect_entry))
		for unsupported_entry in transform_result.get("unsupported", []):
			result["unsupported"].append(str(unsupported_entry))

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

	if _SELL_REGEN_GAINS.has(source_id):
		_apply_run_regeneration_bonus(_item_value_for_rarity(item, _SELL_REGEN_GAINS[source_id]), "sell_%s" % source_id, result)

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

	if source_id == "feather":
		_reduce_cooldowns_percent([_find_leftmost_item(inventory, related_inventory)], _item_value_for_rarity(item, [2, 4, 6]), result)

	if source_id == "improvised_bludgeon":
		_apply_duration_to_item(_find_leftmost_matching_item(inventory, related_inventory, "slow"), "slow_duration", 1.0, result)

	if source_id == "rocket_boots":
		_apply_duration_to_item(_find_leftmost_matching_item(inventory, related_inventory, "haste"), "haste_duration", 1.0, result)

	if source_id == "snowflake":
		_apply_duration_to_item(_find_leftmost_matching_item(inventory, related_inventory, "freeze"), "freeze_duration", 0.5, result)

	if source_id == "genie_lamp":
		_add_service_unlock("genie_rit", source_id, result)

	if source_id == "thieves_guild_medallion":
		_add_service_unlock("thieves_guild", source_id, result)

	if source_id in ["colossal_popsicle", "darkstone_focuser", "flamecoil_gem", "landscraper", "maitoan_altar", "tourist_chariot", "truffles"]:
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
		if sold_item.source_id.to_lower() == "catalyst" and _SELL_CATALYST_REGEN_OBSERVERS.has(observer_id):
			_apply_run_regeneration_bonus(_item_value_for_rarity(observer, _SELL_CATALYST_REGEN_OBSERVERS[observer_id]), "sell_catalyst:%s" % observer_id, result)
		if observer_id == "vat_of_acid":
			_apply_sold_item_tags_to_observer(observer, sold_item, result)
		if observer_id == "landscraper":
			_apply_landscraper_sell_counter(observer, result)

static func _apply_landscraper_sell_counter(observer: ItemDataClass, result: Dictionary) -> void:
	if observer == null:
		return
	var sell_count: int = int(observer.runtime_counters.get("sold_items", 0)) + 1
	observer.runtime_counters["sold_items"] = sell_count
	result["effects_applied"].append("landscraper_sell_count:%d" % sell_count)
	if sell_count < 10:
		return
	observer.runtime_counters["sold_items"] = 0
	var value_gain: int = _item_value_for_rarity(observer, [0, 0, 5, 10])
	if value_gain <= 0:
		return
	observer.buy_price += value_gain
	result["effects_applied"].append("landscraper_value:+%d" % value_gain)

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

static func _transform_leftmost_small_item(rarity: int, inventory: LinearInventoryClass, related_inventory: LinearInventoryClass) -> Dictionary:
	var result: Dictionary = {
		"success": false,
		"source_id": "catalyst",
		"target_id": "",
		"replacement_id": "",
		"enchantment": "",
		"effects_applied": [],
		"unsupported": [],
	}
	var target: ItemDataClass = _find_leftmost_matching_item(inventory, related_inventory, "small")
	if target == null:
		result["unsupported"].append("transform_missing_leftmost_small")
		return result
	var target_inventory: LinearInventoryClass = _find_inventory_containing(target, inventory, related_inventory)
	if target_inventory == null:
		result["unsupported"].append("transform_inventory_not_found")
		return result
	var start_slot: int = target.slot_index
	var target_id: String = target.source_id
	var target_rarity: int = target.rarity
	var was_reagent: bool = _has_tag(target, "reagent")
	result["target_id"] = target_id
	var replacement: ItemDataClass = BazaarContentClass.create_random_mak_day1_shop_item(rarity, [target], "Small", "")
	if replacement == null:
		result["unsupported"].append("transform_replacement_missing")
		return result
	if was_reagent:
		var enchantment_id: String = str(_REAGENT_TRANSFORM_ENCHANTMENTS.get(target_id, ""))
		if not enchantment_id.is_empty() and EnchantmentCatalogClass.is_known_enchantment(enchantment_id):
			EnchantmentCatalogClass.apply_to_item(replacement, enchantment_id)
			result["enchantment"] = enchantment_id
			result["effects_applied"].append("transform_enchant:%s" % enchantment_id)
		elif not enchantment_id.is_empty():
			result["unsupported"].append("unknown_transform_enchantment:%s" % enchantment_id)
	if not target_inventory.remove_item(target):
		result["unsupported"].append("transform_remove_failed")
		return result
	if target_inventory.place_item(replacement, start_slot):
		result["success"] = true
		result["replacement_id"] = replacement.source_id
		if was_reagent:
			_apply_reagent_transform_observer_effects(target_id, target_rarity, inventory, related_inventory, result)
		return result
	target_inventory.place_item(target, start_slot)
	result["unsupported"].append("transform_place_failed")
	return result

static func _apply_reagent_transform_observer_effects(
	target_id: String,
	target_rarity: int,
	inventory: LinearInventoryClass,
	related_inventory: LinearInventoryClass,
	result: Dictionary
) -> void:
	for observer in _collect_owned_items(inventory, related_inventory):
		if observer == null:
			continue
		var observer_id: String = observer.source_id.to_lower()
		if _REAGENT_TRANSFORM_BURN_OBSERVERS.has(observer_id):
			_apply_burn_to_item(observer, _item_value_for_rarity(observer, _REAGENT_TRANSFORM_BURN_OBSERVERS[observer_id]), result)
		if _REAGENT_TRANSFORM_POISON_OBSERVERS.has(observer_id):
			_apply_poison_to_item(observer, _item_value_for_rarity(observer, _REAGENT_TRANSFORM_POISON_OBSERVERS[observer_id]), result)
		if _REAGENT_TRANSFORM_REGEN_OBSERVERS.has(observer_id):
			_apply_regeneration_to_item(observer, _item_value_for_rarity(observer, _REAGENT_TRANSFORM_REGEN_OBSERVERS[observer_id]), result)
	result["effects_applied"].append("reagent_transformed:%s:%s" % [target_id, _rarity_name(target_rarity)])

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

static func _apply_regeneration_to_item(item: ItemDataClass, amount: int, result: Dictionary) -> void:
	if item == null or amount <= 0:
		return
	item.regeneration += float(amount)
	result["effects_applied"].append("%s regeneration:+%d" % [item.item_name, amount])

static func _apply_run_regeneration_bonus(amount: int, source: String, result: Dictionary) -> void:
	if amount <= 0:
		return
	RunStateService.add_battle_start_status_bonus("regeneration", float(amount), source)
	result["effects_applied"].append("regeneration:+%d" % amount)
	var combat_state: Dictionary = result.get("combat_state", {})
	combat_state["regeneration"] = float(combat_state.get("regeneration", 0.0)) + float(amount)
	result["combat_state"] = combat_state

static func _add_service_unlock(service_id: String, source_id: String, result: Dictionary) -> void:
	RunStateService.add_service_unlock(service_id, 1, "sell_%s" % source_id)
	result["effects_applied"].append("service_unlock:%s" % service_id)
	var service_unlocks: Dictionary = result.get("service_unlocks", {})
	service_unlocks[service_id] = int(service_unlocks.get(service_id, 0)) + 1
	result["service_unlocks"] = service_unlocks

static func _apply_duration_to_item(item: ItemDataClass, field_name: String, amount: float, result: Dictionary) -> void:
	if item == null or amount <= 0.0:
		return
	match field_name:
		"slow_duration":
			item.slow_duration += amount
		"haste_duration":
			item.haste_duration += amount
		"freeze_duration":
			item.freeze_duration += amount
		_:
			return
	result["effects_applied"].append("%s %s:+%.1f" % [item.item_name, field_name, amount])

static func _apply_sold_item_tags_to_observer(observer: ItemDataClass, sold_item: ItemDataClass, result: Dictionary) -> void:
	if observer == null or sold_item == null:
		return
	var added: Array[String] = []
	for tag in sold_item.tags:
		var tag_text: String = str(tag)
		if tag_text.is_empty() or _has_tag(observer, tag_text):
			continue
		observer.tags.append(tag_text)
		added.append(tag_text)
	if not added.is_empty():
		result["effects_applied"].append("vat_of_acid_tags:+%s" % ",".join(added))

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
		"slow":
			return _has_tag(item, "slow") or item.slow_count > 0
		"haste":
			return _has_tag(item, "haste") or item.haste_count > 0
		"freeze":
			return _has_tag(item, "freeze") or item.freeze_count > 0
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

static func _rarity_name(rarity: int) -> String:
	match rarity:
		BazaarContentClass.RARITY_SILVER:
			return "Silver"
		BazaarContentClass.RARITY_GOLD:
			return "Gold"
		BazaarContentClass.RARITY_DIAMOND:
			return "Diamond"
	return "Bronze"

static func _has_no_base_value(item: ItemDataClass) -> bool:
	if item == null:
		return false
	var text: String = "%s %s" % [item.description, item.source_effect_text]
	var wiki_spec: Dictionary = WikiMonsterCatalogClass.find_item_spec(item.source_id)
	if not wiki_spec.is_empty():
		text += " %s" % str(wiki_spec.get("effect", ""))
	return "no base value" in text.to_lower()
