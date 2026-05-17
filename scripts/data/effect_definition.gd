class_name EffectDefinition
extends RefCounted

const ItemDataClass = preload("res://scripts/data/item_data.gd")

const TRIGGER_ON_BATTLE_START: String = "on_battle_start"
const TRIGGER_ON_COOLDOWN_READY: String = "on_cooldown_ready"
const TRIGGER_ON_ITEM_USED: String = "on_item_used"
const TRIGGER_ON_TAG_USED: String = "on_tag_used"
const TRIGGER_ON_DAMAGE_DEALT: String = "on_damage_dealt"
const TRIGGER_ON_DAMAGE_TAKEN: String = "on_damage_taken"
const TRIGGER_ON_SHIELD_GAINED: String = "on_shield_gained"
const TRIGGER_ON_HEAL: String = "on_heal"
const TRIGGER_ON_CRIT: String = "on_crit"
const TRIGGER_ON_ENEMY_STATUS_APPLIED: String = "on_enemy_status_applied"
const TRIGGER_ON_RELOAD: String = "on_reload"
const TRIGGER_ON_SELL: String = "on_sell"
const TRIGGER_ON_BUY: String = "on_buy"
const TRIGGER_ON_HOUR_START: String = "on_hour_start"
const TRIGGER_ON_TRANSFORM: String = "on_transform"
const TRIGGER_ON_ENCHANT: String = "on_enchant"

const EFFECT_DAMAGE: String = "damage"
const EFFECT_SHIELD: String = "shield"
const EFFECT_HEAL: String = "heal"
const EFFECT_BURN: String = "burn"
const EFFECT_POISON: String = "poison"
const EFFECT_REGENERATION: String = "regeneration"
const EFFECT_SLOW: String = "slow"
const EFFECT_HASTE: String = "haste"
const EFFECT_FREEZE: String = "freeze"
const EFFECT_CHARGE: String = "charge"
const EFFECT_RELOAD: String = "reload"
const EFFECT_AMMO: String = "ammo"
const EFFECT_RUNTIME_BONUS: String = "runtime_bonus"
const EFFECT_MULTICAST: String = "multicast"

const _PRIORITY_KEYWORD_MATCHERS := {
	EFFECT_DAMAGE: ["damage"],
	EFFECT_SHIELD: ["shield"],
	EFFECT_HEAL: ["heal"],
	EFFECT_BURN: ["burn"],
	EFFECT_POISON: ["poison"],
	EFFECT_REGENERATION: ["regen", "regeneration"],
	EFFECT_SLOW: ["slow"],
	EFFECT_HASTE: ["haste"],
	EFFECT_FREEZE: ["freeze"],
	EFFECT_CHARGE: ["charge"],
	EFFECT_RELOAD: ["reload"],
	EFFECT_RUNTIME_BONUS: ["gain", "gains", "have +", "has +"],
	EFFECT_MULTICAST: ["multicast"],
}

const _HOOK_KEYWORD_MATCHERS := {
	TRIGGER_ON_SELL: ["when you sell", "when this is sold"],
	TRIGGER_ON_BUY: ["when you buy", "when this is bought"],
	TRIGGER_ON_HOUR_START: ["start of each day", "start of each hour"],
	TRIGGER_ON_TRANSFORM: ["when this is transformed", "when you transform"],
	TRIGGER_ON_ENCHANT: ["when you enchant", "when another item is enchanted"],
}

const _SUPPORTED_ITEM_WARNING_EFFECTS := [
	EFFECT_DAMAGE,
	EFFECT_SHIELD,
	EFFECT_HEAL,
	EFFECT_BURN,
	EFFECT_POISON,
	EFFECT_REGENERATION,
	EFFECT_SLOW,
	EFFECT_HASTE,
	EFFECT_FREEZE,
	EFFECT_CHARGE,
	EFFECT_RELOAD,
	EFFECT_RUNTIME_BONUS,
	EFFECT_MULTICAST,
]

const _SUPPORTED_ITEM_WARNING_TRIGGERS := [
	TRIGGER_ON_SELL,
	TRIGGER_ON_BUY,
	TRIGGER_ON_HOUR_START,
	TRIGGER_ON_TRANSFORM,
	TRIGGER_ON_ENCHANT,
]

