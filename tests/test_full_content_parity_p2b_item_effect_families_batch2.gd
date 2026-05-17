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
		print("== tests/test_full_content_parity_p2b_item_effect_families_batch2.gd ==")
		test_batch2_reasons_are_resolved()
		test_batch2_definitions_are_explicit()
		test_direct_damage_and_value_runtime_batch()
		test_freeze_slow_and_multicast_batch()
		test_charge_and_runtime_bonus_batch()
		_print_summary()

func test_batch2_reasons_are_resolved() -> void:
	var report: Dictionary = BazaarContentClass.get_all_monster_parity_report()
	var reason_counts: Dictionary = report.get("grouped_missing_mechanics", {}).get("reason_counts", {})
	for reason in [
		"item:bayonet:unsupported_item_effect:bayonet:damage",
		"item:crusher_claw:unsupported_item_effect:crusher_claw:damage",
		"item:crusher_claw:unsupported_item_effect:crusher_claw:runtime_bonus",
		"item:dragon_heart:unsupported_item_effect:dragon_heart:charge",
		"item:force_field:unsupported_item_effect:force_field:damage",
		"item:grn_w4sp:unsupported_item_effect:grn_w4sp:charge",
		"item:icebreaker:unsupported_item_effect:icebreaker:charge",
		"item:kinetic_cannon:unsupported_item_effect:kinetic_cannon:charge",
		"item:kinetic_cannon:unsupported_item_effect:kinetic_cannon:runtime_bonus",
		"item:powder_keg:unsupported_item_effect:powder_keg:damage",
		"item:powder_keg:unsupported_item_effect:powder_keg:charge",
		"item:pulse_rifle:unsupported_item_effect:pulse_rifle:multicast",
		"item:pulse_rifle:unsupported_item_effect:pulse_rifle:runtime_bonus",
		"item:runic_double_bow:unsupported_item_effect:runic_double_bow:multicast",
		"item:scythe:unsupported_item_effect:scythe:damage",
		"item:skillet:unsupported_item_effect:skillet:multicast",
		"item:skillet:unsupported_item_effect:skillet:runtime_bonus",
		"item:stopwatch:unsupported_item_effect:stopwatch:freeze",
		"item:the_boulder:unsupported_item_effect:the_boulder:damage",
		"item:tommoo_gun:unsupported_item_effect:tommoo_gun:damage",
		"item:turtle_shell:unsupported_item_effect:turtle_shell:charge",
		"item:turtle_shell:unsupported_item_effect:turtle_shell:runtime_bonus",
		"item:tusked_helm:unsupported_item_effect:tusked_helm:multicast",
		"item:weather_glass:unsupported_item_effect:weather_glass:multicast",
		"item:weather_glass:unsupported_item_effect:weather_glass:runtime_bonus",
		"item:weather_machine:unsupported_item_effect:weather_machine:freeze",
		"item:weather_machine:unsupported_item_effect:weather_machine:slow",
		"item:weights:unsupported_item_effect:weights:charge",
		"item:weights:unsupported_item_effect:weights:runtime_bonus",
	]:
		_assert_true(not reason_counts.has(reason), "P2B batch2 residual reason resolved: %s" % reason)

