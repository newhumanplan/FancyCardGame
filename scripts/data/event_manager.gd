class_name EventManager
extends RefCounted

const BazaarContentClass = preload("res://scripts/data/bazaar_content.gd")
const ItemDataClass = preload("res://scripts/data/item_data.gd")
const LinearInventoryClass = preload("res://scripts/data/linear_inventory.gd")
const HeroDataClass = preload("res://scripts/data/hero_data.gd")
const PassiveSkillDataClass = preload("res://scripts/data/passive_skill.gd")
const ItemAcquisitionClass = preload("res://scripts/data/item_acquisition.gd")

## 事件管理器 — 管理事件注册、随机选择、效果执行
## 将 main.gd 中硬编码的事件逻辑提取到此模块

## 事件执行回调类型（由 main.gd 注入）
## 回调签名: func(event_type: String) -> void
var event_callback: Callable

## ============ 随机事件定义 ============

## 随机事件列表（ID, 名称, 图标, 权重）
var _random_events: Array[Dictionary] = BazaarContentClass.get_all_event_specs()

func _build_option(text: String, option_type: String, event_id: String = "", metadata: Dictionary = {}) -> Dictionary:
	var option := {"text": text, "type": option_type}
	if not event_id.is_empty():
		option["event_id"] = event_id
	for key in metadata.keys():
		option[key] = metadata[key]
	return option

func _build_event_option(evt: Dictionary) -> Dictionary:
	var event_id: String = str(evt.get("id", ""))
	return _build_option(str(evt.get("name", "Event")), "random_event", event_id, {
		"summary": str(evt.get("summary", "")),
		"rarity": str(evt.get("rarity", "")),
		"art_path": BazaarContentClass.get_event_art_path(event_id),
	})

func _build_merchant_option(day: int) -> Dictionary:
	var merchants: Array[Dictionary] = BazaarContentClass.get_day1_merchants()
	if merchants.is_empty():
		return _build_option("Merchant", "shop")
	var merchant: Dictionary = merchants.pick_random()
	var merchant_id: String = str(merchant.get("id", ""))
	return _build_option(str(merchant.get("name", "Merchant")), "shop", "", {
		"merchant_id": merchant_id,
		"merchant_type": str(merchant.get("type", "")),
		"summary": str(merchant.get("summary", "")),
		"rarity": str(merchant.get("starting_tier", "")),
		"art_path": BazaarContentClass.get_merchant_art_path(merchant_id),
	})

func _build_monster_option(spec: Dictionary, index: int, day: int) -> Dictionary:
	var monster_id: String = str(spec.get("id", ""))
	var option := _build_option(str(spec.get("name", "Monster")), "monster", "", {
		"monster_id": monster_id,
		"summary": str(spec.get("tier", "Monster")),
		"rarity": str(spec.get("tier", "")),
	})
	option["encounter_index"] = index
	option["day"] = day
	return option

## ============ 事件选项生成 ============

## 生成事件选项列表（替代 main.gd 中的 _generate_event_options）
## 返回最多3个选项字典: [{"text": "...", "icon": "...", "type": "..."}]
func generate_options(hour: int, day: int) -> Array[Dictionary]:
	if PhaseService.is_pvp_phase(hour):
		return [_build_option("⚔️ PvP 对战", "pvp")]

	if PhaseService.is_pve_phase(hour):
		var monsters: Array[Dictionary] = BazaarContentClass.get_monster_specs_for_day(day)
		if monsters.is_empty():
			monsters = BazaarContentClass.get_day1_monster_specs()
		monsters.shuffle()
		var monster_options: Array[Dictionary] = []
		for i in range(mini(3, monsters.size())):
			monster_options.append(_build_monster_option(monsters[i], i + 1, day))
		return monster_options

	var options: Array[Dictionary] = []
	options.append(_build_merchant_option(day))

	var used_event_ids: Dictionary = {}
	while options.size() < 3:
		var evt = _pick_random_event(day, used_event_ids)
		if evt.is_empty():
			break
		var event_id: String = str(evt.get("id", ""))
		used_event_ids[event_id] = true
		options.append(_build_event_option(evt))

	options.shuffle()
	return options

## 按权重随机选择一个随机事件
func _pick_random_event(day: int, excluded_ids: Dictionary = {}) -> Dictionary:
	# 过滤掉不符合天数要求的事件
	var eligible: Array[Dictionary] = []
	for evt in _random_events:
		var event_id: String = str(evt.get("id", ""))
		if excluded_ids.has(event_id):
			continue
		var min_day: int = int(evt.get("min_day", 0))
		var max_day: int = int(evt.get("max_day", 0))
		if day < min_day:
			continue
		if max_day > 0 and day > max_day:
			continue
		eligible.append(evt)

	if eligible.is_empty():
		return {}

	# 按权重随机
	var total_weight: int = 0
	for evt in eligible:
		total_weight += evt.get("weight", 10)

	if total_weight <= 0:
		return eligible[0]
	var roll: int = randi() % total_weight
	var cumulative: int = 0
	for evt in eligible:
		cumulative += evt.get("weight", 10)
		if roll < cumulative:
			return evt

	return eligible[0]

