extends Node

## RewardService - run reward application gateway.
## Stateless by design: authoritative values live in EconomyService,
## HeroStateService, and RunStateService.

const BazaarContentClass = preload("res://scripts/data/bazaar_content.gd")
const EnchantmentCatalogClass = preload("res://scripts/data/enchantment_catalog.gd")
const ItemAcquisitionClass = preload("res://scripts/data/item_acquisition.gd")
const LinearInventoryClass = preload("res://scripts/data/linear_inventory.gd")
const PlayerSkillCatalogClass = preload("res://scripts/data/player_skill_catalog.gd")

signal reward_applied(summary: Dictionary)
signal reward_choice_available(choice: Dictionary)
signal reward_choice_resolved(choice: Dictionary, option: Dictionary, summary: Dictionary)
signal level_reward_applied(level: int, reward: Dictionary, summary: Dictionary)

const DEFAULT_LEVEL_REWARDS: Dictionary = {
	2: {"max_health": 5, "income": 1},
	3: {"max_health": 10, "gold": 3},
	4: {"max_health": 10, "income": 1},
	5: {"max_health": 15, "gold": 5},
}

const CHOICE_TYPE_MONSTER_REWARD: String = "monster_reward"
const CHOICE_TYPE_LEVEL_UP: String = "level_up"
const FALLBACK_LEVEL_CHOICE_GOLD: int = 3

var _pending_reward_choices: Array[Dictionary] = []
var _next_choice_id: int = 1

func reset_runtime_state() -> void:
	_pending_reward_choices.clear()
	_next_choice_id = 1

func has_pending_choice() -> bool:
	return not _pending_reward_choices.is_empty()

func get_active_choice() -> Dictionary:
	if not has_pending_choice():
		return {}
	return (_pending_reward_choices[0] as Dictionary).duplicate(true)

func apply_monster_reward(
	reward: Dictionary,
	source: String = "pve_win",
	primary_inventory: LinearInventoryClass = null,
	secondary_inventory: LinearInventoryClass = null
) -> Dictionary:
	if reward.is_empty():
		var empty_summary: Dictionary = _new_summary(source)
		reward_applied.emit(empty_summary)
		return {
			"summary": empty_summary,
			"choice_queued": false,
			"choice": {},
		}

	var choice: Dictionary = _build_monster_reward_choice(reward, source)
	if choice.is_empty():
		var immediate_summary: Dictionary = apply_reward(reward, source, primary_inventory, secondary_inventory)
		return {
			"summary": immediate_summary,
			"choice_queued": false,
			"choice": {},
		}

	var queued_choice: Dictionary = _enqueue_reward_choice(choice)
	var summary: Dictionary = _new_summary(source)
	summary["choice_queued"] = true
	summary["pending_choice_ids"].append(str(queued_choice.get("choice_id", "")))
	summary["queued_choice_types"].append(str(queued_choice.get("type", "")))
	reward_applied.emit(summary)
	return {
		"summary": summary,
		"choice_queued": true,
		"choice": queued_choice.duplicate(true),
	}

