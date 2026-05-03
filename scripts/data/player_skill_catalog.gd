class_name PlayerSkillCatalog
extends RefCounted

const SkillDataClass = preload("res://scripts/data/skill_data.gd")
const WikiMonsterCatalogClass = preload("res://scripts/data/wiki_monster_catalog.gd")
const EffectDefinitionClass = preload("res://scripts/data/effect_definition.gd")

const SUPPORT_IMPLEMENTED := "implemented"
const SUPPORT_UNSUPPORTED := "unsupported"
const SUPPORT_UNKNOWN := "unknown"

const _SKILLS_CONFIG_PATH := "res://scripts/data/skills_config.json"
const _TIER_INDEX := {
	"bronze": 0,
	"silver": 1,
	"gold": 2,
	"diamond": 3,
}

const _NUMERIC_SKILL_RULES := {
	"deadly_eye": {
		"values": [5.0, 10.0, 15.0, 20.0],
		"starting_tier": "bronze",
		"build_skill_data": false,
	},
	"fiery": {
		"effect_type": SkillDataClass.EffectType.BURN,
		"values": [1.0, 2.0, 3.0, 4.0],
		"starting_tier": "bronze",
	},
	"gunner": {
		"values": [1.0, 2.0, 3.0],
		"starting_tier": "silver",
		"build_skill_data": false,
	},
	"ammo_stash": {
		"values": [1.0, 2.0, 3.0],
		"starting_tier": "silver",
		"build_skill_data": false,
	},
	"improved_toxins": {
		"effect_type": SkillDataClass.EffectType.POISON,
		"values": [1.0, 2.0, 3.0, 4.0],
		"starting_tier": "bronze",
	},
	"keen_eye": {
		"effect_type": SkillDataClass.EffectType.CRIT,
		"values": [4.0, 8.0, 12.0, 16.0],
		"starting_tier": "bronze",
	},
	"quick_defenses": {
		"effect_type": SkillDataClass.EffectType.COOLDOWN,
		"values": [5.0, 7.0, 10.0, 15.0],
		"starting_tier": "bronze",
	},
	"toughness": {
		"effect_type": SkillDataClass.EffectType.SHIELD,
		"values": [10.0, 15.0, 20.0, 25.0],
		"starting_tier": "bronze",
	},
	"large_appetites": {
		"effect_type": SkillDataClass.EffectType.HEALTH,
		"values": [500.0, 1000.0, 1500.0, 2000.0],
		"starting_tier": "bronze",
	},
	"strength": {
		"values": [10.0, 15.0, 20.0, 25.0],
		"starting_tier": "bronze",
		"build_skill_data": false,
	},
	"left_handed": {
		"values": [20.0, 30.0, 40.0, 50.0],
		"starting_tier": "bronze",
		"build_skill_data": false,
	},
	"right_handed": {
		"values": [20.0, 30.0, 40.0, 50.0],
		"starting_tier": "bronze",
		"build_skill_data": false,
	},
	"initial_dose": {
		"values": [2.0, 4.0, 6.0, 8.0],
		"starting_tier": "bronze",
		"build_skill_data": false,
	},
	"vital_reserve": {
		"values": [2.0, 4.0, 6.0, 8.0],
		"starting_tier": "bronze",
		"build_skill_data": false,
	},
	"reaching_the_summit": {
		"values": [3.0, 6.0],
		"starting_tier": "gold",
		"build_skill_data": false,
	},
	"purifying_flame": {
		"values": [1.0, 2.0],
		"starting_tier": "gold",
		"build_skill_data": false,
	},
	"slow_and_steady": {
		"values": [2.0, 4.0, 6.0],
		"starting_tier": "silver",
		"build_skill_data": false,
	},
	"slowed_targets": {
		"values": [1.0, 2.0, 3.0],
		"starting_tier": "silver",
		"build_skill_data": false,
	},
	"snowstorm": {
		"values": [2.0, 4.0, 6.0, 8.0],
		"starting_tier": "bronze",
		"build_skill_data": false,
	},
	"tracer_fire": {
		"values": [1.0, 2.0, 3.0],
		"starting_tier": "silver",
		"build_skill_data": false,
	},
	"trained": {
		"values": [5.0, 10.0, 15.0, 20.0],
		"starting_tier": "bronze",
		"build_skill_data": false,
	},
}

