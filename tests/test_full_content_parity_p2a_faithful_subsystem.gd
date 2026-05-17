extends Node

const BazaarContentClass = preload("res://scripts/data/bazaar_content.gd")
const EffectDefinitionClass = preload("res://scripts/data/effect_definition.gd")
const LinearInventoryClass = preload("res://scripts/data/linear_inventory.gd")
const MonsterDataClass = preload("res://scripts/data/monster_data.gd")

var _total: int = 0
var _passed: int = 0

func _ready() -> void:
	if not Engine.is_editor_hint():
		print("== tests/test_full_content_parity_p2a_faithful_subsystem.gd ==")
		test_p2a_report_resolves_selected_trigger_reasons()
		test_flashy_mechanic_monster_tool_adjacent_crit_runtime()
		test_time_to_tinker_monster_haste_shield_runtime()
		test_flashy_reload_monster_crit_reload_other_ammo_runtime()
		test_hard_subsystem_blockers_remain_explicit()
		_print_summary()

func test_p2a_report_resolves_selected_trigger_reasons() -> void:
	var report: Dictionary = BazaarContentClass.get_all_monster_parity_report()
	var reason_counts: Dictionary = report.get("grouped_missing_mechanics", {}).get("reason_counts", {})
	for reason in [
		"skill:chilling_touch:first_freeze_all_enemy_items_trigger_needs_global_status_event_batching",
		"skill:flashy_mechanic:player_skill_runtime_not_bound_to_monster_ai:trigger_rule",
		"skill:flashy_reload:player_skill_runtime_not_bound_to_monster_ai:trigger_rule",
		"skill:hard_shell:first_self_below_half_health_shield_percent_trigger_not_modelled",
		"skill:hunker_down:first_self_below_half_health_shield_percent_trigger_not_modelled",
		"skill:petrifying_gaze:first_self_below_half_health_freeze_all_enemy_items_trigger_not_modelled",
		"skill:time_to_tinker:player_skill_runtime_not_bound_to_monster_ai:trigger_rule",
	]:
		_assert_true(not reason_counts.has(reason), "P2A selected trigger reason resolved: %s" % reason)

func test_flashy_mechanic_monster_tool_adjacent_crit_runtime() -> void:
	var monster: MonsterDataClass = _start_custom_monster([
		{"source_id": "left_weapon", "name": "Left Weapon", "tags": ["Weapon"], "damage": 10, "cooldown": 8.0, "current_cooldown": 8.0, "crit_chance": 0.0},
		{"source_id": "tool_source", "name": "Tool Source", "tags": ["Tool"], "damage": 0, "cooldown": 1.0, "current_cooldown": 0.0, "crit_chance": 0.0},
		{"source_id": "right_weapon", "name": "Right Weapon", "tags": ["Weapon"], "damage": 10, "cooldown": 8.0, "current_cooldown": 8.0, "crit_chance": 0.0},
	], [{"id": "flashy_mechanic", "tier": "Gold"}])
	_battle_system().call("_trigger_monster_items")
	_assert_float_eq(float(monster.monster_items[0].get("crit_chance", 0.0)), 0.06, "Flashy Mechanic gives left adjacent item +6% crit")
	_assert_float_eq(float(monster.monster_items[2].get("crit_chance", 0.0)), 0.06, "Flashy Mechanic gives right adjacent item +6% crit")
	_assert_true(_trace_has("flashy_mechanic_tool_adjacent_crit"), "Flashy Mechanic monster trigger is traced")
	_battle_system().call("end_battle")

func test_time_to_tinker_monster_haste_shield_runtime() -> void:
	var monster: MonsterDataClass = _start_custom_monster([
		{"source_id": "haste_source", "name": "Haste Source", "tags": ["Tool"], "damage": 0, "haste": 1, "haste_duration": 2.0, "cooldown": 1.0, "current_cooldown": 0.0},
		{"source_id": "target", "name": "Target", "tags": ["Weapon"], "damage": 10, "cooldown": 8.0, "current_cooldown": 8.0},
	], [{"id": "time_to_tinker", "tier": "Silver"}])
	_battle_system().call("_trigger_monster_items")
	_assert_float_eq(monster.current_shield, 20.0, "Silver Time to Tinker shields 20 when monster Hastes")
	_assert_true(_trace_has("time_to_tinker_on_haste_shield"), "Time to Tinker monster trigger is traced")
	_battle_system().call("end_battle")

func test_flashy_reload_monster_crit_reload_other_ammo_runtime() -> void:
	var monster: MonsterDataClass = _start_custom_monster([
		{"source_id": "crit_source", "name": "Crit Source", "tags": ["Weapon"], "damage": 0, "cooldown": 1.0, "current_cooldown": 0.0, "crit_chance": 1.0},
		{"source_id": "ammo_target", "name": "Ammo Target", "tags": ["Ammo"], "damage": 0, "cooldown": 8.0, "current_cooldown": 8.0, "ammo": 0, "current_ammo": 0, "max_ammo": 2},
	], [{"id": "flashy_reload", "tier": "Diamond"}])
	_battle_system().call("_trigger_monster_items")
	_assert_eq(int(monster.monster_items[1].get("current_ammo", 0)), 1, "Flashy Reload reloads another Ammo item +1 on monster crit")
	_assert_true(_trace_has("flashy_reload_on_crit_reload_ammo"), "Flashy Reload monster trigger is traced")
	_battle_system().call("end_battle")

func test_hard_subsystem_blockers_remain_explicit() -> void:
	var report: Dictionary = BazaarContentClass.get_all_monster_parity_report()
	var reason_counts: Dictionary = report.get("grouped_missing_mechanics", {}).get("reason_counts", {})
	_assert_true(not reason_counts.has("skill:fiery_rebirth:death_prevention_heal_to_full_runtime_not_modelled"), "Fiery Rebirth death-prevention blocker is resolved by P2A-3")
	_assert_true(not reason_counts.has("skill:ravenous:first_self_below_half_health_temporary_destroy_item_not_modelled"), "P2A-4 resolves Ravenous board-destruction blocker")

func _start_custom_monster(items: Array, skills: Array) -> MonsterDataClass:
	var hero = BazaarContentClass.create_mak_hero()
	var game_manager: Node = _game_manager()
	game_manager.call("reset_stats")
	game_manager.set("selected_hero", hero)
	game_manager.set("player_health", hero.max_hp)
	var desired_cooldowns: Array[float] = []
	for item in items:
		desired_cooldowns.append(float((item as Dictionary).get("current_cooldown", (item as Dictionary).get("cooldown", 0.0))))
	var monster: MonsterDataClass = MonsterDataClass.new()
	monster.monster_name = "P2A Trigger Test"
	monster.max_hp = 1000
	monster.current_hp = 1000
	monster.monster_items = items.duplicate(true)
	monster.monster_skills = skills.duplicate(true)
	_battle_system().call("start_battle", monster, LinearInventoryClass.new())
	for index in range(monster.monster_items.size()):
		var item: Dictionary = monster.monster_items[index]
		item["current_cooldown"] = desired_cooldowns[index]
	return monster

func _battle_system() -> Node:
	return get_node("/root/BattleSystem")

func _game_manager() -> Node:
	return get_node("/root/GameManager")

func _trace_has(definition_id: String) -> bool:
	for entry in _battle_system().call("get_effect_execution_trace"):
		if str(entry.get("definition_id", "")) == definition_id:
			return true
	return false

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