static func build_item_effects(item: ItemDataClass) -> Array[Dictionary]:
	var definitions: Array[Dictionary] = []
	var handled_keywords: Dictionary = {}
	if item == null:
		return definitions

	_append_root_value_effect(
		definitions,
		handled_keywords,
		item,
		"%s_root_damage" % item.source_id,
		EFFECT_DAMAGE,
		"enemy",
		"hero",
		"source.damage"
	)
	if item.source_id != "duct_tape":
		_append_root_value_effect(
			definitions,
			handled_keywords,
			item,
			"%s_root_shield" % item.source_id,
			EFFECT_SHIELD,
			"self",
			"hero",
			"source.shield"
		)
	_append_root_value_effect(
		definitions,
		handled_keywords,
		item,
		"%s_root_heal" % item.source_id,
		EFFECT_HEAL,
		"self",
		"hero",
		"source.heal"
	)
	_append_root_value_effect(
		definitions,
		handled_keywords,
		item,
		"%s_root_poison" % item.source_id,
		EFFECT_POISON,
		"enemy",
		"hero",
		"source.poison"
	)
	if item.poison_damage <= 0.0 and not item.source_id.is_empty() and item.source_id != "emerald":
		definitions.append({
			"id": "%s_root_poison_bonus" % item.source_id,
			"trigger": TRIGGER_ON_COOLDOWN_READY,
			"target": {"side": "enemy", "selector": "hero"},
			"effect": {
				"type": EFFECT_POISON,
				"amount_from": "source.poison_bonus",
				"crit_scaled": true,
			},
		})
	_append_root_value_effect(
		definitions,
		handled_keywords,
		item,
		"%s_root_burn" % item.source_id,
		EFFECT_BURN,
		"enemy",
		"hero",
		"source.burn"
	)
	_append_root_value_effect(
		definitions,
		handled_keywords,
		item,
		"%s_root_regeneration" % item.source_id,
		EFFECT_REGENERATION,
		"self",
		"hero",
		"source.regeneration"
	)

	_append_root_cooldown_effect(
		definitions,
		handled_keywords,
		item,
		"%s_root_slow" % item.source_id,
		EFFECT_SLOW,
		"enemy",
		"slowest_items",
		"source.slow_count",
		"source.slow_duration"
	)
	_append_root_cooldown_effect(
		definitions,
		handled_keywords,
		item,
		"%s_root_freeze" % item.source_id,
		EFFECT_FREEZE,
		"enemy",
		"slowest_items",
		"source.freeze_count",
		"source.freeze_duration"
	)
	_append_root_cooldown_effect(
		definitions,
		handled_keywords,
		item,
		"%s_root_haste" % item.source_id,
		EFFECT_HASTE,
		"self",
		"slowest_other_items",
		"source.haste_count",
		"source.haste_duration"
	)

	if item.has_ammo_limit():
		handled_keywords[EFFECT_AMMO] = true

	match item.source_id:
		"adrenaline_shot":
			handled_keywords[EFFECT_RELOAD] = true
			handled_keywords[EFFECT_RUNTIME_BONUS] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_CRIT, EFFECT_RELOAD, {"side": "self", "selector": "this_item"}, {"type": EFFECT_RELOAD, "amount": 1}, {"event_source_is_owner": true}))
		"aludel":
			handled_keywords[EFFECT_MULTICAST] = true
			definitions.append({
				"id": "aludel_adjacent_potion_multicast",
				"trigger": TRIGGER_ON_COOLDOWN_READY,
				"condition": {"adjacent_any_tags": ["Potion", "Reagent"]},
				"target": {"side": "self", "selector": "this_item"},
				"effect": {"type": EFFECT_MULTICAST, "amount": 1},
			})
		"barbed_claws":
			handled_keywords[EFFECT_POISON] = true
			handled_keywords[EFFECT_MULTICAST] = true
			definitions.append({
				"id": "barbed_claws_self_poison_multicast",
				"trigger": TRIGGER_ON_COOLDOWN_READY,
				"condition": {"status_at_least": {"side": "self", "type": EFFECT_POISON, "minimum": 1.0}},
				"target": {"side": "self", "selector": "this_item"},
				"effect": {"type": EFFECT_MULTICAST, "amount": 1},
			})
			definitions.append({
				"id": "barbed_claws_enemy_poison_multicast",
				"trigger": TRIGGER_ON_COOLDOWN_READY,
				"condition": {"status_at_least": {"side": "enemy", "type": EFFECT_POISON, "minimum": 1.0}},
				"target": {"side": "self", "selector": "this_item"},
				"effect": {"type": EFFECT_MULTICAST, "amount": 1},
			})
		"black_pepper":
			handled_keywords[EFFECT_CHARGE] = true
			handled_keywords[EFFECT_MULTICAST] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_CHARGE, {"side": "self", "selector": "adjacent"}, {"type": EFFECT_CHARGE, "amount_by_rarity": [1, 2, 3]}))
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_MULTICAST, {"side": "self", "selector": "this_item"}, {"type": EFFECT_MULTICAST, "amount": 1}))
		"blu_b33tl3":
			handled_keywords[EFFECT_CHARGE] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_ENEMY_STATUS_APPLIED, EFFECT_CHARGE, {"side": "self", "selector": "this_item"}, {"type": EFFECT_CHARGE, "amount": 1}, {"status_type": EFFECT_POISON, "event_source_is_owner_or_adjacent": true}))
		"blk_sp1d3r":
			handled_keywords[EFFECT_CHARGE] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_ENEMY_STATUS_APPLIED, EFFECT_CHARGE, {"side": "self", "selector": "this_item"}, {"type": EFFECT_CHARGE, "amount": 1}, {"status_type_any": [EFFECT_POISON, EFFECT_BURN], "event_source_is_adjacent": true}))
		"athanor":
			handled_keywords[EFFECT_RELOAD] = true
			handled_keywords[EFFECT_BURN] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_RELOAD, {"side": "self", "selector": "adjacent"}, {"type": EFFECT_RELOAD, "amount": 1}))
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_TAG_USED, EFFECT_BURN, {"side": "enemy", "selector": "hero"}, {"type": EFFECT_BURN, "amount_by_rarity": [8, 12, 16]}, {"tag": "Potion"}))
		"amber":
			handled_keywords[EFFECT_RUNTIME_BONUS] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_BATTLE_START, EFFECT_RUNTIME_BONUS, {"side": "self", "selector": "other_matching_tag_items", "tag": "Slow"}, {"type": EFFECT_RUNTIME_BONUS, "bonus_key": "slow_count", "amount": 1.0, "scope": "combat"}))
		"battery":
			handled_keywords[EFFECT_CHARGE] = true
			definitions.append({
				"id": "battery_root_charge_left",
				"trigger": TRIGGER_ON_COOLDOWN_READY,
				"target": {"side": "self", "selector": "left_item"},
				"effect": {
					"type": EFFECT_CHARGE,
					"amount_by_rarity": [1.0, 2.0, 3.0, 4.0],
				},
			})
		"bayonet":
			handled_keywords[EFFECT_DAMAGE] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_TAG_USED, EFFECT_DAMAGE, {"side": "enemy", "selector": "hero"}, {"type": EFFECT_DAMAGE, "amount_by_rarity": [10, 15, 20, 25]}, {"tag": "Weapon", "event_source_relation": "left_adjacent"}))
		"boiling_flask":
			handled_keywords[EFFECT_RELOAD] = true
			handled_keywords[EFFECT_MULTICAST] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_RELOAD, {"side": "self", "selector": "adjacent_matching_tag_items", "tag": "Potion"}, {"type": EFFECT_RELOAD, "amount": 1}))
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_MULTICAST, {"side": "self", "selector": "adjacent_matching_tag_items", "tag": "Potion"}, {"type": EFFECT_MULTICAST, "amount": 1}))
		"dive_weights":
			handled_keywords[EFFECT_RUNTIME_BONUS] = true
			handled_keywords[EFFECT_MULTICAST] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_BATTLE_START, EFFECT_RUNTIME_BONUS, {"side": "self", "selector": "this_item"}, {"type": EFFECT_RUNTIME_BONUS, "bonus_key": "cooldown_flat_reduction", "amount_from": "adjacent_items.matching_tag_count", "tag": "Aquatic", "scope": "combat"}))
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_MULTICAST, {"side": "self", "selector": "this_item"}, {"type": EFFECT_MULTICAST, "amount_from": "source.ammo"}))
		"blue_piggles_l":
			handled_keywords[EFFECT_RUNTIME_BONUS] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_BATTLE_START, EFFECT_RUNTIME_BONUS, {"side": "self", "selector": "left_item"}, {"type": EFFECT_RUNTIME_BONUS, "bonus_key": "crit_rate", "amount_by_rarity": [4, 8, 12, 16], "scope": "combat"}))
		"elemental_depth_charge":
			handled_keywords[EFFECT_MULTICAST] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_MULTICAST, {"side": "self", "selector": "this_item"}, {"type": EFFECT_MULTICAST, "amount_from": "other_items.matching_tag_count", "tag": "Aquatic"}))
		"candles":
			handled_keywords[EFFECT_CHARGE] = true
			definitions.append({
				"id": "candles_on_small_item_charge",
				"trigger": TRIGGER_ON_ITEM_USED,
				"condition": {"event_source_size": "small"},
				"target": {"side": "self", "selector": "this_item"},
				"effect": {"type": EFFECT_CHARGE, "amount": 2.0},
			})
		"cellar":
			handled_keywords[EFFECT_RELOAD] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_RELOAD, {"side": "self", "selector": "ammo_items", "count": 1}, {"type": EFFECT_RELOAD, "amount": 1}))
		"cutlass", "tiny_cutlass":
			handled_keywords[EFFECT_MULTICAST] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_MULTICAST, {"side": "self", "selector": "this_item"}, {"type": EFFECT_MULTICAST, "amount": 1}))
		"duct_tape":
			definitions.append({
				"id": "duct_tape_on_left_item_shield",
				"trigger": TRIGGER_ON_ITEM_USED,
				"condition": {"event_source_relation": "left_adjacent"},
				"target": {"side": "self", "selector": "hero"},
				"effect": {"type": EFFECT_SHIELD, "amount_from": "source.shield"},
			})
		"broken_shackles":
			handled_keywords[EFFECT_CHARGE] = true
			handled_keywords[EFFECT_RUNTIME_BONUS] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_BATTLE_START, EFFECT_RUNTIME_BONUS, {"side": "self", "selector": "matching_tag_items", "tag": "Weapon"}, {"type": EFFECT_RUNTIME_BONUS, "bonus_key": EFFECT_DAMAGE, "amount_by_rarity": [4, 8, 12], "scope": "combat"}))
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_TAG_USED, EFFECT_CHARGE, {"side": "self", "selector": "this_item"}, {"type": EFFECT_CHARGE, "amount": 2.0}, {"tag": "Weapon"}))
		"bomb_squad":
			handled_keywords[EFFECT_HASTE] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_ITEM_USED, EFFECT_HASTE, {"side": "self", "selector": "this_item"}, {"type": EFFECT_HASTE, "amount": 2.0}, {"tag": "Friend", "event_source_is_owner_or_adjacent": true, "event_source_not_owner": true}))
		"emerald":
			handled_keywords[EFFECT_RUNTIME_BONUS] = true
		"ectoplasm":
			handled_keywords[EFFECT_HEAL] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_HEAL, {"side": "self", "selector": "hero"}, {"type": EFFECT_HEAL, "amount_from": "enemy_status.poison"}))
		"floor_spike":
			handled_keywords[EFFECT_CHARGE] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_TAG_USED, EFFECT_CHARGE, {"side": "self", "selector": "this_item"}, {"type": EFFECT_CHARGE, "amount": 1}, {"tag": "Weapon"}))
		"dooltron":
			handled_keywords[EFFECT_CHARGE] = true
			handled_keywords[EFFECT_FREEZE] = true
			handled_keywords[EFFECT_SHIELD] = true
			definitions.append(_trigger_condition_marker(item.source_id, EFFECT_FREEZE, "status-trigger condition handles Freeze"))
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_ENEMY_STATUS_APPLIED, EFFECT_CHARGE, {"side": "self", "selector": "this_item"}, {"type": EFFECT_CHARGE, "amount_by_rarity": [1, 2]}, {"status_type_any": [EFFECT_HASTE, EFFECT_SLOW, EFFECT_POISON, EFFECT_FREEZE, EFFECT_BURN]}))
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_TAG_USED, EFFECT_SHIELD, {"side": "self", "selector": "hero"}, {"type": EFFECT_SHIELD, "amount_by_rarity": [50, 100]}, {"tag": "Friend"}))
		"dragon_heart":
			handled_keywords[EFFECT_CHARGE] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_ENEMY_STATUS_APPLIED, EFFECT_CHARGE, {"side": "self", "selector": "this_item"}, {"type": EFFECT_CHARGE, "amount": 2}, {"status_type": EFFECT_BURN}))
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_TAG_USED, EFFECT_CHARGE, {"side": "self", "selector": "this_item"}, {"type": EFFECT_CHARGE, "amount": 2}, {"tag": "Flying"}))
		"dragon_wing":
			handled_keywords[EFFECT_CHARGE] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_ENEMY_STATUS_APPLIED, EFFECT_CHARGE, {"side": "self", "selector": "this_item"}, {"type": EFFECT_CHARGE, "amount": 2}, {"status_type": EFFECT_BURN}))
		"electric_eels":
			handled_keywords[EFFECT_CHARGE] = true
			definitions.append({"id": "electric_eels_on_item_used_charge", "trigger": "", "target": {"selector": "runtime_service"}, "effect": {"type": EFFECT_CHARGE, "runtime_path": "BattleSystem enemy item-use charge"}})
		"fire_claw":
			handled_keywords[EFFECT_RUNTIME_BONUS] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_BATTLE_START, EFFECT_RUNTIME_BONUS, {"side": "self", "selector": "this_item"}, {"type": EFFECT_RUNTIME_BONUS, "bonus_key": EFFECT_BURN, "amount_from": "other_items.burn_percent_by_rarity", "percent_by_rarity": [0.5, 0.75, 1.0], "scope": "combat"}))
		"fungal_spores":
			handled_keywords[EFFECT_RUNTIME_BONUS] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_RUNTIME_BONUS, {"side": "self", "selector": "matching_tag_items", "tag": "Poison"}, {"type": EFFECT_RUNTIME_BONUS, "bonus_key": EFFECT_POISON, "amount_by_rarity": [2, 3, 4, 5], "scope": "combat"}))
		"fireflies":
			handled_keywords[EFFECT_RUNTIME_BONUS] = true
		"flamethrower":
			handled_keywords[EFFECT_BURN] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_BURN, {"side": "enemy", "selector": "hero"}, {"type": EFFECT_BURN, "amount_from": "source.damage"}))
		"frozen_flame":
			handled_keywords[EFFECT_RUNTIME_BONUS] = true
		"frozen_bludgeon":
			handled_keywords[EFFECT_RUNTIME_BONUS] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_ENEMY_STATUS_APPLIED, EFFECT_RUNTIME_BONUS, {"side": "self", "selector": "matching_tag_items", "tag": "Weapon"}, {"type": EFFECT_RUNTIME_BONUS, "bonus_key": EFFECT_DAMAGE, "amount_by_rarity": [4, 6, 8, 10], "scope": "combat"}, {"status_type": EFFECT_FREEZE}))
		"force_field":
			handled_keywords[EFFECT_DAMAGE] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_DAMAGE, {"side": "enemy", "selector": "hero"}, {"type": EFFECT_DAMAGE, "amount_from": "hero.shield"}, {}, "after_consume"))
		"gatling_gun":
			handled_keywords[EFFECT_MULTICAST] = true
			handled_keywords[EFFECT_RUNTIME_BONUS] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_MULTICAST, {"side": "self", "selector": "this_item"}, {"type": EFFECT_MULTICAST, "amount": 1}))
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, "crit_runtime_bonus", {"side": "self", "selector": "this_item"}, {"type": EFFECT_RUNTIME_BONUS, "bonus_key": "crit_rate", "amount_by_rarity": [0, 5, 10, 15], "scope": "combat"}))
			var gatling_cooldown_definition: Dictionary = _hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, "first_use_cooldown_runtime_bonus", {"side": "self", "selector": "this_item"}, {"type": EFFECT_RUNTIME_BONUS, "bonus_key": "cooldown_flat_reduction", "amount_from": "source.cooldown_percent", "percent": 0.5, "scope": "combat"}, {}, "after_consume")
			gatling_cooldown_definition["max_triggers_per_fight"] = 1
			definitions.append(gatling_cooldown_definition)
		"barbed_wire":
			handled_keywords[EFFECT_RUNTIME_BONUS] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_SHIELD_GAINED, EFFECT_RUNTIME_BONUS, {"side": "self", "selector": "this_item"}, {"type": EFFECT_RUNTIME_BONUS, "bonus_key": EFFECT_DAMAGE, "amount_by_rarity": [0, 5, 10, 15], "scope": "combat"}))
		"anchor":
			handled_keywords[EFFECT_DAMAGE] = true
			handled_keywords[EFFECT_HASTE] = true
			handled_keywords[EFFECT_RUNTIME_BONUS] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_DAMAGE, {"side": "enemy", "selector": "hero"}, {"type": EFFECT_DAMAGE, "amount_from": "enemy.max_health_percent", "percent_by_rarity": [0.0, 0.0, 0.2, 0.3], "crit_scaled": true}))
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_ITEM_USED, EFFECT_HASTE, {"side": "self", "selector": "this_item"}, {"type": EFFECT_HASTE, "amount_by_rarity": [0.0, 0.0, 2.0, 4.0]}, {"event_source_is_adjacent": true}))
		"black_rose":
			handled_keywords[EFFECT_RUNTIME_BONUS] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_ENEMY_STATUS_APPLIED, EFFECT_RUNTIME_BONUS, {"side": "self", "selector": "this_item"}, {"type": EFFECT_RUNTIME_BONUS, "bonus_key": EFFECT_REGENERATION, "amount_by_rarity": [0, 1, 2, 3], "scope": "combat"}, {"status_type": EFFECT_POISON}))
		"crusher_claw":
			handled_keywords[EFFECT_DAMAGE] = true
			handled_keywords[EFFECT_RUNTIME_BONUS] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_RUNTIME_BONUS, {"side": "self", "selector": "matching_tag_items", "tag": "Shield"}, {"type": EFFECT_RUNTIME_BONUS, "bonus_key": EFFECT_SHIELD, "amount_by_rarity": [2, 4, 6, 8], "scope": "combat"}))
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_DAMAGE, {"side": "enemy", "selector": "hero"}, {"type": EFFECT_DAMAGE, "amount_from": "items.highest_shield"}, {}, "after_consume"))
		"dock_lines":
			if not _definitions_handle_effect(definitions, EFFECT_SLOW):
				handled_keywords[EFFECT_SLOW] = true
				definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_SLOW, {"side": "enemy", "selector": "slowest_items", "count": 2}, {"type": EFFECT_SLOW, "amount": 3.0, "count_crit_scaled": true, "crit_scaled": true}))
		"goop_flail":
			handled_keywords[EFFECT_MULTICAST] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_MULTICAST, {"side": "self", "selector": "this_item"}, {"type": EFFECT_MULTICAST, "amount": 2}))
		"haladie":
			handled_keywords[EFFECT_MULTICAST] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_MULTICAST, {"side": "self", "selector": "this_item"}, {"type": EFFECT_MULTICAST, "amount": 1}))
		"grapeshot":
			handled_keywords[EFFECT_RELOAD] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_ITEM_USED, EFFECT_RELOAD, {"side": "self", "selector": "this_item"}, {"type": EFFECT_RELOAD, "amount": 1}, {"event_source_has_ammo": true, "event_source_not_owner": true}))
		"grn_w4sp":
			handled_keywords[EFFECT_CHARGE] = true
			handled_keywords[EFFECT_FREEZE] = true
			definitions.append(_trigger_condition_marker(item.source_id, EFFECT_FREEZE, "adjacent status-trigger condition handles Freeze"))
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_ENEMY_STATUS_APPLIED, EFFECT_CHARGE, {"side": "self", "selector": "this_item"}, {"type": EFFECT_CHARGE, "amount": 1}, {"status_type_any": [EFFECT_SLOW, EFFECT_FREEZE], "event_source_is_adjacent": true}))
		"guardian_shell":
			handled_keywords[EFFECT_SHIELD] = true
			handled_keywords[EFFECT_CHARGE] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_SHIELD, {"side": "self", "selector": "hero"}, {"type": EFFECT_SHIELD, "amount_by_rarity": [0, 40, 60, 80]}))
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_ENEMY_STATUS_APPLIED, EFFECT_CHARGE, {"side": "self", "selector": "this_item"}, {"type": EFFECT_CHARGE, "amount": 1}, {"status_type": EFFECT_POISON}))
		"handaxe":
			handled_keywords[EFFECT_RUNTIME_BONUS] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_BATTLE_START, EFFECT_RUNTIME_BONUS, {"side": "self", "selector": "matching_tag_items", "tag": "Weapon"}, {"type": EFFECT_RUNTIME_BONUS, "bonus_key": EFFECT_DAMAGE, "amount_by_rarity": [6, 9, 12, 15], "scope": "combat"}))
		"goggles":
			handled_keywords[EFFECT_RUNTIME_BONUS] = true
			definitions.append({"id": "goggles_on_item_used_runtime_bonus", "trigger": "", "target": {"selector": "runtime_service"}, "effect": {"type": EFFECT_RUNTIME_BONUS, "runtime_path": "BattleSystem on-Haste adjacent Crit Chance runtime"}})
		"incendiary_rounds":
			handled_keywords[EFFECT_BURN] = true
			handled_keywords[EFFECT_RUNTIME_BONUS] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_BATTLE_START, EFFECT_AMMO, {"side": "self", "selector": "adjacent"}, {"type": EFFECT_AMMO, "amount": 1}))
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_ITEM_USED, EFFECT_BURN, {"side": "enemy", "selector": "hero"}, {"type": EFFECT_BURN, "amount_by_rarity": [1, 2, 3]}, {"event_source_is_owner_or_adjacent": true, "event_source_not_owner": true}))
		"hot_sauce":
			handled_keywords[EFFECT_MULTICAST] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_MULTICAST, {"side": "self", "selector": "this_item"}, {"type": EFFECT_MULTICAST, "amount_from": "adjacent_items.matching_any_tag_count", "tags": ["Food"]}))
		"icebreaker":
			handled_keywords[EFFECT_CHARGE] = true
			handled_keywords[EFFECT_FREEZE] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_ENEMY_STATUS_APPLIED, EFFECT_CHARGE, {"side": "self", "selector": "this_item"}, {"type": EFFECT_CHARGE, "amount_by_rarity": [1, 2, 3]}, {"status_type": EFFECT_FREEZE}))
		"illusoray":
			handled_keywords[EFFECT_RUNTIME_BONUS] = true
			handled_keywords[EFFECT_MULTICAST] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_MULTICAST, {"side": "self", "selector": "this_item"}, {"type": EFFECT_MULTICAST, "amount_from": "adjacent_items.matching_any_tag_count", "tags": ["Friend", "Ray"]}))
		"infinite_potion":
			handled_keywords[EFFECT_RELOAD] = true
			definitions.append({
				"id": "infinite_potion_root_reload_self",
				"trigger": TRIGGER_ON_COOLDOWN_READY,
				"timing": "after_consume",
				"target": {"side": "self", "selector": "this_item"},
				"effect": {"type": EFFECT_RELOAD, "amount": 1},
			})
		"powder_flask":
			handled_keywords[EFFECT_RELOAD] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_RELOAD, {"side": "self", "selector": "right_item"}, {"type": EFFECT_RELOAD, "amount_by_rarity": [1, 2, 3, 4]}))
		"powder_keg":
			handled_keywords[EFFECT_DAMAGE] = true
			handled_keywords[EFFECT_CHARGE] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_DAMAGE, {"side": "enemy", "selector": "hero"}, {"type": EFFECT_DAMAGE, "amount_from": "enemy.max_health_percent", "percent_by_rarity": [0.0, 0.3, 0.35, 0.4], "crit_scaled": true}))
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_ENEMY_STATUS_APPLIED, EFFECT_CHARGE, {"side": "self", "selector": "this_item"}, {"type": EFFECT_CHARGE, "amount": 2}, {"status_type": EFFECT_BURN}))
		"ice_claw":
			handled_keywords[EFFECT_RUNTIME_BONUS] = true
		"memento_mori":
			handled_keywords[EFFECT_DAMAGE] = true
			handled_keywords[EFFECT_HEAL] = true
			handled_keywords[EFFECT_RUNTIME_BONUS] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_DAMAGE_TAKEN, EFFECT_HEAL, {"side": "self", "selector": "hero"}, {"type": EFFECT_HEAL, "amount": 1}))
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_DAMAGE_TAKEN, EFFECT_DAMAGE, {"side": "self", "selector": "hero"}, {"type": EFFECT_DAMAGE, "prevented": true}))
			definitions.append(_runtime_bonus_marker(item.source_id, "BattleSystem would-die Heal 1 and no-damage window runtime"))
		"jellyfish":
			handled_keywords[EFFECT_HASTE] = true
			handled_keywords[EFFECT_RUNTIME_BONUS] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_ITEM_USED, EFFECT_HASTE, {"side": "self", "selector": "this_item"}, {"type": EFFECT_HASTE, "amount_by_rarity": [1, 2, 3, 4]}, {"tag": "Aquatic", "event_source_is_owner_or_adjacent": true, "event_source_not_owner": true}))
		"kinetic_cannon":
			handled_keywords[EFFECT_CHARGE] = true
			handled_keywords[EFFECT_RUNTIME_BONUS] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_ITEM_USED, EFFECT_CHARGE, {"side": "self", "selector": "this_item"}, {"type": EFFECT_CHARGE, "amount": 1}, {"event_source_size": "small"}))
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_ITEM_USED, EFFECT_RUNTIME_BONUS, {"side": "self", "selector": "this_item"}, {"type": EFFECT_RUNTIME_BONUS, "bonus_key": EFFECT_DAMAGE, "amount_by_rarity": [25, 50, 75], "scope": "combat"}, {"event_source_size": "small"}))
		"knife_set":
			handled_keywords[EFFECT_CHARGE] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_TAG_USED, EFFECT_CHARGE, {"side": "self", "selector": "this_item"}, {"type": EFFECT_CHARGE, "amount": 2}, {"tag": "Weapon"}))
		"leeches":
			handled_keywords[EFFECT_RUNTIME_BONUS] = true
		"lightbulb":
			handled_keywords[EFFECT_CHARGE] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_CHARGE, {"side": "self", "selector": "right_matching_tag", "tag": "Tech"}, {"type": EFFECT_CHARGE, "amount": 1}))
		"lumboars":
			handled_keywords[EFFECT_MULTICAST] = true
			handled_keywords[EFFECT_RUNTIME_BONUS] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_MULTICAST, {"side": "self", "selector": "this_item"}, {"type": EFFECT_MULTICAST, "amount": 1}))
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_RUNTIME_BONUS, {"side": "self", "selector": "matching_tag_items", "tag": "Weapon"}, {"type": EFFECT_RUNTIME_BONUS, "bonus_key": EFFECT_DAMAGE, "amount_by_rarity": [5, 10, 15, 20], "scope": "combat"}))
		"magic_carpet":
			handled_keywords[EFFECT_RUNTIME_BONUS] = true
		"micro_dave":
			handled_keywords[EFFECT_CHARGE] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_ITEM_USED, EFFECT_CHARGE, {"side": "self", "selector": "this_item"}, {"type": EFFECT_CHARGE, "amount": 1}, {"event_source_size": "small"}))
		"magnus_femur":
			handled_keywords[EFFECT_RUNTIME_BONUS] = true
		"mortar_pestle", "mortar_and_pestle":
			handled_keywords[EFFECT_RUNTIME_BONUS] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_RUNTIME_BONUS, {"side": "self", "selector": "lifesteal_weapon_items"}, {"type": EFFECT_RUNTIME_BONUS, "bonus_key": EFFECT_DAMAGE, "amount_by_rarity": [10, 15, 20, 25], "scope": "combat"}))
		"nightshade":
			handled_keywords[EFFECT_RUNTIME_BONUS] = true
		"nitro":
			handled_keywords[EFFECT_BURN] = true
			handled_keywords[EFFECT_CHARGE] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, "enemy_burn", {"side": "enemy", "selector": "hero"}, {"type": EFFECT_BURN, "amount_by_rarity": [0, 4, 6, 8]}))
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, "self_burn", {"side": "self", "selector": "hero"}, {"type": EFFECT_BURN, "amount_by_rarity": [0, 4, 6, 8]}))
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_CHARGE, {"side": "self", "selector": "slowest_other_items", "count": 1}, {"type": EFFECT_CHARGE, "amount_by_rarity": [1, 2, 3, 4]}))
		"plasma_grenade":
			handled_keywords[EFFECT_BURN] = true
			handled_keywords[EFFECT_SLOW] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, "enemy_burn", {"side": "enemy", "selector": "hero"}, {"type": EFFECT_BURN, "amount_by_rarity": [5, 10, 15, 20]}))
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, "self_burn", {"side": "self", "selector": "hero"}, {"type": EFFECT_BURN, "amount_by_rarity": [5, 10, 15, 20]}))
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_SLOW, {"side": "enemy", "selector": "slowest_items", "count": 99}, {"type": EFFECT_SLOW, "amount_by_rarity": [1, 1, 1, 2]}))
		"curry":
			handled_keywords[EFFECT_CHARGE] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_CHARGE, {"side": "self", "selector": "other_matching_size_highest_cooldown", "size": "small", "count": 1}, {"type": EFFECT_CHARGE, "amount_by_rarity": [0, 3, 4, 5]}))
		"ouroboros_statue":
			handled_keywords[EFFECT_REGENERATION] = true
			handled_keywords[EFFECT_RUNTIME_BONUS] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_ENEMY_STATUS_APPLIED, EFFECT_REGENERATION, {"side": "self", "selector": "hero"}, {"type": EFFECT_REGENERATION, "amount_by_rarity": [0, 2, 6, 10]}, {"status_type": EFFECT_POISON}))
		"cosmic_plumage":
			handled_keywords[EFFECT_CHARGE] = true
			handled_keywords[EFFECT_RUNTIME_BONUS] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_BATTLE_START, "shield_runtime_bonus", {"side": "self", "selector": "matching_tag_items", "tag": "Shield"}, {"type": EFFECT_RUNTIME_BONUS, "bonus_key": EFFECT_SHIELD, "amount_by_rarity": [10, 20, 30], "scope": "combat"}))
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_BATTLE_START, "weapon_runtime_bonus", {"side": "self", "selector": "matching_tag_items", "tag": "Weapon"}, {"type": EFFECT_RUNTIME_BONUS, "bonus_key": EFFECT_DAMAGE, "amount_by_rarity": [10, 20, 30], "scope": "combat"}))
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_CRIT, EFFECT_CHARGE, {"side": "self", "selector": "this_item"}, {"type": EFFECT_CHARGE, "amount": 3.0}, {"event_source_is_owner": true}))
		"nargile":
			handled_keywords[EFFECT_CHARGE] = true
			handled_keywords[EFFECT_RUNTIME_BONUS] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_BATTLE_START, EFFECT_RUNTIME_BONUS, {"side": "self", "selector": "adjacent"}, {"type": EFFECT_RUNTIME_BONUS, "bonus_key": "crit_rate", "amount_by_rarity": [25, 50], "scope": "combat"}))
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_CRIT, EFFECT_CHARGE, {"side": "self", "selector": "this_item"}, {"type": EFFECT_CHARGE, "amount": 2.0}, {"event_source_is_owner": true}))
		"octopus":
			handled_keywords[EFFECT_MULTICAST] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_MULTICAST, {"side": "self", "selector": "this_item"}, {"type": EFFECT_MULTICAST, "amount": 7}))
		"refractor":
			handled_keywords[EFFECT_RUNTIME_BONUS] = true
		"revolver":
			handled_keywords[EFFECT_RELOAD] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_CRIT, EFFECT_RELOAD, {"side": "self", "selector": "this_item"}, {"type": EFFECT_RELOAD, "amount": 2}, {"event_source_is_owner": true}))
		"rivet_gun":
			handled_keywords[EFFECT_CHARGE] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_ITEM_USED, EFFECT_CHARGE, {"side": "self", "selector": "left_item"}, {"type": EFFECT_CHARGE, "amount_by_rarity": [1, 2]}, {"event_source_relation": "right_adjacent"}))
		"quill_and_ink":
			handled_keywords[EFFECT_MULTICAST] = true
			definitions.append({
				"id": "quill_and_ink_no_other_weapon_multicast",
				"trigger": TRIGGER_ON_COOLDOWN_READY,
				"condition": {"no_other_tag": "Weapon"},
				"target": {"side": "self", "selector": "this_item"},
				"effect": {"type": EFFECT_MULTICAST, "amount": 1},
			})
		"pulse_rifle":
			handled_keywords[EFFECT_RUNTIME_BONUS] = true
			handled_keywords[EFFECT_MULTICAST] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, "adjacent_friend_multicast", {"side": "self", "selector": "this_item"}, {"type": EFFECT_MULTICAST, "amount": 1}, {"adjacent_any_tags": ["Friend"]}))
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, "only_friend_multicast", {"side": "self", "selector": "this_item"}, {"type": EFFECT_MULTICAST, "amount": 1}, {"adjacent_any_tags": ["Friend"], "player_tag_count_equals": {"tag": "Friend", "count": 1}}))
		"rocket_launcher":
			handled_keywords[EFFECT_MULTICAST] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_MULTICAST, {"side": "self", "selector": "this_item"}, {"type": EFFECT_MULTICAST, "amount": 2}))
		"runic_daggers":
			handled_keywords[EFFECT_CHARGE] = true
			handled_keywords[EFFECT_MULTICAST] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_MULTICAST, {"side": "self", "selector": "this_item"}, {"type": EFFECT_MULTICAST, "amount": 1}))
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_CRIT, EFFECT_CHARGE, {"side": "self", "selector": "this_item"}, {"type": EFFECT_CHARGE, "amount": 1}, {"event_source_not_owner": true}))
		"runic_double_bow":
			handled_keywords[EFFECT_MULTICAST] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_MULTICAST, {"side": "self", "selector": "this_item"}, {"type": EFFECT_MULTICAST, "amount": 1}))
		"ruby":
			handled_keywords[EFFECT_RUNTIME_BONUS] = true
		"satchel":
			handled_keywords[EFFECT_RELOAD] = true
			handled_keywords[EFFECT_REGENERATION] = true
			handled_keywords[EFFECT_RUNTIME_BONUS] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_RELOAD, {"side": "self", "selector": "ammo_items", "count": 2}, {"type": EFFECT_RELOAD, "amount": 1}))
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_RELOAD, EFFECT_REGENERATION, {"side": "self", "selector": "hero"}, {"type": EFFECT_REGENERATION, "amount": 2}))
		"the_boulder":
			handled_keywords[EFFECT_DAMAGE] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_DAMAGE, {"side": "enemy", "selector": "hero"}, {"type": EFFECT_DAMAGE, "amount_from": "enemy.max_health_percent", "percent": 1.0, "crit_scaled": true}))
		"flagship":
			handled_keywords[EFFECT_RUNTIME_BONUS] = true
			handled_keywords[EFFECT_MULTICAST] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_MULTICAST, {"side": "self", "selector": "this_item"}, {"type": EFFECT_MULTICAST, "amount_from": "other_items.matching_any_tag_count", "tags": ["Tool", "Property", "Friend", "Ammo"]}))
		"sapphire":
			handled_keywords[EFFECT_RUNTIME_BONUS] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_BATTLE_START, EFFECT_RUNTIME_BONUS, {"side": "self", "selector": "other_matching_tag_items", "tag": "Freeze"}, {"type": EFFECT_RUNTIME_BONUS, "bonus_key": "freeze_duration", "amount": 0.5, "scope": "combat"}))
		"pearl":
			handled_keywords[EFFECT_CHARGE] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_TAG_USED, EFFECT_CHARGE, {"side": "self", "selector": "this_item"}, {"type": EFFECT_CHARGE, "amount": 1.0}, {"tag": "Aquatic", "event_source_not_owner": true}))
		"pufferfish":
			handled_keywords[EFFECT_CHARGE] = true
			definitions.append({"id": "pufferfish_on_item_used_charge", "trigger": "", "target": {"selector": "runtime_service"}, "effect": {"type": EFFECT_CHARGE, "runtime_path": "BattleSystem on-Haste self-charge runtime"}})
		"pesky_pete":
			handled_keywords[EFFECT_MULTICAST] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_MULTICAST, {"side": "self", "selector": "this_item"}, {"type": EFFECT_MULTICAST, "amount_from": "adjacent_items.matching_any_tag_count", "tags": ["Friend", "Property"]}))
		"plasma_rifle":
			handled_keywords[EFFECT_CHARGE] = true
			handled_keywords[EFFECT_RUNTIME_BONUS] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_ENEMY_STATUS_APPLIED, EFFECT_RUNTIME_BONUS, {"side": "self", "selector": "this_item"}, {"type": EFFECT_RUNTIME_BONUS, "bonus_key": EFFECT_DAMAGE, "amount_by_rarity": [20, 40, 60], "scope": "combat"}, {"status_type": EFFECT_BURN}))
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_ENEMY_STATUS_APPLIED, EFFECT_CHARGE, {"side": "self", "selector": "this_item"}, {"type": EFFECT_CHARGE, "amount": 1}, {"status_type": EFFECT_BURN}))
		"piggles":
			handled_keywords[EFFECT_CHARGE] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_CHARGE, {"side": "self", "selector": "adjacent_matching_size_items", "size": "small"}, {"type": EFFECT_CHARGE, "amount_by_rarity": [1, 2, 3, 4]}))
		"rapid_injection_system":
			handled_keywords[EFFECT_POISON] = true
			handled_keywords[EFFECT_REGENERATION] = true
			handled_keywords[EFFECT_RUNTIME_BONUS] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_ITEM_USED, EFFECT_POISON, {"side": "self", "selector": "hero"}, {"type": EFFECT_POISON, "amount_by_rarity": [4, 8, 12]}, {"event_source_relation": "left_adjacent"}))
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_ITEM_USED, EFFECT_REGENERATION, {"side": "self", "selector": "hero"}, {"type": EFFECT_REGENERATION, "amount_by_rarity": [2, 4, 6]}, {"event_source_relation": "left_adjacent"}))
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_ITEM_USED, EFFECT_RUNTIME_BONUS, {"side": "self", "selector": "this_item"}, {"type": EFFECT_RUNTIME_BONUS, "bonus_key": EFFECT_REGENERATION, "amount_by_rarity": [2, 4, 6], "scope": "combat"}, {"event_source_relation": "left_adjacent"}))
		"seaweed":
			handled_keywords[EFFECT_RUNTIME_BONUS] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_TAG_USED, EFFECT_RUNTIME_BONUS, {"side": "self", "selector": "this_item"}, {"type": EFFECT_RUNTIME_BONUS, "bonus_key": EFFECT_HEAL, "amount_by_rarity": [5, 10, 15, 20], "scope": "combat"}, {"tag": "Aquatic"}))
		"shadowed_cloak":
			handled_keywords[EFFECT_HASTE] = true
			handled_keywords[EFFECT_RUNTIME_BONUS] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_ITEM_USED, EFFECT_HASTE, {"side": "self", "selector": "source_item"}, {"type": EFFECT_HASTE, "amount_by_rarity": [1, 2, 3, 4]}, {"event_source_relation": "right_adjacent"}))
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_ITEM_USED, EFFECT_RUNTIME_BONUS, {"side": "self", "selector": "source_item"}, {"type": EFFECT_RUNTIME_BONUS, "bonus_key": EFFECT_DAMAGE, "amount_by_rarity": [3, 5, 7, 9], "scope": "combat"}, {"event_source_relation": "right_adjacent", "tag": "Weapon"}))
		"scythe":
			handled_keywords[EFFECT_DAMAGE] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_DAMAGE, {"side": "enemy", "selector": "hero"}, {"type": EFFECT_DAMAGE, "amount_from": "enemy.max_health_percent", "percent": 0.333333333333, "crit_scaled": true}))
		"skillet":
			handled_keywords[EFFECT_RUNTIME_BONUS] = true
			handled_keywords[EFFECT_MULTICAST] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_MULTICAST, {"side": "self", "selector": "this_item"}, {"type": EFFECT_MULTICAST, "amount": 1}, {"adjacent_matching_tag_count_at_least": {"tag": "Food", "count": 2}}))
		"snow_globe":
			handled_keywords[EFFECT_RUNTIME_BONUS] = true
			handled_keywords[EFFECT_MULTICAST] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_MULTICAST, {"side": "self", "selector": "this_item"}, {"type": EFFECT_MULTICAST, "amount_from": "adjacent_items.matching_any_tag_count", "tags": ["Property"]}))
		"stopwatch":
			handled_keywords[EFFECT_FREEZE] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, "freeze_player_items", {"side": "self", "selector": "slowest_items", "count": 99}, {"type": EFFECT_FREEZE, "amount_by_rarity": [0, 0, 1, 2]}))
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, "freeze_enemy_items", {"side": "enemy", "selector": "slowest_items", "count": 99}, {"type": EFFECT_FREEZE, "amount_by_rarity": [0, 0, 1, 2]}))
		"spices":
			handled_keywords[EFFECT_RUNTIME_BONUS] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_BATTLE_START, EFFECT_RUNTIME_BONUS, {"side": "self", "selector": "matching_tag_items", "tag": "Weapon"}, {"type": EFFECT_RUNTIME_BONUS, "bonus_key": EFFECT_DAMAGE, "amount_from": "weakest_weapon.damage", "scope": "combat"}))
		"smelling_salts":
			handled_keywords[EFFECT_HASTE] = true
			definitions.append({
				"id": "smelling_salts_on_slow_haste_left",
				"trigger": TRIGGER_ON_ENEMY_STATUS_APPLIED,
				"condition": {
					"status_type": EFFECT_SLOW,
					"event_source_is_owner_or_adjacent": true,
				},
				"target": {"side": "self", "selector": "left_item"},
				"effect": {
					"type": EFFECT_HASTE,
					"amount_by_rarity": [1.0, 2.0, 3.0, 4.0],
				},
			})
		"spider_mace":
			handled_keywords[EFFECT_CHARGE] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_ENEMY_STATUS_APPLIED, EFFECT_CHARGE, {"side": "self", "selector": "this_item"}, {"type": EFFECT_CHARGE, "amount": 2}, {"status_type_any": [EFFECT_SLOW, EFFECT_POISON]}))
		"soul_ring":
			handled_keywords[EFFECT_POISON] = true
			handled_keywords[EFFECT_REGENERATION] = true
			handled_keywords[EFFECT_RUNTIME_BONUS] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_BATTLE_START, EFFECT_REGENERATION, {"side": "self", "selector": "hero"}, {"type": EFFECT_REGENERATION, "amount_by_rarity": [0, 0, 10, 20]}))
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_POISON, {"side": "enemy", "selector": "hero"}, {"type": EFFECT_POISON, "amount_from": "player_status.regeneration", "crit_scaled": true}))
		"throwing_knives":
			handled_keywords[EFFECT_CHARGE] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_CRIT, EFFECT_CHARGE, {"side": "self", "selector": "this_item"}, {"type": EFFECT_CHARGE, "amount_by_rarity": [1, 2, 3]}, {"event_source_not_owner": true}))
		"tesla_coil":
			handled_keywords[EFFECT_CHARGE] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_TAG_USED, EFFECT_CHARGE, {"side": "self", "selector": "slowest_items", "count": 1}, {"type": EFFECT_CHARGE, "amount": 1}, {"tag": "Tech", "event_source_is_owner_or_adjacent": true}))
		"thurible":
			handled_keywords[EFFECT_RUNTIME_BONUS] = true
		"succulents":
			handled_keywords[EFFECT_RUNTIME_BONUS] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_RUNTIME_BONUS, {"side": "self", "selector": "this_item"}, {"type": EFFECT_RUNTIME_BONUS, "bonus_key": EFFECT_HEAL, "amount_by_rarity": [1, 2, 3, 4], "scope": "permanent"}, {}, "after_consume"))
		"tazidian_dagger":
			handled_keywords[EFFECT_AMMO] = true
			handled_keywords[EFFECT_RUNTIME_BONUS] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_BATTLE_START, EFFECT_AMMO, {"side": "self", "selector": "left_item"}, {"type": EFFECT_AMMO, "amount_by_rarity": [1, 2, 3, 4]}))
		"tommoo_gun":
			handled_keywords[EFFECT_DAMAGE] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_DAMAGE, {"side": "enemy", "selector": "hero"}, {"type": EFFECT_DAMAGE, "amount_from": "source.ammo", "crit_scaled": true}))
		"turtle_shell":
			handled_keywords[EFFECT_CHARGE] = true
			handled_keywords[EFFECT_RUNTIME_BONUS] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_BATTLE_START, EFFECT_RUNTIME_BONUS, {"side": "self", "selector": "matching_tag_items", "tag": "Shield"}, {"type": EFFECT_RUNTIME_BONUS, "bonus_key": EFFECT_SHIELD, "amount_by_rarity": [0, 0, 10, 15], "scope": "combat"}))
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_ITEM_USED, EFFECT_CHARGE, {"side": "self", "selector": "this_item"}, {"type": EFFECT_CHARGE, "amount": 1}, {"event_source_not_owner": true, "no_event_source_tag": "Weapon"}))
		"tusked_helm":
			handled_keywords[EFFECT_MULTICAST] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_MULTICAST, {"side": "self", "selector": "this_item"}, {"type": EFFECT_MULTICAST, "amount": 1}))
		"apothecary":
			handled_keywords[EFFECT_CHARGE] = true
			for status_type in [EFFECT_POISON, EFFECT_BURN, EFFECT_SLOW]:
				definitions.append(_hook_definition(item.source_id, TRIGGER_ON_ENEMY_STATUS_APPLIED, EFFECT_CHARGE, {"side": "self", "selector": "this_item"}, {"type": EFFECT_CHARGE, "amount": 1}, {"status_type": status_type}))
		"sword_cane":
			definitions.append({
				"id": "sword_cane_adjacent_regen_regeneration",
				"trigger": TRIGGER_ON_COOLDOWN_READY,
				"condition": {"adjacent_status_type": EFFECT_REGENERATION},
				"target": {"side": "self", "selector": "hero"},
				"effect": {
					"type": EFFECT_REGENERATION,
					"amount_by_rarity": [2.0, 4.0, 6.0, 8.0],
					"crit_scaled": true,
				},
			})
			definitions.append({
				"id": "sword_cane_adjacent_burn_burn",
				"trigger": TRIGGER_ON_COOLDOWN_READY,
				"condition": {"adjacent_status_type": EFFECT_BURN},
				"target": {"side": "enemy", "selector": "hero"},
				"effect": {
					"type": EFFECT_BURN,
					"amount_by_rarity": [2.0, 4.0, 6.0, 8.0],
					"crit_scaled": true,
					"include_burn_synergy_bonus": true,
				},
			})
			definitions.append({
				"id": "sword_cane_adjacent_poison_poison",
				"trigger": TRIGGER_ON_COOLDOWN_READY,
				"condition": {"adjacent_status_type": EFFECT_POISON},
				"target": {"side": "enemy", "selector": "hero"},
				"effect": {
					"type": EFFECT_POISON,
					"amount_by_rarity": [2.0, 4.0, 6.0, 8.0],
					"crit_scaled": true,
				},
			})
		"venom":
			handled_keywords[EFFECT_POISON] = true
			definitions.append({
				"id": "venom_on_left_weapon_poison",
				"trigger": TRIGGER_ON_TAG_USED,
				"condition": {
					"tag": "Weapon",
					"event_source_relation": "left_adjacent",
				},
				"target": {"side": "enemy", "selector": "hero"},
				"effect": {
					"type": EFFECT_POISON,
					"amount_by_rarity": [2.0, 3.0, 4.0, 5.0],
					"include_runtime_poison_bonus": true,
				},
			})
		"venomous_dose":
			definitions.append({
				"id": "venomous_dose_root_self_poison",
				"trigger": TRIGGER_ON_COOLDOWN_READY,
				"target": {"side": "self", "selector": "hero"},
				"effect": {
					"type": EFFECT_POISON,
					"amount_from": "source.poison",
					"crit_scaled": true,
				},
			})
		"wand":
			handled_keywords[EFFECT_CHARGE] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_CHARGE, {"side": "self", "selector": "other_non_matching_tag_items", "tag": "Weapon"}, {"type": EFFECT_CHARGE, "amount_by_rarity": [1, 1, 1, 2]}))
		"weakpoint_detector":
			handled_keywords[EFFECT_CHARGE] = true
			handled_keywords[EFFECT_RUNTIME_BONUS] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_BATTLE_START, EFFECT_RUNTIME_BONUS, {"side": "self", "selector": "matching_tag_items", "tag": "Weapon"}, {"type": EFFECT_RUNTIME_BONUS, "bonus_key": EFFECT_DAMAGE, "amount_by_rarity": [5, 10, 15, 20], "scope": "combat"}))
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_ENEMY_STATUS_APPLIED, EFFECT_CHARGE, {"side": "self", "selector": "this_item"}, {"type": EFFECT_CHARGE, "amount": 2.0}, {"status_type": EFFECT_SLOW}))
		"weather_glass":
			handled_keywords[EFFECT_RUNTIME_BONUS] = true
			handled_keywords[EFFECT_MULTICAST] = true
			handled_keywords[EFFECT_SLOW] = true
			handled_keywords[EFFECT_FREEZE] = true
			definitions.append(_trigger_condition_marker(item.source_id, EFFECT_SLOW, "multicast tag count handles Slow-tagged items"))
			definitions.append(_trigger_condition_marker(item.source_id, EFFECT_FREEZE, "multicast tag count handles Freeze-tagged items"))
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_MULTICAST, {"side": "self", "selector": "this_item"}, {"type": EFFECT_MULTICAST, "amount_from": "other_items.matching_any_tag_count", "tags": ["Burn", "Poison", "Slow", "Freeze"]}))
		"weather_machine":
			handled_keywords[EFFECT_SLOW] = true
			handled_keywords[EFFECT_FREEZE] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_FREEZE, {"side": "enemy", "selector": "slowest_items", "count": 1}, {"type": EFFECT_FREEZE, "amount_by_rarity": [0, 0, 1, 2]}))
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_SLOW, {"side": "enemy", "selector": "slowest_items", "count": 1}, {"type": EFFECT_SLOW, "amount_by_rarity": [0, 0, 2, 3]}))
		"weights":
			handled_keywords[EFFECT_CHARGE] = true
			handled_keywords[EFFECT_RUNTIME_BONUS] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_BATTLE_START, "weapon_damage", {"side": "self", "selector": "matching_tag_items", "tag": "Weapon"}, {"type": EFFECT_RUNTIME_BONUS, "bonus_key": EFFECT_DAMAGE, "amount_by_rarity": [10, 15, 20, 25], "scope": "combat"}))
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_BATTLE_START, "heal_item_heal", {"side": "self", "selector": "matching_tag_items", "tag": "Heal"}, {"type": EFFECT_RUNTIME_BONUS, "bonus_key": EFFECT_HEAL, "amount_by_rarity": [10, 15, 20, 25], "scope": "combat"}))
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_HEAL, EFFECT_CHARGE, {"side": "self", "selector": "this_item"}, {"type": EFFECT_CHARGE, "amount": 1}, {"overheal": true}))
		"vitality_potion":
			handled_keywords[EFFECT_HEAL] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_HEAL, {"side": "self", "selector": "hero"}, {"type": EFFECT_HEAL, "amount_from": "hero.max_health_percent", "percent_by_rarity": [0.0, 0.0, 0.5, 1.0]}))
		"atm":
			handled_keywords[EFFECT_SHIELD] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_SHIELD, {"side": "self", "selector": "hero"}, {"type": EFFECT_SHIELD, "amount_from": "income_by_rarity", "multiplier_by_rarity": [1, 2, 3, 4]}))
		"cryosleeve":
			handled_keywords[EFFECT_FREEZE] = true
			handled_keywords[EFFECT_SHIELD] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_FREEZE, {"side": "self", "selector": "this_item"}, {"type": EFFECT_FREEZE, "amount": 2.0}))
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_FREEZE, {"side": "self", "selector": "adjacent"}, {"type": EFFECT_FREEZE, "amount": 2.0}))
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_ENEMY_STATUS_APPLIED, EFFECT_SHIELD, {"side": "self", "selector": "hero"}, {"type": EFFECT_SHIELD, "amount_from": "source.shield"}, {"status_type": EFFECT_FREEZE}))
		"dragon_whelp":
			handled_keywords[EFFECT_BURN] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_BURN, {"side": "enemy", "selector": "hero"}, {"type": EFFECT_BURN, "amount_from": "source.damage"}))
		"hogwash":
			handled_keywords[EFFECT_HEAL] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_HEAL, {"side": "self", "selector": "hero"}, {"type": EFFECT_HEAL, "amount_from": "hero.max_health_percent", "percent": 0.1}))
		"lighthouse":
			handled_keywords[EFFECT_CHARGE] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_ENEMY_STATUS_APPLIED, EFFECT_CHARGE, {"side": "self", "selector": "this_item"}, {"type": EFFECT_CHARGE, "amount": 2}, {"status_type": EFFECT_SLOW}))
		"necronomicon":
			handled_keywords[EFFECT_CHARGE] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_ITEM_USED, EFFECT_CHARGE, {"side": "self", "selector": "this_item"}, {"type": EFFECT_CHARGE, "amount": 1}, {"no_event_source_tag": "Weapon", "event_source_not_owner": true}))
		"nitrogen_hammer":
			handled_keywords[EFFECT_CHARGE] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_ENEMY_STATUS_APPLIED, EFFECT_CHARGE, {"side": "self", "selector": "this_item"}, {"type": EFFECT_CHARGE, "amount": 1}, {"status_type": EFFECT_FREEZE}))
		"old_saltclaw":
			handled_keywords[EFFECT_DAMAGE] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_DAMAGE, {"side": "enemy", "selector": "hero"}, {"type": EFFECT_DAMAGE, "amount": 10, "crit_scaled": true}))
		"pendulum":
			handled_keywords[EFFECT_CHARGE] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_ITEM_USED, EFFECT_CHARGE, {"side": "self", "selector": "other_adjacent_to_source_around_owner"}, {"type": EFFECT_CHARGE, "amount_by_rarity": [1, 2]}, {"event_source_is_adjacent": true}))
		"red_f1r3fly":
			handled_keywords[EFFECT_CHARGE] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_TAG_USED, EFFECT_CHARGE, {"side": "self", "selector": "this_item"}, {"type": EFFECT_CHARGE, "amount": 1}, {"tag": EFFECT_HASTE, "event_source_is_adjacent": true}))
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_ENEMY_STATUS_APPLIED, EFFECT_CHARGE, {"side": "self", "selector": "this_item"}, {"type": EFFECT_CHARGE, "amount": 1}, {"status_type": EFFECT_SLOW, "event_source_is_adjacent": true}))
		"robe":
			handled_keywords[EFFECT_CHARGE] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_ITEM_USED, EFFECT_CHARGE, {"side": "self", "selector": "this_item"}, {"type": EFFECT_CHARGE, "amount": 1}, {"event_source_is_adjacent": true}))
		"rocket_boots":
			handled_keywords[EFFECT_HASTE] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_HASTE, {"side": "self", "selector": "adjacent"}, {"type": EFFECT_HASTE, "amount_by_rarity": [1, 2, 3, 4]}))
		"slumbering_primordial":
			handled_keywords[EFFECT_CHARGE] = true
			handled_keywords[EFFECT_FREEZE] = true
			definitions.append(_trigger_condition_marker(item.source_id, EFFECT_FREEZE, "status-trigger condition handles Freeze"))
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_ENEMY_STATUS_APPLIED, EFFECT_CHARGE, {"side": "self", "selector": "this_item"}, {"type": EFFECT_CHARGE, "amount_by_rarity": [1, 2]}, {"status_type_any": [EFFECT_POISON, EFFECT_FREEZE, EFFECT_BURN]}))
		"solar_farm":
			handled_keywords[EFFECT_CHARGE] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_ENEMY_STATUS_APPLIED, EFFECT_CHARGE, {"side": "self", "selector": "this_item"}, {"type": EFFECT_CHARGE, "amount": 2}, {"status_type": EFFECT_BURN}))
		"sunlight_spear":
			handled_keywords[EFFECT_REGENERATION] = true
			handled_keywords[EFFECT_BURN] = true
			handled_keywords[EFFECT_DAMAGE] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_REGENERATION, {"side": "self", "selector": "hero"}, {"type": EFFECT_REGENERATION, "amount_by_rarity": [4, 8, 12]}))
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_BURN, {"side": "enemy", "selector": "hero"}, {"type": EFFECT_BURN, "amount_from": "player_status.regeneration"}))
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_DAMAGE, {"side": "enemy", "selector": "hero"}, {"type": EFFECT_DAMAGE, "amount_from": "all_status.burn_plus_player_regeneration", "crit_scaled": true}))
		"textiles":
			handled_keywords[EFFECT_HEAL] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_HEAL, {"side": "self", "selector": "hero"}, {"type": EFFECT_HEAL, "amount_from": "hero.shield"}))
		"torpedo":
			handled_keywords[EFFECT_RELOAD] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_ITEM_USED, EFFECT_RELOAD, {"side": "self", "selector": "this_item"}, {"type": EFFECT_RELOAD, "amount": 1}, {"event_source_not_owner": true, "event_source_any_tags": ["Aquatic", "Ammo"], "event_source_size": "large"}))
		"tortuga":
			handled_keywords[EFFECT_HASTE] = true
			handled_keywords[EFFECT_CHARGE] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_HASTE, {"side": "self", "selector": "other_items"}, {"type": EFFECT_HASTE, "amount": 1}))
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_TAG_USED, EFFECT_CHARGE, {"side": "self", "selector": "this_item"}, {"type": EFFECT_CHARGE, "amount": 2}, {"tag": "Friend", "event_source_not_owner": true}))
		"trebuchet":
			handled_keywords[EFFECT_CHARGE] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_TAG_USED, EFFECT_CHARGE, {"side": "self", "selector": "this_item"}, {"type": EFFECT_CHARGE, "amount": 2}, {"tag": "Weapon"}))
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_TAG_USED, EFFECT_CHARGE, {"side": "self", "selector": "this_item"}, {"type": EFFECT_CHARGE, "amount": 2}, {"tag": EFFECT_HASTE}))
		"void_shield":
			handled_keywords[EFFECT_SHIELD] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_SHIELD, {"side": "self", "selector": "hero"}, {"type": EFFECT_SHIELD, "amount_from": "enemy_status.burn"}))
		"ylw_m4nt1s":
			handled_keywords[EFFECT_CHARGE] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_ENEMY_STATUS_APPLIED, EFFECT_CHARGE, {"side": "self", "selector": "this_item"}, {"type": EFFECT_CHARGE, "amount": 1}, {"status_type": EFFECT_BURN, "event_source_is_adjacent": true}))
		"yo_yo":
			handled_keywords[EFFECT_CHARGE] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_ITEM_USED, EFFECT_CHARGE, {"side": "self", "selector": "this_item"}, {"type": EFFECT_CHARGE, "amount_by_rarity": [1, 2, 3, 4]}, {"event_source_is_adjacent": true}))
		"zoarcid":
			handled_keywords[EFFECT_CHARGE] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_ENEMY_STATUS_APPLIED, EFFECT_CHARGE, {"side": "self", "selector": "this_item"}, {"type": EFFECT_CHARGE, "amount": 1}, {"status_type": EFFECT_BURN}))
		"void_ray":
			handled_keywords[EFFECT_MULTICAST] = true
			handled_keywords[EFFECT_RUNTIME_BONUS] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_MULTICAST, {"side": "self", "selector": "this_item"}, {"type": EFFECT_MULTICAST, "amount": 1}))
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_SHIELD_GAINED, EFFECT_RUNTIME_BONUS, {"side": "self", "selector": "this_item"}, {"type": EFFECT_RUNTIME_BONUS, "bonus_key": EFFECT_BURN, "amount_by_rarity": [0, 0, 1, 2], "scope": "combat"}))
		"z_sword":
			handled_keywords[EFFECT_RUNTIME_BONUS] = true
			handled_keywords[EFFECT_MULTICAST] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_MULTICAST, {"side": "self", "selector": "this_item"}, {"type": EFFECT_MULTICAST, "amount": 1}, {"has_item_size": "large"}))

	_append_p2b_runtime_bonus_family_definitions(definitions, handled_keywords, item)
	_append_p2b_confirmed_remainder_definitions(definitions, handled_keywords, item)
	_append_non_combat_hook_definitions(definitions, handled_keywords, item)
	var runtime_bonus_path: String = _runtime_bonus_runtime_path(item.source_id)
	if not runtime_bonus_path.is_empty() and not _definitions_handle_effect(definitions, EFFECT_RUNTIME_BONUS):
		definitions.append(_runtime_bonus_marker(item.source_id, runtime_bonus_path))
	return definitions