const _TRIGGER_SKILL_RULES := {
	"heated_shells": {
		"values": [2.0, 3.0, 4.0],
		"starting_tier": "silver",
	},
	"insect_bite": {"values": [2.0], "starting_tier": "diamond"},
	"invigorating_cold": {"values": [2.0], "counts": [1.0, 2.0, 3.0], "starting_tier": "silver"},
	"lash_out": {"values": [3.0, 6.0, 9.0, 12.0], "starting_tier": "bronze"},
	"paralytic_poison": {
		"values": [2.0, 3.0, 4.0],
		"starting_tier": "silver",
	},
	"paralyzing_rush": {"values": [1.0, 2.0], "starting_tier": "gold"},
	"poison_tyrant": {"values": [2.0, 4.0, 6.0, 8.0], "starting_tier": "bronze"},
	"pyromania": {"values": [10.0, 15.0], "starting_tier": "gold"},
	"regenerative": {"values": [10.0, 20.0, 30.0], "starting_tier": "silver"},
	"rush": {"values": [3.0, 4.0, 5.0, 6.0], "starting_tier": "bronze"},
	"rust": {"values": [3.0, 4.0, 5.0, 6.0], "starting_tier": "bronze"},
	"shored_up": {"values": [1.0], "starting_tier": "diamond"},
	"slow_burn": {
		"limits": [5.0, 10.0],
		"charge_seconds": [1.0, 1.0],
		"starting_tier": "gold",
	},
	"small_refresh": {"values": [5.0, 10.0, 15.0, 20.0], "starting_tier": "bronze"},
	"thick_hide": {"values": [1.0], "starting_tier": "diamond"},
	"time_to_tinker": {"values": [10.0, 20.0, 30.0, 40.0], "starting_tier": "bronze"},
	"tools_of_the_trade": {"values": [1.0, 1.0], "limits": [5.0, 10.0], "starting_tier": "gold"},
	"toxic_friendship": {"values": [1.0, 2.0], "starting_tier": "gold"},
	"trickle_down_economics": {"values": [3.0, 4.0], "starting_tier": "gold"},
	"unwavering": {"values": [20.0, 40.0], "starting_tier": "gold"},
	"valley_fever": {"values": [2.0], "starting_tier": "diamond"},
	"void_energy": {"values": [1.0], "starting_tier": "diamond"},
	"void_rage": {"values": [1.0, 2.0], "starting_tier": "gold"},
	"warm_hugs": {"values": [2.0, 3.0], "starting_tier": "gold"},
}

const _EXPLICIT_UNSUPPORTED_SKILL_RULES := {
	"initial_chill": {
		"reason": "phase1_freeze_bonus_runtime_not_verified",
	},
}

static var _skills_config_loaded: bool = false
static var _skills_config_entries: Array[Dictionary] = []
static var _skills_config_by_id: Dictionary = {}
static var _warned_unsupported_queries: Dictionary = {}

static func resolve_skill_refs(skill_refs: Array) -> Array[Dictionary]:
	var resolved: Array[Dictionary] = []
	for skill_ref in skill_refs:
		var entry: Dictionary = get_skill_entry(skill_ref)
		if not entry.is_empty():
			resolved.append(entry)
	return resolved

static func get_skill_entry(skill_ref: Variant) -> Dictionary:
	if skill_ref == null:
		return {}
	if skill_ref is SkillDataClass:
		return _build_entry_from_skill_data(skill_ref as SkillDataClass)

	var skill_id: String = ""
	var raw_tier: Variant = null
	if skill_ref is Dictionary:
		var entry: Dictionary = skill_ref as Dictionary
		skill_id = str(entry.get("id", entry.get("skill_id", ""))).strip_edges().to_lower()
		raw_tier = entry.get("tier", entry.get("rarity", null))
	elif skill_ref is String:
		skill_id = str(skill_ref).strip_edges().to_lower()
	else:
		return {}

	if skill_id.is_empty():
		return {}
	return _build_entry_from_skill_id(skill_id, raw_tier)

static func normalize_skill_ref(skill_ref: Variant) -> Dictionary:
	return get_skill_entry(skill_ref)

