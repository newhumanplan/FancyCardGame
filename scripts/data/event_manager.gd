class_name EventManager
extends RefCounted

const BazaarContentClass = preload("res://scripts/data/bazaar_content.gd")
const ItemDataClass = preload("res://scripts/data/item_data.gd")
const LinearInventoryClass = preload("res://scripts/data/linear_inventory.gd")
const HeroDataClass = preload("res://scripts/data/hero_data.gd")
const PassiveSkillDataClass = preload("res://scripts/data/passive_skill.gd")
const ItemAcquisitionClass = preload("res://scripts/data/item_acquisition.gd")

const IMPLEMENTED_EVENT_IDS: Array[String] = [
	"a_strange_mushroom", "abandoned_property", "aerodrome", "aldric", "armory",
	"artisan_dunes", "b1_b2", "battlefield", "bazaarcon", "block_party",
	"borrow", "botanical_gardens", "botul", "bounty_hunters_event",
	"cabin_fishing", "cache_of_riches", "candy_stash", "cinder_chase",
	"deadly_duel", "deep_sea_fishing", "dfleck", "dooleys_workshop",
	"eating_contest", "economic_seminar", "epic_battle", "extract_extract",
	"finns_big_bite", "flambe", "forja", "freezer", "furnace", "futura",
	"genie_lamp_event", "guard_locker", "gumball_machine_event", "haddy",
	"hospital", "house_party", "invest_in_yourself", "investment_pitch",
	"jules_cafe", "jungle_ruins", "likit", "look_for_spare_change",
	"lost_and_found", "mad_maddie", "mandala", "medicine_cabinet",
	"monster_ranch", "mountain_pass", "mysterious_portal", "obstacle_course",
	"pearls_dig_site", "procure_medkit", "pyre", "racetrack",
	"recycling_center", "regenerative_tincture", "relax", "scrap_salvage",
	"security_center", "sharpening_kit", "shrouded_figure", "snack_time",
	"start_of_run", "street_festival", "study", "the_artist", "the_cult",
	"the_docks", "the_lost_crate", "tiny_furry_monster", "treasure_chest",
	"utility_box", "workshop"
]

const REWARD_EVENT_RULES: Dictionary = {
	"abandoned_property": {"income": 1, "max_health": 20},
	"aerodrome": {"items": [{"id": "ornithopter", "tier": "Silver"}], "item_count": 1},
	"aldric": {"skills": [{"id": "product_showcase", "tier": "Gold"}], "skill_count": 1},
	"artisan_dunes": {"upgrade_leftmost": true, "gold": 2},
	"bazaarcon": {"skills": [{"id": "trader", "tier": "Gold"}], "skill_count": 1, "gold": 6},
	"block_party": {"max_health": 30, "heal": 30},
	"botul": {"items": [{"id": "noxious_potion", "tier": "Silver"}], "item_count": 1},
	"bounty_hunters_event": {"items": [{"id": "wanted_poster", "tier": "Gold"}], "item_count": 1},
	"cabin_fishing": {"items": [{"id": "catfish", "tier": "Bronze"}], "item_count": 1},
	"deadly_duel": {"items": [{"id": "revolver", "tier": "Silver"}], "item_count": 1, "prestige": 1},
	"deep_sea_fishing": {"items": [{"id": "pearl", "tier": "Gold"}, {"id": "pufferfish", "tier": "Gold"}], "item_count": 1},
	"dfleck": {"enchant_leftmost": "toxic", "gold": 4},
	"dooleys_workshop": {"items": [{"id": "dooltron", "tier": "Gold"}, {"id": "cog", "tier": "Gold"}], "item_count": 1},
	"eating_contest": {"max_health": 40, "heal": 40},
	"economic_seminar": {"income": 2, "gold": 4},
	"epic_battle": {"xp": 3, "prestige": 1},
	"flambe": {"items": [{"id": "flamberge", "tier": "Gold"}, {"id": "hot_sauce", "tier": "Gold"}], "item_count": 1},
	"forja": {"upgrade_leftmost": true, "enchant_leftmost": "fiery"},
	"freezer": {"items": [{"id": "ice_cubes", "tier": "Silver"}, {"id": "coolant", "tier": "Silver"}], "item_count": 1},
	"futura": {"heal": 60, "prestige": 1},
	"genie_lamp_event": {"items": [{"id": "genie_lamp", "tier": "Diamond"}], "item_count": 1},
	"haddy": {"skills": [{"id": "big_ego", "tier": "Gold"}], "skill_count": 1},
	"hospital": {"heal": 80, "max_health": 20},
	"investment_pitch": {"gold": 12, "income": 1},
	"jules_cafe": {"heal": 30, "items": [{"id": "chocolate_bar", "tier": "Silver"}], "item_count": 1},
	"likit": {"items": [{"id": "chocolate_bar", "tier": "Silver"}], "item_count": 1},
	"mad_maddie": {"items": [{"id": "mortar_pestle", "tier": "Gold"}, {"id": "powder_flask", "tier": "Gold"}], "item_count": 1},
	"mandala": {"enchant_leftmost": "restorative"},
	"monster_ranch": {"items": [{"id": "pelt", "tier": "Gold"}, {"id": "bear_claws", "tier": "Gold"}], "item_count": 1},
	"mountain_pass": {"xp": 2, "gold": 5},
	"mysterious_portal": {"items": [{"id": "magic_carpet", "tier": "Gold"}, {"id": "cosmic_amulet", "tier": "Gold"}], "item_count": 1},
	"pearls_dig_site": {"items": [{"id": "pearl", "tier": "Gold"}], "item_count": 1, "gold": 4},
	"pyre": {"enchant_leftmost": "fiery", "items": [{"id": "cinders", "tier": "Silver"}], "item_count": 1},
	"shrouded_figure": {"skills": [{"id": "ambush", "tier": "Gold"}], "skill_count": 1},
	"street_festival": {"gold": 8, "heal": 25},
	"the_artist": {"enchant_leftmost": "obsidian", "gold": 5},
	"the_cult": {"skills": [{"id": "ancient_vengeance", "tier": "Gold"}], "skill_count": 1},
	"workshop": {"upgrade_leftmost": true, "items": [{"id": "upgrade_hammer", "tier": "Silver"}], "item_count": 1}
}

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

