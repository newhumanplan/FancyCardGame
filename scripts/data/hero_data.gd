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

## 当前护盾值（运行时）
var current_shield: float = 0.0

## ============ 技能系统运行时状态 ============

var skill_crit_bonus: float = 0.0
var skill_shield_bonus: float = 0.0
var skill_burn_bonus: float = 0.0
var skill_poison_bonus: float = 0.0
var skill_freeze_bonus: float = 0.0
var skill_haste_bonus: float = 0.0
var skill_charge_bonus: float = 0.0
var skill_health_bonus: float = 0.0
var skill_cooldown_reduction: float = 0.0

var _skill_base_max_hp: int = -1
var _skill_base_crit_chance: float = -1.0

## ============ 被动技能（统一使用 PassiveSkillDataClass） ============

const PassiveSkillType = preload("res://scripts/data/passive_skill.gd")

## 英雄专属被动技能列表
var passive_skills: Array = []  ## Array[PassiveSkillData]

## ============ 战斗被动加成（由 passive_skill.gd apply_to_hero 设置）============

var _combat_bonus_shield: float = 0.0    ## 战斗开始护盾（转治疗）
var _combat_cd_reduction: float = 0.0    ## 冷却缩减百分比
var _combat_reflect: float = 0.0         ## 伤害反弹百分比
var _combat_lifesteal: float = 0.0       ## 生命偷取百分比

## ============ 技能与物品 ============

## 技能列表
@export var skills: Array = []

## 可用物品 ID 列表
@export var available_items: Array[String] = []

## ============ 初始化方法 ============

func _init():
	current_hp = max_hp
	current_shield = 0.0
	_capture_skill_base_stats()

## ============ 运行时方法 ============

## 重置生命值
func reset_hp():
	current_hp = max_hp
	current_shield = 0.0

## 获取当前生命值
func get_current_hp() -> int:
	return current_hp

## 受到伤害（直接扣除，MVP 无防御属性）
## damage: 伤害值
## 返回: 实际受到的伤害
func take_damage(damage: int) -> int:
	var actual_damage: int = maxi(damage, 0)
	current_hp = maxi(current_hp - actual_damage, 0)
	return actual_damage

## 治疗
func heal(heal_amount: int):
	current_hp = mini(current_hp + maxi(heal_amount, 0), max_hp)

## 增加护盾（可叠加，上限为最大生命值）
func add_shield(value: float) -> void:
	if max_hp <= 0:
		current_shield = 0.0
		return
	current_shield = clampf(current_shield + maxf(value, 0.0), 0.0, float(max_hp))

## 移除护盾
## 返回：实际移除的护盾量
func remove_shield(value: float) -> float:
	var shield_to_remove: float = maxf(value, 0.0)
	var removed: float = minf(current_shield, shield_to_remove)
	current_shield = maxf(current_shield - removed, 0.0)
	return removed

## 是否存活
func is_alive() -> bool:
	return current_hp > 0

## 获取生命值百分比
func get_hp_percent() -> float:
	if max_hp <= 0:
		return 0.0
	return float(current_hp) / float(max_hp)

## 获取护盾百分比
func get_shield_ratio() -> float:
	if max_hp <= 0:
		return 0.0
	return clampf(current_shield / float(max_hp), 0.0, 1.0)

func _capture_skill_base_stats() -> void:
	if _skill_base_max_hp < 0:
		_skill_base_max_hp = max_hp
	if _skill_base_crit_chance < 0.0:
		_skill_base_crit_chance = crit_chance

func refresh_skill_base_stats() -> void:
	_skill_base_max_hp = max_hp
	_skill_base_crit_chance = crit_chance

func reset_skill_effects() -> void:
	_capture_skill_base_stats()
	max_hp = _skill_base_max_hp
	crit_chance = _skill_base_crit_chance
	current_hp = mini(current_hp, max_hp)
	skill_crit_bonus = 0.0
	skill_shield_bonus = 0.0
	skill_burn_bonus = 0.0
	skill_poison_bonus = 0.0
	skill_freeze_bonus = 0.0
	skill_haste_bonus = 0.0
	skill_charge_bonus = 0.0
	skill_health_bonus = 0.0
	skill_cooldown_reduction = 0.0

## ============ 工具方法 ============

## 获取类型名称
func get_type_name() -> String:
	match hero_type:
		HeroType.WARRIOR: return "战士"
		HeroType.MAGE: return "法师"
		_: return "未知"

## 检查是否暴击
func roll_crit() -> bool:
	return randf() < clampf(crit_chance, 0.0, 1.0)