static func build_skill_data(skill_ref: Variant) -> SkillDataClass:
	var resolved: Dictionary = _resolve_catalog_entry(skill_ref)
	if resolved.is_empty():
		return null
	if str(resolved.get("support_status", SUPPORT_UNKNOWN)) != SUPPORT_IMPLEMENTED:
		return null
	var numeric_rule: Dictionary = resolved.get("numeric_rule", {})
	if numeric_rule.is_empty():
		return null
	if not bool(numeric_rule.get("build_skill_data", true)):
		return null

	var values: Array = numeric_rule.get("values", [])
	if values.is_empty():
		return null

	var skill: SkillDataClass = SkillDataClass.new()
	skill.id = str(resolved.get("id", ""))
	skill.skill_name = str(resolved.get("name", skill.id))
	skill.description = str(resolved.get("description", ""))
	skill.rarity = clampi(int(resolved.get("tier_index", 0)), 0, 3)
	skill.effect_type = int(numeric_rule.get("effect_type", SkillDataClass.EffectType.CRIT))
	skill.effect_values = _expand_values(values, int(resolved.get("starting_tier_index", 0)))
	return skill

static func get_skill_display_name(skill_ref: Variant) -> String:
	var resolved: Dictionary = _resolve_catalog_entry(skill_ref)
	return "" if resolved.is_empty() else str(resolved.get("name", ""))

static func get_tier_value(skill_ref: Variant, field: String = "values", fallback: float = 0.0) -> float:
	var resolved: Dictionary = _resolve_catalog_entry(skill_ref)
	if resolved.is_empty():
		return fallback

	var support_status: String = str(resolved.get("support_status", SUPPORT_UNKNOWN))
	var source_rule: Dictionary = resolved.get("trigger_rule", {})
	if source_rule.is_empty() or not source_rule.has(field):
		source_rule = resolved.get("numeric_rule", {})
	if source_rule.is_empty():
		if support_status == SUPPORT_UNSUPPORTED:
			_warn_unsupported_value_query(
				str(resolved.get("id", "")),
				field,
				str(resolved.get("unsupported_reason", ""))
			)
		elif support_status == SUPPORT_UNKNOWN:
			_warn_unknown_value_query(str(resolved.get("id", "")), field)
		return fallback

	var values: Array = source_rule.get(field, [])
	if values.is_empty():
		return fallback

	var start_tier: int = clampi(int(resolved.get("starting_tier_index", 0)), 0, 3)
	var tier_index: int = clampi(int(resolved.get("tier_index", start_tier)), 0, 3)
	if tier_index < start_tier:
		return fallback
	var offset: int = clampi(tier_index - start_tier, 0, values.size() - 1)
	return float(values[offset])

