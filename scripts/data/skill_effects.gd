class_name SkillEffects
extends RefCounted

## 技能效果应用器 — 将被动技能效果应用到英雄属性

## 将技能效果应用到英雄属性
## 返回修改后的属性字典
static func apply_passive_skills(skills: Array[SkillData], hero: HeroData) -> Dictionary:
	var modifiers: Dictionary = {
		"crit_bonus": 0.0,
		"max_health_bonus": 0.0,
		"shield_bonus": 0.0,
		"cooldown_reduction": 0.0,
		"burn_bonus": 0.0,
		"poison_bonus": 0.0,
		"freeze_bonus": 0.0,
		"haste_bonus": 0.0,
		"charge_bonus": 0.0,
	}

	for skill in skills:
		var value: float = skill.get_effect_value()
		match skill.effect_type:
			SkillData.EffectType.CRIT:
				modifiers["crit_bonus"] += value / 100.0
			SkillData.EffectType.HEALTH:
				modifiers["max_health_bonus"] += value
			SkillData.EffectType.SHIELD:
				modifiers["shield_bonus"] += value
			SkillData.EffectType.COOLDOWN:
				modifiers["cooldown_reduction"] += value / 100.0
			SkillData.EffectType.BURN:
				modifiers["burn_bonus"] += value
			SkillData.EffectType.POISON:
				modifiers["poison_bonus"] += value
			SkillData.EffectType.FREEZE:
				modifiers["freeze_bonus"] += value
			SkillData.EffectType.HASTE:
				modifiers["haste_bonus"] += value
			SkillData.EffectType.CHARGE:
				modifiers["charge_bonus"] += value

	# 应用暴击加成到英雄
	if hero and modifiers["crit_bonus"] > 0:
		hero.crit_chance += modifiers["crit_bonus"]
	# 应用生命加成到英雄
	if hero and modifiers["max_health_bonus"] > 0:
		hero.max_hp += int(modifiers["max_health_bonus"])

	return modifiers

## 获取技能效果摘要文本
static func get_effects_summary(skills: Array[SkillData]) -> String:
	var summary: String = ""
	for skill in skills:
		var value: float = skill.get_effect_value()
		if value > 0:
			summary += "%s %s: +%.1f\n" % [skill.get_quality_name(), skill.get_effect_type_name(), value]
	if summary == "":
		summary = "无技能效果"
	return summary
