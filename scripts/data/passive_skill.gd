class_name PassiveSkillData
extends RefCounted

## 英雄被动技能定义 — 每个英雄的专属被动技能
## 与 SkillData 不同，被动技能是英雄固有能力，不可替换

## 被动技能名称
var skill_name: String = ""

## 被动技能描述
var description: String = ""

## 被动技能效果类型
var effect_type: PassiveSkillData.EffectType = EffectType.HEALTH_BONUS

## 效果值
var effect_value: float = 0.0

## 效果类型枚举
enum EffectType {
	HEALTH_BONUS,        ## 增加最大生命值
	CRIT_BONUS,          ## 增加暴击率（百分比）
	SHIELD_BONUS,        ## 增加护盾值
	COOLDOWN_REDUCTION,  ## 减少物品冷却（百分比）
	DAMAGE_REFLECTION,   ## 反弹伤害（百分比）
	LIFESTEAL,           ## 生命偷取（百分比）
}

static func get_combat_bonuses(hero: HeroData) -> Dictionary:
	return {
		"shield": 0.0 if hero == null else maxf(hero._combat_bonus_shield, 0.0),
		"cd_reduction": 0.0 if hero == null else clampf(hero._combat_cd_reduction, 0.0, 0.8),
		"reflect": 0.0 if hero == null else clampf(hero._combat_reflect, 0.0, 1.0),
		"lifesteal": 0.0 if hero == null else clampf(hero._combat_lifesteal, 0.0, 1.0),
	}

## 应用被动技能效果到英雄
## HEALTH/CRIT 立即修改英雄属性
## SHIELD/CD_REDUCTION/REFLECT/LIFESTEAL 存储到英雄字典供战斗系统读取
static func apply_to_hero(skill: PassiveSkillData, hero: HeroData) -> void:
	if not skill or not hero:
		return
	match skill.effect_type:
		EffectType.HEALTH_BONUS:
			hero.max_hp += int(skill.effect_value)
			hero.current_hp = hero.max_hp
		EffectType.CRIT_BONUS:
			hero.crit_chance = clampf(hero.crit_chance + skill.effect_value / 100.0, 0.0, 1.0)
		EffectType.SHIELD_BONUS:
			hero._combat_bonus_shield = hero._combat_bonus_shield + skill.effect_value
		EffectType.COOLDOWN_REDUCTION:
			hero._combat_cd_reduction = clampf(hero._combat_cd_reduction + skill.effect_value / 100.0, 0.0, 0.8)
		EffectType.DAMAGE_REFLECTION:
			hero._combat_reflect = clampf(hero._combat_reflect + skill.effect_value / 100.0, 0.0, 1.0)
		EffectType.LIFESTEAL:
			hero._combat_lifesteal = clampf(hero._combat_lifesteal + skill.effect_value / 100.0, 0.0, 1.0)
	print("被动技能生效: %s — %s (+%.1f)" % [skill.skill_name, skill.get_type_description(), skill.effect_value])

## 获取效果描述文本
func get_type_description() -> String:
	match effect_type:
		EffectType.HEALTH_BONUS: return "生命值 +%.0f" % effect_value
		EffectType.CRIT_BONUS: return "暴击率 +%.1f%%" % effect_value
		EffectType.SHIELD_BONUS: return "护盾 +%.0f" % effect_value
		EffectType.COOLDOWN_REDUCTION: return "冷却 -%.1f%%" % effect_value
		EffectType.DAMAGE_REFLECTION: return "反弹 %.1f%%" % effect_value
		EffectType.LIFESTEAL: return "生命偷取 %.1f%%" % effect_value
		_: return "未知效果"

## 获取完整描述
func get_full_description() -> String:
	return "%s: %s" % [skill_name, description]