static func get_effect_definitions(skill_ref: Variant) -> Array[Dictionary]:
	var resolved: Dictionary = _resolve_catalog_entry(skill_ref)
	if resolved.is_empty():
		return []
	if str(resolved.get("support_status", SUPPORT_UNKNOWN)) != SUPPORT_IMPLEMENTED:
		return []

	var skill_id: String = str(resolved.get("id", ""))
	match skill_id:
		"heated_shells":
			return [_skill_definition("heated_shells_on_ammo_burn", EffectDefinitionClass.TRIGGER_ON_ITEM_USED, EffectDefinitionClass.EFFECT_BURN, get_tier_value(resolved), {"side": "enemy", "selector": "hero"}, {"event_source_has_ammo": true})]
		"insect_bite":
			return [_skill_definition("insect_bite_battle_start_self_poison", EffectDefinitionClass.TRIGGER_ON_BATTLE_START, EffectDefinitionClass.EFFECT_POISON, get_tier_value(resolved), {"side": "self", "selector": "hero"})]
		"invigorating_cold":
			return [_skill_definition("invigorating_cold_on_freeze_haste_items", EffectDefinitionClass.TRIGGER_ON_ENEMY_STATUS_APPLIED, EffectDefinitionClass.EFFECT_HASTE, get_tier_value(resolved), {"side": "self", "selector": "slowest_items", "count": int(round(get_tier_value(resolved, "counts")))}, {"status_type": EffectDefinitionClass.EFFECT_FREEZE}, 1)]
		"lash_out":
			return [_skill_definition("lash_out_battle_start_poison", EffectDefinitionClass.TRIGGER_ON_BATTLE_START, EffectDefinitionClass.EFFECT_POISON, get_tier_value(resolved), {"side": "enemy", "selector": "hero"})]
		"paralytic_poison":
			return [_skill_definition("paralytic_poison_on_first_poison_freeze", EffectDefinitionClass.TRIGGER_ON_ENEMY_STATUS_APPLIED, EffectDefinitionClass.EFFECT_FREEZE, get_tier_value(resolved), {"side": "enemy", "selector": "slowest_items", "count": 1}, {"status_type": EffectDefinitionClass.EFFECT_POISON}, 1)]
		"paralyzing_rush":
			return [_skill_definition("paralyzing_rush_on_slow_haste_weapon", EffectDefinitionClass.TRIGGER_ON_ENEMY_STATUS_APPLIED, EffectDefinitionClass.EFFECT_HASTE, get_tier_value(resolved), {"side": "self", "selector": "matching_tag_highest_cooldown", "tag": "Weapon", "count": 1}, {"status_type": EffectDefinitionClass.EFFECT_SLOW})]
		"poison_tyrant":
			return [_skill_definition("poison_tyrant_on_poison_regeneration", EffectDefinitionClass.TRIGGER_ON_ENEMY_STATUS_APPLIED, EffectDefinitionClass.EFFECT_REGENERATION, get_tier_value(resolved), {"side": "self", "selector": "hero"}, {"status_type": EffectDefinitionClass.EFFECT_POISON})]
		"pyromania":
			return [_skill_definition("pyromania_on_large_item_burn", EffectDefinitionClass.TRIGGER_ON_ITEM_USED, EffectDefinitionClass.EFFECT_BURN, get_tier_value(resolved), {"side": "enemy", "selector": "hero"}, {"event_source_size": "large"})]
		"regenerative":
			return [_skill_definition("regenerative_battle_start_regeneration", EffectDefinitionClass.TRIGGER_ON_BATTLE_START, EffectDefinitionClass.EFFECT_REGENERATION, get_tier_value(resolved), {"side": "self", "selector": "hero"})]
		"rush":
			return [_skill_definition("rush_first_item_haste_weapon", EffectDefinitionClass.TRIGGER_ON_ITEM_USED, EffectDefinitionClass.EFFECT_HASTE, get_tier_value(resolved), {"side": "self", "selector": "matching_tag_highest_cooldown", "tag": "Weapon", "count": 1}, {}, 1)]
		"rust":
			return [_skill_definition("rust_first_item_slow_enemy", EffectDefinitionClass.TRIGGER_ON_ITEM_USED, EffectDefinitionClass.EFFECT_SLOW, get_tier_value(resolved), {"side": "enemy", "selector": "slowest_items", "count": 1}, {}, 1)]
		"shored_up":
			return [_skill_definition("shored_up_on_heal_charge_shield_item", EffectDefinitionClass.TRIGGER_ON_HEAL, EffectDefinitionClass.EFFECT_CHARGE, get_tier_value(resolved), {"side": "self", "selector": "matching_tag_highest_cooldown", "tag": "Shield", "count": 1})]
		"slow_burn":
			return [_skill_definition("slow_burn_on_slow_charge", EffectDefinitionClass.TRIGGER_ON_ENEMY_STATUS_APPLIED, EffectDefinitionClass.EFFECT_CHARGE, get_tier_value(resolved, "charge_seconds"), {"side": "self", "selector": "matching_tag_highest_cooldown", "tag": "Burn", "count": 1}, {"status_type": EffectDefinitionClass.EFFECT_SLOW}, int(round(get_tier_value(resolved, "limits"))))]
		"small_refresh":
			return [_skill_definition("small_refresh_on_small_item_heal", EffectDefinitionClass.TRIGGER_ON_ITEM_USED, EffectDefinitionClass.EFFECT_HEAL, get_tier_value(resolved), {"side": "self", "selector": "hero"}, {"event_source_size": "small"})]
		"thick_hide":
			return [_skill_definition("thick_hide_on_slow_charge_item", EffectDefinitionClass.TRIGGER_ON_ENEMY_STATUS_APPLIED, EffectDefinitionClass.EFFECT_CHARGE, get_tier_value(resolved), {"side": "self", "selector": "slowest_items", "count": 1}, {"status_type": EffectDefinitionClass.EFFECT_SLOW})]
		"time_to_tinker":
			return [_skill_definition("time_to_tinker_on_haste_shield", EffectDefinitionClass.TRIGGER_ON_ENEMY_STATUS_APPLIED, EffectDefinitionClass.EFFECT_SHIELD, get_tier_value(resolved), {"side": "self", "selector": "hero"}, {"status_type": EffectDefinitionClass.EFFECT_HASTE})]
		"tools_of_the_trade":
			return [_skill_definition("tools_of_the_trade_on_tool_haste_tool", EffectDefinitionClass.TRIGGER_ON_TAG_USED, EffectDefinitionClass.EFFECT_HASTE, get_tier_value(resolved), {"side": "self", "selector": "matching_tag_highest_cooldown", "tag": "Tool", "count": 1}, {"tag": "Tool"}, int(round(get_tier_value(resolved, "limits"))))]
		"toxic_friendship":
			return [_skill_definition("toxic_friendship_on_friend_poison", EffectDefinitionClass.TRIGGER_ON_TAG_USED, EffectDefinitionClass.EFFECT_POISON, get_tier_value(resolved), {"side": "enemy", "selector": "hero"}, {"tag": "Friend"})]
		"trickle_down_economics":
			return [_skill_definition("trickle_down_economics_on_large_item_haste", EffectDefinitionClass.TRIGGER_ON_ITEM_USED, EffectDefinitionClass.EFFECT_HASTE, get_tier_value(resolved), {"side": "self", "selector": "slowest_other_items", "count": 1}, {"event_source_size": "large"})]
		"unwavering":
			return [_skill_definition("unwavering_on_item_used_shield", EffectDefinitionClass.TRIGGER_ON_ITEM_USED, EffectDefinitionClass.EFFECT_SHIELD, get_tier_value(resolved), {"side": "self", "selector": "hero"})]
		"valley_fever":
			return [_skill_definition("valley_fever_battle_start_self_burn", EffectDefinitionClass.TRIGGER_ON_BATTLE_START, EffectDefinitionClass.EFFECT_BURN, get_tier_value(resolved), {"side": "self", "selector": "hero"})]
		"void_energy":
			return [_skill_definition("void_energy_on_burn_charge_shield_item", EffectDefinitionClass.TRIGGER_ON_ENEMY_STATUS_APPLIED, EffectDefinitionClass.EFFECT_CHARGE, get_tier_value(resolved), {"side": "self", "selector": "matching_tag_highest_cooldown", "tag": "Shield", "count": 1}, {"status_type": EffectDefinitionClass.EFFECT_BURN})]
		"void_rage":
			return [_skill_definition("void_rage_on_burn_haste_item", EffectDefinitionClass.TRIGGER_ON_ENEMY_STATUS_APPLIED, EffectDefinitionClass.EFFECT_HASTE, get_tier_value(resolved), {"side": "self", "selector": "slowest_items", "count": 1}, {"status_type": EffectDefinitionClass.EFFECT_BURN})]
		"warm_hugs":
			return [_skill_definition("warm_hugs_on_friend_burn", EffectDefinitionClass.TRIGGER_ON_TAG_USED, EffectDefinitionClass.EFFECT_BURN, get_tier_value(resolved), {"side": "enemy", "selector": "hero"}, {"tag": "Friend"})]
	return []

