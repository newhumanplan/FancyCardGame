extends Node

const BazaarContentClass = preload("res://scripts/data/bazaar_content.gd")
const EffectDefinitionClass = preload("res://scripts/data/effect_definition.gd")
const ItemDataClass = preload("res://scripts/data/item_data.gd")
const LinearInventoryClass = preload("res://scripts/data/linear_inventory.gd")
const MonsterDataClass = preload("res://scripts/data/monster_data.gd")

const STATUS_DIR := "/Users/Allenz/Projects/FancyCardGame/.codex-status/T-FCG-FULL-CONTENT-PARITY-001/P1E-g"

var _total: int = 0
var _passed: int = 0

func _ready() -> void:
	if not Engine.is_editor_hint():
		print("== tests/test_full_content_parity_p1e_g_monster_reactive_items.gd ==")
		test_reactive_item_reasons_are_resolved()
		test_reactive_item_definitions_are_explicit()
		test_ectoplasm_heals_from_enemy_poison_total()
		test_shadowed_cloak_hastes_and_buffs_right_weapon()
		test_battle_start_weapon_runtime_bonuses_and_charge_triggers()
		test_p1e_g_monster_report_delta_shape()
		_print_summary()

func test_reactive_item_reasons_are_resolved() -> void:
	var report: Dictionary = BazaarContentClass.get_all_monster_parity_report()
	var reason_counts: Dictionary = report.get("grouped_missing_mechanics", {}).get("reason_counts", {})
	for reason in [
		"item:ectoplasm:unsupported_item_effect:ectoplasm:heal",
		"item:shadowed_cloak:unsupported_item_effect:shadowed_cloak:haste",
		"item:shadowed_cloak:unsupported_item_effect:shadowed_cloak:runtime_bonus",
		"item:broken_shackles:unsupported_item_effect:broken_shackles:charge",
		"item:broken_shackles:unsupported_item_effect:broken_shackles:runtime_bonus",
		"item:handaxe:unsupported_item_effect:handaxe:runtime_bonus",
		"item:weakpoint_detector:unsupported_item_effect:weakpoint_detector:charge",
		"item:weakpoint_detector:unsupported_item_effect:weakpoint_detector:runtime_bonus",
		"item:weakpoint_detector:unsupported_item_effect:weakpoint_detector:slow",
	]:
		_assert_true(not reason_counts.has(reason), "P1E-g monster item reason resolved: %s" % reason)

func test_reactive_item_definitions_are_explicit() -> void:
	var expected_ids := {
		"ectoplasm": ["ectoplasm_on_cooldown_ready_heal"],
		"shadowed_cloak": ["shadowed_cloak_on_item_used_haste", "shadowed_cloak_on_item_used_runtime_bonus"],
		"broken_shackles": ["broken_shackles_on_battle_start_runtime_bonus", "broken_shackles_on_tag_used_charge"],
		"handaxe": ["handaxe_on_battle_start_runtime_bonus"],
		"weakpoint_detector": ["weakpoint_detector_on_battle_start_runtime_bonus", "weakpoint_detector_on_enemy_status_applied_charge"],
	}
	for item_id in expected_ids.keys():
		var item: ItemDataClass = _create_item(item_id)
		var ids: Array[String] = _definition_ids(item)
		for definition_id in expected_ids[item_id]:
			_assert_true(ids.has(str(definition_id)), "%s has %s" % [item_id, str(definition_id)])
		for warning in item.effect_warnings:
			_assert_true(not str(warning).begins_with("unsupported_item_effect:%s:" % item_id), "%s has no stale P1E-g effect warning: %s" % [item_id, str(warning)])

func test_ectoplasm_heals_from_enemy_poison_total() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var ectoplasm: ItemDataClass = _create_item("ectoplasm")
	_assert_true(inv.place_item(ectoplasm, 0), "places Ectoplasm")
	var monster: MonsterDataClass = _start_battle(inv)
	var hero = _game_manager().get("selected_hero")
	_game_manager().set("player_health", hero.max_hp - 10)
	ectoplasm.current_cooldown = 0.0

	_battle_system().call("execute_battle_tick", 0.0)
	_assert_true(_trace_has("ectoplasm_on_cooldown_ready_heal"), "Ectoplasm heal trace executes")
	var expected_poison: float = float(_battle_system().call("get_status_totals", "enemy").get("poison", 0.0))
	_assert_true(expected_poison >= ectoplasm.poison_damage, "Ectoplasm applies source poison before heal")
	_assert_eq(_game_manager().get("player_health"), hero.max_hp - 10 + int(expected_poison), "Ectoplasm heals equal to opponent poison")
	_battle_system().call("end_battle")

