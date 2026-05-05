extends Node

const BazaarContentClass = preload("res://scripts/data/bazaar_content.gd")
const LinearInventoryClass = preload("res://scripts/data/linear_inventory.gd")
const SellServiceClass = preload("res://scripts/services/sell_service.gd")

const STATUS_DIR := "/Users/Allenz/Projects/FancyCardGame/.codex-status/T-FCG-FULL-CONTENT-PARITY-001/P1E-f"

var _total: int = 0
var _passed: int = 0

func _ready() -> void:
	if not Engine.is_editor_hint():
		print("== tests/test_full_content_parity_p1e_f_monster_sell_mutation_items.gd ==")
		test_sell_mutation_item_reasons_are_resolved()
		test_sell_mutation_runtime_paths_are_explicit()
		test_sell_mutation_service_paths_change_targets()
		test_p1e_f_monster_report_delta_shape()
		_print_summary()

func test_sell_mutation_item_reasons_are_resolved() -> void:
	var report: Dictionary = BazaarContentClass.get_all_monster_parity_report()
	var reason_counts: Dictionary = report.get("grouped_missing_mechanics", {}).get("reason_counts", {})
	for reason in [
		"item:cinders:unsupported_item_effect:cinders:runtime_bonus",
		"item:extract:unsupported_item_effect:extract:runtime_bonus",
		"item:med_kit:unsupported_item_effect:med_kit:runtime_bonus",
		"item:sharpening_stone:unsupported_item_effect:sharpening_stone:runtime_bonus",
	]:
		_assert_true(not reason_counts.has(reason), "sell-mutation monster item reason resolved: %s" % reason)

	for monster_id in ["pyro", "viper", "boarrior", "rogue_scrapper"]:
		var entry: Dictionary = _find_report_entry(report, monster_id)
		_assert_true((entry.get("supported_mechanics", []) as Array).has("effect_dsl"), "%s keeps item effect DSL support" % monster_id)

func test_sell_mutation_runtime_paths_are_explicit() -> void:
	for item_id in ["cinders", "extract", "med_kit", "sharpening_stone"]:
		var item = BazaarContentClass.create_item(item_id, BazaarContentClass.RARITY_BRONZE)
		_assert_true(item != null, "%s item can be created" % item_id)
		if item == null:
			continue
		_assert_true(_definition_ids(item).has("%s_runtime_bonus_supported" % item_id), "%s records SellService runtime bonus path" % item_id)
		_assert_true(not item.effect_warnings.has("unsupported_item_effect:%s:runtime_bonus" % item_id), "%s no longer reports stale runtime_bonus warning" % item_id)

func test_sell_mutation_service_paths_change_targets() -> void:
	_assert_sell_changes_target("cinders", "fire_potion", "burn_damage", "Cinders grants Burn to leftmost Burn item")
	_assert_sell_changes_target("extract", "venom", "poison_damage", "Extract grants Poison to leftmost Poison item")
	_assert_sell_changes_target("med_kit", "bluenanas", "heal", "Med Kit grants Heal to leftmost Heal item")
	_assert_sell_changes_target("sharpening_stone", "old_sword", "damage", "Sharpening Stone grants Damage to leftmost Weapon")

func test_p1e_f_monster_report_delta_shape() -> void:
	_assert_true(DirAccess.dir_exists_absolute(STATUS_DIR), "P1E-f status artifact directory is available")
	var report: Dictionary = BazaarContentClass.get_all_monster_parity_report()
	_assert_true(int(report.get("monster_count", 0)) == 101, "P1E-f all-monster report remains all 101 monsters")
	_assert_true(int(report.get("missing_mechanics_count", 999)) < 98, "P1E-f report reduces missing monster mechanics from P1E-e baseline")

func _assert_sell_changes_target(sell_item_id: String, target_item_id: String, key: String, label: String) -> void:
	var inventory: LinearInventoryClass = LinearInventoryClass.new()
	var sell_item = BazaarContentClass.create_item(sell_item_id, BazaarContentClass.RARITY_BRONZE)
	var target_item = BazaarContentClass.create_item(target_item_id, BazaarContentClass.RARITY_BRONZE)
	_assert_true(sell_item != null, "%s sell item exists" % sell_item_id)
	_assert_true(target_item != null, "%s target item exists" % target_item_id)
	if sell_item == null or target_item == null:
		return
	_assert_true(inventory.place_item(sell_item, 0), "places %s sell item" % sell_item_id)
	_assert_true(inventory.place_item(target_item, 1), "places %s target item" % target_item_id)
	var before: float = float(target_item.get(key))
	var result: Dictionary = SellServiceClass.sell_item(sell_item, inventory)
	_assert_true(bool(result.get("success", false)), "%s sell succeeds" % sell_item_id)
	_assert_true(float(target_item.get(key)) > before, label)

func _definition_ids(item) -> Array[String]:
	var ids: Array[String] = []
	for definition in item.effects:
		if definition is Dictionary:
			ids.append(str((definition as Dictionary).get("id", "")))
	return ids

func _find_report_entry(report: Dictionary, monster_id: String) -> Dictionary:
	for entry in report.get("monsters", []):
		if entry is Dictionary and str((entry as Dictionary).get("id", "")) == monster_id:
			return entry as Dictionary
	return {}

func _assert_true(condition: bool, label: String) -> void:
	_total += 1
	if condition:
		_passed += 1
		print("PASS: %s" % label)
	else:
		push_error("FAIL: %s" % label)

func _print_summary() -> void:
	print("SUMMARY: %d/%d passed" % [_passed, _total])
	get_tree().quit(1 if _passed < _total else 0)