func test_batch2_definitions_are_explicit() -> void:
	var expected_ids := {
		"bayonet": ["bayonet_on_tag_used_damage"],
		"crusher_claw": ["crusher_claw_on_cooldown_ready_runtime_bonus", "crusher_claw_on_cooldown_ready_damage"],
		"dragon_heart": ["dragon_heart_on_enemy_status_applied_charge", "dragon_heart_on_tag_used_charge"],
		"force_field": ["force_field_on_cooldown_ready_damage"],
		"grn_w4sp": ["grn_w4sp_on_enemy_status_applied_charge"],
		"icebreaker": ["icebreaker_on_enemy_status_applied_charge"],
		"kinetic_cannon": ["kinetic_cannon_on_item_used_charge", "kinetic_cannon_on_item_used_runtime_bonus"],
		"powder_keg": ["powder_keg_on_cooldown_ready_damage", "powder_keg_on_enemy_status_applied_charge"],
		"pulse_rifle": ["pulse_rifle_on_cooldown_ready_adjacent_friend_multicast", "pulse_rifle_on_cooldown_ready_only_friend_multicast", "pulse_rifle_runtime_bonus_supported"],
		"runic_double_bow": ["runic_double_bow_on_cooldown_ready_multicast"],
		"scythe": ["scythe_on_cooldown_ready_damage"],
		"skillet": ["skillet_on_cooldown_ready_multicast", "skillet_runtime_bonus_supported"],
		"stopwatch": ["stopwatch_on_cooldown_ready_freeze_player_items", "stopwatch_on_cooldown_ready_freeze_enemy_items"],
		"the_boulder": ["the_boulder_on_cooldown_ready_damage"],
		"tommoo_gun": ["tommoo_gun_on_cooldown_ready_damage"],
		"turtle_shell": ["turtle_shell_on_battle_start_runtime_bonus", "turtle_shell_on_item_used_charge"],
		"tusked_helm": ["tusked_helm_on_cooldown_ready_multicast"],
		"weather_glass": ["weather_glass_on_cooldown_ready_multicast", "weather_glass_runtime_bonus_supported"],
		"weather_machine": ["weather_machine_on_cooldown_ready_freeze", "weather_machine_on_cooldown_ready_slow"],
		"weights": ["weights_on_battle_start_weapon_damage", "weights_on_battle_start_heal_item_heal", "weights_on_heal_charge"],
	}
	for item_id in expected_ids.keys():
		var item: ItemDataClass = _create_item(str(item_id), BazaarContentClass.RARITY_GOLD)
		var ids: Array[String] = _definition_ids(item)
		for definition_id in expected_ids[item_id]:
			_assert_true(ids.has(str(definition_id)), "%s has %s" % [item_id, str(definition_id)])

func test_direct_damage_and_value_runtime_batch() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var force_field: ItemDataClass = _create_item("force_field")
	var tommoo_gun: ItemDataClass = _create_item("tommoo_gun", BazaarContentClass.RARITY_DIAMOND)
	var crusher_claw: ItemDataClass = _create_item("crusher_claw")
	var turtle_shell: ItemDataClass = _create_item("turtle_shell")
	_assert_true(inv.place_item(force_field, 0), "places Force Field")
	_assert_true(inv.place_item(tommoo_gun, 3), "places Tommoo Gun")
	_assert_true(inv.place_item(crusher_claw, 4), "places Crusher Claw")
	_assert_true(inv.place_item(turtle_shell, 6), "places Shield item")
	var monster: MonsterDataClass = _start_battle(inv, "P2B Batch2 Direct Damage Test", 1000)
	_execute_cooldown(force_field)
	_assert_eq(monster.current_hp, 950, "Force Field deals damage equal to Shield after shielding")
	_execute_cooldown(tommoo_gun)
	_assert_eq(monster.current_hp, 900, "Tommoo Gun deals damage equal to Ammo")
	_execute_cooldown(crusher_claw)
	_assert_float_eq(_item_runtime_bonus(turtle_shell, EffectDefinitionClass.EFFECT_SHIELD), 16.0, "Crusher Claw adds Gold Shield on top of Turtle Shell's battle-start bonus")
	_assert_eq(monster.current_hp, 844, "Crusher Claw deals highest Shield item value after its buff")
	_battle_system().call("end_battle")

	var inv2: LinearInventoryClass = LinearInventoryClass.new()
	var scythe: ItemDataClass = _create_item("scythe")
	var powder_keg: ItemDataClass = _create_item("powder_keg")
	var the_boulder: ItemDataClass = _create_item("the_boulder")
	_assert_true(inv2.place_item(scythe, 0), "places Scythe")
	_assert_true(inv2.place_item(powder_keg, 2), "places Powder Keg")
	_assert_true(inv2.place_item(the_boulder, 4), "places The Boulder")
	var monster2: MonsterDataClass = _start_battle(inv2, "P2B Batch2 Percent Damage Test", 900)
	_execute_cooldown(scythe)
	_assert_eq(monster2.current_hp, 600, "Scythe deals one third enemy max health")
	_execute_cooldown(powder_keg)
	_assert_eq(monster2.current_hp, 285, "Gold Powder Keg deals 35 percent enemy max health")
	_execute_cooldown(the_boulder)
	_assert_eq(monster2.current_hp, 0, "The Boulder deals enemy max health and HP clamps at zero")
	_battle_system().call("end_battle")

