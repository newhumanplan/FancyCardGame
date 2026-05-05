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
		print("== tests/test_full_content_parity_p1e_n_monster_status_runtime_items.gd ==")
		test_p1e_n_item_reasons_are_resolved()
		test_p1e_n_definitions_are_explicit()
		test_status_runtime_items_apply_in_battle()
		test_thurible_root_burn_and_regen_are_explicit()
		test_p1e_n_monster_report_delta_shape()
		_print_summary()

func test_p1e_n_item_reasons_are_resolved() -> void:
	var report: Dictionary = BazaarContentClass.get_all_monster_parity_report()
	var reason_counts: Dictionary = report.get("grouped_missing_mechanics", {}).get("reason_counts", {})
	for reason in [
		"item:barbed_wire:unsupported_item_effect:barbed_wire:runtime_bonus",
		"item:black_rose:unsupported_item_effect:black_rose:runtime_bonus",
		"item:frozen_bludgeon:unsupported_item_effect:frozen_bludgeon:runtime_bonus",
		"item:thurible:unsupported_item_effect:thurible:runtime_bonus",
		"item:void_ray:unsupported_item_effect:void_ray:multicast",
		"item:void_ray:unsupported_item_effect:void_ray:runtime_bonus",
	]:
		_assert_true(not reason_counts.has(reason), "P1E-n monster item reason resolved: %s" % reason)

func test_p1e_n_definitions_are_explicit() -> void:
	var expected_ids := {
		"barbed_wire": ["barbed_wire_on_shield_gained_runtime_bonus"],
		"black_rose": ["black_rose_root_regeneration", "black_rose_on_enemy_status_applied_runtime_bonus"],
		"frozen_bludgeon": ["frozen_bludgeon_root_freeze", "frozen_bludgeon_on_enemy_status_applied_runtime_bonus"],
		"thurible": ["thurible_root_burn", "thurible_root_regeneration", "thurible_runtime_bonus_supported"],
		"void_ray": ["void_ray_root_burn", "void_ray_on_cooldown_ready_multicast", "void_ray_on_shield_gained_runtime_bonus"],
	}
	for item_id in expected_ids.keys():
		var item: ItemDataClass = _create_item(item_id, BazaarContentClass.RARITY_GOLD)
		var ids: Array[String] = _definition_ids(item)
		for definition_id in expected_ids[item_id]:
			_assert_true(ids.has(str(definition_id)), "%s has %s" % [item_id, str(definition_id)])
		for warning in item.effect_warnings:
			_assert_true(not str(warning).begins_with("unsupported_item_effect:%s:" % item_id), "%s has no stale P1E-n effect warning: %s" % [item_id, str(warning)])

