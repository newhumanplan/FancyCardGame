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
		print("== tests/test_full_content_parity_p1e_j_monster_charge_runtime_items.gd ==")
		test_p1e_j_item_reasons_are_resolved()
		test_p1e_j_definitions_are_explicit()
		test_charge_runtime_items_apply_in_battle()
		test_p1e_j_monster_report_delta_shape()
		_print_summary()

func test_p1e_j_item_reasons_are_resolved() -> void:
	var report: Dictionary = BazaarContentClass.get_all_monster_parity_report()
	var reason_counts: Dictionary = report.get("grouped_missing_mechanics", {}).get("reason_counts", {})
	for reason in [
		"item:cosmic_plumage:unsupported_item_effect:cosmic_plumage:charge",
		"item:cosmic_plumage:unsupported_item_effect:cosmic_plumage:runtime_bonus",
		"item:nargile:unsupported_item_effect:nargile:charge",
		"item:pearl:unsupported_item_effect:pearl:charge",
	]:
		_assert_true(not reason_counts.has(reason), "P1E-j monster item reason resolved: %s" % reason)

func test_p1e_j_definitions_are_explicit() -> void:
	var expected_ids := {
		"cosmic_plumage": [
			"cosmic_plumage_on_battle_start_shield_runtime_bonus",
			"cosmic_plumage_on_battle_start_weapon_runtime_bonus",
			"cosmic_plumage_on_crit_charge",
		],
		"nargile": [
			"nargile_on_battle_start_runtime_bonus",
			"nargile_on_crit_charge",
		],
		"pearl": ["pearl_on_tag_used_charge"],
	}
	for item_id in expected_ids.keys():
		var item: ItemDataClass = _create_item(item_id, BazaarContentClass.RARITY_GOLD)
		var ids: Array[String] = _definition_ids(item)
		for definition_id in expected_ids[item_id]:
			_assert_true(ids.has(str(definition_id)), "%s has %s" % [item_id, str(definition_id)])
		for warning in item.effect_warnings:
			_assert_true(not str(warning).begins_with("unsupported_item_effect:%s:" % item_id), "%s has no stale P1E-j effect warning: %s" % [item_id, str(warning)])

func test_charge_runtime_items_apply_in_battle() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var cosmic: ItemDataClass = _create_item("cosmic_plumage", BazaarContentClass.RARITY_DIAMOND)
	var nargile: ItemDataClass = _create_item("nargile", BazaarContentClass.RARITY_DIAMOND)
	var pearl: ItemDataClass = _create_item("pearl", BazaarContentClass.RARITY_GOLD)
	var aquatic: ItemDataClass = _create_item("jellyfish", BazaarContentClass.RARITY_GOLD)
	var weapon: ItemDataClass = _create_item("fang", BazaarContentClass.RARITY_BRONZE)
	_assert_true(inv.place_item(weapon, 0), "places Weapon target")
	_assert_true(inv.place_item(nargile, 1), "places Nargile")
	_assert_true(inv.place_item(pearl, 3), "places Pearl")
	_assert_true(inv.place_item(cosmic, 4), "places Cosmic Plumage")
	_assert_true(inv.place_item(aquatic, 6), "places Aquatic source")
	_start_battle(inv)

	_assert_true(_trace_has("cosmic_plumage_on_battle_start_shield_runtime_bonus"), "Cosmic Plumage battle-start Shield runtime trace executes")
	_assert_true(_trace_has("cosmic_plumage_on_battle_start_weapon_runtime_bonus"), "Cosmic Plumage battle-start Weapon runtime trace executes")
	_assert_true(_trace_has("nargile_on_battle_start_runtime_bonus"), "Nargile battle-start crit trace executes")
	_assert_float_eq(_item_runtime_bonus(weapon, EffectDefinitionClass.EFFECT_DAMAGE), 30.0, "Cosmic Plumage gives Diamond Weapon +Damage")
	_assert_float_eq(_item_runtime_bonus(pearl, EffectDefinitionClass.EFFECT_SHIELD), 30.0, "Cosmic Plumage gives Diamond Shield item +Shield")
	_assert_float_eq(_item_runtime_bonus(weapon, "crit_rate"), 50.0, "Nargile gives left adjacent item Diamond Crit Chance")

	cosmic.current_cooldown = 7.0
	nargile.current_cooldown = 7.0
	pearl.current_cooldown = 7.0
	_process_events([
		{"name": EffectDefinitionClass.TRIGGER_ON_CRIT, "source_item": cosmic, "source_id": cosmic.source_id, "depth": 0},
		{"name": EffectDefinitionClass.TRIGGER_ON_CRIT, "source_item": nargile, "source_id": nargile.source_id, "depth": 0},
		{"name": EffectDefinitionClass.TRIGGER_ON_TAG_USED, "source_item": aquatic, "source_id": aquatic.source_id, "depth": 0},
	])
	_assert_true(_trace_has("cosmic_plumage_on_crit_charge"), "Cosmic Plumage crit Charge trace executes")
	_assert_true(_trace_has("nargile_on_crit_charge"), "Nargile crit Charge trace executes")
	_assert_true(_trace_has("pearl_on_tag_used_charge"), "Pearl Aquatic-use Charge trace executes")
	_assert_float_eq(cosmic.current_cooldown, 4.0, "Cosmic Plumage Charges itself 3 seconds on crit")
	_assert_float_eq(nargile.current_cooldown, 5.0, "Nargile Charges itself 2 seconds on crit")
	_assert_float_eq(pearl.current_cooldown, 6.0, "Pearl Charges itself 1 second when another Aquatic item is used")
	_battle_system().call("end_battle")

func test_p1e_j_monster_report_delta_shape() -> void:
	var report: Dictionary = BazaarContentClass.get_all_monster_parity_report()
	_assert_true(int(report.get("monster_count", 0)) == 101, "P1E-j all-monster report remains all 101 monsters")
	_assert_true(int(report.get("missing_mechanics_count", 999)) <= 95, "P1E-j does not widen missing monster mechanics from P1E-i baseline")

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
	monster.monster_name = "P1E-j Charge Runtime Item Test"
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
