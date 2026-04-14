class_name MonsterData
extends Resource

const MonsterAIType = preload("res://scripts/data/monster_ai.gd")

## 怪物等级枚举
enum MonsterTier { TIER_1, TIER_2, TIER_3 }

## ============ 基础属性 ============

## 怪物名称
@export var monster_name: String = "怪物"

## 怪物等级
@export var tier: MonsterTier = MonsterTier.TIER_1

## 最大生命值
@export var max_hp: int = 50

## 当前生命值（运行时）
var current_hp: int = 50

## ============ 怪物物品系统 ============
## 怪物的"武器"：1-3 个物品，各有 damage + cooldown
## 在战斗循环中按 CD 触发，伤害扣玩家 HP

## 怪物物品列表: [{name: String, damage: int, cooldown: float, current_cooldown: float}]
var monster_items: Array = []

## 怪物 AI 行为模式
var ai = null  ## MonsterAI

## ============ 掉落奖励 ============

## 最小金币奖励
@export var gold_reward_min: int = 5

## 最大金币奖励
@export var gold_reward_max: int = 15

## 物品掉落几率
@export var item_drop_chance: float = 0.3

## ============ 初始化方法 ============

func _init():
	current_hp = max_hp

## ============ 运行时方法 ============

## 重置生命值
func reset_hp():
	current_hp = max_hp

## 获取当前生命值
func get_current_hp() -> int:
	return current_hp

## 受到伤害（直接扣除，MVP 无防御属性）
## damage: 原始伤害值
## 返回: 实际受到的伤害
func take_damage(damage: int) -> int:
	var actual_damage: int = damage
	current_hp = maxi(current_hp - actual_damage, 0)
	return actual_damage

## 是否存活
func is_alive() -> bool:
	return current_hp > 0

## 获取生命值百分比
func get_hp_percent() -> float:
	if max_hp <= 0:
		return 0.0
	return float(current_hp) / float(max_hp)

## ============ 怪物物品方法 ============

## 初始化怪物物品冷却（战斗开始时调用）
func init_item_cooldowns() -> void:
	for item in monster_items:
		var cooldown: float = maxf(float(item.get("cooldown", 0.0)), 0.0)
		item["current_cooldown"] = cooldown

## 重置怪物物品冷却（战斗结束时调用）
func reset_item_cooldowns() -> void:
	for item in monster_items:
		if item.has("base_cooldown"):
			item["cooldown"] = item["base_cooldown"]
		item["current_cooldown"] = 0.0

## ============ 战斗相关方法 ============

## 获取金币奖励
func get_gold_reward() -> int:
	if gold_reward_max <= gold_reward_min:
		return gold_reward_min
	return randi() % (gold_reward_max - gold_reward_min + 1) + gold_reward_min

## 检查是否掉落物品
func should_drop_item() -> bool:
	return randf() < clampf(item_drop_chance, 0.0, 1.0)

## ============ 工具方法 ============

## 获取等级名称
func get_tier_name() -> String:
	match tier:
		MonsterTier.TIER_1: return "一级"
		MonsterTier.TIER_2: return "二级"
		MonsterTier.TIER_3: return "三级"
		_: return "未知"

## 获取等级颜色
func get_tier_color() -> Color:
	match tier:
		MonsterTier.TIER_1: return Color.GREEN
		MonsterTier.TIER_2: return Color.BLUE
		MonsterTier.TIER_3: return Color.RED
		_: return Color.WHITE
