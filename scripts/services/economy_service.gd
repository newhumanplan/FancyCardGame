extends Node

## EconomyService - 金币管理
## 从 GameManager 提取

signal gold_changed(amount: int)

var gold: int = 100
var total_gold_earned: int = 0

func get_gold() -> int:
	return gold

func add_gold(amount: int) -> void:
	gold += amount
	total_gold_earned += amount
	gold_changed.emit(gold)

func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true

func can_afford(amount: int) -> bool:
	return gold >= amount

func reset() -> void:
	gold = 100
	total_gold_earned = 0
