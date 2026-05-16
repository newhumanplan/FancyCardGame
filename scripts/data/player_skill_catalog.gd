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
	"adaptive_ordinance": {"values": [2.0, 4.0, 6.0], "starting_tier": "silver", "build_skill_data": false},
	"all_talk": {"values": [25.0, 50.0], "starting_tier": "gold", "build_skill_data": false},
	"arms_race": {"values": [2.0, 3.0], "starting_tier": "gold", "build_skill_data": false},
	"augmented_defenses": {"values": [1.0], "starting_tier": "gold", "build_skill_data": false},
	"augmented_weaponry": {"values": [1.0], "starting_tier": "gold", "build_skill_data": false},
	"command_ship": {"values": [10.0, 15.0, 20.0], "starting_tier": "silver", "build_skill_data": false},
	"dual_wield": {"values": [50.0], "starting_tier": "diamond", "build_skill_data": false},
	"friend_zone": {"values": [5.0], "starting_tier": "gold", "build_skill_data": false},
	"full_arsenal": {"values": [5.0, 10.0], "starting_tier": "gold", "build_skill_data": false},
	"guardian_s_fury": {"values": [20.0], "starting_tier": "gold", "build_skill_data": false},
	"hyper_focus": {"values": [30.0], "starting_tier": "bronze", "build_skill_data": false},
	"one_shot_one_kill": {"values": [50.0], "starting_tier": "diamond", "build_skill_data": false},
	"the_right_tool": {"values": [5.0, 10.0, 15.0], "starting_tier": "silver", "build_skill_data": false},
	"waters_of_infinity": {"values": [20.0, 30.0, 40.0], "starting_tier": "silver", "build_skill_data": false},
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
		"critical_aid": {
			"values": [5.0, 10.0, 15.0, 20.0],
			"starting_tier": "bronze",
			"build_skill_data": false,
		},
		"diamond_fangs": {
			"values": [20.0, 30.0, 40.0, 50.0],
			"starting_tier": "bronze",
			"build_skill_data": false,
		},
		"exposing_toxins": {
			"values": [1.0, 2.0, 3.0],
			"starting_tier": "silver",
			"build_skill_data": false,
		},
		"extreme_comfort": {
			"values": [1.0, 2.0, 3.0, 4.0],
			"starting_tier": "bronze",
			"build_skill_data": false,
		},
		"final_flame": {
			"values": [2.0, 4.0, 6.0, 8.0],
			"starting_tier": "bronze",
			"build_skill_data": false,
		},
		"first_responder": {
			"values": [20.0, 35.0, 50.0, 65.0],
			"starting_tier": "bronze",
			"build_skill_data": false,
		},
		"flamedancer": {
			"values": [5.0, 10.0, 15.0, 20.0],
			"starting_tier": "bronze",
			"build_skill_data": false,
		},
		"follow_up_care": {
			"values": [20.0, 35.0, 50.0, 65.0],
			"starting_tier": "bronze",
			"build_skill_data": false,
		},
		"frontal_shielding": {
			"values": [20.0, 30.0, 40.0, 50.0],
			"starting_tier": "bronze",
			"build_skill_data": false,
		},
		"big_ego": {
			"values": [1.0],
			"starting_tier": "diamond",
			"build_skill_data": false,
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
		"burning_rage": {
			"values": [2.0, 4.0, 6.0, 8.0],
			"starting_tier": "bronze",
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
		"vengeance": {
			"values": [5.0, 10.0, 15.0],
			"starting_tier": "silver",
			"build_skill_data": false,
		},
	}

const _TRIGGER_SKILL_RULES := {
	"aggressive": {"values": [2.0, 4.0, 6.0, 8.0], "starting_tier": "bronze"},
	"ambush": {"values": [15.0, 30.0], "starting_tier": "gold"},
	"anything_to_win": {"values": [1.0, 2.0, 3.0], "starting_tier": "silver"},
	"assault_focus": {"values": [2.0, 4.0], "starting_tier": "gold"},
	"beautiful_friendship": {"values": [3.0, 6.0], "starting_tier": "gold"},
	"blizzard": {"values": [2.0, 3.0], "starting_tier": "gold"},
	"crashing_waves": {"values": [1.0, 1.0], "limits": [5.0, 10.0], "starting_tier": "gold"},
	"distributed_systems": {"values": [2.0, 3.0], "counts": [2.0, 3.0], "starting_tier": "gold"},
	"draconic_rage": {"values": [15.0], "starting_tier": "diamond"},
	"electrified_hull": {"values": [1.0, 1.0], "limits": [4.0, 8.0], "starting_tier": "gold"},
	"flashy_mechanic": {"values": [3.0, 6.0, 9.0], "starting_tier": "silver"},
	"flashy_reload": {"values": [1.0], "starting_tier": "diamond"},
	"chilling_touch": {"values": [3.0, 5.0, 7.0], "starting_tier": "silver"},
	"fiery_rebirth": {"values": [1.0], "starting_tier": "bronze"},
	"foreboding_winds": {"values": [2.0, 4.0], "starting_tier": "gold"},
	"hard_shell": {"values": [20.0, 30.0, 40.0, 50.0], "starting_tier": "bronze"},
	"hunker_down": {"values": [30.0, 50.0, 80.0], "starting_tier": "silver"},
	"hypnotic_drain": {"values": [2.0], "starting_tier": "diamond"},
	"jack_of_all_trades": {"values": [1.0], "limits": [5.0], "starting_tier": "gold"},
	"juggler": {"values": [1.0], "starting_tier": "diamond"},
	"jury_rigger": {"values": [1.0, 2.0, 3.0], "starting_tier": "silver"},
	"neophiliac": {"values": [2.0, 3.0], "starting_tier": "gold"},
	"parting_shot": {"values": [5.0, 10.0], "starting_tier": "gold"},
	"retool": {"values": [1.0], "starting_tier": "diamond"},
	"rigged": {"values": [1.0, 2.0, 3.0], "starting_tier": "silver"},
	"sharpened_steel": {"values": [4.0, 8.0, 12.0], "starting_tier": "silver"},
	"wake_up_call": {"values": [1.0], "starting_tier": "diamond"},
		"heated_shells": {
			"values": [2.0, 3.0, 4.0],
			"starting_tier": "silver",
		},
		"heat_lover": {"values": [2.0, 4.0, 6.0, 8.0], "starting_tier": "bronze"},
		"insect_bite": {"values": [2.0], "starting_tier": "diamond"},
		"invigorating_cold": {"values": [2.0], "counts": [1.0, 2.0, 3.0], "starting_tier": "silver"},
		"lash_out": {"values": [3.0, 6.0, 9.0, 12.0], "starting_tier": "bronze"},
	"paralytic_poison": {
		"values": [2.0, 3.0, 4.0],
		"starting_tier": "silver",
	},
	"overheal_haste": {"values": [2.0, 4.0], "starting_tier": "gold"},
	"paralyzing_rush": {"values": [1.0, 2.0], "starting_tier": "gold"},
	"petrifying_gaze": {"values": [1.0, 2.0, 3.0], "starting_tier": "silver"},
	"poison_tyrant": {"values": [2.0, 4.0, 6.0, 8.0], "starting_tier": "bronze"},
	"pyromania": {"values": [10.0, 15.0], "starting_tier": "gold"},
		"regenerative": {"values": [10.0, 20.0, 30.0], "starting_tier": "silver"},
		"rush": {"values": [3.0, 4.0, 5.0, 6.0], "starting_tier": "bronze"},
		"rust": {"values": [3.0, 4.0, 5.0, 6.0], "starting_tier": "bronze"},
		"equivalent_exchange": {"values": [1.0], "starting_tier": "diamond"},
		"firestarter": {"values": [17.0, 25.0, 35.0], "starting_tier": "silver"},
		"cosmic_wind": {"values": [1.0, 2.0, 3.0], "starting_tier": "silver"},
		"cryomastery": {"values": [1.0, 1.0], "limits": [3.0, 6.0], "starting_tier": "gold"},
		"flurry_of_blows": {"values": [1.0, 1.0], "limits": [4.0, 8.0], "starting_tier": "gold"},
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
	"aerial_assault": {"reason": "flying_state_runtime_not_modelled_for_item_start_flying"},
	"ancient_vengeance": {"reason": "enemy_weapon_use_reactive_relic_charge_not_modelled_for_player_skill_runtime"},
	"bonk": {"reason": "cooldowns_as_dynamic_scalar_text_unresolved"},
	"burst_of_flame": {"reason": "first_enemy_below_half_health_trigger_not_modelled"},
	"chilling_touch": {"reason": "first_freeze_all_enemy_items_trigger_needs_global_status_event_batching"},
	"clean_storefront": {"reason": "combat_value_bonus_runtime_not_modelled"},
	"counterstrike": {"reason": "enemy_weapon_use_limited_counter_trigger_not_modelled"},
	"desperate_cleanse": {"reason": "first_self_below_half_health_cleanse_runtime_not_modelled"},
	"expert_pilot": {"reason": "vehicle_damage_and_shield_percent_aura_not_modelled"},
	"fiery_rebirth": {"reason": "death_prevention_heal_to_full_runtime_not_modelled"},
	"free_ride": {"reason": "rightmost_item_vehicle_override_and_vehicle_cooldown_aura_not_modelled"},
	"hard_shell": {"reason": "first_self_below_half_health_shield_percent_trigger_not_modelled"},
	"haunting_flight": {"reason": "flying_state_runtime_not_modelled_for_small_items"},
	"heavy_weaponry": {"reason": "missing_official_skill_text_only_monster_reference_available"},
	"hunker_down": {"reason": "first_self_below_half_health_shield_percent_trigger_not_modelled"},
	"initial_chill": {"reason": "freeze_bonus_runtime_not_verified"},
	"into_the_void": {"reason": "temporary_board_item_destruction_not_modelled"},
	"jack_of_all_trades_duplicate": {"reason": "duplicate_monster_skill_id_requires_canonical_merge_with_jack_of_all_trades"},
	"master_salesman": {"reason": "combat_value_multiplier_runtime_not_modelled"},
	"nanobot_construction": {"reason": "large_item_cooldown_reduction_per_small_item_percent_text_unresolved"},
	"panic": {"reason": "first_self_below_half_health_reload_items_trigger_not_modelled"},
	"passive_power": {"reason": "no_cooldown_item_multi_stat_percent_aura_not_modelled"},
	"petrifying_gaze": {"reason": "first_self_below_half_health_freeze_all_enemy_items_trigger_not_modelled"},
	"pickpocket": {"reason": "battle_start_gold_reward_runtime_not_modelled_in_battle_system"},
	"power_broker": {"reason": "weapon_damage_from_income_runtime_aura_not_modelled"},
	"precision_tools": {"reason": "tool_hasted_event_permanent_damage_bonus_not_modelled"},
	"product_showcase": {"reason": "ammo_depleted_adjacent_charge_trigger_not_modelled"},
	"prosperity": {"reason": "shield_bonus_from_total_item_value_runtime_aura_not_modelled"},
	"ravenous": {"reason": "first_self_below_half_health_temporary_destroy_item_not_modelled"},
	"relax_bro": {"reason": "crit_chance_trigger_text_unresolved"},
	"siphoned_shielding": {"reason": "shield_bonus_from_enemy_poison_runtime_aura_not_modelled"},
	"sparring_partner_skill": {"reason": "death_prevention_cleanse_double_max_health_and_enemy_gold_not_modelled"},
	"titanium_casing": {"reason": "the_core_use_trigger_and_shield_item_bonus_not_modelled"},
	"toxic_fuel": {"reason": "poisoned_side_conditional_cooldown_percent_aura_not_modelled"},
	"trader": {"reason": "persistent_item_value_bonus_not_modelled_for_skills"},
	"void_render": {"reason": "combat_destroy_item_trigger_weapon_and_burn_bonus_not_modelled"},
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
		"aggressive":
			return [_skill_definition("aggressive_on_weapon_crit_source", EffectDefinitionClass.TRIGGER_ON_TAG_USED, EffectDefinitionClass.EFFECT_RUNTIME_BONUS, get_tier_value(resolved), {"side": "self", "selector": "source_item"}, {"tag": "Weapon"}, 0, {"bonus_key": "crit_rate"})]
		"ambush":
			return [_skill_definition("ambush_battle_start_enemy_max_health_damage", EffectDefinitionClass.TRIGGER_ON_BATTLE_START, EffectDefinitionClass.EFFECT_DAMAGE, 0.0, {"side": "enemy", "selector": "hero"}, {}, 0, {"amount_from": "enemy.max_health_percent", "percent": get_tier_value(resolved) / 100.0})]
		"anything_to_win":
			return [
				_skill_definition("anything_to_win_non_weapon_burn", EffectDefinitionClass.TRIGGER_ON_ITEM_USED, EffectDefinitionClass.EFFECT_BURN, get_tier_value(resolved), {"side": "enemy", "selector": "hero"}, {"no_event_source_tag": "Weapon"}),
				_skill_definition("anything_to_win_non_weapon_poison", EffectDefinitionClass.TRIGGER_ON_ITEM_USED, EffectDefinitionClass.EFFECT_POISON, get_tier_value(resolved), {"side": "enemy", "selector": "hero"}, {"no_event_source_tag": "Weapon"}),
			]
		"assault_focus":
			return [_skill_definition("assault_focus_non_weapon_slow_source", EffectDefinitionClass.TRIGGER_ON_ITEM_USED, EffectDefinitionClass.EFFECT_SLOW, get_tier_value(resolved), {"side": "self", "selector": "source_item"}, {"no_event_source_tag": "Weapon"})]
		"beautiful_friendship":
			return [_skill_definition("beautiful_friendship_friend_buffs_weapons", EffectDefinitionClass.TRIGGER_ON_TAG_USED, EffectDefinitionClass.EFFECT_RUNTIME_BONUS, get_tier_value(resolved), {"side": "self", "selector": "matching_tag_items", "tag": "Weapon"}, {"tag": "Friend"}, 0, {"bonus_key": "damage"})]
		"blizzard":
			return [_skill_definition("blizzard_first_item_freeze_non_weapons", EffectDefinitionClass.TRIGGER_ON_ITEM_USED, EffectDefinitionClass.EFFECT_FREEZE, get_tier_value(resolved), {"side": "self", "selector": "non_matching_tag_items", "tag": "Weapon"}, {}, 1)]
		"crashing_waves":
			return [_skill_definition("crashing_waves_aquatic_haste_weapon", EffectDefinitionClass.TRIGGER_ON_TAG_USED, EffectDefinitionClass.EFFECT_HASTE, get_tier_value(resolved), {"side": "self", "selector": "matching_tag_highest_cooldown", "tag": "Weapon", "count": 1}, {"tag": "Aquatic"}, int(round(get_tier_value(resolved, "limits"))))]
		"distributed_systems":
			return [_skill_definition("distributed_systems_large_haste_small", EffectDefinitionClass.TRIGGER_ON_ITEM_USED, EffectDefinitionClass.EFFECT_HASTE, get_tier_value(resolved), {"side": "self", "selector": "matching_size_highest_cooldown", "size": "small", "count": int(round(get_tier_value(resolved, "counts")))}, {"event_source_size": "large"})]
		"draconic_rage":
			return [_skill_definition("draconic_rage_medium_burn_bonus", EffectDefinitionClass.TRIGGER_ON_ITEM_USED, EffectDefinitionClass.EFFECT_RUNTIME_BONUS, get_tier_value(resolved), {"side": "self", "selector": "matching_tag_items", "tag": "Burn"}, {"event_source_size": "medium"}, 0, {"bonus_key": "burn"})]
		"electrified_hull":
			return [_skill_definition("electrified_hull_on_shield_charge", EffectDefinitionClass.TRIGGER_ON_SHIELD_GAINED, EffectDefinitionClass.EFFECT_CHARGE, get_tier_value(resolved), {"side": "self", "selector": "slowest_items", "count": 1}, {}, int(round(get_tier_value(resolved, "limits"))))]
		"flashy_mechanic":
			return [_skill_definition("flashy_mechanic_tool_adjacent_crit", EffectDefinitionClass.TRIGGER_ON_TAG_USED, EffectDefinitionClass.EFFECT_RUNTIME_BONUS, get_tier_value(resolved), {"side": "self", "selector": "adjacent_to_source"}, {"tag": "Tool"}, 0, {"bonus_key": "crit_rate"})]
		"flashy_reload":
			return [_skill_definition("flashy_reload_on_crit_reload_ammo", EffectDefinitionClass.TRIGGER_ON_CRIT, EffectDefinitionClass.EFFECT_RELOAD, get_tier_value(resolved), {"side": "self", "selector": "ammo_items", "count": 1})]
		"foreboding_winds":
			return [_skill_definition("foreboding_winds_any_item_crit", EffectDefinitionClass.TRIGGER_ON_ITEM_USED, EffectDefinitionClass.EFFECT_RUNTIME_BONUS, get_tier_value(resolved), {"side": "self", "selector": "all_items"}, {}, 0, {"bonus_key": "crit_rate"})]
		"hypnotic_drain":
			return [_skill_definition("hypnotic_drain_lifesteal_weapon_freeze_smaller", EffectDefinitionClass.TRIGGER_ON_TAG_USED, EffectDefinitionClass.EFFECT_FREEZE, get_tier_value(resolved), {"side": "self", "selector": "smaller_than_source_highest_cooldown", "count": 1}, {"tag": "Weapon", "event_source_has_lifesteal": true})]
		"jack_of_all_trades":
			return [_skill_definition("jack_of_all_trades_first_item_charge", EffectDefinitionClass.TRIGGER_ON_ITEM_USED, EffectDefinitionClass.EFFECT_CHARGE, get_tier_value(resolved), {"side": "self", "selector": "slowest_items", "count": 1}, {}, int(round(get_tier_value(resolved, "limits"))))]
		"juggler":
			return [_skill_definition("juggler_small_item_charge_large", EffectDefinitionClass.TRIGGER_ON_ITEM_USED, EffectDefinitionClass.EFFECT_CHARGE, get_tier_value(resolved), {"side": "self", "selector": "matching_size_highest_cooldown", "size": "large", "count": 1}, {"event_source_size": "small"})]
		"jury_rigger":
			return [_skill_definition("jury_rigger_ammo_reload_left", EffectDefinitionClass.TRIGGER_ON_ITEM_USED, EffectDefinitionClass.EFFECT_RELOAD, get_tier_value(resolved), {"side": "self", "selector": "left_of_source"}, {"event_source_has_ammo": true})]
		"neophiliac":
			return [
				_skill_definition("neophiliac_first_burn_charge", EffectDefinitionClass.TRIGGER_ON_ENEMY_STATUS_APPLIED, EffectDefinitionClass.EFFECT_CHARGE, get_tier_value(resolved), {"side": "self", "selector": "slowest_items", "count": 1}, {"status_type": EffectDefinitionClass.EFFECT_BURN}, 1),
				_skill_definition("neophiliac_first_poison_charge", EffectDefinitionClass.TRIGGER_ON_ENEMY_STATUS_APPLIED, EffectDefinitionClass.EFFECT_CHARGE, get_tier_value(resolved), {"side": "self", "selector": "slowest_items", "count": 1}, {"status_type": EffectDefinitionClass.EFFECT_POISON}, 1),
				_skill_definition("neophiliac_first_slow_charge", EffectDefinitionClass.TRIGGER_ON_ENEMY_STATUS_APPLIED, EffectDefinitionClass.EFFECT_CHARGE, get_tier_value(resolved), {"side": "self", "selector": "slowest_items", "count": 1}, {"status_type": EffectDefinitionClass.EFFECT_SLOW}, 1),
				_skill_definition("neophiliac_first_freeze_charge", EffectDefinitionClass.TRIGGER_ON_ENEMY_STATUS_APPLIED, EffectDefinitionClass.EFFECT_CHARGE, get_tier_value(resolved), {"side": "self", "selector": "slowest_items", "count": 1}, {"status_type": EffectDefinitionClass.EFFECT_FREEZE}, 1),
				_skill_definition("neophiliac_first_haste_charge", EffectDefinitionClass.TRIGGER_ON_ENEMY_STATUS_APPLIED, EffectDefinitionClass.EFFECT_CHARGE, get_tier_value(resolved), {"side": "self", "selector": "slowest_items", "count": 1}, {"status_type": EffectDefinitionClass.EFFECT_HASTE}, 1),
			]
		"parting_shot":
			return [_skill_definition("parting_shot_ammo_self_crit", EffectDefinitionClass.TRIGGER_ON_ITEM_USED, EffectDefinitionClass.EFFECT_RUNTIME_BONUS, get_tier_value(resolved), {"side": "self", "selector": "source_item"}, {"event_source_has_ammo": true}, 0, {"bonus_key": "crit_rate"})]
		"retool":
			return [_skill_definition("retool_tool_reload_adjacent", EffectDefinitionClass.TRIGGER_ON_TAG_USED, EffectDefinitionClass.EFFECT_RELOAD, get_tier_value(resolved), {"side": "self", "selector": "adjacent_to_source"}, {"tag": "Tool"})]
		"rigged":
			return [_skill_definition("rigged_first_item_haste_all", EffectDefinitionClass.TRIGGER_ON_ITEM_USED, EffectDefinitionClass.EFFECT_HASTE, get_tier_value(resolved), {"side": "self", "selector": "all_items"}, {}, 1)]
		"sharpened_steel":
			return [_skill_definition("sharpened_steel_weapon_adjacent_crit", EffectDefinitionClass.TRIGGER_ON_TAG_USED, EffectDefinitionClass.EFFECT_RUNTIME_BONUS, get_tier_value(resolved), {"side": "self", "selector": "adjacent_to_source"}, {"tag": "Weapon"}, 0, {"bonus_key": "crit_rate"})]
		"wake_up_call":
			return [_skill_definition("wake_up_call_small_haste_status_item", EffectDefinitionClass.TRIGGER_ON_ITEM_USED, EffectDefinitionClass.EFFECT_HASTE, get_tier_value(resolved), {"side": "self", "selector": "matching_any_tag_highest_cooldown", "tags": ["Burn", "Poison", "Freeze"], "count": 1}, {"event_source_size": "small"})]
		"cosmic_wind":
			return [_skill_definition("cosmic_wind_on_crit_haste_item", EffectDefinitionClass.TRIGGER_ON_CRIT, EffectDefinitionClass.EFFECT_HASTE, get_tier_value(resolved), {"side": "self", "selector": "slowest_items", "count": 1})]
		"cryomastery":
			return [_skill_definition("cryomastery_on_shield_freeze_item", EffectDefinitionClass.TRIGGER_ON_SHIELD_GAINED, EffectDefinitionClass.EFFECT_FREEZE, get_tier_value(resolved), {"side": "enemy", "selector": "slowest_items", "count": 1}, {}, int(round(get_tier_value(resolved, "limits"))))]
		"equivalent_exchange":
			return [_skill_definition("equivalent_exchange_on_heal_charge_poison_item", EffectDefinitionClass.TRIGGER_ON_HEAL, EffectDefinitionClass.EFFECT_CHARGE, get_tier_value(resolved), {"side": "self", "selector": "matching_tag_highest_cooldown", "tag": "Poison", "count": 1})]
		"firestarter":
			return [_skill_definition("firestarter_battle_start_enemy_burn", EffectDefinitionClass.TRIGGER_ON_BATTLE_START, EffectDefinitionClass.EFFECT_BURN, get_tier_value(resolved), {"side": "enemy", "selector": "hero"})]
		"flurry_of_blows":
			return [_skill_definition("flurry_of_blows_on_weapon_charge_item", EffectDefinitionClass.TRIGGER_ON_TAG_USED, EffectDefinitionClass.EFFECT_CHARGE, get_tier_value(resolved), {"side": "self", "selector": "slowest_items", "count": 1}, {"tag": "Weapon"}, int(round(get_tier_value(resolved, "limits"))))]
		"heated_shells":
			return [_skill_definition("heated_shells_on_ammo_burn", EffectDefinitionClass.TRIGGER_ON_ITEM_USED, EffectDefinitionClass.EFFECT_BURN, get_tier_value(resolved), {"side": "enemy", "selector": "hero"}, {"event_source_has_ammo": true})]
		"heat_lover":
			return [_skill_definition("heat_lover_on_burn_regeneration", EffectDefinitionClass.TRIGGER_ON_ENEMY_STATUS_APPLIED, EffectDefinitionClass.EFFECT_REGENERATION, get_tier_value(resolved), {"side": "self", "selector": "hero"}, {"status_type": EffectDefinitionClass.EFFECT_BURN})]
		"insect_bite":
			return [_skill_definition("insect_bite_battle_start_self_poison", EffectDefinitionClass.TRIGGER_ON_BATTLE_START, EffectDefinitionClass.EFFECT_POISON, get_tier_value(resolved), {"side": "self", "selector": "hero"})]
		"invigorating_cold":
			return [_skill_definition("invigorating_cold_on_freeze_haste_items", EffectDefinitionClass.TRIGGER_ON_ENEMY_STATUS_APPLIED, EffectDefinitionClass.EFFECT_HASTE, get_tier_value(resolved), {"side": "self", "selector": "slowest_items", "count": int(round(get_tier_value(resolved, "counts")))}, {"status_type": EffectDefinitionClass.EFFECT_FREEZE}, 1)]
		"lash_out":
			return [_skill_definition("lash_out_battle_start_poison", EffectDefinitionClass.TRIGGER_ON_BATTLE_START, EffectDefinitionClass.EFFECT_POISON, get_tier_value(resolved), {"side": "enemy", "selector": "hero"})]
		"overheal_haste":
			return [_skill_definition("overheal_haste_on_overheal_haste_all", EffectDefinitionClass.TRIGGER_ON_HEAL, EffectDefinitionClass.EFFECT_HASTE, get_tier_value(resolved), {"side": "self", "selector": "all_items"}, {"overheal": true}, 1)]
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
	max_triggers_per_fight: int = 0,
	effect_extra: Dictionary = {}
) -> Dictionary:
	var effect: Dictionary = {"type": effect_type, "amount": amount}
	for key in effect_extra.keys():
		effect[key] = effect_extra[key]
	var definition: Dictionary = {
		"id": definition_id,
		"trigger": trigger,
		"target": target,
		"effect": effect,
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