static func _append_p2b_runtime_bonus_family_definitions(definitions: Array[Dictionary], handled_keywords: Dictionary, item: ItemDataClass) -> void:
	if item == null:
		return
	match item.source_id:
		"atm", "citrus", "dog", "holsters", "improvised_bludgeon", "myrrh", "necronomicon", "salamander_pup", "silk_scarf", "solar_farm", "temporary_shelter":
			_append_runtime_marker_definition(definitions, handled_keywords, item.source_id, "existing root or service hook models this source-backed runtime text")
		"biomerge_arm":
			_append_runtime_marker_definition(definitions, handled_keywords, item.source_id, "BattleSystem battle-start left-item crit and Max Ammo aura")
			handled_keywords[EFFECT_AMMO] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_BATTLE_START, "left_item_crit", {"side": "self", "selector": "left_item"}, {"type": EFFECT_RUNTIME_BONUS, "bonus_key": "crit_rate", "amount": 100, "scope": "combat"}))
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_BATTLE_START, EFFECT_AMMO, {"side": "self", "selector": "left_item"}, {"type": EFFECT_AMMO, "amount": 1}))
		"bill_dozer":
			definitions.append(_p2b_runtime_bonus_definition(item.source_id, TRIGGER_ON_TAG_USED, {"side": "self", "selector": "this_item"}, {"bonus_key": EFFECT_DAMAGE, "amount_by_rarity": [10, 15, 30]}, {"tag": "Friend", "event_source_not_owner": true}))
		"cosmic_amulet", "thermal_lance", "sharkray":
			_append_runtime_marker_definition(definitions, handled_keywords, item.source_id, "BattleSystem on-Haste item runtime bonus")
		"death_caps":
			definitions.append(_p2b_runtime_bonus_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, {"side": "self", "selector": "matching_tag_items", "tag": "Poison"}, {"bonus_key": EFFECT_POISON, "amount_by_rarity": [0, 2, 4, 6]}))
		"dishwasher":
			definitions.append(_p2b_runtime_bonus_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, {"side": "self", "selector": "matching_tag_items", "tag": "Weapon"}, {"bonus_key": EFFECT_DAMAGE, "amount_by_rarity": [10, 20, 40, 80]}))
		"ethergy_conduit":
			definitions.append(_p2b_runtime_bonus_definition(item.source_id, TRIGGER_ON_ENEMY_STATUS_APPLIED, {"side": "self", "selector": "all_items"}, {"bonus_key": "crit_rate", "amount": 4}, {"status_type": EFFECT_POISON}))
		"forgotten_god":
			definitions.append(_p2b_runtime_bonus_definition(item.source_id, TRIGGER_ON_ENEMY_STATUS_APPLIED, {"side": "self", "selector": "this_item"}, {"bonus_key": EFFECT_POISON, "amount": 8}, {"status_type": EFFECT_SLOW, "event_source_is_adjacent": true}))
		"friendly_doll":
			definitions.append(_p2b_runtime_bonus_definition(item.source_id, TRIGGER_ON_BATTLE_START, {"side": "self", "selector": "this_item"}, {"bonus_key": "crit_rate", "amount_by_rarity": [50, 75, 100]}, {"player_tag_count_equals": {"tag": "Friend", "count": 1}}))
		"ganjo":
			for tag in ["Weapon", "Heal", "Shield"]:
				var bonus_key: String = EFFECT_DAMAGE if tag == "Weapon" else (EFFECT_HEAL if tag == "Heal" else EFFECT_SHIELD)
				definitions.append(_p2b_runtime_bonus_definition(item.source_id, TRIGGER_ON_BATTLE_START, {"side": "self", "selector": "adjacent_matching_tag_items", "tag": tag}, {"bonus_key": bonus_key, "amount_by_rarity": [10, 15, 20, 25]}, {}, "%s_runtime_bonus" % tag.to_lower()))
		"grindstone":
			definitions.append(_p2b_runtime_bonus_definition(item.source_id, TRIGGER_ON_BATTLE_START, {"side": "self", "selector": "left_matching_tag", "tag": "Weapon"}, {"bonus_key": EFFECT_DAMAGE, "amount_by_rarity": [0, 10, 20, 30]}))
		"honing_steel":
			definitions.append(_p2b_runtime_bonus_definition(item.source_id, TRIGGER_ON_BATTLE_START, {"side": "self", "selector": "right_matching_tag", "tag": "Weapon"}, {"bonus_key": EFFECT_DAMAGE, "amount_by_rarity": [8, 12, 16, 20]}))
		"ice_pick":
			definitions.append(_p2b_runtime_bonus_definition(item.source_id, TRIGGER_ON_ENEMY_STATUS_APPLIED, {"side": "self", "selector": "this_item"}, {"bonus_key": EFFECT_DAMAGE, "amount_by_rarity": [0, 15, 20, 25]}, {"status_type": EFFECT_FREEZE}))
		"infernal_greatsword":
			definitions.append(_p2b_runtime_bonus_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, {"side": "self", "selector": "this_item"}, {"bonus_key": EFFECT_DAMAGE, "amount_from": "enemy_status.burn"}, {}, EFFECT_RUNTIME_BONUS, "after_consume"))
		"jitte":
			definitions.append(_p2b_runtime_bonus_definition(item.source_id, TRIGGER_ON_ENEMY_STATUS_APPLIED, {"side": "self", "selector": "this_item"}, {"bonus_key": EFFECT_DAMAGE, "amount_by_rarity": [0, 10, 20, 30]}, {"status_type": EFFECT_SLOW}))
		"mantis_shrimp":
			definitions.append(_p2b_runtime_bonus_definition(item.source_id, TRIGGER_ON_ENEMY_STATUS_APPLIED, {"side": "self", "selector": "this_item"}, {"bonus_key": EFFECT_DAMAGE, "amount_by_rarity": [10, 15, 20, 25]}, {"status_type": EFFECT_SLOW}, "damage_runtime_bonus"))
			definitions.append(_p2b_runtime_bonus_definition(item.source_id, TRIGGER_ON_ENEMY_STATUS_APPLIED, {"side": "self", "selector": "this_item"}, {"bonus_key": EFFECT_BURN, "amount_by_rarity": [2, 4, 6, 8]}, {"status_type": EFFECT_SLOW}, "burn_runtime_bonus"))
		"nitrogen_hammer":
			definitions.append(_p2b_runtime_bonus_definition(item.source_id, TRIGGER_ON_ENEMY_STATUS_APPLIED, {"side": "self", "selector": "this_item"}, {"bonus_key": EFFECT_DAMAGE, "amount_by_rarity": [0, 50, 100, 200]}, {"status_type": EFFECT_FREEZE}))
		"old_saltclaw":
			definitions.append(_p2b_runtime_bonus_definition(item.source_id, TRIGGER_ON_ENEMY_STATUS_APPLIED, {"side": "self", "selector": "this_item"}, {"bonus_key": EFFECT_DAMAGE, "amount_by_rarity": [0, 5, 10, 15]}, {"status_type": EFFECT_SLOW}))
		"orbital_polisher":
			definitions.append(_p2b_runtime_bonus_definition(item.source_id, TRIGGER_ON_BATTLE_START, {"side": "self", "selector": "adjacent"}, {"bonus_key": EFFECT_DAMAGE, "amount_by_rarity": [0, 0, 5, 10]}, {}, "adjacent_damage_runtime_bonus"))
			definitions.append(_p2b_runtime_bonus_definition(item.source_id, TRIGGER_ON_BATTLE_START, {"side": "self", "selector": "adjacent"}, {"bonus_key": EFFECT_SHIELD, "amount_by_rarity": [0, 0, 5, 10]}, {}, "adjacent_shield_runtime_bonus"))
		"pickled_peppers":
			definitions.append(_p2b_runtime_bonus_definition(item.source_id, TRIGGER_ON_ENEMY_STATUS_APPLIED, {"side": "self", "selector": "this_item"}, {"bonus_key": EFFECT_BURN, "amount_by_rarity": [0, 0, 5, 10]}, {"status_type": EFFECT_BURN}))
		"red_piggles_r":
			definitions.append(_p2b_runtime_bonus_definition(item.source_id, TRIGGER_ON_BATTLE_START, {"side": "self", "selector": "right_matching_tag", "tag": "Weapon"}, {"bonus_key": EFFECT_DAMAGE, "amount_by_rarity": [4, 8, 12, 16]}))
		"red_piggles_x":
			definitions.append(_p2b_runtime_bonus_definition(item.source_id, TRIGGER_ON_BATTLE_START, {"side": "self", "selector": "matching_tag_items", "tag": "Weapon"}, {"bonus_key": EFFECT_DAMAGE, "amount_by_rarity": [1, 2, 3, 4]}))
		"runic_great_axe":
			definitions.append(_p2b_runtime_bonus_definition(item.source_id, TRIGGER_ON_BATTLE_START, {"side": "self", "selector": "lifesteal_weapon_items"}, {"bonus_key": "crit_rate", "amount": 100}))
		"salt":
			definitions.append(_p2b_runtime_bonus_definition(item.source_id, TRIGGER_ON_BATTLE_START, {"side": "self", "selector": "adjacent"}, {"bonus_key": "crit_rate", "amount_by_rarity": [0, 10, 15, 20]}))
		"sharkclaws":
			definitions.append(_p2b_runtime_bonus_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, {"side": "self", "selector": "other_matching_tag_items", "tag": "Weapon"}, {"bonus_key": EFFECT_DAMAGE, "amount_by_rarity": [10, 20, 30, 40]}))
		"silencer":
			definitions.append(_p2b_runtime_bonus_definition(item.source_id, TRIGGER_ON_BATTLE_START, {"side": "self", "selector": "left_matching_tag", "tag": "Weapon"}, {"bonus_key": EFFECT_DAMAGE, "amount_by_rarity": [10, 20, 30, 50]}))
		"slumbering_primordial":
			definitions.append(_p2b_runtime_bonus_definition(item.source_id, TRIGGER_ON_ENEMY_STATUS_APPLIED, {"side": "self", "selector": "this_item"}, {"bonus_key": EFFECT_DAMAGE, "amount_by_rarity": [0, 0, 75, 100]}, {"status_type_any": [EFFECT_POISON, EFFECT_FREEZE, EFFECT_BURN]}))
		"sunlight_spear":
			_append_runtime_marker_definition(definitions, handled_keywords, item.source_id, "BattleSystem battle-start/source Regeneration runtime")
		"torpedo":
			definitions.append(_p2b_runtime_bonus_definition(item.source_id, TRIGGER_ON_ITEM_USED, {"side": "self", "selector": "this_item"}, {"bonus_key": EFFECT_DAMAGE, "amount_by_rarity": [0, 30, 60, 90]}, {"event_source_not_owner": true, "event_source_any_tags": ["Aquatic", "Ammo"]}))
		"tropical_island":
			definitions.append(_p2b_runtime_bonus_definition(item.source_id, TRIGGER_ON_ENEMY_STATUS_APPLIED, {"side": "self", "selector": "this_item"}, {"bonus_key": EFFECT_REGENERATION, "amount_by_rarity": [0, 0, 5, 10]}, {"status_type": EFFECT_SLOW}))
		"wanted_poster":
			definitions.append(_p2b_runtime_bonus_definition(item.source_id, TRIGGER_ON_BATTLE_START, {"side": "self", "selector": "all_items"}, {"bonus_key": "crit_rate", "amount_by_rarity": [0, 10, 20, 30]}))
	if _definitions_handle_effect(definitions, EFFECT_RUNTIME_BONUS):
		handled_keywords[EFFECT_RUNTIME_BONUS] = true

