extends Node

## 战斗系统 - 管理战斗中的自动触发和效果

## 游戏管理器引用
var game_manager: Node

## 当前激活的特殊效果（持续效果）
var active_effects: Array[Dictionary] = []

## 战斗状态
var is_battle_active: bool = false

## 毒液定时器（用于持续伤害）
var poison_timer: float = 0.0

## 再生定时器（用于持续治疗）
var regeneration_timer: float = 0.0

func _ready() -> void:
	game_manager = get_node("/root/GameManager")

## 开始战斗
func start_battle() -> void:
	is_battle_active = true
	active_effects.clear()
	print("战斗开始!")

## 结束战斗
func end_battle() -> void:
	is_battle_active = false
	active_effects.clear()
	print("战斗结束!")

## 处理物品触发（冷却完毕时自动触发）
## item: 物品数据
func process_item_trigger(item: ItemData) -> void:
	if not is_battle_active:
		return
	
	if item == null:
		return
	
	# 检查是否冷却完毕
	if not item.can_trigger():
		return
	
	# 应用稀有度加成后的效果
	var damage = item.get_rarity_adjusted_damage()
	var shield = item.get_rarity_adjusted_shield()
	var heal = item.get_rarity_adjusted_heal()
	
	# 应用伤害
	if damage > 0:
		_apply_damage(damage, item)
	
	# 应用护盾
	if shield > 0:
		_apply_shield(shield, item)
	
	# 应用治疗
	if heal > 0:
		_apply_healing(heal, item)
	
	# 应用特殊效果
	if item.has_special_effect():
		_apply_special_effect(item)
	
	# 重置冷却
	item.reset_cooldown()

## 应用伤害
func _apply_damage(damage: int, item: ItemData) -> void:
	# 检查目标是否免疫
	var target_immune = _is_target_immune()
	if target_immune:
		print("目标免疫伤害!")
		return
	
	# 造成伤害
	game_manager.take_damage(damage)
	print("%s 造成 %d 伤害!" % [item.item_name, damage])
	
	# 检查是否有眩晕效果
	if item.stun_duration > 0:
		_add_stun_effect(item.stun_duration)

## 应用护盾
func _apply_shield(amount: int, item: ItemData) -> void:
	# 护盾效果可以增加到玩家防御或创建临时护盾
	# 这里简化为增加临时防御
	game_manager.player_defense += amount
	game_manager.defense_changed.emit(game_manager.player_defense)
	print("%s 提供 %d 护盾!" % [item.item_name, amount])

## 应用治疗
func _apply_healing(amount: int, item: ItemData) -> void:
	game_manager.heal(amount)
	print("%s 恢复 %d 生命!" % [item.item_name, amount])

## 应用特殊效果
func _apply_special_effect(item: ItemData) -> void:
	# 中毒效果
	if item.poison_damage > 0:
		_add_poison_effect(item.poison_damage, item)
	
	# 再生效果
	if item.regeneration > 0:
		_add_regeneration_effect(item.regeneration, item)
	
	# 眩晕效果（已在伤害处理中）
	
	# 免疫效果
	if item.is_immune:
		_add_immune_effect(item)

## 添加中毒效果
func _add_poison_effect(dps: float, item: ItemData) -> void:
	active_effects.append({
		"type": "poison",
		"dps": dps,
		"item_name": item.item_name,
		"duration": 5.0  # 持续5秒
	})
	print("%s 施加中毒效果 (%.1f DPS)!" % [item.item_name, dps])

## 添加再生效果
func _add_regeneration_effect(hps: float, item: ItemData) -> void:
	active_effects.append({
		"type": "regeneration",
		"hps": hps,
		"item_name": item.item_name,
		"duration": 5.0  # 持续5秒
	})
	print("%s 施加再生效果 (%.1f HPS)!" % [item.item_name, hps])

## 添加眩晕效果（暂停冷却）
var stun_timer: float = 0.0

func _add_stun_effect(duration: float) -> void:
	stun_timer = duration
	print("目标眩晕 %.1f 秒!" % duration)

## 添加免疫效果
func _add_immune_effect(item: ItemData) -> void:
	active_effects.append({
		"type": "immune",
		"item_name": item.item_name,
		"duration": 3.0  # 持续3秒
	})
	print("%s 获得免疫效果!" % item.item_name)

## 检查目标是否免疫
func _is_target_immune() -> bool:
	for effect in active_effects:
		if effect.get("type") == "immune":
			return true
	return false

## 检查是否眩晕（暂停冷却）
func is_stunned() -> bool:
	return stun_timer > 0

## 每帧更新（处理持续效果）
func _process(delta: float) -> void:
	if not is_battle_active:
		return
	
	# 更新眩晕计时器
	if stun_timer > 0:
		stun_timer -= delta
	
	# 处理持续效果
	var expired_effects: Array[int] = []
	
	for i in range(active_effects.size()):
		var effect = active_effects[i]
		var duration = effect.get("duration", 0.0)
		
		if duration > 0:
			effect["duration"] = duration - delta
			
			# 应用持续效果
			match effect.get("type"):
				"poison":
					var dps = effect.get("dps", 0.0)
					game_manager.take_damage(int(dps * delta))
				"regeneration":
					var hps = effect.get("hps", 0.0)
					game_manager.heal(int(hps * delta))
			
			# 检查是否过期
			if effect["duration"] <= 0:
				expired_effects.append(i)
				print("效果 %s 结束" % effect.get("type"))
	
	# 移除过期效果（倒序移除）
	expired_effects.reverse()
	for idx in expired_effects:
		active_effects.remove_at(idx)

## 更新物品冷却（战斗每帧调用）
## inventory: 背包系统
func update_cooldowns(inventory, delta: float) -> void:
	if not is_battle_active:
		return
	
	# 眩晕时暂停冷却
	if is_stunned():
		return
	
	# 更新所有物品的冷却
	for item in inventory.items:
		if item != null and item.current_cooldown > 0:
			item.current_cooldown -= delta
		
		# 冷却完毕时自动触发
		if item.can_trigger():
			process_item_trigger(item)

## 获取当前效果状态
func get_active_effects_info() -> String:
	var info = "激活效果:\n"
	for effect in active_effects:
		var effect_type = effect.get("type", "unknown")
		var duration = effect.get("duration", 0.0)
		info += "- %s (%.1fs)\n" % [effect_type, duration]
	return info
