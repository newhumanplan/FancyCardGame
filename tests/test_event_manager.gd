extends Node


class MockHero:
	extends RefCounted
	var crit_chance: float = 0.1


class MockGameManager:
	extends Node
	var gold: int = 50
	var health: int = 40
	var max_health: int = 100
	var prestige: int = 0
	var damage_taken: int = 0
	var selected_hero = null

	func add_gold(amount: int) -> void:
		gold += amount

	func spend_gold(amount: int) -> void:
		gold -= amount

	func heal(amount: int) -> void:
		health = mini(health + amount, max_health)

	func take_damage(amount: int) -> void:
		damage_taken += amount
		health = maxi(health - amount, 0)

	func add_prestige(amount: int) -> void:
		prestige += amount

	func get_max_health() -> int:
		return max_health


var _total: int = 0
var _passed: int = 0


func _ready() -> void:
	print("== test_event_manager.gd ==")
	randomize()
	_run_tests()
	_print_summary()
	if get_tree():
		get_tree().quit()


func _run_tests() -> void:
	test_generate_options_returns_pvp_at_hour_4()
	test_generate_options_returns_three_options_outside_pvp_hour()
	test_generate_options_boundary_hour_is_not_pvp()
	test_generate_options_random_event_ids_are_registered()
	test_execute_random_event_merchant_bonus()
	test_execute_random_event_healing_fountain()
	test_execute_random_event_pickpocket()
	test_execute_random_event_treasure()
	test_execute_random_event_heal()
	test_execute_random_event_bandits()
	test_execute_random_event_wounded_hero()
	test_execute_random_event_storm()
	test_execute_random_event_strange_merchant()
	test_execute_random_event_ancient_shrine()
	test_execute_random_event_thief_guild()
	test_execute_random_event_blessed_rest()
	test_execute_random_event_invalid_id()
	test_execute_treasure_event_adds_gold()
	test_execute_camp_event_restores_health_and_prestige()
	test_get_all_events_returns_12_entries()
	test_get_event_count_returns_12()


func _event_manager():
	return load("res://scripts/data/event_manager.gd").new()


func _mock_game_manager() -> MockGameManager:
	var game_manager = MockGameManager.new()
	game_manager.selected_hero = MockHero.new()
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


func _assert_contains(text: String, expected: String, label: String) -> void:
	_assert_true(text.find(expected) != -1, "%s | expected substring=%s actual=%s" % [label, expected, text])


func _print_summary() -> void:
	print("SUMMARY: %d/%d passed" % [_passed, _total])


func test_generate_options_returns_pvp_at_hour_4() -> void:
	var manager = _event_manager()
	var options = manager.generate_options(4, 1)

	_assert_eq(options.size(), 1, "generate_options returns one option at PvP hour")
	_assert_eq(options[0]["type"], "pvp", "generate_options marks hour 4 as pvp")


func test_generate_options_returns_three_options_outside_pvp_hour() -> void:
	var manager = _event_manager()
	var options = manager.generate_options(2, 1)

	_assert_eq(options.size(), 3, "generate_options returns three options outside PvP hour")


func test_generate_options_boundary_hour_is_not_pvp() -> void:
	var manager = _event_manager()
	var options = manager.generate_options(5, 1)
	var only_pvp: bool = options.size() == 1 and options[0]["type"] == "pvp"

	_assert_true(not only_pvp, "generate_options boundary hour 5 is not forced pvp")


func test_generate_options_random_event_ids_are_registered() -> void:
	var manager = _event_manager()
	var event_ids: Dictionary = {}
	for event_data in manager.get_all_events():
		event_ids[event_data["id"]] = true

	var saw_random_event := false
	for _i in range(40):
		for option in manager.generate_options(2, 1):
			if option["type"] == "random_event":
				saw_random_event = true
				_assert_true(event_ids.has(option["event_id"]), "generate_options random event id comes from registered events")
				return

	_assert_true(saw_random_event, "generate_options can produce random_event option across repeated rolls")


func test_execute_random_event_merchant_bonus() -> void:
	var manager = _event_manager()
	var game_manager = _mock_game_manager()

	var result = manager.execute_random_event("merchant_bonus", 2, game_manager)

	_assert_eq(game_manager.gold, 62, "merchant_bonus adds gold")
	_assert_contains(result, "12", "merchant_bonus result mentions amount")


func test_execute_random_event_healing_fountain() -> void:
	var manager = _event_manager()
	var game_manager = _mock_game_manager()

	var result = manager.execute_random_event("healing_fountain", 2, game_manager)

	_assert_eq(game_manager.health, 65, "healing_fountain restores quarter max health")
	_assert_contains(result, "25", "healing_fountain result mentions heal amount")


func test_execute_random_event_pickpocket() -> void:
	var manager = _event_manager()
	var game_manager = _mock_game_manager()

	var result = manager.execute_random_event("pickpocket", 2, game_manager)

	_assert_eq(game_manager.gold, 41, "pickpocket spends expected gold")
	_assert_contains(result, "9", "pickpocket result mentions stolen amount")