func test_freeze_slow_and_multicast_batch() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var stopwatch: ItemDataClass = _create_item("stopwatch")
	var weather_machine: ItemDataClass = _create_item("weather_machine")
	var fang: ItemDataClass = _create_item("fang")
	_assert_true(inv.place_item(stopwatch, 0), "places Stopwatch")
	_assert_true(inv.place_item(weather_machine, 1), "places Weather Machine")
	_assert_true(inv.place_item(fang, 4), "places Fang")
	var monster_items: Array = [
		{"source_id": "fang", "name": "Enemy Fang", "size": "Small", "tags": ["Weapon"], "damage": 5, "cooldown": 10.0, "current_cooldown": 2.0},
	]
	_start_battle(inv, "P2B Batch2 Freeze Slow Test", 1000, monster_items)
	fang.current_cooldown = 2.0
	var enemy_cooldown_before: float = _monster_item_cooldown(0)
	_execute_cooldown(stopwatch)
	_assert_float_eq(fang.current_cooldown, 3.0, "Gold Stopwatch freezes player items for 1 second")
	_assert_float_eq(_monster_item_cooldown(0), enemy_cooldown_before + 1.0, "Gold Stopwatch freezes enemy items for 1 second")
	var enemy_cooldown_after_stopwatch: float = _monster_item_cooldown(0)
	_execute_cooldown(weather_machine)
	_assert_float_eq(_monster_item_cooldown(0), enemy_cooldown_after_stopwatch + 3.0, "Gold Weather Machine freezes 1 and slows 2 seconds")
	_battle_system().call("end_battle")

	var inv2: LinearInventoryClass = LinearInventoryClass.new()
	var pulse_rifle: ItemDataClass = _create_item("pulse_rifle")
	var piranha: ItemDataClass = _create_item("piranha")
	_assert_true(inv2.place_item(pulse_rifle, 0), "places Pulse Rifle")
	_assert_true(inv2.place_item(piranha, 2), "places only adjacent Friend")
	_start_battle(inv2, "P2B Batch2 Pulse Rifle Test")
	_assert_eq(_multicast_count(pulse_rifle), 3, "Pulse Rifle doubles adjacent Friend multicast if it is your only Friend")
	_battle_system().call("end_battle")

	var inv3: LinearInventoryClass = LinearInventoryClass.new()
	var skillet: ItemDataClass = _create_item("skillet")
	var black_pepper: ItemDataClass = _create_item("black_pepper")
	var hot_sauce: ItemDataClass = _create_item("hot_sauce")
	var runic_double_bow: ItemDataClass = _create_item("runic_double_bow")
	var tusked_helm: ItemDataClass = _create_item("tusked_helm")
	_assert_true(inv3.place_item(black_pepper, 0), "places left Food")
	_assert_true(inv3.place_item(skillet, 1), "places Skillet")
	_assert_true(inv3.place_item(hot_sauce, 3), "places right Food")
	_assert_true(inv3.place_item(runic_double_bow, 4), "places Runic Double Bow")
	_assert_true(inv3.place_item(tusked_helm, 6), "places Tusked Helm")
	_start_battle(inv3, "P2B Batch2 Static Multicast Test")
	_assert_eq(_multicast_count(skillet), 2, "Skillet gains +1 Multicast when both adjacent items are Food")
	_assert_eq(_multicast_count(runic_double_bow), 2, "Runic Double Bow Multicast: 2 is one extra cast")
	_assert_eq(_multicast_count(tusked_helm), 2, "Tusked Helm Multicast: 2 is one extra cast")
	_battle_system().call("end_battle")

	var inv4: LinearInventoryClass = LinearInventoryClass.new()
	var weather_glass: ItemDataClass = _create_item("weather_glass")
	var burn_item: ItemDataClass = _create_item("black_pepper")
	var poison_item: ItemDataClass = _create_item("poppy_field")
	_assert_true(inv4.place_item(weather_glass, 0), "places Weather Glass")
	_assert_true(inv4.place_item(burn_item, 2), "places Burn item")
	_assert_true(inv4.place_item(poison_item, 3), "places Poison item")
	_start_battle(inv4, "P2B Batch2 Weather Glass Test")
	_assert_eq(_multicast_count(weather_glass), 3, "Weather Glass gains +1 Multicast for each other Burn/Poison/Slow/Freeze item")
	_battle_system().call("end_battle")

