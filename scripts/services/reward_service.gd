extends Node

## RewardService - run reward application gateway.
## Stateless by design: authoritative values live in EconomyService,
## HeroStateService, and RunStateService.

const BazaarContentClass = preload("res://scripts/data/bazaar_content.gd")
const ItemAcquisitionClass = preload("res://scripts/data/item_acquisition.gd")
const LinearInventoryClass = preload("res://scripts/data/linear_inventory.gd")
const PlayerSkillCatalogClass = preload("res://scripts/data/player_skill_catalog.gd")

signal reward_applied(summary: Dictionary)
signal level_reward_applied(level: int, reward: Dictionary, summary: Dictionary)

const DEFAULT_LEVEL_REWARDS: Dictionary = {
	2: {"max_health": 5, "income": 1},
	3: {"max_health": 10, "gold": 3},
	4: {"max_health": 10, "income": 1},
	5: {"max_health": 15, "gold": 5},
}

func apply_reward(
	reward: Dictionary,
	source: String = "",
	primary_inventory: LinearInventoryClass = null,
	secondary_inventory: LinearInventoryClass = null
) -> Dictionary:
	var summary: Dictionary = _new_summary(source)
	if reward.is_empty():
		return summary

	_apply_immediate_reward(reward, summary, primary_inventory, secondary_inventory)

	var xp_amount: int = int(reward.get("xp", 0))
	if xp_amount > 0:
		var xp_result: Dictionary = HeroStateService.add_xp(xp_amount)
		summary["xp"] = int(summary.get("xp", 0)) + xp_amount
		summary["xp_result"] = xp_result
		for level_value in xp_result.get("levels_gained", []):
			var level_reward: Dictionary = get_level_reward(int(level_value))
			if level_reward.is_empty():
				continue
			var level_summary: Dictionary = _new_summary("level_%d" % int(level_value))
			_apply_immediate_reward(level_reward, level_summary, primary_inventory, secondary_inventory)
			summary["level_rewards"].append({
				"level": int(level_value),
				"reward": level_reward,
				"summary": level_summary,
			})
			level_reward_applied.emit(int(level_value), level_reward, level_summary)

	reward_applied.emit(summary)
	return summary

func get_level_reward(level: int) -> Dictionary:
	if DEFAULT_LEVEL_REWARDS.has(level):
		return DEFAULT_LEVEL_REWARDS[level].duplicate(true)
	if level <= 1:
		return {}
	if level % 2 == 0:
		return {"max_health": 10, "income": 1}
	return {"max_health": 5, "gold": 5}

func _new_summary(source: String) -> Dictionary:
	return {
		"source": source,
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
		"level_rewards": [],
	}

func _apply_immediate_reward(
	reward: Dictionary,
	summary: Dictionary,
	primary_inventory: LinearInventoryClass = null,
	secondary_inventory: LinearInventoryClass = null
) -> void:
	var gold_amount: int = int(reward.get("gold", 0))
	if gold_amount > 0:
		EconomyService.add_gold(gold_amount)
		GameManager.record_gold_earned(gold_amount)
		summary["gold"] = int(summary.get("gold", 0)) + gold_amount

	var income_amount: int = int(reward.get("income", 0))
	if income_amount != 0:
		EconomyService.add_income(income_amount)
		summary["income"] = int(summary.get("income", 0)) + income_amount

	var max_health_amount: int = int(reward.get("max_health", 0))
	if max_health_amount > 0:
		var applied_health: int = HeroStateService.add_max_health(max_health_amount)
		summary["max_health"] = int(summary.get("max_health", 0)) + applied_health

	var heal_amount: int = int(reward.get("heal", 0))
	if heal_amount > 0:
		HeroStateService.heal(heal_amount)
		summary["heal"] = int(summary.get("heal", 0)) + heal_amount

	var prestige_amount: int = int(reward.get("prestige", 0))
	if prestige_amount > 0:
		RunStateService.add_prestige(prestige_amount)
		summary["prestige"] = int(summary.get("prestige", 0)) + prestige_amount

	_apply_item_rewards(reward, summary, primary_inventory, secondary_inventory)
	_apply_skill_rewards(reward, summary)

