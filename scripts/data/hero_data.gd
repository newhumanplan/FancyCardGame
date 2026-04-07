class_name HeroData
extends Resource

## 英雄类型枚举
enum HeroType { WARRIOR, MAGE }

## ============ 基础属性 ============

## 英雄名称
@export var hero_name: String = "英雄"

## 英雄类型
@export var hero_type: HeroType = HeroType.WARRIOR

## 最大生命值
@export var max_hp: int = 100

## 暴击几率（英雄基础暴击率，物品触发时使用）
@export var crit_chance: float = 0.05

## 当前生命值（运行时）
var current_hp: int = 100

## ============ 被动技能 ============

## 被动技能名称
@export var passive_skill_name: String = ""

## 被动技能描述
@export var passive_skill_description: String = ""

## 被动技能加成类型 ("health", "crit", "shield_bonus", "cooldown_reduction")
@export var passive_bonus_type: String = ""

## 被动技能加成值
@export var passive_bonus_value: float = 0.0

## ============ 技能与物品 ============

## 技能列表
@export var skills: Array[SkillData] = []

## 可用物品 ID 列表
@export var available_items: Array[String] = []

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
## damage: 伤害值
## 返回: 实际受到的伤害
func take_damage(damage: int) -> int:
	var actual_damage: int = damage
	current_hp = maxi(current_hp - actual_damage, 0)
	return actual_damage

## 治疗
func heal(heal_amount: int):
	current_hp = mini(current_hp + heal_amount, max_hp)

## 是否存活
func is_alive() -> bool:
	return current_hp > 0

## 获取生命值百分比
func get_hp_percent() -> float:
	if max_hp <= 0:
		return 0.0
	return float(current_hp) / float(max_hp)

## ============ 工具方法 ============

## 获取类型名称
func get_type_name() -> String:
	match hero_type:
		HeroType.WARRIOR: return "战士"
		HeroType.MAGE: return "法师"
		_: return "未知"

## 检查是否暴击
func roll_crit() -> bool:
	return randf() < crit_chance

## 是否有被动技能
func has_passive_skill() -> bool:
	return passive_skill_name != ""

## 获取被动技能描述完整文本
func get_passive_skill_full_description() -> String:
	if not has_passive_skill():
		return ""
	return "%s: %s" % [
		passive_skill_name,
		passive_skill_description
	]