func test_charge_and_runtime_bonus_batch() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var grn_w4sp: ItemDataClass = _create_charged_item("grn_w4sp")
	var dock_lines: ItemDataClass = _create_item("dock_lines")
	_assert_true(inv.place_item(dock_lines, 0), "places Slow adjacent source")
	_assert_true(inv.place_item(grn_w4sp, 2), "places GRN-W4SP adjacent to Slow source")
	_start_battle(inv, "P2B Batch2 GRN-W4SP Charge Test")
	grn_w4sp.current_cooldown = 10.0
	_process_event(EffectDefinitionClass.TRIGGER_ON_ENEMY_STATUS_APPLIED, dock_lines, {"status_type": EffectDefinitionClass.EFFECT_SLOW})
	_assert_float_eq(grn_w4sp.current_cooldown, 9.0, "GRN-W4SP charges from adjacent Slow")
	_battle_system().call("end_battle")

	var inv_charge: LinearInventoryClass = LinearInventoryClass.new()
	var dragon_heart: ItemDataClass = _create_charged_item("dragon_heart")
	var dragon_wing: ItemDataClass = _create_item("dragon_wing")
	var icebreaker: ItemDataClass = _create_charged_item("icebreaker")
	var fang: ItemDataClass = _create_item("fang")
	_assert_true(inv_charge.place_item(dragon_heart, 0), "places Dragon Heart")
	_assert_true(inv_charge.place_item(dragon_wing, 2), "places Flying item")
	_assert_true(inv_charge.place_item(icebreaker, 4), "places Icebreaker")
	_assert_true(inv_charge.place_item(fang, 6), "places Small item")
	_start_battle(inv_charge, "P2B Batch2 Dragon Icebreaker Charge Test")
	for charged_item in [dragon_heart, icebreaker]:
		(charged_item as ItemDataClass).current_cooldown = 10.0
	_process_event(EffectDefinitionClass.TRIGGER_ON_ENEMY_STATUS_APPLIED, fang, {"status_type": EffectDefinitionClass.EFFECT_BURN})
	_assert_float_eq(dragon_heart.current_cooldown, 8.0, "Dragon Heart charges from Burn")
	_process_event(EffectDefinitionClass.TRIGGER_ON_TAG_USED, dragon_wing)
	_assert_float_eq(dragon_heart.current_cooldown, 6.0, "Dragon Heart charges from Flying item use")
	_process_event(EffectDefinitionClass.TRIGGER_ON_ENEMY_STATUS_APPLIED, fang, {"status_type": EffectDefinitionClass.EFFECT_FREEZE})
	_assert_float_eq(icebreaker.current_cooldown, 7.0, "Gold Icebreaker charges from any Freeze")
	_battle_system().call("end_battle")

	var inv_kinetic: LinearInventoryClass = LinearInventoryClass.new()
	var kinetic_cannon: ItemDataClass = _create_charged_item("kinetic_cannon")
	var small_item: ItemDataClass = _create_item("fang")
	_assert_true(inv_kinetic.place_item(kinetic_cannon, 0), "places Kinetic Cannon")
	_assert_true(inv_kinetic.place_item(small_item, 3), "places Small trigger item")
	_start_battle(inv_kinetic, "P2B Batch2 Kinetic Cannon Charge Test")
	kinetic_cannon.current_cooldown = 10.0
	_process_event(EffectDefinitionClass.TRIGGER_ON_ITEM_USED, small_item)
	_assert_float_eq(kinetic_cannon.current_cooldown, 9.0, "Kinetic Cannon charges from Small item use")
	_assert_float_eq(_item_runtime_bonus(kinetic_cannon, EffectDefinitionClass.EFFECT_DAMAGE), 75.0, "Kinetic Cannon gains Gold Damage from Small item use")
	_battle_system().call("end_battle")

	var inv2: LinearInventoryClass = LinearInventoryClass.new()
	var turtle_shell: ItemDataClass = _create_charged_item("turtle_shell")
	var shield_item: ItemDataClass = _create_item("force_field")
	var non_weapon: ItemDataClass = _create_item("black_pepper")
	var weights: ItemDataClass = _create_charged_item("weights")
	var weapon: ItemDataClass = _create_item("fang")
	var heal_item: ItemDataClass = _create_item("bluenanas")
	_assert_true(inv2.place_item(turtle_shell, 0), "places Turtle Shell")
	_assert_true(inv2.place_item(shield_item, 2), "places Shield item")
	_assert_true(inv2.place_item(non_weapon, 5), "places non-Weapon")
	_assert_true(inv2.place_item(weights, 6), "places Weights")
	_assert_true(inv2.place_item(weapon, 8), "places Weapon")
	_assert_true(inv2.place_item(heal_item, 9), "places Heal item")
	_start_battle(inv2, "P2B Batch2 Runtime Bonus Test")
	turtle_shell.current_cooldown = 10.0
	weights.current_cooldown = 10.0
	_assert_float_eq(_item_runtime_bonus(shield_item, EffectDefinitionClass.EFFECT_SHIELD), 10.0, "Gold Turtle Shell gives Shield items +10 Shield for the fight")
	_assert_float_eq(_item_runtime_bonus(weapon, EffectDefinitionClass.EFFECT_DAMAGE), 20.0, "Gold Weights gives Weapons +20 Damage for the fight")
	_assert_float_eq(_item_runtime_bonus(heal_item, EffectDefinitionClass.EFFECT_HEAL), 20.0, "Gold Weights gives Heal items +20 Heal for the fight")
	_process_event(EffectDefinitionClass.TRIGGER_ON_ITEM_USED, non_weapon)
	_assert_float_eq(turtle_shell.current_cooldown, 9.0, "Turtle Shell charges when another non-Weapon item is used")
	_process_event(EffectDefinitionClass.TRIGGER_ON_HEAL, heal_item, {"overheal": true})
	_assert_float_eq(weights.current_cooldown, 9.0, "Weights charges on Over Heal")
	_battle_system().call("end_battle")

