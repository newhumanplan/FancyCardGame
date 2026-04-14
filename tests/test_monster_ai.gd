extends Node

var _total: int = 0
var _passed: int = 0


func _ready() -> void:
	print("== tests/test_monster_ai.gd ==")
	_run_tests()
	_print_summary()
	get_tree().quit()


func _run_tests() -> void:
	test_factory_methods_create_expected_presets()
	test_is_low_hp_and_damage_multiplier_follow_threshold()
	test_should_heal_uses_base_and_low_hp_bonus()
	test_get_mode_name_returns_expected_labels()


func _ai_script():
	return load("res://scripts/data/monster_ai.gd")


func _monster(max_hp: int, current_hp: int):
	var monster = load("res://scripts/data/monster_data.gd").new()
	monster.max_hp = max_hp
	monster.current_hp = current_hp
	return monster


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


func test_factory_methods_create_expected_presets() -> void:
	var ai_script = _ai_script()
	var aggressive = ai_script.create_aggressive()
	var defensive = ai_script.create_defensive()
	var technical = ai_script.create_technical()
	var boss = ai_script.create_boss()
	var swarm = ai_script.create_swarm()

	_assert_float_eq(aggressive.damage_multiplier, 1.3, "create_aggressive sets damage multiplier")
	_assert_float_eq(defensive.heal_chance, 0.15, "create_defensive sets heal chance")
	_assert_eq(technical.special_effect_type, "poison", "create_technical sets poison special effect")
	_assert_float_eq(boss.low_hp_damage_multiplier, 1.6, "create_boss sets low hp damage multiplier")
	_assert_float_eq(swarm.attack_speed_multiplier, 2.0, "create_swarm sets fast attack speed")


func test_is_low_hp_and_damage_multiplier_follow_threshold() -> void:
	var ai_script = _ai_script()
	var aggressive = ai_script.create_aggressive()
	var boss = ai_script.create_boss()
	var healthy_monster = _monster(100, 80)
	var low_hp_monster = _monster(100, 20)
	var very_low_hp_monster = _monster(100, 10)

	_assert_true(not aggressive.is_low_hp(healthy_monster), "is_low_hp returns false above threshold")
	_assert_true(boss.is_low_hp(low_hp_monster), "is_low_hp returns true at threshold")
	_assert_float_eq(aggressive.get_current_damage_multiplier(healthy_monster), 1.3, "get_current_damage_multiplier keeps base multiplier when healthy")
	_assert_float_eq(boss.get_current_damage_multiplier(very_low_hp_monster), 1.6, "get_current_damage_multiplier switches to low hp multiplier")


func test_should_heal_uses_base_and_low_hp_bonus() -> void:
	var ai_script = _ai_script()
	var defensive = ai_script.create_defensive()
	var healthy_monster = _monster(100, 80)
	var low_hp_monster = _monster(100, 20)

	defensive.heal_chance = 1.0
	defensive.low_hp_heal_chance_bonus = 0.0
	_assert_true(defensive.should_heal(healthy_monster), "should_heal returns true with guaranteed base chance")

	defensive.heal_chance = 0.0
	defensive.low_hp_heal_chance_bonus = 1.0
	_assert_true(defensive.should_heal(low_hp_monster), "should_heal returns true with guaranteed low hp bonus")


func test_get_mode_name_returns_expected_labels() -> void:
	var ai_script = _ai_script()

	_assert_eq(ai_script.create_aggressive().get_mode_name(), "激进", "get_mode_name returns aggressive label")
	_assert_eq(ai_script.create_defensive().get_mode_name(), "防御", "get_mode_name returns defensive label")
	_assert_eq(ai_script.create_technical().get_mode_name(), "技术", "get_mode_name returns technical label")
	_assert_eq(ai_script.create_boss().get_mode_name(), "Boss", "get_mode_name returns boss label")
	_assert_eq(ai_script.create_swarm().get_mode_name(), "蜂群", "get_mode_name returns swarm label")