## ============ 事件效果执行 ============

## 执行随机事件效果（返回描述文本）
## game_manager: GameManager autoload 引用
func execute_random_event(event_id: String, day: int, game_manager: Node, inventory: LinearInventoryClass = null, stash_inventory: LinearInventoryClass = null) -> String:
	if game_manager == null:
		return "事件执行失败: GameManager 不存在"
	var hero_type: HeroDataClass.HeroType = game_manager.selected_hero.hero_type if game_manager.selected_hero != null else HeroDataClass.HeroType.MAK
	match event_id:
		"a_strange_mushroom":
			var potion: ItemDataClass = BazaarContentClass.create_random_hero_item(hero_type, BazaarContentClass.RARITY_SILVER, "Small", "Potion", true)
			return _grant_item_or_gold(potion, inventory, stash_inventory, game_manager, 4, "A Strange Mushroom: Mak brew a small Silver-tier Potion")
		"armory":
			var weapon: ItemDataClass = BazaarContentClass.create_random_hero_item(hero_type, BazaarContentClass.RARITY_BRONZE, "", "Weapon", true)
			return _grant_item_or_gold(weapon, inventory, stash_inventory, game_manager, 0, "Armory: get a free Weapon")
		"b1_b2":
			if _upgrade_first_bronze_item(inventory):
				return "B1&B2: upgraded 1 Bronze-tier item."
			return "B1&B2: no Bronze item to upgrade."
		"battlefield":
			var small_weapon: ItemDataClass = BazaarContentClass.create_random_hero_item(hero_type, BazaarContentClass.RARITY_BRONZE, "Small", "Weapon", true)
			if small_weapon == null:
				small_weapon = BazaarContentClass.create_item("old_sword", BazaarContentClass.RARITY_BRONZE)
			return _grant_item_or_gold(small_weapon, inventory, stash_inventory, game_manager, 0, "Battlefield: get a free small Weapon")
		"borrow":
			game_manager.add_income(-1)
			var borrow_gold: int = 8 if day <= 2 else (7 if day <= 4 else 6)
			game_manager.add_gold(borrow_gold)
			return "Borrow: lost 1 Income and gained %d Gold." % borrow_gold
		"botanical_gardens":
			var poison_item: ItemDataClass = BazaarContentClass.create_random_hero_item(hero_type, BazaarContentClass.RARITY_BRONZE, "", "Poison", true)
			return _grant_item_or_gold(poison_item, inventory, stash_inventory, game_manager, 0, "Botanical Gardens: get a free Poison item")
		"cache_of_riches":
			var cache_gold: int = 3 if day <= 2 else (4 if day <= 4 else 5)
			game_manager.add_gold(cache_gold)
			return "Cache of Riches: gained %d Gold." % cache_gold
		"candy_stash":
			var granted: int = 0
			for i in range(3):
				if _grant_item(BazaarContentClass.create_item("chocolate_bar", BazaarContentClass.RARITY_BRONZE), inventory, stash_inventory):
					granted += 1
			return "Candy Stash: gained %d Chocolate Bar(s)." % granted
		"cinder_chase":
			return _grant_item_or_gold(BazaarContentClass.create_item("cinders", BazaarContentClass.RARITY_BRONZE), inventory, stash_inventory, game_manager, 0, "Cinder Chase: get Cinders")
		"extract_extract":
			return _grant_item_or_gold(BazaarContentClass.create_item("extract", BazaarContentClass.RARITY_BRONZE), inventory, stash_inventory, game_manager, 0, "Extract Extract: get Extract")
		"finns_big_bite":
			var bite_health: int = maxi(int(game_manager.level), 1) * 20
			game_manager.add_max_health(bite_health)
			return "Finn's Big Bite: gained %d Max Health." % bite_health
		"furnace":
			var burn_item: ItemDataClass = BazaarContentClass.create_random_hero_item(hero_type, BazaarContentClass.RARITY_BRONZE, "Small", "Burn", true)
			return _grant_item_or_gold(burn_item, inventory, stash_inventory, game_manager, 0, "Furnace: get a small Burn item")
		"guard_locker":
			var shield_item: ItemDataClass = BazaarContentClass.create_random_hero_item(hero_type, BazaarContentClass.RARITY_BRONZE, "Small", "Shield", true)
			return _grant_item_or_gold(shield_item, inventory, stash_inventory, game_manager, 0, "Guard Locker: get a small Shield item")
		"house_party":
			var friend_item: ItemDataClass = BazaarContentClass.create_random_hero_item(hero_type, BazaarContentClass.RARITY_BRONZE, "Small", "Friend", true)
			return _grant_item_or_gold(friend_item, inventory, stash_inventory, game_manager, 0, "House Party: get a small Friend")
		"invest_in_yourself":
			var income_gain: int = 1 if day <= 3 else 2
			game_manager.add_income(income_gain)
			return "Invest in Yourself: gained %d Income." % income_gain
		"jungle_ruins":
			var reagent: ItemDataClass = BazaarContentClass.create_random_hero_item(hero_type, BazaarContentClass.RARITY_SILVER, "", "Reagent", true)
			return _grant_item_or_gold(reagent, inventory, stash_inventory, game_manager, 0, "Jungle Ruins: hunted for a Silver Reagent")
		"look_for_spare_change":
			game_manager.add_gold(3)
			return "Look for Spare Change: gained 3 Gold."
		"lost_and_found":
			var lost_item: ItemDataClass = _create_random_non_weapon_item(BazaarContentClass.RARITY_BRONZE, "Small")
			return _grant_item_or_gold(lost_item, inventory, stash_inventory, game_manager, 0, "Lost and Found: get a small non-Weapon item")
		"medicine_cabinet":
			var medicine: ItemDataClass = _create_random_tag_item(["Heal", "Regen"], BazaarContentClass.RARITY_BRONZE, "Small")
			return _grant_item_or_gold(medicine, inventory, stash_inventory, game_manager, 0, "Medicine Cabinet: get a small Heal or Regen item")
		"obstacle_course":
			var slow_item: ItemDataClass = BazaarContentClass.create_random_hero_item(hero_type, BazaarContentClass.RARITY_BRONZE, "", "Slow", true)
			return _grant_item_or_gold(slow_item, inventory, stash_inventory, game_manager, 0, "Obstacle Course: get a Slow item")
		"procure_medkit":
			return _grant_item_or_gold(BazaarContentClass.create_item("med_kit", BazaarContentClass.RARITY_BRONZE), inventory, stash_inventory, game_manager, 0, "Procure Medkit: get Med Kit")
		"racetrack":
			var haste_item: ItemDataClass = BazaarContentClass.create_item("smelling_salts", BazaarContentClass.RARITY_BRONZE)
			return _grant_item_or_gold(haste_item, inventory, stash_inventory, game_manager, 0, "Racetrack: get a Haste item")
		"regenerative_tincture":
			var regen_item: ItemDataClass = BazaarContentClass.create_random_hero_item(hero_type, BazaarContentClass.RARITY_BRONZE, "Small", "Regen", true)
			return _grant_item_or_gold(regen_item, inventory, stash_inventory, game_manager, 0, "Regenerative Tincture: get a Regen item")
		"relax":
			var shield_value: int = 100 * maxi(int(game_manager.level), 1)
			_add_combat_shield_skill(game_manager, shield_value)
			return "Relax: next fights start with %d Shield." % shield_value
		"recycling_center":
			var recycled_item: ItemDataClass = _create_random_non_weapon_item(BazaarContentClass.RARITY_BRONZE, "")
			return _grant_item_or_gold(recycled_item, inventory, stash_inventory, game_manager, 0, "Recycling Center: get a non-Weapon item")
		"scrap_salvage":
			return _grant_item_or_gold(BazaarContentClass.create_item("scrap", BazaarContentClass.RARITY_BRONZE), inventory, stash_inventory, game_manager, 0, "Scrap Salvage: get Scrap")
		"sharpening_kit":
			var damage_item: ItemDataClass = BazaarContentClass.create_random_hero_item(hero_type, BazaarContentClass.RARITY_BRONZE, "Small", "Damage", true)
			return _grant_item_or_gold(damage_item, inventory, stash_inventory, game_manager, 0, "Sharpening Kit: get a small Damage item")
		"snack_time":
			var snack_health: int = 20 * maxi(int(game_manager.level), 1)
			game_manager.add_max_health(snack_health)
			return "Snack Time: gained %d Max Health." % snack_health
		"the_lost_crate":
			var medium_item: ItemDataClass = BazaarContentClass.create_random_hero_item(hero_type, BazaarContentClass.RARITY_BRONZE, "Medium", "", true)
			return _grant_item_or_gold(medium_item, inventory, stash_inventory, game_manager, 0, "The Lost Crate: opened for a Medium item")
		"tiny_furry_monster":
			game_manager.add_max_health(25)
			return "Tiny Furry Monster: gained 25 Max Health."
		"treasure_chest":
			var treasure_item: ItemDataClass = BazaarContentClass.create_random_hero_item(hero_type, BazaarContentClass.RARITY_BRONZE, "", "", true)
			return _grant_item_or_gold(treasure_item, inventory, stash_inventory, game_manager, 0, "Treasure Chest: get an item")

		_:
			return "未知事件!"

