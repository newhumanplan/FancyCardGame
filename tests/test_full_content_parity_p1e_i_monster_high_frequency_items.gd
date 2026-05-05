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
		print("== tests/test_full_content_parity_p1e_i_monster_high_frequency_items.gd ==")
		test_p1e_i_item_reasons_are_resolved()
		test_p1e_i_definitions_are_explicit()
		test_battle_start_runtime_bonuses_apply()
		test_seaweed_gains_heal_from_aquatic_use()
		test_p1e_i_monster_report_delta_shape()
		_print_summary()

func test_p1e_i_item_reasons_are_resolved() -> void:
	var report: Dictionary = BazaarContentClass.get_all_monster_parity_report()
	var reason_counts: Dictionary = report.get("grouped_missing_mechanics", {}).get("reason_counts", {})
	for reason in [
		"item:amber:unsupported_item_effect:amber:runtime_bonus",
		"item:blue_piggles_l:unsupported_item_effect:blue_piggles_l:runtime_bonus",
		"item:fire_claw:unsupported_item_effect:fire_claw:runtime_bonus",
		"item:seaweed:unsupported_item_effect:seaweed:runtime_bonus",
		"item:spices:unsupported_item_effect:spices:runtime_bonus",
	]:
		_assert_true(not reason_counts.has(reason), "P1E-i monster item reason resolved: %s" % reason)

func test_p1e_i_definitions_are_explicit() -> void:
	var expected_ids := {
		"amber": ["amber_on_battle_start_runtime_bonus"],
		"blue_piggles_l": ["blue_piggles_l_on_battle_start_runtime_bonus"],
		"fire_claw": ["fire_claw_on_battle_start_runtime_bonus"],
		"seaweed": ["seaweed_on_tag_used_runtime_bonus"],
		"spices": ["spices_on_battle_start_runtime_bonus"],
	}
	for item_id in expected_ids.keys():
		var item: ItemDataClass = _create_item(item_id, BazaarContentClass.RARITY_GOLD)
		var ids: Array[String] = _definition_ids(item)
		for definition_id in expected_ids[item_id]:
			_assert_true(ids.has(str(definition_id)), "%s has %s" % [item_id, str(definition_id)])
		for warning in item.effect_warnings:
			_assert_true(not str(warning).begins_with("unsupported_item_effect:%s:" % item_id), "%s has no stale P1E-i effect warning: %s" % [item_id, str(warning)])

func test_battle_start_runtime_bonuses_apply() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var amber: ItemDataClass = _create_item("amber", BazaarContentClass.RARITY_GOLD)
	var slow_item: ItemDataClass = _create_item("bottled_tornado", BazaarContentClass.RARITY_SILVER)
	var blue_piggles: ItemDataClass = _create_item("blue_piggles_l", BazaarContentClass.RARITY_GOLD)
	var left_weapon: ItemDataClass = _create_item("fang", BazaarContentClass.RARITY_BRONZE)
	var fire_claw: ItemDataClass = _create_item("fire_claw", BazaarContentClass.RARITY_GOLD)
	var burn_item: ItemDataClass = _create_item("ruby", BazaarContentClass.RARITY_GOLD)
	var spices: ItemDataClass = _create_item("spices", BazaarContentClass.RARITY_DIAMOND)
	var strong_weapon: ItemDataClass = _create_item("revolver", BazaarContentClass.RARITY_GOLD)
	var weakest_weapon_damage: float = float(left_weapon.get_rarity_adjusted_damage())
	var other_burn_total: float = burn_item.burn_damage
	_assert_true(inv.place_item(amber, 0), "places Amber")
	_assert_true(inv.place_item(slow_item, 1), "places target Slow item")
	_assert_true(inv.place_item(left_weapon, 3), "places left Weapon")
	_assert_true(inv.place_item(blue_piggles, 4), "places Blue Piggles L")
	_assert_true(inv.place_item(fire_claw, 5), "places Fire Claw")
	_assert_true(inv.place_item(burn_item, 7), "places other Burn item")
	_assert_true(inv.place_item(spices, 8), "places Spices")
	_assert_true(inv.place_item(strong_weapon, 9), "places stronger Weapon")
	_start_battle(inv)

	_assert_true(_trace_has("amber_on_battle_start_runtime_bonus"), "Amber battle-start slow-count bonus trace executes")
	_assert_true(_trace_has("blue_piggles_l_on_battle_start_runtime_bonus"), "Blue Piggles L battle-start crit trace executes")
	_assert_true(_trace_has("fire_claw_on_battle_start_runtime_bonus"), "Fire Claw battle-start Burn trace executes")
	_assert_true(_trace_has("spices_on_battle_start_runtime_bonus"), "Spices battle-start weapon damage trace executes")
	_assert_float_eq(_item_runtime_bonus(slow_item, "slow_count"), 1.0, "Amber grants other Slow item +1 Slow count")
	_assert_float_eq(_item_runtime_bonus(left_weapon, "crit_rate"), 12.0, "Blue Piggles L grants left item Crit Chance for the fight")
	_assert_float_eq(_item_runtime_bonus(fire_claw, EffectDefinitionClass.EFFECT_BURN), other_burn_total, "Fire Claw gains Burn equal to 100% of other Burn at Gold")
	_assert_float_eq(_item_runtime_bonus(left_weapon, EffectDefinitionClass.EFFECT_DAMAGE), weakest_weapon_damage, "Spices grants each Weapon weakest Weapon damage")
	_assert_float_eq(_item_runtime_bonus(strong_weapon, EffectDefinitionClass.EFFECT_DAMAGE), weakest_weapon_damage, "Spices applies same weakest Weapon damage to stronger Weapon")
	_battle_system().call("end_battle")

func test_seaweed_gains_heal_from_aquatic_use() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var aquatic: ItemDataClass = _create_item("jellyfish", BazaarContentClass.RARITY_SILVER)
	var seaweed: ItemDataClass = _create_item("seaweed", BazaarContentClass.RARITY_GOLD)
	_assert_true(inv.place_item(aquatic, 0), "places Aquatic source")
	_assert_true(inv.place_item(seaweed, 1), "places Seaweed")
	_start_battle(inv)

	_process_events([{"name": EffectDefinitionClass.TRIGGER_ON_TAG_USED, "source_item": aquatic, "source_id": aquatic.source_id, "depth": 0}])
	_assert_true(_trace_has("seaweed_on_tag_used_runtime_bonus"), "Seaweed Aquatic-use Heal trace executes")
	_assert_float_eq(_item_runtime_bonus(seaweed, EffectDefinitionClass.EFFECT_HEAL), 15.0, "Seaweed gains Gold Heal bonus for the fight")
	_battle_system().call("end_battle")

func test_p1e_i_monster_report_delta_shape() -> void:
	var report: Dictionary = BazaarContentClass.get_all_monster_parity_report()
	_assert_true(int(report.get("monster_count", 0)) == 101, "P1E-i all-monster report remains all 101 monsters")
	_assert_true(int(report.get("missing_mechanics_count", 999)) <= 95, "P1E-i does not widen missing monster mechanics from P1E-h baseline")

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
	monster.monster_name = "P1E-i High Frequency Item Test"
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
