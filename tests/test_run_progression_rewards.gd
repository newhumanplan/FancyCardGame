extends Node

const HeroDataClass = preload("res://scripts/data/hero_data.gd")

var _total: int = 0
var _passed: int = 0

func _ready() -> void:
	if not Engine.is_editor_hint():
		print("== tests/test_run_progression_rewards.gd ==")
		_run_tests()
		_print_summary()

func _run_tests() -> void:
	test_hour_completion_grants_xp_and_day_income()

func _reset_services_with_hero() -> void:
	EconomyService.reset()
	RunStateService.reset(true)
	HeroStateService.reset()
	var hero = HeroFactoryService.create_hero(HeroDataClass.HeroType.WARRIOR)
	GameManager.select_hero(hero)

func test_hour_completion_grants_xp_and_day_income() -> void:
	_reset_services_with_hero()
	for _i in range(6):
		GameManager.next_hour()

	_assert_eq(RunStateService.current_day, 2, "six completed hours advances to day 2")
	_assert_eq(RunStateService.current_hour, 0, "six completed hours wraps hour to 0")
	_assert_eq(HeroStateService.xp, 6, "each completed hour grants 1 XP")
	_assert_eq(EconomyService.gold, EconomyService.STARTING_GOLD + EconomyService.STARTING_INCOME, "new day grants income gold")

	GameManager.next_hour()
	GameManager.next_hour()

	_assert_eq(HeroStateService.level, 2, "eight completed hours levels hero to 2")
	_assert_eq(HeroStateService.xp, 0, "level-up consumes 8 XP")
	_assert_eq(EconomyService.income, EconomyService.STARTING_INCOME + 1, "level 2 reward increases income")

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
