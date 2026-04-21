class_name MonsterAI
extends RefCounted
const MonsterDataClass = preload("res://scripts/data/monster_data.gd")

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

static func _create_ai(mode: AIMode, config: Dictionary) -> MonsterAI:
	var ai = new()
	ai.ai_mode = mode
	ai.damage_multiplier = float(config.get("damage_multiplier", ai.damage_multiplier))
	ai.heal_chance = float(config.get("heal_chance", ai.heal_chance))
	ai.heal_amount = int(config.get("heal_amount", ai.heal_amount))
	ai.special_effect_chance = float(config.get("special_effect_chance", ai.special_effect_chance))
	ai.special_effect_type = str(config.get("special_effect_type", ai.special_effect_type))
	ai.special_effect_value = int(config.get("special_effect_value", ai.special_effect_value))
	ai.attack_speed_multiplier = float(config.get("attack_speed_multiplier", ai.attack_speed_multiplier))
	ai.low_hp_threshold = float(config.get("low_hp_threshold", ai.low_hp_threshold))
	ai.low_hp_damage_multiplier = float(config.get("low_hp_damage_multiplier", ai.low_hp_damage_multiplier))
	ai.low_hp_heal_chance_bonus = float(config.get("low_hp_heal_chance_bonus", ai.low_hp_heal_chance_bonus))
	return ai

## ============ 预设 AI 配置 ============

## 激进型 AI
static func create_aggressive() -> MonsterAI:
	return _create_ai(AIMode.AGGRESSIVE, {
		"damage_multiplier": 1.3,
		"attack_speed_multiplier": 1.0,
		"low_hp_damage_multiplier": 1.3,
	})

## 防御型 AI
static func create_defensive() -> MonsterAI:
	return _create_ai(AIMode.DEFENSIVE, {
		"damage_multiplier": 0.8,
		"heal_chance": 0.15,
		"heal_amount": 5,
		"attack_speed_multiplier": 0.8,
		"low_hp_heal_chance_bonus": 0.3,
	})

## 技术型 AI
static func create_technical() -> MonsterAI:
	return _create_ai(AIMode.TECHNICAL, {
		"damage_multiplier": 1.0,
		"special_effect_chance": 0.3,
		"special_effect_type": "poison",
		"special_effect_value": 3,
		"attack_speed_multiplier": 0.9,
	})

## Boss AI
static func create_boss() -> MonsterAI:
	return _create_ai(AIMode.BOSS, {
		"damage_multiplier": 1.5,
		"heal_chance": 0.05,
		"heal_amount": 10,
		"special_effect_chance": 0.2,
		"special_effect_type": "burn",
		"special_effect_value": 5,
		"attack_speed_multiplier": 1.2,
		"low_hp_threshold": 0.2,
		"low_hp_damage_multiplier": 1.6,
	})

## 蜂群型 AI
static func create_swarm() -> MonsterAI:
	return _create_ai(AIMode.SWARM, {
		"damage_multiplier": 0.6,
		"attack_speed_multiplier": 2.0,
	})

## ============ 运行时行为 ============

## 低血量治疗概率加成（仅防御/Boss）
var low_hp_heal_chance_bonus: float = 0.0

## 判断是否处于低血量状态
func is_low_hp(monster: MonsterDataClass) -> bool:
	if monster == null:
		return false
	return monster.get_hp_percent() <= low_hp_threshold

## 获取当前伤害倍率
func get_current_damage_multiplier(monster: MonsterDataClass) -> float:
	var mult = damage_multiplier
	if is_low_hp(monster):
		mult = low_hp_damage_multiplier
	return mult

## 判断是否触发自我治疗（每 tick）
func should_heal(monster: MonsterDataClass) -> bool:
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
func apply_to_monster_items(monster: MonsterDataClass) -> void:
	if monster == null:
		return
	var modifier = get_cooldown_modifier()
	for item in monster.monster_items:
		if item.has("cooldown"):
			var base_cooldown: float = float(item.get("base_cooldown", item["cooldown"]))
			item["base_cooldown"] = base_cooldown
			item["cooldown"] = maxf(base_cooldown * modifier, 0.1)
