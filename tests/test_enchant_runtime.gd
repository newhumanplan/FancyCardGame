extends Node

const BazaarContentClass = preload("res://scripts/data/bazaar_content.gd")
const ItemDataClass = preload("res://scripts/data/item_data.gd")
const LinearInventoryClass = preload("res://scripts/data/linear_inventory.gd")
const MonsterDataClass = preload("res://scripts/data/monster_data.gd")
const PvpGhostServiceClass = preload("res://scripts/services/pvp_ghost_service.gd")

var _total: int = 0
var _passed: int = 0

func _ready() -> void:
	if not Engine.is_editor_hint():
		print("== tests/test_enchant_runtime.gd ==")
		_run_tests()
		_print_summary()

func _run_tests() -> void:
	test_fiery_enchant_adds_burn_via_runtime()
	test_toxic_enchant_adds_poison_via_runtime()
	test_restorative_enchant_adds_heal_and_regen_via_runtime()
	test_heavy_enchant_adds_damage_via_runtime()
	test_obsidian_enchant_adds_damage_via_runtime()
	test_snapshot_enchanted_item_affects_monster_combat()

func _battle_system() -> Node:
	return get_node("/root/BattleSystem")

func _game_manager() -> Node:
	return get_node("/root/GameManager")

func _create_item(
	item_id: String,
	rarity: int = BazaarContentClass.RARITY_BRONZE,
	enchantment: String = ""
) -> ItemDataClass:
	var item: ItemDataClass = BazaarContentClass.create_item(item_id, rarity, enchantment)
	_assert_true(item != null, "test setup creates %s[%s]" % [item_id, enchantment if not enchantment.is_empty() else "none"])
	return item

func _start_battle(hero_skills: Array, inv: LinearInventoryClass, monster: MonsterDataClass = null) -> MonsterDataClass:
	var hero = BazaarContentClass.create_mak_hero()
	hero.crit_chance = 0.0
	hero.skills = hero_skills.duplicate()
	var game_manager: Node = _game_manager()
	game_manager.call("reset_stats")
	game_manager.set("selected_hero", hero)
	game_manager.set("player_health", hero.max_hp)
	var battle_monster: MonsterDataClass = monster if monster != null else MonsterDataClass.new()
	if monster == null:
		battle_monster.monster_name = "Enchant Test"
		battle_monster.max_hp = 100
		battle_monster.current_hp = 100
	_battle_system().call("start_battle", battle_monster, inv)
	return battle_monster

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

func test_fiery_enchant_adds_burn_via_runtime() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var item: ItemDataClass = _create_item("fang", BazaarContentClass.RARITY_BRONZE, "fiery")
	_assert_true(inv.place_item(item, 0), "places Fiery-enchanted item")
	var monster: MonsterDataClass = _start_battle([], inv)
	item.current_cooldown = 0.0
	_battle_system().call("execute_battle_tick", 0.0)
	_assert_eq(item.enchantment_id, "fiery", "Fiery enchantment id is normalized on item runtime")
	_assert_eq(item.item_name, "Fang [Fiery]", "Fiery enchantment updates item display name")
	_assert_eq(monster.current_hp, 95, "Fiery enchantment preserves the base damage use")
	_assert_float_eq(float(_battle_system().call("get_status_totals", "enemy").get("burn", 0.0)), 2.0, "Fiery enchantment adds Burn through the runtime")
	_battle_system().call("end_battle")

func test_toxic_enchant_adds_poison_via_runtime() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var item: ItemDataClass = _create_item("fang", BazaarContentClass.RARITY_BRONZE, "toxic")
	_assert_true(inv.place_item(item, 0), "places Toxic-enchanted item")
	_start_battle([], inv)
	item.current_cooldown = 0.0
	_battle_system().call("execute_battle_tick", 0.0)
	_assert_float_eq(float(_battle_system().call("get_status_totals", "enemy").get("poison", 0.0)), 2.0, "Toxic enchantment adds Poison through the runtime")
	_battle_system().call("end_battle")

