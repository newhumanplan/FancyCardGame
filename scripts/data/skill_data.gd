class_name SkillData
extends Resource

## 技能类型枚举
enum SkillType { ATTACK, BUFF, DEBUFF, HEAL }

## 技能名称
@export var skill_name: String = "技能"

## 技能描述
@export var description: String = ""

## 技能类型
@export var skill_type: SkillType = SkillType.ATTACK

## 技能冷却时间
@export var cooldown: float = 5.0

## 当前冷却时间（运行时）
var current_cooldown: float = 0.0

## 技能效果值（伤害/治疗量等）
@export var effect_value: int = 0

## 技能消耗（mana/能量等）
@export var cost: int = 0

## ============ 运行时方法 ============

## 检查技能是否可用
func can_use() -> bool:
	return current_cooldown <= 0

## 使用技能
func use():
	if can_use():
		current_cooldown = cooldown

## 重置冷却
func reset_cooldown():
	current_cooldown = 0.0

## 减少冷却（每帧调用）
## delta: 时间增量
func reduce_cooldown(delta: float):
	current_cooldown = maxf(current_cooldown - delta, 0.0)

## ============ 工具方法 ============

## 获取类型名称
func get_type_name() -> String:
	match skill_type:
		SkillType.ATTACK: return "攻击"
		SkillType.BUFF: return "增益"
		SkillType.DEBUFF: return "减益"
		SkillType.HEAL: return "治疗"
		_: return "未知"
