class_name MonsterData
extends Resource

## 怪物等级枚举
enum MonsterTier { TIER_1, TIER_2, TIER_3 }

## ============ 基础属性 ============

## 怪物名称
@export var monster_name: String = "怪物"

## 怪物等级
@export var tier: MonsterTier = MonsterTier.TIER_1

## 最大生命值
@export var max_hp: int = 50

## 攻击力
@export var attack: int = 10

## 防御力
@export var defense: int = 0

## 攻击冷却时间
@export var attack_cooldown: float = 4.0

## 当前生命值（运行时）
var current_hp: int = 50

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

## 受到伤害
## damage: 原始伤害值
## 返回: 实际受到的伤害
func take_damage(damage: int) -> int:
	var actual_damage: int = maxi(damage - defense, 1)  # 至少造成1点伤害
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

## ============ 战斗相关方法 ============

## 攻击冷却是否完毕
func can_attack() -> bool:
	return is_alive()  # 简化版：只要活着就能攻击

## 获取金币奖励
func get_gold_reward() -> int:
	if gold_reward_max <= gold_reward_min:
		return gold_reward_min
	return randi() % (gold_reward_max - gold_reward_min + 1) + gold_reward_min

## 检查是否掉落物品
func should_drop_item() -> bool:
	return randf() < item_drop_chance

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
