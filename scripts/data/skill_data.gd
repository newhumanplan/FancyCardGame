class_name SkillData
extends Resource

## 技能品质枚举
enum Quality { BRONZE, SILVER, GOLD, DIAMOND }

## 技能效果类型
enum EffectType { CRIT, SHIELD, BURN, POISON, FREEZE, HASTE, CHARGE, HEALTH, COOLDOWN }

## 技能ID
@export var skill_id: String = ""

## 技能名称
@export var skill_name: String = "技能"

## 技能描述
@export var description: String = ""

## 技能品质
@export var quality: Quality = Quality.BRONZE

## 效果类型
@export var effect_type: EffectType = EffectType.CRIT

## 效果数值（按品质递增）: [Bronze, Silver, Gold, Diamond]
@export var effect_values: Array[float] = [0.0, 0.0, 0.0, 0.0]

## 所属英雄（空字符串=通用技能）
@export var hero_id: String = ""

## 是否已解锁
var unlocked: bool = false

## 获取当前品质对应的效果值
func get_effect_value() -> float:
	var idx: int = quality as int
	if idx >= 0 and idx < effect_values.size():
		return maxf(effect_values[idx], 0.0)
	return 0.0

## 获取品质名称
func get_quality_name() -> String:
	match quality:
		Quality.BRONZE: return "铜"
		Quality.SILVER: return "银"
		Quality.GOLD: return "金"
		Quality.DIAMOND: return "钻"
		_: return "未知"

## 获取效果类型名称
func get_effect_type_name() -> String:
	match effect_type:
		EffectType.CRIT: return "暴击"
		EffectType.SHIELD: return "护盾"
		EffectType.BURN: return "燃烧"
		EffectType.POISON: return "中毒"
		EffectType.FREEZE: return "冰冻"
		EffectType.HASTE: return "急速"
		EffectType.CHARGE: return "充能"
		EffectType.HEALTH: return "生命"
		EffectType.COOLDOWN: return "冷却"
		_: return "未知"

## 从字典创建（用于JSON加载）
static func from_dict(data: Dictionary) -> SkillData:
	var skill = SkillData.new()
	if data.has("skill_id"): skill.skill_id = data["skill_id"]
	if data.has("skill_name"): skill.skill_name = data["skill_name"]
	if data.has("description"): skill.description = data["description"]
	if data.has("hero_id"): skill.hero_id = data["hero_id"]
	if data.has("effect_type"):
		var type_str: String = data["effect_type"]
		match type_str:
			"crit": skill.effect_type = EffectType.CRIT
			"shield": skill.effect_type = EffectType.SHIELD
			"burn": skill.effect_type = EffectType.BURN
			"poison": skill.effect_type = EffectType.POISON
			"freeze": skill.effect_type = EffectType.FREEZE
			"haste": skill.effect_type = EffectType.HASTE
			"charge": skill.effect_type = EffectType.CHARGE
			"health": skill.effect_type = EffectType.HEALTH
			"cooldown": skill.effect_type = EffectType.COOLDOWN
	if data.has("effect_values"):
		var raw = data["effect_values"]
		if raw is Array:
			var typed: Array[float] = []
			for v in raw:
				typed.append(maxf(float(v), 0.0))
				if typed.size() == 4:
					break
			while typed.size() < 4:
				typed.append(0.0)
			skill.effect_values = typed
	return skill
