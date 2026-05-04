extends Node

const BazaarContentClass = preload("res://scripts/data/bazaar_content.gd")
const EffectDefinitionClass = preload("res://scripts/data/effect_definition.gd")
const ItemDataClass = preload("res://scripts/data/item_data.gd")
const LinearInventoryClass = preload("res://scripts/data/linear_inventory.gd")
const MonsterDataClass = preload("res://scripts/data/monster_data.gd")

var _passed: int = 0
var _failed: int = 0

func _ready() -> void:
	print("== tests/test_item_effect_battle_triggers.gd ==")
	test_anchor_definitions_cover_p1c_items()
	test_revolver_crit_reloads_itself()
	test_grapeshot_reloads_when_another_ammo_item_is_used()
	test_satchel_root_reload_emits_reload_chain_regen()
	test_black_pepper_charges_adjacent_items_and_multicasts()
	test_lightbulb_charges_right_tech_item()
	test_tag_status_and_ammo_definition_mutations()
	test_reachable_warning_report_reduces_battle_trigger_families()
	print("SUMMARY: %d/%d passed" % [_passed, _passed + _failed])
	get_tree().quit(1 if _failed > 0 else 0)

func _battle_system() -> Node:
	return get_node("/root/BattleSystem")

func _game_manager() -> Node:
	return get_node("/root/GameManager")

func _create_item(item_id: String, rarity: int = BazaarContentClass.RARITY_BRONZE) -> ItemDataClass:
	var item: ItemDataClass = BazaarContentClass.create_item(item_id, rarity)
	_assert_not_null(item, "creates %s" % item_id)
	return item

func _definition_ids(item: ItemDataClass) -> Array[String]:
	var ids: Array[String] = []
	for definition in item.effects:
		ids.append(str((definition as Dictionary).get("id", "")))
	return ids

func _trace_has(definition_id: String) -> bool:
	for entry in _battle_system().call("get_effect_execution_trace"):
		if str(entry.get("definition_id", "")) == definition_id:
			return true
	return false

func _set_ready(item: ItemDataClass) -> void:
	item.current_cooldown = 0.0

func _set_blocked(item: ItemDataClass, cooldown: float = 8.0) -> void:
	item.current_cooldown = cooldown

func _process_events(events: Array[Dictionary]) -> void:
	_battle_system().call("_process_reactive_effect_events", events)

func _start_battle(inv: LinearInventoryClass, monster: MonsterDataClass = null, crit_chance: float = 0.0) -> MonsterDataClass:
	var hero = BazaarContentClass.create_mak_hero()
	hero.crit_chance = crit_chance
	var game_manager: Node = _game_manager()
	game_manager.call("reset_stats")
	game_manager.set("selected_hero", hero)
	game_manager.set("player_health", hero.max_hp)
	var battle_monster: MonsterDataClass = monster if monster != null else MonsterDataClass.new()
	if monster == null:
		battle_monster.monster_name = "P1C Trigger Test"
		battle_monster.max_hp = 500
		battle_monster.current_hp = 500
	_battle_system().call("start_battle", battle_monster, inv)
	return battle_monster

func test_anchor_definitions_cover_p1c_items() -> void:
	_assert_true(_definition_ids(_create_item("revolver")).has("revolver_on_crit_reload"), "Revolver has crit reload definition")
	_assert_true(_definition_ids(_create_item("grapeshot")).has("grapeshot_on_item_used_reload"), "Grapeshot has other-ammo reload definition")
	_assert_true(_definition_ids(_create_item("satchel")).has("satchel_on_cooldown_ready_reload"), "Satchel has root reload definition")
	_assert_true(_definition_ids(_create_item("satchel")).has("satchel_on_reload_regeneration"), "Satchel has reload-chain regen definition")
	_assert_true(_definition_ids(_create_item("black_pepper", BazaarContentClass.RARITY_SILVER)).has("black_pepper_on_cooldown_ready_charge"), "Black Pepper has adjacent charge definition")
	_assert_true(_definition_ids(_create_item("black_pepper", BazaarContentClass.RARITY_SILVER)).has("black_pepper_on_cooldown_ready_multicast"), "Black Pepper has multicast definition")
	_assert_true(_definition_ids(_create_item("lightbulb")).has("lightbulb_on_cooldown_ready_charge"), "Lightbulb has right-Tech charge definition")

func test_revolver_crit_reloads_itself() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var revolver: ItemDataClass = _create_item("revolver")
	_assert_true(inv.place_item(revolver, 0), "places Revolver")
	_start_battle(inv, null, 1.0)
	revolver.current_ammo = 1
	_set_ready(revolver)

	_battle_system().call("execute_battle_tick", 0.0)
	_assert_true(_trace_has("revolver_on_crit_reload"), "Revolver reload trace executes on crit")
	_assert_eq(revolver.get_current_ammo(), 2, "Revolver spends one ammo then reloads two")
	_battle_system().call("end_battle")