func test_status_runtime_items_apply_in_battle() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var barbed_wire: ItemDataClass = _create_item("barbed_wire", BazaarContentClass.RARITY_GOLD)
	var black_rose: ItemDataClass = _create_item("black_rose", BazaarContentClass.RARITY_GOLD)
	var frozen_bludgeon: ItemDataClass = _create_item("frozen_bludgeon", BazaarContentClass.RARITY_GOLD)
	var void_ray: ItemDataClass = _create_item("void_ray", BazaarContentClass.RARITY_DIAMOND)
	_assert_true(inv.place_item(barbed_wire, 0), "places Barbed Wire")
	_assert_true(inv.place_item(black_rose, 1), "places Black Rose")
	_assert_true(inv.place_item(frozen_bludgeon, 2), "places Frozen Bludgeon")
	_assert_true(inv.place_item(void_ray, 4), "places Void Ray")
	_start_battle(inv)

	_process_events([{"name": EffectDefinitionClass.TRIGGER_ON_SHIELD_GAINED, "source_item": barbed_wire, "source_id": barbed_wire.source_id, "depth": 0}])
	_assert_true(_trace_has("barbed_wire_on_shield_gained_runtime_bonus"), "Barbed Wire shield-triggered Damage trace executes")
	_assert_true(_trace_has("void_ray_on_shield_gained_runtime_bonus"), "Void Ray shield-triggered Burn trace executes")
	_assert_float_eq(_item_runtime_bonus(barbed_wire, EffectDefinitionClass.EFFECT_DAMAGE), 10.0, "Gold Barbed Wire gains +10 Damage when you Shield")
	_assert_float_eq(_item_runtime_bonus(void_ray, EffectDefinitionClass.EFFECT_BURN), 2.0, "Diamond Void Ray gains +2 Burn when you Shield")

	frozen_bludgeon.current_cooldown = 0.0
	var freeze_result: Dictionary = _battle_system().call("_execute_item_effect_definitions", frozen_bludgeon, _root_context())
	_process_events(freeze_result.get("events", []))
	_assert_true(_trace_has("frozen_bludgeon_root_freeze"), "Frozen Bludgeon root Freeze trace executes")
	_assert_true(_trace_has("frozen_bludgeon_on_enemy_status_applied_runtime_bonus"), "Frozen Bludgeon Freeze-triggered weapon Damage trace executes")
	_assert_float_eq(_item_runtime_bonus(frozen_bludgeon, EffectDefinitionClass.EFFECT_DAMAGE), 8.0, "Gold Frozen Bludgeon gives weapons +8 Damage when you Freeze")

	var poison_event := {"name": EffectDefinitionClass.TRIGGER_ON_ENEMY_STATUS_APPLIED, "source_item": black_rose, "source_id": black_rose.source_id, "status_type": EffectDefinitionClass.EFFECT_POISON, "depth": 0}
	_process_events([poison_event])
	_assert_true(_trace_has("black_rose_on_enemy_status_applied_runtime_bonus"), "Black Rose Poison-triggered Regen trace executes")
	_assert_float_eq(_item_runtime_bonus(black_rose, EffectDefinitionClass.EFFECT_REGENERATION), 2.0, "Gold Black Rose gains +2 Regen when you Poison")

	var multicast_count: int = int(_battle_system().call("_get_player_item_multicast_count", void_ray))
	_assert_true(_trace_has("void_ray_on_cooldown_ready_multicast"), "Void Ray multicast trace is evaluated")
	_assert_eq(multicast_count, 2, "Void Ray Multicast: 2 is represented as one extra cast")
	_battle_system().call("end_battle")

func test_thurible_root_burn_and_regen_are_explicit() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var thurible: ItemDataClass = _create_item("thurible", BazaarContentClass.RARITY_GOLD)
	_assert_true(inv.place_item(thurible, 0), "places Thurible")
	_start_battle(inv)

	_battle_system().call("_execute_item_effect_definitions", thurible, _root_context())
	_assert_true(_trace_has("thurible_root_burn"), "Thurible root Burn trace executes")
	_assert_true(_trace_has("thurible_root_regeneration"), "Thurible fight Regen trace executes")
	_assert_float_eq(_enemy_status(EffectDefinitionClass.EFFECT_BURN), thurible.burn_damage, "Thurible Burns for its source amount")
	_assert_float_eq(_player_status(EffectDefinitionClass.EFFECT_REGENERATION), thurible.regeneration, "Thurible gains source Regen for the fight")
	_battle_system().call("end_battle")

func test_p1e_n_monster_report_delta_shape() -> void:
	var report: Dictionary = BazaarContentClass.get_all_monster_parity_report()
	_assert_true(int(report.get("monster_count", 0)) == 101, "P1E-n all-monster report remains all 101 monsters")
	_assert_true(int(report.get("missing_mechanics_count", 999)) <= 94, "P1E-n does not widen missing monster mechanics from P1E-m baseline")

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

func _enemy_status(status_type: String) -> float:
	return float(_battle_system().call("get_status_totals", "enemy").get(status_type, 0.0))

func _player_status(status_type: String) -> float:
	return float(_battle_system().call("get_status_totals", "player").get(status_type, 0.0))

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
	monster.monster_name = "P1E-n Status Runtime Item Test"
	monster.max_hp = 500
	monster.current_hp = 500
	monster.monster_items = [{"name": "target dummy item", "cooldown": 10.0, "current_cooldown": 5.0}]
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
