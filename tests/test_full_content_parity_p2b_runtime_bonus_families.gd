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
		print("== tests/test_full_content_parity_p2b_runtime_bonus_families.gd ==")
		test_p2b4_runtime_bonus_reasons_are_reduced()
		test_p2b4_definition_anchors_exist()
		test_battle_start_runtime_bonus_families()
		test_cooldown_and_item_use_runtime_bonus_families()
		test_status_runtime_bonus_families()
		test_haste_runtime_bonus_families()
		_print_summary()

func test_p2b4_runtime_bonus_reasons_are_reduced() -> void:
	var report: Dictionary = BazaarContentClass.get_all_monster_parity_report()
	var reason_counts: Dictionary = report.get("grouped_missing_mechanics", {}).get("reason_counts", {})
	for reason in _implemented_reason_keys():
		_assert_true(not reason_counts.has(reason), "P2B-4 runtime_bonus reason resolved: %s" % reason)

func test_p2b4_definition_anchors_exist() -> void:
	var expected_ids := {
		"biomerge_arm": ["biomerge_arm_on_battle_start_left_item_crit", "biomerge_arm_on_battle_start_ammo"],
		"bill_dozer": ["bill_dozer_on_tag_used_runtime_bonus"],
		"death_caps": ["death_caps_on_cooldown_ready_runtime_bonus"],
		"dishwasher": ["dishwasher_on_cooldown_ready_runtime_bonus"],
		"ganjo": ["ganjo_on_battle_start_weapon_runtime_bonus", "ganjo_on_battle_start_heal_runtime_bonus", "ganjo_on_battle_start_shield_runtime_bonus"],
		"grindstone": ["grindstone_on_battle_start_runtime_bonus"],
		"honing_steel": ["honing_steel_on_battle_start_runtime_bonus"],
		"ice_pick": ["ice_pick_on_enemy_status_applied_runtime_bonus"],
		"jitte": ["jitte_on_enemy_status_applied_runtime_bonus"],
		"mantis_shrimp": ["mantis_shrimp_on_enemy_status_applied_damage_runtime_bonus", "mantis_shrimp_on_enemy_status_applied_burn_runtime_bonus"],
		"nitrogen_hammer": ["nitrogen_hammer_on_enemy_status_applied_runtime_bonus"],
		"orbital_polisher": ["orbital_polisher_on_battle_start_adjacent_damage_runtime_bonus", "orbital_polisher_on_battle_start_adjacent_shield_runtime_bonus"],
		"runic_great_axe": ["runic_great_axe_on_battle_start_runtime_bonus"],
		"torpedo": ["torpedo_on_item_used_runtime_bonus"],
		"wanted_poster": ["wanted_poster_on_battle_start_runtime_bonus"],
	}
	for item_id in expected_ids.keys():
		var ids: Array[String] = _definition_ids(_create_item(str(item_id), BazaarContentClass.RARITY_GOLD))
		for definition_id in expected_ids[item_id]:
			_assert_true(ids.has(str(definition_id)), "%s has %s" % [str(item_id), str(definition_id)])

func test_battle_start_runtime_bonus_families() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var grindstone: ItemDataClass = _create_item("grindstone", BazaarContentClass.RARITY_GOLD)
	var left_weapon: ItemDataClass = _create_item("fang")
	var honing: ItemDataClass = _create_item("honing_steel", BazaarContentClass.RARITY_GOLD)
	var right_weapon: ItemDataClass = _create_item("fang")
	var salt: ItemDataClass = _create_item("salt", BazaarContentClass.RARITY_GOLD)
	var adjacent_item: ItemDataClass = _create_item("fang")
	_assert_true(inv.place_item(left_weapon, 0), "places left Weapon")
	_assert_true(inv.place_item(grindstone, 1), "places Grindstone")
	_assert_true(inv.place_item(honing, 3), "places Honing Steel")
	_assert_true(inv.place_item(right_weapon, 4), "places right Weapon")
	_assert_true(inv.place_item(salt, 6), "places Salt")
	_assert_true(inv.place_item(adjacent_item, 7), "places adjacent item")
	_start_battle(inv, "P2B-4 Battle Start Runtime")
	_assert_float_eq(_item_runtime_bonus(left_weapon, EffectDefinitionClass.EFFECT_DAMAGE), 20.0, "Gold Grindstone gives left Weapon +20 Damage")
	_assert_float_eq(_item_runtime_bonus(right_weapon, EffectDefinitionClass.EFFECT_DAMAGE), 16.0, "Gold Honing Steel gives right Weapon +16 Damage")
	_assert_float_eq(_item_runtime_bonus(adjacent_item, "crit_rate"), 15.0, "Gold Salt gives adjacent item +15 Crit Chance")
	_battle_system().call("end_battle")