func resolve_active_choice(
	index: int,
	primary_inventory: LinearInventoryClass = null,
	secondary_inventory: LinearInventoryClass = null
) -> Dictionary:
	var result: Dictionary = {
		"resolved": false,
		"choice": {},
		"option": {},
		"summary": {},
	}
	if not has_pending_choice():
		return result

	var choice: Dictionary = (_pending_reward_choices[0] as Dictionary).duplicate(true)
	var options: Array = choice.get("options", [])
	if index < 0 or index >= options.size():
		return result

	_pending_reward_choices.remove_at(0)

	var option: Dictionary = {}
	if options[index] is Dictionary:
		option = (options[index] as Dictionary).duplicate(true)
	var selected_reward: Dictionary = {}
	if option.get("reward", {}) is Dictionary:
		selected_reward = (option.get("reward", {}) as Dictionary).duplicate(true)

	var choice_source: String = str(choice.get("source", choice.get("choice_id", "reward_choice")))
	var option_id: String = str(option.get("id", "selected")).strip_edges()
	var summary: Dictionary = apply_reward(
		selected_reward,
		"%s:%s" % [choice_source, option_id],
		primary_inventory,
		secondary_inventory
	)

	if str(choice.get("type", "")) == CHOICE_TYPE_LEVEL_UP:
		level_reward_applied.emit(int(choice.get("level", 0)), selected_reward.duplicate(true), summary.duplicate(true))

	reward_choice_resolved.emit(choice.duplicate(true), option.duplicate(true), summary.duplicate(true))
	result["resolved"] = true
	result["choice"] = choice
	result["option"] = option
	result["summary"] = summary
	return result

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
			var level_choice: Dictionary = _build_level_reward_choice(
				int(level_value),
				primary_inventory,
				secondary_inventory
			)
			if not level_choice.is_empty():
				var queued_choice: Dictionary = _enqueue_reward_choice(level_choice)
				summary["choice_queued"] = true
				summary["pending_choice_ids"].append(str(queued_choice.get("choice_id", "")))
				summary["queued_choice_types"].append(str(queued_choice.get("type", "")))
				summary["level_rewards"].append({
					"level": int(level_value),
					"choice_id": str(queued_choice.get("choice_id", "")),
					"choice_queued": true,
				})
				continue

			var level_reward: Dictionary = get_level_reward(int(level_value))
			if level_reward.is_empty():
				continue
			var level_summary: Dictionary = _new_summary("level_%d" % int(level_value))
			_apply_immediate_reward(level_reward, level_summary, primary_inventory, secondary_inventory)
			summary["level_rewards"].append({
				"level": int(level_value),
				"reward": level_reward,
				"summary": level_summary,
				"choice_queued": false,
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
		"upgrades": [],
		"upgrade_failures": [],
		"enchantments": [],
		"enchant_failures": [],
		"level_rewards": [],
		"choice_queued": false,
		"pending_choice_ids": [],
		"queued_choice_types": [],
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
	_apply_upgrade_rewards(reward, summary, primary_inventory, secondary_inventory)
	_apply_enchant_rewards(reward, summary, primary_inventory, secondary_inventory)

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

func _apply_upgrade_rewards(
	reward: Dictionary,
	summary: Dictionary,
	primary_inventory: LinearInventoryClass,
	secondary_inventory: LinearInventoryClass
) -> void:
	if not bool(reward.get("upgrade_leftmost", false)):
		return
	var target = _find_leftmost_upgradable_item(primary_inventory, secondary_inventory)
	if target == null:
		summary["upgrade_failures"].append({"reason": "no_upgrade_target"})
		return
	var previous_rarity: int = int(target.rarity)
	if BazaarContentClass.apply_rarity_to_item(target, previous_rarity + 1):
		summary["upgrades"].append({
			"id": target.source_id,
			"name": target.item_name,
			"from": _rarity_to_tier(previous_rarity),
			"to": _rarity_to_tier(target.rarity),
		})
		return
	summary["upgrade_failures"].append({
		"id": target.source_id,
		"reason": "upgrade_apply_failed",
	})

func _apply_enchant_rewards(
	reward: Dictionary,
	summary: Dictionary,
	primary_inventory: LinearInventoryClass,
	secondary_inventory: LinearInventoryClass
) -> void:
	var enchantment_id: String = str(reward.get("enchant_leftmost", "")).strip_edges().to_lower()
	if enchantment_id.is_empty():
		return
	if not EnchantmentCatalogClass.is_known_enchantment(enchantment_id):
		summary["enchant_failures"].append({
			"reason": "unknown_enchantment",
			"id": enchantment_id,
		})
		return
	var target = _find_leftmost_enchantable_item(primary_inventory, secondary_inventory)
	if target == null:
		summary["enchant_failures"].append({"reason": "no_enchant_target"})
		return
	EnchantmentCatalogClass.apply_to_item(target, enchantment_id)
	summary["enchantments"].append({
		"id": target.source_id,
		"name": target.item_name,
		"enchantment": enchantment_id,
	})

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

func _enqueue_reward_choice(choice: Dictionary) -> Dictionary:
	var queued_choice: Dictionary = choice.duplicate(true)
	var choice_id: String = str(queued_choice.get("choice_id", "")).strip_edges()
	if choice_id.is_empty():
		choice_id = "reward_choice_%d" % _next_choice_id
		_next_choice_id += 1
	queued_choice["choice_id"] = choice_id
	_pending_reward_choices.append(queued_choice)
	reward_choice_available.emit(queued_choice.duplicate(true))
	return queued_choice

func _build_monster_reward_choice(reward: Dictionary, source: String) -> Dictionary:
	var item_refs: Array = _reward_refs(reward, ["item_id", "item_ids", "item_pool", "items"])
	var skill_refs: Array = _reward_refs(reward, ["skill_id", "skill_ids", "skill_pool", "skills"])
	if item_refs.is_empty() and skill_refs.is_empty():
		return {}

	var options: Array[Dictionary] = []
	var item_option: Dictionary = _build_item_choice_option(item_refs, 0, "monster_item", "Monster Item")
	if not item_option.is_empty():
		options.append(item_option)

	var skill_option: Dictionary = _build_skill_choice_option(skill_refs, 0, "monster_skill", "Monster Skill")
	if not skill_option.is_empty():
		options.append(skill_option)

	var fallback_reward: Dictionary = _copy_reward_fields(
		reward,
		["gold", "xp", "income", "max_health", "heal", "prestige"]
	)
	if fallback_reward.is_empty():
		fallback_reward["gold"] = maxi(int(reward.get("gold", 0)), 1)
	options.append({
		"id": "monster_fallback",
		"kind": "fallback",
		"badge": "SPOILS",
		"label": "Take the Payout",
		"summary": _describe_reward(fallback_reward),
		"reward": fallback_reward,
	})

	return {
		"type": CHOICE_TYPE_MONSTER_REWARD,
		"source": source,
		"title": "Choose a Reward",
		"subtitle": "Pick one reward from this victory.",
		"options": options,
	}

func _build_level_reward_choice(
	level: int,
	primary_inventory: LinearInventoryClass,
	secondary_inventory: LinearInventoryClass
) -> Dictionary:
	if level <= 1:
		return {}

	var base_reward: Dictionary = get_level_reward(level)
	var options: Array[Dictionary] = []
	var max_health_amount: int = int(base_reward.get("max_health", 0))
	if max_health_amount > 0:
		options.append({
			"id": "level_health",
			"kind": "max_health",
			"badge": "GROWTH",
			"label": "Bulk Up",
			"summary": _describe_reward({"max_health": max_health_amount}),
			"reward": {"max_health": max_health_amount},
		})

	if base_reward.has("income") and int(base_reward.get("income", 0)) != 0:
		var income_amount: int = int(base_reward.get("income", 0))
		options.append({
			"id": "level_income",
			"kind": "income",
			"badge": "ECON",
			"label": "Steady Income",
			"summary": _describe_reward({"income": income_amount}),
			"reward": {"income": income_amount},
		})
	elif int(base_reward.get("gold", 0)) > 0:
		var gold_amount: int = int(base_reward.get("gold", 0))
		options.append({
			"id": "level_gold",
			"kind": "gold",
			"badge": "ECON",
			"label": "Take Gold",
			"summary": _describe_reward({"gold": gold_amount}),
			"reward": {"gold": gold_amount},
		})

	for kind in _get_level_extra_choice_priority(level):
		if options.size() >= 3:
			break
		if _has_choice_kind(options, kind):
			continue
		var option: Dictionary = _build_level_extra_choice_option(
			kind,
			level,
			primary_inventory,
			secondary_inventory
		)
		if option.is_empty():
			continue
		options.append(option)

	if options.size() < 3 and not _has_choice_kind(options, "gold"):
		options.append({
			"id": "level_gold_fallback",
			"kind": "gold",
			"badge": "ECON",
			"label": "Pocket Gold",
			"summary": _describe_reward({"gold": maxi(int(base_reward.get("gold", 0)), FALLBACK_LEVEL_CHOICE_GOLD)}),
			"reward": {"gold": maxi(int(base_reward.get("gold", 0)), FALLBACK_LEVEL_CHOICE_GOLD)},
		})

	if options.size() < 2:
		return {}
	if options.size() > 3:
		options = options.slice(0, 3)

	return {
		"type": CHOICE_TYPE_LEVEL_UP,
		"source": "level_%d" % level,
		"level": level,
		"title": "Level Up",
		"subtitle": "Choose how this level shapes your build.",
		"options": options,
	}

func _build_level_extra_choice_option(
	kind: String,
	level: int,
	primary_inventory: LinearInventoryClass,
	secondary_inventory: LinearInventoryClass
) -> Dictionary:
	match kind:
		"board_slot":
			return {}
		"item":
			return _build_level_item_choice_option(level)
		"skill":
			return _build_level_skill_choice_option()
		"upgrade":
			return _build_level_upgrade_choice_option(primary_inventory, secondary_inventory)
		"enchant":
			return _build_level_enchant_choice_option(primary_inventory, secondary_inventory)
	return {}

func _build_level_item_choice_option(level: int) -> Dictionary:
	var hero = HeroStateService.selected_hero
	if hero == null:
		return {}
	var item_ids: Array[String] = BazaarContentClass.get_hero_item_ids(hero.hero_type)
	if item_ids.is_empty():
		return {}
	var item_index: int = (level - 2) % item_ids.size()
	var rarity: int = BazaarContentClass.RARITY_BRONZE
	if level >= 6:
		rarity = BazaarContentClass.RARITY_SILVER
	if level >= 10:
		rarity = BazaarContentClass.RARITY_GOLD
	var tier: String = _rarity_to_tier(rarity)
	var item_id: String = item_ids[item_index]
	var item = BazaarContentClass.create_item(item_id, rarity)
	if item == null:
		return {}
	return {
		"id": "level_item",
		"kind": "item",
		"badge": "ITEM",
		"label": item.item_name,
		"summary": "Gain a %s item." % tier,
		"reward": {
			"items": [{"id": item_id, "tier": tier}],
			"item_count": 1,
		},
	}

func _build_level_skill_choice_option() -> Dictionary:
	var hero = HeroStateService.selected_hero
	if hero == null:
		return {}
	var skill_ids: Array[String] = BazaarContentClass.get_hero_skill_ids(hero.hero_type)
	if skill_ids.is_empty():
		return {}
	for skill_id in skill_ids:
		if _hero_has_skill(hero.skills, skill_id):
			continue
		var skill_ref: Dictionary = PlayerSkillCatalogClass.normalize_skill_ref({"id": skill_id})
		if skill_ref.is_empty():
			continue
		var tier: String = str(skill_ref.get("tier", "Bronze"))
		return {
			"id": "level_skill",
			"kind": "skill",
			"badge": "SKILL",
			"label": str(skill_ref.get("name", skill_id)),
			"summary": "Gain a %s skill." % tier,
			"reward": {
				"skills": [{"id": skill_id, "tier": tier}],
				"skill_count": 1,
			},
		}
	return {}

func _build_level_upgrade_choice_option(
	primary_inventory: LinearInventoryClass,
	secondary_inventory: LinearInventoryClass
) -> Dictionary:
	var target = _find_leftmost_upgradable_item(primary_inventory, secondary_inventory)
	if target == null:
		return {}
	return {
		"id": "level_upgrade",
		"kind": "upgrade",
		"badge": "UPGRADE",
		"label": "Upgrade %s" % target.item_name,
		"summary": "Raise it by one tier.",
		"reward": {"upgrade_leftmost": true},
	}

func _build_level_enchant_choice_option(
	primary_inventory: LinearInventoryClass,
	secondary_inventory: LinearInventoryClass
) -> Dictionary:
	var target = _find_leftmost_enchantable_item(primary_inventory, secondary_inventory)
	if target == null:
		return {}
	var enchantment_id: String = _pick_level_up_enchantment(target)
	if enchantment_id.is_empty():
		return {}
	return {
		"id": "level_enchant",
		"kind": "enchant",
		"badge": "ENCHANT",
		"label": "%s Enchant" % EnchantmentCatalogClass.get_label(enchantment_id),
		"summary": "Enchant %s." % target.item_name,
		"reward": {"enchant_leftmost": enchantment_id},
	}

func _build_item_choice_option(refs: Array, ref_index: int, option_id: String, label_prefix: String) -> Dictionary:
	if ref_index < 0 or ref_index >= refs.size():
		return {}
	var item_ref = refs[ref_index]
	var item_id: String = _reward_ref_id(item_ref, "item_id")
	if item_id.is_empty():
		return {}
	var rarity: int = _reward_ref_rarity(item_ref)
	var tier: String = _reward_ref_tier(item_ref)
	var item = BazaarContentClass.create_item(item_id, rarity)
	if item == null:
		return {}
	return {
		"id": option_id,
		"kind": "item",
		"badge": "ITEM",
		"label": "%s: %s" % [label_prefix, item.item_name],
		"summary": "Gain a %s item." % tier,
		"reward": {
			"items": [{"id": item_id, "tier": tier}],
			"item_count": 1,
		},
	}

func _build_skill_choice_option(refs: Array, ref_index: int, option_id: String, label_prefix: String) -> Dictionary:
	if ref_index < 0 or ref_index >= refs.size():
		return {}
	var skill_ref = refs[ref_index]
	var skill_id: String = _reward_ref_id(skill_ref, "skill_id")
	if skill_id.is_empty():
		return {}
	var resolved: Dictionary = PlayerSkillCatalogClass.normalize_skill_ref(skill_ref)
	if resolved.is_empty():
		return {}
	var tier: String = str(resolved.get("tier", _reward_ref_tier(skill_ref)))
	return {
		"id": option_id,
		"kind": "skill",
		"badge": "SKILL",
		"label": "%s: %s" % [label_prefix, str(resolved.get("name", skill_id))],
		"summary": "Gain a %s skill." % tier,
		"reward": {
			"skills": [{"id": skill_id, "tier": tier}],
			"skill_count": 1,
		},
	}

func _get_level_extra_choice_priority(level: int) -> Array[String]:
	match level % 4:
		0:
			return ["board_slot", "upgrade", "skill", "item", "enchant"]
		1:
			return ["enchant", "item", "skill", "upgrade", "board_slot"]
		2:
			return ["board_slot", "item", "skill", "upgrade", "enchant"]
		_:
			return ["skill", "item", "upgrade", "enchant", "board_slot"]

func _has_choice_kind(options: Array[Dictionary], kind: String) -> bool:
	for option in options:
		if str(option.get("kind", "")) == kind:
			return true
	return false

func _copy_reward_fields(reward: Dictionary, fields: Array[String]) -> Dictionary:
	var result: Dictionary = {}
	for field in fields:
		if reward.has(field):
			result[field] = reward[field]
	return result

func _describe_reward(reward: Dictionary) -> String:
	var parts: Array[String] = []
	if int(reward.get("gold", 0)) > 0:
		parts.append("+%d Gold" % int(reward.get("gold", 0)))
	if int(reward.get("xp", 0)) > 0:
		parts.append("+%d XP" % int(reward.get("xp", 0)))
	if int(reward.get("income", 0)) != 0:
		parts.append("%+d Income" % int(reward.get("income", 0)))
	if int(reward.get("max_health", 0)) > 0:
		parts.append("+%d Max Health" % int(reward.get("max_health", 0)))
	if int(reward.get("heal", 0)) > 0:
		parts.append("Heal %d" % int(reward.get("heal", 0)))
	if int(reward.get("prestige", 0)) > 0:
		parts.append("+%d Prestige" % int(reward.get("prestige", 0)))
	return " / ".join(parts)

func _find_leftmost_upgradable_item(
	primary_inventory: LinearInventoryClass,
	secondary_inventory: LinearInventoryClass
):
	for item in ItemAcquisitionClass.collect_owned_items(primary_inventory, secondary_inventory):
		if item != null and item.rarity < BazaarContentClass.RARITY_DIAMOND:
			return item
	return null

func _find_leftmost_enchantable_item(
	primary_inventory: LinearInventoryClass,
	secondary_inventory: LinearInventoryClass
):
	for item in ItemAcquisitionClass.collect_owned_items(primary_inventory, secondary_inventory):
		if item != null and str(item.enchantment_id).is_empty():
			return item
	return null

func _pick_level_up_enchantment(item) -> String:
	if item == null:
		return ""
	if _item_has_tag(item, "Burn"):
		return "fiery"
	if _item_has_tag(item, "Poison"):
		return "toxic"
	if _item_has_tag(item, "Heal") or _item_has_tag(item, "Regen"):
		return "restorative"
	return "heavy"

func _item_has_tag(item, required_tag: String) -> bool:
	if item == null or required_tag.is_empty():
		return false
	for tag in item.tags:
		if str(tag).to_lower() == required_tag.to_lower():
			return true
	return false

func _rarity_to_tier(rarity: int) -> String:
	match int(rarity):
		BazaarContentClass.RARITY_SILVER:
			return "Silver"
		BazaarContentClass.RARITY_GOLD:
			return "Gold"
		BazaarContentClass.RARITY_DIAMOND:
			return "Diamond"
		_:
			return "Bronze"
