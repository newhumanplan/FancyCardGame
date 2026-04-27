class_name BattleEffectRuntime
extends RefCounted

const ItemEffectsClass = preload("res://scripts/data/item_effects.gd")

static func merge_skill_bonuses(effects: Array, burn_bonus: float, poison_bonus: float) -> Array[Dictionary]:
	var merged: Array[Dictionary] = []
	for effect in effects:
		if not effect is Dictionary:
			continue
		var effect_copy: Dictionary = effect.duplicate()
		var effect_type: String = str(effect_copy.get("type", ""))
		if effect_type == ItemEffectsClass.EFFECT_BURN and burn_bonus > 0:
			effect_copy["value"] = float(effect_copy.get("value", 0.0)) + burn_bonus
		elif effect_type == ItemEffectsClass.EFFECT_POISON and poison_bonus > 0:
			effect_copy["value"] = float(effect_copy.get("value", 0.0)) + poison_bonus
		merged.append(effect_copy)
	return merged

static func describe_effect(effect: Dictionary) -> String:
	var value_text: String = "+%d" % int(round(float(effect.get("value", 0.0))))
	match str(effect.get("type", "")):
		ItemEffectsClass.EFFECT_POISON:
			return "☠️ [%s] 施加中毒 %s!" % [effect.get("item_name", "未知"), value_text]
		ItemEffectsClass.EFFECT_BURN:
			return "🔥 [%s] 施加燃烧 %s!" % [effect.get("item_name", "未知"), value_text]
		ItemEffectsClass.EFFECT_REGEN:
			return "💚 [%s] 获得再生 %s!" % [effect.get("item_name", "未知"), value_text]
		_:
			return ""

static func process_active_effects(active_effects: Array[Dictionary], tick: float, monster: MonsterData, game_manager: Node) -> Array[String]:
	var logs: Array[String] = []
	var expired_indices: Array[int] = []
	for i in range(active_effects.size()):
		var effect = active_effects[i]
		effect["duration"] = float(effect.get("duration", 0.0)) - tick
		if float(effect["duration"]) <= 0:
			expired_indices.append(i)
			continue
		var result = ItemEffectsClass.process_effect_tick(effect, tick, monster, game_manager.player_health, game_manager.get_max_health())
		var damage_to_monster: int = int(result.get("damage_to_monster", 0))
		var heal_player: int = int(result.get("heal_player", 0))
		if damage_to_monster > 0 and monster != null and monster.is_alive():
			monster.take_damage(damage_to_monster)
		if heal_player > 0:
			game_manager.heal(heal_player)
	expired_indices.reverse()
	for idx in expired_indices:
		var removed_effect = active_effects[idx]
		active_effects.remove_at(idx)
		logs.append("效果 [%s] 结束" % removed_effect.get("item_name", "未知"))
	return logs

static func get_active_effects_info(active_effects: Array[Dictionary]) -> String:
	if active_effects.is_empty():
		return "激活效果:\n"
	var lines: PackedStringArray = ["激活效果:"]
	for effect in active_effects:
		lines.append("- %s (%.1fs)" % [effect.get("type", "unknown"), float(effect.get("duration", 0.0))])
	return "\n".join(lines) + "\n"
