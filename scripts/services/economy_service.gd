extends Node

## EconomyService - 金币管理
## 从 GameManager 提取

const BazaarContentClass = preload("res://scripts/data/bazaar_content.gd")
const EconomyManagerClass = preload("res://scripts/data/economy_manager.gd")
const HeroDataClass = preload("res://scripts/data/hero_data.gd")
const ItemAcquisitionClass = preload("res://scripts/data/item_acquisition.gd")
const ItemDataClass = preload("res://scripts/data/item_data.gd")
const LinearInventoryClass = preload("res://scripts/data/linear_inventory.gd")

signal gold_changed(amount: int)
signal income_changed(amount: int)

const STARTING_GOLD: int = 15
const STARTING_INCOME: int = 7
const SHOP_FREE_REFRESH_COST: int = 0
const SHOP_PAID_REFRESH_COST: int = 2
const SHOP_MAX_VISIBLE_ITEMS: int = 5

const SERVICE_VENDOR_SPECS: Array[Dictionary] = [
	{"id": "skill_trainer", "name": "Skill Trainer", "kind": "skill_trainer", "min_day": 1, "weight": 12, "summary": "Train a hero skill."},
	{"id": "enchanter", "name": "Enchanter", "kind": "enchanter", "min_day": 2, "weight": 8, "summary": "Enchant your leftmost item."},
	{"id": "healer", "name": "Healer", "kind": "healer", "min_day": 1, "weight": 12, "summary": "Restore Health."},
	{"id": "upgrade_vendor", "name": "Upgrade Vendor", "kind": "upgrade", "min_day": 1, "weight": 10, "summary": "Upgrade your leftmost item."},
	{"id": "free_reward", "name": "Free Reward", "kind": "free_reward", "min_day": 1, "weight": 10, "summary": "Take a small reward."},
	{"id": "finance_office", "name": "Income/Finance", "kind": "finance", "min_day": 1, "weight": 10, "summary": "Improve your economy."},
]

var gold: int = STARTING_GOLD
var income: int = STARTING_INCOME
var total_gold_earned: int = 0

func get_gold() -> int:
	return gold

func add_gold(amount: int) -> void:
	if amount <= 0:
		return
	gold += amount
	total_gold_earned += amount
	gold_changed.emit(gold)

func spend_gold(amount: int) -> bool:
	if amount < 0:
		return false
	if gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true

func can_afford(amount: int) -> bool:
	return gold >= amount

func add_income(amount: int) -> void:
	if amount == 0:
		return
	income = maxi(income + amount, 0)
	income_changed.emit(income)

func reset() -> void:
	gold = STARTING_GOLD
	income = STARTING_INCOME
	total_gold_earned = 0
	gold_changed.emit(gold)
	income_changed.emit(income)

func get_shop_refresh_cost(free_refresh_used: bool) -> int:
	return SHOP_PAID_REFRESH_COST if free_refresh_used else SHOP_FREE_REFRESH_COST

func get_max_shop_rarity_for_day(day: int) -> int:
	return EconomyManagerClass.get_max_rarity(day)

func get_service_vendor_specs(day: int = 1) -> Array[Dictionary]:
	var specs: Array[Dictionary] = []
	for spec in SERVICE_VENDOR_SPECS:
		if maxi(day, 1) < int(spec.get("min_day", 1)):
			continue
		specs.append(spec.duplicate(true))
	return specs

func pick_service_vendor(day: int, excluded_ids: Dictionary = {}) -> Dictionary:
	var eligible: Array[Dictionary] = []
	for spec in get_service_vendor_specs(day):
		var service_id: String = str(spec.get("id", ""))
		if excluded_ids.has(service_id):
			continue
		eligible.append(spec)
	if eligible.is_empty():
		return {}

	var total_weight: int = 0
	for spec in eligible:
		total_weight += maxi(int(spec.get("weight", 1)), 1)
	var roll: int = randi() % maxi(total_weight, 1)
	var cumulative: int = 0
	for spec in eligible:
		cumulative += maxi(int(spec.get("weight", 1)), 1)
		if roll < cumulative:
			return spec.duplicate(true)
	return eligible[0].duplicate(true)

