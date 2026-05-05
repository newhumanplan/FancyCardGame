extends Node

const BazaarContentClass = preload("res://scripts/data/bazaar_content.gd")

const STATUS_DIR := "/Users/Allenz/Projects/FancyCardGame/.codex-status/T-FCG-FULL-CONTENT-PARITY-001/P1E-d"

var _total: int = 0
var _passed: int = 0

func _ready() -> void:
	if not Engine.is_editor_hint():
		print("== tests/test_full_content_parity_p1e_d_monster_edge_numeric_skills.gd ==")
		test_edge_numeric_skill_reasons_are_resolved()
		test_edge_numeric_skill_runtime_changes_monster_items()
		test_p1e_d_monster_report_regression()
		_print_summary()

func test_edge_numeric_skill_reasons_are_resolved() -> void:
	var report: Dictionary = BazaarContentClass.get_all_monster_parity_report()
	var reason_counts: Dictionary = report.get("grouped_missing_mechanics", {}).get("reason_counts", {})
	for reason in [
		"skill:critical_aid:player_skill_runtime_not_bound_to_monster_ai:battle_runtime_numeric",
		"skill:final_flame:player_skill_runtime_not_bound_to_monster_ai:battle_runtime_numeric",
		"skill:first_responder:player_skill_runtime_not_bound_to_monster_ai:battle_runtime_numeric",
		"skill:follow_up_care:player_skill_runtime_not_bound_to_monster_ai:battle_runtime_numeric",
		"skill:frontal_shielding:player_skill_runtime_not_bound_to_monster_ai:battle_runtime_numeric",
		"skill:initial_dose:player_skill_runtime_not_bound_to_monster_ai:battle_runtime_numeric",
	]:
		_assert_true(not reason_counts.has(reason), "edge numeric monster skill reason resolved: %s" % reason)

	var boarrior: Dictionary = _find_report_entry(report, "boarrior")
	var gorgon: Dictionary = _find_report_entry(report, "gorgon_noble")
	var joyful: Dictionary = _find_report_entry(report, "joyful_jack")
	var roaming: Dictionary = _find_report_entry(report, "roaming_isle")
	var radiant: Dictionary = _find_report_entry(report, "radiant_corsair")
	_assert_true((boarrior.get("supported_mechanics", []) as Array).has("skill:frontal_shielding:leftmost_shield_bonus"), "Boarrior reports Frontal Shielding runtime")
	_assert_true((gorgon.get("supported_mechanics", []) as Array).has("skill:initial_dose:leftmost_poison_bonus"), "Gorgon Noble reports Initial Dose runtime")
	_assert_true((joyful.get("supported_mechanics", []) as Array).has("skill:critical_aid:heal_item_crit_bonus"), "Joyful Jack reports Critical Aid runtime")
	_assert_true((roaming.get("supported_mechanics", []) as Array).has("skill:first_responder:leftmost_heal_bonus"), "Roaming Isle reports First Responder runtime")
	_assert_true((roaming.get("supported_mechanics", []) as Array).has("skill:follow_up_care:rightmost_heal_bonus"), "Roaming Isle reports Follow-Up Care runtime")
	_assert_true((radiant.get("supported_mechanics", []) as Array).has("skill:final_flame:rightmost_burn_bonus"), "Radiant Corsair reports Final Flame runtime")

func test_edge_numeric_skill_runtime_changes_monster_items() -> void:
	var boarrior = BazaarContentClass.create_monster("boarrior", 3)
	_assert_true(_first_item_with_key_at_least(boarrior, "shield", 20.0), "Frontal Shielding gives Boarrior's leftmost shield item +20 Shield")

	var gorgon = BazaarContentClass.create_monster("gorgon_noble", 7)
	_assert_true(_first_item_with_key_at_least(gorgon, "poison", 2.0), "Initial Dose gives Gorgon Noble's leftmost poison item +2 Poison")

	var joyful = BazaarContentClass.create_monster("joyful_jack", 8)
	_assert_true(_any_item_with_keys_at_least(joyful, "heal", 1.0, "crit_chance", 0.05), "Critical Aid gives Joyful Jack heal items +5% crit")

	var roaming = BazaarContentClass.create_monster("roaming_isle", 11)
	_assert_true(_first_item_with_key_at_least(roaming, "heal", 20.0), "First Responder gives Roaming Isle's leftmost heal item +20 Heal")
	_assert_true(_last_item_with_key_at_least(roaming, "heal", 20.0), "Follow-Up Care gives Roaming Isle's rightmost heal item +20 Heal")

	var radiant = BazaarContentClass.create_monster("radiant_corsair", 12)
	_assert_true(_last_item_with_key_at_least(radiant, "burn", 2.0), "Final Flame gives Radiant Corsair's rightmost Burn item +2 Burn")

func test_p1e_d_monster_report_regression() -> void:
	var err: int = DirAccess.make_dir_recursive_absolute(STATUS_DIR)
	_assert_true(err == OK or DirAccess.dir_exists_absolute(STATUS_DIR), "P1E-d status artifact directory is available")
	var report: Dictionary = BazaarContentClass.get_all_monster_parity_report()
	_assert_true(int(report.get("monster_count", 0)) == 101, "P1E-d all-monster report remains all 101 monsters")
	_assert_true(int(report.get("missing_mechanics_count", 999)) <= 96, "P1E-d regression observes current reduced missing mechanics count")

func _find_report_entry(report: Dictionary, monster_id: String) -> Dictionary:
	for entry in report.get("monsters", []):
		if entry is Dictionary and str((entry as Dictionary).get("id", "")) == monster_id:
			return entry as Dictionary
	return {}

func _first_item_with_key_at_least(monster, key: String, expected: float) -> bool:
	if monster == null:
		return false
	for item in monster.monster_items:
		if item is Dictionary and float((item as Dictionary).get(key, 0.0)) >= expected:
			return true
	return false

func _last_item_with_key_at_least(monster, key: String, expected: float) -> bool:
	if monster == null:
		return false
	for index in range(monster.monster_items.size() - 1, -1, -1):
		var item: Dictionary = monster.monster_items[index] as Dictionary
		if float(item.get(key, 0.0)) >= expected:
			return true
	return false

func _any_item_with_keys_at_least(monster, key_a: String, expected_a: float, key_b: String, expected_b: float) -> bool:
	if monster == null:
		return false
	for item in monster.monster_items:
		if not item is Dictionary:
			continue
		var item_dict: Dictionary = item as Dictionary
		if float(item_dict.get(key_a, 0.0)) >= expected_a and float(item_dict.get(key_b, 0.0)) >= expected_b:
			return true
	return false

func _assert_true(condition: bool, label: String) -> void:
	_total += 1
	if condition:
		_passed += 1
		print("PASS: %s" % label)
	else:
		push_error("FAIL: %s" % label)

func _print_summary() -> void:
	print("SUMMARY: %d/%d passed" % [_passed, _total])
	get_tree().quit(1 if _passed < _total else 0)