## 获取所有注册的随机事件列表（用于 UI 展示或调试）
func get_all_events() -> Array[Dictionary]:
	return _random_events.duplicate(true)

## 获取事件总数
func get_event_count() -> int:
	return _random_events.size()

func _grant_item_or_gold(item: ItemDataClass, inventory: LinearInventoryClass, stash_inventory: LinearInventoryClass, game_manager: Node, fallback_gold: int, message: String) -> String:
	if _grant_item(item, inventory, stash_inventory):
		return "%s: gained %s." % [message, item.item_name]
	if fallback_gold > 0:
		game_manager.add_gold(fallback_gold)
		return "%s: inventory full, gained %d Gold instead." % [message, fallback_gold]
	return "%s: inventory full." % message

func _grant_item(item: ItemDataClass, inventory: LinearInventoryClass, stash_inventory: LinearInventoryClass = null) -> bool:
	if item == null or inventory == null:
		return false
	item.slot_index = -1
	var result: Dictionary = ItemAcquisitionClass.grant_item(item, inventory, stash_inventory, false)
	return bool(result.get("success", false))

func _create_random_non_weapon_item(rarity: int, required_size: String = "") -> ItemDataClass:
	var candidates: Array[ItemDataClass] = []
	for item_id in _mak_event_item_ids():
		var item: ItemDataClass = BazaarContentClass.create_item(item_id, rarity)
		if item == null:
			continue
		if item.type == ItemDataClass.Type.WEAPON:
			continue
		if not _matches_required_size(item, required_size):
			continue
		candidates.append(item)
	return null if candidates.is_empty() else candidates.pick_random()

