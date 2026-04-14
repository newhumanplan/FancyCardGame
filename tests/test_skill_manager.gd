extends Node

var _total: int = 0
var _passed: int = 0


func _ready() -> void:
	print("== test_skill_manager.gd ==")
	_run_tests()
	_print_summary()
	if get_tree():
		get_tree().quit()


func _run_tests() -> void:
	test_equip_skill_adds_single_skill()
	test_equip_skill_ignores_duplicate()
	test_equip_skill_supports_multiple_skills()
	test_unequip_skill_removes_existing_skill()
	test_unequip_skill_ignores_missing_skill()
	test_get_total_effect_for_single_skill()
	test_get_total_effect_stacks_multiple_skills()
	test_get_total_effect_returns_zero_without_match()
	test_get_skills_by_type_returns_matches()
	test_get_skills_by_type_returns_empty_without_match()
	test_get_skill_count_tracks_equipped_and_clear()
	test_clear_removes_all_skills()


func _skill_manager():
	return load("res://scripts/data/skill_manager.gd").new()


func _make_skill(skill_id: String, effect_type: int, values: Array[float], quality: int = 0):
	var script = load("res://scripts/data/skill_data.gd")
	var skill = script.new()
	skill.skill_id = skill_id
	skill.skill_name = "Skill %s" % skill_id
	skill.effect_type = effect_type
	skill.effect_values = values
	skill.quality = quality
	return skill


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
	_assert_true(abs(actual - expected) <= tolerance, "%s | expected=%.3f actual=%.3f" % [label, expected, actual])


func _print_summary() -> void:
	print("SUMMARY: %d/%d passed" % [_passed, _total])


func test_equip_skill_adds_single_skill() -> void:
	var skill_data = load("res://scripts/data/skill_data.gd")
	var manager = _skill_manager()
	var skill = _make_skill("crit_1", skill_data.EffectType.CRIT, [0.1, 0.2, 0.3, 0.4])

	manager.equip_skill(skill)

	_assert_eq(manager.get_skill_count(), 1, "equip_skill adds one skill")
	_assert_true(skill.unlocked, "equip_skill marks skill unlocked")


func test_equip_skill_ignores_duplicate() -> void:
	var skill_data = load("res://scripts/data/skill_data.gd")
	var manager = _skill_manager()
	var skill = _make_skill("shield_1", skill_data.EffectType.SHIELD, [5.0, 10.0, 15.0, 20.0])

	manager.equip_skill(skill)
	manager.equip_skill(skill)

	_assert_eq(manager.get_skill_count(), 1, "equip_skill ignores duplicate by skill_id")


func test_equip_skill_supports_multiple_skills() -> void:
	var skill_data = load("res://scripts/data/skill_data.gd")
	var manager = _skill_manager()

	manager.equip_skill(_make_skill("crit_1", skill_data.EffectType.CRIT, [0.1, 0.2, 0.3, 0.4]))
	manager.equip_skill(_make_skill("shield_1", skill_data.EffectType.SHIELD, [5.0, 10.0, 15.0, 20.0]))
	manager.equip_skill(_make_skill("crit_2", skill_data.EffectType.CRIT, [0.05, 0.1, 0.15, 0.2]))

	_assert_eq(manager.get_skill_count(), 3, "equip_skill supports multiple distinct skills")


func test_unequip_skill_removes_existing_skill() -> void:
	var skill_data = load("res://scripts/data/skill_data.gd")
	var manager = _skill_manager()
	var skill = _make_skill("crit_1", skill_data.EffectType.CRIT, [0.1, 0.2, 0.3, 0.4])
	manager.equip_skill(skill)

	manager.unequip_skill("crit_1")

	_assert_eq(manager.get_skill_count(), 0, "unequip_skill removes existing skill")


func test_unequip_skill_ignores_missing_skill() -> void:
	var skill_data = load("res://scripts/data/skill_data.gd")
	var manager = _skill_manager()
	manager.equip_skill(_make_skill("crit_1", skill_data.EffectType.CRIT, [0.1, 0.2, 0.3, 0.4]))

	manager.unequip_skill("missing")

	_assert_eq(manager.get_skill_count(), 1, "unequip_skill ignores missing skill_id")


