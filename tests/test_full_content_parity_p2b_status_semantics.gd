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
		print("== tests/test_full_content_parity_p2b_status_semantics.gd ==")
		test_burn_shield_absorption_for_monster()
		test_burn_shield_absorption_for_player()
		test_burn_decays_three_percent_after_each_damage_tick()
		test_player_enrage_clears_slow_freeze_and_reduces_cooldown()
		test_monster_enrage_clears_slow_freeze_and_reduces_cooldown()
		_print_summary()

func test_burn_shield_absorption_for_monster() -> void:
	var monster: MonsterDataClass = _start_custom_monster([], [], [])
	monster.current_shield = 100.0
	_battle_system().call("_apply_status_effect", {"type": EffectDefinitionClass.EFFECT_BURN, "value": 100.0, "target": "enemy", "item_name": "test burn"})
	_battle_system().call("_process_status_state", "enemy", _battle_system().get("enemy_status_state"), 0.5)
	_assert_eq(monster.current_hp, 1000, "100 shield absorbs 100 Burn with no HP damage")
	_assert_float_eq(monster.current_shield, 50.0, "Burn consumes half as much monster shield")

	monster.current_shield = 30.0
	_battle_system().set("enemy_status_state", _new_status_state_with_burn(100.0))
	_battle_system().call("_process_status_state", "enemy", _battle_system().get("enemy_status_state"), 0.5)
	_assert_eq(monster.current_hp, 960, "30 shield absorbs 60 Burn and leaves 40 HP damage")
	_assert_float_eq(monster.current_shield, 0.0, "partial Burn shield absorption consumes all available monster shield")
	_battle_system().call("end_battle")

func test_burn_shield_absorption_for_player() -> void:
	_start_custom_monster([], [], [])
	var hero = _game_manager().selected_hero
	hero.current_shield = 100.0
	_game_manager().set("player_health", 100)
	_battle_system().call("_apply_status_effect", {"type": EffectDefinitionClass.EFFECT_BURN, "value": 100.0, "target": "self", "item_name": "test burn"})
	_battle_system().call("_process_status_state", "player", _battle_system().get("player_status_state"), 0.5)
	_assert_eq(int(_game_manager().get("player_health")), 100, "100 shield absorbs 100 player Burn with no HP damage")
	_assert_float_eq(hero.current_shield, 50.0, "Burn consumes half as much player shield")

	hero.current_shield = 30.0
	_battle_system().set("player_status_state", _new_status_state_with_burn(100.0))
	_battle_system().call("_process_status_state", "player", _battle_system().get("player_status_state"), 0.5)
	_assert_eq(int(_game_manager().get("player_health")), 60, "30 shield absorbs 60 player Burn and leaves 40 HP damage")
	_assert_float_eq(hero.current_shield, 0.0, "partial Burn shield absorption consumes all available player shield")
	_battle_system().call("end_battle")

func test_burn_decays_three_percent_after_each_damage_tick() -> void:
	var monster: MonsterDataClass = _start_custom_monster([], [], [])
	monster.current_shield = 0.0
	_battle_system().call("_apply_status_effect", {"type": EffectDefinitionClass.EFFECT_BURN, "value": 100.0, "target": "enemy", "item_name": "test burn"})
	_battle_system().call("_process_status_state", "enemy", _battle_system().get("enemy_status_state"), 0.5)
	_assert_float_eq(float(_battle_system().call("get_status_totals", "enemy").get("burn", 0.0)), 97.0, "Burn decays by 3 percent after first damage tick")
	_assert_eq(monster.current_hp, 900, "first Burn tick deals pre-decay amount")
	_battle_system().call("_process_status_state", "enemy", _battle_system().get("enemy_status_state"), 0.5)
	_assert_float_eq(float(_battle_system().call("get_status_totals", "enemy").get("burn", 0.0)), 94.09, "Burn decays by 3 percent after second damage tick")
	_assert_eq(monster.current_hp, 803, "second Burn tick deals rounded pre-decay amount")
	_battle_system().call("end_battle")

