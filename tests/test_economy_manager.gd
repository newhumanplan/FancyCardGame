extends Node

var _total: int = 0
var _passed: int = 0


func _ready() -> void:
	if not Engine.is_editor_hint():
		print("== tests/test_economy_manager.gd ==")
		_run_tests()
		_print_summary()


func _run_tests() -> void:
	test_calculate_item_price_for_multiple_rarity_and_size_cases()
	test_apply_prestige_discount_for_full_and_zero_prestige()
	test_get_shop_item_count_before_and_after_day_five()
	test_get_max_rarity_progression()


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


func test_calculate_item_price_for_multiple_rarity_and_size_cases() -> void:
	var economy = _economy()

	var expected_by_size: Dictionary = {
		0: [2, 4, 8, 16],
		1: [4, 8, 16, 32],
		2: [6, 12, 24, 48],
	}
	for size in expected_by_size.keys():
		var expected_prices: Array = expected_by_size[size]
		for rarity_index in range(expected_prices.size()):
			var rarity: int = rarity_index + 1
			_assert_eq(
				economy.calculate_item_price(rarity, int(size), 0, 1),
				int(expected_prices[rarity_index]),
				"default price table size=%d rarity=%d" % [int(size), rarity]
			)
	_assert_eq(economy.calculate_item_price(3, 1, 0, 1), economy.calculate_item_price(3, 1, 3, 10), "default price ignores item type and day")


func test_apply_prestige_discount_for_full_and_zero_prestige() -> void:
	var economy = _economy()

	_assert_eq(economy.apply_prestige_discount(100, 20, 20), 80, "apply_prestige_discount gives max discount at full prestige")
	_assert_eq(economy.apply_prestige_discount(100, 0, 20), 100, "apply_prestige_discount gives no discount at zero prestige")


func test_get_shop_item_count_before_and_after_day_five() -> void:
	var economy = _economy()
	var early = economy.get_shop_item_count(3)
	var late = economy.get_shop_item_count(5)

	_assert_eq(early["min"], 3, "get_shop_item_count keeps early minimum count")
	_assert_eq(early["max"], 6, "get_shop_item_count keeps early maximum count")
	_assert_eq(late["min"], 3, "get_shop_item_count keeps late minimum count")
	_assert_eq(late["max"], 8, "get_shop_item_count expands late maximum count")


func test_get_max_rarity_progression() -> void:
	var economy = _economy()

	_assert_eq(economy.get_max_rarity(1), 1, "get_max_rarity returns common on day 1")
	_assert_eq(economy.get_max_rarity(3), 2, "get_max_rarity returns rare on day 3")
	_assert_eq(economy.get_max_rarity(5), 3, "get_max_rarity returns epic on day 5")
	_assert_eq(economy.get_max_rarity(7), 4, "get_max_rarity returns legendary on day 7")
