extends Node

const HeroDataClass = preload("res://scripts/data/hero_data.gd")

var _total: int = 0
var _passed: int = 0

func _ready() -> void:
	if not Engine.is_editor_hint():
		print("== tests/test_battle_end_full_heal.gd ==")
		_run_tests()
		_print_summary()

func _run_tests() -> void:
	test_pve_win_restores_current_max_health()
	test_pvp_win_restores_current_max_health()
	test_continuing_pvp_loss_restores_current_max_health()
	test_terminal_pvp_loss_does_not_mask_run_failure()

func _reset_with_wounded_hero(max_health: int, current_health: int) -> void:
	RewardService.reset_runtime_state()
	EconomyService.reset()
	RunStateService.reset(true)
	HeroStateService.reset()
	var hero = HeroFactoryService.create_hero(HeroDataClass.HeroType.WARRIOR)
	hero.max_hp = max_health
	hero.current_hp = current_health
	GameManager.select_hero(hero)
	GameManager.player_health = current_health
	GameManager.stats_total_battles = 0
	GameManager.stats_total_wins = 0
	GameManager.stats_total_losses = 0

func test_pve_win_restores_current_max_health() -> void:
	_reset_with_wounded_hero(137, 42)
	var result: Dictionary = BattleProgressionService.apply_battle_result(true, false)
	_assert_true(bool(result.get("health_restored", false)), "PvE win marks health restored")
	_assert_eq(GameManager.player_health, 137, "PvE win restores player health to current max")
	_assert_eq(GameManager.selected_hero.current_hp, 137, "PvE win syncs selected hero current HP")
	_assert_eq(int(result.get("player_max_health", 0)), 137, "PvE win records current max health")

func test_pvp_win_restores_current_max_health() -> void:
	_reset_with_wounded_hero(151, 9)
	var result: Dictionary = BattleProgressionService.apply_battle_result(true, true)
	_assert_true(bool(result.get("health_restored", false)), "PvP win marks health restored")
	_assert_eq(GameManager.player_health, 151, "PvP win restores player health to current max")
	_assert_eq(GameManager.selected_hero.current_hp, 151, "PvP win syncs selected hero current HP")

func test_continuing_pvp_loss_restores_current_max_health() -> void:
	_reset_with_wounded_hero(129, 17)
	RunStateService.current_day = 4
	RunStateService.prestige = 3
	var result: Dictionary = BattleProgressionService.apply_battle_result(false, true)
	_assert_true(bool(result.get("last_chance", false)), "first prestige-zero PvP loss continues through Last Chance")
	_assert_true(not bool(result.get("run_failed", false)), "first prestige-zero PvP loss is not terminal")
	_assert_true(bool(result.get("health_restored", false)), "continuing PvP loss marks health restored")
	_assert_eq(GameManager.player_health, 129, "continuing PvP loss restores player health to current max")

func test_terminal_pvp_loss_does_not_mask_run_failure() -> void:
	_reset_with_wounded_hero(144, 23)
	RunStateService.current_day = 4
	RunStateService.prestige = 1
	RunStateService.last_chance_used = true
	RunStateService.prestige_zero_count = 1
	var result: Dictionary = BattleProgressionService.apply_battle_result(false, true)
	_assert_true(bool(result.get("run_failed", false)), "second prestige-zero PvP loss remains terminal")
	_assert_true(not bool(result.get("health_restored", true)), "terminal run failure does not mark health restored")
	_assert_eq(GameManager.player_health, 23, "terminal run failure does not hide the failed combat health state")

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
