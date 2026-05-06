extends Node

const BazaarContentClass = preload("res://scripts/data/bazaar_content.gd")
const EffectDefinitionClass = preload("res://scripts/data/effect_definition.gd")
const ItemDataClass = preload("res://scripts/data/item_data.gd")
const LinearInventoryClass = preload("res://scripts/data/linear_inventory.gd")
const MonsterDataClass = preload("res://scripts/data/monster_data.gd")

var _total: int = 0
var _passed: int = 0

func _ready() -> void:
	if not Engine.is_editor_hint():
		print("== tests/test_full_content_parity_p1e_p_monster_hazard_runtime_items.gd ==")
		test_p1e_p_item_reasons_are_resolved()
		test_p1e_p_definitions_are_explicit()
		test_plasma_grenade_burns_both_players_and_slows_all_enemy_items()
		test_curry_charges_another_small_item()
		test_hot_sauce_counts_adjacent_food_multicast()
		test_p1e_p_monster_report_delta_shape()
		_print_summary()

func test_p1e_p_item_reasons_are_resolved() -> void:
	var report: Dictionary = BazaarContentClass.get_all_monster_parity_report()
	var reason_counts: Dictionary = report.get("grouped_missing_mechanics", {}).get("reason_counts", {})
	for reason in [
		"item:plasma_grenade:unsupported_item_effect:plasma_grenade:burn",
		"item:plasma_grenade:unsupported_item_effect:plasma_grenade:slow",
		"item:curry:unsupported_item_effect:curry:charge",
		"item:hot_sauce:unsupported_item_effect:hot_sauce:multicast",
		"item:hot_sauce:unsupported_item_effect:hot_sauce:runtime_bonus",
	]:
		_assert_true(not reason_counts.has(reason), "P1E-p monster item reason resolved: %s" % reason)

func test_p1e_p_definitions_are_explicit() -> void:
	var expected_ids := {
		"plasma_grenade": [
			"plasma_grenade_on_cooldown_ready_enemy_burn",
			"plasma_grenade_on_cooldown_ready_self_burn",
			"plasma_grenade_on_cooldown_ready_slow",
		],
		"curry": [
			"curry_root_burn",
			"curry_on_cooldown_ready_charge",
		],
		"hot_sauce": [
			"hot_sauce_root_burn",
			"hot_sauce_on_cooldown_ready_multicast",
			"hot_sauce_runtime_bonus_supported",
		],
	}
	for item_id in expected_ids.keys():
		var item: ItemDataClass = _create_item(item_id, BazaarContentClass.RARITY_GOLD)
		var ids: Array[String] = _definition_ids(item)
		for definition_id in expected_ids[item_id]:
			_assert_true(ids.has(str(definition_id)), "%s has %s" % [item_id, str(definition_id)])
		for warning in item.effect_warnings:
			_assert_true(not str(warning).begins_with("unsupported_item_effect:%s:" % item_id), "%s has no stale P1E-p effect warning: %s" % [item_id, str(warning)])

func test_plasma_grenade_burns_both_players_and_slows_all_enemy_items() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var plasma: ItemDataClass = _create_item("plasma_grenade", BazaarContentClass.RARITY_GOLD)
	_assert_true(inv.place_item(plasma, 0), "places Plasma Grenade")
	var monster: MonsterDataClass = _start_battle(inv)

	var result: Dictionary = _battle_system().call("_execute_item_effect_definitions", plasma, _root_context())
	_assert_true(bool(result.get("executed", false)), "Plasma Grenade root Burn/Slow effects execute")
	_assert_true(_trace_has("plasma_grenade_on_cooldown_ready_enemy_burn"), "Plasma Grenade enemy Burn trace executes")
	_assert_true(_trace_has("plasma_grenade_on_cooldown_ready_self_burn"), "Plasma Grenade self Burn trace executes")
	_assert_true(_trace_has("plasma_grenade_on_cooldown_ready_slow"), "Plasma Grenade Slow trace executes")
	_assert_float_eq(_enemy_status(EffectDefinitionClass.EFFECT_BURN), 15.0, "Gold Plasma Grenade Burns the enemy")
	_assert_float_eq(_player_status(EffectDefinitionClass.EFFECT_BURN), 15.0, "Gold Plasma Grenade Burns self")
	_assert_float_eq(float(monster.monster_items[0].get("current_cooldown", 0.0)), 6.0, "Plasma Grenade Slows first enemy item")
	_assert_float_eq(float(monster.monster_items[1].get("current_cooldown", 0.0)), 4.0, "Plasma Grenade Slows second enemy item")
	_assert_float_eq(float(monster.monster_items[2].get("current_cooldown", 0.0)), 2.0, "Plasma Grenade Slows third enemy item")
	_battle_system().call("end_battle")

