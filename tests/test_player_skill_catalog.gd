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
	test_registered_skill_expectations_match_phase1_runtime()
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

func test_registered_skill_expectations_match_phase1_runtime() -> void:
	var report: Dictionary = PlayerSkillCatalogClass.get_coverage_report()
	var implemented_registered_ids: Array = report.get("implemented_registered_ids", [])
	var unsupported_registered_ids: Array = report.get("unsupported_registered_ids", [])
	_assert_eq(
		implemented_registered_ids,
		["deadly_eye", "fiery", "improved_toxins", "keen_eye", "large_appetites", "quick_defenses", "toughness"],
		"Phase1 registered skill implementations are the validated runtime-backed set"
	)
	_assert_eq(
		unsupported_registered_ids,
		["initial_chill"],
		"Phase1 leaves only Initial Chill explicitly unsupported from skills_config"
	)
	var initial_chill: Dictionary = PlayerSkillCatalogClass.get_skill_entry("initial_chill")
	_assert_eq(
		str(initial_chill.get("unsupported_reason", "")),
		"phase1_freeze_bonus_runtime_not_verified",
		"Initial Chill unsupported reason is explicit"
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