static func _skill_definition(
	definition_id: String,
	trigger: String,
	effect_type: String,
	amount: float,
	target: Dictionary,
	condition: Dictionary = {},
	max_triggers_per_fight: int = 0
) -> Dictionary:
	var definition: Dictionary = {
		"id": definition_id,
		"trigger": trigger,
		"target": target,
		"effect": {"type": effect_type, "amount": amount},
	}
	if not condition.is_empty():
		definition["condition"] = condition
	if max_triggers_per_fight > 0:
		definition["max_triggers_per_fight"] = max_triggers_per_fight
	return definition

static func get_effect_warnings(skill_ref: Variant) -> Array[String]:
	var resolved: Dictionary = _resolve_catalog_entry(skill_ref)
	if resolved.is_empty():
		return []
	if str(resolved.get("support_status", SUPPORT_UNKNOWN)) != SUPPORT_UNSUPPORTED:
		return []
	return [
		"unsupported_skill_effect:%s:%s"
		% [str(resolved.get("id", "")), str(resolved.get("unsupported_reason", ""))]
	]

static func get_registered_skill_ids() -> Array[String]:
	_ensure_skills_config_cache()
	var ids: Array[String] = []
	for entry in _skills_config_entries:
		ids.append(str(entry.get("skill_id", "")).to_lower())
	return _sorted_unique(ids)

