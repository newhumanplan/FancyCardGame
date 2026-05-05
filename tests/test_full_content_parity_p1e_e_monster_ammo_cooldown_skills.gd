extends Node

const BazaarContentClass = preload("res://scripts/data/bazaar_content.gd")

const STATUS_DIR := "/Users/Allenz/Projects/FancyCardGame/.codex-status/T-FCG-FULL-CONTENT-PARITY-001/P1E-e"

var _total: int = 0
var _passed: int = 0

func _ready() -> void:
	if not Engine.is_editor_hint():
		print("== tests/test_full_content_parity_p1e_e_monster_ammo_cooldown_skills.gd ==")
		test_ammo_and_cooldown_skill_reasons_are_resolved()
		test_ammo_and_cooldown_skill_runtime_changes_monster_items()
		test_p1e_e_monster_report_regression()
		_print_summary()

func test_ammo_and_cooldown_skill_reasons_are_resolved() -> void:
	var report: Dictionary = BazaarContentClass.get_all_monster_parity_report()
	var reason_counts: Dictionary = report.get("grouped_missing_mechanics", {}).get("reason_counts", {})
	for reason in [
		"skill:ammo_stash:player_skill_runtime_not_bound_to_monster_ai:battle_runtime_numeric",
		"skill:command_ship:player_skill_runtime_not_bound_to_monster_ai:battle_runtime_numeric",
		"skill:diamond_fangs:player_skill_runtime_not_bound_to_monster_ai:battle_runtime_numeric",
		"skill:friend_zone:player_skill_runtime_not_bound_to_monster_ai:battle_runtime_numeric",
		"skill:full_arsenal:player_skill_runtime_not_bound_to_monster_ai:battle_runtime_numeric",
		"skill:gunner:player_skill_runtime_not_bound_to_monster_ai:battle_runtime_numeric",
		"skill:hyper_focus:player_skill_runtime_not_bound_to_monster_ai:battle_runtime_numeric",
		"skill:vengeance:player_skill_runtime_not_bound_to_monster_ai:battle_runtime_numeric",
	]:
		_assert_true(not reason_counts.has(reason), "ammo/cooldown monster skill reason resolved: %s" % reason)

	_assert_has_mechanic(report, "bloodreef_raider", "skill:ammo_stash:leftmost_ammo_item_max_ammo")
	_assert_has_mechanic(report, "hooverbike_hooligan", "skill:gunner:ammo_item_max_ammo")
	_assert_has_mechanic(report, "bloodreef_captain", "skill:full_arsenal:vehicle_weapon_tool_cooldown_reduction")
	_assert_has_mechanic(report, "sabretooth", "skill:diamond_fangs:small_diamond_item_cooldown_reduction")
	_assert_has_mechanic(report, "veteran_octopus", "skill:hyper_focus:solo_medium_item_cooldown_reduction")
	_assert_has_mechanic(report, "infernal_envoy", "skill:vengeance:edge_item_cooldown_reduction")
	_assert_has_mechanic(report, "tortuga", "skill:friend_zone:friend_cooldown_reduction")
	_assert_has_mechanic(report, "car_conductor", "skill:command_ship:non_vehicle_cooldown_reduction")

func test_ammo_and_cooldown_skill_runtime_changes_monster_items() -> void:
	var raider = BazaarContentClass.create_monster("bloodreef_raider", 5)
	_assert_true(_first_item_with_key_at_least(raider, "ammo", 2.0), "Ammo Stash increases Bloodreef Raider's first Ammo item")

	var hooligan = BazaarContentClass.create_monster("hooverbike_hooligan", 5)
	_assert_true(_all_ammo_items_at_least(hooligan, 3.0), "Gunner increases Hooverbike Hooligan Ammo items")

	var captain = BazaarContentClass.create_monster("bloodreef_captain", 10)
	_assert_true(_any_cooldown_below_base(captain), "Full Arsenal reduces Bloodreef Captain item cooldowns from board tags")

	var octopus = BazaarContentClass.create_monster("veteran_octopus", 13)
	_assert_true(_source_item_cooldown_at_most(octopus, "octopus", 5.6), "Hyper Focus reduces Veteran Octopus' single medium item cooldown")

	var envoy = BazaarContentClass.create_monster("infernal_envoy", 6)
	_assert_true(_edge_cooldown_below_base(envoy), "Vengeance reduces Infernal Envoy edge item cooldowns")

	var tortuga = BazaarContentClass.create_monster("tortuga", 1)
	_assert_true(_tagged_cooldown_below_base(tortuga, "Friend"), "Friend Zone reduces Tortuga Friend item cooldowns")

func test_p1e_e_monster_report_regression() -> void:
	var err: int = DirAccess.make_dir_recursive_absolute(STATUS_DIR)
	_assert_true(err == OK or DirAccess.dir_exists_absolute(STATUS_DIR), "P1E-e status artifact directory is available")
	var report: Dictionary = BazaarContentClass.get_all_monster_parity_report()
	_assert_true(int(report.get("monster_count", 0)) == 101, "P1E-e all-monster report remains all 101 monsters")
	_assert_true(int(report.get("missing_mechanics_count", 999)) <= 96, "P1E-e regression observes current reduced missing mechanics count")

func _assert_has_mechanic(report: Dictionary, monster_id: String, mechanic: String) -> void:
	var entry: Dictionary = _find_report_entry(report, monster_id)
	_assert_true((entry.get("supported_mechanics", []) as Array).has(mechanic), "%s reports %s" % [monster_id, mechanic])

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

func _all_ammo_items_at_least(monster, expected: float) -> bool:
	if monster == null:
		return false
	var checked: int = 0
	for item in monster.monster_items:
		if not item is Dictionary:
			continue
		var item_dict: Dictionary = item as Dictionary
		if int(item_dict.get("ammo", 0)) <= 0:
			continue
		checked += 1
		if float(item_dict.get("ammo", 0.0)) < expected:
			return false
	return checked > 0

func _any_cooldown_below_base(monster) -> bool:
	if monster == null:
		return false
	for item in monster.monster_items:
		if not item is Dictionary:
			continue
		var item_dict: Dictionary = item as Dictionary
		if item_dict.has("base_cooldown") and float(item_dict.get("cooldown", 0.0)) < float(item_dict.get("base_cooldown", 0.0)):
			return true
	return false

func _source_item_cooldown_at_most(monster, source_id: String, expected: float) -> bool:
	if monster == null:
		return false
	for item in monster.monster_items:
		if item is Dictionary and str((item as Dictionary).get("source_id", "")) == source_id:
			return float((item as Dictionary).get("cooldown", 0.0)) <= expected
	return false

func _edge_cooldown_below_base(monster) -> bool:
	if monster == null or monster.monster_items.is_empty():
		return false
	var first: Dictionary = monster.monster_items[0] as Dictionary
	var last: Dictionary = monster.monster_items[monster.monster_items.size() - 1] as Dictionary
	return _cooldown_below_base(first) or _cooldown_below_base(last)

func _tagged_cooldown_below_base(monster, tag: String) -> bool:
	if monster == null:
		return false
	for item in monster.monster_items:
		if not item is Dictionary:
			continue
		var item_dict: Dictionary = item as Dictionary
		if _has_tag(item_dict, tag) and _cooldown_below_base(item_dict):
			return true
	return false

func _cooldown_below_base(item: Dictionary) -> bool:
	return item.has("base_cooldown") and float(item.get("cooldown", 0.0)) < float(item.get("base_cooldown", 0.0))

func _has_tag(item: Dictionary, tag: String) -> bool:
	for value in item.get("tags", []):
		if str(value) == tag:
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
