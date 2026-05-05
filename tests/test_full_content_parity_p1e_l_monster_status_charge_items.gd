extends Node

const BazaarContentClass = preload("res://scripts/data/bazaar_content.gd")
const EffectDefinitionClass = preload("res://scripts/data/effect_definition.gd")
const ItemDataClass = preload("res://scripts/data/item_data.gd")
const LinearInventoryClass = preload("res://scripts/data/linear_inventory.gd")
const MonsterDataClass = preload("res://scripts/data/monster_data.gd")
const SellServiceClass = preload("res://scripts/services/sell_service.gd")

var _total: int = 0
var _passed: int = 0

func _ready() -> void:
	if not Engine.is_editor_hint():
		print("== tests/test_full_content_parity_p1e_l_monster_status_charge_items.gd ==")
		test_p1e_l_item_reasons_are_resolved()
		test_p1e_l_definitions_are_explicit()
		test_status_items_apply_source_backed_runtime()
		test_charge_items_apply_source_backed_targets()
		test_gland_sell_runtime_path_is_backed_by_sell_service()
		test_p1e_l_monster_report_delta_shape()
		_print_summary()

func test_p1e_l_item_reasons_are_resolved() -> void:
	var report: Dictionary = BazaarContentClass.get_all_monster_parity_report()
	var reason_counts: Dictionary = report.get("grouped_missing_mechanics", {}).get("reason_counts", {})
	for reason in [
		"item:gland:unsupported_item_effect:gland:runtime_bonus",
		"item:incense:unsupported_item_effect:incense:runtime_bonus",
		"item:venomous_dose:unsupported_item_effect:venomous_dose:runtime_bonus",
		"item:wand:unsupported_item_effect:wand:charge",
		"item:dock_lines:unsupported_item_effect:dock_lines:slow",
		"item:piggles:unsupported_item_effect:piggles:charge",
	]:
		_assert_true(not reason_counts.has(reason), "P1E-l monster item reason resolved: %s" % reason)

func test_p1e_l_definitions_are_explicit() -> void:
	var expected_ids := {
		"gland": ["gland_runtime_bonus_supported"],
		"incense": ["incense_root_slow", "incense_root_regeneration", "incense_runtime_bonus_supported"],
		"venomous_dose": ["venomous_dose_root_poison", "venomous_dose_root_regeneration", "venomous_dose_root_self_poison", "venomous_dose_runtime_bonus_supported"],
		"wand": ["wand_on_cooldown_ready_charge"],
		"piggles": ["piggles_on_cooldown_ready_charge"],
	}
	for item_id in expected_ids.keys():
		var item: ItemDataClass = _create_item(item_id, BazaarContentClass.RARITY_GOLD)
		var ids: Array[String] = _definition_ids(item)
		for definition_id in expected_ids[item_id]:
			_assert_true(ids.has(str(definition_id)), "%s has %s" % [item_id, str(definition_id)])
		for warning in item.effect_warnings:
			_assert_true(not str(warning).begins_with("unsupported_item_effect:%s:" % item_id), "%s has no stale P1E-l effect warning: %s" % [item_id, str(warning)])
	var dock_lines: ItemDataClass = _create_item("dock_lines", BazaarContentClass.RARITY_GOLD)
	var dock_ids: Array[String] = _definition_ids(dock_lines)
	_assert_true(dock_ids.has("dock_lines_root_slow") or dock_ids.has("dock_lines_on_cooldown_ready_slow"), "dock_lines has explicit Slow definition")
	for warning in dock_lines.effect_warnings:
		_assert_true(not str(warning).begins_with("unsupported_item_effect:dock_lines:"), "dock_lines has no stale P1E-l effect warning: %s" % str(warning))