func _create_random_tag_item(required_tags: Array[String], rarity: int, required_size: String = "") -> ItemDataClass:
	var candidates: Array[ItemDataClass] = []
	for item_id in _mak_event_item_ids():
		var item: ItemDataClass = BazaarContentClass.create_item(item_id, rarity)
		if item == null:
			continue
		if not _matches_required_size(item, required_size):
			continue
		for required_tag in required_tags:
			if _item_has_tag(item, required_tag):
				candidates.append(item)
				break
	return null if candidates.is_empty() else candidates.pick_random()

func _matches_required_size(item: ItemDataClass, required_size: String) -> bool:
	if item == null or required_size.is_empty():
		return true
	match required_size:
		"Small":
			return item.size == ItemDataClass.Size.SMALL
		"Medium":
			return item.size == ItemDataClass.Size.MEDIUM
		"Large":
			return item.size == ItemDataClass.Size.LARGE
	return true

func _item_has_tag(item: ItemDataClass, required_tag: String) -> bool:
	if item == null:
		return false
	for tag in item.tags:
		if str(tag).to_lower() == required_tag.to_lower():
			return true
	return false

func _mak_event_item_ids() -> Array[String]:
	return [
		"aludel", "calcinator", "candles", "catalyst", "emerald", "fire_potion",
		"fireflies", "fungal_spores", "hourglass", "incense", "mortar_pestle",
		"mothmeal", "myrrh", "nightshade", "noxious_potion", "philosophers_stone",
		"potion_potion", "quill_and_ink", "retort", "ruby", "smelling_salts",
		"sulphur", "venom", "venomander", "venomous_dose", "bluenanas",
		"chocolate_bar", "cinders", "duct_tape", "eagle_talisman", "extract",
		"gland", "insect_wing", "med_kit", "pelt", "scrap", "silk_scarf"
	]

func _upgrade_first_bronze_item(inventory: LinearInventoryClass) -> bool:
	if inventory == null:
		return false
	for item in inventory.items:
		if item == null:
			continue
		if item.rarity == BazaarContentClass.RARITY_BRONZE:
			BazaarContentClass.apply_rarity_to_item(item, BazaarContentClass.RARITY_SILVER)
			inventory.inventory_changed.emit()
			return true
	return false

func _add_combat_shield_skill(game_manager: Node, shield_value: int) -> void:
	if game_manager.selected_hero == null:
		return
	var skill := PassiveSkillDataClass.new()
	skill.skill_name = "Relax"
	skill.description = "Start combat with Shield from the Relax event."
	skill.effect_type = PassiveSkillDataClass.EffectType.SHIELD_BONUS
	skill.effect_value = float(shield_value)
	game_manager.selected_hero.passive_skills.append(skill)
	PassiveSkillDataClass.apply_to_hero(skill, game_manager.selected_hero)
