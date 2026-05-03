extends Node

const PlayerSkillCatalogClass = preload("res://scripts/data/player_skill_catalog.gd")

var _total: int = 0
var _passed: int = 0

func _ready() -> void:
	if not Engine.is_editor_hint():
		print("== tests/test_player_skill_catalog.gd ==")
		_run_tests()
		_print_coverage_snapshot()
		_print_summary()

func _run_tests() -> void:
	test_registered_skill_ids_have_explicit_catalog_status()
	test_registered_skill_expectations_match_runtime()
	test_runtime_coverage_reaches_phase_p2_target()
	test_phase_p2_skill_effect_definitions_are_explicit()
	test_known_wiki_skills_are_never_unknown()
	test_deadly_eye_and_gunner_tier_values_match_runtime_expectations()

func _assert_true(condition: bool, label: String) -> void:
	_total += 1
	if condition:
		_passed += 1
		print("PASS: %s" % label)
	else:
		push_error("FAIL: %s" % label)

func _assert_eq(actual, expected, label: String) -> void:
	_assert_true(actual == expected, "%s | expected=%s actual=%s" % [label, str(expected), str(actual)])

func _assert_float_eq(actual: float, expected: float, label: String, tolerance: float = 0.001) -> void:
	_assert_true(absf(actual - expected) <= tolerance, "%s | expected=%.3f actual=%.3f" % [label, expected, actual])

func _print_summary() -> void:
	print("SUMMARY: %d/%d passed" % [_passed, _total])
	get_tree().quit(1 if _passed < _total else 0)

func _print_coverage_snapshot() -> void:
	var report: Dictionary = PlayerSkillCatalogClass.get_coverage_report()
	print("CATALOG_COVERAGE registered=%d implemented_registered=%d unsupported_registered=%d wiki=%d referenced=%d implemented_total=%d unsupported_total=%d unknown_total=%d" % [
		int(report.get("registered_count", 0)),
		(report.get("implemented_registered_ids", []) as Array).size(),
		(report.get("unsupported_registered_ids", []) as Array).size(),
		int(report.get("wiki_skill_count", 0)),
		int(report.get("monster_referenced_count", 0)),
		int(report.get("implemented_count", 0)),
		int(report.get("unsupported_count", 0)),
		int(report.get("unknown_count", 0)),
	])
	print("CATALOG_REGISTERED_IMPLEMENTED=%s" % ",".join(report.get("implemented_registered_ids", [])))
	print("CATALOG_REGISTERED_UNSUPPORTED=%s" % ",".join(report.get("unsupported_registered_ids", [])))

func test_registered_skill_ids_have_explicit_catalog_status() -> void:
	var report: Dictionary = PlayerSkillCatalogClass.get_coverage_report()
	var registered_ids: Array = report.get("registered_ids", [])
	for skill_id_variant in registered_ids:
		var skill_id: String = str(skill_id_variant)
		var entry: Dictionary = PlayerSkillCatalogClass.get_skill_entry(skill_id)
		_assert_true(
			str(entry.get("support_status", "")) != PlayerSkillCatalogClass.SUPPORT_UNKNOWN,
			"registered skill has explicit catalog coverage: %s" % skill_id
		)

func test_registered_skill_expectations_match_runtime() -> void:
	var report: Dictionary = PlayerSkillCatalogClass.get_coverage_report()
	var implemented_registered_ids: Array = report.get("implemented_registered_ids", [])
	var unsupported_registered_ids: Array = report.get("unsupported_registered_ids", [])
	_assert_eq(
		implemented_registered_ids,
		["deadly_eye", "fiery", "improved_toxins", "keen_eye", "large_appetites", "quick_defenses", "toughness"],
		"registered skill implementations remain the validated runtime-backed set"
	)
	_assert_eq(
		unsupported_registered_ids,
		["initial_chill"],
		"registered skill coverage leaves only Initial Chill explicitly unsupported from skills_config"
	)
	var initial_chill: Dictionary = PlayerSkillCatalogClass.get_skill_entry("initial_chill")
	_assert_eq(
		str(initial_chill.get("unsupported_reason", "")),
		"phase1_freeze_bonus_runtime_not_verified",
		"Initial Chill unsupported reason is explicit"
	)

func test_runtime_coverage_reaches_phase_p2_target() -> void:
	var report: Dictionary = PlayerSkillCatalogClass.get_coverage_report()
	var implemented_ids: Array = report.get("implemented_ids", [])
	_assert_true(
		int(report.get("implemented_count", 0)) >= 60,
		"PhaseP2 runtime-backed skill count reaches at least 60"
	)
	for skill_id in [
		"ammo_stash",
		"big_ego",
		"burning_rage",
		"cosmic_wind",
		"critical_aid",
		"cryomastery",
		"diamond_fangs",
		"equivalent_exchange",
		"exposing_toxins",
		"extreme_comfort",
		"final_flame",
		"firestarter",
		"first_responder",
		"flamedancer",
		"flurry_of_blows",
		"follow_up_care",
		"frontal_shielding",
		"heat_lover",
		"heated_shells",
		"initial_dose",
		"invigorating_cold",
		"lash_out",
		"left_handed",
		"paralytic_poison",
		"poison_tyrant",
		"pyromania",
		"rush",
		"slow_burn",
		"strength",
		"time_to_tinker",
		"unwavering",
		"vengeance",
		"vital_reserve",
	]:
		_assert_true(
			implemented_ids.has(skill_id),
			"PhaseP2 priority skill is runtime-backed: %s" % skill_id
		)