func test_grapeshot_reloads_when_another_ammo_item_is_used() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var fire_potion: ItemDataClass = _create_item("fire_potion")
	var grapeshot: ItemDataClass = _create_item("grapeshot")
	_assert_true(inv.place_item(fire_potion, 0), "places Fire Potion")
	_assert_true(inv.place_item(grapeshot, 1), "places Grapeshot")
	_start_battle(inv)
	grapeshot.current_ammo = 0
	_set_ready(fire_potion)
	_set_blocked(grapeshot)

	_battle_system().call("execute_battle_tick", 0.0)
	_assert_true(_trace_has("grapeshot_on_item_used_reload"), "Grapeshot reloads from another Ammo item use")
	_assert_eq(grapeshot.get_current_ammo(), 1, "Grapeshot receives one ammo")
	_battle_system().call("end_battle")

func test_satchel_root_reload_emits_reload_chain_regen() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var satchel: ItemDataClass = _create_item("satchel")
	var grapeshot: ItemDataClass = _create_item("grapeshot")
	_assert_true(inv.place_item(satchel, 0), "places Satchel")
	_assert_true(inv.place_item(grapeshot, 2), "places ammo target")
	_start_battle(inv)
	grapeshot.current_ammo = 0
	_set_ready(satchel)
	_set_blocked(grapeshot)

	_battle_system().call("execute_battle_tick", 0.0)
	_assert_true(_trace_has("satchel_on_cooldown_ready_reload"), "Satchel root reload executes")
	_assert_true(_trace_has("satchel_on_reload_regeneration"), "Satchel reload-chain regeneration executes")
	_assert_eq(grapeshot.get_current_ammo(), 1, "Satchel reloads an ammo item")
	_assert_float_eq(float(_battle_system().call("get_status_totals", "self").get("regeneration", 0.0)), 2.0, "Satchel grants regen after Reload")
	_battle_system().call("end_battle")

func test_black_pepper_charges_adjacent_items_and_multicasts() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var left_target: ItemDataClass = _create_item("fang")
	var black_pepper: ItemDataClass = _create_item("black_pepper", BazaarContentClass.RARITY_SILVER)
	var right_target: ItemDataClass = _create_item("lighter")
	_assert_true(inv.place_item(left_target, 0), "places left charge target")
	_assert_true(inv.place_item(black_pepper, 1), "places Black Pepper")
	_assert_true(inv.place_item(right_target, 2), "places right charge target")
	_start_battle(inv)
	left_target.current_cooldown = 5.0
	right_target.current_cooldown = 6.0
	_set_ready(black_pepper)

	_battle_system().call("execute_battle_tick", 0.0)
	_assert_true(_trace_has("black_pepper_on_cooldown_ready_charge"), "Black Pepper charge trace executes")
	_assert_true(_trace_has("black_pepper_on_cooldown_ready_multicast"), "Black Pepper multicast trace executes")
	_assert_float_eq(left_target.current_cooldown, 1.0, "Black Pepper charges left adjacent item across both casts")
	_assert_float_eq(right_target.current_cooldown, 2.0, "Black Pepper charges right adjacent item across both casts")
	_assert_float_eq(float(_battle_system().call("get_status_totals", "enemy").get("burn", 0.0)), 6.0, "Black Pepper burns twice with multicast 2")
	_battle_system().call("end_battle")

func test_lightbulb_charges_right_tech_item() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var lightbulb: ItemDataClass = _create_item("lightbulb")
	var tech_target: ItemDataClass = _create_item("battery")
	_assert_true(inv.place_item(lightbulb, 0), "places Lightbulb")
	_assert_true(inv.place_item(tech_target, 1), "places right Tech target")
	_start_battle(inv)
	_set_ready(lightbulb)
	tech_target.current_cooldown = 4.0

	_battle_system().call("execute_battle_tick", 0.0)
	_assert_true(_trace_has("lightbulb_on_cooldown_ready_charge"), "Lightbulb right-Tech charge trace executes")
	_assert_float_eq(tech_target.current_cooldown, 3.0, "Lightbulb charges the Tech item to its right")
	_battle_system().call("end_battle")

