extends Node

## EconomyService - 金币管理
## 从 GameManager 提取

signal gold_changed(amount: int)
signal income_changed(amount: int)

const STARTING_GOLD: int = 15
const STARTING_INCOME: int = 7

var gold: int = STARTING_GOLD
var income: int = STARTING_INCOME
var total_gold_earned: int = 0

func get_gold() -> int:
	return gold

func add_gold(amount: int) -> void:
	if amount <= 0:
		return
	gold += amount
	total_gold_earned += amount
	gold_changed.emit(gold)

func spend_gold(amount: int) -> bool:
	if amount < 0:
		return false
	if gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true

func can_afford(amount: int) -> bool:
	return gold >= amount

func add_income(amount: int) -> void:
	if amount == 0:
		return
	income = maxi(income + amount, 0)
	income_changed.emit(income)

func reset() -> void:
	gold = STARTING_GOLD
	income = STARTING_INCOME
	total_gold_earned = 0
	gold_changed.emit(gold)
	income_changed.emit(income)