static func _append_runtime_marker_definition(definitions: Array[Dictionary], handled_keywords: Dictionary, source_id: String, runtime_path: String) -> void:
	handled_keywords[EFFECT_RUNTIME_BONUS] = true
	if not _definitions_handle_effect(definitions, EFFECT_RUNTIME_BONUS):
		definitions.append(_runtime_bonus_marker(source_id, runtime_path))

static func _p2b_runtime_bonus_definition(source_id: String, trigger: String, target: Dictionary, runtime_effect: Dictionary, condition: Dictionary = {}, effect_name: String = EFFECT_RUNTIME_BONUS, timing: String = "") -> Dictionary:
	var effect: Dictionary = {"type": EFFECT_RUNTIME_BONUS, "scope": "combat"}
	for key in runtime_effect.keys():
		effect[key] = runtime_effect[key]
	return _hook_definition(source_id, trigger, effect_name, target, effect, condition, timing)

static func _append_p2b_confirmed_remainder_definitions(definitions: Array[Dictionary], handled_keywords: Dictionary, item: ItemDataClass) -> void:
	if item == null:
		return
	match item.source_id:
		"ethergy_conduit":
			handled_keywords[EFFECT_CHARGE] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_CRIT, EFFECT_CHARGE, {"side": "self", "selector": "matching_tag_items", "tag": "Relic"}, {"type": EFFECT_CHARGE, "amount": 1}, {"event_source_is_owner": true}))
		"eye_of_the_colossus":
			handled_keywords[EFFECT_CHARGE] = true
			definitions.append(_runtime_bonus_marker(item.source_id, "BattleSystem enemy item destruction runtime"))
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_ITEM_USED, EFFECT_CHARGE, {"side": "self", "selector": "this_item"}, {"type": EFFECT_CHARGE, "amount": 1}, {"event_source_is_adjacent": true}))
		"ice_cream_truck":
			handled_keywords[EFFECT_CHARGE] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_ITEM_USED, EFFECT_CHARGE, {"side": "self", "selector": "this_item"}, {"type": EFFECT_CHARGE, "amount": 1}, {"event_source_not_owner": true, "no_event_source_tag": "Weapon"}))
		"iceberg":
			handled_keywords[EFFECT_FREEZE] = true
			definitions.append(_trigger_condition_marker(item.source_id, EFFECT_FREEZE, "BattleSystem enemy item-use Freeze runtime"))
		"tripwire":
			handled_keywords[EFFECT_SLOW] = true
			definitions.append(_trigger_condition_marker(item.source_id, EFFECT_SLOW, "BattleSystem enemy item-use Slow runtime"))
		"void_shield":
			handled_keywords[EFFECT_BURN] = true
			_append_runtime_marker_definition(definitions, handled_keywords, item.source_id, "BattleSystem enemy item-use Burn runtime")
			definitions.append(_trigger_condition_marker(item.source_id, EFFECT_BURN, "BattleSystem enemy item-use Burn runtime"))
		"fire_bomb", "ice_bomb":
			handled_keywords[EFFECT_RELOAD] = true
			definitions.append(_trigger_condition_marker(item.source_id, EFFECT_RELOAD, "BattleSystem start-Flying self Reload runtime"))
		"flare_gun":
			handled_keywords[EFFECT_BURN] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_BURN, {"side": "enemy", "selector": "hero"}, {"type": EFFECT_BURN, "amount_by_rarity": [0, 0, 9, 0]}))
		"golf_clubs":
			handled_keywords[EFFECT_RUNTIME_BONUS] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_HEAL, EFFECT_RUNTIME_BONUS, {"side": "self", "selector": "this_item"}, {"type": EFFECT_RUNTIME_BONUS, "bonus_key": EFFECT_DAMAGE, "amount_by_rarity": [10, 20, 30, 40], "scope": "combat"}))
		"holsters":
			handled_keywords[EFFECT_HASTE] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_BATTLE_START, EFFECT_HASTE, {"side": "self", "selector": "matching_size_items", "size": "small"}, {"type": EFFECT_HASTE, "amount_by_rarity": [0, 1, 2, 2]}))
		"infernal_greatsword":
			handled_keywords[EFFECT_BURN] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_BURN, {"side": "enemy", "selector": "hero"}, {"type": EFFECT_BURN, "amount_from": "source.damage"}))
		"refractor":
			handled_keywords[EFFECT_RUNTIME_BONUS] = true
			handled_keywords[EFFECT_FREEZE] = true
			definitions.append(_trigger_condition_marker(item.source_id, EFFECT_FREEZE, "status-triggered runtime bonus handles Freeze text"))
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_ENEMY_STATUS_APPLIED, EFFECT_RUNTIME_BONUS, {"side": "self", "selector": "this_item"}, {"type": EFFECT_RUNTIME_BONUS, "bonus_key": EFFECT_DAMAGE, "amount_by_rarity": [10, 20, 30, 40], "scope": "combat"}, {"status_type_any": [EFFECT_SLOW, EFFECT_FREEZE, EFFECT_BURN, EFFECT_POISON]}))
		"ritual_dagger":
			handled_keywords[EFFECT_REGENERATION] = true
			_append_runtime_marker_definition(definitions, handled_keywords, item.source_id, "BattleSystem Damage-scaled Regen runtime")
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_REGENERATION, {"side": "self", "selector": "hero"}, {"type": EFFECT_REGENERATION, "amount_from": "source.damage"}))
		"soul_of_the_district":
			handled_keywords[EFFECT_SHIELD] = true
			handled_keywords[EFFECT_DAMAGE] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_SHIELD, {"side": "self", "selector": "hero"}, {"type": EFFECT_SHIELD, "amount_from": "hero.current_health"}))
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_COOLDOWN_READY, EFFECT_DAMAGE, {"side": "enemy", "selector": "hero"}, {"type": EFFECT_DAMAGE, "amount_from": "hero.shield"}, {}, "after_consume"))