func test_get_total_effect_for_single_skill() -> void:
	var skill_data = load("res://scripts/data/skill_data.gd")
	var manager = _skill_manager()
	var skill = _make_skill("crit_1", skill_data.EffectType.CRIT, [0.1, 0.2, 0.3, 0.4], skill_data.Quality.GOLD)
	manager.equip_skill(skill)

	_assert_float_eq(manager.get_total_effect(skill_data.EffectType.CRIT), 0.3, "get_total_effect returns one skill value")


func test_get_total_effect_stacks_multiple_skills() -> void:
	var skill_data = load("res://scripts/data/skill_data.gd")
	var manager = _skill_manager()
	manager.equip_skill(_make_skill("crit_1", skill_data.EffectType.CRIT, [0.1, 0.2, 0.3, 0.4], skill_data.Quality.SILVER))
	manager.equip_skill(_make_skill("crit_2", skill_data.EffectType.CRIT, [0.05, 0.1, 0.15, 0.2], skill_data.Quality.GOLD))

	_assert_float_eq(manager.get_total_effect(skill_data.EffectType.CRIT), 0.35, "get_total_effect stacks multiple skills")


func test_get_total_effect_returns_zero_without_match() -> void:
	var skill_data = load("res://scripts/data/skill_data.gd")
	var manager = _skill_manager()
	manager.equip_skill(_make_skill("shield_1", skill_data.EffectType.SHIELD, [5.0, 10.0, 15.0, 20.0]))

	_assert_float_eq(manager.get_total_effect(skill_data.EffectType.CRIT), 0.0, "get_total_effect returns zero without matching type")


func test_get_skills_by_type_returns_matches() -> void:
	var skill_data = load("res://scripts/data/skill_data.gd")
	var manager = _skill_manager()
	manager.equip_skill(_make_skill("crit_1", skill_data.EffectType.CRIT, [0.1, 0.2, 0.3, 0.4]))
	manager.equip_skill(_make_skill("shield_1", skill_data.EffectType.SHIELD, [5.0, 10.0, 15.0, 20.0]))
	manager.equip_skill(_make_skill("crit_2", skill_data.EffectType.CRIT, [0.05, 0.1, 0.15, 0.2]))

	var result = manager.get_skills_by_type(skill_data.EffectType.CRIT)

	_assert_eq(result.size(), 2, "get_skills_by_type returns matching skills")


func test_get_skills_by_type_returns_empty_without_match() -> void:
	var skill_data = load("res://scripts/data/skill_data.gd")
	var manager = _skill_manager()
	manager.equip_skill(_make_skill("shield_1", skill_data.EffectType.SHIELD, [5.0, 10.0, 15.0, 20.0]))

	var result = manager.get_skills_by_type(skill_data.EffectType.CRIT)

	_assert_eq(result.size(), 0, "get_skills_by_type returns empty without match")


func test_get_skill_count_tracks_equipped_and_clear() -> void:
	var skill_data = load("res://scripts/data/skill_data.gd")
	var manager = _skill_manager()
	manager.equip_skill(_make_skill("crit_1", skill_data.EffectType.CRIT, [0.1, 0.2, 0.3, 0.4]))
	manager.equip_skill(_make_skill("shield_1", skill_data.EffectType.SHIELD, [5.0, 10.0, 15.0, 20.0]))
	_assert_eq(manager.get_skill_count(), 2, "get_skill_count reports equipped size")

	manager.clear()

	_assert_eq(manager.get_skill_count(), 0, "get_skill_count returns zero after clear")


func test_clear_removes_all_skills() -> void:
	var skill_data = load("res://scripts/data/skill_data.gd")
	var manager = _skill_manager()
	manager.equip_skill(_make_skill("crit_1", skill_data.EffectType.CRIT, [0.1, 0.2, 0.3, 0.4]))
	manager.equip_skill(_make_skill("shield_1", skill_data.EffectType.SHIELD, [5.0, 10.0, 15.0, 20.0]))

	manager.clear()

	_assert_eq(manager.get_equipped_skills().size(), 0, "clear removes all equipped skills")
