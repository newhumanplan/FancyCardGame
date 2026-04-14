extends Node

const PassiveSkillDataClass = preload("res://scripts/data/passive_skill.gd")
const SkillManagerClass = preload("res://scripts/data/skill_manager.gd")
const SkillEffectsClass = preload("res://scripts/data/skill_effects.gd")
const ItemEffectsClass = preload("res://scripts/data/item_effects.gd")

## 战斗系统 - 纯物品触发战斗
## 重构：移除独立攻击逻辑，所有伤害来自物品触发
## 集成：SkillManager 技能加成 / PassiveSkills 被动加成 / ItemEffects 物品效果

## 游戏管理器引用
var game_manager: Node

## 技能管理器（运行时初始化）
var skill_manager: RefCounted = null

## 技能效果修正器
var skill_modifiers: Dictionary = {}

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
	# 初始化技能管理器（加载 skills_config.json）
	_init_skill_manager()

## ============ 技能系统集成 ============

## 初始化技能管理器，加载配置并应用英雄技能
func _init_skill_manager() -> void:
	skill_manager = SkillManagerClass.new()
	# 加载 skills_config.json 中的通用技能
	var available_skills = SkillManagerClass.load_skills_from_config()
	# 装备前3个通用技能（MVP）
	for i in range(mini(available_skills.size(), 3)):
		skill_manager.equip_skill(available_skills[i])
	# 应用技能效果到英雄
	if game_manager.selected_hero:
		skill_modifiers = SkillEffectsClass.apply_passive_skills(
			skill_manager.get_equipped_skills(), game_manager.selected_hero
		)
		print("技能效果已应用到英雄")

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

	# 应用被动技能战斗效果到英雄
	_apply_passive_combat_effects()

	print("⚔️ 战斗开始! %s 出现!" % (current_monster.monster_name if current_monster else "???"))

## 应用被动技能的战斗效果（护盾值等）
func _apply_passive_combat_effects() -> void:
	if not game_manager.selected_hero or game_manager.selected_hero.passive_skills.is_empty():
		return
	for ps in game_manager.selected_hero.passive_skills:
		if ps.effect_type == PassiveSkillDataClass.EffectType.SHIELD_BONUS and ps.effect_value > 0:
			# 护盾效果在战斗开始时转化为治疗
			var shield_heal: int = int(ps.effect_value)
			game_manager.heal(shield_heal)
			print("🛡️ 被动 [%s] 战斗开始，获得 %d 护盾值(→治疗)" % [ps.skill_name, shield_heal])

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

## ============ 被动技能辅助方法 ============

