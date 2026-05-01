extends Node

const BazaarContentClass = preload("res://scripts/data/bazaar_content.gd")
const LinearInventoryClass = preload("res://scripts/data/linear_inventory.gd")
const SellServiceClass = preload("res://scripts/services/sell_service.gd")

var _total: int = 0
var _passed: int = 0

func _ready() -> void:
	if not Engine.is_editor_hint():
		print("== tests/test_sell_service.gd ==")
		_run_tests()
		_print_summary()

func _run_tests() -> void:
	test_sell_price_respects_explicit_value_and_no_base_value_rules()
	test_sell_service_removes_item_and_adds_gold()
	test_catalyst_sale_transforms_leftmost_small_item()
	test_inventory_ui_sell_button_uses_sell_service()

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
	get_tree().quit(1 if _passed < _total else 0)

func test_sell_price_respects_explicit_value_and_no_base_value_rules() -> void:
	var spare_change = BazaarContentClass.create_item("spare_change", BazaarContentClass.RARITY_BRONZE)
	var chocolate_bar = BazaarContentClass.create_item("chocolate_bar", BazaarContentClass.RARITY_BRONZE)
	var fang = BazaarContentClass.create_item("fang", BazaarContentClass.RARITY_BRONZE)

	_assert_eq(SellServiceClass.calculate_sell_price(spare_change), 1, "explicit sell-value item uses wiki worth value")
	_assert_eq(SellServiceClass.calculate_sell_price(chocolate_bar), 0, "no-base-value item sells for zero")
	_assert_eq(SellServiceClass.calculate_sell_price(fang), fang.buy_price, "normal item sells for its current base value")

func test_sell_service_removes_item_and_adds_gold() -> void:
	var inventory: LinearInventoryClass = LinearInventoryClass.new()
	var fang = BazaarContentClass.create_item("fang", BazaarContentClass.RARITY_BRONZE)
	_assert_true(inventory.place_item(fang, 0), "places Fang for sell test")
	GameManager.call("reset_stats")
	GameManager.set("gold", 10)

	var result: Dictionary = SellServiceClass.sell_item(fang, inventory)

	_assert_true(bool(result.get("success", false)), "sell service reports success")
	_assert_eq(inventory.get_item_count(), 0, "sold item is removed from inventory")
	_assert_eq(int(GameManager.get("gold")), 12, "selling adds gold using sell service rule")

func test_catalyst_sale_transforms_leftmost_small_item() -> void:
	var inventory: LinearInventoryClass = LinearInventoryClass.new()
	var catalyst = BazaarContentClass.create_item("catalyst", BazaarContentClass.RARITY_BRONZE)
	var original = BazaarContentClass.create_item("fang", BazaarContentClass.RARITY_BRONZE)
	_assert_true(inventory.place_item(catalyst, 0), "places Catalyst")
	_assert_true(inventory.place_item(original, 1), "places sell target")
	GameManager.call("reset_stats")

	var result: Dictionary = SellServiceClass.sell_item(catalyst, inventory)
	var transformed = inventory.get_item_at(1)

	_assert_true(bool(result.get("success", false)), "catalyst sale succeeds")
	_assert_eq(inventory.get_item_count(), 1, "catalyst is removed while transformed item remains")
	_assert_true(transformed != null and transformed != original, "catalyst replaces the leftmost small item with a new item instance")

func test_inventory_ui_sell_button_uses_sell_service() -> void:
	var scene: PackedScene = load("res://scenes/inventory_ui.tscn")
	var inventory_ui: Control = scene.instantiate() as Control
	add_child(inventory_ui)
	var inventory: LinearInventoryClass = LinearInventoryClass.new()
	var fang = BazaarContentClass.create_item("fang", BazaarContentClass.RARITY_BRONZE)
	_assert_true(inventory.place_item(fang, 0), "places Fang in InventoryUI")
	inventory_ui.call("set_inventory", inventory)
	GameManager.call("reset_stats")
	GameManager.set("gold", 0)

	inventory_ui.call("_show_item_detail", fang)
	var detail_panel: Control = inventory_ui.get("detail_panel") as Control
	var sell_button: Button = detail_panel.find_child("SellButton", true, false) as Button
	_assert_true(sell_button != null, "inventory detail panel exposes a sell button")
	if sell_button != null:
		sell_button.emit_signal("pressed")

	_assert_eq(inventory.get_item_count(), 0, "InventoryUI sell button removes the item through SellService")
	_assert_eq(int(GameManager.get("gold")), 2, "InventoryUI sell button updates gold via SellService")
