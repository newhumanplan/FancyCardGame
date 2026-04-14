class_name SkillManager
extends RefCounted

## 技能管理器 — 管理英雄的被动技能装备与效果计算

## 已装备的技能列表
var equipped_skills: Array[SkillData] = []

## 技能字典（ID -> SkillData）用于快速查找
var _skill_dict: Dictionary = {}

## 信号
signal skill_added(skill: SkillData)
signal skill_removed(skill: SkillData)

## 装备技能
func equip_skill(skill: SkillData) -> void:
	if skill == null or skill.skill_id.is_empty():
		return
	if not _skill_dict.has(skill.skill_id):
		equipped_skills.append(skill)
		_skill_dict[skill.skill_id] = skill
		skill.unlocked = true
		skill_added.emit(skill)
		print("装备技能: %s (%s)" % [skill.skill_name, skill.get_quality_name()])

## 卸下技能
func unequip_skill(skill_id: String) -> void:
	if _skill_dict.has(skill_id):
		var skill = _skill_dict[skill_id]
		equipped_skills.erase(skill)
		_skill_dict.erase(skill_id)
		skill_removed.emit(skill)
		print("卸下技能: %s" % skill.skill_name)

## 获取指定类型技能的总效果值
func get_total_effect(effect_type: SkillData.EffectType) -> float:
	var total: float = 0.0
	for skill in equipped_skills:
		if skill.effect_type == effect_type:
			total += skill.get_effect_value()
	return total

## 获取所有已装备技能
func get_equipped_skills() -> Array[SkillData]:
	return equipped_skills.duplicate()

## 获取技能数量
func get_skill_count() -> int:
	return equipped_skills.size()

## 按类型获取技能列表
func get_skills_by_type(effect_type: SkillData.EffectType) -> Array[SkillData]:
	var result: Array[SkillData] = []
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
## 返回 Array[SkillData] 所有可加载的技能
static func load_skills_from_config() -> Array[SkillData]:
	var skill_script = load("res://scripts/data/skill_data.gd")
	var skills: Array[SkillData] = []
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
				if skill != null and not skill.skill_id.is_empty():
					skills.append(skill)
	print("加载技能配置: %d 个技能" % skills.size())
	return skills
