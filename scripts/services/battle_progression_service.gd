extends Node

## BattleProgressionService - 战斗/声望影响/胜负统计
## 从 GameManager 提取

const PVP_WINS_FOR_CLEAR: int = 10

func _ready() -> void:
	# Autoloads are available in _ready()
	print("BattleProgressionService ready")

func record_battle_win() -> void:
	if RunStateService:
		RunStateService.wins += 1

func record_battle_loss() -> void:
	if RunStateService:
		RunStateService.losses += 1

func on_battle_win() -> void:
	if RunStateService:
		RunStateService.wins += 1

func on_battle_lose() -> void:
	if RunStateService:
		RunStateService.losses += 1

func on_pvp_win() -> void:
	if RunStateService:
		RunStateService.pvp_wins += 1
		RunStateService.add_prestige(3)
	if EconomyService:
		EconomyService.add_gold(10)
	print("PvP 胜利! 声望+3，金币+10 (PVP胜场: %d/%d)" % [RunStateService.pvp_wins if RunStateService else 0, PVP_WINS_FOR_CLEAR])

func on_pvp_lose() -> void:
	if RunStateService:
		var penalty: int = maxi(3, RunStateService.current_day)
		RunStateService.remove_prestige(penalty)
		print("PvP 失败! 声望-%d" % penalty)

func buy_prestige(amount: int, cost: int) -> bool:
	if EconomyService == null or RunStateService == null:
		return false
	if not EconomyService.spend_gold(cost):
		return false
	RunStateService.add_prestige(amount)
	return true

func gold_upgrade() -> void:
	if RunStateService:
		RunStateService.prestige_zero_count = 0
		RunStateService.prestige = 1
		RunStateService.add_prestige(1)

func full_reset() -> void:
	if RunStateService:
		RunStateService.current_day = 1
		RunStateService.current_hour = 0
		RunStateService.wins = 0
		RunStateService.losses = 0
		RunStateService.pvp_wins = 0
		RunStateService.prestige = 20
		RunStateService.prestige_zero_count = 0
