extends Node

const EconomyManagerClass = preload("res://scripts/data/economy_manager.gd")
const BazaarContentClass = preload("res://scripts/data/bazaar_content.gd")
const ItemDataClass = preload("res://scripts/data/item_data.gd")

var _total: int = 0
var _passed: int = 0

func _ready() -> void:
	if not Engine.is_editor_hint():
		print("== tests/test_item_price_rarity_border.gd ==")
		test_default_price_formula_table()
		test_source_catalog_items_use_normalized_default_price()
		test_rarity_border_color_helper()
		test_shop_and_inventory_use_rarity_border_styles()
		_print_summary()

func test_default_price_formula_table() -> void:
	var expected_by_size: Dictionary = {
		ItemDataClass.Size.SMALL: [2, 4, 8, 16],
		ItemDataClass.Size.MEDIUM: [4, 8, 16, 32],
		ItemDataClass.Size.LARGE: [6, 12, 24, 48],
	}
	for size in expected_by_size.keys():
		var expected_prices: Array = expected_by_size[size]
		for rarity_index in range(expected_prices.size()):
			var rarity: int = rarity_index + 1
			_assert_eq(
				EconomyManagerClass.calculate_item_price(rarity, int(size), ItemDataClass.Type.WEAPON, 1),
				int(expected_prices[rarity_index]),
				"price table size=%d rarity=%d" % [int(size), rarity]
			)

func test_source_catalog_items_use_normalized_default_price() -> void:
	var fire_potion: ItemDataClass = BazaarContentClass.create_item("fire_potion", BazaarContentClass.RARITY_DIAMOND)
	_assert_eq(fire_potion.buy_price, 16, "small diamond source-backed item price")

	var apothecary: ItemDataClass = BazaarContentClass.create_item("apothecary", BazaarContentClass.RARITY_SILVER)
	_assert_eq(apothecary.buy_price, 12, "large silver source-backed item price")

	var sulphur: ItemDataClass = BazaarContentClass.create_item("sulphur", BazaarContentClass.RARITY_BRONZE)
	_assert_eq(sulphur.buy_price, 2, "explicit catalog cost does not override baseline")

func test_rarity_border_color_helper() -> void:
	var bronze: Color = ItemDataClass.get_rarity_border_color(BazaarContentClass.RARITY_BRONZE)
	var silver: Color = ItemDataClass.get_rarity_border_color(BazaarContentClass.RARITY_SILVER)
	var gold: Color = ItemDataClass.get_rarity_border_color(BazaarContentClass.RARITY_GOLD)
	var diamond: Color = ItemDataClass.get_rarity_border_color(BazaarContentClass.RARITY_DIAMOND)
	_assert_true(bronze.r > bronze.b, "bronze border reads warm/copper")
	_assert_true(silver.r > 0.75 and silver.g > 0.75 and silver.b > 0.75, "silver border reads light gray")
	_assert_true(gold.r > 0.90 and gold.g > 0.55 and gold.b < 0.35, "gold border reads gold")
	_assert_true(diamond.b > 0.90 and diamond.g > 0.85, "diamond border reads cyan-white")

func test_shop_and_inventory_use_rarity_border_styles() -> void:
	var shop_source: String = _read_text("res://scripts/ui/shop_ui.gd")
	var inventory_source: String = _read_text("res://scripts/ui/inventory_ui.gd")
	var battle_source: String = _read_text("res://scripts/ui/battle_ui.gd")
	_assert_true(shop_source.find("card_style.border_color = item.get_rarity_color()") >= 0, "shop card outer border uses item rarity color")
	_assert_true(shop_source.find("card_style.set_border_width_all(4)") >= 0, "shop card rarity border is visibly thick")
	_assert_true(inventory_source.find("style.border_color = item_color") >= 0, "inventory item card border uses rarity color")
	_assert_true(inventory_source.find("style.set_border_width_all(3)") >= 0, "inventory card rarity border is visibly thick")
	_assert_true(battle_source.find("style.border_color = colors[\"border\"]") >= 0, "battle item card border keeps rarity color")

func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_as_text() if file != null else ""

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
