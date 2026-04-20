class_name HeroFactory
extends Node

const HeroDataClass = preload("res://scripts/data/hero_data.gd")
const PassiveSkillDataClass = preload("res://scripts/data/passive_skill.gd")

## 英雄工厂 - 统一管理战士/法师的创建
## 从 main.gd _on_warrior_selected / _on_mage_selected 提取

func create_hero(hero_type: HeroData.HeroType) -> HeroData:
	match hero_type:
		HeroData.HeroType.WARRIOR:
			return _create_warrior()
		HeroData.HeroType.MAGE:
			return _create_mage()
	return _create_warrior()

func _create_warrior() -> HeroData:
	var hero = HeroDataClass.new()
	hero.hero_name = "战士"
	hero.hero_type = HeroDataClass.HeroType.WARRIOR
	hero.max_hp = 120
	hero.crit_chance = 0.05

	var ps1 = PassiveSkillDataClass.new()
	ps1.skill_name = "铁壁"
	ps1.description = "坚韧体质，生命值上限+20"
	ps1.effect_type = PassiveSkillDataClass.EffectType.HEALTH_BONUS
	ps1.effect_value = 20.0
	hero.passive_skills.append(ps1)

	var ps2 = PassiveSkillDataClass.new()
	ps2.skill_name = "战斗本能"
	ps2.description = "丰富的战斗经验，暴击率+2%"
	ps2.effect_type = PassiveSkillDataClass.EffectType.CRIT_BONUS
	ps2.effect_value = 2.0
	hero.passive_skills.append(ps2)

	return hero

func _create_mage() -> HeroData:
	var hero = HeroDataClass.new()
	hero.hero_name = "法师"
	hero.hero_type = HeroDataClass.HeroType.MAGE
	hero.max_hp = 80
	hero.crit_chance = 0.15

	var ps1 = PassiveSkillDataClass.new()
	ps1.skill_name = "奥术智慧"
	ps1.description = "对魔法的深刻理解，暴击率+5%"
	ps1.effect_type = PassiveSkillDataClass.EffectType.CRIT_BONUS
	ps1.effect_value = 5.0
	hero.passive_skills.append(ps1)

	var ps2 = PassiveSkillDataClass.new()
	ps2.skill_name = "魔力涌动"
	ps2.description = "魔力充沛，生命值上限+10"
	ps2.effect_type = PassiveSkillDataClass.EffectType.HEALTH_BONUS
	ps2.effect_value = 10.0
	hero.passive_skills.append(ps2)

	return hero