func _execute_cooldown(item: ItemDataClass) -> void:
	var before_result: Dictionary = _battle_system().call("_execute_item_effect_definitions", item, _root_context())
	if bool(before_result.get("executed", false)):
		for event_data in before_result.get("events", []):
			pass
	_battle_system().call("_execute_item_effect_definitions", item, _root_context(), "after_consume")

func _root_context() -> Dictionary:
	return {
		"crit_multiplier": 1.0,
		"burn_bonus": 0.0,
		"poison_bonus": 0.0,
		"lifesteal_rate": 0.0,
		"is_crit": false,
	}

func _start_battle(inv: LinearInventoryClass, monster_name: String, monster_hp: int = 1000, monster_items: Array = []) -> MonsterDataClass:
	var hero = BazaarContentClass.create_mak_hero()
	var game_manager: Node = _game_manager()
	game_manager.call("reset_stats")
	game_manager.set("selected_hero", hero)
	game_manager.set("player_health", hero.max_hp)
	var monster: MonsterDataClass = MonsterDataClass.new()
	monster.monster_name = monster_name
	monster.max_hp = monster_hp
	monster.current_hp = monster_hp
	monster.monster_items = monster_items.duplicate(true)
	monster.monster_skills = []
	_battle_system().call("start_battle", monster, inv)
	return monster

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

func _multicast_count(item: ItemDataClass) -> int:
	return int(_battle_system().call("_get_player_item_multicast_count", item))

func _monster_item_cooldown(index: int) -> float:
	var monster = _battle_system().get("current_monster")
	if monster == null:
		return 0.0
	return float(monster.monster_items[index].get("current_cooldown", 0.0))

func _item_runtime_bonus(item: ItemDataClass, key: String) -> float:
	return float(_battle_system().call("_get_item_runtime_bonus", item, key))

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
