class_name MonsterAI
extends RefCounted

## 怪物 AI 系统 — 定义怪物行为模式
## 不同怪物有不同的 AI 策略，影响战斗中的行为

## AI 行为模式
enum AIMode {
	AGGRESSIVE,    ## 激进型：优先攻击，伤害加成
	DEFENSIVE,     ## 防御型：受伤时降低伤害输出，有自我治疗
	TECHNICAL,     ## 技术型：使用特殊效果（中毒/燃烧）
	BOSS,          ## Boss型：高血量+多物品+强化属性
	SWARM,         ## 蜂群型：频繁低伤害攻击
}

## AI 行为数据
var ai_mode: AIMode = AIMode.AGGRESSIVE

## 伤害倍率（基于 AI 模式调整）
var damage_multiplier: float = 1.0

## 治疗概率（每 tick 概率触发自我治疗）
var heal_chance: float = 0.0

## 治疗量
var heal_amount: int = 0

## 特殊效果概率（中毒/燃烧附加）
var special_effect_chance: float = 0.0

## 特殊效果类型 ("poison", "burn", "freeze")
var special_effect_type: String = "poison"

## 特殊效果值
var special_effect_value: int = 0

## 攻击频率倍率（影响冷却缩减）
var attack_speed_multiplier: float = 1.0

## 低血量阈值（低于此血量触发特殊行为）
var low_hp_threshold: float = 0.3

## 低血量时伤害倍率
var low_hp_damage_multiplier: float = 1.0

## ============ 预设 AI 配置 ============

## 激进型 AI
static func create_aggressive() -> MonsterAI:
	var ai = new()
	ai.ai_mode = AIMode.AGGRESSIVE
	ai.damage_multiplier = 1.3
	ai.attack_speed_multiplier = 1.0
	ai.low_hp_damage_multiplier = 1.3  ## 狂暴模式
	return ai

## 防御型 AI
static func create_defensive() -> MonsterAI:
	var ai = new()
	ai.ai_mode = AIMode.DEFENSIVE
	ai.damage_multiplier = 0.8
	ai.heal_chance = 0.15
	ai.heal_amount = 5
	ai.attack_speed_multiplier = 0.8
	ai.low_hp_heal_chance_bonus = 0.3  ## 低血量时治疗概率+30%
	return ai

## 技术型 AI
static func create_technical() -> MonsterAI:
	var ai = new()
	ai.ai_mode = AIMode.TECHNICAL
	ai.damage_multiplier = 1.0
	ai.special_effect_chance = 0.3
	ai.special_effect_type = "poison"
	ai.special_effect_value = 3
	ai.attack_speed_multiplier = 0.9
	return ai

## Boss AI
static func create_boss() -> MonsterAI:
	var ai = new()
	ai.ai_mode = AIMode.BOSS
	ai.damage_multiplier = 1.5
	ai.heal_chance = 0.05
	ai.heal_amount = 10
	ai.special_effect_chance = 0.2
	ai.special_effect_type = "burn"
	ai.special_effect_value = 5
	ai.attack_speed_multiplier = 1.2
	ai.low_hp_threshold = 0.2
	ai.low_hp_damage_multiplier = 1.6  ## Boss 狂暴
	return ai

## 蜂群型 AI
static func create_swarm() -> MonsterAI:
	var ai = new()
	ai.ai_mode = AIMode.SWARM
	ai.damage_multiplier = 0.6
	ai.attack_speed_multiplier = 2.0  ## 攻击频率翻倍
	return ai

## ============ 运行时行为 ============

## 低血量治疗概率加成（仅防御/Boss）
var low_hp_heal_chance_bonus: float = 0.0

## 判断是否处于低血量状态
func is_low_hp(monster: MonsterData) -> bool:
	return monster.get_hp_percent() <= low_hp_threshold

## 获取当前伤害倍率
func get_current_damage_multiplier(monster: MonsterData) -> float:
	var mult = damage_multiplier
	if is_low_hp(monster):
		mult = low_hp_damage_multiplier
	return mult

## 判断是否触发自我治疗（每 tick）
func should_heal(monster: MonsterData) -> bool:
	var chance = heal_chance
	if is_low_hp(monster) and low_hp_heal_chance_bonus > 0:
		chance += low_hp_heal_chance_bonus
	return randf() < clampf(chance, 0.0, 1.0)

## 判断是否附加特殊效果
func should_apply_special() -> bool:
	return randf() < clampf(special_effect_chance, 0.0, 1.0)

## 获取冷却缩减（基于攻击速度倍率）
func get_cooldown_modifier() -> float:
	return 1.0 / maxf(attack_speed_multiplier, 0.1)

## 获取 AI 模式名称
func get_mode_name() -> String:
	match ai_mode:
		AIMode.AGGRESSIVE: return "激进"
		AIMode.DEFENSIVE: return "防御"
		AIMode.TECHNICAL: return "技术"
		AIMode.BOSS: return "Boss"
		AIMode.SWARM: return "蜂群"
		_: return "普通"

## 根据 AI 模式调整物品冷却（在战斗开始时调用）
func apply_to_monster_items(monster: MonsterData) -> void:
	var modifier = get_cooldown_modifier()
	for item in monster.monster_items:
		if item.has("cooldown"):
			var base_cooldown: float = float(item.get("base_cooldown", item["cooldown"]))
			item["base_cooldown"] = base_cooldown
			item["cooldown"] = maxf(base_cooldown * modifier, 0.1)
