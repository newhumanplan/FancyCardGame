extends Node

const BazaarContentClass = preload("res://scripts/data/bazaar_content.gd")
const ItemDataClass = preload("res://scripts/data/item_data.gd")

var _total: int = 0
var _passed: int = 0

func _ready() -> void:
	if not Engine.is_editor_hint():
		print("== tests/test_full_content_parity_p1e_b_monster_numeric_skills.gd ==")
		test_direct_numeric_skill_reasons_are_resolved()
		test_direct_numeric_skill_runtime_changes_monster_items()
		_print_summary()

func test_direct_numeric_skill_reasons_are_resolved() -> void:
	var report: Dictionary = BazaarContentClass.get_all_monster_parity_report()
	var reason_counts: Dictionary = report.get("grouped_missing_mechanics", {}).get("reason_counts", {})
	for reason in [
		"skill:deadly_eye:player_skill_runtime_not_bound_to_monster_ai:battle_runtime_numeric",
		"skill:keen_eye:player_skill_runtime_not_bound_to_monster_ai:numeric_rule",
		"skill:strength:player_skill_runtime_not_bound_to_monster_ai:battle_runtime_numeric",
	]:
		_assert_true(not reason_counts.has(reason), "direct numeric monster skill reason resolved: %s" % reason)

	var fanged: Dictionary = _find_report_entry(report, "fanged_inglet")
	var mosquito: Dictionary = _find_report_entry(report, "giant_mosquito")
	var thug: Dictionary = _find_report_entry(report, "thug")
	_assert_true((fanged.get("supported_mechanics", []) as Array).has("skill:deadly_eye:weapon_crit_bonus"), "Fanged Inglet reports Deadly Eye weapon crit runtime")
	_assert_true((mosquito.get("supported_mechanics", []) as Array).has("skill:keen_eye:all_item_crit_bonus"), "Giant Mosquito reports Keen Eye all-item crit runtime")
	_assert_true((thug.get("supported_mechanics", []) as Array).has("skill:strength:weapon_damage_bonus"), "Thug reports Strength weapon damage runtime")

func test_direct_numeric_skill_runtime_changes_monster_items() -> void:
	var void_knight = BazaarContentClass.create_monster("void_knight", 13)
	_assert_true(_any_matching_item_at_least(void_knight, "crit_chance", 0.05, "weapon"), "Deadly Eye gives Void Knight weapons +5% crit")

	var mosquito = BazaarContentClass.create_monster("giant_mosquito", 2)
	_assert_true(_all_items_at_least(mosquito, "crit_chance", 0.04), "Keen Eye gives Giant Mosquito all items +4% crit")

	var thug = BazaarContentClass.create_monster("thug", 8)
	_assert_true(_any_matching_item_at_least(thug, "damage", 10.0, "weapon"), "Strength gives Thug weapons +10 damage")

func _find_report_entry(report: Dictionary, monster_id: String) -> Dictionary:
	for entry in report.get("monsters", []):
		if entry is Dictionary and str((entry as Dictionary).get("id", "")) == monster_id:
			return entry as Dictionary
	return {}

func _any_matching_item_at_least(monster, key: String, expected: float, item_kind: String) -> bool:
	if monster == null:
		return false
	for item in monster.monster_items:
		if not item is Dictionary:
			continue
		if item_kind == "weapon" and int((item as Dictionary).get("type", ItemDataClass.Type.UTILITY)) != ItemDataClass.Type.WEAPON:
			continue
		if float((item as Dictionary).get(key, 0.0)) >= expected:
			return true
	return false

func _all_items_at_least(monster, key: String, expected: float) -> bool:
	if monster == null or monster.monster_items.is_empty():
		return false
	for item in monster.monster_items:
		if not item is Dictionary:
			return false
		if float((item as Dictionary).get(key, 0.0)) < expected:
			return false
	return true

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
