extends Node

var _total: int = 0
var _passed: int = 0


func _ready() -> void:
	print("== tests/test_skill_effects.gd ==")
	_run_tests()
	_print_summary()
	get_tree().quit()


func _run_tests() -> void:
	test_apply_passive_skills_updates_crit_health_and_shield()
	test_apply_passive_skills_stacks_multiple_skills()
	test_get_effects_summary_returns_lines_for_non_empty_skills()
	test_get_effects_summary_returns_empty_message()


func _skill_script():
	return load("res://scripts/data/skill_data.gd")


func _effects_script():
	return load("res://scripts/data/skill_effects.gd")


func _hero():
	var hero = load("res://scripts/data/hero_data.gd").new()
	hero.max_hp = 100
	hero.current_hp = 80
	hero.crit_chance = 0.10
	return hero


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


func test_apply_passive_skills_updates_crit_health_and_shield() -> void:
	var skill_data = _skill_script()
	var hero = _hero()
	var skills = [
		_make_skill("crit_1", skill_data.EffectType.CRIT, [10.0, 15.0, 20.0, 25.0]),
		_make_skill("health_1", skill_data.EffectType.HEALTH, [30.0, 40.0, 50.0, 60.0]),
		_make_skill("shield_1", skill_data.EffectType.SHIELD, [12.0, 16.0, 20.0, 24.0]),
	]

	var modifiers = _effects_script().apply_passive_skills(skills, hero)

	_assert_float_eq(hero.crit_chance, 0.20, "apply_passive_skills adds crit bonus to hero")
	_assert_eq(hero.max_hp, 130, "apply_passive_skills adds max health to hero")
	_assert_eq(hero.current_hp, 80, "apply_passive_skills keeps current hp clamped to new max")
	_assert_float_eq(float(modifiers["shield_bonus"]), 12.0, "apply_passive_skills returns shield modifier")


func test_apply_passive_skills_stacks_multiple_skills() -> void:
	var skill_data = _skill_script()
	var hero = _hero()
	var skills = [
		_make_skill("crit_1", skill_data.EffectType.CRIT, [10.0, 10.0, 10.0, 10.0]),
		_make_skill("crit_2", skill_data.EffectType.CRIT, [5.0, 5.0, 5.0, 5.0]),
		_make_skill("health_1", skill_data.EffectType.HEALTH, [20.0, 20.0, 20.0, 20.0]),
		_make_skill("cooldown_1", skill_data.EffectType.COOLDOWN, [10.0, 10.0, 10.0, 10.0]),
	]

	var modifiers = _effects_script().apply_passive_skills(skills, hero)

	_assert_float_eq(hero.crit_chance, 0.25, "apply_passive_skills stacks crit bonuses")
	_assert_eq(hero.max_hp, 120, "apply_passive_skills stacks health bonuses")
	_assert_float_eq(float(modifiers["cooldown_reduction"]), 0.10, "apply_passive_skills converts cooldown bonus to ratio")


func test_get_effects_summary_returns_lines_for_non_empty_skills() -> void:
	var skill_data = _skill_script()
	var skills = [
		_make_skill("crit_1", skill_data.EffectType.CRIT, [10.0, 10.0, 10.0, 10.0], skill_data.Quality.BRONZE, "鹰眼"),
		_make_skill("burn_1", skill_data.EffectType.BURN, [3.0, 3.0, 3.0, 3.0], skill_data.Quality.GOLD, "火印"),
	]

	var summary = _effects_script().get_effects_summary(skills)

	_assert_true("铜 暴击: +10.0" in summary, "get_effects_summary formats crit line")
	_assert_true("金 燃烧: +3.0" in summary, "get_effects_summary formats burn line")


func test_get_effects_summary_returns_empty_message() -> void:
	var summary = _effects_script().get_effects_summary([])

	_assert_eq(summary, "无技能效果", "get_effects_summary returns empty-state text for empty list")
