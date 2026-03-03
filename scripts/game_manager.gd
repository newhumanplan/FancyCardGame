extends Node

## 游戏管理器 - 管理全局状态

## 金币
var gold: int = 100

## 当前回合
var current_round: int = 1

## 最大回合
var max_rounds: int = 5

## 信号
signal gold_changed(amount: int)
signal round_changed(round: int)

func _ready() -> void:
	print("GameManager 已初始化")

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

## 下一回合
func next_round() -> void:
	current_round += 1
	round_changed.emit(current_round)

## 重置游戏
func reset() -> void:
	gold = 100
	current_round = 1