func test_player_enrage_clears_slow_freeze_and_reduces_cooldown() -> void:
	var fang: ItemDataClass = _create_item("fang")
	_start_custom_monster([], [], [fang])
	fang.current_cooldown = 8.0
	_battle_system().call("_enter_enrage", "player", 5.0)
	_assert_float_eq(fang.current_cooldown, 2.7, "player Enrage clears Slow/Freeze delay and applies 10 percent cooldown reduction")
	_assert_float_eq(_battle_system().call("_get_player_item_effective_cooldown", fang), 2.7, "player item cooldown time is reduced by 10 percent while Enraged")
	_battle_system().call("_exit_enrage", "player")
	_assert_float_eq(_battle_system().call("_get_player_item_effective_cooldown", fang), 3.0, "player item cooldown returns to source value after Enrage exits")
	_battle_system().call("end_battle")

func test_monster_enrage_clears_slow_freeze_and_reduces_cooldown() -> void:
	var monster: MonsterDataClass = _start_custom_monster([
		{"source_id": "fang", "name": "Fang", "size": "Small", "tags": ["Weapon"], "damage": 5, "cooldown": 10.0, "current_cooldown": 16.0},
	], [], [])
	_battle_system().call("_enter_enrage", "monster", 5.0)
	_assert_float_eq(float(monster.monster_items[0].get("current_cooldown", 0.0)), 9.0, "monster Enrage clears Slow/Freeze delay and applies 10 percent cooldown reduction")
	monster.monster_items[0]["current_cooldown"] = 0.0
	_battle_system().call("_trigger_monster_items")
	_assert_float_eq(float(monster.monster_items[0].get("current_cooldown", 0.0)), 9.0, "monster item reset cooldown is reduced by 10 percent while Enraged")
	_battle_system().call("_exit_enrage", "monster")
	monster.monster_items[0]["current_cooldown"] = 0.0
	_battle_system().call("_trigger_monster_items")
	_assert_float_eq(float(monster.monster_items[0].get("current_cooldown", 0.0)), 10.0, "monster item reset cooldown returns to source value after Enrage exits")
	_battle_system().call("end_battle")

func _start_custom_monster(items: Array, skills: Array, player_items: Array = []) -> MonsterDataClass:
	var hero = BazaarContentClass.create_mak_hero()
	var game_manager: Node = _game_manager()
	game_manager.call("reset_stats")
	game_manager.set("selected_hero", hero)
	game_manager.set("player_health", hero.max_hp)
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	for index in range(player_items.size()):
		if player_items[index] != null:
			_assert_true(inv.place_item(player_items[index], index), "places player item %d" % index)
	var desired_cooldowns: Array[float] = []
	for item in items:
		desired_cooldowns.append(float((item as Dictionary).get("current_cooldown", (item as Dictionary).get("cooldown", 0.0))))
	var monster: MonsterDataClass = MonsterDataClass.new()
	monster.monster_name = "P2B Status Test"
	monster.max_hp = 1000
	monster.current_hp = 1000
	monster.monster_items = items.duplicate(true)
	monster.monster_skills = skills.duplicate(true)
	_battle_system().call("start_battle", monster, inv)
	for index in range(monster.monster_items.size()):
		var item: Dictionary = monster.monster_items[index]
		item["current_cooldown"] = desired_cooldowns[index]
	return monster

func _new_status_state_with_burn(amount: float) -> Dictionary:
	return {
		"poison": 0.0,
		"burn": amount,
		"regeneration": 0.0,
		"burn_tick": 0.0,
		"poison_regen_tick": 0.0,
	}

func _battle_system() -> Node:
	return get_node("/root/BattleSystem")

func _game_manager() -> Node:
	return get_node("/root/GameManager")

func _create_item(item_id: String, rarity: int = BazaarContentClass.RARITY_BRONZE) -> ItemDataClass:
	var item: ItemDataClass = BazaarContentClass.create_item(item_id, rarity)
	_assert_true(item != null, "creates %s" % item_id)
	return item

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
