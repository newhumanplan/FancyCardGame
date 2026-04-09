extends Node

## 战斗系统 - 纯物品触发战斗
## 重构：移除独立攻击逻辑，所有伤害来自物品触发
## 按原版大巴扎 1:1 复刻

## 游戏管理器引用
var game_manager: Node

## 战斗状态
var is_battle_active: bool = false

## 战斗 tick 间隔（秒）
const BATTLE_TICK: float = 0.5

## 当前怪物数据（运行时引用）
var current_monster: MonsterData = null

## 玩家背包引用（运行时）
var inventory: LinearInventory = null

## 当前激活的持续效果列表
## [{type: String, value: float, duration: float, item_name: String}]
var active_effects: Array[Dictionary] = []

## 暴击反馈信号（供 UI 使用）
signal item_triggered(item_name: String, damage: int, is_crit: bool, target: String)
signal effect_applied(item_name: String, effect_type: String, value: int, target: String)
signal monster_item_triggered(monster_name: String, item_name: String, damage: int)

func _ready() -> void:
	game_manager = get_node("/root/GameManager")

## ============ 战斗控制 ============

## 开始战斗
func start_battle(monster: MonsterData, inv: LinearInventory) -> void:
	is_battle_active = true
	current_monster = monster
	inventory = inv
	active_effects.clear()

	# 初始化玩家物品冷却为满值
	if inventory:
		for item in inventory.items:
			if item != null and item.cooldown > 0:
				item.current_cooldown = item.cooldown

	# 初始化怪物物品冷却为满值
	if current_monster:
		current_monster.init_item_cooldowns()
		# 应用 AI 冷却调整
		if current_monster.ai:
			current_monster.ai.apply_to_monster_items(current_monster)

	print("⚔️ 战斗开始! %s 出现!" % (current_monster.monster_name if current_monster else "???"))

## 结束战斗
func end_battle() -> void:
	is_battle_active = false
	active_effects.clear()

	# 重置所有物品冷却
	if inventory:
		for item in inventory.items:
			if item != null:
				item.current_cooldown = 0.0

	# 重置怪物物品冷却
	if current_monster:
		current_monster.reset_item_cooldowns()

	print("战斗结束!")

## ============ 核心：战斗 Tick ============

## 执行一个战斗 tick（每 0.5 秒）
func execute_battle_tick() -> bool:
	if not is_battle_active:
		return false

	# 1. 检查战斗是否结束
	if _check_battle_end():
		return true

	# 2. 更新所有物品 current_cooldown
	_update_player_item_cooldowns()
	_update_monster_item_cooldowns()

	# 3. 处理玩家物品触发
	_trigger_player_items()

	# 再次检查战斗结束（玩家物品可能击杀怪物）
	if _check_battle_end():
		return true

	# 4. 处理怪物物品触发
	_trigger_monster_items()

	# 5. 处理持续效果（Burn/Poison/Regen）
	_process_active_effects()

	# 6. 最终检查战斗结束
	_check_battle_end()

	return false

## ============ 玩家物品系统 ============

## 更新玩家物品冷却
func _update_player_item_cooldowns() -> void:
	if not inventory:
		return
	for item in inventory.items:
		if item != null and item.current_cooldown > 0:
			item.current_cooldown -= BATTLE_TICK

## 触发玩家物品
func _trigger_player_items() -> void:
	if not inventory:
		return

	var hero_crit_rate: float = 0.05  # 默认暴击率
	if game_manager.selected_hero:
		hero_crit_rate = game_manager.selected_hero.crit_chance

	for item in inventory.items:
		if item == null:
			continue
		if item.current_cooldown > 0:
			continue

		# 判定暴击
		var is_crit: bool = randf() < hero_crit_rate
		var crit_multiplier: float = 2.0 if is_crit else 1.0

		# 计算伤害 = base_damage × rarity_multiplier × crit_multiplier
		var rarity_mult: float = item.get_rarity_multiplier()

		# 伤害效果
		if item.damage > 0 and current_monster and current_monster.is_alive():
			var total_damage: int = int(float(item.damage) * rarity_mult * crit_multiplier)
			current_monster.take_damage(total_damage)
			var crit_text: String = "（暴击!）" if is_crit else ""
			item_triggered.emit(item.item_name, total_damage, is_crit, "enemy")
			print("🗡️ [%s] 触发！造成 %d 伤害%s" % [item.item_name, total_damage, crit_text])

		# 护盾效果（加己方护盾，MVP 暂简化为回血）
		if item.shield > 0:
			var total_shield: int = int(float(item.shield) * rarity_mult * crit_multiplier)
			game_manager.heal(int(total_shield * 0.5))  # 护盾效果简化为回一半血
			var crit_text: String = "（暴击!）" if is_crit else ""
			effect_applied.emit(item.item_name, "shield", total_shield, "self")
			print("🛡️ [%s] 触发！获得 %d 护盾%s" % [item.item_name, total_shield, crit_text])

		# 治疗效果
		if item.heal > 0:
			var total_heal: int = int(float(item.heal) * rarity_mult * crit_multiplier)
			game_manager.heal(total_heal)
			var crit_text: String = "（暴击!）" if is_crit else ""
			effect_applied.emit(item.item_name, "heal", total_heal, "self")
			print("💚 [%s] 触发！恢复 %d 生命%s" % [item.item_name, total_heal, crit_text])

		# 特殊效果
		if item.has_special_effect():
			_apply_item_special_effects(item, is_crit, rarity_mult)

		# 重置冷却
		item.current_cooldown = item.cooldown

