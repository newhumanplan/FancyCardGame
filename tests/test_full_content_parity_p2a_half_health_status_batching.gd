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
		print("== tests/test_full_content_parity_p2a_half_health_status_batching.gd ==")
		test_first_below_half_health_monster_skills_trigger_once()
		test_chilling_touch_slows_all_enemy_items_on_first_freeze_once()
		test_p2a2_report_resolves_half_health_status_reasons()
		_print_summary()

func test_first_below_half_health_monster_skills_trigger_once() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var fang: ItemDataClass = _create_item("fang")
	var lighter: ItemDataClass = _create_item("lighter")
	_assert_true(inv.place_item(fang, 0), "places Fang target")
	_assert_true(inv.place_item(lighter, 1), "places Lighter target")
	var monster: MonsterDataClass = _start_custom_monster(inv, [], [
		{"id": "hard_shell", "tier": "Diamond"},
		{"id": "hunker_down", "tier": "Gold"},
		{"id": "petrifying_gaze", "tier": "Diamond"},
	])
	fang.current_cooldown = 4.0
	lighter.current_cooldown = 6.0

	_battle_system().call("_damage_current_monster", 510)
	_assert_eq(monster.current_hp, 490, "monster crosses below half health")
	_assert_float_eq(monster.current_shield, 1000.0, "Hard Shell Diamond and Hunker Down Gold shield from max health percent")
	_assert_float_eq(fang.current_cooldown, 7.0, "Petrifying Gaze freezes all player items for Diamond duration")
	_assert_float_eq(lighter.current_cooldown, 9.0, "Petrifying Gaze freezes second player item for Diamond duration")
	_assert_eq(_trace_count("hard_shell_first_below_half_health_shield"), 1, "Hard Shell trace records once")
	_assert_eq(_trace_count("hunker_down_first_below_half_health_shield"), 1, "Hunker Down trace records once")
	_assert_eq(_trace_count("petrifying_gaze_first_below_half_health_freeze_all_enemy_items"), 1, "Petrifying Gaze trace records once")

	_battle_system().call("_damage_current_monster", 100)
	_assert_eq(_trace_count("hard_shell_first_below_half_health_shield"), 1, "Hard Shell does not retrigger after first below-half crossing")
	_assert_eq(_trace_count("hunker_down_first_below_half_health_shield"), 1, "Hunker Down does not retrigger after first below-half crossing")
	_assert_eq(_trace_count("petrifying_gaze_first_below_half_health_freeze_all_enemy_items"), 1, "Petrifying Gaze does not retrigger after first below-half crossing")
	_battle_system().call("end_battle")

func test_chilling_touch_slows_all_enemy_items_on_first_freeze_once() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var fang: ItemDataClass = _create_item("fang")
	var lighter: ItemDataClass = _create_item("lighter")
	_assert_true(inv.place_item(fang, 0), "places Fang slow target")
	_assert_true(inv.place_item(lighter, 1), "places Lighter freeze target")
	var monster: MonsterDataClass = _start_custom_monster(inv, [
		{"source_id": "freeze_source", "name": "Freeze Source", "tags": ["Freeze"], "damage": 0, "freeze": 1, "freeze_duration": 1.0, "cooldown": 1.0, "current_cooldown": 0.0},
	], [{"id": "chilling_touch", "tier": "Gold"}])
	fang.current_cooldown = 4.0
	lighter.current_cooldown = 6.0

	_battle_system().call("_trigger_monster_items")
	_assert_float_eq(fang.current_cooldown, 9.0, "Chilling Touch slows all enemy items for Gold duration")
	_assert_float_eq(lighter.current_cooldown, 12.0, "Monster Freeze plus Chilling Touch apply to frozen target")
	_assert_eq(_trace_count("chilling_touch_first_freeze_slow_all_enemy_items"), 1, "Chilling Touch trace records once")

	monster.monster_items[0]["current_cooldown"] = 0.0
	_battle_system().call("_trigger_monster_items")
	_assert_eq(_trace_count("chilling_touch_first_freeze_slow_all_enemy_items"), 1, "Chilling Touch does not retrigger on later Freeze")
	_battle_system().call("end_battle")

func test_p2a2_report_resolves_half_health_status_reasons() -> void:
	var report: Dictionary = BazaarContentClass.get_all_monster_parity_report()
	var reason_counts: Dictionary = report.get("grouped_missing_mechanics", {}).get("reason_counts", {})
	for reason in [
		"skill:chilling_touch:first_freeze_all_enemy_items_trigger_needs_global_status_event_batching",
		"skill:hard_shell:first_self_below_half_health_shield_percent_trigger_not_modelled",
		"skill:hunker_down:first_self_below_half_health_shield_percent_trigger_not_modelled",
		"skill:petrifying_gaze:first_self_below_half_health_freeze_all_enemy_items_trigger_not_modelled",
	]:
		_assert_true(not reason_counts.has(reason), "P2A-2 reason resolved: %s" % reason)
	_assert_true(reason_counts.has("skill:fiery_rebirth:death_prevention_heal_to_full_runtime_not_modelled"), "Fiery Rebirth remains explicit death-prevention blocker")

func _start_custom_monster(inv: LinearInventoryClass, items: Array, skills: Array) -> MonsterDataClass:
	var hero = BazaarContentClass.create_mak_hero()
	var game_manager: Node = _game_manager()
	game_manager.call("reset_stats")
	game_manager.set("selected_hero", hero)
	game_manager.set("player_health", hero.max_hp)
	var desired_cooldowns: Array[float] = []
	for item in items:
		desired_cooldowns.append(float((item as Dictionary).get("current_cooldown", (item as Dictionary).get("cooldown", 0.0))))
	var monster: MonsterDataClass = MonsterDataClass.new()
	monster.monster_name = "P2A-2 Runtime Test"
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
