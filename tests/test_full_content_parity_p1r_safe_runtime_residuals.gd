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
		print("== tests/test_full_content_parity_p1r_safe_runtime_residuals.gd ==")
		test_p1r_reasons_are_resolved()
		test_p1r_item_definitions_are_explicit()
		test_anchor_damage_and_adjacent_haste_runtime()
		test_electric_eels_charges_when_enemy_uses_item()
		test_haste_reference_items_apply_runtime()
		test_p1r_numeric_skills_change_monster_items()
		test_p1r_monster_report_delta_shape()
		_print_summary()

func test_p1r_reasons_are_resolved() -> void:
	var report: Dictionary = BazaarContentClass.get_all_monster_parity_report()
	var reason_counts: Dictionary = report.get("grouped_missing_mechanics", {}).get("reason_counts", {})
	for reason in [
		"item:goggles:unsupported_item_effect:goggles:runtime_bonus",
		"item:pufferfish:unsupported_item_effect:pufferfish:charge",
		"item:anchor:unsupported_item_effect:anchor:damage",
		"item:anchor:unsupported_item_effect:anchor:haste",
		"item:anchor:unsupported_item_effect:anchor:runtime_bonus",
		"item:electric_eels:unsupported_item_effect:electric_eels:charge",
		"skill:exposing_toxins:player_skill_runtime_not_bound_to_monster_ai:battle_runtime_numeric",
		"skill:reaching_the_summit:player_skill_runtime_not_bound_to_monster_ai:battle_runtime_numeric",
		"skill:tracer_fire:player_skill_runtime_not_bound_to_monster_ai:battle_runtime_numeric",
	]:
		_assert_true(not reason_counts.has(reason), "P1R residual reason resolved: %s" % reason)
	_assert_true(reason_counts.has("item:lockbox:unsupported_item_effect:lockbox:runtime_bonus"), "Lockbox remains explicit because value/economy semantics are out of scope")

func test_p1r_item_definitions_are_explicit() -> void:
	var expected_ids := {
		"anchor": [
			"anchor_on_cooldown_ready_damage",
			"anchor_on_item_used_haste",
			"anchor_runtime_bonus_supported",
		],
		"electric_eels": [
			"electric_eels_root_damage",
			"electric_eels_root_slow",
			"electric_eels_on_item_used_charge",
		],
		"goggles": [
			"goggles_root_shield",
			"goggles_on_item_used_runtime_bonus",
		],
		"pufferfish": [
			"pufferfish_root_poison",
			"pufferfish_on_item_used_charge",
		],
	}
	for item_id in expected_ids.keys():
		var item: ItemDataClass = _create_item(item_id, BazaarContentClass.RARITY_GOLD)
		var ids: Array[String] = _definition_ids(item)
		for definition_id in expected_ids[item_id]:
			_assert_true(ids.has(str(definition_id)), "%s has %s" % [item_id, str(definition_id)])
		for warning in item.effect_warnings:
			_assert_true(not str(warning).begins_with("unsupported_item_effect:%s:" % item_id), "%s has no stale P1R effect warning: %s" % [item_id, str(warning)])

func test_anchor_damage_and_adjacent_haste_runtime() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var anchor: ItemDataClass = _create_item("anchor", BazaarContentClass.RARITY_GOLD)
	var adjacent: ItemDataClass = _create_item("fang", BazaarContentClass.RARITY_BRONZE)
	_assert_true(inv.place_item(anchor, 0), "places Anchor")
	_assert_true(inv.place_item(adjacent, 2), "places adjacent item")
	var monster: MonsterDataClass = _start_battle(inv, "P1R Anchor Test", 1000)
	anchor.current_cooldown = 5.0
	var damage_result: Dictionary = _battle_system().call("_execute_item_effect_definitions", anchor, _root_context())
	_assert_true(bool(damage_result.get("executed", false)), "Anchor damage effect executes")
	_assert_true(_trace_has("anchor_on_cooldown_ready_damage"), "Anchor enemy max-health damage trace executes")
	_assert_eq(monster.current_hp, 800, "Gold Anchor deals 20% of enemy max health")
	var events: Array[Dictionary] = [_battle_system().call("_make_effect_event", EffectDefinitionClass.TRIGGER_ON_ITEM_USED, adjacent)]
	_battle_system().call("_process_reactive_effect_events", events)
	_assert_true(_trace_has("anchor_on_item_used_haste"), "Anchor adjacent-use Haste trace executes")
	_assert_float_eq(anchor.current_cooldown, 3.0, "Gold Anchor hastes itself by 2 seconds after adjacent item use")
	_battle_system().call("end_battle")

