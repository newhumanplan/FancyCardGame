extends Node

const HeroDataClass = preload("res://scripts/data/hero_data.gd")
const LinearInventoryClass = preload("res://scripts/data/linear_inventory.gd")

var _total: int = 0
var _passed: int = 0

func _ready() -> void:
	if not Engine.is_editor_hint():
		print("== tests/test_run_progression_rewards.gd ==")
		_run_tests()
		_print_summary()

func _run_tests() -> void:
	test_hour_completion_grants_xp_and_day_income()
	test_eighth_hour_queues_level_reward_choice_until_selected()

func _reset_services_with_hero() -> void:
	RewardService.reset_runtime_state()
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
	_assert_true(not RewardService.has_pending_choice(), "no reward choice is queued before the level-up threshold")

func test_eighth_hour_queues_level_reward_choice_until_selected() -> void:
	_reset_services_with_hero()
	var inventory: LinearInventoryClass = LinearInventoryClass.new()
	var stash: LinearInventoryClass = LinearInventoryClass.new()
	for _i in range(7):
		GameManager.next_hour()

	_assert_eq(HeroStateService.level, 1, "seven completed hours does not level the hero")
	GameManager.next_hour()

	_assert_eq(RunStateService.current_day, 2, "eighth completed hour stays in day 2")
	_assert_eq(RunStateService.current_hour, 2, "eighth completed hour advances into hour 2")
	_assert_eq(HeroStateService.level, 2, "eighth completed hour levels the hero")
	_assert_eq(HeroStateService.xp, 0, "eighth completed hour still consumes XP")
	_assert_true(RewardService.has_pending_choice(), "eighth completed hour queues a level reward choice")
	_assert_eq(EconomyService.income, EconomyService.STARTING_INCOME, "income stays unchanged before the level reward choice resolves")

	var choice: Dictionary = RewardService.get_active_choice()
	var health_index: int = _find_choice_index(choice, "max_health")
	_assert_true(health_index >= 0, "level reward choice offers a max health option")
	if health_index >= 0:
		RewardService.resolve_active_choice(health_index, inventory, stash)
	_assert_true(not RewardService.has_pending_choice(), "resolving the level reward clears the pending choice")
	_assert_true(GameManager.get_max_health() > 120, "selecting the health reward increases max health")

func _find_choice_index(choice: Dictionary, kind: String) -> int:
	var options: Array = choice.get("options", [])
	for index in range(options.size()):
		if options[index] is Dictionary and str((options[index] as Dictionary).get("kind", "")) == kind:
			return index
	return -1

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