func test_shadowed_cloak_hastes_and_buffs_right_weapon() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var cloak: ItemDataClass = _create_item("shadowed_cloak")
	var fang: ItemDataClass = _create_item("fang")
	_assert_true(inv.place_item(cloak, 0), "places Shadowed Cloak")
	_assert_true(inv.place_item(fang, 2), "places right Weapon")
	_start_battle(inv)
	fang.current_cooldown = 5.0

	_process_events([{"name": EffectDefinitionClass.TRIGGER_ON_ITEM_USED, "source_item": fang, "source_id": fang.source_id, "depth": 0}])
	_assert_true(_trace_has("shadowed_cloak_on_item_used_haste"), "Shadowed Cloak haste trace executes")
	_assert_true(_trace_has("shadowed_cloak_on_item_used_runtime_bonus"), "Shadowed Cloak damage trace executes")
	_assert_float_eq(fang.current_cooldown, 4.0, "Shadowed Cloak hastes the item to its right")
	_assert_float_eq(_item_runtime_bonus(fang, EffectDefinitionClass.EFFECT_DAMAGE), 3.0, "Shadowed Cloak grants right Weapon combat damage")
	_battle_system().call("end_battle")

func test_battle_start_weapon_runtime_bonuses_and_charge_triggers() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var broken_shackles: ItemDataClass = _create_item("broken_shackles")
	var handaxe: ItemDataClass = _create_item("handaxe")
	var weakpoint_detector: ItemDataClass = _create_item("weakpoint_detector")
	var fang: ItemDataClass = _create_item("fang")
	_assert_true(inv.place_item(broken_shackles, 0), "places Broken Shackles")
	_assert_true(inv.place_item(handaxe, 1), "places Handaxe")
	_assert_true(inv.place_item(weakpoint_detector, 3), "places Weakpoint Detector")
	_assert_true(inv.place_item(fang, 5), "places target Weapon")
	_start_battle(inv)
	_assert_true(_trace_has("broken_shackles_on_battle_start_runtime_bonus"), "Broken Shackles battle-start weapon bonus executes")
	_assert_true(_trace_has("handaxe_on_battle_start_runtime_bonus"), "Handaxe battle-start weapon bonus executes")
	_assert_true(_trace_has("weakpoint_detector_on_battle_start_runtime_bonus"), "Weakpoint Detector battle-start weapon bonus executes")
	_assert_float_eq(_item_runtime_bonus(fang, EffectDefinitionClass.EFFECT_DAMAGE), 15.0, "battle-start source-backed weapon bonuses stack")

	broken_shackles.current_cooldown = 7.0
	weakpoint_detector.current_cooldown = 6.0
	_process_events([{"name": EffectDefinitionClass.TRIGGER_ON_TAG_USED, "source_item": fang, "source_id": fang.source_id, "depth": 0}])
	_assert_true(_trace_has("broken_shackles_on_tag_used_charge"), "Broken Shackles charges itself after Weapon use")
	_assert_float_eq(broken_shackles.current_cooldown, 5.0, "Broken Shackles charge amount is applied")
	_process_events([{"name": EffectDefinitionClass.TRIGGER_ON_ENEMY_STATUS_APPLIED, "source_item": weakpoint_detector, "source_id": weakpoint_detector.source_id, "status_type": EffectDefinitionClass.EFFECT_SLOW, "depth": 0}])
	_assert_true(_trace_has("weakpoint_detector_on_enemy_status_applied_charge"), "Weakpoint Detector charges itself after Slow")
	_assert_float_eq(weakpoint_detector.current_cooldown, 4.0, "Weakpoint Detector charge amount is applied")
	_battle_system().call("end_battle")

func test_p1e_g_monster_report_delta_shape() -> void:
	_assert_true(DirAccess.dir_exists_absolute(STATUS_DIR), "P1E-g status artifact directory is available")
	var report: Dictionary = BazaarContentClass.get_all_monster_parity_report()
	_assert_true(int(report.get("monster_count", 0)) == 101, "P1E-g all-monster report remains all 101 monsters")
	_assert_true(int(report.get("missing_mechanics_count", 999)) < 96, "P1E-g report reduces missing monster mechanics from P1E-f baseline")

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

func _process_events(events: Array[Dictionary]) -> void:
	_battle_system().call("_process_reactive_effect_events", events)

func _start_battle(inv: LinearInventoryClass) -> MonsterDataClass:
	var hero = BazaarContentClass.create_mak_hero()
	var game_manager: Node = _game_manager()
	game_manager.call("reset_stats")
	game_manager.set("selected_hero", hero)
	game_manager.set("player_health", hero.max_hp)
	var monster: MonsterDataClass = MonsterDataClass.new()
	monster.monster_name = "P1E-g Reactive Test"
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

func _assert_eq(actual, expected, label: String) -> void:
	_assert_true(actual == expected, "%s | expected=%s actual=%s" % [label, str(expected), str(actual)])

func _assert_float_eq(actual: float, expected: float, label: String, tolerance: float = 0.001) -> void:
	_assert_true(absf(actual - expected) <= tolerance, "%s | expected=%.3f actual=%.3f" % [label, expected, actual])

func _print_summary() -> void:
	print("SUMMARY: %d/%d passed" % [_passed, _total])
	get_tree().quit(1 if _passed < _total else 0)