func test_electric_eels_charges_when_enemy_uses_item() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var eels: ItemDataClass = _create_item("electric_eels", BazaarContentClass.RARITY_GOLD)
	_assert_true(inv.place_item(eels, 0), "places Electric Eels")
	_start_battle(inv, "P1R Electric Eels Test")
	eels.current_cooldown = 5.0
	_battle_system().call("_after_monster_item_used", 0)
	_assert_float_eq(eels.current_cooldown, 3.0, "Electric Eels charges 2 seconds when enemy uses an item")
	_battle_system().call("end_battle")

func test_haste_reference_items_apply_runtime() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var goggles: ItemDataClass = _create_item("goggles", BazaarContentClass.RARITY_GOLD)
	var left_weapon: ItemDataClass = _create_item("fang", BazaarContentClass.RARITY_BRONZE)
	var pufferfish: ItemDataClass = _create_item("pufferfish", BazaarContentClass.RARITY_GOLD)
	_assert_true(inv.place_item(left_weapon, 0), "places left adjacent weapon")
	_assert_true(inv.place_item(goggles, 1), "places Goggles")
	_assert_true(inv.place_item(pufferfish, 3), "places Pufferfish")
	_start_battle(inv, "P1R Haste Reference Test")
	pufferfish.current_cooldown = 7.0
	_battle_system().call("_handle_player_item_gained_haste", goggles, 1)
	_battle_system().call("_handle_player_item_gained_haste", pufferfish, 1)
	_assert_float_eq(_item_runtime_bonus(left_weapon, "crit_rate"), 6.0, "Gold Goggles gives adjacent items +6% Crit Chance when it gains Haste")
	_assert_float_eq(pufferfish.current_cooldown, 5.0, "Pufferfish charges itself by 2 seconds when you Haste")
	_battle_system().call("end_battle")

func test_p1r_numeric_skills_change_monster_items() -> void:
	var foundation = BazaarContentClass.create_monster("foundation_weeper", 0)
	_assert_true(_all_items_at_least(foundation, "crit_chance", 0.01), "Exposing Toxins gives Foundation Weeper items +1% crit")
	var chilly = BazaarContentClass.create_monster("chilly_charles", 0)
	_assert_true(_all_items_at_least(chilly, "crit_chance", 0.03), "Reaching the Summit gives Chilly Charles items +3% crit")
	var annex = BazaarContentClass.create_monster("annex_trooper", 0)
	_assert_true(_all_items_at_least(annex, "crit_chance", 0.01), "Tracer Fire gives Annex Trooper items +1% crit")

func test_p1r_monster_report_delta_shape() -> void:
	var report: Dictionary = BazaarContentClass.get_all_monster_parity_report()
	_assert_true(int(report.get("monster_count", 0)) == 101, "P1R all-monster report remains all 101 monsters")
	_assert_true(int(report.get("missing_mechanics_count", 999)) <= 94, "P1R does not widen missing monster mechanics from fresh audit baseline")

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

func _start_battle(inv: LinearInventoryClass, monster_name: String, max_hp: int = 500) -> MonsterDataClass:
	var hero = BazaarContentClass.create_mak_hero()
	var game_manager: Node = _game_manager()
	game_manager.call("reset_stats")
	game_manager.set("selected_hero", hero)
	game_manager.set("player_health", hero.max_hp)
	var monster: MonsterDataClass = MonsterDataClass.new()
	monster.monster_name = monster_name
	monster.max_hp = max_hp
	monster.current_hp = max_hp
	monster.monster_items = [{"source_id": "enemy_a", "name": "enemy item", "cooldown": 10.0, "current_cooldown": 0.0}]
	_battle_system().call("start_battle", monster, inv)
	return monster

func _all_items_at_least(monster, key: String, expected: float) -> bool:
	if monster == null or monster.monster_items.is_empty():
		return false
	for item in monster.monster_items:
		if not item is Dictionary:
			return false
		if float((item as Dictionary).get(key, 0.0)) < expected:
			return false
	return true

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