func test_curry_charges_another_small_item() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var curry: ItemDataClass = _create_item("curry", BazaarContentClass.RARITY_GOLD)
	var small_target: ItemDataClass = _create_item("lighter", BazaarContentClass.RARITY_BRONZE)
	var large_non_target: ItemDataClass = _create_item("gatling_gun", BazaarContentClass.RARITY_BRONZE)
	_assert_true(inv.place_item(curry, 0), "places Curry")
	_assert_true(inv.place_item(small_target, 1), "places another Small target")
	_assert_true(inv.place_item(large_non_target, 3), "places non-Small non-target")
	_start_battle(inv)
	curry.current_cooldown = 9.0
	small_target.current_cooldown = 5.0
	large_non_target.current_cooldown = 8.0

	var result: Dictionary = _battle_system().call("_execute_item_effect_definitions", curry, _root_context())
	_assert_true(bool(result.get("executed", false)), "Curry root Burn/Charge effects execute")
	_assert_true(_trace_has("curry_root_burn"), "Curry Burn trace executes")
	_assert_true(_trace_has("curry_on_cooldown_ready_charge"), "Curry Charge trace executes")
	_assert_float_eq(small_target.current_cooldown, 1.0, "Gold Curry Charges another Small item by 4 seconds")
	_assert_float_eq(curry.current_cooldown, 9.0, "Curry does not Charge itself")
	_assert_float_eq(large_non_target.current_cooldown, 8.0, "Curry does not Charge a non-Small item")
	_battle_system().call("end_battle")

func test_hot_sauce_counts_adjacent_food_multicast() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var left_food: ItemDataClass = _create_item("curry", BazaarContentClass.RARITY_GOLD)
	var hot_sauce: ItemDataClass = _create_item("hot_sauce", BazaarContentClass.RARITY_GOLD)
	var right_food: ItemDataClass = _create_item("black_pepper", BazaarContentClass.RARITY_GOLD)
	var far_food: ItemDataClass = _create_item("ice_cubes", BazaarContentClass.RARITY_GOLD)
	_assert_true(inv.place_item(left_food, 0), "places left adjacent Food")
	_assert_true(inv.place_item(hot_sauce, 1), "places Hot Sauce")
	_assert_true(inv.place_item(right_food, 2), "places right adjacent Food")
	_assert_true(inv.place_item(far_food, 4), "places non-adjacent Food")
	_start_battle(inv)

	_assert_eq(_multicast_count(hot_sauce), 3, "Hot Sauce gets +1 Multicast for each adjacent Food")
	_assert_true(_trace_has("hot_sauce_on_cooldown_ready_multicast"), "Hot Sauce multicast trace executes")
	_battle_system().call("end_battle")

func test_p1e_p_monster_report_delta_shape() -> void:
	var report: Dictionary = BazaarContentClass.get_all_monster_parity_report()
	_assert_true(int(report.get("monster_count", 0)) == 101, "P1E-p all-monster report remains all 101 monsters")
	_assert_true(int(report.get("missing_mechanics_count", 999)) <= 94, "P1E-p does not widen missing monster mechanics from P1E-o baseline")

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

func _multicast_count(item: ItemDataClass) -> int:
	return int(_battle_system().call("_get_player_item_multicast_count", item))

func _enemy_status(status_type: String) -> float:
	return float(_battle_system().call("get_status_totals", "enemy").get(status_type, 0.0))

func _player_status(status_type: String) -> float:
	return float(_battle_system().call("get_status_totals", "player").get(status_type, 0.0))

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
	monster.monster_name = "P1E-p Hazard Runtime Item Test"
	monster.max_hp = 500
	monster.current_hp = 500
	monster.monster_items = [
		{"source_id": "enemy_a", "cooldown": 5.0, "current_cooldown": 5.0},
		{"source_id": "enemy_b", "cooldown": 3.0, "current_cooldown": 3.0},
		{"source_id": "enemy_c", "cooldown": 1.0, "current_cooldown": 1.0},
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

func _assert_eq(actual, expected, label: String) -> void:
	_assert_true(actual == expected, "%s | expected=%s actual=%s" % [label, str(expected), str(actual)])

func _assert_float_eq(actual: float, expected: float, label: String, tolerance: float = 0.001) -> void:
	_assert_true(absf(actual - expected) <= tolerance, "%s | expected=%.3f actual=%.3f" % [label, expected, actual])

func _print_summary() -> void:
	print("SUMMARY: %d/%d passed" % [_passed, _total])
	get_tree().quit(1 if _passed < _total else 0)
