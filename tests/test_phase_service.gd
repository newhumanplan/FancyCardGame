extends Node

var _total: int = 0
var _passed: int = 0

func _ready() -> void:
	if not Engine.is_editor_hint():
		print("== tests/test_phase_service.gd ==")
		_run_tests()
		_print_summary()

func _run_tests() -> void:
	test_build_hours()
	test_battle_hours()
	test_day_length_wrap_index()

func test_build_hours() -> void:
	for hour in [0, 1, 3, 4]:
		_assert_true(PhaseService.can_shop(hour), "hour %d allows build/shop" % hour)
		_assert_true(not PhaseService.can_battle(hour), "hour %d does not allow battle" % hour)

func test_battle_hours() -> void:
	_assert_true(PhaseService.is_pve_phase(2), "hour 2 is PvE")
	_assert_true(PhaseService.is_pvp_phase(5), "hour 5 is PvP")
	_assert_true(PhaseService.can_battle(2), "hour 2 allows battle")
	_assert_true(PhaseService.can_battle(5), "hour 5 allows battle")
	_assert_true(not PhaseService.can_shop(5), "hour 5 does not allow shop")

func test_day_length_wrap_index() -> void:
	_assert_eq(PhaseService.MAX_HOURS_PER_DAY, 6, "day has six hours")
	_assert_eq(PhaseService.get_hour_index(6), 0, "hour 6 wraps to 0")
	_assert_eq(PhaseService.get_hour_index(-1), 5, "negative hour wraps to PvP")

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