func test_execute_random_event_treasure() -> void:
	var manager = _event_manager()
	var game_manager = _mock_game_manager()

	var result = manager.execute_random_event("treasure", 2, game_manager)

	_assert_eq(game_manager.gold, 66, "treasure adds expected gold")
	_assert_contains(result, "16", "treasure result mentions gold amount")


func test_execute_random_event_heal() -> void:
	var manager = _event_manager()
	var game_manager = _mock_game_manager()

	var result = manager.execute_random_event("heal", 2, game_manager)

	_assert_eq(game_manager.health, 59, "heal event restores fixed amount")
	_assert_contains(result, "19", "heal result mentions amount")


func test_execute_random_event_bandits() -> void:
	var manager = _event_manager()
	var game_manager = _mock_game_manager()

	var result = manager.execute_random_event("bandits", 2, game_manager)

	_assert_eq(game_manager.damage_taken, 11, "bandits deals expected damage")
	_assert_contains(result, "11", "bandits result mentions damage")


func test_execute_random_event_wounded_hero() -> void:
	var manager = _event_manager()
	var game_manager = _mock_game_manager()

	var result = manager.execute_random_event("wounded_hero", 2, game_manager)

	_assert_eq(game_manager.gold, 55, "wounded_hero adds gold")
	_assert_eq(game_manager.prestige, 3, "wounded_hero adds prestige")
	_assert_contains(result, "+3", "wounded_hero result mentions prestige")


func test_execute_random_event_storm() -> void:
	var manager = _event_manager()
	var game_manager = _mock_game_manager()

	var result = manager.execute_random_event("storm", 2, game_manager)

	_assert_eq(game_manager.gold, 43, "storm spends gold")
	_assert_eq(game_manager.damage_taken, 3, "storm deals fixed damage")
	_assert_contains(result, "7", "storm result mentions gold loss")


func test_execute_random_event_strange_merchant() -> void:
	var manager = _event_manager()
	var game_manager = _mock_game_manager()

	var result = manager.execute_random_event("strange_merchant", 2, game_manager)

	_assert_eq(game_manager.gold, 76, "strange_merchant adds gold")
	_assert_eq(game_manager.damage_taken, 5, "strange_merchant deals self damage")
	_assert_contains(result, "26", "strange_merchant result mentions gold amount")


func test_execute_random_event_ancient_shrine() -> void:
	var manager = _event_manager()
	var game_manager = _mock_game_manager()

	var result = manager.execute_random_event("ancient_shrine", 2, game_manager)

	_assert_true(game_manager.selected_hero.crit_chance > 0.1, "ancient_shrine increases hero crit chance")
	_assert_contains(result, "3.0", "ancient_shrine result mentions crit bonus percent")


func test_execute_random_event_thief_guild() -> void:
	var manager = _event_manager()
	var game_manager = _mock_game_manager()

	var result = manager.execute_random_event("thief_guild", 2, game_manager)

	_assert_eq(game_manager.gold, 41, "thief_guild spends protection fee")
	_assert_contains(result, "9", "thief_guild result mentions fee")


func test_execute_random_event_blessed_rest() -> void:
	var manager = _event_manager()
	var game_manager = _mock_game_manager()

	var result = manager.execute_random_event("blessed_rest", 2, game_manager)

	_assert_eq(game_manager.health, 73, "blessed_rest heals one third max hp")
	_assert_eq(game_manager.gold, 55, "blessed_rest adds bonus gold")
	_assert_contains(result, "33", "blessed_rest result mentions heal amount")


func test_execute_random_event_invalid_id() -> void:
	var manager = _event_manager()
	var game_manager = _mock_game_manager()

	var result = manager.execute_random_event("missing", 2, game_manager)

	_assert_eq(result, "未知事件!", "invalid event id returns fallback text")


func test_execute_treasure_event_adds_gold() -> void:
	var manager = _event_manager()
	var game_manager = _mock_game_manager()

	var result = manager.execute_treasure_event(3, game_manager)

	_assert_eq(game_manager.gold, 80, "execute_treasure_event adds day-scaled gold")
	_assert_contains(result, "30", "execute_treasure_event result mentions amount")


func test_execute_camp_event_restores_health_and_prestige() -> void:
	var manager = _event_manager()
	var game_manager = _mock_game_manager()

	var result = manager.execute_camp_event(3, game_manager)

	_assert_eq(game_manager.health, 75, "execute_camp_event heals day-scaled amount")
	_assert_eq(game_manager.prestige, 2, "execute_camp_event adds prestige")
	_assert_contains(result, "+2", "execute_camp_event result mentions prestige")


func test_get_all_events_returns_12_entries() -> void:
	var manager = _event_manager()

	_assert_eq(manager.get_all_events().size(), 12, "get_all_events returns all 12 events")


func test_get_event_count_returns_12() -> void:
	var manager = _event_manager()

	_assert_eq(manager.get_event_count(), 12, "get_event_count returns 12")
