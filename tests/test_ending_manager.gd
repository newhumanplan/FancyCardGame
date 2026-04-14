extends Node


class MockGameManager:
	extends Node
	var pvp_wins: int = 0
	var prestige: int = 0
	var max_prestige: int = 10
	var current_day: int = 1
	var stats_total_wins: int = 0
	var stats_total_losses: int = 0
	var stats_total_gold_earned: int = 0
	var losses: int = 0
	var stats_total_battles: int = 0


var _total: int = 0
var _passed: int = 0


func _ready() -> void:
	print("== test_ending_manager.gd ==")
	_run_tests()
	_print_summary()
	if get_tree():
		get_tree().quit()


func _ending():
	return load("res://scripts/data/ending_manager.gd")


func _game_manager() -> MockGameManager:
	return MockGameManager.new()


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


func _run_tests() -> void:
	test_determine_ending_returns_victory()
	test_determine_ending_returns_perfect()
	test_determine_ending_returns_defeat()
	test_determine_ending_returns_speedrun()
	test_get_ending_description_covers_all_endings()
	test_get_ending_title_covers_all_endings()
	test_generate_summary_includes_key_fields()
	test_collect_data_copies_game_manager_values()


func test_determine_ending_returns_victory() -> void:
	var ending = _ending()
	var game_manager = _game_manager()
	game_manager.pvp_wins = 10
	game_manager.prestige = 5
	game_manager.max_prestige = 10
	game_manager.current_day = 20

	_assert_eq(ending.determine_ending(game_manager), ending.EndingType.VICTORY, "determine_ending returns victory for 10 wins")


func test_determine_ending_returns_perfect() -> void:
	var ending = _ending()
	var game_manager = _game_manager()
	game_manager.pvp_wins = 10
	game_manager.prestige = 10
	game_manager.max_prestige = 10
	game_manager.current_day = 12

	_assert_eq(ending.determine_ending(game_manager), ending.EndingType.PERFECT, "determine_ending returns perfect for full prestige win")


func test_determine_ending_returns_defeat() -> void:
	var ending = _ending()
	var game_manager = _game_manager()
	game_manager.pvp_wins = 3
	game_manager.prestige = 1
	game_manager.current_day = 8

	_assert_eq(ending.determine_ending(game_manager), ending.EndingType.DEFEAT, "determine_ending returns defeat without 10 wins")


func test_determine_ending_returns_speedrun() -> void:
	var ending = _ending()
	var game_manager = _game_manager()
	game_manager.pvp_wins = 10
	game_manager.prestige = 7
	game_manager.max_prestige = 10
	game_manager.current_day = 9

	_assert_eq(ending.determine_ending(game_manager), ending.EndingType.SPEEDRUN, "determine_ending returns speedrun for <=10 day win")


func test_get_ending_description_covers_all_endings() -> void:
	var ending = _ending()
	var ending_types = [
		ending.EndingType.VICTORY,
		ending.EndingType.DEFEAT,
		ending.EndingType.PERFECT,
		ending.EndingType.SPEEDRUN,
		ending.EndingType.SURVIVOR,
	]

	for ending_type in ending_types:
		_assert_true(ending.get_ending_description(ending_type).strip_edges() != "", "get_ending_description returns non-empty text")


func test_get_ending_title_covers_all_endings() -> void:
	var ending = _ending()
	var ending_types = [
		ending.EndingType.VICTORY,
		ending.EndingType.DEFEAT,
		ending.EndingType.PERFECT,
		ending.EndingType.SPEEDRUN,
		ending.EndingType.SURVIVOR,
	]

	for ending_type in ending_types:
		_assert_true(ending.get_ending_title(ending_type).strip_edges() != "", "get_ending_title returns non-empty text")


func test_generate_summary_includes_key_fields() -> void:
	var ending = _ending()
	var game_manager = _game_manager()
	game_manager.current_day = 9
	game_manager.pvp_wins = 10
	game_manager.stats_total_wins = 18
	game_manager.stats_total_losses = 4
	game_manager.stats_total_gold_earned = 230
	game_manager.prestige = 8
	game_manager.max_prestige = 10

	var summary = ending.generate_summary(game_manager, ending.EndingType.SPEEDRUN)

	_assert_contains(summary, "存活天数: 9", "generate_summary includes current day")
	_assert_contains(summary, "PvP胜场: 10/10", "generate_summary includes pvp wins")
	_assert_contains(summary, "总金币: 230", "generate_summary includes total gold")
	_assert_contains(summary, "最终声望: 8/10", "generate_summary includes prestige")
	_assert_contains(summary, "速通大师", "generate_summary includes achievement text for speedrun")


func test_collect_data_copies_game_manager_values() -> void:
	var ending = _ending()
	var manager = ending.new()
	var game_manager = _game_manager()
	game_manager.pvp_wins = 10
	game_manager.prestige = 9
	game_manager.max_prestige = 10
	game_manager.current_day = 15
	game_manager.stats_total_gold_earned = 320
	game_manager.losses = 4
	game_manager.stats_total_battles = 22

	manager.collect_data(game_manager)

	_assert_eq(manager.ending_type, ending.EndingType.VICTORY, "collect_data stores resolved ending type")
	_assert_eq(manager.days_survived, 15, "collect_data stores current day")
	_assert_eq(manager.total_gold, 320, "collect_data stores total gold")
	_assert_eq(manager.pvp_wins, 10, "collect_data stores pvp wins")
	_assert_eq(manager.pvp_losses, 4, "collect_data stores losses")
	_assert_eq(manager.total_battles, 22, "collect_data stores total battles")
	_assert_eq(manager.prestige_at_end, 9, "collect_data stores ending prestige")