## ============ 怪物物品系统 ============

## 更新怪物物品冷却
func _update_monster_item_cooldowns() -> void:
	if not current_monster:
		return
	for item in current_monster.monster_items:
		if item["current_cooldown"] > 0:
			item["current_cooldown"] -= BATTLE_TICK

## 触发怪物物品（集成 MonsterAI）
func _trigger_monster_items() -> void:
	if not current_monster or not current_monster.is_alive():
		return

	# AI 自我治疗
	if current_monster.ai and current_monster.ai.should_heal(current_monster):
		var heal = current_monster.ai.heal_amount
		current_monster.current_hp = mini(current_monster.current_hp + heal, current_monster.max_hp)
		print("👹 [%s] 自我治疗! 恢复 %d HP" % [current_monster.monster_name, heal])

	# AI 伤害倍率
	var damage_mult: float = 1.0
	if current_monster.ai:
		damage_mult = current_monster.ai.get_current_damage_multiplier(current_monster)

	for item in current_monster.monster_items:
		if item["current_cooldown"] > 0:
			continue

		var damage: int = int(float(item["damage"]) * damage_mult)
		var item_name: String = item["name"]

		# 怪物物品触发，伤害扣玩家 HP
		game_manager.take_damage(damage)
		monster_item_triggered.emit(current_monster.monster_name, item_name, damage)
		print("👹 [%s] 的 [%s] 触发！造成 %d 伤害" % [current_monster.monster_name, item_name, damage])

		# 检查玩家是否死亡
		if game_manager.player_health <= 0:
			break

		# 重置冷却
		item["current_cooldown"] = item["cooldown"]

## ============ 持续效果处理 ============

## 应用物品特殊效果
func _apply_item_special_effects(item: ItemData, is_crit: bool, rarity_mult: float) -> void:
	var crit_mult: float = 2.0 if is_crit else 1.0

	# 中毒效果
	if item.poison_damage > 0:
		active_effects.append({
			"type": "poison",
			"value": item.poison_damage * rarity_mult * crit_mult,
			"duration": 5.0,
			"item_name": item.item_name,
			"target": "enemy"
		})
		print("☠️ [%s] 施加中毒效果 (%.1f DPS, 5s)!" % [item.item_name, item.poison_damage * rarity_mult])

	# 燃烧效果
	if item.burn_damage > 0:
		active_effects.append({
			"type": "burn",
			"value": item.burn_damage * rarity_mult * crit_mult,
			"duration": 5.0,
			"item_name": item.item_name,
			"target": "enemy"
		})
		print("🔥 [%s] 施加燃烧效果 (%.1f DPS, 5s)!" % [item.item_name, item.burn_damage * rarity_mult])

	# 再生效果
	if item.regeneration > 0:
		active_effects.append({
			"type": "regeneration",
			"value": item.regeneration * rarity_mult * crit_mult,
			"duration": 5.0,
			"item_name": item.item_name,
			"target": "self"
		})
		print("💚 [%s] 施加再生效果 (%.1f HPS, 5s)!" % [item.item_name, item.regeneration * rarity_mult])

## 处理所有持续效果
func _process_active_effects() -> void:
	var tick = BATTLE_TICK
	var expired_indices: Array[int] = []

	for i in range(active_effects.size()):
		var effect = active_effects[i]
		effect["duration"] -= tick

		if effect["duration"] <= 0:
			expired_indices.append(i)
			continue

		var value_per_sec: float = effect["value"]
		var tick_value: float = value_per_sec * tick
		var tick_value_int: int = int(tick_value)

		match effect["type"]:
			"poison":
				if current_monster and current_monster.is_alive():
					current_monster.take_damage(tick_value_int)
			"burn":
				if current_monster and current_monster.is_alive():
					current_monster.take_damage(tick_value_int)
			"regeneration":
				game_manager.heal(tick_value_int)

	# 移除过期效果（倒序移除避免索引偏移）
	expired_indices.reverse()
	for idx in expired_indices:
		var removed_effect = active_effects[idx]
		active_effects.remove_at(idx)
		print("效果 [%s] 结束" % removed_effect.get("item_name", "未知"))

## ============ 战斗结束检查 ============

## 检查战斗是否结束，返回 true 表示战斗结束
func _check_battle_end() -> bool:
	if current_monster and not current_monster.is_alive():
		return true
	if game_manager.player_health <= 0:
		return true
	return false

## 获取战斗结果
## 返回: {"won": bool, "monster_killed": bool, "player_dead": bool}
func get_battle_result() -> Dictionary:
	var monster_killed: bool = current_monster != null and not current_monster.is_alive()
	var player_dead: bool = game_manager.player_health <= 0
	return {
		"won": monster_killed,
		"monster_killed": monster_killed,
		"player_dead": player_dead
	}

## 获取当前效果状态
func get_active_effects_info() -> String:
	var info = "激活效果:\n"
	for effect in active_effects:
		var effect_type = effect.get("type", "unknown")
		var duration = effect.get("duration", 0.0)
		info += "- %s (%.1fs)\n" % [effect_type, duration]
	return info
