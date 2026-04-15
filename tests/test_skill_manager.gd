extends Node

var _total: int = 0
var _passed: int = 0


func _ready() -> void:
	if not Engine.is_editor_hint():
		print("== tests/test_skill_manager.gd ==")
		_run_tests()
		_print_summary()


func _run_tests() -> void:
	test_equip_and_deduplicate_skills()
	test_unequip_and_get_equipped_skills_copy()
	test_get_total_effect_single_multi_and_none()
	test_get_skills_by_type_filters_correctly()
	test_clear_resets_unlock_state_and_storage()


func _manager():
	return load("res://scripts/data/skill_manager.gd").new()


func _skill_script():
	return load("res://scripts/data/skill_data.gd")


func _make_skill(skill_id: String, effect_type: int, values: Array[float], quality: int = 0, name: String = ""):
	var skill = _skill_script().new()
	skill.skill_id = skill_id
	skill.skill_name = name if not name.is_empty() else skill_id
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
	_assert_true(absf(actual - expected) <= tolerance, "%s | expected=%.3f actual=%.3f" % [label, expected, actual])


func _print_summary() -> void:
	print("SUMMARY: %d/%d passed" % [_passed, _total])


func test_equip_and_deduplicate_skills() -> void:
	var skill_data = _skill_script()
	var manager = _manager()
	var crit_skill = _make_skill("crit_1", skill_data.EffectType.CRIT, [5.0, 10.0, 15.0, 20.0], skill_data.Quality.SILVER)

	manager.equip_skill(crit_skill)
	manager.equip_skill(crit_skill)
	manager.equip_skill(_make_skill("", skill_data.EffectType.SHIELD, [10.0, 10.0, 10.0, 10.0]))

	_assert_eq(manager.get_skill_count(), 1, "equip_skill adds valid skill and ignores duplicate/invalid entries")
	_assert_true(crit_skill.unlocked, "equip_skill marks skill as unlocked")


func test_unequip_and_get_equipped_skills_copy() -> void:
	var skill_data = _skill_script()
	var manager = _manager()
	manager.equip_skill(_make_skill("crit_1", skill_data.EffectType.CRIT, [5.0, 10.0, 15.0, 20.0]))
	manager.equip_skill(_make_skill("shield_1", skill_data.EffectType.SHIELD, [8.0, 10.0, 12.0, 14.0]))

	var equipped = manager.get_equipped_skills()
	equipped.clear()
	manager.unequip_skill("crit_1")

	_assert_eq(manager.get_skill_count(), 1, "unequip_skill removes only requested skill")
	_assert_eq(manager.get_equipped_skills().size(), 1, "get_equipped_skills returns a copy")


func test_get_total_effect_single_multi_and_none() -> void:
	var skill_data = _skill_script()
	var manager = _manager()
	manager.equip_skill(_make_skill("crit_1", skill_data.EffectType.CRIT, [5.0, 10.0, 15.0, 20.0], skill_data.Quality.BRONZE))
	manager.equip_skill(_make_skill("crit_2", skill_data.EffectType.CRIT, [2.0, 4.0, 6.0, 8.0], skill_data.Quality.GOLD))
	manager.equip_skill(_make_skill("hp_1", skill_data.EffectType.HEALTH, [20.0, 30.0, 40.0, 50.0], skill_data.Quality.SILVER))

	_assert_float_eq(manager.get_total_effect(skill_data.EffectType.HEALTH), 30.0, "get_total_effect returns single matching skill value")
	_assert_float_eq(manager.get_total_effect(skill_data.EffectType.CRIT), 11.0, "get_total_effect stacks multiple matching skills")
	_assert_float_eq(manager.get_total_effect(skill_data.EffectType.FREEZE), 0.0, "get_total_effect returns zero without matching skills")


func test_get_skills_by_type_filters_correctly() -> void:
	var skill_data = _skill_script()
	var manager = _manager()
	manager.equip_skill(_make_skill("shield_1", skill_data.EffectType.SHIELD, [8.0, 10.0, 12.0, 14.0]))
	manager.equip_skill(_make_skill("shield_2", skill_data.EffectType.SHIELD, [4.0, 6.0, 8.0, 10.0]))
	manager.equip_skill(_make_skill("burn_1", skill_data.EffectType.BURN, [1.0, 2.0, 3.0, 4.0]))

	var shields = manager.get_skills_by_type(skill_data.EffectType.SHIELD)
	var burns = manager.get_skills_by_type(skill_data.EffectType.BURN)

	_assert_eq(shields.size(), 2, "get_skills_by_type returns all matching skills")
	_assert_eq(burns[0].skill_id, "burn_1", "get_skills_by_type preserves matching skill entries")


func test_clear_resets_unlock_state_and_storage() -> void:
	var skill_data = _skill_script()
	var manager = _manager()
	var crit_skill = _make_skill("crit_1", skill_data.EffectType.CRIT, [5.0, 10.0, 15.0, 20.0])
	var shield_skill = _make_skill("shield_1", skill_data.EffectType.SHIELD, [8.0, 10.0, 12.0, 14.0])
	manager.equip_skill(crit_skill)
	manager.equip_skill(shield_skill)

	manager.clear()

	_assert_eq(manager.get_skill_count(), 0, "clear removes all equipped skills")
	_assert_true(not crit_skill.unlocked and not shield_skill.unlocked, "clear resets unlocked flag on equipped skills")