func test_status_items_apply_source_backed_runtime() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var dock_lines: ItemDataClass = _create_item("dock_lines", BazaarContentClass.RARITY_GOLD)
	var incense: ItemDataClass = _create_item("incense", BazaarContentClass.RARITY_GOLD)
	var venomous_dose: ItemDataClass = _create_item("venomous_dose", BazaarContentClass.RARITY_GOLD)
	_assert_true(inv.place_item(dock_lines, 0), "places Dock Lines")
	_assert_true(inv.place_item(incense, 2), "places Incense")
	_assert_true(inv.place_item(venomous_dose, 4), "places Venomous Dose")
	var monster: MonsterDataClass = _start_battle(inv)

	_battle_system().call("_execute_item_effect_definitions", dock_lines, _root_context())
	_assert_true(_trace_has("dock_lines_on_cooldown_ready_slow"), "Dock Lines Slow trace executes")
	_assert_float_eq(float(monster.monster_items[0].get("current_cooldown", 0.0)), 11.0, "Dock Lines Slows highest cooldown enemy item")
	_assert_float_eq(float(monster.monster_items[1].get("current_cooldown", 0.0)), 9.0, "Dock Lines Slows second highest cooldown enemy item")

	_battle_system().call("_execute_item_effect_definitions", incense, _root_context())
	_assert_true(_trace_has("incense_root_regeneration"), "Incense root Regen trace executes")
	_assert_float_eq(float(_battle_system().call("get_status_totals", "player").get("regeneration", 0.0)), 6.0, "Incense grants Gold Regen for the fight")

	_battle_system().call("_execute_item_effect_definitions", venomous_dose, _root_context())
	_assert_true(_trace_has("venomous_dose_root_poison"), "Venomous Dose enemy Poison trace executes")
	_assert_true(_trace_has("venomous_dose_root_self_poison"), "Venomous Dose self Poison trace executes")
	_assert_true(_trace_has("venomous_dose_root_regeneration"), "Venomous Dose Regen trace executes")
	_assert_float_eq(float(_battle_system().call("get_status_totals", "enemy").get("poison", 0.0)), 6.0, "Venomous Dose poisons enemy at Gold")
	_assert_float_eq(float(_battle_system().call("get_status_totals", "player").get("poison", 0.0)), 6.0, "Venomous Dose poisons self at Gold")
	_assert_float_eq(float(_battle_system().call("get_status_totals", "player").get("regeneration", 0.0)), 12.0, "Venomous Dose adds Gold Regen without losing Incense Regen")
	_battle_system().call("end_battle")

func test_charge_items_apply_source_backed_targets() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var weapon: ItemDataClass = _create_item("fang", BazaarContentClass.RARITY_BRONZE)
	var wand: ItemDataClass = _create_item("wand", BazaarContentClass.RARITY_GOLD)
	var non_weapon: ItemDataClass = _create_item("incense", BazaarContentClass.RARITY_GOLD)
	var left_small: ItemDataClass = _create_item("gland", BazaarContentClass.RARITY_BRONZE)
	var piggles: ItemDataClass = _create_item("piggles", BazaarContentClass.RARITY_GOLD)
	var right_small: ItemDataClass = _create_item("venomous_dose", BazaarContentClass.RARITY_BRONZE)
	var far_small: ItemDataClass = _create_item("gland", BazaarContentClass.RARITY_BRONZE)
	_assert_true(inv.place_item(weapon, 0), "places Weapon non-target")
	_assert_true(inv.place_item(wand, 1), "places Wand")
	_assert_true(inv.place_item(non_weapon, 2), "places non-Weapon Charge target")
	_assert_true(inv.place_item(left_small, 4), "places adjacent Small Charge target")
	_assert_true(inv.place_item(piggles, 5), "places Piggles")
	_assert_true(inv.place_item(right_small, 6), "places second adjacent Small Charge target")
	_assert_true(inv.place_item(far_small, 8), "places non-adjacent Small non-target")
	_start_battle(inv)
	weapon.current_cooldown = 5.0
	non_weapon.current_cooldown = 5.0
	left_small.current_cooldown = 5.0
	right_small.current_cooldown = 5.0
	far_small.current_cooldown = 5.0

	_battle_system().call("_execute_item_effect_definitions", wand, _root_context())
	_battle_system().call("_execute_item_effect_definitions", piggles, _root_context())
	_assert_true(_trace_has("wand_on_cooldown_ready_charge"), "Wand Charge trace executes")
	_assert_true(_trace_has("piggles_on_cooldown_ready_charge"), "Piggles Charge trace executes")
	_assert_float_eq(weapon.current_cooldown, 5.0, "Wand does not Charge Weapon items")
	_assert_float_eq(non_weapon.current_cooldown, 4.0, "Wand Charges other non-Weapon item at Gold")
	_assert_float_eq(left_small.current_cooldown, 1.0, "Piggles adds adjacent Small Charge after Wand's non-Weapon Charge")
	_assert_float_eq(right_small.current_cooldown, 1.0, "Piggles adds adjacent Small Charge to the right target")
	_assert_float_eq(far_small.current_cooldown, 4.0, "Piggles does not add extra Charge to non-adjacent Small item")
	_battle_system().call("end_battle")

