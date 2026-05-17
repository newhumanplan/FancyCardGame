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
		print("== tests/test_full_content_parity_p2b_direct_status_families.gd ==")
		test_p2b3_reasons_are_resolved()
		test_p2b3_definitions_are_explicit()
		test_direct_status_amounts()
		test_charge_haste_reload_selectors()
		_print_summary()

func test_p2b3_reasons_are_resolved() -> void:
	var report: Dictionary = BazaarContentClass.get_all_monster_parity_report()
	var reason_counts: Dictionary = report.get("grouped_missing_mechanics", {}).get("reason_counts", {})
	for reason in [
		"item:atm:unsupported_item_effect:atm:shield",
		"item:cryosleeve:unsupported_item_effect:cryosleeve:freeze",
		"item:dooltron:unsupported_item_effect:dooltron:freeze",
		"item:dragon_whelp:unsupported_item_effect:dragon_whelp:burn",
		"item:grn_w4sp:unsupported_item_effect:grn_w4sp:freeze",
		"item:hogwash:unsupported_item_effect:hogwash:heal",
		"item:lighthouse:unsupported_item_effect:lighthouse:charge",
		"item:necronomicon:unsupported_item_effect:necronomicon:charge",
		"item:nitrogen_hammer:unsupported_item_effect:nitrogen_hammer:charge",
		"item:old_saltclaw:unsupported_item_effect:old_saltclaw:damage",
		"item:pendulum:unsupported_item_effect:pendulum:charge",
		"item:red_f1r3fly:unsupported_item_effect:red_f1r3fly:charge",
		"item:robe:unsupported_item_effect:robe:charge",
		"item:rocket_boots:unsupported_item_effect:rocket_boots:haste",
		"item:slumbering_primordial:unsupported_item_effect:slumbering_primordial:charge",
		"item:slumbering_primordial:unsupported_item_effect:slumbering_primordial:freeze",
		"item:solar_farm:unsupported_item_effect:solar_farm:charge",
		"item:sunlight_spear:unsupported_item_effect:sunlight_spear:burn",
		"item:sunlight_spear:unsupported_item_effect:sunlight_spear:damage",
		"item:sunlight_spear:unsupported_item_effect:sunlight_spear:regeneration",
		"item:textiles:unsupported_item_effect:textiles:heal",
		"item:torpedo:unsupported_item_effect:torpedo:reload",
		"item:tortuga:unsupported_item_effect:tortuga:charge",
		"item:tortuga:unsupported_item_effect:tortuga:haste",
		"item:trebuchet:unsupported_item_effect:trebuchet:charge",
		"item:void_shield:unsupported_item_effect:void_shield:shield",
		"item:weather_glass:unsupported_item_effect:weather_glass:freeze",
		"item:weather_glass:unsupported_item_effect:weather_glass:slow",
		"item:ylw_m4nt1s:unsupported_item_effect:ylw_m4nt1s:charge",
		"item:yo_yo:unsupported_item_effect:yo_yo:charge",
		"item:zoarcid:unsupported_item_effect:zoarcid:charge",
	]:
		_assert_true(not reason_counts.has(reason), "P2B-3 residual reason resolved: %s" % reason)

func test_p2b3_definitions_are_explicit() -> void:
	var expected_ids := {
		"atm": ["atm_on_cooldown_ready_shield"],
		"cryosleeve": ["cryosleeve_on_cooldown_ready_freeze", "cryosleeve_on_enemy_status_applied_shield"],
		"dragon_whelp": ["dragon_whelp_on_cooldown_ready_burn"],
		"hogwash": ["hogwash_on_cooldown_ready_heal"],
		"lighthouse": ["lighthouse_on_enemy_status_applied_charge"],
		"necronomicon": ["necronomicon_on_item_used_charge"],
		"old_saltclaw": ["old_saltclaw_on_cooldown_ready_damage"],
		"pendulum": ["pendulum_on_item_used_charge"],
		"rocket_boots": ["rocket_boots_on_cooldown_ready_haste"],
		"sunlight_spear": ["sunlight_spear_on_cooldown_ready_regeneration", "sunlight_spear_on_cooldown_ready_burn", "sunlight_spear_on_cooldown_ready_damage"],
		"textiles": ["textiles_on_cooldown_ready_heal"],
		"torpedo": ["torpedo_on_item_used_reload"],
		"tortuga": ["tortuga_on_cooldown_ready_haste", "tortuga_on_tag_used_charge"],
		"void_shield": ["void_shield_on_cooldown_ready_shield"],
	}
	for item_id in expected_ids.keys():
		var item: ItemDataClass = _create_item(str(item_id), BazaarContentClass.RARITY_GOLD)
		var ids: Array[String] = _definition_ids(item)
		for definition_id in expected_ids[item_id]:
			_assert_true(ids.has(str(definition_id)), "%s has %s" % [item_id, str(definition_id)])

