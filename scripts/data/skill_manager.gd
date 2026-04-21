class_name SkillManager
extends RefCounted
const SkillDataClass = preload("res://scripts/data/skill_data.gd")

## 技能管理器 — 管理英雄的被动技能装备与效果计算

## 已装备的技能列表
var equipped_skills: Array[SkillDataClass] = []

## 技能字典（ID -> SkillData）用于快速查找
var _skill_dict: Dictionary = {}

## 信号
signal skill_added(skill: SkillDataClass)
signal skill_removed(skill: SkillDataClass)

static func _is_valid_skill(skill: SkillDataClass) -> bool:
	return skill != null and not skill.id.is_empty()

func _build_effect_totals() -> Dictionary:
	return {
		"crit_bonus": 0.0,
		"shield_bonus": 0.0,
		"burn_bonus": 0.0,
		"poison_bonus": 0.0,
		"freeze_bonus": 0.0,
		"haste_bonus": 0.0,
		"charge_bonus": 0.0,
		"max_health_bonus": 0.0,
		"cooldown_reduction": 0.0,
	}

## 装备技能
func equip(skill: SkillDataClass) -> bool:
	if not _is_valid_skill(skill):
		return false
	if not _skill_dict.has(skill.id):
		equipped_skills.append(skill)
		_skill_dict[skill.id] = skill
		skill.unlocked = true
		skill_added.emit(skill)
		print("装备技能: %s (%s)" % [skill.name, skill.get_quality_name()])
		return true
	return false

func equip_skill(skill: SkillDataClass) -> void:
	equip(skill)

## 卸下技能
func unequip(skill_id: String) -> bool:
	if _skill_dict.has(skill_id):
		var skill = _skill_dict[skill_id]
		equipped_skills.erase(skill)
		_skill_dict.erase(skill_id)
		if skill != null:
			skill.unlocked = false
		skill_removed.emit(skill)
		print("卸下技能: %s" % skill.name)
		return true
	return false

func unequip_skill(skill_id: String) -> void:
	unequip(skill_id)

## 获取指定类型技能的总效果值
func get_total_effect(effect_type: SkillData.EffectType) -> float:
	var total: float = 0.0
	for skill in equipped_skills:
		if skill.effect_type == effect_type:
			total += skill.get_effect_value()
	return total

func get_effect_totals() -> Dictionary:
	var totals := _build_effect_totals()
	totals["crit_bonus"] = get_total_effect(SkillData.EffectType.CRIT)
	totals["shield_bonus"] = get_total_effect(SkillData.EffectType.SHIELD)
	totals["burn_bonus"] = get_total_effect(SkillData.EffectType.BURN)
	totals["poison_bonus"] = get_total_effect(SkillData.EffectType.POISON)
	totals["freeze_bonus"] = get_total_effect(SkillData.EffectType.FREEZE)
	totals["haste_bonus"] = get_total_effect(SkillData.EffectType.HASTE)
	totals["charge_bonus"] = get_total_effect(SkillData.EffectType.CHARGE)
	totals["max_health_bonus"] = get_total_effect(SkillData.EffectType.HEALTH)
	totals["cooldown_reduction"] = clampf(get_total_effect(SkillData.EffectType.COOLDOWN) / 100.0, 0.0, 0.8)
	return totals

func apply_passive_skills(hero: HeroData) -> Dictionary:
	var totals := get_effect_totals()
	if hero == null:
		return totals
	hero.reset_skill_effects()
	hero.skill_crit_bonus = float(totals["crit_bonus"])
	hero.skill_shield_bonus = float(totals["shield_bonus"])
	hero.skill_burn_bonus = float(totals["burn_bonus"])
	hero.skill_poison_bonus = float(totals["poison_bonus"])
	hero.skill_freeze_bonus = float(totals["freeze_bonus"])
	hero.skill_haste_bonus = float(totals["haste_bonus"])
	hero.skill_charge_bonus = float(totals["charge_bonus"])
	hero.skill_health_bonus = float(totals["max_health_bonus"])
	hero.skill_cooldown_reduction = float(totals["cooldown_reduction"])
	if hero.skill_health_bonus > 0.0:
		hero.max_hp += int(round(hero.skill_health_bonus))
		hero.current_hp = min(hero.current_hp, hero.max_hp)
	if hero.skill_crit_bonus > 0.0:
		hero.crit_chance = clampf(hero.crit_chance + hero.skill_crit_bonus / 100.0, 0.0, 1.0)
	return totals

## 获取所有已装备技能
func get_equipped_skills() -> Array[SkillDataClass]:
	return equipped_skills.duplicate()

## 获取技能数量
func get_skill_count() -> int:
	return equipped_skills.size()

## 按类型获取技能列表
func get_skills_by_type(effect_type: SkillData.EffectType) -> Array[SkillDataClass]:
	var result: Array[SkillDataClass] = []
	for skill in equipped_skills:
		if skill.effect_type == effect_type:
			result.append(skill)
	return result

## 清空所有技能
func clear() -> void:
	for skill in equipped_skills:
		if skill != null:
			skill.unlocked = false
	equipped_skills.clear()
	_skill_dict.clear()

## 从 skills_config.json 加载技能库（不自动装备）
## 返回 Array[SkillDataClass] 所有可加载的技能
static func load_skills_from_config() -> Array[SkillDataClass]:
	var skill_script = load("res://scripts/data/skill_data.gd")
	var skills: Array[SkillDataClass] = []
	if skill_script == null:
		push_warning("skill_data.gd 加载失败")
		return skills
	var file = FileAccess.open("res://scripts/data/skills_config.json", FileAccess.READ)
	if not file:
		push_warning("skills_config.json 加载失败")
		return skills
	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	if err != OK:
		push_warning("skills_config.json 解析失败: %s" % json.get_error_message())
		return skills
	var data = json.get_data()
	if data is Array:
		for entry in data:
			if entry is Dictionary:
				var skill = skill_script.from_dict(entry)
				if _is_valid_skill(skill):
					skills.append(skill)
	print("加载技能配置: %d 个技能" % skills.size())
	return skills
