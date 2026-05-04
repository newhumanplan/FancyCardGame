extends Node

const BazaarContentClass = preload("res://scripts/data/bazaar_content.gd")
const EffectDefinitionClass = preload("res://scripts/data/effect_definition.gd")
const ItemDataClass = preload("res://scripts/data/item_data.gd")

var _passed: int = 0
var _failed: int = 0

func _ready() -> void:
	print("== tests/test_item_effect_catalog_gaps.gd ==")
	test_p1e_catalog_gap_audit_is_reduced_and_explicit()
	test_max_health_text_does_not_emit_heal_warning()
	test_service_unlock_items_are_runtime_service_backed()
	print("SUMMARY: %d/%d passed" % [_passed, _passed + _failed])
	get_tree().quit(1 if _failed > 0 else 0)

func test_p1e_catalog_gap_audit_is_reduced_and_explicit() -> void:
	var report: Dictionary = BazaarContentClass.get_reachable_item_effect_coverage_report()
	var families: Dictionary = report.get("warning_family_counts", {})
	_assert_eq(int(report.get("unknown_item_total", -1)), 0, "P1E keeps reachable create-item gaps closed")
	_assert_true((report.get("unknown_effect_categories", []) as Array).is_empty(), "P1E introduces zero unknown effect categories")
	_assert_true(int(report.get("warning_entry_total", 9999)) < 358, "P1E reduces residual warning entries from P1D baseline")
	_assert_true(int(report.get("warning_item_total", 9999)) < 242, "P1E reduces residual warning item count from P1D baseline")
	_assert_true(int(families.get("unsupported_item_effect:heal", 9999)) < 27, "P1E removes Max Health false positives from Heal warnings")
	_assert_true(int(families.get("unsupported_item_effect:runtime_bonus", 9999)) < 157, "P1E removes service-unlock false positives from runtime_bonus warnings")
	var blank_reason_count: int = 0
	for entry in report.get("warning_items", []):
		for warning in (entry as Dictionary).get("warnings", []):
			var reason: String = str((warning as Dictionary).get("reason", ""))
			if reason.strip_edges().is_empty():
				blank_reason_count += 1
	_assert_eq(blank_reason_count, 0, "residual warnings keep explicit reasons")

func test_max_health_text_does_not_emit_heal_warning() -> void:
	for item_id in ["chocolate_bar", "coconut", "bear_mask", "anchor"]:
		var item: ItemDataClass = BazaarContentClass.create_item(item_id, BazaarContentClass.RARITY_BRONZE)
		_assert_not_null(item, "creates %s" % item_id)
		if item == null:
			continue
		_assert_true(not item.effect_warnings.has("unsupported_item_effect:%s:heal" % item_id), "%s Max Health text does not create Heal warning" % item_id)

func test_service_unlock_items_are_runtime_service_backed() -> void:
	for item_id in ["genie_lamp", "thieves_guild_medallion"]:
		var item: ItemDataClass = BazaarContentClass.create_item(item_id, BazaarContentClass.RARITY_DIAMOND)
		_assert_not_null(item, "creates %s" % item_id)
		if item == null:
			continue
		_assert_true(_has_effect_trigger(item, EffectDefinitionClass.TRIGGER_ON_SELL), "%s records on_sell service unlock trigger" % item_id)
		_assert_true(_has_effect_type(item, EffectDefinitionClass.EFFECT_RUNTIME_BONUS), "%s records runtime/service support marker" % item_id)
		_assert_true(not item.effect_warnings.has("unsupported_item_effect:%s:runtime_bonus" % item_id), "%s no longer reports stale runtime_bonus warning" % item_id)

func _has_effect_trigger(item: ItemDataClass, trigger: String) -> bool:
	for definition in item.effects:
		if definition is Dictionary and str((definition as Dictionary).get("trigger", "")) == trigger:
			return true
	return false

func _has_effect_type(item: ItemDataClass, effect_type: String) -> bool:
	for definition in item.effects:
		if not definition is Dictionary:
			continue
		var effect: Dictionary = (definition as Dictionary).get("effect", {})
		if str(effect.get("type", "")) == effect_type:
			return true
	return false

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
