extends Node

const HeroDataClass = preload("res://scripts/data/hero_data.gd")
const LinearInventoryClass = preload("res://scripts/data/linear_inventory.gd")

class FixedMonster:
	extends RefCounted
	var reward: Dictionary = {}

	func _init(reward_ref: Dictionary = {}) -> void:
		reward = reward_ref.duplicate(true)

	func get_reward() -> Dictionary:
		return reward.duplicate(true)

var _total: int = 0
var _passed: int = 0

func _ready() -> void:
	if not Engine.is_editor_hint():
		print("== tests/test_battle_progression_service.gd ==")
		_run_tests()
		_print_summary()

func _run_tests() -> void:
	test_pve_win_queues_reward_choice_instead_of_auto_granting_item_or_skill()
	test_pvp_win_counts_without_gold_or_prestige_reward()
	test_pvp_loss_uses_current_day_penalty_and_last_chance()

func _reset_services() -> void:
	RewardService.reset_runtime_state()
	EconomyService.reset()
	RunStateService.reset(true)
	HeroStateService.reset()
	var hero = HeroFactoryService.create_hero(HeroDataClass.HeroType.WARRIOR)
	GameManager.select_hero(hero)
	GameManager.stats_total_battles = 0
	GameManager.stats_total_wins = 0
	GameManager.stats_total_losses = 0
	GameManager.stats_total_gold_earned = 0

func test_pve_win_queues_reward_choice_instead_of_auto_granting_item_or_skill() -> void:
	_reset_services()
	var inventory: LinearInventoryClass = LinearInventoryClass.new()
	var stash: LinearInventoryClass = LinearInventoryClass.new()
	var result: Dictionary = BattleProgressionService.apply_battle_result(
		true,
		false,
		FixedMonster.new({
			"gold": 9,
			"xp": 2,
			"item_pool": [{"id": "scrap", "tier": "Bronze"}],
			"skill_pool": [{"id": "toughness", "tier": "Bronze"}],
		}),
		inventory,
		stash
	)
	_assert_true(bool(result.get("reward_choice_queued", false)), "PvE win queues a reward choice when item or skill rewards exist")
	_assert_eq(int(result["gold_reward"]), 0, "PvE choice queue does not immediately grant gold")
	_assert_eq(int(result["xp_reward"]), 0, "PvE choice queue does not immediately grant XP")
	_assert_eq(EconomyService.gold, EconomyService.STARTING_GOLD, "PvE choice queue keeps gold unchanged before selection")
	_assert_eq(HeroStateService.xp, 0, "PvE choice queue keeps XP unchanged before selection")
	_assert_true(RewardService.has_pending_choice(), "PvE choice queue leaves a pending reward choice")
	_assert_eq(RunStateService.wins, 1, "PvE win still increments win streak")

func test_pvp_win_counts_without_gold_or_prestige_reward() -> void:
	_reset_services()
	var result: Dictionary = BattleProgressionService.apply_battle_result(true, true)
	_assert_eq(int(result["pvp_wins"]), 1, "PvP win increments PvP wins")
	_assert_eq(EconomyService.gold, EconomyService.STARTING_GOLD, "PvP win does not add gold")
	_assert_eq(RunStateService.prestige, RunStateService.STARTING_PRESTIGE, "PvP win does not add prestige")

func test_pvp_loss_uses_current_day_penalty_and_last_chance() -> void:
	_reset_services()
	RunStateService.current_day = 4
	RunStateService.prestige = 3
	var first_loss: Dictionary = BattleProgressionService.apply_battle_result(false, true)
	_assert_eq(int(first_loss["prestige_loss"]), 4, "PvP loss penalty equals current day")
	_assert_true(bool(first_loss["last_chance"]), "first prestige zero triggers Last Chance")
	_assert_eq(RunStateService.prestige, 1, "Last Chance restores prestige to 1")

	RunStateService.current_day = 4
	var second_loss: Dictionary = BattleProgressionService.apply_battle_result(false, true)
	_assert_true(bool(second_loss["run_failed"]), "second prestige zero fails the run")

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