func test_cooldown_and_item_use_runtime_bonus_families() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var death_caps: ItemDataClass = _create_item("death_caps", BazaarContentClass.RARITY_GOLD)
	var poison_item: ItemDataClass = _create_item("venom")
	_assert_true(inv.place_item(death_caps, 0), "places Death Caps")
	_assert_true(inv.place_item(poison_item, 5), "places Poison item")
	_start_battle(inv, "P2B-4 Death Caps Runtime")
	_execute_cooldown(death_caps)
	_assert_float_eq(_item_runtime_bonus(poison_item, EffectDefinitionClass.EFFECT_POISON), 4.0, "Gold Death Caps gives Poison items +4 Poison")
	_battle_system().call("end_battle")

	var inv2: LinearInventoryClass = LinearInventoryClass.new()
	var dishwasher: ItemDataClass = _create_item("dishwasher", BazaarContentClass.RARITY_GOLD)
	var weapon: ItemDataClass = _create_item("fang")
	_assert_true(inv2.place_item(dishwasher, 0), "places Dishwasher")
	_assert_true(inv2.place_item(weapon, 5), "places Weapon")
	_start_battle(inv2, "P2B-4 Dishwasher Runtime")
	_execute_cooldown(dishwasher)
	_assert_float_eq(_item_runtime_bonus(weapon, EffectDefinitionClass.EFFECT_DAMAGE), 40.0, "Gold Dishwasher gives Weapons +40 Damage")
	_battle_system().call("end_battle")

	var inv3: LinearInventoryClass = LinearInventoryClass.new()
	var torpedo: ItemDataClass = _create_item("torpedo", BazaarContentClass.RARITY_GOLD)
	var aquatic: ItemDataClass = _create_item("electric_eels")
	_assert_true(inv3.place_item(torpedo, 0), "places Torpedo")
	_start_battle(inv3, "P2B-4 Torpedo Runtime")
	_process_event(EffectDefinitionClass.TRIGGER_ON_ITEM_USED, aquatic)
	_assert_true(_item_runtime_bonus(torpedo, EffectDefinitionClass.EFFECT_DAMAGE) > 0.0, "Torpedo gains Damage when Aquatic source is used")
	_battle_system().call("end_battle")

