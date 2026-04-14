extends Node

var _total: int = 0
var _passed: int = 0


func _ready() -> void:
	print("== tests/test_game_event.gd ==")
	_run_tests()
	_print_summary()
	get_tree().quit()


func _run_tests() -> void:
	test_create_sets_core_fields()
	test_default_values_match_data_definition()
	test_weight_and_day_range_are_assignable()
	test_event_type_enum_and_default_value()


func _event_script():
	return load("res://scripts/data/game_event.gd")


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


func test_create_sets_core_fields() -> void:
	var game_event = _event_script()
	var event = game_event.create("treasure", "宝库", "💎", game_event.EventType.TREASURE, 7)

	_assert_eq(event.event_id, "treasure", "create assigns event id")
	_assert_eq(event.event_name, "宝库", "create assigns event name")
	_assert_eq(event.event_icon, "💎", "create assigns event icon")
	_assert_eq(event.event_type, game_event.EventType.TREASURE, "create assigns event type")
	_assert_eq(event.weight, 7, "create assigns custom weight")


func test_default_values_match_data_definition() -> void:
	var game_event = _event_script()
	var event = game_event.new()

	_assert_eq(event.weight, 10, "default weight is 10")
	_assert_eq(event.min_day, 0, "default min_day is 0")
	_assert_eq(event.max_day, 0, "default max_day is 0")
	_assert_true(not event.is_special, "default is_special is false")
	_assert_eq(event.event_type, game_event.EventType.RANDOM_EVENT, "default event_type is RANDOM_EVENT")


func test_weight_and_day_range_are_assignable() -> void:
	var event = _event_script().new()
	event.weight = 15
	event.min_day = 3
	event.max_day = 8

	_assert_eq(event.weight, 15, "weight can be customized")
	_assert_eq(event.min_day, 3, "min_day can be customized")
	_assert_eq(event.max_day, 8, "max_day can be customized")


func test_event_type_enum_and_default_value() -> void:
	var game_event = _event_script()

	_assert_true(game_event.EventType.SHOP != game_event.EventType.MONSTER, "EventType enum values are distinct")
	_assert_true(game_event.EventType.PVP != game_event.EventType.RANDOM_EVENT, "EventType enum includes pvp and random event")
	_assert_true(game_event.EventType.TREASURE != game_event.EventType.CAMP, "EventType enum includes treasure and camp")
	_assert_true(game_event.EventType.FUTURA >= 0, "EventType enum includes futura")