static func get_wiki_skill_ids() -> Array[String]:
	var ids: Array[String] = []
	for spec in WikiMonsterCatalogClass.get_skill_specs():
		if not spec is Dictionary:
			continue
		ids.append(str((spec as Dictionary).get("id", "")).to_lower())
	return _sorted_unique(ids)

static func get_monster_referenced_skill_ids() -> Array[String]:
	var ids: Array[String] = []
	for monster_spec in WikiMonsterCatalogClass.get_monster_specs():
		if not monster_spec is Dictionary:
			continue
		for skill_id in (monster_spec as Dictionary).get("skill_ids", []):
			ids.append(str(skill_id).to_lower())
	return _sorted_unique(ids)

static func get_known_skill_ids() -> Array[String]:
	var ids: Array[String] = []
	ids.append_array(get_registered_skill_ids())
	ids.append_array(get_wiki_skill_ids())
	ids.append_array(get_monster_referenced_skill_ids())
	for skill_id in _NUMERIC_SKILL_RULES.keys():
		ids.append(str(skill_id).to_lower())
	for skill_id in _TRIGGER_SKILL_RULES.keys():
		ids.append(str(skill_id).to_lower())
	for skill_id in _EXPLICIT_UNSUPPORTED_SKILL_RULES.keys():
		ids.append(str(skill_id).to_lower())
	return _sorted_unique(ids)

static func get_coverage_report() -> Dictionary:
	var registered_ids: Array[String] = get_registered_skill_ids()
	var wiki_ids: Array[String] = get_wiki_skill_ids()
	var referenced_ids: Array[String] = get_monster_referenced_skill_ids()
	var known_ids: Array[String] = get_known_skill_ids()
	var implemented_ids: Array[String] = []
	var unsupported_ids: Array[String] = []
	var unknown_ids: Array[String] = []
	var unsupported_registered_ids: Array[String] = []
	var implemented_registered_ids: Array[String] = []

	for skill_id in known_ids:
		var entry: Dictionary = get_skill_entry(skill_id)
		match str(entry.get("support_status", SUPPORT_UNKNOWN)):
			SUPPORT_IMPLEMENTED:
				implemented_ids.append(skill_id)
				if registered_ids.has(skill_id):
					implemented_registered_ids.append(skill_id)
			SUPPORT_UNSUPPORTED:
				unsupported_ids.append(skill_id)
				if registered_ids.has(skill_id):
					unsupported_registered_ids.append(skill_id)
			_:
				unknown_ids.append(skill_id)

	return {
		"registered_ids": registered_ids,
		"wiki_skill_ids": wiki_ids,
		"monster_referenced_skill_ids": referenced_ids,
		"known_skill_ids": known_ids,
		"implemented_ids": implemented_ids,
		"unsupported_ids": unsupported_ids,
		"unknown_ids": unknown_ids,
		"implemented_registered_ids": implemented_registered_ids,
		"unsupported_registered_ids": unsupported_registered_ids,
		"registered_count": registered_ids.size(),
		"wiki_skill_count": wiki_ids.size(),
		"monster_referenced_count": referenced_ids.size(),
		"known_count": known_ids.size(),
		"implemented_count": implemented_ids.size(),
		"unsupported_count": unsupported_ids.size(),
		"unknown_count": unknown_ids.size(),
	}

static func _expand_values(values: Array, start_tier_index: int) -> Array[float]:
	var expanded: Array[float] = [0.0, 0.0, 0.0, 0.0]
	var safe_start: int = clampi(start_tier_index, 0, 3)
	for offset in range(values.size()):
		var tier_index: int = safe_start + offset
		if tier_index < 0 or tier_index >= expanded.size():
			break
		expanded[tier_index] = float(values[offset])
	return expanded

