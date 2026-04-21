class_name SkillData
extends Resource
const SkillDataClass = preload("res://scripts/data/skill_data.gd")

## 技能品质枚举
enum Rarity { BRONZE, SILVER, GOLD, DIAMOND }
const Quality = Rarity

## 技能效果类型
enum EffectType { CRIT, SHIELD, BURN, POISON, FREEZE, HASTE, CHARGE, HEALTH, COOLDOWN }

## 核心字段
@export var id: String = ""
@export var name: String = "技能"
@export var rarity: Rarity = Rarity.BRONZE

## 技能描述
@export var description: String = ""

## 所属英雄（空字符串=通用技能）
@export var hero: String = ""

## 效果类型
@export var effect_type: EffectType = EffectType.CRIT

## 效果数值（按品质递增）: [Bronze, Silver, Gold, Diamond]
@export var effect_value: Array[float] = [0.0, 0.0, 0.0, 0.0]

## 技能来源商人
@export var merchant: String = ""

## 是否已解锁
var unlocked: bool = false

## 兼容旧字段命名
var skill_id: String:
	get:
		return id
	set(value):
		id = value

var skill_name: String:
	get:
		return name
	set(value):
		name = value

var quality: Rarity:
	get:
		return rarity
	set(value):
		rarity = value

var hero_id: String:
	get:
		return hero
	set(value):
		hero = value

var effect_values: Array[float]:
	get:
		return effect_value
	set(value):
		effect_value = _normalize_effect_values(value)

## 获取当前品质对应的效果值
func get_effect_value() -> float:
	var idx: int = rarity as int
	if idx >= 0 and idx < effect_value.size():
		return maxf(effect_value[idx], 0.0)
	return 0.0

## 获取品质名称
func get_quality_name() -> String:
	match rarity:
		Rarity.BRONZE: return "铜"
		Rarity.SILVER: return "银"
		Rarity.GOLD: return "金"
		Rarity.DIAMOND: return "钻"
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

func _normalize_effect_values(values: Array) -> Array[float]:
	var typed: Array[float] = []
	for entry in values:
		typed.append(maxf(float(entry), 0.0))
		if typed.size() == 4:
			break
	while typed.size() < 4:
		typed.append(0.0)
	return typed

static func _parse_rarity(raw_value) -> Rarity:
	if raw_value is int:
		return clampi(int(raw_value), 0, 3)
	var text := str(raw_value).to_lower()
	match text:
		"bronze", "铜", "br":
			return Rarity.BRONZE
		"silver", "银", "sr":
			return Rarity.SILVER
		"gold", "金", "ur":
			return Rarity.GOLD
		"diamond", "钻", "ssr":
			return Rarity.DIAMOND
		_:
			return Rarity.BRONZE

static func _parse_effect_type(raw_value) -> EffectType:
	var text := str(raw_value).to_lower()
	match text:
		"crit":
			return EffectType.CRIT
		"shield":
			return EffectType.SHIELD
		"burn":
			return EffectType.BURN
		"poison":
			return EffectType.POISON
		"freeze":
			return EffectType.FREEZE
		"haste":
			return EffectType.HASTE
		"charge":
			return EffectType.CHARGE
		"health":
			return EffectType.HEALTH
		"cooldown":
			return EffectType.COOLDOWN
		_:
			return EffectType.CRIT

## 从字典创建（用于JSON加载）
static func from_dict(data: Dictionary) -> SkillData:
	var skill = SkillDataClass.new()
	if data.has("id"): skill.id = str(data["id"])
	elif data.has("skill_id"): skill.id = str(data["skill_id"])
	if data.has("name"): skill.name = str(data["name"])
	elif data.has("skill_name"): skill.name = str(data["skill_name"])
	if data.has("description"): skill.description = data["description"]
	if data.has("hero"): skill.hero = str(data["hero"])
	elif data.has("hero_id"): skill.hero = str(data["hero_id"])
	if data.has("merchant"): skill.merchant = str(data["merchant"])
	if data.has("rarity"):
		skill.rarity = _parse_rarity(data["rarity"])
	elif data.has("quality"):
		skill.rarity = _parse_rarity(data["quality"])
	if data.has("effect_type"):
		skill.effect_type = _parse_effect_type(data["effect_type"])
	if data.has("effect_value") and data["effect_value"] is Array:
		skill.effect_value = skill._normalize_effect_values(data["effect_value"])
	elif data.has("effect_values") and data["effect_values"] is Array:
		skill.effect_value = skill._normalize_effect_values(data["effect_values"])
	return skill