func test_tag_status_and_ammo_definition_mutations() -> void:
	var trigger_inv: LinearInventoryClass = LinearInventoryClass.new()
	var floor_spike: ItemDataClass = _create_item("floor_spike")
	var fang: ItemDataClass = _create_item("fang")
	var spider_mace: ItemDataClass = _create_item("spider_mace")
	_assert_true(trigger_inv.place_item(floor_spike, 0), "places Floor Spike")
	_assert_true(trigger_inv.place_item(fang, 1), "places Weapon source")
	_assert_true(trigger_inv.place_item(spider_mace, 2), "places Spider Mace")
	_start_battle(trigger_inv)
	floor_spike.current_cooldown = 5.0
	spider_mace.current_cooldown = 6.0
	_process_events([{"name": EffectDefinitionClass.TRIGGER_ON_TAG_USED, "source_item": fang, "source_id": fang.source_id, "depth": 0}])
	_assert_true(_trace_has("floor_spike_on_tag_used_charge"), "Floor Spike Weapon-use charge trace executes")
	_assert_float_eq(floor_spike.current_cooldown, 4.0, "Floor Spike charges after a Weapon use")
	_process_events([{"name": EffectDefinitionClass.TRIGGER_ON_ENEMY_STATUS_APPLIED, "source_item": fang, "source_id": fang.source_id, "status_type": EffectDefinitionClass.EFFECT_POISON, "depth": 0}])
	_assert_true(_trace_has("spider_mace_on_enemy_status_applied_charge"), "Spider Mace status-chain charge trace executes")
	_assert_float_eq(spider_mace.current_cooldown, 4.0, "Spider Mace charges after Poison is applied")
	_battle_system().call("end_battle")

	var tesla_inv: LinearInventoryClass = LinearInventoryClass.new()
	var battery: ItemDataClass = _create_item("battery")
	var tesla: ItemDataClass = _create_item("tesla_coil")
	var slow_target: ItemDataClass = _create_item("fang")
	_assert_true(tesla_inv.place_item(battery, 0), "places adjacent Tech source")
	_assert_true(tesla_inv.place_item(tesla, 1), "places Tesla Coil")
	_assert_true(tesla_inv.place_item(slow_target, 3), "places slowest target")
	_start_battle(tesla_inv)
	battery.current_cooldown = 1.0
	tesla.current_cooldown = 3.0
	slow_target.current_cooldown = 8.0
	_process_events([{"name": EffectDefinitionClass.TRIGGER_ON_TAG_USED, "source_item": battery, "source_id": battery.source_id, "depth": 0}])
	_assert_true(_trace_has("tesla_coil_on_tag_used_charge"), "Tesla Coil adjacent-Tech charge trace executes")
	_assert_float_eq(slow_target.current_cooldown, 7.0, "Tesla Coil charges the slowest item")
	_battle_system().call("end_battle")

	var ammo_inv: LinearInventoryClass = LinearInventoryClass.new()
	var potion: ItemDataClass = _create_item("noxious_potion")
	var dagger: ItemDataClass = _create_item("tazidian_dagger")
	_assert_true(ammo_inv.place_item(potion, 0), "places Potion left of Tazidian Dagger")
	_assert_true(ammo_inv.place_item(dagger, 1), "places Tazidian Dagger")
	_start_battle(ammo_inv)
	_assert_true(_trace_has("tazidian_dagger_on_battle_start_ammo"), "Tazidian Dagger ammo trace executes")
	_assert_eq(potion.get_max_ammo(), 2, "Tazidian Dagger grants exactly +1 max Ammo via DSL")
	_assert_eq(potion.get_current_ammo(), 2, "Tazidian Dagger fills granted max Ammo")
	_battle_system().call("end_battle")

func test_reachable_warning_report_reduces_battle_trigger_families() -> void:
	var report: Dictionary = BazaarContentClass.get_reachable_item_effect_coverage_report()
	var family_counts: Dictionary = report.get("warning_family_counts", {})
	_assert_true(int(family_counts.get("unsupported_item_effect:charge", 999)) < 57, "charge warning family is reduced from P1B baseline")
	_assert_true(int(family_counts.get("unsupported_item_effect:reload", 999)) < 13, "reload warning family is reduced from P1B baseline")
	_assert_true(int(family_counts.get("unsupported_item_effect:multicast", 999)) < 33, "multicast warning family is reduced from P1B baseline")
	_assert_true((report.get("unknown_effect_categories", []) as Array).is_empty(), "P1C warning report introduces no unknown warning families")

func _assert_true(value: bool, message: String) -> void:
	if value:
		_passed += 1
		print("PASS: %s" % message)
	else:
		_failed += 1
		push_error("FAIL: %s" % message)

func _assert_eq(actual, expected, message: String) -> void:
	_assert_true(actual == expected, "%s | expected=%s actual=%s" % [message, str(expected), str(actual)])

func _assert_float_eq(actual: float, expected: float, message: String, tolerance: float = 0.001) -> void:
	_assert_true(absf(actual - expected) <= tolerance, "%s | expected=%.3f actual=%.3f" % [message, expected, actual])

func _assert_not_null(value, message: String) -> void:
	_assert_true(value != null, message)
