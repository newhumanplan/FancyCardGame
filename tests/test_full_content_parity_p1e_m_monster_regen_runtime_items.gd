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
		print("== tests/test_full_content_parity_p1e_m_monster_regen_runtime_items.gd ==")
		test_p1e_m_item_reasons_are_resolved()
		test_p1e_m_definitions_are_explicit()
		test_regen_runtime_items_apply_source_backed_effects()
		test_p1e_m_monster_report_delta_shape()
		_print_summary()

func test_p1e_m_item_reasons_are_resolved() -> void:
	var report: Dictionary = BazaarContentClass.get_all_monster_parity_report()
	var reason_counts: Dictionary = report.get("grouped_missing_mechanics", {}).get("reason_counts", {})
	for reason in [
		"item:ouroboros_statue:unsupported_item_effect:ouroboros_statue:regeneration",
		"item:ouroboros_statue:unsupported_item_effect:ouroboros_statue:runtime_bonus",
		"item:soul_ring:unsupported_item_effect:soul_ring:regeneration",
		"item:soul_ring:unsupported_item_effect:soul_ring:runtime_bonus",
		"item:venomander:unsupported_item_effect:venomander:runtime_bonus",
	]:
		_assert_true(not reason_counts.has(reason), "P1E-m monster item reason resolved: %s" % reason)

func test_p1e_m_definitions_are_explicit() -> void:
	var expected_ids := {
		"ouroboros_statue": ["ouroboros_statue_root_poison", "ouroboros_statue_on_enemy_status_applied_regeneration"],
		"soul_ring": ["soul_ring_on_battle_start_regeneration", "soul_ring_on_cooldown_ready_poison"],
		"venomander": ["venomander_root_poison", "venomander_root_regeneration", "venomander_runtime_bonus_supported"],
	}
	for item_id in expected_ids.keys():
		var item: ItemDataClass = _create_item(item_id, BazaarContentClass.RARITY_GOLD)
		var ids: Array[String] = _definition_ids(item)
		for definition_id in expected_ids[item_id]:
			_assert_true(ids.has(str(definition_id)), "%s has %s" % [item_id, str(definition_id)])
		for warning in item.effect_warnings:
			_assert_true(not str(warning).begins_with("unsupported_item_effect:%s:" % item_id), "%s has no stale P1E-m effect warning: %s" % [item_id, str(warning)])

func test_regen_runtime_items_apply_source_backed_effects() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var soul_ring: ItemDataClass = _create_item("soul_ring", BazaarContentClass.RARITY_GOLD)
	var ouroboros: ItemDataClass = _create_item("ouroboros_statue", BazaarContentClass.RARITY_GOLD)
	var venomander: ItemDataClass = _create_item("venomander", BazaarContentClass.RARITY_GOLD)
	_assert_true(inv.place_item(soul_ring, 0), "places Soul Ring")
	_assert_true(inv.place_item(ouroboros, 2), "places Ouroboros Statue")
	_assert_true(inv.place_item(venomander, 4), "places Venomander")
	_start_battle(inv)

	_assert_true(_trace_has("soul_ring_on_battle_start_regeneration"), "Soul Ring battle-start Regen trace executes")
	_assert_float_eq(float(_battle_system().call("get_status_totals", "player").get("regeneration", 0.0)), 10.0, "Soul Ring grants Gold fight Regen at battle start")

	var soul_result: Dictionary = _battle_system().call("_execute_item_effect_definitions", soul_ring, _root_context())
	_assert_true(_trace_has("soul_ring_on_cooldown_ready_poison"), "Soul Ring Regen-scaled Poison trace executes")
	_assert_float_eq(float(_battle_system().call("get_status_totals", "enemy").get("poison", 0.0)), 10.0, "Soul Ring poisons equal to current Regen")
	_process_events(soul_result.get("events", []))

	var ouroboros_result: Dictionary = _battle_system().call("_execute_item_effect_definitions", ouroboros, _root_context())
	_process_events(ouroboros_result.get("events", []))
	_assert_true(_trace_has("ouroboros_statue_root_poison"), "Ouroboros Statue root Poison trace executes")
	_assert_true(_trace_has("ouroboros_statue_on_enemy_status_applied_regeneration"), "Ouroboros Statue poison-triggered Regen trace executes")
	_assert_float_eq(float(_battle_system().call("get_status_totals", "enemy").get("poison", 0.0)), 16.0, "Ouroboros Statue adds Gold Poison")
	_assert_float_eq(float(_battle_system().call("get_status_totals", "player").get("regeneration", 0.0)), 22.0, "Ouroboros Statue gains Gold Regen from both Poison events")

	_battle_system().call("_execute_item_effect_definitions", venomander, _root_context())
	_assert_true(_trace_has("venomander_root_poison"), "Venomander root Poison trace executes")
	_assert_true(_trace_has("venomander_root_regeneration"), "Venomander root Regen trace executes")
	_assert_float_eq(float(_battle_system().call("get_status_totals", "enemy").get("poison", 0.0)), 19.0, "Venomander adds Gold Poison")
	_assert_float_eq(float(_battle_system().call("get_status_totals", "player").get("regeneration", 0.0)), 25.0, "Venomander adds Gold Regen after Ouroboros Poison triggers")
	_battle_system().call("end_battle")

func test_p1e_m_monster_report_delta_shape() -> void:
	var report: Dictionary = BazaarContentClass.get_all_monster_parity_report()
	_assert_true(int(report.get("monster_count", 0)) == 101, "P1E-m all-monster report remains all 101 monsters")
	_assert_true(int(report.get("missing_mechanics_count", 999)) <= 94, "P1E-m does not widen missing monster mechanics from P1E-l baseline")

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

func _process_events(events: Array) -> void:
	var typed_events: Array[Dictionary] = []
	for event in events:
		if event is Dictionary:
			typed_events.append(event)
	_battle_system().call("_process_reactive_effect_events", typed_events)

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
	monster.monster_name = "P1E-m Regen Runtime Item Test"
	monster.max_hp = 500
	monster.current_hp = 500
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
