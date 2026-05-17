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
		print("== tests/test_full_content_parity_p2b_confirmed_remainder.gd ==")
		test_confirmed_remainder_reasons_are_resolved()
		test_confirmed_remainder_definition_anchors_exist()
		test_charge_and_reactive_runtime_families()
		test_enemy_item_use_and_flying_reload_families()
		test_direct_status_and_shield_damage_families()
		_print_summary()

func test_confirmed_remainder_reasons_are_resolved() -> void:
	var report: Dictionary = BazaarContentClass.get_all_monster_parity_report()
	var reason_counts: Dictionary = report.get("grouped_missing_mechanics", {}).get("reason_counts", {})
	for reason in _implemented_reason_keys():
		_assert_true(not reason_counts.has(reason), "P2B-5 reason resolved: %s" % reason)

func test_confirmed_remainder_definition_anchors_exist() -> void:
	var expected_ids := {
		"ethergy_conduit": ["ethergy_conduit_on_crit_charge"],
		"eye_of_the_colossus": ["eye_of_the_colossus_on_item_used_charge"],
		"ice_cream_truck": ["ice_cream_truck_on_item_used_charge"],
		"iceberg": ["iceberg_freeze_trigger_condition_supported"],
		"tripwire": ["tripwire_slow_trigger_condition_supported"],
		"void_shield": ["void_shield_burn_trigger_condition_supported"],
		"fire_bomb": ["fire_bomb_reload_trigger_condition_supported"],
		"ice_bomb": ["ice_bomb_reload_trigger_condition_supported"],
		"flare_gun": ["flare_gun_on_cooldown_ready_burn"],
		"golf_clubs": ["golf_clubs_on_heal_runtime_bonus"],
		"holsters": ["holsters_on_battle_start_haste"],
		"infernal_greatsword": ["infernal_greatsword_on_cooldown_ready_burn"],
		"refractor": ["refractor_on_enemy_status_applied_runtime_bonus", "refractor_freeze_trigger_condition_supported"],
		"ritual_dagger": ["ritual_dagger_on_cooldown_ready_regeneration"],
		"soul_of_the_district": ["soul_of_the_district_on_cooldown_ready_shield", "soul_of_the_district_on_cooldown_ready_damage"],
	}
	for item_id in expected_ids.keys():
		var ids: Array[String] = _definition_ids(_create_item(str(item_id), BazaarContentClass.RARITY_GOLD))
		for definition_id in expected_ids[item_id]:
			_assert_true(ids.has(str(definition_id)), "%s has %s" % [str(item_id), str(definition_id)])

func test_charge_and_reactive_runtime_families() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var conduit: ItemDataClass = _create_item("ethergy_conduit", BazaarContentClass.RARITY_GOLD)
	var relic: ItemDataClass = _create_item("ritual_dagger", BazaarContentClass.RARITY_GOLD)
	_assert_true(inv.place_item(conduit, 0), "places Ethergy Conduit")
	_assert_true(inv.place_item(relic, 4), "places Relic")
	_start_battle(inv, "P2B-5 Ethergy Runtime")
	relic.current_cooldown = 5.0
	_process_event(EffectDefinitionClass.TRIGGER_ON_CRIT, conduit)
	_assert_float_eq(relic.current_cooldown, 4.0, "Ethergy Conduit charges Relics when you Crit")
	_battle_system().call("end_battle")

	var inv2: LinearInventoryClass = LinearInventoryClass.new()
	var adjacent_source: ItemDataClass = _create_item("fang")
	var eye: ItemDataClass = _create_item("eye_of_the_colossus", BazaarContentClass.RARITY_GOLD)
	_assert_true(inv2.place_item(adjacent_source, 0), "places adjacent source")
	_assert_true(inv2.place_item(eye, 1), "places Eye of the Colossus")
	_start_battle(inv2, "P2B-5 Eye Runtime")
	eye.current_cooldown = 5.0
	_process_event(EffectDefinitionClass.TRIGGER_ON_ITEM_USED, adjacent_source)
	_assert_float_eq(eye.current_cooldown, 4.0, "Eye of the Colossus charges on adjacent item use")
	_battle_system().call("end_battle")

	var inv3: LinearInventoryClass = LinearInventoryClass.new()
	var truck: ItemDataClass = _create_item("ice_cream_truck", BazaarContentClass.RARITY_GOLD)
	var non_weapon: ItemDataClass = _create_item("holsters", BazaarContentClass.RARITY_GOLD)
	_assert_true(inv3.place_item(truck, 0), "places Ice Cream Truck")
	_assert_true(inv3.place_item(non_weapon, 5), "places non-Weapon source")
	_start_battle(inv3, "P2B-5 Truck Runtime")
	truck.current_cooldown = 5.0
	_process_event(EffectDefinitionClass.TRIGGER_ON_ITEM_USED, non_weapon)
	_assert_float_eq(truck.current_cooldown, 4.0, "Ice Cream Truck charges when another non-Weapon item is used")
	_battle_system().call("end_battle")

	var inv4: LinearInventoryClass = LinearInventoryClass.new()
	var refractor: ItemDataClass = _create_item("refractor", BazaarContentClass.RARITY_GOLD)
	var freeze_source: ItemDataClass = _create_item("ice_pick", BazaarContentClass.RARITY_GOLD)
	_assert_true(inv4.place_item(refractor, 0), "places Refractor")
	_start_battle(inv4, "P2B-5 Refractor Runtime")
	_process_event(EffectDefinitionClass.TRIGGER_ON_ENEMY_STATUS_APPLIED, freeze_source, {"status_type": EffectDefinitionClass.EFFECT_FREEZE})
	_assert_float_eq(_item_runtime_bonus(refractor, EffectDefinitionClass.EFFECT_DAMAGE), 30.0, "Gold Refractor gains +30 Damage when you Freeze")
	_battle_system().call("end_battle")