func test_direct_status_amounts() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var atm: ItemDataClass = _create_item("atm", BazaarContentClass.RARITY_GOLD)
	var dragon_whelp: ItemDataClass = _create_item("dragon_whelp", BazaarContentClass.RARITY_GOLD)
	var hogwash: ItemDataClass = _create_item("hogwash", BazaarContentClass.RARITY_GOLD)
	var textiles: ItemDataClass = _create_item("textiles", BazaarContentClass.RARITY_GOLD)
	var void_shield: ItemDataClass = _create_item("void_shield", BazaarContentClass.RARITY_DIAMOND)
	_assert_true(inv.place_item(atm, 0), "places ATM")
	_assert_true(inv.place_item(dragon_whelp, 2), "places Dragon Whelp")
	_assert_true(inv.place_item(hogwash, 3), "places Hogwash")
	_assert_true(inv.place_item(textiles, 6), "places Textiles")
	_assert_true(inv.place_item(void_shield, 8), "places Void Shield")
	var monster: MonsterDataClass = _start_battle(inv, "P2B-3 Direct Status Test", 1000)
	_game_manager().set("income", 7)
	_game_manager().set("player_health", 60)
	_selected_hero().current_shield = 30.0
	_battle_system().call("_add_status_to_state", _battle_system().get("enemy_status_state"), EffectDefinitionClass.EFFECT_BURN, 11.0)

	_execute_cooldown(atm)
	_assert_float_eq(_selected_hero().current_shield, 51.0, "Gold ATM shields for 3x income")
	_execute_cooldown(dragon_whelp)
	_assert_float_eq(_enemy_status(EffectDefinitionClass.EFFECT_BURN), 12.0, "Dragon Whelp Burns equal to its Damage")
	_execute_cooldown(hogwash)
	_assert_eq(_game_manager().get("player_health"), 70, "Hogwash heals 10 percent max health")
	_execute_cooldown(textiles)
	_assert_eq(_game_manager().get("player_health"), 100, "Textiles heals equal to current Shield and caps at max health")
	var shield_before_void: float = _selected_hero().current_shield
	_execute_cooldown(void_shield)
	var expected_void_shield: float = minf(shield_before_void + _enemy_status(EffectDefinitionClass.EFFECT_BURN), float(_selected_hero().max_hp))
	_assert_float_eq(_selected_hero().current_shield, expected_void_shield, "Void Shield shields equal to enemy Burn")
	_battle_system().call("end_battle")

	var inv2: LinearInventoryClass = LinearInventoryClass.new()
	var sunlight_spear: ItemDataClass = _create_item("sunlight_spear", BazaarContentClass.RARITY_GOLD)
	var old_saltclaw: ItemDataClass = _create_item("old_saltclaw", BazaarContentClass.RARITY_GOLD)
	_assert_true(inv2.place_item(sunlight_spear, 0), "places Sunlight Spear")
	_assert_true(inv2.place_item(old_saltclaw, 3), "places Old Saltclaw")
	var monster2: MonsterDataClass = _start_battle(inv2, "P2B-3 Sunlight Spear Test", 1000)
	_battle_system().call("_add_status_to_state", _battle_system().get("player_status_state"), EffectDefinitionClass.EFFECT_REGENERATION, 5.0)
	_battle_system().call("_add_status_to_state", _battle_system().get("player_status_state"), EffectDefinitionClass.EFFECT_BURN, 3.0)
	_battle_system().call("_add_status_to_state", _battle_system().get("enemy_status_state"), EffectDefinitionClass.EFFECT_BURN, 7.0)
	_execute_cooldown(sunlight_spear)
	_assert_float_eq(_player_status(EffectDefinitionClass.EFFECT_REGENERATION), 17.0, "Gold Sunlight Spear grants source Regeneration")
	_assert_float_eq(_enemy_status(EffectDefinitionClass.EFFECT_BURN), 24.0, "Sunlight Spear Burns equal to player Regeneration after grant")
	_assert_eq(monster2.current_hp, 956, "Sunlight Spear damages for player Regen plus both Burn totals after its Burn lands")
	_execute_cooldown(old_saltclaw)
	_assert_eq(monster2.current_hp, 946, "Old Saltclaw deals source text Damage 10")
	_battle_system().call("end_battle")