func test_gland_sell_runtime_path_is_backed_by_sell_service() -> void:
	RunStateService.reset()
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var gland: ItemDataClass = _create_item("gland", BazaarContentClass.RARITY_GOLD)
	_assert_true(inv.place_item(gland, 0), "places Gland")
	_assert_true(bool(SellServiceClass.sell_item(gland, inv).get("success", false)), "Gland sell succeeds")
	_assert_float_eq(float(RunStateService.get_battle_start_status_bonuses().get("regeneration", 0.0)), 3.0, "Gland sell stores Gold battle-start Regen")

func test_p1e_l_monster_report_delta_shape() -> void:
	var report: Dictionary = BazaarContentClass.get_all_monster_parity_report()
	_assert_true(int(report.get("monster_count", 0)) == 101, "P1E-l all-monster report remains all 101 monsters")
	_assert_true(int(report.get("missing_mechanics_count", 999)) <= 95, "P1E-l does not widen missing monster mechanics from P1E-k baseline")

func _battle_system() -> Node:
	return get_node("/root/BattleSystem")

func _game_manager() -> Node:
	return get_node("/root/GameManager")

func _create_item(item_id: String, rarity: int = BazaarContentClass.RARITY_BRONZE) -> ItemDataClass:
	var item: ItemDataClass = BazaarContentClass.create_item(item_id, rarity)
	_assert_true(item != null, "creates %s" % item_id)
	return item

func _definition_ids(item: ItemDataClass) -> Array[String]:
	var ids: Array[String] = []
	if item == null:
		return ids
	for definition in item.effects:
		ids.append(str((definition as Dictionary).get("id", "")))
	return ids

func _trace_has(definition_id: String) -> bool:
	for entry in _battle_system().call("get_effect_execution_trace"):
		if str(entry.get("definition_id", "")) == definition_id:
			return true
	return false

func _root_context() -> Dictionary:
	return {
		"is_crit": false,
		"crit_multiplier": 1.0,
		"lifesteal_rate": 0.0,
		"burn_bonus": 0.0,
		"poison_bonus": 0.0,
	}

func _start_battle(inv: LinearInventoryClass) -> MonsterDataClass:
	var hero = BazaarContentClass.create_mak_hero()
	var game_manager: Node = _game_manager()
	game_manager.call("reset_stats")
	game_manager.set("selected_hero", hero)
	game_manager.set("player_health", hero.max_hp)
	var monster: MonsterDataClass = MonsterDataClass.new()
	monster.monster_name = "P1E-l Status Charge Item Test"
	monster.max_hp = 500
	monster.current_hp = 500
	monster.monster_items = [
		{"source_id": "enemy_a", "cooldown": 8.0, "current_cooldown": 8.0},
		{"source_id": "enemy_b", "cooldown": 6.0, "current_cooldown": 6.0},
	]
	_battle_system().call("start_battle", monster, inv)
	return monster

func _assert_true(condition: bool, label: String) -> void:
	_total += 1
	if condition:
		_passed += 1
		print("PASS: %s" % label)
	else:
		push_error("FAIL: %s" % label)

func _assert_float_eq(actual: float, expected: float, label: String, tolerance: float = 0.001) -> void:
	_assert_true(absf(actual - expected) <= tolerance, "%s | expected=%.3f actual=%.3f" % [label, expected, actual])

func _print_summary() -> void:
	print("SUMMARY: %d/%d passed" % [_passed, _total])
	get_tree().quit(1 if _passed < _total else 0)
