extends Node

const BazaarContentClass = preload("res://scripts/data/bazaar_content.gd")
const EffectDefinitionClass = preload("res://scripts/data/effect_definition.gd")
const HeroDataClass = preload("res://scripts/data/hero_data.gd")
const ItemDataClass = preload("res://scripts/data/item_data.gd")
const LinearInventoryClass = preload("res://scripts/data/linear_inventory.gd")
const MonsterDataClass = preload("res://scripts/data/monster_data.gd")

var _total: int = 0
var _passed: int = 0

func _ready() -> void:
	if not Engine.is_editor_hint():
		print("== tests/test_full_content_parity_p2a_hard_mechanics_aggregate.gd ==")
		test_memento_mori_heals_one_and_blocks_status_damage_window()
		test_sparring_partner_cleanses_doubles_and_grants_enemy_gold_once()
		test_ravenous_and_into_the_void_destroy_items_for_fight_only()
		test_flying_state_halves_slow_and_triggers_aerial_assault_charge()
		test_economy_value_bridge_runtime_scaling()
		test_p2a4_report_resolves_hard_mechanic_reasons()
		_print_summary()

func test_memento_mori_heals_one_and_blocks_status_damage_window() -> void:
	var memento: ItemDataClass = _create_item("memento_mori", BazaarContentClass.RARITY_GOLD)
	var monster: MonsterDataClass = _start_custom_monster([], [], [memento])
	_game_manager().set("player_health", 5)
	_battle_system().call("_damage_player", 10)
	_assert_eq(int(_game_manager().get("player_health")), 1, "Memento Mori intercepts lethal player damage and heals to 1")
	_assert_eq(_trace_count("memento_mori_would_die_heal_1_no_damage"), 1, "Memento Mori trace records once")
	_battle_system().call("_apply_status_effect", {"type": EffectDefinitionClass.EFFECT_BURN, "value": 20.0, "target": "self", "item_name": "test burn"})
	_battle_system().call("_process_status_state", "player", _battle_system().get("player_status_state"), 0.5)
	_assert_eq(int(_game_manager().get("player_health")), 1, "Memento Mori no-damage window blocks lethal Burn tick")
	_battle_system().call("end_battle")
	monster.current_hp = 0

func test_sparring_partner_cleanses_doubles_and_grants_enemy_gold_once() -> void:
	var start_gold: int = int(_game_manager().call("get_gold"))
	var monster: MonsterDataClass = _start_custom_monster([], [{"id": "sparring_partner_skill", "tier": "Bronze"}], [])
	monster.current_hp = 10
	_battle_system().call("_apply_status_effect", {"type": EffectDefinitionClass.EFFECT_BURN, "value": 12.0, "target": "enemy", "item_name": "test burn"})
	_battle_system().call("_apply_status_effect", {"type": EffectDefinitionClass.EFFECT_POISON, "value": 12.0, "target": "enemy", "item_name": "test poison"})
	_battle_system().call("_damage_current_monster", 999)
	_assert_eq(monster.max_hp, 2000, "Sparring Partner doubles monster Max Health")
	_assert_eq(monster.current_hp, 2000, "Sparring Partner heals monster to full")
	_assert_float_eq(float(_battle_system().call("get_status_totals", "enemy").get("burn", 99.0)), 0.0, "Sparring Partner cleanses Burn")
	_assert_float_eq(float(_battle_system().call("get_status_totals", "enemy").get("poison", 99.0)), 0.0, "Sparring Partner cleanses Poison")
	_assert_eq(int(_game_manager().call("get_gold")), start_gold + 1, "Sparring Partner grants enemy player 1 Gold in PvE")
	_battle_system().call("_damage_current_monster", 3000)
	_assert_eq(_trace_count("sparring_partner_would_die_cleanse_double_max_health_enemy_gold"), 1, "Sparring Partner triggers once per fight")
	_battle_system().call("end_battle")

