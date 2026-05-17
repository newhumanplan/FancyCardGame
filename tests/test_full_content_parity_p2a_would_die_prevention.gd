extends Node

const BazaarContentClass = preload("res://scripts/data/bazaar_content.gd")
const EffectDefinitionClass = preload("res://scripts/data/effect_definition.gd")
const ItemEffectsClass = preload("res://scripts/data/item_effects.gd")
const LinearInventoryClass = preload("res://scripts/data/linear_inventory.gd")
const MonsterDataClass = preload("res://scripts/data/monster_data.gd")

var _total: int = 0
var _passed: int = 0

func _ready() -> void:
	if not Engine.is_editor_hint():
		print("== tests/test_full_content_parity_p2a_would_die_prevention.gd ==")
		test_monster_fiery_rebirth_saves_and_heals_to_full_once()
		test_player_fiery_rebirth_saves_and_heals_to_full_once()
		test_shield_absorption_precedes_lethal_check()
		test_burn_and_poison_lethal_ticks_trigger_fiery_rebirth_without_status_cleanse()
		test_p2a3_report_resolves_fiery_rebirth_reason_only()
		_print_summary()

func test_monster_fiery_rebirth_saves_and_heals_to_full_once() -> void:
	var monster: MonsterDataClass = _start_custom_monster([], [{"id": "fiery_rebirth", "tier": "Bronze"}], [])
	monster.current_hp = 25
	_battle_system().call("_damage_current_monster", 80)
	_assert_eq(monster.current_hp, monster.max_hp, "monster Fiery Rebirth intercepts lethal damage before HP reaches 0")
	_assert_eq(_trace_count("fiery_rebirth_would_die_heal_to_full"), 1, "monster Fiery Rebirth trace records once")
	_battle_system().call("_damage_current_monster", monster.max_hp + 10)
	_assert_eq(monster.current_hp, 0, "monster Fiery Rebirth does not save second lethal damage in same fight")
	_assert_eq(_trace_count("fiery_rebirth_would_die_heal_to_full"), 1, "monster Fiery Rebirth remains once per fight")
	_battle_system().call("end_battle")

func test_player_fiery_rebirth_saves_and_heals_to_full_once() -> void:
	var hero = BazaarContentClass.create_mak_hero()
	hero.skills = [{"id": "fiery_rebirth", "tier": "Bronze"}]
	var monster: MonsterDataClass = _start_custom_monster([], [], [], hero)
	_game_manager().set("player_health", 20)
	_battle_system().call("_damage_player", 40)
	_assert_eq(int(_game_manager().get("player_health")), hero.max_hp, "player Fiery Rebirth intercepts lethal damage before HP reaches 0")
	_assert_eq(_trace_count("fiery_rebirth_would_die_heal_to_full"), 1, "player Fiery Rebirth trace records once")
	_battle_system().call("_damage_player", hero.max_hp + 10)
	_assert_eq(int(_game_manager().get("player_health")), 0, "player Fiery Rebirth does not save second lethal damage in same fight")
	_assert_eq(_trace_count("fiery_rebirth_would_die_heal_to_full"), 1, "player Fiery Rebirth remains once per fight")
	monster.current_hp = 0
	_battle_system().call("end_battle")

func test_shield_absorption_precedes_lethal_check() -> void:
	var monster: MonsterDataClass = _start_custom_monster([], [{"id": "fiery_rebirth", "tier": "Bronze"}], [])
	monster.current_hp = 25
	monster.current_shield = 100.0
	_battle_system().call("_damage_current_monster", 80)
	_assert_eq(monster.current_hp, 25, "monster shield absorbs nonlethal post-shield damage without triggering Fiery Rebirth")
	_assert_float_eq(monster.current_shield, 20.0, "monster shield is reduced before lethal check")
	_assert_eq(_trace_count("fiery_rebirth_would_die_heal_to_full"), 0, "Fiery Rebirth does not trigger when shield prevents lethal HP damage")
	_battle_system().call("_damage_current_monster", 50)
	_assert_eq(monster.current_hp, monster.max_hp, "monster Fiery Rebirth triggers after shield absorption leaves lethal HP damage")
	_assert_eq(_trace_count("fiery_rebirth_would_die_heal_to_full"), 1, "Fiery Rebirth triggers once after shield absorption")
	_battle_system().call("end_battle")

func test_burn_and_poison_lethal_ticks_trigger_fiery_rebirth_without_status_cleanse() -> void:
	var burn_monster: MonsterDataClass = _start_custom_monster([], [{"id": "fiery_rebirth", "tier": "Bronze"}], [])
	burn_monster.current_hp = 5
	_battle_system().call("_apply_status_effect", {"type": ItemEffectsClass.EFFECT_BURN, "value": 8.0, "target": "enemy", "item_name": "test burn"})
	_battle_system().call("_process_status_state", "enemy", _battle_system().get("enemy_status_state"), 0.5)
	_assert_eq(burn_monster.current_hp, burn_monster.max_hp, "monster Fiery Rebirth saves lethal Burn tick")
	_assert_true(float(_battle_system().call("get_status_totals", "enemy").get("burn", 0.0)) > 0.0, "Fiery Rebirth does not cleanse monster Burn status")
	_battle_system().call("end_battle")

	var hero = BazaarContentClass.create_mak_hero()
	hero.skills = [{"id": "fiery_rebirth", "tier": "Bronze"}]
	_start_custom_monster([], [], [], hero)
	_game_manager().set("player_health", 5)
	_battle_system().call("_apply_status_effect", {"type": ItemEffectsClass.EFFECT_POISON, "value": 8.0, "target": "self", "item_name": "test poison"})
	_battle_system().call("_process_status_state", "player", _battle_system().get("player_status_state"), 1.0)
	_assert_eq(int(_game_manager().get("player_health")), hero.max_hp, "player Fiery Rebirth saves lethal Poison tick")
	_assert_true(float(_battle_system().call("get_status_totals", "player").get("poison", 0.0)) > 0.0, "Fiery Rebirth does not cleanse player Poison status")
	_battle_system().call("end_battle")

func test_p2a3_report_resolves_fiery_rebirth_reason_only() -> void:
	var report: Dictionary = BazaarContentClass.get_all_monster_parity_report()
	var reason_counts: Dictionary = report.get("grouped_missing_mechanics", {}).get("reason_counts", {})
	_assert_true(not reason_counts.has("skill:fiery_rebirth:death_prevention_heal_to_full_runtime_not_modelled"), "P2A-3 resolves Fiery Rebirth death-prevention reason")
	_assert_true(not reason_counts.has("skill:sparring_partner_skill:death_prevention_cleanse_double_max_health_and_enemy_gold_not_modelled"), "P2A-4 resolves Sparring Partner death-prevention residual")
	_assert_true(not reason_counts.has("skill:ravenous:first_self_below_half_health_temporary_destroy_item_not_modelled"), "P2A-4 resolves Ravenous board-destruction residual")

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
	monster.monster_name = "P2A-3 Would Die Test"
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

func _trace_count(definition_id: String) -> int:
	var count: int = 0
	for entry in _battle_system().call("get_effect_execution_trace"):
		if str(entry.get("definition_id", "")) == definition_id:
			count += 1
	return count

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