static func _tier_index(raw_tier: Variant) -> int:
	if raw_tier is int:
		var int_value: int = int(raw_tier)
		if int_value >= 1 and int_value <= 4:
			return int_value - 1
		return clampi(int_value, 0, 3)
	var tier_name: String = str(raw_tier).strip_edges().to_lower()
	return int(_TIER_INDEX.get(tier_name, 0))

static func _resolve_tier_index(raw_tier: Variant, default_index: int) -> int:
	if raw_tier == null:
		return clampi(default_index, 0, 3)
	return _tier_index(raw_tier)

static func _build_entry_from_skill_data(data: SkillDataClass) -> Dictionary:
	if data == null or data.id.is_empty():
		return {}
	return {
		"id": data.id.to_lower(),
		"name": data.skill_name,
		"description": data.description,
		"tier_index": clampi(int(data.rarity), 0, 3),
		"starting_tier_index": 0,
		"tags": [],
		"numeric_rule": {
			"effect_type": int(data.effect_type),
			"values": data.effect_values.duplicate(),
			"starting_tier": "bronze",
		},
		"trigger_rule": {},
		"support_status": SUPPORT_IMPLEMENTED,
		"unsupported_reason": "",
		"implementation_kind": "skill_data_instance",
		"sources": ["skill_data_instance"],
	}

static func _build_entry_from_skill_id(skill_id: String, raw_tier: Variant) -> Dictionary:
	var config_spec: Dictionary = _find_skills_config_entry(skill_id)
	var wiki_spec: Dictionary = WikiMonsterCatalogClass.find_skill_spec(skill_id)
	var monster_referenced: bool = get_monster_referenced_skill_ids().has(skill_id)
	var numeric_rule: Dictionary = _duplicate_rule(_NUMERIC_SKILL_RULES.get(skill_id, {}))
	var trigger_rule: Dictionary = _duplicate_rule(_TRIGGER_SKILL_RULES.get(skill_id, {}))
	var unsupported_rule: Dictionary = _duplicate_rule(_EXPLICIT_UNSUPPORTED_SKILL_RULES.get(skill_id, {}))
	var sources: Array[String] = []
	if not config_spec.is_empty():
		sources.append("skills_config")
	if not wiki_spec.is_empty():
		sources.append("wiki_skill_spec")
	if monster_referenced:
		sources.append("monster_skill_reference")
	if not numeric_rule.is_empty():
		sources.append("numeric_rule")
	if not trigger_rule.is_empty():
		sources.append("trigger_rule")
	if not unsupported_rule.is_empty():
		sources.append("explicit_unsupported")

	var support_status: String = SUPPORT_UNKNOWN
	var unsupported_reason: String = ""
	var implementation_kind: String = SUPPORT_UNKNOWN
	if not numeric_rule.is_empty() or not trigger_rule.is_empty():
		support_status = SUPPORT_IMPLEMENTED
		if not trigger_rule.is_empty():
			implementation_kind = "trigger_rule"
		elif bool(numeric_rule.get("build_skill_data", true)):
			implementation_kind = "numeric_rule"
		else:
			implementation_kind = "battle_runtime_numeric"
	elif not unsupported_rule.is_empty():
		support_status = SUPPORT_UNSUPPORTED
		unsupported_reason = str(unsupported_rule.get("reason", "phase1_catalog_rule_missing"))
		implementation_kind = "explicit_unsupported"
	elif not config_spec.is_empty() or not wiki_spec.is_empty():
		support_status = SUPPORT_UNSUPPORTED
		unsupported_reason = "phase1_catalog_rule_missing"
		implementation_kind = "implicit_unsupported"
	elif monster_referenced:
		support_status = SUPPORT_UNSUPPORTED
		unsupported_reason = "monster_skill_reference_missing_spec"
		implementation_kind = "referenced_without_spec"

	var default_tier_index: int = _tier_index(
		numeric_rule.get(
			"starting_tier",
			trigger_rule.get(
				"starting_tier",
				wiki_spec.get("starting_tier", config_spec.get("starting_tier", "bronze"))
			)
		)
	)
	return {
		"id": skill_id,
		"name": str(wiki_spec.get("name", config_spec.get("skill_name", _titleize_skill_id(skill_id)))),
		"description": str(wiki_spec.get("effect", config_spec.get("description", ""))),
		"tier_index": _resolve_tier_index(raw_tier, default_tier_index),
		"starting_tier_index": default_tier_index,
		"tags": wiki_spec.get("tags", []),
		"numeric_rule": numeric_rule,
		"trigger_rule": trigger_rule,
		"support_status": support_status,
		"unsupported_reason": unsupported_reason,
		"implementation_kind": implementation_kind,
		"sources": sources,
	}

