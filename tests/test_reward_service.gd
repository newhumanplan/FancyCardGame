extends Node

const HeroDataClass = preload("res://scripts/data/hero_data.gd")

var _total: int = 0
var _passed: int = 0

func _ready() -> void:
	if not Engine.is_editor_hint():
		print("== tests/test_reward_service.gd ==")
		_run_tests()
		_print_summary()

func _run_tests() -> void:
	test_apply_basic_reward()
	test_level_reward_applies_income_and_max_health()

func _reset_services_with_hero() -> void:
	EconomyService.reset()
	RunStateService.reset(true)
	HeroStateService.reset()
	var hero = HeroFactoryService.create_hero(HeroDataClass.HeroType.WARRIOR)
	GameManager.select_hero(hero)

func test_apply_basic_reward() -> void:
	_reset_services_with_hero()
	GameManager.take_damage(10)
	var summary: Dictionary = RewardService.apply_reward({"gold": 4, "income": 2, "heal": 5}, "test_basic")
	_assert_eq(int(summary["gold"]), 4, "basic reward summary tracks gold")
	_assert_eq(EconomyService.gold, EconomyService.STARTING_GOLD + 4, "basic reward adds gold")
	_assert_eq(EconomyService.income, EconomyService.STARTING_INCOME + 2, "basic reward adds income")
	_assert_eq(HeroStateService.player_health, 115, "basic reward heals current hero")

func test_level_reward_applies_income_and_max_health() -> void:
	_reset_services_with_hero()
	var summary: Dictionary = RewardService.apply_reward({"xp": HeroStateService.XP_PER_LEVEL}, "test_level")
	_assert_eq(HeroStateService.level, 2, "8 XP levels hero to 2")
	_assert_eq(HeroStateService.xp, 0, "level-up consumes XP")
	_assert_eq(EconomyService.income, EconomyService.STARTING_INCOME + 1, "level 2 reward adds income")
	_assert_eq(GameManager.get_max_health(), 125, "level 2 reward adds max health")
	_assert_eq(HeroStateService.player_health, 125, "level 2 max health reward heals by same amount")
	_assert_eq(summary["level_rewards"].size(), 1, "summary includes one level reward")

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
