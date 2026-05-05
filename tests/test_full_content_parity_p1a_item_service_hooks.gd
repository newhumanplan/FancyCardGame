extends Node

const BazaarContentClass = preload("res://scripts/data/bazaar_content.gd")
const EffectDefinitionClass = preload("res://scripts/data/effect_definition.gd")
const HeroDataClass = preload("res://scripts/data/hero_data.gd")
const ItemDataClass = preload("res://scripts/data/item_data.gd")
const LinearInventoryClass = preload("res://scripts/data/linear_inventory.gd")
const MonsterDataClass = preload("res://scripts/data/monster_data.gd")
const SellServiceClass = preload("res://scripts/services/sell_service.gd")

var _total: int = 0
var _passed: int = 0

func _ready() -> void:
	print("== tests/test_full_content_parity_p1a_item_service_hooks.gd ==")
	test_p1a_warning_report_reduces_service_families()
	test_landscraper_counts_sold_items_and_gains_value()
	test_powder_flask_reloads_right_item_ammo()
	test_vitality_potion_heals_from_hero_max_health()
	_print_summary()

func _battle_system() -> Node:
	return get_node("/root/BattleSystem")

func _game_manager() -> Node:
	return get_node("/root/GameManager")

func _create_item(item_id: String, rarity: int = BazaarContentClass.RARITY_BRONZE) -> ItemDataClass:
	var item: ItemDataClass = BazaarContentClass.create_item(item_id, rarity)
	_assert_true(item != null, "creates %s" % item_id)
	return item

func test_p1a_warning_report_reduces_service_families() -> void:
	var report: Dictionary = BazaarContentClass.get_reachable_item_effect_coverage_report()
	var families: Dictionary = report.get("warning_family_counts", {})
	_assert_eq(int(report.get("unknown_item_total", -1)), 0, "P1A keeps unknown reachable items closed")
	_assert_true((report.get("unknown_effect_categories", []) as Array).is_empty(), "P1A introduces zero unknown warning families")
	_assert_true(int(report.get("warning_entry_total", 9999)) <= 334, "P1A reduces warning entries from 337 baseline")
	_assert_true(int(families.get("unsupported_item_trigger:on_sell", 0)) == 0, "P1A closes hookable on_sell warning")
	_assert_true(int(families.get("unsupported_item_effect:heal", 9999)) <= 7, "P1A closes Vitality Potion heal warning")
	_assert_true(int(families.get("unsupported_item_effect:reload", 9999)) <= 5, "P1A closes Powder Flask reload warning")

func test_landscraper_counts_sold_items_and_gains_value() -> void:
	RewardService.reset_runtime_state()
	var inventory: LinearInventoryClass = LinearInventoryClass.new()
	var landscraper: ItemDataClass = _create_item("landscraper", BazaarContentClass.RARITY_GOLD)
	_assert_true(inventory.place_item(landscraper, 0), "places Landscraper")
	var initial_value: int = landscraper.buy_price
	for index in range(10):
		var spare: ItemDataClass = _create_item("spare_change", BazaarContentClass.RARITY_BRONZE)
		_assert_true(inventory.place_item(spare, 3), "places sell item %d" % index)
		var result: Dictionary = SellServiceClass.sell_item(spare, inventory)
		_assert_true(bool(result.get("success", false)), "sells item %d" % index)
	_assert_eq(landscraper.buy_price, initial_value + 5, "Landscraper gains +5 value after 10 sold items at Gold")
	_assert_eq(int(landscraper.runtime_counters.get("sold_items", -1)), 0, "Landscraper sell counter resets after threshold")
	_assert_true(not landscraper.effect_warnings.has("unsupported_item_trigger:landscraper:on_sell"), "Landscraper no longer reports unsupported on_sell trigger")

func test_powder_flask_reloads_right_item_ammo() -> void:
	var inventory: LinearInventoryClass = LinearInventoryClass.new()
	var powder_flask: ItemDataClass = _create_item("powder_flask", BazaarContentClass.RARITY_BRONZE)
	var grenade: ItemDataClass = _create_item("grenade", BazaarContentClass.RARITY_BRONZE)
	_assert_true(inventory.place_item(powder_flask, 0), "places Powder Flask")
	_assert_true(inventory.place_item(grenade, 1), "places Ammo item to the right")
	_start_test_battle(inventory, 300)
	grenade.reset_ammo(2)
	grenade.consume_ammo(2)
	powder_flask.current_cooldown = 0.0
	_battle_system().call("execute_battle_tick", 0.0)
	_assert_eq(grenade.get_current_ammo(), 1, "Powder Flask reloads right item by 1 at Bronze")
	_assert_true(_trace_has("powder_flask_on_cooldown_ready_reload"), "Powder Flask emits reload DSL trace")
	_battle_system().call("end_battle")

func test_vitality_potion_heals_from_hero_max_health() -> void:
	var inventory: LinearInventoryClass = LinearInventoryClass.new()
	var potion: ItemDataClass = _create_item("vitality_potion", BazaarContentClass.RARITY_GOLD)
	_assert_true(inventory.place_item(potion, 0), "places Vitality Potion")
	_start_test_battle(inventory, 300)
	var game_manager: Node = _game_manager()
	game_manager.set("player_health", 25)
	potion.reset_ammo(1)
	potion.current_cooldown = 0.0
	_battle_system().call("execute_battle_tick", 0.0)
	_assert_eq(int(game_manager.get("player_health")), 75, "Vitality Potion heals 50% of 100 Max Health at Gold")
	_assert_true(_trace_has("vitality_potion_on_cooldown_ready_heal"), "Vitality Potion emits max-health heal DSL trace")
	_assert_true(not potion.effect_warnings.has("unsupported_item_effect:vitality_potion:heal"), "Vitality Potion no longer reports unsupported heal")
	_battle_system().call("end_battle")

func _start_test_battle(inventory: LinearInventoryClass, monster_hp: int) -> void:
	var hero: HeroDataClass = BazaarContentClass.create_mak_hero()
	hero.max_hp = 100
	hero.crit_chance = 0.0
	hero.skills = []
	var game_manager: Node = _game_manager()
	game_manager.call("reset_stats")
	game_manager.set("selected_hero", hero)
	game_manager.set("player_health", hero.max_hp)
	var monster: MonsterDataClass = MonsterDataClass.new()
	monster.monster_name = "P1A Item Service Hook Test"
	monster.max_hp = monster_hp
	monster.current_hp = monster_hp
	_battle_system().call("start_battle", monster, inventory)

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