static func _append_non_combat_hook_definitions(definitions: Array[Dictionary], handled_keywords: Dictionary, item: ItemDataClass) -> void:
	_append_sell_service_hook_definitions(definitions, handled_keywords, item)
	match item.source_id:
		"catalyst":
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_SELL, "transform", {"selector": "leftmost_small"}, {"type": "transform", "selector": "leftmost_small"}))
		"cinders":
			handled_keywords[EFFECT_BURN] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_SELL, EFFECT_BURN, {"selector": "leftmost_burn"}, {"type": EFFECT_BURN, "amount_by_rarity": [1, 2, 3, 4]}))
		"extract":
			handled_keywords[EFFECT_POISON] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_SELL, EFFECT_POISON, {"selector": "leftmost_poison"}, {"type": EFFECT_POISON, "amount_by_rarity": [1, 2, 3, 4]}))
		"scrap":
			handled_keywords[EFFECT_SHIELD] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_SELL, EFFECT_SHIELD, {"selector": "leftmost_shield"}, {"type": EFFECT_SHIELD, "amount_by_rarity": [3, 6, 12, 24]}))
		"med_kit":
			handled_keywords[EFFECT_HEAL] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_SELL, EFFECT_HEAL, {"selector": "leftmost_heal"}, {"type": EFFECT_HEAL, "amount_by_rarity": [5, 10, 20, 40]}))
		"eagle_talisman":
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_SELL, "crit", {"selector": "leftmost_item"}, {"type": "crit", "amount_by_rarity": [5, 10, 15, 20]}))
		"gland":
			handled_keywords[EFFECT_REGENERATION] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_SELL, EFFECT_REGENERATION, {"selector": "hero"}, {"type": EFFECT_REGENERATION, "amount_by_rarity": [1, 2, 3, 4]}))
		"philosophers_stone":
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_BUY, "grant_item", {"selector": "inventory"}, {"type": "grant_item", "item_id": "catalyst"}))
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_TRANSFORM, EFFECT_REGENERATION, {"selector": "this_item", "event_source_tag": "Reagent"}, {"type": EFFECT_REGENERATION, "amount_by_rarity": [2, 3, 4, 5]}))
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_ENCHANT, "enchant_observer", {"selector": "this_item"}, {"type": "enchant_observer"}))
		"atm":
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_BUY, "income", {"selector": "run"}, {"type": "income", "amount_by_rarity": [1, 2, 3, 5]}))
		"hatchet":
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_BUY, "grant_item", {"selector": "inventory"}, {"type": "grant_item", "item_id": "truffles"}))
		"lightbulb":
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_BUY, "grant_item", {"selector": "inventory"}, {"type": "grant_item", "item_id": "battery"}))
		"satchel":
			handled_keywords[EFFECT_REGENERATION] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_BUY, EFFECT_REGENERATION, {"selector": "this_item", "event_source_tag": "Potion"}, {"type": EFFECT_REGENERATION, "amount_by_rarity": [2, 4, 6]}))

	if item.source_id in ["aludel", "mortar_pestle", "mortar_and_pestle", "sifting_pan", "laboratory", "athanor", "apothecary"]:
		definitions.append(_hook_definition(item.source_id, TRIGGER_ON_HOUR_START, "grant_item", {"selector": "inventory"}, {"type": "grant_item", "item_id": "catalyst"}))

	match item.source_id:
		"alembic":
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_HOUR_START, "grant_item", {"selector": "inventory"}, {"type": "grant_item", "item_id": "catalyst"}))
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_HOUR_START, "transform", {"selector": "left_small_item"}, {"type": "transform", "item_id": "fire_potion"}))
		"calcinator", "retort":
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_HOUR_START, "spend_gold_grant_item", {"selector": "inventory"}, {"type": "grant_item", "item_id": "chunk_of_lead", "gold_cost": 3}))
		"the_tome_of_yyahan":
			handled_keywords[EFFECT_REGENERATION] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_HOUR_START, "grant_item", {"selector": "inventory"}, {"type": "grant_item", "item_id": "hemlock"}))
		"tropical_island":
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_HOUR_START, "grant_item", {"selector": "inventory"}, {"type": "grant_item", "item_id": "coconut"}))
		"piggles":
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_HOUR_START, "upgrade", {"selector": "piggle_item"}, {"type": "upgrade"}))

	if not item.enchantment_id.is_empty():
		definitions.append(_hook_definition(item.source_id, TRIGGER_ON_ENCHANT, "enchant", {"selector": "this_item"}, {"type": "enchant", "enchantment": item.enchantment_id}))

	var transform_enchantment: String = _transform_enchantment_for_item(item.source_id)
	if not transform_enchantment.is_empty():
		definitions.append(_hook_definition(item.source_id, TRIGGER_ON_TRANSFORM, "enchant", {"selector": "transformed_item"}, {"type": "enchant", "enchantment": transform_enchantment}))

	match item.source_id:
		"calcinator":
			handled_keywords[EFFECT_BURN] = true
			handled_keywords[EFFECT_RUNTIME_BONUS] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_TRANSFORM, EFFECT_RUNTIME_BONUS, {"selector": "this_item", "event_source_tag": "Reagent"}, {"type": EFFECT_RUNTIME_BONUS, "bonus_key": EFFECT_BURN, "amount_by_rarity": [3, 5, 7, 9], "scope": "permanent"}))
		"retort":
			handled_keywords[EFFECT_POISON] = true
			handled_keywords[EFFECT_RUNTIME_BONUS] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_TRANSFORM, EFFECT_RUNTIME_BONUS, {"selector": "this_item", "event_source_tag": "Reagent"}, {"type": EFFECT_RUNTIME_BONUS, "bonus_key": EFFECT_POISON, "amount_by_rarity": [3, 5, 7, 9], "scope": "permanent"}))
		"the_tome_of_yyahan":
			handled_keywords[EFFECT_REGENERATION] = true
			handled_keywords[EFFECT_RUNTIME_BONUS] = true
			definitions.append(_hook_definition(item.source_id, TRIGGER_ON_TRANSFORM, EFFECT_RUNTIME_BONUS, {"selector": "this_item", "event_source_tag": "Reagent"}, {"type": EFFECT_RUNTIME_BONUS, "bonus_key": EFFECT_REGENERATION, "amount_by_rarity": [4, 10, 15], "scope": "permanent"}))

