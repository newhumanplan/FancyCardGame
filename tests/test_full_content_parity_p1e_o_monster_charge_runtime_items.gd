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
		print("== tests/test_full_content_parity_p1e_o_monster_charge_runtime_items.gd ==")
		test_p1e_o_item_reasons_are_resolved()
		test_p1e_o_definitions_are_explicit()
		test_gatling_gun_runtime_executes_in_battle()
		test_nitro_burns_both_players_and_charges_an_item()
		test_sell_mutation_items_apply_permanent_runtime()
		test_p1e_o_monster_report_delta_shape()
		_print_summary()

func test_p1e_o_item_reasons_are_resolved() -> void:
	var report: Dictionary = BazaarContentClass.get_all_monster_parity_report()
	var reason_counts: Dictionary = report.get("grouped_missing_mechanics", {}).get("reason_counts", {})
	for reason in [
		"item:gatling_gun:unsupported_item_effect:gatling_gun:runtime_bonus",
		"item:nitro:unsupported_item_effect:nitro:burn",
		"item:nitro:unsupported_item_effect:nitro:charge",
		"item:junkyard_club:unsupported_item_effect:junkyard_club:runtime_bonus",
		"item:trained_spider:unsupported_item_effect:trained_spider:runtime_bonus",
	]:
		_assert_true(not reason_counts.has(reason), "P1E-o monster item reason resolved: %s" % reason)

func test_p1e_o_definitions_are_explicit() -> void:
	var expected_ids := {
		"gatling_gun": [
			"gatling_gun_root_damage",
			"gatling_gun_on_cooldown_ready_multicast",
			"gatling_gun_on_cooldown_ready_crit_runtime_bonus",
			"gatling_gun_on_cooldown_ready_first_use_cooldown_runtime_bonus",
		],
		"nitro": [
			"nitro_on_cooldown_ready_enemy_burn",
			"nitro_on_cooldown_ready_self_burn",
			"nitro_on_cooldown_ready_charge",
		],
		"junkyard_club": [
			"junkyard_club_root_damage",
			"junkyard_club_on_sell_damage",
			"junkyard_club_runtime_bonus_supported",
		],
		"trained_spider": [
			"trained_spider_root_poison",
			"trained_spider_on_sell_poison",
			"trained_spider_runtime_bonus_supported",
		],
	}
	for item_id in expected_ids.keys():
		var item: ItemDataClass = _create_item(item_id, BazaarContentClass.RARITY_GOLD)
		var ids: Array[String] = _definition_ids(item)
		for definition_id in expected_ids[item_id]:
			_assert_true(ids.has(str(definition_id)), "%s has %s" % [item_id, str(definition_id)])
		for warning in item.effect_warnings:
			_assert_true(not str(warning).begins_with("unsupported_item_effect:%s:" % item_id), "%s has no stale P1E-o effect warning: %s" % [item_id, str(warning)])

func test_gatling_gun_runtime_executes_in_battle() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var gatling_gun: ItemDataClass = _create_item("gatling_gun", BazaarContentClass.RARITY_GOLD)
	_assert_true(inv.place_item(gatling_gun, 0), "places Gatling Gun")
	_start_battle(inv)

	var multicast_count: int = int(_battle_system().call("_get_player_item_multicast_count", gatling_gun))
	_assert_true(_trace_has("gatling_gun_on_cooldown_ready_multicast"), "Gatling Gun multicast trace is evaluated")
	_assert_eq(multicast_count, 2, "Gatling Gun Multicast: 2 is represented as one extra cast")

	var root_result: Dictionary = _battle_system().call("_execute_item_effect_definitions", gatling_gun, _root_context())
	_assert_true(bool(root_result.get("executed", false)), "Gatling Gun root runtime effects execute")
	_assert_true(_trace_has("gatling_gun_root_damage"), "Gatling Gun root Damage trace executes")
	_assert_true(_trace_has("gatling_gun_on_cooldown_ready_crit_runtime_bonus"), "Gatling Gun fight Crit Chance trace executes")
	_assert_float_eq(_item_runtime_bonus(gatling_gun, "crit_rate"), 10.0, "Gold Gatling Gun gains +10% Crit Chance for the fight")

	var first_use_result: Dictionary = _battle_system().call("_execute_item_effect_definitions", gatling_gun, _root_context(), "after_consume")
	_assert_true(bool(first_use_result.get("executed", false)), "Gatling Gun first-use cooldown runtime executes")
	_assert_true(_trace_has("gatling_gun_on_cooldown_ready_first_use_cooldown_runtime_bonus"), "Gatling Gun first-use cooldown trace executes")
	_assert_float_eq(_item_runtime_bonus(gatling_gun, "cooldown_flat_reduction"), gatling_gun.cooldown * 0.5, "Gatling Gun stores half-cooldown flat reduction")
	var second_use_result: Dictionary = _battle_system().call("_execute_item_effect_definitions", gatling_gun, _root_context(), "after_consume")
	_assert_true(not bool(second_use_result.get("executed", false)), "Gatling Gun first-use cooldown runtime is capped once per fight")
	_assert_float_eq(_item_runtime_bonus(gatling_gun, "cooldown_flat_reduction"), gatling_gun.cooldown * 0.5, "Gatling Gun cooldown runtime does not stack after the first use")
	_battle_system().call("end_battle")

