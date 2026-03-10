extends Node

## 游戏管理器 - 管理全局状态

## ============ 基础属性 ============

## 金币
var gold: int = 100

## 当前回合
var current_round: int = 1

## 最大回合
var max_rounds: int = 5

## ============ 英雄系统 ============

## 当前选择的英雄
var selected_hero: HeroData = null

## 玩家生命值
var player_health: int = 100

## ============ Prestige 系统 ============

## Prestige 值
var prestige: int = 10

## 胜场
var wins: int = 0

## 败场
var losses: int = 0

## 信号
signal gold_changed(amount: int)
signal round_changed(round: int)
signal prestige_changed(value: int)
signal health_changed(amount: int)
signal game_over(won: bool)

func _ready() -> void:
	print("GameManager 已初始化")

## ============ 金币管理 ============

## 获取金币
func get_gold() -> int:
	return gold

## 增加金币
func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(amount)

## 花费金币
func spend_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		gold_changed.emit(-amount)
		return true
	return false

## 检查是否足够
func can_afford(amount: int) -> bool:
	return gold >= amount

## ============ 回合管理 ============

## 下一回合
func next_round() -> void:
	current_round += 1
	round_changed.emit(current_round)

## 重置回合
func reset_round() -> void:
	current_round = 1
	round_changed.emit(current_round)

## ============ Prestige 系统 ============

## 计算 Prestige 加成
func get_prestige_bonus() -> float:
	# Prestige 越高，奖励加成越多
	# 公式: 1 + (prestige / 100)
	return 1.0 + (float(prestige) / 100.0)

## 增加 Prestige
func add_prestige(amount: int) -> void:
	prestige += amount
	prestige_changed.emit(prestige)

## Prestige 加成购买
func buy_prestige(amount: int, cost: int) -> bool:
	if spend_gold(cost):
		add_prestige(amount)
		return true
	return false

## 战斗胜利
func on_battle_win() -> void:
	wins += 1
	# 根据连胜增加 Prestige
	var bonus: int = 1
	if wins >= 3:
		bonus = 2
	if wins >= 5:
		bonus = 3
	add_prestige(bonus)

## 战斗失败
func on_battle_lose() -> void:
	losses += 1
	wins = 0  # 重置连胜

## ============ 生命值管理 ============

## 扣除生命值
func take_damage(amount: int) -> void:
	player_health = max(0, player_health - amount)
	health_changed.emit(player_health)
	if player_health <= 0:
		game_over.emit(false)

## 治疗
func heal(amount: int) -> void:
	player_health = min(100, player_health + amount)
	health_changed.emit(player_health)

## ============ 游戏流程 ============

## 重置游戏
func reset() -> void:
	gold = 100
	current_round = 1
	player_health = 100
	wins = 0
	losses = 0
	# Prestige 保留

## 完全重置（Prestige 也重置）
func full_reset() -> void:
	gold = 100
	current_round = 1
	player_health = 100
	prestige = 10
	wins = 0
	losses = 0