static func _append_sell_service_hook_definitions(definitions: Array[Dictionary], handled_keywords: Dictionary, item: ItemDataClass) -> void:
	if item == null:
		return
	var source_id: String = item.source_id.to_lower()
	if source_id in ["bluenanas", "chocolate_bar", "coconut", "green_gumball", "vial_of_blood", "arken_s_ring", "eagle_talisman", "agility_boots", "blue_gumball", "feather", "gunpowder", "gearnola_bar", "rocket_boots", "snowflake"]:
		handled_keywords[EFFECT_RUNTIME_BONUS] = true
	if source_id == "landscraper":
		definitions.append(_hook_definition(source_id, TRIGGER_ON_SELL, "value_gain", {"selector": "this_item"}, {"type": "value_gain", "amount_by_rarity": [0, 0, 5, 10], "threshold": 10}))
	if source_id in ["bluenanas", "chocolate_bar", "coconut", "green_gumball"]:
		definitions.append(_hook_definition(source_id, TRIGGER_ON_SELL, "max_health", {"selector": "hero"}, {"type": "max_health"}))
	if source_id == "vial_of_blood":
		definitions.append(_hook_definition(source_id, TRIGGER_ON_SELL, "xp", {"selector": "hero"}, {"type": "xp"}))
	if source_id == "arken_s_ring":
		definitions.append(_hook_definition(source_id, TRIGGER_ON_SELL, "prestige", {"selector": "run"}, {"type": "prestige"}))
	if source_id in ["eagle_talisman", "agility_boots", "blue_gumball"]:
		definitions.append(_hook_definition(source_id, TRIGGER_ON_SELL, "crit", {"selector": "items"}, {"type": "crit"}))
	if source_id in ["magnifying_glass", "old_sword", "rune_axe", "sharpening_stone", "junkyard_club", "lifting_gloves", "red_gumball"]:
		handled_keywords[EFFECT_DAMAGE] = true
		definitions.append(_hook_definition(source_id, TRIGGER_ON_SELL, EFFECT_DAMAGE, {"selector": "weapon_items"}, {"type": EFFECT_DAMAGE}))
	if source_id in ["marble_scalemail", "scrap", "yellow_gumball"]:
		handled_keywords[EFFECT_SHIELD] = true
		definitions.append(_hook_definition(source_id, TRIGGER_ON_SELL, EFFECT_SHIELD, {"selector": "shield_items"}, {"type": EFFECT_SHIELD}))
	if source_id in ["hot_springs", "junkyard_repairbot", "med_kit"]:
		handled_keywords[EFFECT_HEAL] = true
		definitions.append(_hook_definition(source_id, TRIGGER_ON_SELL, EFFECT_HEAL, {"selector": "heal_items"}, {"type": EFFECT_HEAL}))
	if source_id in ["cinders", "salamander_pup"]:
		handled_keywords[EFFECT_BURN] = true
		definitions.append(_hook_definition(source_id, TRIGGER_ON_SELL, EFFECT_BURN, {"selector": "burn_items"}, {"type": EFFECT_BURN}))
	if source_id in ["extract", "trained_spider"]:
		handled_keywords[EFFECT_POISON] = true
		definitions.append(_hook_definition(source_id, TRIGGER_ON_SELL, EFFECT_POISON, {"selector": "poison_items"}, {"type": EFFECT_POISON}))
	if source_id in ["citrus", "gland"]:
		handled_keywords[EFFECT_REGENERATION] = true
		definitions.append(_hook_definition(source_id, TRIGGER_ON_SELL, EFFECT_REGENERATION, {"selector": "hero"}, {"type": EFFECT_REGENERATION}))
	if source_id in ["clockwork_blades", "insect_wing"]:
		definitions.append(_hook_definition(source_id, TRIGGER_ON_SELL, "cooldown_reduction", {"selector": "all_items"}, {"type": "cooldown_reduction"}))
	if source_id == "feather":
		definitions.append(_hook_definition(source_id, TRIGGER_ON_SELL, "cooldown_reduction", {"selector": "leftmost_item"}, {"type": "cooldown_reduction"}))
	if source_id == "gunpowder":
		definitions.append(_hook_definition(source_id, TRIGGER_ON_SELL, EFFECT_AMMO, {"selector": "leftmost_ammo"}, {"type": EFFECT_AMMO}))
	if source_id in ["upgrade_hammer", "magician_s_top_hat"]:
		definitions.append(_hook_definition(source_id, TRIGGER_ON_SELL, "upgrade", {"selector": "leftmost_item"}, {"type": "upgrade"}))
	if source_id == "safe":
		definitions.append(_hook_definition(source_id, TRIGGER_ON_SELL, "grant_item", {"selector": "inventory"}, {"type": "grant_item", "item_id": "spare_change"}))
	if source_id in ["dog", "improvised_bludgeon"]:
		handled_keywords[EFFECT_DAMAGE] = true
		definitions.append(_hook_definition(source_id, TRIGGER_ON_SELL, EFFECT_DAMAGE, {"selector": "self_or_slow_item"}, {"type": EFFECT_DAMAGE}))
	if source_id in ["temporary_shelter", "silk_scarf"]:
		handled_keywords[EFFECT_SHIELD] = true
		definitions.append(_hook_definition(source_id, TRIGGER_ON_SELL, EFFECT_SHIELD, {"selector": "self"}, {"type": EFFECT_SHIELD}))
	if source_id == "gearnola_bar":
		definitions.append(_hook_definition(source_id, TRIGGER_ON_SELL, EFFECT_AMMO, {"selector": "self"}, {"type": EFFECT_AMMO}))
	if source_id == "sifting_pan":
		handled_keywords[EFFECT_REGENERATION] = true
		definitions.append(_hook_definition(source_id, TRIGGER_ON_SELL, EFFECT_REGENERATION, {"selector": "hero"}, {"type": EFFECT_REGENERATION}))
	if source_id in ["rocket_boots", "snowflake"]:
		definitions.append(_hook_definition(source_id, TRIGGER_ON_SELL, "duration_bonus", {"selector": "leftmost_status_item"}, {"type": "duration_bonus"}))
	if source_id == "vat_of_acid":
		definitions.append(_hook_definition(source_id, TRIGGER_ON_SELL, "type_gain", {"selector": "this_item"}, {"type": "type_gain"}))
	if source_id == "genie_lamp":
		definitions.append(_hook_definition(source_id, TRIGGER_ON_SELL, "service_unlock", {"selector": "run"}, {"type": "service_unlock", "service_id": "genie_rit"}))
	if source_id == "thieves_guild_medallion":
		definitions.append(_hook_definition(source_id, TRIGGER_ON_SELL, "service_unlock", {"selector": "run"}, {"type": "service_unlock", "service_id": "thieves_guild"}))