func test_ravenous_and_into_the_void_destroy_items_for_fight_only() -> void:
	var fang: ItemDataClass = _create_item("fang")
	var duct_tape: ItemDataClass = _create_item("duct_tape")
	var monster: MonsterDataClass = _start_custom_monster([
		{"source_id": "void_source", "name": "Void Source", "size": "Small", "tags": ["Weapon"], "damage": 0, "cooldown": 1.0, "current_cooldown": 0.0},
		{"source_id": "fang", "name": "Fang", "size": "Small", "tags": ["Weapon"], "damage": 5, "cooldown": 1.0, "current_cooldown": 3.0},
	], [{"id": "ravenous", "tier": "Bronze"}, {"id": "into_the_void", "tier": "Diamond"}], [fang, duct_tape])
	_battle_system().call("_damage_current_monster", 510)
	_assert_eq(_destroyed_player_count(), 1, "Ravenous destroys one player item for the fight")
	monster.monster_items[0]["current_cooldown"] = 0.0
	_battle_system().call("_trigger_monster_items")
	_assert_true(_destroyed_player_count() >= 1, "Into the Void keeps player-board destruction tracked")
	_assert_true(_destroyed_monster_count() >= 1, "Into the Void destroys one monster-board item for the fight")
	_battle_system().call("end_battle")
	_assert_eq(_destroyed_player_count(), 0, "temporary player destruction is cleared after combat")
	_assert_eq(_destroyed_monster_count(), 0, "temporary monster destruction is cleared after combat")

func test_flying_state_halves_slow_and_triggers_aerial_assault_charge() -> void:
	var bat: ItemDataClass = _create_item("bat")
	var fang: ItemDataClass = _create_item("fang")
	var monster: MonsterDataClass = _start_custom_monster([
		{"source_id": "slow_source", "name": "Slow Source", "size": "Small", "tags": ["Slow"], "damage": 0, "slow": 1, "slow_duration": 4.0, "cooldown": 1.0, "current_cooldown": 0.0},
	], [], [bat, fang])
	bat.current_cooldown = 8.0
	fang.current_cooldown = 3.0
	_battle_system().call("_set_player_item_flying", bat, "test")
	_battle_system().call("_trigger_monster_items")
	_assert_float_eq(bat.current_cooldown, 10.0, "Flying item receives half Slow duration")
	_battle_system().call("end_battle")

	monster = _start_custom_monster([
		{"source_id": "flying_source", "name": "Flying Source", "size": "Small", "tags": ["Flying"], "effect": "This starts Flying.", "damage": 0, "cooldown": 1.0, "current_cooldown": 0.0},
		{"source_id": "fang", "name": "Fang", "size": "Small", "tags": ["Weapon"], "damage": 5, "cooldown": 10.0, "current_cooldown": 5.0},
	], [{"id": "aerial_assault", "tier": "Diamond"}], [])
	_battle_system().call("_trigger_monster_items")
	_assert_float_eq(float(monster.monster_items[1].get("current_cooldown", 0.0)), 4.0, "Aerial Assault charges a Weapon when an item starts Flying")
	_battle_system().call("end_battle")

func test_economy_value_bridge_runtime_scaling() -> void:
	var fang: ItemDataClass = _create_item("fang")
	var scarf: ItemDataClass = _create_item("duct_tape")
	var lockbox: ItemDataClass = _create_item("lockbox", BazaarContentClass.RARITY_SILVER)
	lockbox.buy_price = 16
	var hero = BazaarContentClass.create_bazaar_hero(HeroDataClass.HeroType.PYGMALIEN)
	hero.skills = [
		{"id": "pickpocket", "tier": "Silver"},
		{"id": "power_broker", "tier": "Silver"},
		{"id": "prosperity", "tier": "Diamond"},
		{"id": "clean_storefront", "tier": "Silver"},
		{"id": "master_salesman", "tier": "Diamond"},
		{"id": "trader", "tier": "Gold"},
	]
	_game_manager().set("gold", 15)
	_game_manager().set("income", 7)
	_start_custom_monster([], [], [fang, scarf, null, lockbox], hero)
	_assert_eq(int(_game_manager().call("get_gold")), 17, "Pickpocket gains battle-start Gold from tier value")
	_assert_eq(_battle_system().call("_get_player_item_skill_damage_bonus", fang), 41, "Power Broker and Lockbox bridge Income/Value into Weapon Damage")
	_assert_eq(_battle_system().call("_get_player_item_skill_shield_bonus", scarf), 76, "Prosperity bridges total combat Value into Shield bonus")
	_battle_system().call("_damage_current_monster", 2000)
	_battle_system().call("end_battle")
	_assert_eq(lockbox.buy_price, 22, "Lockbox gains value on fight win")

