extends Node

const BazaarContentClass = preload("res://scripts/data/bazaar_content.gd")
const HeroDataClass = preload("res://scripts/data/hero_data.gd")
const LinearInventoryClass = preload("res://scripts/data/linear_inventory.gd")


class MockGameManager:
	extends Node
	var gold: int = 0
	var income: int = 0
	var health: int = 0
	var max_health_value: int = 0
	var prestige: int = 0
	var damage_taken: int = 0
	var level: int = 1
	var selected_hero = null

	func setup() -> void:
		set("gold", 50)
		set("income", 7)
		set("health", 40)
		set("max_health_value", 100)
		set("prestige", 0)
		set("damage_taken", 0)
		var hero: HeroDataClass = HeroDataClass.new()
		hero.hero_name = "Mak"
		hero.max_hp = max_health_value
		hero.current_hp = health
		hero.crit_chance = 0.10
		set("selected_hero", hero)

	func add_gold(amount: int) -> void:
		gold += amount

	func spend_gold(amount: int) -> void:
		gold -= amount

	func add_income(amount: int) -> void:
		income += amount

	func heal(amount: int) -> void:
		health = mini(health + amount, max_health_value)

	func take_damage(amount: int) -> void:
		damage_taken += amount
		health = maxi(health - amount, 0)

	func add_prestige(amount: int) -> void:
		prestige += amount

	func add_max_health(amount: int) -> int:
		max_health_value += amount
		health = mini(health + amount, max_health_value)
		if selected_hero != null:
			selected_hero.max_hp += amount
			selected_hero.current_hp = health
		return max_health_value

	func get_max_health() -> int:
		return max_health_value


var _total: int = 0
var _passed: int = 0


func _ready() -> void:
	if not Engine.is_editor_hint():
		print("== tests/test_event_manager.gd ==")
		randomize()
		_run_tests()
		_print_summary()


func _run_tests() -> void:
	test_generate_options_for_pvp_hour()
	test_generate_options_for_pve_hour()
	test_generate_options_for_build_hour()
	test_get_all_events_and_count()
	test_execute_random_event_for_each_event_id()


func _manager():
	return load("res://scripts/data/event_manager.gd").new()


func _game_manager() -> MockGameManager:
	var game_manager = MockGameManager.new()
	game_manager.setup()
	return game_manager


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


func test_generate_options_for_pvp_hour() -> void:
	var options = _manager().generate_options(5, 2)

	_assert_eq(options.size(), 1, "generate_options returns only one option at PvP hour")
	_assert_eq(options[0]["type"], "pvp", "generate_options labels hour 5 option as pvp")


func test_generate_options_for_pve_hour() -> void:
	var options = _manager().generate_options(2, 3)
	_assert_eq(options.size(), 3, "generate_options returns three monster options at PvE hour")
	for option in options:
		_assert_eq(option["type"], "monster", "generate_options labels PvE options as monsters")


func test_generate_options_for_build_hour() -> void:
	var manager = _manager()
	var saw_random_event := false
	var random_event_is_registered := true
	var registered_ids: Dictionary = {}
	for event_data in manager.get_all_events():
		registered_ids[event_data["id"]] = true

	for _i in range(50):
		var options = manager.generate_options(0, 3)
		var types: Array[String] = []
		var seen_event_ids: Dictionary = {}
		for option in options:
			types.append(str(option["type"]))
			if option["type"] == "random_event":
				saw_random_event = true
				var event_id: String = str(option.get("event_id", ""))
				if seen_event_ids.has(event_id):
					random_event_is_registered = false
				seen_event_ids[event_id] = true
				if not registered_ids.has(event_id):
					random_event_is_registered = false
		if "monster" in types or "pvp" in types or "treasure" in types or "camp" in types:
			random_event_is_registered = false
		if options.size() == 3 and "shop" in types and saw_random_event:
			break

	_assert_true(saw_random_event, "generate_options can produce random events in build hours")
	_assert_true(random_event_is_registered, "generate_options random_event ids come from registered event list")


func test_get_all_events_and_count() -> void:
	var manager = _manager()
	var events = manager.get_all_events()
	events[0]["name"] = "mutated"
	var fresh_events = manager.get_all_events()

	_assert_true(manager.get_event_count() >= 30, "get_event_count includes full Day 1 event catalog")
	_assert_true(fresh_events[0]["name"] != "mutated", "get_all_events returns a deep copy")


func test_execute_random_event_for_each_event_id() -> void:
	var manager = _manager()
	var borrow_manager = _game_manager()
	var borrow_result = manager.execute_random_event("borrow", 2, borrow_manager)
	_assert_eq(borrow_manager.gold, 58, "Borrow grants day 1-2 gold")
	_assert_eq(borrow_manager.income, 6, "Borrow removes one income")
	_assert_true("8" in borrow_result, "Borrow result mentions gold amount")
	borrow_manager.free()

	var cache_manager = _game_manager()
	var cache_result = manager.execute_random_event("cache_of_riches", 2, cache_manager)
	_assert_eq(cache_manager.gold, 53, "Cache of Riches grants day 1-2 gold")
	_assert_true("3" in cache_result, "Cache of Riches result mentions gold amount")
	cache_manager.free()

	var furry_manager = _game_manager()
	var furry_result = manager.execute_random_event("tiny_furry_monster", 2, furry_manager)
	_assert_eq(furry_manager.max_health_value, 125, "Tiny Furry Monster increases max health")
	_assert_eq(furry_manager.selected_hero.max_hp, 125, "Tiny Furry Monster updates hero max health")
	_assert_true("25" in furry_result, "Tiny Furry Monster result mentions health amount")
	furry_manager.free()

	var relax_manager = _game_manager()
	var relax_result = manager.execute_random_event("relax", 2, relax_manager)
	_assert_eq(int(relax_manager.selected_hero._combat_bonus_shield), 100, "Relax applies next-fight shield bonus")
	_assert_true("100" in relax_result, "Relax result mentions shield amount")
	relax_manager.free()

	var item_manager = _game_manager()
	var inventory: LinearInventoryClass = LinearInventoryClass.new()
	var item_result = manager.execute_random_event("battlefield", 1, item_manager, inventory)
	_assert_true(inventory.items.size() == 1, "Battlefield grants an item when inventory is available")
	_assert_true(item_result.find("gained") >= 0, "Battlefield result mentions gained item")
	item_manager.free()

	var upgrade_item = BazaarContentClass.create_item("fire_potion", BazaarContentClass.RARITY_BRONZE)
	var upgrade_inventory: LinearInventoryClass = LinearInventoryClass.new()
	upgrade_inventory.place_item(upgrade_item, 0)
	var upgrade_manager = _game_manager()
	var upgrade_result = manager.execute_random_event("b1_b2", 1, upgrade_manager, upgrade_inventory)
	_assert_eq(upgrade_item.rarity, BazaarContentClass.RARITY_SILVER, "B1&B2 upgrades one bronze item")
	_assert_true(upgrade_result.find("upgraded") >= 0, "B1&B2 result mentions upgrade")
	upgrade_manager.free()