func get_service_vendor_reward(service_id: String, day: int, hero_type: HeroDataClass.HeroType) -> Dictionary:
	var safe_day: int = maxi(day, 1)
	match service_id:
		"skill_trainer":
			var skill_ref: Dictionary = _pick_skill_reward(hero_type)
			if skill_ref.is_empty():
				return {"xp": 1}
			return {"skills": [skill_ref], "skill_count": 1}
		"enchanter":
			return {"enchant_leftmost": _pick_enchantment_for_day(safe_day)}
		"healer":
			return {"heal": 20 + safe_day * 10}
		"upgrade_vendor":
			return {"upgrade_leftmost": true}
		"free_reward":
			var item_ref: Dictionary = _pick_item_reward(hero_type, safe_day)
			if item_ref.is_empty():
				return {"gold": 2 + safe_day}
			return {"items": [item_ref], "item_count": 1}
		"finance_office":
			return {"gold": 3 + safe_day, "income": 1}
	return {}

func generate_merchant_shelf(
	merchant_info: Dictionary,
	inventory: LinearInventoryClass,
	stash_inventory: LinearInventoryClass,
	day: int,
	hero_type: HeroDataClass.HeroType,
	item_count: int = -1
) -> Array[ItemDataClass]:
	var target_count: int = item_count
	if target_count <= 0:
		target_count = randi_range(3, SHOP_MAX_VISIBLE_ITEMS)
	target_count = clampi(target_count, 1, SHOP_MAX_VISIBLE_ITEMS)

	var items: Array[ItemDataClass] = []
	var attempts: int = 0
	while items.size() < target_count and attempts < target_count * 8:
		attempts += 1
		var generated_item: ItemDataClass = generate_merchant_item(
			merchant_info,
			inventory,
			stash_inventory,
			day,
			hero_type,
			items
		)
		if generated_item != null:
			items.append(generated_item)
	return items

func refresh_merchant_shelf(
	current_items: Array[ItemDataClass],
	locked_indices: Array[int],
	merchant_info: Dictionary,
	inventory: LinearInventoryClass,
	stash_inventory: LinearInventoryClass,
	day: int,
	hero_type: HeroDataClass.HeroType
) -> Array[ItemDataClass]:
	var target_count: int = clampi(maxi(current_items.size(), 3), 1, SHOP_MAX_VISIBLE_ITEMS)
	var next_items: Array[ItemDataClass] = []
	for index in range(target_count):
		if index in locked_indices and index < current_items.size() and current_items[index] != null:
			next_items.append(current_items[index])
			continue
		var generated_item: ItemDataClass = generate_merchant_item(
			merchant_info,
			inventory,
			stash_inventory,
			day,
			hero_type,
			next_items
		)
		if generated_item != null:
			next_items.append(generated_item)
	return next_items

func generate_merchant_item(
	merchant_info: Dictionary,
	inventory: LinearInventoryClass,
	stash_inventory: LinearInventoryClass,
	day: int,
	hero_type: HeroDataClass.HeroType,
	pending_items: Array[ItemDataClass] = []
) -> ItemDataClass:
	var required_size: String = ""
	var required_tag: String = ""
	var effective_max_rarity: int = get_max_shop_rarity_for_day(day)
	var merchant_type: String = str(merchant_info.get("merchant_type", merchant_info.get("type", "")))
	var merchant_tier: String = str(merchant_info.get("rarity", merchant_info.get("starting_tier", "")))

	if merchant_tier == "Silver":
		effective_max_rarity = maxi(effective_max_rarity, BazaarContentClass.RARITY_SILVER)

	match merchant_type:
		"Weapon":
			required_tag = "Weapon"
		"Small":
			required_size = "Small"
		"Medium, Large":
			required_size = "Medium"
		"Ammo":
			required_tag = "Ammo"
		"Bronze, Junk":
			required_tag = "Junk"
			effective_max_rarity = BazaarContentClass.RARITY_BRONZE
		"Potion":
			required_tag = "Potion"
		"NonWeapon":
			required_tag = "NonWeapon"
		"Small, Large":
			required_size = "Small"
		"Silver":
			effective_max_rarity = maxi(effective_max_rarity, BazaarContentClass.RARITY_SILVER)

	var owned_items: Array[ItemDataClass] = ItemAcquisitionClass.collect_owned_items(inventory, stash_inventory)
	owned_items.append_array(pending_items)
	var generated_item: ItemDataClass = _create_shop_item_with_fallback(
		hero_type,
		effective_max_rarity,
		owned_items,
		required_size,
		required_tag
	)
	if generated_item != null:
		generated_item.buy_price = calculate_shop_item_price(generated_item, day)
	return generated_item