func test_status_runtime_bonus_families() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var jitte: ItemDataClass = _create_item("jitte", BazaarContentClass.RARITY_GOLD)
	var ice_pick: ItemDataClass = _create_item("ice_pick", BazaarContentClass.RARITY_GOLD)
	var mantis: ItemDataClass = _create_item("mantis_shrimp", BazaarContentClass.RARITY_GOLD)
	var nitrogen: ItemDataClass = _create_item("nitrogen_hammer", BazaarContentClass.RARITY_GOLD)
	var peppers: ItemDataClass = _create_item("pickled_peppers", BazaarContentClass.RARITY_GOLD)
	var source: ItemDataClass = _create_item("weather_machine", BazaarContentClass.RARITY_GOLD)
	_assert_true(inv.place_item(jitte, 0), "places Jitte")
	_assert_true(inv.place_item(ice_pick, 1), "places Ice Pick")
	_assert_true(inv.place_item(mantis, 3), "places Mantis Shrimp")
	_assert_true(inv.place_item(nitrogen, 5), "places Nitrogen Hammer")
	_assert_true(inv.place_item(peppers, 8), "places Pickled Peppers")
	_start_battle(inv, "P2B-4 Status Runtime")
	_process_event(EffectDefinitionClass.TRIGGER_ON_ENEMY_STATUS_APPLIED, source, {"status_type": EffectDefinitionClass.EFFECT_SLOW})
	_process_event(EffectDefinitionClass.TRIGGER_ON_ENEMY_STATUS_APPLIED, source, {"status_type": EffectDefinitionClass.EFFECT_FREEZE})
	_process_event(EffectDefinitionClass.TRIGGER_ON_ENEMY_STATUS_APPLIED, source, {"status_type": EffectDefinitionClass.EFFECT_BURN})
	_assert_float_eq(_item_runtime_bonus(jitte, EffectDefinitionClass.EFFECT_DAMAGE), 20.0, "Gold Jitte gains +20 Damage on Slow")
	_assert_float_eq(_item_runtime_bonus(mantis, EffectDefinitionClass.EFFECT_DAMAGE), 20.0, "Gold Mantis Shrimp gains +20 Damage on Slow")
	_assert_float_eq(_item_runtime_bonus(mantis, EffectDefinitionClass.EFFECT_BURN), 6.0, "Gold Mantis Shrimp gains +6 Burn on Slow")
	_assert_float_eq(_item_runtime_bonus(ice_pick, EffectDefinitionClass.EFFECT_DAMAGE), 20.0, "Gold Ice Pick gains +20 Damage on Freeze")
	_assert_float_eq(_item_runtime_bonus(nitrogen, EffectDefinitionClass.EFFECT_DAMAGE), 100.0, "Gold Nitrogen Hammer gains +100 Damage on Freeze")
	_assert_float_eq(_item_runtime_bonus(peppers, EffectDefinitionClass.EFFECT_BURN), 5.0, "Gold Pickled Peppers gains +5 Burn on Burn")
	_battle_system().call("end_battle")

func test_haste_runtime_bonus_families() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var rocket_boots: ItemDataClass = _create_item("rocket_boots", BazaarContentClass.RARITY_GOLD)
	var cosmic: ItemDataClass = _create_item("cosmic_amulet", BazaarContentClass.RARITY_GOLD)
	var thermal: ItemDataClass = _create_item("thermal_lance", BazaarContentClass.RARITY_GOLD)
	var sharkray: ItemDataClass = _create_item("sharkray", BazaarContentClass.RARITY_GOLD)
	_assert_true(inv.place_item(cosmic, 0), "places Cosmic Amulet")
	_assert_true(inv.place_item(rocket_boots, 1), "places Rocket Boots")
	_assert_true(inv.place_item(thermal, 3), "places Thermal Lance")
	_assert_true(inv.place_item(sharkray, 7), "places Sharkray")
	_start_battle(inv, "P2B-4 Haste Runtime")
	_execute_cooldown(rocket_boots)
	_assert_float_eq(_item_runtime_bonus(cosmic, "crit_rate"), 3.0, "Gold Cosmic Amulet gives itself +3 Crit when Hasted")
	_assert_float_eq(_item_runtime_bonus(rocket_boots, "crit_rate"), 3.0, "Gold Cosmic Amulet gives all items +3 Crit when Hasted")
	_assert_float_eq(_item_runtime_bonus(thermal, EffectDefinitionClass.EFFECT_BURN), 10.0, "Gold Thermal Lance gains +10 Burn when Hasted")
	_assert_float_eq(_item_runtime_bonus(sharkray, EffectDefinitionClass.EFFECT_DAMAGE), 0.0, "Non-adjacent Sharkray does not gain Haste from Rocket Boots")
	_battle_system().call("end_battle")