static func _definitions_handle_effect(definitions: Array[Dictionary], effect_type: String) -> bool:
	for definition_variant in definitions:
		if not definition_variant is Dictionary:
			continue
		var effect_data: Dictionary = (definition_variant as Dictionary).get("effect", {})
		if str(effect_data.get("type", "")) == effect_type:
			return true
	return false

static func _runtime_bonus_marker(source_id: String, runtime_path: String) -> Dictionary:
	return {
		"id": "%s_runtime_bonus_supported" % source_id,
		"trigger": "",
		"target": {"selector": "runtime_service"},
		"effect": {"type": EFFECT_RUNTIME_BONUS, "runtime_path": runtime_path},
	}

static func _trigger_condition_marker(source_id: String, effect_type: String, runtime_path: String) -> Dictionary:
	return {
		"id": "%s_%s_trigger_condition_supported" % [source_id, effect_type],
		"trigger": "",
		"target": {"selector": "runtime_service"},
		"effect": {"type": effect_type, "runtime_path": runtime_path},
	}

static func _runtime_bonus_runtime_path(source_id: String) -> String:
	match source_id:
		"emerald", "ruby":
			return "BattleSystem passive combat aura"
		"nightshade", "leeches", "refractor", "fireflies", "frozen_flame", "ice_claw", "magnus_femur", "magic_carpet", "goggles":
			return "BattleSystem reactive combat runtime bonus"
		"bluenanas", "chocolate_bar", "coconut", "green_gumball", "vial_of_blood", "arken_s_ring", "eagle_talisman", "agility_boots", "blue_gumball", "feather", "gunpowder", "gearnola_bar", "rocket_boots", "snowflake":
			return "SellService permanent sell mutation"
		"cinders", "extract", "gland", "junkyard_club", "med_kit", "sharpening_stone", "trained_spider":
			return "SellService permanent targeted stat mutation"
		"gatling_gun":
			return "BattleSystem cooldown multicast, fight Crit Chance, and first-use cooldown runtime"
		"incense", "venomous_dose":
			return "BattleSystem root status and fight Regen effects"
		"satchel":
			return "ItemAcquisition permanent Potion buy mutation and BattleSystem reload regen"
		"tazidian_dagger", "boiling_flask":
			return "BattleSystem item aura runtime bonus"
		"incendiary_rounds", "jellyfish":
			return "BattleSystem adjacent item-use and battle-start item runtime bonus"
		"lockbox":
			return "BattleSystem fight-win value gain and Value-scaled weapon Damage runtime"
		"amber", "blue_piggles_l", "cosmic_plumage", "elemental_depth_charge", "fire_claw", "hot_sauce", "nargile", "pesky_pete", "poppy_field", "seaweed", "spices":
			return "BattleSystem high-frequency item runtime bonus"
		"flagship", "illusoray", "pulse_rifle", "skillet", "snow_globe", "weather_glass", "z_sword":
			return "BattleSystem multicast DSL handles source has/gains +Multicast text"
		"rapid_injection_system":
			return "BattleSystem adjacent item-use self-poison and regeneration runtime"
		"ouroboros_statue":
			return "BattleSystem poison-triggered fight Regen runtime"
		"anchor":
			return "BattleSystem enemy-health Damage and adjacent-use Haste runtime"
		"barbed_wire":
			return "BattleSystem shield-triggered fight Damage runtime"
		"black_rose":
			return "BattleSystem poison-triggered fight Regeneration runtime"
		"frozen_bludgeon":
			return "BattleSystem freeze-triggered weapon Damage runtime"
		"soul_ring":
			return "BattleSystem battle-start Regen and Regen-scaled poison runtime"
		"thurible":
			return "BattleSystem root Burn and fight Regeneration effects"
		"venomander":
			return "BattleSystem root Poison and fight Regeneration effects"
		"void_ray":
			return "BattleSystem cooldown multicast and shield-triggered Burn runtime"
		"electric_eels", "pufferfish":
			return "BattleSystem source-backed charge trigger runtime"
		"genie_lamp", "thieves_guild_medallion":
			return "SellService service unlock"
	return ""

