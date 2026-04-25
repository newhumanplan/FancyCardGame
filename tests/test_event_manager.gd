extends Node


class MockHero:
	extends RefCounted
	var crit_chance: float = 0.10


class MockGameManager:
	extends Node
	var gold: int = 0
	var health: int = 0
	var max_health_value: int = 0
	var prestige: int = 0
	var damage_taken: int = 0
	var selected_hero = null

	func setup() -> void:
		set("gold", 50)
		set("health", 40)
		set("max_health_value", 100)
		set("prestige", 0)
		set("damage_taken", 0)
		set("selected_hero", MockHero.new())

	func add_gold(amount: int) -> void:
		gold += amount

	func spend_gold(amount: int) -> void:
		gold -= amount

	func heal(amount: int) -> void:
		health = mini(health + amount, max_health_value)

	func take_damage(amount: int) -> void:
		damage_taken += amount
		health = maxi(health - amount, 0)

	func add_prestige(amount: int) -> void:
		prestige += amount

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
		for option in options:
			types.append(str(option["type"]))
			if option["type"] == "random_event":
				saw_random_event = true
				if not registered_ids.has(option.get("event_id", "")):
					random_event_is_registered = false
		if "monster" in types or "pvp" in types:
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

	_assert_eq(manager.get_event_count(), 12, "get_event_count returns registered random event count")
	_assert_true(fresh_events[0]["name"] != "mutated", "get_all_events returns a deep copy")


func test_execute_random_event_for_each_event_id() -> void:
	var manager = _manager()
	var cases = [
		{"id": "merchant_bonus", "day": 2, "gold": 62, "health": 40, "prestige": 0, "damage_taken": 0, "crit": 0.10, "text": "12"},
		{"id": "healing_fountain", "day": 2, "gold": 50, "health": 65, "prestige": 0, "damage_taken": 0, "crit": 0.10, "text": "25"},
		{"id": "pickpocket", "day": 2, "gold": 41, "health": 40, "prestige": 0, "damage_taken": 0, "crit": 0.10, "text": "9"},
		{"id": "treasure", "day": 2, "gold": 66, "health": 40, "prestige": 0, "damage_taken": 0, "crit": 0.10, "text": "16"},
		{"id": "heal", "day": 2, "gold": 50, "health": 59, "prestige": 0, "damage_taken": 0, "crit": 0.10, "text": "19"},
		{"id": "bandits", "day": 2, "gold": 50, "health": 29, "prestige": 0, "damage_taken": 11, "crit": 0.10, "text": "11"},
		{"id": "wounded_hero", "day": 2, "gold": 55, "health": 40, "prestige": 3, "damage_taken": 0, "crit": 0.10, "text": "+3"},
		{"id": "storm", "day": 2, "gold": 43, "health": 37, "prestige": 0, "damage_taken": 3, "crit": 0.10, "text": "7"},
		{"id": "strange_merchant", "day": 2, "gold": 76, "health": 35, "prestige": 0, "damage_taken": 5, "crit": 0.10, "text": "26"},
		{"id": "ancient_shrine", "day": 2, "gold": 50, "health": 40, "prestige": 0, "damage_taken": 0, "crit": 0.13, "text": "3.0"},
		{"id": "thief_guild", "day": 2, "gold": 41, "health": 40, "prestige": 0, "damage_taken": 0, "crit": 0.10, "text": "9"},
		{"id": "blessed_rest", "day": 2, "gold": 55, "health": 73, "prestige": 0, "damage_taken": 0, "crit": 0.10, "text": "33"},
	]

	for case_data in cases:
		var game_manager = _game_manager()
		var result = manager.execute_random_event(case_data["id"], case_data["day"], game_manager)
		_assert_eq(game_manager.gold, case_data["gold"], "execute_random_event updates gold for %s" % case_data["id"])
		_assert_eq(game_manager.health, case_data["health"], "execute_random_event updates health for %s" % case_data["id"])
		_assert_eq(game_manager.prestige, case_data["prestige"], "execute_random_event updates prestige for %s" % case_data["id"])
		_assert_eq(game_manager.damage_taken, case_data["damage_taken"], "execute_random_event updates damage for %s" % case_data["id"])
		_assert_true(absf(game_manager.selected_hero.crit_chance - float(case_data["crit"])) <= 0.001, "execute_random_event updates hero crit for %s" % case_data["id"])
		_assert_true(str(case_data["text"]) in result, "execute_random_event result mentions expected amount for %s" % case_data["id"])
		game_manager.free()
