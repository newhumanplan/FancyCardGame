extends Node

var _total: int = 0
var _passed: int = 0


func _ready() -> void:
	if not Engine.is_editor_hint():
		print("== tests/test_item_effects.gd ==")
		_run_tests()
		_print_summary()


func _run_tests() -> void:
	test_calculate_damage_handles_normal_crit_and_rarity()
	test_calculate_heal_and_shield_handle_null_and_normal_values()
	test_build_active_effects_creates_poison_burn_and_regen()
	test_build_active_effects_returns_empty_for_plain_items()
	test_active_effects_merge_accepts_item_effect_output()
	test_get_item_summary_includes_core_stats_and_special_effects()


func _item_script():
	return load("res://scripts/data/item_data.gd")


func _effects_script():
	return load("res://scripts/data/item_effects.gd")


func _effect_runtime_script():
	return load("res://scripts/data/battle_effect_runtime.gd")


func _item(name: String = "物品"):
	var item = _item_script().new()
	item.item_name = name
	return item


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


func _find_effect(effects: Array, effect_type: String) -> Dictionary:
	for effect in effects:
		if str(effect.get("type", "")) == effect_type:
			return effect
	return {}


func _print_summary() -> void:
	print("SUMMARY: %d/%d passed" % [_passed, _total])
	get_tree().quit(1 if _passed < _total else 0)


func test_calculate_damage_handles_normal_crit_and_rarity() -> void:
	var item = _item("火刃")
	item.damage = 20
	item.rarity = 3

	_assert_eq(_effects_script().calculate_damage(item, false), 20, "calculate_damage uses wiki-selected rarity value")
	_assert_eq(_effects_script().calculate_damage(item, true), 40, "calculate_damage doubles damage on crit")
	_assert_eq(_effects_script().calculate_damage(null, false), 0, "calculate_damage is null-safe")


func test_calculate_heal_and_shield_handle_null_and_normal_values() -> void:
	var item = _item("圣杯")
	item.heal = 15
	item.shield = 10
	item.rarity = 2

	_assert_eq(_effects_script().calculate_heal(item), 15, "calculate_heal uses wiki-selected rarity value")
	_assert_eq(_effects_script().calculate_shield(item), 10, "calculate_shield uses wiki-selected rarity value")
	_assert_eq(_effects_script().calculate_heal(null), 0, "calculate_heal is null-safe")
	_assert_eq(_effects_script().calculate_shield(null), 0, "calculate_shield is null-safe")


func test_build_active_effects_creates_poison_burn_and_regen() -> void:
	var item = _item("灾厄瓶")
	item.poison_damage = 5.0
	item.burn_damage = 4.0
	item.regeneration = 3.0
	item.rarity = 2

	var effects = _effects_script().build_active_effects(item, true)
	var poison = _find_effect(effects, "poison")
	var burn = _find_effect(effects, "burn")
	var regen = _find_effect(effects, "regeneration")

	_assert_float_eq(float(poison.get("value", 0.0)), 10.0, "build_active_effects applies crit without double-scaling wiki values")
	_assert_float_eq(float(burn.get("value", 0.0)), 8.0, "build_active_effects applies crit without double-scaling wiki values")
	_assert_float_eq(float(regen.get("value", 0.0)), 6.0, "build_active_effects applies crit without double-scaling wiki values")
	_assert_eq(str(regen.get("target", "")), "self", "build_active_effects targets regeneration at self")


func test_build_active_effects_returns_empty_for_plain_items() -> void:
	var item = _item("普通剑")
	item.damage = 12

	_assert_true(_effects_script().build_active_effects(item, false).is_empty(), "build_active_effects returns empty list for items without status effects")


func test_active_effects_merge_accepts_item_effect_output() -> void:
	var item = _item("Nightshade")
	item.poison_damage = 6.0

	var merged: Array[Dictionary] = _effect_runtime_script().merge_skill_bonuses(_effects_script().build_active_effects(item, false), 0.0, 2.0)
	var poison = _find_effect(merged, "poison")

	_assert_float_eq(float(poison.get("value", 0.0)), 8.0, "merge_skill_bonuses accepts build_active_effects output and applies poison bonus")


func test_get_item_summary_includes_core_stats_and_special_effects() -> void:
	var item = _item("烈焰护符")
	item.damage = 10
	item.shield = 6
	item.heal = 8
	item.crit_chance = 0.10
	item.burn_damage = 2.5
	item.rarity = 2

	var summary = _effects_script().get_item_summary(item)

	_assert_true("伤害:10" in summary, "get_item_summary includes wiki-selected damage")
	_assert_true("护盾:6" in summary, "get_item_summary includes wiki-selected shield")
	_assert_true("治疗:8" in summary, "get_item_summary includes wiki-selected heal")
	_assert_true("暴击:10%" in summary, "get_item_summary includes wiki-selected crit")
	_assert_true("燃烧 +2" in summary, "get_item_summary includes special effect description")