static func _ensure_skills_config_cache() -> void:
	if _skills_config_loaded:
		return
	_skills_config_loaded = true
	_skills_config_entries.clear()
	_skills_config_by_id.clear()

	var file: FileAccess = FileAccess.open(_SKILLS_CONFIG_PATH, FileAccess.READ)
	if file == null:
		push_warning("PlayerSkillCatalog failed to open %s" % _SKILLS_CONFIG_PATH)
		return

	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("PlayerSkillCatalog failed to parse %s: %s" % [
			_SKILLS_CONFIG_PATH,
			json.get_error_message(),
		])
		return

	var raw_entries: Variant = json.get_data()
	if not raw_entries is Array:
		push_warning("PlayerSkillCatalog expected an Array in %s" % _SKILLS_CONFIG_PATH)
		return

	for raw_entry in raw_entries:
		if not raw_entry is Dictionary:
			continue
		var entry: Dictionary = (raw_entry as Dictionary).duplicate(true)
		var skill_id: String = str(entry.get("skill_id", entry.get("id", ""))).strip_edges().to_lower()
		if skill_id.is_empty():
			continue
		entry["skill_id"] = skill_id
		_skills_config_entries.append(entry)
		_skills_config_by_id[skill_id] = entry

static func _find_skills_config_entry(skill_id: String) -> Dictionary:
	_ensure_skills_config_cache()
	if not _skills_config_by_id.has(skill_id):
		return {}
	return (_skills_config_by_id.get(skill_id, {}) as Dictionary).duplicate(true)

static func _duplicate_rule(rule: Variant) -> Dictionary:
	if not rule is Dictionary:
		return {}
	return (rule as Dictionary).duplicate(true)

static func _resolve_catalog_entry(skill_ref: Variant) -> Dictionary:
	if skill_ref is Dictionary:
		var entry: Dictionary = skill_ref as Dictionary
		if entry.has("support_status") and entry.has("id"):
			return entry
	return get_skill_entry(skill_ref)

static func _sorted_unique(ids: Array[String]) -> Array[String]:
	var seen: Dictionary = {}
	var ordered: Array[String] = []
	for skill_id in ids:
		var normalized_id: String = str(skill_id).strip_edges().to_lower()
		if normalized_id.is_empty() or seen.has(normalized_id):
			continue
		seen[normalized_id] = true
		ordered.append(normalized_id)
	ordered.sort()
	return ordered

static func _warn_unsupported_value_query(skill_id: String, field: String, reason: String) -> void:
	if skill_id.is_empty():
		return
	var warning_key: String = "%s:%s" % [skill_id, field]
	if _warned_unsupported_queries.has(warning_key):
		return
	_warned_unsupported_queries[warning_key] = true
	var safe_reason: String = reason if not reason.is_empty() else "phase1_catalog_rule_missing"
	push_warning(
		"PlayerSkillCatalog queried unsupported skill value: %s field=%s reason=%s"
		% [skill_id, field, safe_reason]
	)

static func _warn_unknown_value_query(skill_id: String, field: String) -> void:
	if skill_id.is_empty():
		return
	var warning_key: String = "unknown:%s:%s" % [skill_id, field]
	if _warned_unsupported_queries.has(warning_key):
		return
	_warned_unsupported_queries[warning_key] = true
	push_warning("PlayerSkillCatalog queried unknown skill value: %s field=%s" % [skill_id, field])

static func _titleize_skill_id(skill_id: String) -> String:
	var words: PackedStringArray = skill_id.split("_", false)
	for index in range(words.size()):
		words[index] = words[index].capitalize()
	return " ".join(words)
