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

	_assert_eq(economy.calculate_item_price(1, 0, 0, 1), 12, "calculate_item_price handles common small weapon on day 1")
	_assert_eq(economy.calculate_item_price(3, 1, 2, 4), 67, "calculate_item_price handles epic medium heal item on day 4")
	_assert_eq(economy.calculate_item_price(4, 2, 3, 7), 200, "calculate_item_price clamps very expensive items to max price")


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
