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
		print("== tests/test_full_content_parity_p1e_h_monster_runtime_bonus_items.gd ==")
		test_p1e_h_item_reasons_are_resolved()
		test_p1e_h_definitions_are_explicit()
		test_incendiary_rounds_grants_adjacent_ammo_and_burns()
		test_jellyfish_and_bomb_squad_haste_from_adjacent_tags()
		test_p1e_h_monster_report_delta_shape()
		_print_summary()

func test_p1e_h_item_reasons_are_resolved() -> void:
	var report: Dictionary = BazaarContentClass.get_all_monster_parity_report()
	var reason_counts: Dictionary = report.get("grouped_missing_mechanics", {}).get("reason_counts", {})
	for reason in [
		"item:incendiary_rounds:unsupported_item_effect:incendiary_rounds:runtime_bonus",
		"item:jellyfish:unsupported_item_effect:jellyfish:haste",
		"item:jellyfish:unsupported_item_effect:jellyfish:runtime_bonus",
		"item:bomb_squad:unsupported_item_effect:bomb_squad:haste",
	]:
		_assert_true(not reason_counts.has(reason), "P1E-h monster item reason resolved: %s" % reason)

func test_p1e_h_definitions_are_explicit() -> void:
	var expected_ids := {
		"incendiary_rounds": ["incendiary_rounds_on_battle_start_ammo", "incendiary_rounds_on_item_used_burn"],
		"jellyfish": ["jellyfish_on_item_used_haste"],
		"bomb_squad": ["bomb_squad_on_item_used_haste"],
	}
	for item_id in expected_ids.keys():
		var item: ItemDataClass = _create_item(item_id, BazaarContentClass.RARITY_SILVER)
		var ids: Array[String] = _definition_ids(item)
		for definition_id in expected_ids[item_id]:
			_assert_true(ids.has(str(definition_id)), "%s has %s" % [item_id, str(definition_id)])
		for warning in item.effect_warnings:
			_assert_true(not str(warning).begins_with("unsupported_item_effect:%s:" % item_id), "%s has no stale P1E-h effect warning: %s" % [item_id, str(warning)])

func test_incendiary_rounds_grants_adjacent_ammo_and_burns() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var left_ammo: ItemDataClass = _create_item("bottled_tornado", BazaarContentClass.RARITY_SILVER)
	var rounds: ItemDataClass = _create_item("incendiary_rounds", BazaarContentClass.RARITY_SILVER)
	var right_ammo: ItemDataClass = _create_item("frost_potion", BazaarContentClass.RARITY_SILVER)
	_assert_true(inv.place_item(left_ammo, 0), "places left Ammo item")
	_assert_true(inv.place_item(rounds, 1), "places Incendiary Rounds")
	_assert_true(inv.place_item(right_ammo, 2), "places right Ammo item")
	var left_max_before: int = left_ammo.get_max_ammo()
	var right_max_before: int = right_ammo.get_max_ammo()
	_start_battle(inv)

	_assert_true(_trace_has("incendiary_rounds_on_battle_start_ammo"), "Incendiary Rounds adjacent Ammo trace executes")
	_assert_eq(left_ammo.get_max_ammo(), left_max_before + 1, "left adjacent item gains Max Ammo")
	_assert_eq(right_ammo.get_max_ammo(), right_max_before + 1, "right adjacent item gains Max Ammo")
	var burn_before: float = _enemy_status(EffectDefinitionClass.EFFECT_BURN)
	_process_events([{"name": EffectDefinitionClass.TRIGGER_ON_ITEM_USED, "source_item": left_ammo, "source_id": left_ammo.source_id, "depth": 0}])
	_assert_true(_trace_has("incendiary_rounds_on_item_used_burn"), "Incendiary Rounds adjacent-use Burn trace executes")
	_assert_true(_enemy_status(EffectDefinitionClass.EFFECT_BURN) >= burn_before + 2.0, "Incendiary Rounds applies at least its source Burn from adjacent item use")
	_battle_system().call("end_battle")

func test_jellyfish_and_bomb_squad_haste_from_adjacent_tags() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var aquatic_source: ItemDataClass = _create_item("jellyfish", BazaarContentClass.RARITY_SILVER)
	var jellyfish: ItemDataClass = _create_item("jellyfish", BazaarContentClass.RARITY_GOLD)
	var bomb_squad: ItemDataClass = _create_item("bomb_squad")
	var friend_source: ItemDataClass = _create_item("bomb_squad")
	_assert_true(inv.place_item(aquatic_source, 0), "places adjacent Aquatic source")
	_assert_true(inv.place_item(jellyfish, 1), "places Jellyfish")
	_assert_true(inv.place_item(bomb_squad, 3), "places Bomb Squad")
	_assert_true(inv.place_item(friend_source, 4), "places adjacent Friend source")
	_start_battle(inv)
	jellyfish.current_cooldown = 7.0
	bomb_squad.current_cooldown = 11.0

	_process_events([{"name": EffectDefinitionClass.TRIGGER_ON_ITEM_USED, "source_item": aquatic_source, "source_id": aquatic_source.source_id, "depth": 0}])
	_assert_true(_trace_has("jellyfish_on_item_used_haste"), "Jellyfish adjacent Aquatic Haste trace executes")
	_assert_float_eq(jellyfish.current_cooldown, 4.0, "Jellyfish hastes itself by rarity amount")
	_process_events([{"name": EffectDefinitionClass.TRIGGER_ON_ITEM_USED, "source_item": friend_source, "source_id": friend_source.source_id, "depth": 0}])
	_assert_true(_trace_has("bomb_squad_on_item_used_haste"), "Bomb Squad adjacent Friend Haste trace executes")
	_assert_float_eq(bomb_squad.current_cooldown, 9.0, "Bomb Squad hastes itself by 2 seconds")
	_battle_system().call("end_battle")

func test_p1e_h_monster_report_delta_shape() -> void:
	var report: Dictionary = BazaarContentClass.get_all_monster_parity_report()
	_assert_true(int(report.get("monster_count", 0)) == 101, "P1E-h all-monster report remains all 101 monsters")
	_assert_true(int(report.get("missing_mechanics_count", 999)) <= 95, "P1E-h does not widen missing monster mechanics from P1E-g baseline")

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

func _enemy_status(status_type: String) -> float:
	return float(_battle_system().call("get_status_totals", "enemy").get(status_type, 0.0))

func _process_events(events: Array[Dictionary]) -> void:
	_battle_system().call("_process_reactive_effect_events", events)

func _start_battle(inv: LinearInventoryClass) -> MonsterDataClass:
	var hero = BazaarContentClass.create_mak_hero()
	var game_manager: Node = _game_manager()
	game_manager.call("reset_stats")
	game_manager.set("selected_hero", hero)
	game_manager.set("player_health", hero.max_hp)
	var monster: MonsterDataClass = MonsterDataClass.new()
	monster.monster_name = "P1E-h Runtime Bonus Test"
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
