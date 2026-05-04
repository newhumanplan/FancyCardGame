extends Node

const BazaarContentClass = preload("res://scripts/data/bazaar_content.gd")
const EffectDefinitionClass = preload("res://scripts/data/effect_definition.gd")
const HeroDataClass = preload("res://scripts/data/hero_data.gd")
const ItemDataClass = preload("res://scripts/data/item_data.gd")
const LinearInventoryClass = preload("res://scripts/data/linear_inventory.gd")

var _passed: int = 0
var _failed: int = 0

func _ready() -> void:
	print("== tests/test_item_effect_reachable_coverage.gd ==")
	test_reachable_warning_report_is_explicit_and_reduced()
	test_karnok_reachable_items_can_be_created()
	test_sell_service_backed_items_do_not_emit_stale_warnings()
	test_sell_service_backed_runtime_behavior_is_real()
	print("SUMMARY: %d/%d passed" % [_passed, _passed + _failed])
	get_tree().quit(1 if _failed > 0 else 0)

func test_reachable_warning_report_is_explicit_and_reduced() -> void:
	var report: Dictionary = BazaarContentClass.get_reachable_item_effect_coverage_report()
	_assert_true(int(report.get("total_item_ids", 0)) >= 180, "reachable report covers hero/reward/vendor/PvP item surface")
	_assert_true(int(report.get("warning_entry_total", 9999)) < 473, "P1A warning report reduces relevant parent warning count")
	_assert_eq(int(report.get("unknown_item_total", -1)), 0, "reachable report has no create-item gaps")
	_assert_true((report.get("unknown_effect_categories", []) as Array).is_empty(), "reachable report introduces zero unknown effect categories")
	for entry in report.get("warning_items", []):
		for warning in (entry as Dictionary).get("warnings", []):
			var reason: String = str((warning as Dictionary).get("reason", ""))
			_assert_true(not reason.strip_edges().is_empty(), "reachable warning has explicit unsupported reason")

func test_karnok_reachable_items_can_be_created() -> void:
	for item_id in ["adrenaline_shot", "bear_claws", "honey_jar"]:
		var item: ItemDataClass = BazaarContentClass.create_item(item_id, BazaarContentClass.RARITY_BRONZE)
		_assert_not_null(item, "Karnok reachable item %s can be created" % item_id)

func test_sell_service_backed_items_do_not_emit_stale_warnings() -> void:
	for item_id in ["chocolate_bar", "insect_wing", "extract", "scrap", "med_kit"]:
		var item: ItemDataClass = BazaarContentClass.create_item(item_id, BazaarContentClass.RARITY_BRONZE)
		_assert_not_null(item, "creates %s" % item_id)
		if item == null:
			continue
		for warning in item.effect_warnings:
			_assert_true(str(warning).find("unsupported_item_trigger:%s:on_sell" % item_id) < 0, "%s no longer reports stale on_sell trigger warning" % item_id)

func test_sell_service_backed_runtime_behavior_is_real() -> void:
	GameManager.select_hero(BazaarContentClass.create_mak_hero())
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var poison_item: ItemDataClass = BazaarContentClass.create_item("noxious_potion", BazaarContentClass.RARITY_BRONZE)
	var extract: ItemDataClass = BazaarContentClass.create_item("extract", BazaarContentClass.RARITY_BRONZE)
	_assert_true(inv.place_item(poison_item, 0), "places target item")
	_assert_true(inv.place_item(extract, 1), "places sell item")
	var before: float = poison_item.poison_damage
	var result: Dictionary = SellService.sell_item(extract, inv)
	_assert_true(bool(result.get("success", false)), "SellService sells Extract")
	_assert_true(not (result.get("effects_applied", []) as Array).is_empty(), "SellService applies Extract runtime effect")
	_assert_true(poison_item.poison_damage > before, "Extract mutates item poison value through SellService")

func _assert_true(value: bool, message: String) -> void:
	if value:
		_passed += 1
		print("PASS: %s" % message)
	else:
		_failed += 1
		push_error("FAIL: %s" % message)

func _assert_eq(actual, expected, message: String) -> void:
	_assert_true(actual == expected, "%s | expected=%s actual=%s" % [message, str(expected), str(actual)])

func _assert_not_null(value, message: String) -> void:
	_assert_true(value != null, message)
