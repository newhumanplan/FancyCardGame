extends Node

const BazaarContentClass = preload("res://scripts/data/bazaar_content.gd")
const HeroDataClass = preload("res://scripts/data/hero_data.gd")
const ItemDataClass = preload("res://scripts/data/item_data.gd")
const LinearInventoryClass = preload("res://scripts/data/linear_inventory.gd")
const MonsterDataClass = preload("res://scripts/data/monster_data.gd")

var _total: int = 0
var _passed: int = 0

func _ready() -> void:
	print("== tests/test_full_content_parity_p1b_battle_batch.gd ==")
	test_p1b_warning_report_reduces_safe_battle_families()
	test_haladie_multicast_two_total_hits()
	test_octopus_multicast_eight_total_hits()
	test_flamethrower_burns_equal_to_damage()
	_print_summary()

func _battle_system() -> Node:
	return get_node("/root/BattleSystem")

func _game_manager() -> Node:
	return get_node("/root/GameManager")

func _create_item(item_id: String, rarity: int = BazaarContentClass.RARITY_BRONZE) -> ItemDataClass:
	var item: ItemDataClass = BazaarContentClass.create_item(item_id, rarity)
	_assert_true(item != null, "creates %s" % item_id)
	return item

func test_p1b_warning_report_reduces_safe_battle_families() -> void:
	var report: Dictionary = BazaarContentClass.get_reachable_item_effect_coverage_report()
	var families: Dictionary = report.get("warning_family_counts", {})
	_assert_eq(int(report.get("unknown_item_total", -1)), 0, "P1B keeps unknown reachable items closed")
	_assert_true((report.get("unknown_effect_categories", []) as Array).is_empty(), "P1B introduces zero unknown warning families")
	_assert_true(int(report.get("warning_entry_total", 9999)) <= 331, "P1B safe batch reduces warning entries from post-P1A 334")
	_assert_true(int(families.get("unsupported_item_effect:multicast", 9999)) <= 24, "P1B closes Haladie and Octopus multicast warnings")
	_assert_true(int(families.get("unsupported_item_effect:burn", 9999)) <= 9, "P1B closes Flamethrower burn warning")

func test_haladie_multicast_two_total_hits() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var haladie: ItemDataClass = _create_item("haladie", BazaarContentClass.RARITY_BRONZE)
	_assert_true(inv.place_item(haladie, 0), "places Haladie")
	var monster: MonsterDataClass = _start_test_battle(inv, 100)
	haladie.current_cooldown = 0.0
	_battle_system().call("execute_battle_tick", 0.0)
	_assert_eq(monster.current_hp, 90, "Haladie Multicast:2 produces two 5-damage hits")
	_assert_true(_trace_has("haladie_on_cooldown_ready_multicast"), "Haladie emits multicast DSL trace")
	_battle_system().call("end_battle")

func test_octopus_multicast_eight_total_hits() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var octopus: ItemDataClass = _create_item("octopus", BazaarContentClass.RARITY_BRONZE)
	_assert_true(inv.place_item(octopus, 0), "places Octopus")
	var monster: MonsterDataClass = _start_test_battle(inv, 100)
	octopus.current_cooldown = 0.0
	_battle_system().call("execute_battle_tick", 0.0)
	_assert_eq(monster.current_hp, 36, "Octopus Multicast:8 produces eight 8-damage hits")
	_assert_true(_trace_has("octopus_on_cooldown_ready_multicast"), "Octopus emits multicast DSL trace")
	_battle_system().call("end_battle")

func test_flamethrower_burns_equal_to_damage() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var flamethrower: ItemDataClass = _create_item("flamethrower", BazaarContentClass.RARITY_SILVER)
	_assert_true(inv.place_item(flamethrower, 0), "places Flamethrower")
	_start_test_battle(inv, 100)
	flamethrower.current_cooldown = 0.0
	_battle_system().call("execute_battle_tick", 0.0)
	var enemy_status: Dictionary = _battle_system().call("get_status_totals", "enemy")
	_assert_eq(int(enemy_status.get("burn", 0)), 2, "Flamethrower applies Burn equal to its 2 Damage")
	_assert_true(_trace_has("flamethrower_on_cooldown_ready_burn"), "Flamethrower emits burn DSL trace")
	_battle_system().call("end_battle")

func _start_test_battle(inventory: LinearInventoryClass, monster_hp: int) -> MonsterDataClass:
	var hero: HeroDataClass = BazaarContentClass.create_mak_hero()
	hero.crit_chance = 0.0
	hero.skills = []
	var game_manager: Node = _game_manager()
	game_manager.call("reset_stats")
	game_manager.set("selected_hero", hero)
	game_manager.set("player_health", hero.max_hp)
	var monster: MonsterDataClass = MonsterDataClass.new()
	monster.monster_name = "P1B Battle Batch Test"
	monster.max_hp = monster_hp
	monster.current_hp = monster_hp
	_battle_system().call("start_battle", monster, inventory)
	return monster

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

func _print_summary() -> void:
	print("SUMMARY: %d/%d passed" % [_passed, _total])
	get_tree().quit(1 if _passed < _total else 0)