func _implemented_reason_keys() -> Array[String]:
	return [
		"item:atm:unsupported_item_effect:atm:runtime_bonus",
		"item:bill_dozer:unsupported_item_effect:bill_dozer:runtime_bonus",
		"item:biomerge_arm:unsupported_item_effect:biomerge_arm:runtime_bonus",
		"item:citrus:unsupported_item_effect:citrus:runtime_bonus",
		"item:cosmic_amulet:unsupported_item_effect:cosmic_amulet:runtime_bonus",
		"item:death_caps:unsupported_item_effect:death_caps:runtime_bonus",
		"item:dishwasher:unsupported_item_effect:dishwasher:runtime_bonus",
		"item:dog:unsupported_item_effect:dog:runtime_bonus",
		"item:ethergy_conduit:unsupported_item_effect:ethergy_conduit:runtime_bonus",
		"item:forgotten_god:unsupported_item_effect:forgotten_god:runtime_bonus",
		"item:friendly_doll:unsupported_item_effect:friendly_doll:runtime_bonus",
		"item:ganjo:unsupported_item_effect:ganjo:runtime_bonus",
		"item:grindstone:unsupported_item_effect:grindstone:runtime_bonus",
		"item:holsters:unsupported_item_effect:holsters:runtime_bonus",
		"item:honing_steel:unsupported_item_effect:honing_steel:runtime_bonus",
		"item:ice_pick:unsupported_item_effect:ice_pick:runtime_bonus",
		"item:improvised_bludgeon:unsupported_item_effect:improvised_bludgeon:runtime_bonus",
		"item:infernal_greatsword:unsupported_item_effect:infernal_greatsword:runtime_bonus",
		"item:jitte:unsupported_item_effect:jitte:runtime_bonus",
		"item:mantis_shrimp:unsupported_item_effect:mantis_shrimp:runtime_bonus",
		"item:myrrh:unsupported_item_effect:myrrh:runtime_bonus",
		"item:necronomicon:unsupported_item_effect:necronomicon:runtime_bonus",
		"item:nitrogen_hammer:unsupported_item_effect:nitrogen_hammer:runtime_bonus",
		"item:old_saltclaw:unsupported_item_effect:old_saltclaw:runtime_bonus",
		"item:orbital_polisher:unsupported_item_effect:orbital_polisher:runtime_bonus",
		"item:pickled_peppers:unsupported_item_effect:pickled_peppers:runtime_bonus",
		"item:red_piggles_r:unsupported_item_effect:red_piggles_r:runtime_bonus",
		"item:red_piggles_x:unsupported_item_effect:red_piggles_x:runtime_bonus",
		"item:runic_great_axe:unsupported_item_effect:runic_great_axe:runtime_bonus",
		"item:salamander_pup:unsupported_item_effect:salamander_pup:runtime_bonus",
		"item:salt:unsupported_item_effect:salt:runtime_bonus",
		"item:sharkclaws:unsupported_item_effect:sharkclaws:runtime_bonus",
		"item:sharkray:unsupported_item_effect:sharkray:runtime_bonus",
		"item:silencer:unsupported_item_effect:silencer:runtime_bonus",
		"item:silk_scarf:unsupported_item_effect:silk_scarf:runtime_bonus",
		"item:slumbering_primordial:unsupported_item_effect:slumbering_primordial:runtime_bonus",
		"item:solar_farm:unsupported_item_effect:solar_farm:runtime_bonus",
		"item:sunlight_spear:unsupported_item_effect:sunlight_spear:runtime_bonus",
		"item:temporary_shelter:unsupported_item_effect:temporary_shelter:runtime_bonus",
		"item:thermal_lance:unsupported_item_effect:thermal_lance:runtime_bonus",
		"item:torpedo:unsupported_item_effect:torpedo:runtime_bonus",
		"item:tropical_island:unsupported_item_effect:tropical_island:runtime_bonus",
		"item:wanted_poster:unsupported_item_effect:wanted_poster:runtime_bonus",
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