func calculate_shop_item_price(item: ItemDataClass, day: int) -> int:
	if item == null:
		return 0
	var base_price: int = EconomyManagerClass.calculate_item_price(
		item.rarity,
		item.size as int,
		item.type as int,
		day
	)
	return EconomyManagerClass.apply_prestige_discount(
		base_price,
		RunStateService.prestige,
		RunStateService.max_prestige
	)

func _create_shop_item_with_fallback(
	hero_type: HeroDataClass.HeroType,
	max_rarity: int,
	owned_items: Array,
	required_size: String,
	required_tag: String
) -> ItemDataClass:
	var generated_item: ItemDataClass = null
	if required_tag == "NonWeapon":
		generated_item = _create_random_non_weapon_shop_item(hero_type, max_rarity, owned_items, required_size)
	else:
		generated_item = BazaarContentClass.create_random_hero_shop_item(hero_type, max_rarity, owned_items, required_size, required_tag)
	if generated_item != null:
		return generated_item
	if not required_tag.is_empty():
		generated_item = BazaarContentClass.create_random_hero_shop_item(hero_type, max_rarity, owned_items, required_size, "")
		if generated_item != null:
			return generated_item
	if not required_size.is_empty():
		generated_item = BazaarContentClass.create_random_hero_shop_item(hero_type, max_rarity, owned_items, "", required_tag)
		if generated_item != null:
			return generated_item
	return BazaarContentClass.create_random_hero_shop_item(hero_type, max_rarity, owned_items, "", "")

func _create_random_non_weapon_shop_item(
	hero_type: HeroDataClass.HeroType,
	max_rarity: int,
	owned_items: Array,
	required_size: String
) -> ItemDataClass:
	var candidates: Array[String] = BazaarContentClass.get_hero_item_ids(hero_type)
	candidates.shuffle()
	for item_id in candidates:
		var item: ItemDataClass = BazaarContentClass.create_item(item_id, max_rarity)
		if item == null or item.type == ItemDataClass.Type.WEAPON:
			continue
		if not required_size.is_empty() and not _item_matches_size(item, required_size):
			continue
		if not BazaarContentClass.is_shop_candidate_allowed(item.source_id, item.rarity, owned_items):
			continue
		return item
	return null

func _item_matches_size(item: ItemDataClass, required_size: String) -> bool:
	if item == null:
		return false
	match required_size:
		"Small":
			return item.size == ItemDataClass.Size.SMALL
		"Medium":
			return item.size == ItemDataClass.Size.MEDIUM
		"Large":
			return item.size == ItemDataClass.Size.LARGE
	return true

func _pick_skill_reward(hero_type: HeroDataClass.HeroType) -> Dictionary:
	var skill_ids: Array[String] = BazaarContentClass.get_hero_skill_ids(hero_type)
	if skill_ids.is_empty():
		return {}
	for skill_id in skill_ids:
		var already_owned: bool = false
		if HeroStateService.selected_hero != null:
			for existing_skill in HeroStateService.selected_hero.skills:
				if str(existing_skill) == skill_id:
					already_owned = true
					break
				if existing_skill is Dictionary and str((existing_skill as Dictionary).get("id", "")) == skill_id:
					already_owned = true
					break
		if not already_owned:
			return {"id": skill_id, "tier": "Bronze"}
	return {"id": skill_ids[0], "tier": "Bronze"}

func _pick_item_reward(hero_type: HeroDataClass.HeroType, day: int) -> Dictionary:
	var item_ids: Array[String] = BazaarContentClass.get_hero_item_ids(hero_type)
	if item_ids.is_empty():
		return {}
	var rarity: int = get_max_shop_rarity_for_day(day)
	var item_id: String = item_ids[randi() % item_ids.size()]
	return {"id": item_id, "tier": _rarity_to_tier(rarity)}

func _pick_enchantment_for_day(day: int) -> String:
	if day >= 6:
		return "obsidian"
	if day >= 4:
		return "restorative"
	if day >= 2:
		return "toxic"
	return "fiery"

func _rarity_to_tier(rarity: int) -> String:
	match rarity:
		BazaarContentClass.RARITY_SILVER:
			return "Silver"
		BazaarContentClass.RARITY_GOLD:
			return "Gold"
		BazaarContentClass.RARITY_DIAMOND:
			return "Diamond"
	return "Bronze"
