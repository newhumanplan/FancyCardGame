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
		print("== tests/test_full_content_parity_p1e_q_monster_runtime_utility_items.gd ==")
		test_p1e_q_item_reasons_are_resolved()
		test_p1e_q_definitions_are_explicit()
		test_poppy_field_grants_poison_scaled_weapon_damage()
		test_sapphire_extends_other_freeze_item_duration()
		test_p1e_q_monster_report_delta_shape()
		_print_summary()

func test_p1e_q_item_reasons_are_resolved() -> void:
	var report: Dictionary = BazaarContentClass.get_all_monster_parity_report()
	var reason_counts: Dictionary = report.get("grouped_missing_mechanics", {}).get("reason_counts", {})
	for reason in [
		"item:poppy_field:unsupported_item_effect:poppy_field:runtime_bonus",
		"item:sapphire:unsupported_item_effect:sapphire:runtime_bonus",
	]:
		_assert_true(not reason_counts.has(reason), "P1E-q monster item reason resolved: %s" % reason)

func test_p1e_q_definitions_are_explicit() -> void:
	var expected_ids := {
		"poppy_field": [
			"poppy_field_root_poison",
			"poppy_field_runtime_bonus_supported",
		],
		"sapphire": [
			"sapphire_root_freeze",
			"sapphire_on_battle_start_runtime_bonus",
		],
	}
	for item_id in expected_ids.keys():
		var item: ItemDataClass = _create_item(item_id, BazaarContentClass.RARITY_GOLD)
		var ids: Array[String] = _definition_ids(item)
		for definition_id in expected_ids[item_id]:
			_assert_true(ids.has(str(definition_id)), "%s has %s" % [item_id, str(definition_id)])
		for warning in item.effect_warnings:
			_assert_true(not str(warning).begins_with("unsupported_item_effect:%s:" % item_id), "%s has no stale P1E-q effect warning: %s" % [item_id, str(warning)])

func test_poppy_field_grants_poison_scaled_weapon_damage() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var poppy: ItemDataClass = _create_item("poppy_field", BazaarContentClass.RARITY_GOLD)
	var weapon: ItemDataClass = _create_item("fang", BazaarContentClass.RARITY_BRONZE)
	var non_weapon: ItemDataClass = _create_item("succulents", BazaarContentClass.RARITY_GOLD)
	_assert_true(inv.place_item(poppy, 0), "places Poppy Field")
	_assert_true(inv.place_item(weapon, 3), "places Weapon target")
	_assert_true(inv.place_item(non_weapon, 4), "places non-Weapon control")
	_start_battle(inv)
	_battle_system().call("_apply_status_effect", {
		"type": EffectDefinitionClass.EFFECT_POISON,
		"value": 12.0,
		"duration": 0.0,
		"item_name": "test poison",
		"target": "enemy",
	})

	_assert_float_eq(_item_runtime_bonus(weapon, EffectDefinitionClass.EFFECT_DAMAGE), 9.0, "Gold Poppy Field gives Weapons +75% of enemy Poison as Damage")
	_assert_float_eq(_item_runtime_bonus(non_weapon, EffectDefinitionClass.EFFECT_DAMAGE), 0.0, "Poppy Field does not buff non-Weapons")
	_battle_system().call("end_battle")

func test_sapphire_extends_other_freeze_item_duration() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var sapphire: ItemDataClass = _create_item("sapphire", BazaarContentClass.RARITY_GOLD)
	var freeze_target: ItemDataClass = _create_item("frost_potion", BazaarContentClass.RARITY_GOLD)
	var second_freeze_target: ItemDataClass = _create_item("black_ice", BazaarContentClass.RARITY_GOLD)
	_assert_true(inv.place_item(sapphire, 0), "places Sapphire")
	_assert_true(inv.place_item(freeze_target, 1), "places other Freeze target")
	_assert_true(inv.place_item(second_freeze_target, 2), "places second Freeze target")
	var monster: MonsterDataClass = _start_battle(inv)

	_assert_true(_trace_has("sapphire_on_battle_start_runtime_bonus"), "Sapphire battle-start Freeze duration trace executes")
	_assert_float_eq(_item_runtime_bonus(freeze_target, "freeze_duration"), 0.5, "Sapphire gives another Freeze item +0.5 Freeze duration")
	_assert_float_eq(_item_runtime_bonus(sapphire, "freeze_duration"), 0.0, "Sapphire does not buff itself")
	var result: Dictionary = _battle_system().call("_execute_item_effect_definitions", freeze_target, _root_context())
	_assert_true(bool(result.get("executed", false)), "buffed Freeze item executes")
	_assert_float_eq(float(monster.monster_items[0].get("current_cooldown", 0.0)), 6.5, "Sapphire increases another Freeze item's applied duration")
	_battle_system().call("end_battle")

func test_p1e_q_monster_report_delta_shape() -> void:
	var report: Dictionary = BazaarContentClass.get_all_monster_parity_report()
	_assert_true(int(report.get("monster_count", 0)) == 101, "P1E-q all-monster report remains all 101 monsters")
	_assert_true(int(report.get("missing_mechanics_count", 999)) <= 94, "P1E-q does not widen missing monster mechanics from P1E-p baseline")

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

func _item_runtime_bonus(item: ItemDataClass, key: String) -> float:
	return float(_battle_system().call("_get_item_runtime_bonus", item, key))

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
	monster.monster_name = "P1E-q Runtime Utility Item Test"
	monster.max_hp = 500
	monster.current_hp = 500
	monster.monster_items = [
		{"source_id": "enemy_a", "cooldown": 5.0, "current_cooldown": 5.0},
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