func test_restorative_enchant_adds_heal_and_regen_via_runtime() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var item: ItemDataClass = _create_item("fang", BazaarContentClass.RARITY_BRONZE, "restorative")
	_assert_true(inv.place_item(item, 0), "places Restorative-enchanted item")
	_start_battle([], inv)
	var hero = _game_manager().get("selected_hero")
	_game_manager().set("player_health", hero.max_hp - 20)
	item.current_cooldown = 0.0
	_battle_system().call("execute_battle_tick", 0.0)
	_assert_eq(_game_manager().get("player_health"), hero.max_hp - 14, "Restorative enchantment heals through the runtime")
	_assert_float_eq(float(_battle_system().call("get_status_totals", "self").get("regeneration", 0.0)), 3.0, "Restorative enchantment adds Regeneration through the runtime")
	_battle_system().call("end_battle")

func test_heavy_enchant_adds_damage_via_runtime() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var item: ItemDataClass = _create_item("fang", BazaarContentClass.RARITY_BRONZE, "heavy")
	_assert_true(inv.place_item(item, 0), "places Heavy-enchanted item")
	var monster: MonsterDataClass = _start_battle([], inv)
	item.current_cooldown = 0.0
	_battle_system().call("execute_battle_tick", 0.0)
	_assert_eq(monster.current_hp, 87, "Heavy enchantment adds runtime damage")
	_battle_system().call("end_battle")

func test_obsidian_enchant_adds_damage_via_runtime() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var item: ItemDataClass = _create_item("fang", BazaarContentClass.RARITY_BRONZE, "obsidian")
	_assert_true(inv.place_item(item, 0), "places Obsidian-enchanted item")
	var monster: MonsterDataClass = _start_battle([], inv)
	item.current_cooldown = 0.0
	_battle_system().call("execute_battle_tick", 0.0)
	_assert_eq(monster.current_hp, 77, "Obsidian enchantment adds the larger runtime damage bonus")
	_battle_system().call("end_battle")

func test_snapshot_enchanted_item_affects_monster_combat() -> void:
	var archetype: Dictionary = PvpGhostServiceClass.get_default_archetype()
	archetype["id"] = "ghost_enchant_runtime"
	archetype["hero_id"] = "mak"
	archetype["items"] = [{
		"item_id": "fang",
		"tier": "bronze",
		"size": 1,
		"slot_index": 0,
		"enchantment": "obsidian",
		"cooldown": 4.0,
		"ammo": 0,
		"charges": 0,
	}]
	var validation: Dictionary = PvpGhostServiceClass.validate_curated_archetype(archetype)
	_assert_true(bool(validation.get("valid", false)), "snapshot archetype with a canonical enchantment validates")
	if not bool(validation.get("valid", false)):
		return
	var snapshot = PvpGhostServiceClass.curated_archetype_to_snapshot(archetype)
	var monster: MonsterDataClass = PvpGhostServiceClass.ghost_snapshot_to_monster(snapshot)
	_assert_eq(str(monster.monster_items[0].get("enchantment", "")), "obsidian", "snapshot keeps the canonical enchantment id")
	_assert_eq(int(monster.monster_items[0].get("damage", 0)), 23, "snapshot conversion applies the enchantment damage bonus")
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	_start_battle([], inv, monster)
	var start_health: int = int(_game_manager().get("player_health"))
	var expected_damage: int = int(float(monster.monster_items[0].get("damage", 0)) * monster.ai.get_current_damage_multiplier(monster))
	monster.monster_items[0]["current_cooldown"] = 0.0
	_battle_system().call("execute_battle_tick", 0.0)
	_assert_eq(_game_manager().get("player_health"), start_health - expected_damage, "snapshot enchantment changes live monster combat damage")
	_battle_system().call("end_battle")
