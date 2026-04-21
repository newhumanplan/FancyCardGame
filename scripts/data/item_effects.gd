class_name ItemEffects
extends RefCounted
const MonsterDataClass = preload("res://scripts/data/monster_data.gd")
const ItemDataClass = preload("res://scripts/data/item_data.gd")

## 物品效果系统 — 集中管理物品触发时的效果计算
## 与 battle_system.gd 的 _trigger_player_items 和 _apply_item_special_effects 配合

## 效果类型常量
const EFFECT_POISON: String = "poison"
const EFFECT_BURN: String = "burn"
const EFFECT_REGEN: String = "regeneration"
const EFFECT_STUN: String = "stun"
const EFFECT_FREEZE: String = "freeze"
const EFFECT_SHIELD: String = "shield"
const EFFECT_LIFESTEAL: String = "lifesteal"

static func _append_effect(effects: Array, effect_type: String, value: float, duration: float, item_name: String, target: String) -> void:
	if value <= 0:
		return
	effects.append({
		"type": effect_type,
		"value": value,
		"duration": duration,
		"item_name": item_name,
		"target": target
	})

## 计算物品总伤害（基础伤害 + 稀有度倍率 + 暴击）
static func calculate_damage(item: ItemDataClass, is_crit: bool) -> int:
	if item == null:
		return 0
	var base: int = item.get_rarity_adjusted_damage()
	var mult: float = 2.0 if is_crit else 1.0
	return maxi(int(float(base) * mult), 0)

## 计算物品总护盾
static func calculate_shield(item: ItemDataClass) -> int:
	return 0 if item == null else maxi(item.get_rarity_adjusted_shield(), 0)

## 计算物品总治疗
static func calculate_heal(item: ItemDataClass) -> int:
	return 0 if item == null else maxi(item.get_rarity_adjusted_heal(), 0)

## 计算物品总暴击率加成
static func calculate_crit_chance(item: ItemDataClass) -> float:
	return 0.0 if item == null else clampf(item.crit_chance * item.get_rarity_multiplier(), 0.0, 1.0)

## 构建持续效果数据（供 battle_system.gd 的 active_effects 使用）
## 返回 Array[Dictionary]，每个 dict: {type, value, duration, item_name, target}
static func build_active_effects(item: ItemDataClass, is_crit: bool) -> Array:
	var effects: Array = []
	if item == null:
		return effects
	var rarity_mult: float = item.get_rarity_multiplier()
	var crit_mult: float = 2.0 if is_crit else 1.0

	_append_effect(effects, EFFECT_POISON, item.poison_damage * rarity_mult * crit_mult, 5.0, item.item_name, "enemy")
	_append_effect(effects, EFFECT_BURN, item.burn_damage * rarity_mult * crit_mult, 5.0, item.item_name, "enemy")
	_append_effect(effects, EFFECT_REGEN, item.regeneration * rarity_mult * crit_mult, 5.0, item.item_name, "self")

	return effects

## 处理持续效果 tick（供 battle_system.gd 的 _process_active_effects 使用）
## 返回处理结果: {damage_to_monster: int, damage_to_player: int, heal_player: int}
static func process_effect_tick(effect: Dictionary, battle_tick: float, monster: MonsterDataClass, player_health: int, max_health: int) -> Dictionary:
	var result = {
		"damage_to_monster": 0,
		"damage_to_player": 0,
		"heal_player": 0,
	}

	var value_per_sec: float = maxf(float(effect.get("value", 0.0)), 0.0)
	var tick_value: float = value_per_sec * battle_tick
	var tick_value_int: int = int(tick_value)
	var effect_type: String = str(effect.get("type", ""))

	match effect_type:
		EFFECT_POISON, EFFECT_BURN:
			if monster and monster.is_alive():
				result["damage_to_monster"] = tick_value_int
		EFFECT_REGEN:
			if player_health < max_health:
				result["heal_player"] = tick_value_int
		EFFECT_STUN:
			pass
		EFFECT_FREEZE:
			pass

	return result

## 获取物品效果摘要文本（用于 UI 显示）
static func get_item_summary(item: ItemDataClass) -> String:
	var parts: Array[String] = []

	if item.damage > 0:
		parts.append("伤害:%d" % item.get_rarity_adjusted_damage())
	if item.shield > 0:
		parts.append("护盾:%d" % item.get_rarity_adjusted_shield())
	if item.heal > 0:
		parts.append("治疗:%d" % item.get_rarity_adjusted_heal())
	if item.crit_chance > 0:
		parts.append("暴击:%.0f%%" % (calculate_crit_chance(item) * 100))

	var special = item.get_special_effect_description()
	if special != "":
		parts.append(special)

	return " | ".join(parts)