func test_charge_haste_reload_selectors() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var fang_left: ItemDataClass = _create_item("fang")
	var pendulum: ItemDataClass = _create_item("pendulum", BazaarContentClass.RARITY_DIAMOND)
	var fang_right: ItemDataClass = _create_charged_item("fang")
	_assert_true(inv.place_item(fang_left, 0), "places left adjacent source")
	_assert_true(inv.place_item(pendulum, 1), "places Pendulum")
	_assert_true(inv.place_item(fang_right, 3), "places right adjacent target")
	_start_battle(inv, "P2B-3 Pendulum Test")
	fang_right.current_cooldown = 10.0
	_process_event(EffectDefinitionClass.TRIGGER_ON_ITEM_USED, fang_left)
	_assert_float_eq(fang_right.current_cooldown, 8.0, "Diamond Pendulum charges the other adjacent item")
	_battle_system().call("end_battle")

	var inv2: LinearInventoryClass = LinearInventoryClass.new()
	var rocket_boots: ItemDataClass = _create_item("rocket_boots", BazaarContentClass.RARITY_GOLD)
	var left_item: ItemDataClass = _create_item("fang")
	var right_item: ItemDataClass = _create_item("fang")
	_assert_true(inv2.place_item(left_item, 0), "places left item")
	_assert_true(inv2.place_item(rocket_boots, 1), "places Rocket Boots")
	_assert_true(inv2.place_item(right_item, 3), "places right item")
	_start_battle(inv2, "P2B-3 Rocket Boots Test")
	left_item.current_cooldown = 6.0
	right_item.current_cooldown = 6.0
	_execute_cooldown(rocket_boots)
	_assert_float_eq(left_item.current_cooldown, 3.0, "Gold Rocket Boots Hastes left adjacent item")
	_assert_float_eq(right_item.current_cooldown, 3.0, "Gold Rocket Boots Hastes right adjacent item")
	_battle_system().call("end_battle")

	var inv3: LinearInventoryClass = LinearInventoryClass.new()
	var torpedo: ItemDataClass = _create_item("torpedo", BazaarContentClass.RARITY_GOLD)
	var electric_eels: ItemDataClass = _create_item("electric_eels")
	_assert_true(inv3.place_item(torpedo, 0), "places Torpedo")
	_assert_true(inv3.place_item(electric_eels, 3), "places Large Aquatic source")
	_start_battle(inv3, "P2B-3 Torpedo Test")
	torpedo.current_ammo = 0
	_process_event(EffectDefinitionClass.TRIGGER_ON_ITEM_USED, electric_eels)
	_assert_eq(torpedo.current_ammo, 1, "Torpedo reloads 1 Ammo when another Large Aquatic item is used")
	_battle_system().call("end_battle")

	var inv4: LinearInventoryClass = LinearInventoryClass.new()
	var tortuga: ItemDataClass = _create_charged_item("tortuga")
	var friend: ItemDataClass = _create_item("piranha")
	var other: ItemDataClass = _create_item("fang")
	_assert_true(inv4.place_item(tortuga, 0), "places Tortuga")
	_assert_true(inv4.place_item(friend, 3), "places Friend")
	_assert_true(inv4.place_item(other, 4), "places other item")
	_start_battle(inv4, "P2B-3 Tortuga Test")
	friend.current_cooldown = 5.0
	other.current_cooldown = 5.0
	_execute_cooldown(tortuga)
	_assert_float_eq(friend.current_cooldown, 4.0, "Tortuga Hastes other Friend item")
	_assert_float_eq(other.current_cooldown, 4.0, "Tortuga Hastes other non-Friend item")
	tortuga.current_cooldown = 10.0
	_process_event(EffectDefinitionClass.TRIGGER_ON_TAG_USED, friend)
	_assert_float_eq(tortuga.current_cooldown, 8.0, "Tortuga charges when another Friend is used")
	_battle_system().call("end_battle")

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

func _process_event(event_name: String, source_item: ItemDataClass, extra: Dictionary = {}) -> void:
	var event_data: Dictionary = _battle_system().call("_make_effect_event", event_name, source_item, extra)
	var events: Array[Dictionary] = [event_data]
	_battle_system().call("_process_reactive_effect_events", events)

func _create_charged_item(item_id: String) -> ItemDataClass:
	var item: ItemDataClass = _create_item(item_id, BazaarContentClass.RARITY_GOLD)
	item.current_cooldown = 10.0
	return item

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

func _selected_hero():
	return _game_manager().get("selected_hero")

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