func test_enemy_item_use_and_flying_reload_families() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var iceberg: ItemDataClass = _create_item("iceberg", BazaarContentClass.RARITY_GOLD)
	var tripwire: ItemDataClass = _create_item("tripwire", BazaarContentClass.RARITY_GOLD)
	var void_shield: ItemDataClass = _create_item("void_shield", BazaarContentClass.RARITY_GOLD)
	_assert_true(inv.place_item(iceberg, 0), "places Iceberg")
	_assert_true(inv.place_item(tripwire, 3), "places Tripwire")
	_assert_true(inv.place_item(void_shield, 5), "places Void Shield")
	var monster: MonsterDataClass = _start_battle(inv, "P2B-5 Enemy Use Runtime")
	monster.monster_items = [{"source_id": "fang", "name": "Fang", "size": "Small", "tags": ["Weapon"], "cooldown": 4.0, "current_cooldown": 2.0}]
	_battle_system().call("_after_monster_item_used", 0)
	_assert_float_eq(float(monster.monster_items[0].get("current_cooldown", 0.0)), 3.5, "Iceberg and Tripwire apply enemy item-use Freeze/Slow")
	_assert_float_eq(_enemy_status(EffectDefinitionClass.EFFECT_BURN), 1.0, "Void Shield Burns when enemy uses an item")
	_battle_system().call("end_battle")

	var inv2: LinearInventoryClass = LinearInventoryClass.new()
	var fire_bomb: ItemDataClass = _create_item("fire_bomb", BazaarContentClass.RARITY_GOLD)
	var ice_bomb: ItemDataClass = _create_item("ice_bomb", BazaarContentClass.RARITY_GOLD)
	_assert_true(inv2.place_item(fire_bomb, 0), "places Fire Bomb")
	_assert_true(inv2.place_item(ice_bomb, 1), "places Ice Bomb")
	_start_battle(inv2, "P2B-5 Flying Reload Runtime")
	fire_bomb.current_ammo = 0
	ice_bomb.current_ammo = 0
	_battle_system().call("_set_player_item_flying", fire_bomb, "test")
	_battle_system().call("_set_player_item_flying", ice_bomb, "test")
	_assert_eq(fire_bomb.current_ammo, 1, "Fire Bomb reloads when it starts Flying")
	_assert_eq(ice_bomb.current_ammo, 1, "Ice Bomb reloads when it starts Flying")
	_battle_system().call("end_battle")

func test_direct_status_and_shield_damage_families() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var holsters: ItemDataClass = _create_item("holsters", BazaarContentClass.RARITY_GOLD)
	var small_weapon: ItemDataClass = _create_item("fang")
	_assert_true(inv.place_item(holsters, 0), "places Holsters")
	_assert_true(inv.place_item(small_weapon, 2), "places Small item")
	small_weapon.current_cooldown = 3.0
	_start_battle(inv, "P2B-5 Holsters Runtime")
	_assert_float_eq(small_weapon.current_cooldown, 1.0, "Gold Holsters gives Small items 2 seconds of Haste at battle start")
	_battle_system().call("end_battle")

	var inv2: LinearInventoryClass = LinearInventoryClass.new()
	var ritual: ItemDataClass = _create_item("ritual_dagger", BazaarContentClass.RARITY_GOLD)
	var infernal: ItemDataClass = _create_item("infernal_greatsword", BazaarContentClass.RARITY_GOLD)
	var soul: ItemDataClass = _create_item("soul_of_the_district", BazaarContentClass.RARITY_GOLD)
	var flare: ItemDataClass = _create_item("flare_gun", BazaarContentClass.RARITY_GOLD)
	var heal_source: ItemDataClass = _create_item("hot_springs", BazaarContentClass.RARITY_GOLD)
	var golf: ItemDataClass = _create_item("golf_clubs", BazaarContentClass.RARITY_GOLD)
	_assert_true(inv2.place_item(ritual, 0), "places Ritual Dagger")
	_assert_true(inv2.place_item(infernal, 1), "places Infernal Greatsword")
	_assert_true(inv2.place_item(soul, 4), "places Soul of the District")
	_assert_true(inv2.place_item(flare, 6), "places Flare Gun")
	_assert_true(inv2.place_item(golf, 8), "places Golf Clubs")
	_start_battle(inv2, "P2B-5 Direct Runtime")
	_game_manager().set("player_health", 60)
	_execute_cooldown(ritual)
	_execute_cooldown(infernal)
	_execute_cooldown(flare)
	_execute_cooldown(soul)
	_execute_after_cooldown(soul)
	_assert_eq(_game_manager().get("selected_hero").current_shield, 60.0, "Soul of the District shields equal to current Health")
	_execute_cooldown(heal_source)
	_assert_float_eq(_player_status(EffectDefinitionClass.EFFECT_REGENERATION), 2.0, "Ritual Dagger gains Regen equal to its Damage")
	_assert_float_eq(_enemy_status(EffectDefinitionClass.EFFECT_BURN), 11.0, "Infernal Greatsword and Flare Gun apply source-backed Burn")
	_assert_float_eq(_item_runtime_bonus(golf, EffectDefinitionClass.EFFECT_DAMAGE), 30.0, "Gold Golf Clubs gains +30 Damage when you Heal")
	_battle_system().call("end_battle")

