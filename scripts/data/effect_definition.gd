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
	EFFECT_MULTICAST: ["multicast"],
}

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
		"candles":
			handled_keywords[EFFECT_CHARGE] = true
			definitions.append({
				"id": "candles_on_small_item_charge",
				"trigger": TRIGGER_ON_ITEM_USED,
				"condition": {"event_source_size": "small"},
				"target": {"side": "self", "selector": "this_item"},
				"effect": {"type": EFFECT_CHARGE, "amount": 2.0},
			})
		"duct_tape":
			definitions.append({
				"id": "duct_tape_on_left_item_shield",
				"trigger": TRIGGER_ON_ITEM_USED,
				"condition": {"event_source_relation": "left_adjacent"},
				"target": {"side": "self", "selector": "hero"},
				"effect": {"type": EFFECT_SHIELD, "amount_from": "source.shield"},
			})
		"infinite_potion":
			handled_keywords[EFFECT_RELOAD] = true
			definitions.append({
				"id": "infinite_potion_root_reload_self",
				"trigger": TRIGGER_ON_COOLDOWN_READY,
				"timing": "after_consume",
				"target": {"side": "self", "selector": "this_item"},
				"effect": {"type": EFFECT_RELOAD, "amount": 1},
			})
		"quill_and_ink":
			handled_keywords[EFFECT_MULTICAST] = true
			definitions.append({
				"id": "quill_and_ink_no_other_weapon_multicast",
				"trigger": TRIGGER_ON_COOLDOWN_READY,
				"condition": {"no_other_tag": "Weapon"},
				"target": {"side": "self", "selector": "this_item"},
				"effect": {"type": EFFECT_MULTICAST, "amount": 1},
			})
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

	return definitions

static func collect_item_warnings(
	item: ItemDataClass,
	definitions: Array[Dictionary]
) -> Array[String]:
	var warnings: Array[String] = []
	if item == null:
		return warnings

	var handled_keywords: Dictionary = {}
	for definition in definitions:
		if not definition is Dictionary:
			continue
		var effect_data: Dictionary = (definition as Dictionary).get("effect", {})
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
			"HasteReference":
				handled_keywords[EFFECT_HASTE] = true

	var effect_text: String = item.source_effect_text.to_lower()
	for keyword in _PRIORITY_KEYWORD_MATCHERS.keys():
		if handled_keywords.has(keyword):
			continue
		for matcher in _PRIORITY_KEYWORD_MATCHERS[keyword]:
			if effect_text.contains(str(matcher).to_lower()):
				warnings.append("unsupported_item_effect:%s:%s" % [item.source_id, keyword])
				break
	return warnings

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
