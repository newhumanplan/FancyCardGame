extends Node

var _total: int = 0
var _passed: int = 0


func _ready() -> void:
	print("== test_economy_manager.gd ==")
	_run_tests()
	_print_summary()
	if get_tree():
		get_tree().quit()


func _economy():
	return load("res://scripts/data/economy_manager.gd")


func _assert_true(condition: bool, label: String) -> void:
	_total += 1
	if condition:
		_passed += 1
		print("PASS: %s" % label)
	else:
		push_error("FAIL: %s" % label)


func _assert_eq(actual, expected, label: String) -> void:
	_assert_true(actual == expected, "%s | expected=%s actual=%s" % [label, str(expected), str(actual)])


func _print_summary() -> void:
	print("SUMMARY: %d/%d passed" % [_passed, _total])


func _run_tests() -> void:
	test_calculate_item_price_common_small_weapon_day_1()
	test_calculate_item_price_legendary_large_utility_day_7()
	test_calculate_item_price_invalid_rarity_falls_back()
	test_calculate_monster_gold_multiple_days()
	test_calculate_pvp_gold_multiple_days()
	test_apply_prestige_discount_full_prestige()
	test_apply_prestige_discount_zero_prestige()
	test_apply_prestige_discount_half_prestige()
	test_get_shop_item_count_before_day_5()
	test_get_shop_item_count_from_day_5()
	test_get_max_rarity_for_day_1()
	test_get_max_rarity_for_day_3()
	test_get_max_rarity_for_day_5()
	test_get_max_rarity_for_day_7()


func test_calculate_item_price_common_small_weapon_day_1() -> void:
	var economy = _economy()

	_assert_eq(economy.calculate_item_price(1, 0, 0, 1), 12, "calculate_item_price common small weapon day 1")


func test_calculate_item_price_legendary_large_utility_day_7() -> void:
	var economy = _economy()

	_assert_eq(economy.calculate_item_price(4, 2, 3, 7), 200, "calculate_item_price clamps expensive items at max price")


func test_calculate_item_price_invalid_rarity_falls_back() -> void:
	var economy = _economy()

	_assert_eq(economy.calculate_item_price(0, 1, 1, 3), 10, "calculate_item_price invalid rarity returns fallback")


func test_calculate_monster_gold_multiple_days() -> void:
	var economy = _economy()

	_assert_eq(economy.calculate_monster_gold(1), 11, "calculate_monster_gold day 1")
	_assert_eq(economy.calculate_monster_gold(5), 23, "calculate_monster_gold day 5")
	_assert_eq(economy.calculate_monster_gold(10), 38, "calculate_monster_gold day 10")


func test_calculate_pvp_gold_multiple_days() -> void:
	var economy = _economy()

	_assert_eq(economy.calculate_pvp_gold(1), 17, "calculate_pvp_gold day 1")
	_assert_eq(economy.calculate_pvp_gold(5), 37, "calculate_pvp_gold day 5")
	_assert_eq(economy.calculate_pvp_gold(10), 62, "calculate_pvp_gold day 10")


func test_apply_prestige_discount_full_prestige() -> void:
	var economy = _economy()

	_assert_eq(economy.apply_prestige_discount(100, 20, 20), 80, "apply_prestige_discount full prestige applies 20 percent off")


func test_apply_prestige_discount_zero_prestige() -> void:
	var economy = _economy()

	_assert_eq(economy.apply_prestige_discount(100, 0, 20), 100, "apply_prestige_discount zero prestige keeps price")


func test_apply_prestige_discount_half_prestige() -> void:
	var economy = _economy()

	_assert_eq(economy.apply_prestige_discount(100, 10, 20), 90, "apply_prestige_discount half prestige applies half discount")


func test_get_shop_item_count_before_day_5() -> void:
	var economy = _economy()
	var result = economy.get_shop_item_count(3)

	_assert_eq(result["min"], 3, "get_shop_item_count keeps min before day 5")
	_assert_eq(result["max"], 6, "get_shop_item_count keeps max before day 5")


func test_get_shop_item_count_from_day_5() -> void:
	var economy = _economy()
	var result = economy.get_shop_item_count(5)

	_assert_eq(result["min"], 3, "get_shop_item_count keeps min on day 5+")
	_assert_eq(result["max"], 8, "get_shop_item_count increases max on day 5+")


func test_get_max_rarity_for_day_1() -> void:
	var economy = _economy()

	_assert_eq(economy.get_max_rarity(1), 2, "get_max_rarity day 1 follows current unlock thresholds")


func test_get_max_rarity_for_day_3() -> void:
	var economy = _economy()

	_assert_eq(economy.get_max_rarity(3), 3, "get_max_rarity day 3 returns epic tier")


func test_get_max_rarity_for_day_5() -> void:
	var economy = _economy()

	_assert_eq(economy.get_max_rarity(5), 4, "get_max_rarity day 5 returns legendary tier")


func test_get_max_rarity_for_day_7() -> void:
	var economy = _economy()

	_assert_eq(economy.get_max_rarity(7), 4, "get_max_rarity day 7 remains legendary tier")
