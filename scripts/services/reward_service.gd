extends Node

## RewardService - run reward application gateway.
## Stateless by design: authoritative values live in EconomyService,
## HeroStateService, and RunStateService.

signal reward_applied(summary: Dictionary)
signal level_reward_applied(level: int, reward: Dictionary, summary: Dictionary)

const DEFAULT_LEVEL_REWARDS: Dictionary = {
	2: {"max_health": 5, "income": 1},
	3: {"max_health": 10, "gold": 3},
	4: {"max_health": 10, "income": 1},
	5: {"max_health": 15, "gold": 5},
}

func apply_reward(reward: Dictionary, source: String = "") -> Dictionary:
	var summary: Dictionary = _new_summary(source)
	if reward.is_empty():
		return summary

	_apply_immediate_reward(reward, summary)

	var xp_amount: int = int(reward.get("xp", 0))
	if xp_amount > 0:
		var xp_result: Dictionary = HeroStateService.add_xp(xp_amount)
		summary["xp"] = int(summary.get("xp", 0)) + xp_amount
		summary["xp_result"] = xp_result
		for level_value in xp_result.get("levels_gained", []):
			var level_reward: Dictionary = get_level_reward(int(level_value))
			if level_reward.is_empty():
				continue
			var level_summary: Dictionary = _new_summary("level_%d" % int(level_value))
			_apply_immediate_reward(level_reward, level_summary)
			summary["level_rewards"].append({
				"level": int(level_value),
				"reward": level_reward,
				"summary": level_summary,
			})
			level_reward_applied.emit(int(level_value), level_reward, level_summary)

	reward_applied.emit(summary)
	return summary

func get_level_reward(level: int) -> Dictionary:
	if DEFAULT_LEVEL_REWARDS.has(level):
		return DEFAULT_LEVEL_REWARDS[level].duplicate(true)
	if level <= 1:
		return {}
	if level % 2 == 0:
		return {"max_health": 10, "income": 1}
	return {"max_health": 5, "gold": 5}

func _new_summary(source: String) -> Dictionary:
	return {
		"source": source,
		"gold": 0,
		"income": 0,
		"xp": 0,
		"max_health": 0,
		"heal": 0,
		"prestige": 0,
		"level_rewards": [],
	}

func _apply_immediate_reward(reward: Dictionary, summary: Dictionary) -> void:
	var gold_amount: int = int(reward.get("gold", 0))
	if gold_amount > 0:
		EconomyService.add_gold(gold_amount)
		GameManager.record_gold_earned(gold_amount)
		summary["gold"] = int(summary.get("gold", 0)) + gold_amount

	var income_amount: int = int(reward.get("income", 0))
	if income_amount != 0:
		EconomyService.add_income(income_amount)
		summary["income"] = int(summary.get("income", 0)) + income_amount

	var max_health_amount: int = int(reward.get("max_health", 0))
	if max_health_amount > 0:
		var applied_health: int = HeroStateService.add_max_health(max_health_amount)
		summary["max_health"] = int(summary.get("max_health", 0)) + applied_health

	var heal_amount: int = int(reward.get("heal", 0))
	if heal_amount > 0:
		HeroStateService.heal(heal_amount)
		summary["heal"] = int(summary.get("heal", 0)) + heal_amount

	var prestige_amount: int = int(reward.get("prestige", 0))
	if prestige_amount > 0:
		RunStateService.add_prestige(prestige_amount)
		summary["prestige"] = int(summary.get("prestige", 0)) + prestige_amount