func _build_service_vendor_option(day: int, excluded_ids: Dictionary = {}) -> Dictionary:
	var vendor: Dictionary = EconomyService.pick_service_vendor(day, excluded_ids)
	if vendor.is_empty():
		return {}
	var service_id: String = str(vendor.get("id", ""))
	var hero_type: HeroDataClass.HeroType = HeroStateService.selected_hero.hero_type if HeroStateService.selected_hero != null else HeroDataClass.HeroType.MAK
	return _build_option(str(vendor.get("name", "Service")), "service_vendor", "", {
		"service_id": service_id,
		"service_vendor_kind": str(vendor.get("kind", service_id)),
		"summary": str(vendor.get("summary", "")),
		"rarity": "Service",
		"reward": EconomyService.get_service_vendor_reward(service_id, day, hero_type),
	})

func _build_monster_option(spec: Dictionary, index: int, day: int) -> Dictionary:
	var monster_id: String = str(spec.get("id", ""))
	var metadata: Dictionary = BazaarContentClass.get_monster_encounter_metadata(monster_id, day)
	var summary: String = "Risk %d - %s" % [
		int(metadata.get("risk_score", day)),
		str(metadata.get("reward_summary", str(spec.get("tier", "Monster"))))
	]
	var option := _build_option(str(spec.get("name", "Monster")), "monster", "", {
		"monster_id": monster_id,
		"summary": summary,
		"rarity": str(spec.get("tier", "")),
		"risk_score": int(metadata.get("risk_score", day)),
		"risk_tags": metadata.get("risk_tags", []),
		"reward_tags": metadata.get("reward_tags", []),
		"reward_paths": metadata.get("reward_paths", []),
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

	var used_service_ids: Dictionary = {}
	var service_option: Dictionary = _build_service_vendor_option(day, used_service_ids)
	if not service_option.is_empty():
		used_service_ids[str(service_option.get("service_id", ""))] = true
		options.append(service_option)

	var used_event_ids: Dictionary = {}
	while options.size() < 3:
		var evt = _pick_random_event(day, used_event_ids)
		if evt.is_empty():
			var fallback_service: Dictionary = _build_service_vendor_option(day, used_service_ids)
			if fallback_service.is_empty():
				break
			used_service_ids[str(fallback_service.get("service_id", ""))] = true
			options.append(fallback_service)
			continue
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
	if REWARD_EVENT_RULES.has(event_id):
		return _execute_reward_event(event_id, REWARD_EVENT_RULES[event_id], game_manager, inventory, stash_inventory)
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
		"gumball_machine_event":
			return _grant_item_or_gold(BazaarContentClass.create_item("chocolate_bar", BazaarContentClass.RARITY_BRONZE), inventory, stash_inventory, game_manager, 0, "Gumball Machine: get a treat")
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
		"study":
			var xp_gain: int = 2 if day <= 3 else 3
			_add_xp(game_manager, xp_gain)
			return "Study: gained %d XP." % xp_gain
		"recycling_center":
			var recycled_item: ItemDataClass = _create_random_non_weapon_item(BazaarContentClass.RARITY_BRONZE, "")
			return _grant_item_or_gold(recycled_item, inventory, stash_inventory, game_manager, 0, "Recycling Center: get a non-Weapon item")
		"scrap_salvage":
			return _grant_item_or_gold(BazaarContentClass.create_item("scrap", BazaarContentClass.RARITY_BRONZE), inventory, stash_inventory, game_manager, 0, "Scrap Salvage: get Scrap")
		"security_center":
			_grant_skill(game_manager, {"id": "toughness", "tier": "Bronze"})
			return "Security Center: gained the Toughness skill."
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
		"the_docks":
			var dock_damage: int = 10
			var dock_gold: int = 5 if day <= 4 else 7
			if game_manager.has_method("take_damage"):
				game_manager.take_damage(dock_damage)
			game_manager.add_gold(dock_gold)
			return "The Docks: took %d damage and earned %d Gold." % [dock_damage, dock_gold]
		"tiny_furry_monster":
			game_manager.add_max_health(25)
			return "Tiny Furry Monster: gained 25 Max Health."
		"treasure_chest":
			var treasure_item: ItemDataClass = BazaarContentClass.create_random_hero_item(hero_type, BazaarContentClass.RARITY_BRONZE, "", "", true)
			return _grant_item_or_gold(treasure_item, inventory, stash_inventory, game_manager, 0, "Treasure Chest: get an item")
		"utility_box":
			return _grant_item_or_gold(BazaarContentClass.create_item("scrap", BazaarContentClass.RARITY_BRONZE), inventory, stash_inventory, game_manager, 0, "Utility Box: get a small Tool component")
		"start_of_run":
			game_manager.add_gold(3)
			game_manager.add_income(1)
			_grant_skill(game_manager, {"id": "keen_eye", "tier": "Bronze"})
			return "Start of Run: gained 3 Gold, 1 Income, and a starter Skill."

		_:
			return _unsupported_event_result(event_id)

func get_event_gameplay_coverage_report() -> Dictionary:
	var implemented: Array[String] = []
	var unsupported: Array[Dictionary] = []
	var total: int = 0
	for spec in _random_events:
		var event_id: String = str(spec.get("id", ""))
		if event_id.is_empty():
			continue
		total += 1
		if IMPLEMENTED_EVENT_IDS.has(event_id):
			implemented.append(event_id)
		else:
			unsupported.append({"id": event_id, "name": str(spec.get("name", event_id)), "reason": _unsupported_event_reason(event_id)})
	return {
		"total": total,
		"implemented_total": implemented.size(),
		"unsupported_total": unsupported.size(),
		"implemented_ids": implemented,
		"unsupported": unsupported,
	}

func execute_service_vendor(service_id: String, day: int, game_manager: Node, inventory: LinearInventoryClass = null, stash_inventory: LinearInventoryClass = null) -> String:
	if game_manager == null:
		return "Service failed: GameManager missing."
	var hero_type: HeroDataClass.HeroType = game_manager.selected_hero.hero_type if game_manager.selected_hero != null else HeroDataClass.HeroType.MAK
	var reward: Dictionary = EconomyService.get_service_vendor_reward(service_id, day, hero_type)
	if reward.is_empty():
		return "Unsupported service vendor %s: no reward registered." % service_id
	var summary: Dictionary = RewardService.apply_reward(reward, "service_vendor:%s" % service_id, inventory, stash_inventory)
	return "Service vendor %s: %s" % [service_id, _describe_reward_summary(summary)]

## 获取所有注册的随机事件列表（用于 UI 展示或调试）
func get_all_events() -> Array[Dictionary]:
	return _random_events.duplicate(true)

## 获取事件总数
func get_event_count() -> int:
	return _random_events.size()

func _execute_reward_event(event_id: String, reward: Dictionary, game_manager: Node, inventory: LinearInventoryClass, stash_inventory: LinearInventoryClass) -> String:
	var summary: Dictionary = {}
	if game_manager == GameManager:
		summary = RewardService.apply_reward(reward, "event:%s" % event_id, inventory, stash_inventory)
	else:
		summary = _apply_reward_to_external_manager(reward, event_id, game_manager, inventory, stash_inventory)
	return "%s: %s" % [_event_display_name(event_id), _describe_reward_summary(summary)]

func _apply_reward_to_external_manager(reward: Dictionary, event_id: String, game_manager: Node, inventory: LinearInventoryClass, stash_inventory: LinearInventoryClass) -> Dictionary:
	var summary: Dictionary = {
		"source": "event:%s" % event_id,
		"gold": 0,
		"income": 0,
		"xp": 0,
		"max_health": 0,
		"heal": 0,
		"prestige": 0,
		"items": [],
		"item_failures": [],
		"skills": [],
		"skill_failures": [],
		"upgrades": [],
		"upgrade_failures": [],
		"enchantments": [],
		"enchant_failures": [],
	}
	var gold_amount: int = int(reward.get("gold", 0))
	if gold_amount != 0 and game_manager.has_method("add_gold"):
		game_manager.add_gold(gold_amount)
		summary["gold"] = gold_amount
	var income_amount: int = int(reward.get("income", 0))
	if income_amount != 0 and game_manager.has_method("add_income"):
		game_manager.add_income(income_amount)
		summary["income"] = income_amount
	var xp_amount: int = int(reward.get("xp", 0))
	if xp_amount > 0:
		_add_xp(game_manager, xp_amount)
		summary["xp"] = xp_amount
	var max_health_amount: int = int(reward.get("max_health", 0))
	if max_health_amount > 0 and game_manager.has_method("add_max_health"):
		game_manager.add_max_health(max_health_amount)
		summary["max_health"] = max_health_amount
	var heal_amount: int = int(reward.get("heal", 0))
	if heal_amount > 0 and game_manager.has_method("heal"):
		game_manager.heal(heal_amount)
		summary["heal"] = heal_amount
	var prestige_amount: int = int(reward.get("prestige", 0))
	if prestige_amount > 0 and game_manager.has_method("add_prestige"):
		game_manager.add_prestige(prestige_amount)
		summary["prestige"] = prestige_amount
	_apply_external_item_rewards(reward, summary, inventory, stash_inventory)
	_apply_external_skill_rewards(reward, summary, game_manager)
	if bool(reward.get("upgrade_leftmost", false)):
		if _upgrade_first_bronze_item(inventory):
			summary["upgrades"].append({"target": "leftmost_bronze"})
		else:
			summary["upgrade_failures"].append({"reason": "no_upgrade_target"})
	if not str(reward.get("enchant_leftmost", "")).is_empty():
		summary["enchantments"].append({"enchantment": str(reward.get("enchant_leftmost", "")), "target": "leftmost_available"})
	return summary

func _apply_external_item_rewards(reward: Dictionary, summary: Dictionary, inventory: LinearInventoryClass, stash_inventory: LinearInventoryClass) -> void:
	var item_refs: Array = []
	for key in ["item_id", "item_ids", "item_pool", "items"]:
		if not reward.has(key):
			continue
		var value: Variant = reward[key]
		if value is Array:
			item_refs.append_array(value)
		else:
			item_refs.append(value)
	var item_count: int = maxi(int(reward.get("item_count", 1)), 1)
	var granted: int = 0
	for item_ref in item_refs:
		if granted >= item_count:
			break
		var item_id: String = str(item_ref.get("id", "") if item_ref is Dictionary else item_ref).strip_edges().to_lower()
		if item_id.is_empty():
			continue
		var tier: String = str(item_ref.get("tier", "Bronze") if item_ref is Dictionary else "Bronze")
		var item: ItemDataClass = BazaarContentClass.create_item(item_id, _tier_to_rarity(tier))
		if item == null:
			summary["item_failures"].append({"id": item_id, "reason": "unknown_item"})
			continue
		if _grant_item(item, inventory, stash_inventory):
			summary["items"].append({"id": item.source_id, "name": item.item_name})
			granted += 1
		else:
			summary["item_failures"].append({"id": item_id, "reason": "inventory_full"})

func _apply_external_skill_rewards(reward: Dictionary, summary: Dictionary, game_manager: Node) -> void:
	var skill_refs: Array = []
	for key in ["skill_id", "skill_ids", "skill_pool", "skills"]:
		if not reward.has(key):
			continue
		var value: Variant = reward[key]
		if value is Array:
			skill_refs.append_array(value)
		else:
			skill_refs.append(value)
	var skill_count: int = maxi(int(reward.get("skill_count", 1)), 1)
	var granted: int = 0
	for skill_ref in skill_refs:
		if granted >= skill_count:
			break
		var skill_id: String = str(skill_ref.get("id", "") if skill_ref is Dictionary else skill_ref).strip_edges().to_lower()
		if skill_id.is_empty():
			continue
		if _grant_skill(game_manager, {"id": skill_id}):
			summary["skills"].append({"id": skill_id})
			granted += 1
		else:
			summary["skill_failures"].append({"id": skill_id, "reason": "duplicate_or_missing_hero"})

func _tier_to_rarity(tier: String) -> int:
	match tier:
		"Silver", "silver":
			return BazaarContentClass.RARITY_SILVER
		"Gold", "gold":
			return BazaarContentClass.RARITY_GOLD
		"Diamond", "diamond":
			return BazaarContentClass.RARITY_DIAMOND
	return BazaarContentClass.RARITY_BRONZE

func _event_display_name(event_id: String) -> String:
	var spec: Dictionary = BazaarContentClass.find_event_spec(event_id)
	return str(spec.get("name", event_id))

func _describe_reward_summary(summary: Dictionary) -> String:
	var parts: Array[String] = []
	if int(summary.get("gold", 0)) != 0:
		parts.append("%d Gold" % int(summary.get("gold", 0)))
	if int(summary.get("income", 0)) != 0:
		parts.append("%d Income" % int(summary.get("income", 0)))
	if int(summary.get("heal", 0)) != 0:
		parts.append("%d Heal" % int(summary.get("heal", 0)))
	if int(summary.get("xp", 0)) != 0:
		parts.append("%d XP" % int(summary.get("xp", 0)))
	if not (summary.get("items", []) as Array).is_empty():
		parts.append("item reward")
	if not (summary.get("skills", []) as Array).is_empty():
		parts.append("skill reward")
	if not (summary.get("upgrades", []) as Array).is_empty():
		parts.append("upgrade")
	if not (summary.get("enchantments", []) as Array).is_empty():
		parts.append("enchantment")
	if parts.is_empty():
		return "no applicable target"
	return ", ".join(parts)

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

func _grant_skill(game_manager: Node, skill_ref: Dictionary) -> bool:
	if game_manager == null or game_manager.selected_hero == null:
		return false
	var skill_id: String = str(skill_ref.get("id", ""))
	if skill_id.is_empty():
		return false
	for existing in game_manager.selected_hero.skills:
		if existing is Dictionary and str((existing as Dictionary).get("id", "")) == skill_id:
			return false
		if str(existing) == skill_id:
			return false
	game_manager.selected_hero.skills.append(skill_id)
	return true

func _add_xp(game_manager: Node, amount: int) -> void:
	if game_manager.has_method("add_xp"):
		game_manager.add_xp(amount)
	elif game_manager.has_method("apply_reward"):
		game_manager.apply_reward({"xp": amount}, "event")

func _unsupported_event_result(event_id: String) -> String:
	var message: String = "Unsupported event %s: %s" % [event_id, _unsupported_event_reason(event_id)]
	push_warning(message)
	return message

func _unsupported_event_reason(event_id: String) -> String:
	var spec: Dictionary = BazaarContentClass.find_event_spec(event_id)
	if spec.has("enabled") and not bool(spec.get("enabled")):
		return "event is disabled in the source catalog; no gameplay effect is registered."
	var summary: String = str(spec.get("summary", "")).to_lower()
	var occurrence: String = str(spec.get("occurrence", "")).to_lower()
	if summary.find("special") >= 0 or occurrence.find("sell") >= 0 or occurrence.find("drop") >= 0 or occurrence.find("prestige") >= 0:
		return "special-trigger event needs a dedicated trigger path before runtime execution."
	if summary.find("uncertain") >= 0 or occurrence.find("?") >= 0:
		return "source timing/effect is uncertain; left explicit instead of guessing."
	if str(spec.get("rarity", "")) in ["Diamond", "Legendary"]:
		return "late high-rarity event needs exact effect confirmation before gameplay mapping."
	return "no gameplay effect registered; generic fallback intentionally did nothing."

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