static func _hook_definition(source_id: String, trigger: String, effect_name: String, target: Dictionary, effect: Dictionary, condition: Dictionary = {}, timing: String = "") -> Dictionary:
	var definition: Dictionary = {
		"id": "%s_%s_%s" % [source_id, trigger, effect_name],
		"trigger": trigger,
		"target": target,
		"effect": effect,
	}
	if not condition.is_empty():
		definition["condition"] = condition
	if not timing.is_empty():
		definition["timing"] = timing
	return definition

static func _transform_enchantment_for_item(source_id: String) -> String:
	match source_id:
		"death_caps", "hemlock", "nightshade":
			return "toxic"
		"mothmeal":
			return "heavy"
		"myrrh":
			return "restorative"
		"shard_of_obsidian":
			return "obsidian"
		"sulphur":
			return "fiery"
	return ""

static func collect_item_warnings(
	item: ItemDataClass,
	definitions: Array[Dictionary]
) -> Array[String]:
	var warnings: Array[String] = []
	if item == null:
		return warnings

	var handled_keywords: Dictionary = {}
	var handled_triggers: Dictionary = {}
	for definition in definitions:
		if not definition is Dictionary:
			continue
		var definition_data := definition as Dictionary
		var trigger: String = str(definition_data.get("trigger", ""))
		if not trigger.is_empty():
			handled_triggers[trigger] = true
		var effect_data: Dictionary = definition_data.get("effect", {})
		var effect_type: String = str(effect_data.get("type", ""))
		if not effect_type.is_empty():
			handled_keywords[effect_type] = true

	if item.has_ammo_limit():
		handled_keywords[EFFECT_AMMO] = true

	if item.source_id == "barbed_claws":
		handled_keywords[EFFECT_POISON] = true

	for tag in item.tags:
		match str(tag):
			"DamageReference":
				handled_keywords[EFFECT_DAMAGE] = true
			"ShieldReference":
				handled_keywords[EFFECT_SHIELD] = true
			"HealReference":
				handled_keywords[EFFECT_HEAL] = true
			"BurnReference":
				handled_keywords[EFFECT_BURN] = true
			"PoisonReference":
				handled_keywords[EFFECT_POISON] = true
			"RegenReference":
				handled_keywords[EFFECT_REGENERATION] = true
			"SlowReference":
				handled_keywords[EFFECT_SLOW] = true
			"HasteReference":
				handled_keywords[EFFECT_HASTE] = true

	var effect_text: String = item.source_effect_text.to_lower()
	for trigger in _HOOK_KEYWORD_MATCHERS.keys():
		if handled_triggers.has(trigger):
			continue
		for matcher in _HOOK_KEYWORD_MATCHERS[trigger]:
			if effect_text.contains(str(matcher).to_lower()):
				warnings.append("unsupported_item_trigger:%s:%s" % [item.source_id, trigger])
				break

	for keyword in _PRIORITY_KEYWORD_MATCHERS.keys():
		if handled_keywords.has(keyword):
			continue
		for matcher in _PRIORITY_KEYWORD_MATCHERS[keyword]:
			if _effect_text_matches(effect_text, keyword, str(matcher).to_lower()):
				warnings.append("unsupported_item_effect:%s:%s" % [item.source_id, keyword])
				break
	return warnings

static func _effect_text_matches(effect_text: String, keyword: String, matcher: String) -> bool:
	if matcher.is_empty():
		return false
	if keyword == EFFECT_HEAL and matcher == "heal":
		return _contains_whole_word(effect_text, matcher)
	return effect_text.contains(matcher)

static func _contains_whole_word(text: String, word: String) -> bool:
	var regex := RegEx.new()
	var err: Error = regex.compile("(^|[^a-z0-9_])%s([^a-z0-9_]|$)" % word)
	if err != OK:
		return text.contains(word)
	return regex.search(text) != null

static func get_item_warning_reason(item: ItemDataClass, warning: String) -> String:
	var parts: PackedStringArray = str(warning).split(":")
	var family: String = parts[0] if parts.size() > 0 else ""
	var detail: String = parts[2] if parts.size() > 2 else ""
	var item_id: String = "" if item == null else item.source_id
	if family == "unsupported_item_trigger":
		match detail:
			TRIGGER_ON_SELL:
				if item_id == "landscraper":
					return "Landscraper needs a persistent per-item sell counter for the 10-sells value threshold before it can be claimed supported"
				return "sell hook has no dedicated SellService mapping yet for %s" % item_id
			TRIGGER_ON_BUY:
				return "buy hook has no ItemAcquisition mapping yet for %s" % item_id
			TRIGGER_ON_HOUR_START:
				return "day/hour-start generation or spend behavior needs a RunState/ItemAcquisition mapping for %s" % item_id
			TRIGGER_ON_TRANSFORM:
				return "transform hook needs a SellService transform mapping for %s" % item_id
		return "trigger family is recognized but not implemented for this item"
	if family == "unsupported_item_effect":
		match detail:
			EFFECT_RUNTIME_BONUS:
				return "conditional or permanent stat scaling requires item-specific runtime-bonus semantics"
			EFFECT_MULTICAST:
				return "multicast text needs item-specific trigger and cap semantics"
			EFFECT_CHARGE:
				return "charge target/trigger is ambiguous without item-specific selector support"
			EFFECT_RELOAD:
				return "reload target/trigger is ambiguous without ammo selector support"
			EFFECT_DAMAGE, EFFECT_SHIELD, EFFECT_HEAL, EFFECT_BURN, EFFECT_POISON, EFFECT_REGENERATION, EFFECT_SLOW, EFFECT_HASTE, EFFECT_FREEZE:
				return "base value is parsed only when source numeric fields are present; text-only scaling still needs item-specific semantics"
		return "effect family is recognized but unsupported for this item"
	return "warning family is unknown to the item warning reporter"

static func is_known_item_warning_family(warning: String) -> bool:
	var parts: PackedStringArray = str(warning).split(":")
	if parts.size() < 3:
		return false
	var family: String = parts[0]
	var detail: String = parts[2]
	if family == "unsupported_item_trigger":
		return detail in _SUPPORTED_ITEM_WARNING_TRIGGERS
	if family == "unsupported_item_effect":
		return detail in _SUPPORTED_ITEM_WARNING_EFFECTS
	return false

static func _append_root_value_effect(
	definitions: Array[Dictionary],
	handled_keywords: Dictionary,
	item: ItemDataClass,
	definition_id: String,
	effect_type: String,
	target_side: String,
	target_selector: String,
	amount_from: String
) -> void:
	if item == null:
		return
	match effect_type:
		EFFECT_DAMAGE:
			if item.damage <= 0:
				return
		EFFECT_SHIELD:
			if item.shield <= 0:
				return
		EFFECT_HEAL:
			if item.heal <= 0:
				return
		EFFECT_POISON:
			if item.poison_damage <= 0.0:
				return
		EFFECT_BURN:
			if item.burn_damage <= 0.0:
				return
		EFFECT_REGENERATION:
			if item.regeneration <= 0.0:
				return
		_:
			return

	handled_keywords[effect_type] = true
	definitions.append({
		"id": definition_id,
		"trigger": TRIGGER_ON_COOLDOWN_READY,
		"target": {"side": target_side, "selector": target_selector},
		"effect": {
			"type": effect_type,
			"amount_from": amount_from,
			"crit_scaled": true,
		},
	})

static func _append_root_cooldown_effect(
	definitions: Array[Dictionary],
	handled_keywords: Dictionary,
	item: ItemDataClass,
	definition_id: String,
	effect_type: String,
	target_side: String,
	target_selector: String,
	count_from: String,
	amount_from: String
) -> void:
	if item == null:
		return
	match effect_type:
		EFFECT_SLOW:
			if item.slow_count <= 0 or item.slow_duration <= 0.0:
				return
		EFFECT_FREEZE:
			if item.freeze_count <= 0 or item.freeze_duration <= 0.0:
				return
		EFFECT_HASTE:
			if item.haste_count <= 0 or item.haste_duration <= 0.0:
				return
		_:
			return

	handled_keywords[effect_type] = true
	definitions.append({
		"id": definition_id,
		"trigger": TRIGGER_ON_COOLDOWN_READY,
		"target": {
			"side": target_side,
			"selector": target_selector,
			"count_from": count_from,
		},
		"effect": {
			"type": effect_type,
			"amount_from": amount_from,
			"crit_scaled": true,
			"count_crit_scaled": true,
		},
	})