func test_phase_p2_skill_effect_definitions_are_explicit() -> void:
	var expected_definitions := {
		"cosmic_wind": "cosmic_wind_on_crit_haste_item",
		"cryomastery": "cryomastery_on_shield_freeze_item",
		"equivalent_exchange": "equivalent_exchange_on_heal_charge_poison_item",
		"firestarter": "firestarter_battle_start_enemy_burn",
		"flurry_of_blows": "flurry_of_blows_on_weapon_charge_item",
		"heated_shells": "heated_shells_on_ammo_burn",
		"heat_lover": "heat_lover_on_burn_regeneration",
		"insect_bite": "insect_bite_battle_start_self_poison",
		"invigorating_cold": "invigorating_cold_on_freeze_haste_items",
		"lash_out": "lash_out_battle_start_poison",
		"paralytic_poison": "paralytic_poison_on_first_poison_freeze",
		"poison_tyrant": "poison_tyrant_on_poison_regeneration",
		"pyromania": "pyromania_on_large_item_burn",
		"regenerative": "regenerative_battle_start_regeneration",
		"rush": "rush_first_item_haste_weapon",
		"rust": "rust_first_item_slow_enemy",
		"shored_up": "shored_up_on_heal_charge_shield_item",
		"slow_burn": "slow_burn_on_slow_charge",
		"small_refresh": "small_refresh_on_small_item_heal",
		"time_to_tinker": "time_to_tinker_on_haste_shield",
		"tools_of_the_trade": "tools_of_the_trade_on_tool_haste_tool",
		"toxic_friendship": "toxic_friendship_on_friend_poison",
		"trickle_down_economics": "trickle_down_economics_on_large_item_haste",
		"unwavering": "unwavering_on_item_used_shield",
		"valley_fever": "valley_fever_battle_start_self_burn",
		"void_energy": "void_energy_on_burn_charge_shield_item",
		"void_rage": "void_rage_on_burn_haste_item",
		"warm_hugs": "warm_hugs_on_friend_burn",
	}
	for skill_id in expected_definitions.keys():
		var definitions: Array[Dictionary] = PlayerSkillCatalogClass.get_effect_definitions(skill_id)
		var definition_ids: Array[String] = []
		for definition in definitions:
			definition_ids.append(str(definition.get("id", "")))
		_assert_true(
			definition_ids.has(str(expected_definitions[skill_id])),
			"PhaseP2 trigger skill has explicit DSL definition: %s" % skill_id
		)

func test_known_wiki_skills_are_never_unknown() -> void:
	var report: Dictionary = PlayerSkillCatalogClass.get_coverage_report()
	_assert_eq(int(report.get("unknown_count", 0)), 0, "known wiki and registered skills never fall back to unknown status")
	for skill_id_variant in report.get("monster_referenced_skill_ids", []):
		var skill_id: String = str(skill_id_variant)
		var entry: Dictionary = PlayerSkillCatalogClass.get_skill_entry(skill_id)
		_assert_true(
			str(entry.get("support_status", "")) != PlayerSkillCatalogClass.SUPPORT_UNKNOWN,
			"monster referenced skill has explicit catalog handling: %s" % skill_id
		)

func test_deadly_eye_and_gunner_tier_values_match_runtime_expectations() -> void:
	_assert_float_eq(
		PlayerSkillCatalogClass.get_tier_value({"id": "deadly_eye", "tier": "Bronze"}),
		5.0,
		"Deadly Eye Bronze maps to the first crit bonus tier"
	)
	_assert_float_eq(
		PlayerSkillCatalogClass.get_tier_value({"id": "deadly_eye", "tier": "Silver"}),
		10.0,
		"Deadly Eye Silver maps to the second crit bonus tier"
	)
	_assert_float_eq(
		PlayerSkillCatalogClass.get_tier_value({"id": "deadly_eye", "tier": "Gold"}),
		15.0,
		"Deadly Eye Gold maps to the third crit bonus tier"
	)
	_assert_float_eq(
		PlayerSkillCatalogClass.get_tier_value({"id": "deadly_eye", "tier": "Diamond"}),
		20.0,
		"Deadly Eye Diamond maps to the fourth crit bonus tier"
	)
	_assert_float_eq(
		PlayerSkillCatalogClass.get_tier_value({"id": "gunner", "tier": "Silver"}),
		1.0,
		"Gunner Silver adds one max ammo"
	)
	_assert_float_eq(
		PlayerSkillCatalogClass.get_tier_value({"id": "gunner", "tier": "Gold"}),
		2.0,
		"Gunner Gold adds two max ammo"
	)
	_assert_float_eq(
		PlayerSkillCatalogClass.get_tier_value({"id": "gunner", "tier": "Diamond"}),
		3.0,
		"Gunner Diamond adds three max ammo"
	)
