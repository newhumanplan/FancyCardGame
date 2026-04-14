extends Node

var _total: int = 0
var _passed: int = 0


func _ready() -> void:
	print("== test_monster_ai.gd ==")
	_run_tests()
	_print_summary()
	if get_tree():
		get_tree().quit()


func _monster_ai():
	return load("res://scripts/data/monster_ai.gd")


func _monster_data():
	return load("res://scripts/data/monster_data.gd").new()


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


func _run_tests() -> void:
	test_create_aggressive_sets_damage_speed_and_heal_defaults()
	test_create_defensive_sets_shield_and_heal_related_values()
	test_create_technical_sets_special_effect_values()
	test_create_boss_sets_heal_and_low_hp_rage_values()
	test_create_swarm_sets_attack_speed_multiplier()
	test_is_low_hp_true_below_threshold()
	test_is_low_hp_false_above_threshold()
	test_get_current_damage_multiplier_normal_hp()
	test_get_current_damage_multiplier_low_hp_uses_rage_bonus()
	test_should_heal_with_certain_heal_chance()
	test_should_heal_low_hp_bonus_can_force_heal()
	test_get_cooldown_modifier_matches_modes()
	test_get_mode_name_is_non_empty_for_all_modes()


func test_create_aggressive_sets_damage_speed_and_heal_defaults() -> void:
	var monster_ai = _monster_ai()
	var ai = monster_ai.create_aggressive()

	_assert_float_eq(ai.damage_multiplier, 1.3, "create_aggressive sets damage multiplier")
	_assert_float_eq(ai.attack_speed_multiplier, 1.0, "create_aggressive sets attack speed")
	_assert_float_eq(ai.heal_chance, 0.0, "create_aggressive keeps heal chance at zero")


func test_create_defensive_sets_shield_and_heal_related_values() -> void:
	var monster_ai = _monster_ai()
	var ai = monster_ai.create_defensive()

	_assert_float_eq(ai.damage_multiplier, 0.8, "create_defensive reduces damage")
	_assert_float_eq(ai.heal_chance, 0.15, "create_defensive sets heal chance")
	_assert_eq(ai.heal_amount, 5, "create_defensive sets heal amount")
	_assert_float_eq(ai.low_hp_heal_chance_bonus, 0.3, "create_defensive sets low hp heal bonus")


func test_create_technical_sets_special_effect_values() -> void:
	var monster_ai = _monster_ai()
	var ai = monster_ai.create_technical()

	_assert_float_eq(ai.special_effect_chance, 0.3, "create_technical sets special effect chance")
	_assert_eq(ai.special_effect_type, "poison", "create_technical sets special effect type")
	_assert_eq(ai.special_effect_value, 3, "create_technical sets special effect value")


func test_create_boss_sets_heal_and_low_hp_rage_values() -> void:
	var monster_ai = _monster_ai()
	var ai = monster_ai.create_boss()

	_assert_float_eq(ai.heal_chance, 0.05, "create_boss sets heal chance")
	_assert_eq(ai.heal_amount, 10, "create_boss sets heal amount")
	_assert_float_eq(ai.low_hp_threshold, 0.2, "create_boss lowers low hp threshold")
	_assert_float_eq(ai.low_hp_damage_multiplier, 1.6, "create_boss sets rage damage multiplier")


func test_create_swarm_sets_attack_speed_multiplier() -> void:
	var monster_ai = _monster_ai()
	var ai = monster_ai.create_swarm()

	_assert_float_eq(ai.attack_speed_multiplier, 2.0, "create_swarm doubles attack speed")


func test_is_low_hp_true_below_threshold() -> void:
	var monster_ai = _monster_ai()
	var ai = monster_ai.create_boss()
	var monster = _monster_data()
	monster.max_hp = 100
	monster.current_hp = 20

	_assert_true(ai.is_low_hp(monster), "is_low_hp returns true at threshold")


func test_is_low_hp_false_above_threshold() -> void:
	var monster_ai = _monster_ai()
	var ai = monster_ai.create_boss()
	var monster = _monster_data()
	monster.max_hp = 100
	monster.current_hp = 21

	_assert_true(not ai.is_low_hp(monster), "is_low_hp returns false above threshold")


func test_get_current_damage_multiplier_normal_hp() -> void:
	var monster_ai = _monster_ai()
	var ai = monster_ai.create_aggressive()
	var monster = _monster_data()
	monster.max_hp = 100
	monster.current_hp = 80

	_assert_float_eq(ai.get_current_damage_multiplier(monster), 1.3, "get_current_damage_multiplier uses base value at normal hp")


func test_get_current_damage_multiplier_low_hp_uses_rage_bonus() -> void:
	var monster_ai = _monster_ai()
	var ai = monster_ai.create_boss()
	var monster = _monster_data()
	monster.max_hp = 100
	monster.current_hp = 10

	_assert_float_eq(ai.get_current_damage_multiplier(monster), 1.6, "get_current_damage_multiplier uses low hp bonus")


func test_should_heal_with_certain_heal_chance() -> void:
	var monster_ai = _monster_ai()
	var ai = monster_ai.create_defensive()
	var monster = _monster_data()
	monster.max_hp = 100
	monster.current_hp = 80
	ai.heal_chance = 1.0

	_assert_true(ai.should_heal(monster), "should_heal returns true when heal chance is 1")


func test_should_heal_low_hp_bonus_can_force_heal() -> void:
	var monster_ai = _monster_ai()
	var ai = monster_ai.create_defensive()
	var monster = _monster_data()
	monster.max_hp = 100
	monster.current_hp = 20
	ai.heal_chance = 0.0
	ai.low_hp_heal_chance_bonus = 1.0

	_assert_true(ai.should_heal(monster), "should_heal applies low hp bonus")


func test_get_cooldown_modifier_matches_modes() -> void:
	var monster_ai = _monster_ai()

	_assert_float_eq(monster_ai.create_aggressive().get_cooldown_modifier(), 1.0, "get_cooldown_modifier aggressive")
	_assert_float_eq(monster_ai.create_defensive().get_cooldown_modifier(), 1.25, "get_cooldown_modifier defensive")
	_assert_float_eq(monster_ai.create_technical().get_cooldown_modifier(), 1.0 / 0.9, "get_cooldown_modifier technical")
	_assert_float_eq(monster_ai.create_boss().get_cooldown_modifier(), 1.0 / 1.2, "get_cooldown_modifier boss")
	_assert_float_eq(monster_ai.create_swarm().get_cooldown_modifier(), 0.5, "get_cooldown_modifier swarm")


func test_get_mode_name_is_non_empty_for_all_modes() -> void:
	var monster_ai = _monster_ai()
	var names = [
		monster_ai.create_aggressive().get_mode_name(),
		monster_ai.create_defensive().get_mode_name(),
		monster_ai.create_technical().get_mode_name(),
		monster_ai.create_boss().get_mode_name(),
		monster_ai.create_swarm().get_mode_name(),
	]

	for name in names:
		_assert_true(name.strip_edges() != "", "get_mode_name returns non-empty string")
