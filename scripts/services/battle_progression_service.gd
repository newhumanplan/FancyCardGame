extends Node

## BattleProgressionService - 战斗/声望影响/胜负统计
## 从 GameManager 提取

const PVP_WINS_FOR_CLEAR: int = 10

func _ready() -> void:
	# Autoloads are available in _ready()
	print("BattleProgressionService ready")

func record_battle_win() -> void:
	if RunState:
		RunState.wins += 1

func record_battle_loss() -> void:
	if RunState:
		RunState.losses += 1

func on_battle_win() -> void:
	if RunState:
		RunState.wins += 1

func on_battle_lose() -> void:
	if RunState:
		RunState.losses += 1

func on_pvp_win() -> void:
	if RunState:
		RunState.pvp_wins += 1
		RunState.add_prestige(3)
	if EconomyService:
		EconomyService.add_gold(10)
	print("PvP 胜利! 声望+3，金币+10 (PVP胜场: %d/%d)" % [RunState.pvp_wins if RunState else 0, PVP_WINS_FOR_CLEAR])

func on_pvp_lose() -> void:
	if RunState:
		var penalty: int = maxi(3, RunState.current_day)
		RunState.remove_prestige(penalty)
		print("PvP 失败! 声望-%d" % penalty)

func buy_prestige(amount: int, cost: int) -> bool:
	if EconomyService == null or RunState == null:
		return false
	if not EconomyService.spend_gold(cost):
		return false
	RunState.add_prestige(amount)
	return true

func gold_upgrade() -> void:
	if RunState:
		RunState.prestige_zero_count = 0
		RunState.prestige = 1
		RunState.add_prestige(1)

func full_reset() -> void:
	if RunState:
		RunState.current_day = 1
		RunState.current_hour = 0
		RunState.wins = 0
		RunState.losses = 0
		RunState.pvp_wins = 0
		RunState.prestige = 20
		RunState.prestige_zero_count = 0