func _implemented_reason_keys() -> Array[String]:
	return [
		"item:ethergy_conduit:unsupported_item_effect:ethergy_conduit:charge",
		"item:eye_of_the_colossus:unsupported_item_effect:eye_of_the_colossus:charge",
		"item:ice_cream_truck:unsupported_item_effect:ice_cream_truck:charge",
		"item:iceberg:unsupported_item_effect:iceberg:freeze",
		"item:refractor:unsupported_item_effect:refractor:freeze",
		"item:soul_of_the_district:unsupported_item_effect:soul_of_the_district:shield",
		"item:soul_of_the_district:unsupported_item_effect:soul_of_the_district:damage",
		"item:flare_gun:unsupported_item_effect:flare_gun:burn",
		"item:infernal_greatsword:unsupported_item_effect:infernal_greatsword:burn",
		"item:tripwire:unsupported_item_effect:tripwire:slow",
		"item:holsters:unsupported_item_effect:holsters:haste",
		"item:fire_bomb:unsupported_item_effect:fire_bomb:reload",
		"item:ice_bomb:unsupported_item_effect:ice_bomb:reload",
		"item:ritual_dagger:unsupported_item_effect:ritual_dagger:regeneration",
		"item:golf_clubs:unsupported_item_effect:golf_clubs:runtime_bonus",
		"item:ritual_dagger:unsupported_item_effect:ritual_dagger:runtime_bonus",
		"item:void_shield:unsupported_item_effect:void_shield:runtime_bonus",
	]

func _start_battle(inv: LinearInventoryClass, monster_name: String, hp: int = 1000) -> MonsterDataClass:
	var hero = BazaarContentClass.create_mak_hero()
	var game_manager: Node = _game_manager()
	game_manager.call("reset_stats")
	game_manager.set("selected_hero", hero)
	game_manager.set("player_health", hero.max_hp)
	var monster: MonsterDataClass = MonsterDataClass.new()
	monster.monster_name = monster_name
	monster.max_hp = hp
	monster.current_hp = hp
	monster.monster_items = []
	monster.monster_skills = []
	_battle_system().call("start_battle", monster, inv)
	return monster

func _execute_cooldown(item: ItemDataClass) -> Dictionary:
	var result: Dictionary = _battle_system().call("_execute_item_effect_definitions", item, {}, "before_consume")
	var events: Array[Dictionary] = []
	for event_variant in result.get("events", []):
		if event_variant is Dictionary:
			events.append(event_variant)
	_battle_system().call("_process_reactive_effect_events", events)
	return result

func _execute_after_cooldown(item: ItemDataClass) -> Dictionary:
	return _battle_system().call("_execute_item_effect_definitions", item, {}, "after_consume")

func _process_event(event_name: String, source_item: ItemDataClass, extra: Dictionary = {}) -> void:
	var event_data: Dictionary = _battle_system().call("_make_effect_event", event_name, source_item, extra)
	var events: Array[Dictionary] = [event_data]
	_battle_system().call("_process_reactive_effect_events", events)

func _create_item(item_id: String, rarity: int = BazaarContentClass.RARITY_GOLD) -> ItemDataClass:
	var item: ItemDataClass = BazaarContentClass.create_item(item_id, rarity)
	_assert_true(item != null, "creates %s" % item_id)
	if item != null:
		item.effects = EffectDefinitionClass.build_item_effects(item)
		item.effect_warnings = EffectDefinitionClass.collect_item_warnings(item, item.effects)
	return item

func _definition_ids(item: ItemDataClass) -> Array[String]:
	var ids: Array[String] = []
	if item == null:
		return ids
	for definition in item.effects:
		ids.append(str((definition as Dictionary).get("id", "")))
	return ids

func _item_runtime_bonus(item: ItemDataClass, key: String) -> float:
	return float(_battle_system().call("_get_item_runtime_bonus", item, key))

func _enemy_status(status_type: String) -> float:
	return float(_battle_system().call("_get_status_total", "enemy", status_type))

func _player_status(status_type: String) -> float:
	return float(_battle_system().call("_get_status_total", "self", status_type))

func _battle_system() -> Node:
	return get_node("/root/BattleSystem")

func _game_manager() -> Node:
	return get_node("/root/GameManager")

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