func test_nitro_burns_both_players_and_charges_an_item() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var nitro: ItemDataClass = _create_item("nitro", BazaarContentClass.RARITY_GOLD)
	var target: ItemDataClass = _create_item("lighter", BazaarContentClass.RARITY_BRONZE)
	_assert_true(inv.place_item(nitro, 0), "places Nitro")
	_assert_true(inv.place_item(target, 1), "places Nitro charge target")
	_start_battle(inv)
	target.current_cooldown = 5.0

	var result: Dictionary = _battle_system().call("_execute_item_effect_definitions", nitro, _root_context())
	_assert_true(bool(result.get("executed", false)), "Nitro root Burn/Charge effects execute")
	_assert_true(_trace_has("nitro_on_cooldown_ready_enemy_burn"), "Nitro enemy Burn trace executes")
	_assert_true(_trace_has("nitro_on_cooldown_ready_self_burn"), "Nitro self Burn trace executes")
	_assert_true(_trace_has("nitro_on_cooldown_ready_charge"), "Nitro Charge trace executes")
	_assert_float_eq(_enemy_status(EffectDefinitionClass.EFFECT_BURN), 6.0, "Gold Nitro Burns the enemy for 6")
	_assert_float_eq(_player_status(EffectDefinitionClass.EFFECT_BURN), 6.0, "Gold Nitro Burns self for 6")
	_assert_float_eq(target.current_cooldown, 2.0, "Gold Nitro charges another item by 3 seconds")
	_battle_system().call("end_battle")

func test_sell_mutation_items_apply_permanent_runtime() -> void:
	var weapon_inv: LinearInventoryClass = LinearInventoryClass.new()
	var junkyard_club: ItemDataClass = _create_item("junkyard_club", BazaarContentClass.RARITY_GOLD)
	var weapon_a: ItemDataClass = _create_item("fang", BazaarContentClass.RARITY_BRONZE)
	var weapon_b: ItemDataClass = _create_item("old_sword", BazaarContentClass.RARITY_BRONZE)
	var weapon_a_damage: int = weapon_a.damage
	var weapon_b_damage: int = weapon_b.damage
	_assert_true(weapon_inv.place_item(junkyard_club, 0), "places Junkyard Club")
	_assert_true(weapon_inv.place_item(weapon_a, 2), "places first weapon")
	_assert_true(weapon_inv.place_item(weapon_b, 3), "places second weapon")
	var junkyard_result: Dictionary = SellServiceClass.sell_item(junkyard_club, weapon_inv)
	_assert_true(bool(junkyard_result.get("success", false)), "Junkyard Club sell succeeds")
	_assert_eq(weapon_a.damage, weapon_a_damage + 8, "Gold Junkyard Club gives all weapons +8 Damage")
	_assert_eq(weapon_b.damage, weapon_b_damage + 8, "Gold Junkyard Club applies to every weapon")

	var poison_inv: LinearInventoryClass = LinearInventoryClass.new()
	var trained_spider: ItemDataClass = _create_item("trained_spider", BazaarContentClass.RARITY_GOLD)
	var poison_item: ItemDataClass = _create_item("venom", BazaarContentClass.RARITY_BRONZE)
	var poison_before: float = poison_item.poison_damage
	_assert_true(poison_inv.place_item(trained_spider, 0), "places Trained Spider")
	_assert_true(poison_inv.place_item(poison_item, 1), "places Poison target")
	var trained_result: Dictionary = SellServiceClass.sell_item(trained_spider, poison_inv)
	_assert_true(bool(trained_result.get("success", false)), "Trained Spider sell succeeds")
	_assert_float_eq(poison_item.poison_damage, poison_before + 3.0, "Gold Trained Spider gives the leftmost Poison item +3 Poison")

func test_p1e_o_monster_report_delta_shape() -> void:
	var report: Dictionary = BazaarContentClass.get_all_monster_parity_report()
	_assert_true(int(report.get("monster_count", 0)) == 101, "P1E-o all-monster report remains all 101 monsters")
	_assert_true(int(report.get("missing_mechanics_count", 999)) <= 94, "P1E-o does not widen missing monster mechanics from P1E-n baseline")

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
	monster.monster_name = "P1E-o Charge Runtime Item Test"
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
