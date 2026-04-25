extends Node

## BattleProgressionService - 战斗/声望影响/胜负统计
## 从 GameManager 提取

const PVP_WINS_FOR_CLEAR: int = 10

signal battle_result_applied(result: Dictionary)

func _ready() -> void:
	# Autoloads are available in _ready()
	print("BattleProgressionService ready")

func record_battle_win() -> void:
	_record_win()

func record_battle_loss() -> void:
	_record_loss()

func on_battle_win() -> void:
	apply_battle_result(true, false)

func on_battle_lose() -> void:
	apply_battle_result(false, false)

func on_pvp_win() -> void:
	apply_battle_result(true, true)

func on_pvp_lose() -> void:
	apply_battle_result(false, true)

func apply_battle_result(won: bool, is_pvp: bool, monster = null) -> Dictionary:
	var result: Dictionary = {
		"won": won,
		"is_pvp": is_pvp,
		"gold_reward": 0,
		"prestige_loss": 0,
		"pvp_wins": RunStateService.pvp_wins,
		"run_won": false,
		"run_failed": false,
		"last_chance": false,
	}

	if won:
		_record_win()
		if is_pvp:
			var pvp_win_count: int = RunStateService.add_pvp_win()
			result["pvp_wins"] = pvp_win_count
			result["run_won"] = pvp_win_count >= PVP_WINS_FOR_CLEAR
			print("PvP 胜利! PvP胜场: %d/%d" % [pvp_win_count, PVP_WINS_FOR_CLEAR])
		else:
			var reward: Dictionary = _get_monster_reward(monster)
			var reward_summary: Dictionary = RewardService.apply_reward(reward, "pve_win")
			result["reward"] = reward
			result["reward_summary"] = reward_summary
			result["gold_reward"] = int(reward_summary.get("gold", 0))
			result["xp_reward"] = int(reward_summary.get("xp", 0))
			result["level_rewards"] = reward_summary.get("level_rewards", [])
			print("PvE 胜利! 金币+%d XP+%d" % [int(result["gold_reward"]), int(result["xp_reward"])])
	else:
		_record_loss()
		if is_pvp:
			var penalty: int = RunStateService.current_day
			var prestige_result: Dictionary = RunStateService.remove_prestige(penalty)
			result["prestige_loss"] = penalty
			result["last_chance"] = bool(prestige_result.get("last_chance", false))
			result["run_failed"] = bool(prestige_result.get("run_failed", false))
			print("PvP 失败! 声望-%d" % penalty)
		else:
			print("PvE 战斗失败!")

	battle_result_applied.emit(result)
	return result

func _record_win() -> void:
	RunStateService.wins += 1
	GameManager.record_battle_win()

func _record_loss() -> void:
	RunStateService.losses += 1
	RunStateService.wins = 0
	GameManager.record_battle_loss()

func _get_monster_reward(monster) -> Dictionary:
	if monster != null and monster.has_method("get_reward"):
		return monster.get_reward()
	var reward: Dictionary = {}
	if monster != null and monster.has_method("get_gold_reward"):
		reward["gold"] = int(monster.get_gold_reward())
	if monster != null:
		var xp_value = monster.get("xp_reward")
		if xp_value != null:
			reward["xp"] = int(xp_value)
	return reward

func buy_prestige(amount: int, cost: int) -> bool:
	if EconomyService == null or RunStateService == null:
		return false
	if not EconomyService.spend_gold(cost):
		return false
	RunStateService.add_prestige(amount)
	return true

func gold_upgrade() -> void:
	if RunStateService:
		RunStateService.prestige = 1
		RunStateService.last_chance_used = true
		RunStateService.prestige_zero_count = 1
		RunStateService.prestige_changed.emit(RunStateService.prestige)

func full_reset() -> void:
	if RunStateService:
		RunStateService.reset(true)
	if EconomyService:
		EconomyService.reset()
	if HeroStateService:
		HeroStateService.reset()
