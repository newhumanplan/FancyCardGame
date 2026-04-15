extends Node

var _total: int = 0
var _passed: int = 0


func _ready() -> void:
	if not Engine.is_editor_hint():
		print("== tests/test_passive_skill.gd ==")
		_run_tests()
		_print_summary()


func _run_tests() -> void:
	test_apply_to_hero_updates_health_bonus()
	test_apply_to_hero_updates_crit_bonus()
	test_apply_to_hero_writes_combat_bonus_fields()
	test_description_helpers_return_expected_text()
	test_apply_to_hero_is_null_safe()


func _skill_script():
	return load("res://scripts/data/passive_skill.gd")


func _hero():
	var hero = load("res://scripts/data/hero_data.gd").new()
	hero.max_hp = 100
	hero.current_hp = 60
	hero.crit_chance = 0.05
	hero._combat_bonus_shield = 0.0
	hero._combat_cd_reduction = 0.0
	hero._combat_reflect = 0.0
	hero._combat_lifesteal = 0.0
	return hero


func _make_skill(effect_type: int, effect_value: float, name: String = "被动", description: String = "描述"):
	var skill = _skill_script().new()
	skill.skill_name = name
	skill.description = description
	skill.effect_type = effect_type
	skill.effect_value = effect_value
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


func test_apply_to_hero_updates_health_bonus() -> void:
	var skill_script = _skill_script()
	var hero = _hero()

	skill_script.apply_to_hero(_make_skill(skill_script.EffectType.HEALTH_BONUS, 40.0, "坚韧"), hero)

	_assert_eq(hero.max_hp, 140, "HEALTH_BONUS increases hero max hp")
	_assert_eq(hero.current_hp, 140, "HEALTH_BONUS refills current hp to new max")


func test_apply_to_hero_updates_crit_bonus() -> void:
	var skill_script = _skill_script()
	var hero = _hero()

	skill_script.apply_to_hero(_make_skill(skill_script.EffectType.CRIT_BONUS, 15.0, "鹰眼"), hero)

	_assert_float_eq(hero.crit_chance, 0.20, "CRIT_BONUS adds percent-based crit chance")


func test_apply_to_hero_writes_combat_bonus_fields() -> void:
	var skill_script = _skill_script()
	var hero = _hero()

	skill_script.apply_to_hero(_make_skill(skill_script.EffectType.SHIELD_BONUS, 25.0, "铁壁"), hero)
	skill_script.apply_to_hero(_make_skill(skill_script.EffectType.COOLDOWN_REDUCTION, 15.0, "迅捷"), hero)
	skill_script.apply_to_hero(_make_skill(skill_script.EffectType.DAMAGE_REFLECTION, 12.0, "反刺"), hero)
	skill_script.apply_to_hero(_make_skill(skill_script.EffectType.LIFESTEAL, 8.0, "汲取"), hero)

	_assert_float_eq(hero._combat_bonus_shield, 25.0, "SHIELD_BONUS writes _combat_bonus_shield")
	_assert_float_eq(hero._combat_cd_reduction, 0.15, "COOLDOWN_REDUCTION writes ratio to _combat_cd_reduction")
	_assert_float_eq(hero._combat_reflect, 0.12, "DAMAGE_REFLECTION writes ratio to _combat_reflect")
	_assert_float_eq(hero._combat_lifesteal, 0.08, "LIFESTEAL writes ratio to _combat_lifesteal")


func test_description_helpers_return_expected_text() -> void:
	var skill_script = _skill_script()
	var shield_skill = _make_skill(skill_script.EffectType.SHIELD_BONUS, 30.0, "铁壁", "增加护盾")

	_assert_eq(shield_skill.get_type_description(), "护盾 +30", "get_type_description formats effect text")
	_assert_eq(shield_skill.get_full_description(), "铁壁: 增加护盾", "get_full_description combines name and description")


func test_apply_to_hero_is_null_safe() -> void:
	var skill_script = _skill_script()
	var hero = _hero()
	var original_hp = hero.max_hp

	skill_script.apply_to_hero(null, hero)
	skill_script.apply_to_hero(_make_skill(skill_script.EffectType.HEALTH_BONUS, 20.0), null)

	_assert_eq(hero.max_hp, original_hp, "apply_to_hero ignores null inputs safely")