## 提取英雄被动技能的战斗属性（避免在多个方法中重复遍历）
func _get_passive_combat_stats() -> Dictionary:
	var stats := {
		"lifesteal": 0.0,
		"reflect": 0.0,
		"cd_reduction": 0.0,
	}
	if not game_manager.selected_hero or game_manager.selected_hero.passive_skills.is_empty():
		return stats
	for ps in game_manager.selected_hero.passive_skills:
		match ps.effect_type:
			PassiveSkillDataClass.EffectType.LIFESTEAL:
				stats["lifesteal"] += ps.effect_value / 100.0
			PassiveSkillDataClass.EffectType.DAMAGE_REFLECTION:
				stats["reflect"] += ps.effect_value / 100.0
			PassiveSkillDataClass.EffectType.COOLDOWN_REDUCTION:
				stats["cd_reduction"] += ps.effect_value / 100.0
	stats["lifesteal"] = clampf(stats["lifesteal"], 0.0, 1.0)
	stats["reflect"] = clampf(stats["reflect"], 0.0, 1.0)
	stats["cd_reduction"] = clampf(stats["cd_reduction"] + float(skill_modifiers.get("cooldown_reduction", 0.0)), 0.0, 0.8)
	return stats

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

	# 计算综合暴击率（基础 + 英雄 + 技能加成）
	var hero_crit_rate: float = 0.05
	if game_manager.selected_hero:
		hero_crit_rate = game_manager.selected_hero.crit_chance
	if skill_modifiers.has("crit_bonus"):
		hero_crit_rate += skill_modifiers["crit_bonus"]
	hero_crit_rate = clampf(hero_crit_rate, 0.0, 1.0)

	# 生命偷取率 / 伤害反弹率 / 冷却缩减（通过被动技能统计）
	var passive_stats: Dictionary = _get_passive_combat_stats()
	var lifesteal_rate: float = passive_stats["lifesteal"]
	var cd_reduction: float = passive_stats["cd_reduction"]

	# 技能燃烧/中毒加成
	var burn_bonus: float = skill_modifiers.get("burn_bonus", 0.0)
	var poison_bonus: float = skill_modifiers.get("poison_bonus", 0.0)

	for item in inventory.items:
		if item == null:
			continue
		if item.current_cooldown > 0:
			continue

		# 判定暴击
		var is_crit: bool = randf() < hero_crit_rate
		var crit_text: String = "（暴击!）" if is_crit else ""

		# 伤害效果
		if item.damage > 0 and current_monster and current_monster.is_alive():
			var total_damage: int = ItemEffectsClass.calculate_damage(item, is_crit)
			current_monster.take_damage(total_damage)
			item_triggered.emit(item.item_name, total_damage, is_crit, "enemy")
			print("🗡️ [%s] 触发！造成 %d 伤害%s" % [item.item_name, total_damage, crit_text])
			# 生命偷取
			if lifesteal_rate > 0 and total_damage > 0:
				var stolen: int = int(float(total_damage) * lifesteal_rate)
				if stolen > 0:
					game_manager.heal(stolen)

		# 护盾效果（MVP 简化为半量治疗）
		if item.shield > 0:
			var total_shield: int = ItemEffectsClass.calculate_shield(item)
			if is_crit:
				total_shield *= 2
			game_manager.heal(int(total_shield * 0.5))
			effect_applied.emit(item.item_name, "shield", total_shield, "self")
			print("🛡️ [%s] 触发！获得 %d 护盾%s" % [item.item_name, total_shield, crit_text])

		# 治疗效果
		if item.heal > 0:
			var total_heal: int = ItemEffectsClass.calculate_heal(item)
			if is_crit:
				total_heal *= 2
			game_manager.heal(total_heal)
			effect_applied.emit(item.item_name, "heal", total_heal, "self")
			print("💚 [%s] 触发！恢复 %d 生命%s" % [item.item_name, total_heal, crit_text])

		# 特殊效果（通过 ItemEffects 集中处理）
		if item.has_special_effect():
			_apply_item_special_effects(item, is_crit, burn_bonus, poison_bonus)

		# 重置冷却（应用冷却缩减）
		item.current_cooldown = maxf(item.cooldown * (1.0 - cd_reduction), 0.1)

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

	# 计算伤害反弹率（被动技能）
	var passive_stats: Dictionary = _get_passive_combat_stats()
	var reflect_rate: float = passive_stats["reflect"]

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
		if float(item.get("current_cooldown", 0.0)) > 0:
			continue

		var damage: int = maxi(int(float(item.get("damage", 0)) * damage_mult), 0)
		var item_name: String = str(item.get("name", "怪物物品"))

		# 怪物物品触发，伤害扣玩家 HP
		game_manager.take_damage(damage)
		monster_item_triggered.emit(current_monster.monster_name, item_name, damage)
		print("👹 [%s] 的 [%s] 触发！造成 %d 伤害" % [current_monster.monster_name, item_name, damage])

		# 伤害反弹（被动技能）
		if reflect_rate > 0 and damage > 0:
			var reflected: int = int(float(damage) * reflect_rate)
			if reflected > 0 and current_monster.is_alive():
				current_monster.take_damage(reflected)
				print("🔄 反弹 %d 伤害!" % reflected)

		# 检查玩家是否死亡
		if game_manager.player_health <= 0:
			break

		# 重置冷却
		item["current_cooldown"] = maxf(float(item.get("cooldown", 0.0)), 0.1)

## ============ 持续效果处理 ============

## 应用物品特殊效果（集成 ItemEffects + 技能加成）
func _apply_item_special_effects(item: ItemData, is_crit: bool, burn_bonus: float = 0.0, poison_bonus: float = 0.0) -> void:
	# 通过 ItemEffects 构建效果列表（build_active_effects 内部处理暴击倍率）
	var effects: Array = ItemEffectsClass.build_active_effects(item, is_crit)

	# 合并技能加成到效果
	for eff in effects:
		if eff["type"] == "burn" and burn_bonus > 0:
			eff["value"] += burn_bonus
		if eff["type"] == "poison" and poison_bonus > 0:
			eff["value"] += poison_bonus
		active_effects.append(eff)
		var dps_text: String = "%.1f DPS, %.0fs" % [eff["value"], eff["duration"]]
		match eff["type"]:
			"poison": print("☠️ [%s] 施加中毒 (%s)!" % [item.item_name, dps_text])
			"burn": print("🔥 [%s] 施加燃烧 (%s)!" % [item.item_name, dps_text])
			"regeneration": print("💚 [%s] 施加再生 (%s)!" % [item.item_name, dps_text])

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

		var value_per_sec: float = maxf(float(effect.get("value", 0.0)), 0.0)
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
