extends Node

const BazaarContentClass = preload("res://scripts/data/bazaar_content.gd")
const ItemDataClass = preload("res://scripts/data/item_data.gd")

const STATUS_DIR := "/Users/Allenz/Projects/FancyCardGame/.codex-status/T-FCG-FULL-CONTENT-PARITY-001/P1E-c"

var _total: int = 0
var _passed: int = 0

func _ready() -> void:
	if not Engine.is_editor_hint():
		print("== tests/test_full_content_parity_p1e_c_monster_targeted_numeric_skills.gd ==")
		test_targeted_numeric_skill_reasons_are_resolved()
		test_targeted_numeric_skill_runtime_changes_monster_items()
		test_writes_p1e_c_monster_report_artifact()
		_print_summary()

func test_targeted_numeric_skill_reasons_are_resolved() -> void:
	var report: Dictionary = BazaarContentClass.get_all_monster_parity_report()
	var reason_counts: Dictionary = report.get("grouped_missing_mechanics", {}).get("reason_counts", {})
	for reason in [
		"skill:flamedancer:player_skill_runtime_not_bound_to_monster_ai:battle_runtime_numeric",
		"skill:left_handed:player_skill_runtime_not_bound_to_monster_ai:battle_runtime_numeric",
		"skill:right_handed:player_skill_runtime_not_bound_to_monster_ai:battle_runtime_numeric",
	]:
		_assert_true(not reason_counts.has(reason), "targeted numeric monster skill reason resolved: %s" % reason)

	var hellbilly: Dictionary = _find_report_entry(report, "hellbilly")
	var ferros: Dictionary = _find_report_entry(report, "ferros_khan")
	var radiant: Dictionary = _find_report_entry(report, "radiant_corsair")
	_assert_true((hellbilly.get("supported_mechanics", []) as Array).has("skill:left_handed:leftmost_weapon_damage_bonus"), "Hellbilly reports Left-Handed leftmost weapon damage runtime")
	_assert_true((ferros.get("supported_mechanics", []) as Array).has("skill:left_handed:leftmost_weapon_damage_bonus"), "Ferros Khan reports Left-Handed leftmost weapon damage runtime")
	_assert_true((ferros.get("supported_mechanics", []) as Array).has("skill:right_handed:rightmost_weapon_damage_bonus"), "Ferros Khan reports Right-Handed rightmost weapon damage runtime")
	_assert_true((radiant.get("supported_mechanics", []) as Array).has("skill:flamedancer:burn_item_crit_bonus"), "Radiant Corsair reports Flamedancer Burn-item crit runtime")
	_assert_true((radiant.get("supported_mechanics", []) as Array).has("skill:right_handed:rightmost_weapon_damage_bonus"), "Radiant Corsair reports Right-Handed rightmost weapon damage runtime")

func test_targeted_numeric_skill_runtime_changes_monster_items() -> void:
	var hellbilly = BazaarContentClass.create_monster("hellbilly", 6)
	var hellbilly_left_weapon: Dictionary = _find_edge_weapon(hellbilly, false)
	_assert_true(not hellbilly_left_weapon.is_empty(), "Hellbilly has a leftmost weapon target")
	_assert_true(float(hellbilly_left_weapon.get("damage", 0.0)) >= 25.0, "Left-Handed gives Hellbilly's leftmost weapon +20 damage")

	var ferros = BazaarContentClass.create_monster("ferros_khan", 10)
	var ferros_left_weapon: Dictionary = _find_edge_weapon(ferros, false)
	var ferros_right_weapon: Dictionary = _find_edge_weapon(ferros, true)
	_assert_true(not ferros_left_weapon.is_empty(), "Ferros Khan has a leftmost weapon target")
	_assert_true(not ferros_right_weapon.is_empty(), "Ferros Khan has a rightmost weapon target")
	_assert_true(float(ferros_left_weapon.get("damage", 0.0)) >= 120.0, "Left-Handed gives Ferros Khan's leftmost weapon +20 damage")
	_assert_true(float(ferros_right_weapon.get("damage", 0.0)) >= 120.0, "Right-Handed gives Ferros Khan's rightmost weapon +20 damage")

	var radiant = BazaarContentClass.create_monster("radiant_corsair", 12)
	_assert_true(_any_matching_item_at_least(radiant, "crit_chance", 0.05, "burn"), "Flamedancer gives Radiant Corsair Burn items +5% crit")
	_assert_true(float(_find_edge_weapon(radiant, true).get("damage", 0.0)) >= 25.0, "Right-Handed gives Radiant Corsair's rightmost weapon +20 damage")

func test_writes_p1e_c_monster_report_artifact() -> void:
	var err: int = DirAccess.make_dir_recursive_absolute(STATUS_DIR)
	_assert_true(err == OK or DirAccess.dir_exists_absolute(STATUS_DIR), "P1E-c status artifact directory is available")
	var report: Dictionary = BazaarContentClass.get_all_monster_parity_report()
	var path: String = STATUS_DIR.path_join("monster_parity_101_report.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	_assert_true(file != null, "P1E-c monster parity report artifact opens for write")
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	_assert_true(FileAccess.file_exists(path), "P1E-c monster parity report artifact written")

func _find_report_entry(report: Dictionary, monster_id: String) -> Dictionary:
	for entry in report.get("monsters", []):
		if entry is Dictionary and str((entry as Dictionary).get("id", "")) == monster_id:
			return entry as Dictionary
	return {}

func _find_edge_weapon(monster, from_right: bool) -> Dictionary:
	if monster == null:
		return {}
	if from_right:
		for index in range(monster.monster_items.size() - 1, -1, -1):
			var item: Dictionary = monster.monster_items[index] as Dictionary
			if int(item.get("type", ItemDataClass.Type.UTILITY)) == ItemDataClass.Type.WEAPON:
				return item
		return {}
	for item in monster.monster_items:
		var item_dict: Dictionary = item as Dictionary
		if int(item_dict.get("type", ItemDataClass.Type.UTILITY)) == ItemDataClass.Type.WEAPON:
			return item_dict
	return {}

func _any_matching_item_at_least(monster, key: String, expected: float, item_kind: String) -> bool:
	if monster == null:
		return false
	for item in monster.monster_items:
		if not item is Dictionary:
			continue
		if item_kind == "burn" and int((item as Dictionary).get("burn", 0)) <= 0:
			continue
		if float((item as Dictionary).get(key, 0.0)) >= expected:
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