func _apply_item_rewards(
	reward: Dictionary,
	summary: Dictionary,
	primary_inventory: LinearInventoryClass,
	secondary_inventory: LinearInventoryClass
) -> void:
	var item_refs: Array = _reward_refs(reward, ["item_id", "item_ids", "item_pool", "items"])
	if item_refs.is_empty():
		return
	var item_count: int = maxi(int(reward.get("item_count", 1)), 1)
	var granted: int = 0
	for item_ref in item_refs:
		if granted >= item_count:
			break
		var item_id: String = _reward_ref_id(item_ref, "item_id")
		if item_id.is_empty():
			continue
		var rarity: int = _reward_ref_rarity(item_ref)
		var item = BazaarContentClass.create_item(item_id, rarity)
		if item == null:
			summary["item_failures"].append({"id": item_id, "reason": "unknown_item"})
			continue
		var grant_result: Dictionary = ItemAcquisitionClass.grant_item(item, primary_inventory, secondary_inventory, true)
		if bool(grant_result.get("success", false)):
			summary["items"].append({
				"id": item.source_id,
				"name": item.item_name,
				"rarity": item.rarity,
				"placed": bool(grant_result.get("placed", false)),
				"merged": bool(grant_result.get("merged", false)),
			})
			granted += 1
		else:
			summary["item_failures"].append({"id": item_id, "reason": "inventory_full"})

func _apply_skill_rewards(reward: Dictionary, summary: Dictionary) -> void:
	var skill_refs: Array = _reward_refs(reward, ["skill_id", "skill_ids", "skill_pool", "skills"])
	if skill_refs.is_empty():
		return
	var hero = HeroStateService.selected_hero
	if hero == null:
		summary["skill_failures"].append({"reason": "no_selected_hero"})
		return
	var skill_count: int = maxi(int(reward.get("skill_count", 1)), 1)
	var granted: int = 0
	for skill_ref in skill_refs:
		if granted >= skill_count:
			break
		var skill_id: String = _reward_ref_id(skill_ref, "skill_id")
		if skill_id.is_empty():
			continue
		var resolved: Dictionary = PlayerSkillCatalogClass.normalize_skill_ref(skill_ref)
		if _hero_has_skill(hero.skills, skill_id):
			summary["skill_failures"].append({"id": skill_id, "reason": "duplicate"})
			continue
		var stored_ref: Dictionary = {
			"id": str(resolved.get("id", skill_id)),
			"tier": str(resolved.get("tier", _reward_ref_tier(skill_ref))),
		}
		hero.skills.append(stored_ref["id"])
		summary["skills"].append({
			"id": stored_ref["id"],
			"name": str(resolved.get("name", stored_ref["id"])),
			"tier": stored_ref["tier"],
			"support_status": str(resolved.get("support_status", "unknown")),
		})
		granted += 1

func _reward_refs(reward: Dictionary, keys: Array[String]) -> Array:
	var refs: Array = []
	for key in keys:
		if not reward.has(key):
			continue
		var value = reward[key]
		if value is Array:
			for entry in value:
				refs.append(entry)
		else:
			refs.append(value)
	return refs

func _reward_ref_id(ref, id_key: String) -> String:
	if ref is Dictionary:
		return str((ref as Dictionary).get("id", (ref as Dictionary).get(id_key, ""))).strip_edges().to_lower()
	return str(ref).strip_edges().to_lower()

func _reward_ref_tier(ref) -> String:
	if ref is Dictionary:
		return str((ref as Dictionary).get("tier", (ref as Dictionary).get("rarity", "Bronze")))
	return "Bronze"

func _reward_ref_rarity(ref) -> int:
	var tier: String = _reward_ref_tier(ref)
	match tier:
		"Silver", "silver":
			return BazaarContentClass.RARITY_SILVER
		"Gold", "gold":
			return BazaarContentClass.RARITY_GOLD
		"Diamond", "diamond":
			return BazaarContentClass.RARITY_DIAMOND
	return BazaarContentClass.RARITY_BRONZE

func _hero_has_skill(skills: Array, skill_id: String) -> bool:
	for skill_ref in skills:
		if _reward_ref_id(skill_ref, "skill_id") == skill_id:
			return true
	return false
