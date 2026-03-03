## 金币管理器
## 自动加载单例，负责管理玩家金币
extends Node

## 当前金币数量
var gold: int = 100

## 信号：金币变化
signal gold_changed(amount: int)

## 获取当前金币
func get_gold() -> int:
	return gold

## 增加金币
func add_gold(amount: int) -> void:
	if amount <= 0:
		return
	gold += amount
	gold_changed.emit(amount)

## 花费金币
func spend_gold(amount: int) -> bool:
	if not can_afford(amount):
		return false
	gold -= amount
	gold_changed.emit(-amount)
	return true

## 检查是否可以购买
func can_afford(amount: int) -> bool:
	return gold >= amount

## 设置金币（用于初始化或重置）
func set_gold(amount: int) -> void:
	var diff := amount - gold
	gold = amount
	gold_changed.emit(diff)

## 重置金币
func reset() -> void:
	gold = 100
	gold_changed.emit(-gold + 100)
