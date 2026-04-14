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
	print("== tests/test_ending_manager.gd ==")
	_run_tests()
	_print_summary()
	get_tree().quit()


func _run_tests() -> void:
	test_determine_ending_for_victory_defeat_perfect_and_speedrun()
	test_get_ending_title_and_description()
	test_generate_summary_contains_key_stats()
	test_collect_data_copies_runtime_values()


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


func _print_summary() -> void:
	print("SUMMARY: %d/%d passed" % [_passed, _total])


func test_determine_ending_for_victory_defeat_perfect_and_speedrun() -> void:
	var ending = _ending()

	var victory = _game_manager()
	victory.pvp_wins = 10
	victory.prestige = 5
	victory.current_day = 20
	_assert_eq(ending.determine_ending(victory), ending.EndingType.VICTORY, "determine_ending returns victory for standard win")

	var defeat = _game_manager()
	defeat.pvp_wins = 3
	defeat.current_day = 8
	_assert_eq(ending.determine_ending(defeat), ending.EndingType.DEFEAT, "determine_ending returns defeat without enough wins")

	var perfect = _game_manager()
	perfect.pvp_wins = 10
	perfect.prestige = 10
	perfect.max_prestige = 10
	perfect.current_day = 12
	_assert_eq(ending.determine_ending(perfect), ending.EndingType.PERFECT, "determine_ending returns perfect for full prestige win")

	var speedrun = _game_manager()
	speedrun.pvp_wins = 10
	speedrun.prestige = 7
	speedrun.current_day = 9
	_assert_eq(ending.determine_ending(speedrun), ending.EndingType.SPEEDRUN, "determine_ending returns speedrun for 10-day clear")


func test_get_ending_title_and_description() -> void:
	var ending = _ending()

	_assert_eq(ending.get_ending_title(ending.EndingType.VICTORY), "传奇英雄", "get_ending_title returns victory title")
	_assert_true("失败" in ending.get_ending_description(ending.EndingType.DEFEAT), "get_ending_description returns defeat text")
	_assert_true("完美通关" in ending.get_ending_description(ending.EndingType.PERFECT), "get_ending_description returns perfect text")


func test_generate_summary_contains_key_stats() -> void:
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

	_assert_true("存活天数: 9" in summary, "generate_summary includes current day")
	_assert_true("PvP胜场: 10/10" in summary, "generate_summary includes pvp wins")
	_assert_true("总金币: 230" in summary, "generate_summary includes total gold")
	_assert_true("最终声望: 8/10" in summary, "generate_summary includes prestige")
	_assert_true("速通大师" in summary, "generate_summary includes speedrun achievement")


func test_collect_data_copies_runtime_values() -> void:
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
	_assert_eq(manager.pvp_losses, 4, "collect_data stores pvp losses")
	_assert_eq(manager.total_battles, 22, "collect_data stores total battles")
	_assert_eq(manager.prestige_at_end, 9, "collect_data stores ending prestige")