func test_p2a4_report_resolves_hard_mechanic_reasons() -> void:
	var report: Dictionary = BazaarContentClass.get_all_monster_parity_report()
	var reason_counts: Dictionary = report.get("grouped_missing_mechanics", {}).get("reason_counts", {})
	for reason in [
		"skill:aerial_assault:flying_state_runtime_not_modelled_for_item_start_flying",
		"skill:haunting_flight:flying_state_runtime_not_modelled_for_small_items",
		"skill:into_the_void:temporary_board_item_destruction_not_modelled",
		"skill:ravenous:first_self_below_half_health_temporary_destroy_item_not_modelled",
		"skill:sparring_partner_skill:death_prevention_cleanse_double_max_health_and_enemy_gold_not_modelled",
		"skill:pickpocket:battle_start_gold_reward_runtime_not_modelled_in_battle_system",
		"skill:power_broker:weapon_damage_from_income_runtime_aura_not_modelled",
		"skill:prosperity:shield_bonus_from_total_item_value_runtime_aura_not_modelled",
	]:
		_assert_true(not reason_counts.has(reason), "P2A-4 reason resolved: %s" % reason)

func _start_custom_monster(items: Array, skills: Array, player_items: Array = [], hero = null) -> MonsterDataClass:
	var selected_hero = hero if hero != null else BazaarContentClass.create_mak_hero()
	var game_manager: Node = _game_manager()
	game_manager.call("reset_stats")
	game_manager.set("selected_hero", selected_hero)
	game_manager.set("player_health", selected_hero.max_hp)
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	for index in range(player_items.size()):
		if player_items[index] != null:
			_assert_true(inv.place_item(player_items[index], index), "places player item %d" % index)
	var desired_cooldowns: Array[float] = []
	for item in items:
		desired_cooldowns.append(float((item as Dictionary).get("current_cooldown", (item as Dictionary).get("cooldown", 0.0))))
	var monster: MonsterDataClass = MonsterDataClass.new()
	monster.monster_name = "P2A-4 Runtime Test"
	monster.max_hp = 1000
	monster.current_hp = 1000
	monster.monster_items = items.duplicate(true)
	monster.monster_skills = skills.duplicate(true)
	_battle_system().call("start_battle", monster, inv)
	for index in range(monster.monster_items.size()):
		var item: Dictionary = monster.monster_items[index]
		item["current_cooldown"] = desired_cooldowns[index]
	return monster

func _battle_system() -> Node:
	return get_node("/root/BattleSystem")

func _game_manager() -> Node:
	return get_node("/root/GameManager")

func _create_item(item_id: String, rarity: int = BazaarContentClass.RARITY_BRONZE) -> ItemDataClass:
	var item: ItemDataClass = BazaarContentClass.create_item(item_id, rarity)
	_assert_true(item != null, "creates %s" % item_id)
	return item

func _trace_count(definition_id: String) -> int:
	var count: int = 0
	for entry in _battle_system().call("get_effect_execution_trace"):
		if str(entry.get("definition_id", "")) == definition_id:
			count += 1
	return count

func _destroyed_player_count() -> int:
	return (_battle_system().get("_effect_runtime_state") as Dictionary).get("destroyed_player_item_ids", []).size()

func _destroyed_monster_count() -> int:
	return (_battle_system().get("_effect_runtime_state") as Dictionary).get("destroyed_monster_item_indexes", []).size()

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
