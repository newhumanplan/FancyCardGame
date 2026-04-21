extends Node

const PassiveSkillDataClass = preload("res://scripts/data/passive_skill.gd")
const SkillManagerClass = preload("res://scripts/data/skill_manager.gd")
const SkillEffectsClass = preload("res://scripts/data/skill_effects.gd")
const ItemEffectsClass = preload("res://scripts/data/item_effects.gd")
const BattleEffectRuntimeClass = preload("res://scripts/data/battle_effect_runtime.gd")

var game_manager: Node
var skill_manager: RefCounted = null
var skill_modifiers: Dictionary = {}
var is_battle_active: bool = false
const BATTLE_TICK: float = 0.5
var current_monster: MonsterData = null
var inventory: LinearInventory = null
var active_effects: Array[Dictionary] = []
var _skill_target_hero: HeroData = null

signal item_triggered(item_name: String, damage: int, is_crit: bool, target: String)
signal effect_applied(item_name: String, effect_type: String, value: int, target: String)
signal monster_item_triggered(monster_name: String, item_name: String, damage: int)

func _ready() -> void:
	game_manager = get_node("/root/GameManager")
	_init_skill_manager()

func _init_skill_manager() -> void:
	skill_manager = SkillManagerClass.new()
	var available_skills = SkillManagerClass.new().load_skills_from_config()
	for i in range(mini(available_skills.size(), 3)):
		skill_manager.equip_skill(available_skills[i])
	_refresh_skill_modifiers()

func _refresh_skill_modifiers() -> void:
	skill_modifiers = {}
	if game_manager == null or game_manager.selected_hero == null or skill_manager == null:
		return
	if _skill_target_hero != game_manager.selected_hero:
		game_manager.selected_hero.refresh_skill_base_stats()
		_skill_target_hero = game_manager.selected_hero
	skill_modifiers = skill_manager.apply_passive_skills(game_manager.selected_hero)

func start_battle(monster: MonsterData, inv: LinearInventory) -> void:
	is_battle_active = true
	current_monster = monster
	inventory = inv
	active_effects.clear()
	_refresh_skill_modifiers()
	_reset_player_item_cooldowns(true)
	if current_monster != null:
		current_monster.init_item_cooldowns()
		if current_monster.ai != null:
			current_monster.ai.apply_to_monster_items(current_monster)
	_apply_passive_combat_effects()
	print("⚔️ 战斗开始! %s 出现!" % (current_monster.monster_name if current_monster else "???"))

func _apply_passive_combat_effects() -> void:
	if game_manager == null or game_manager.selected_hero == null:
		return
	var hero: HeroData = game_manager.selected_hero
	var bonuses: Dictionary = PassiveSkillDataClass.get_combat_bonuses(game_manager.selected_hero)
	var shield_heal: int = int(bonuses.get("shield", 0.0))
	if shield_heal <= 0:
		return
	hero.add_shield(float(shield_heal))
	print("🛡️ 战斗开始，获得 %d 护盾" % shield_heal)

func end_battle() -> void:
	is_battle_active = false
	active_effects.clear()
	_reset_player_item_cooldowns(false)
	if current_monster != null:
		current_monster.reset_item_cooldowns()
	if game_manager != null and game_manager.selected_hero != null:
		game_manager.selected_hero.current_shield = 0.0
	print("战斗结束!")

func _reset_player_item_cooldowns(fill_to_max: bool) -> void:
	if inventory == null:
		return
	for item in inventory.items:
		if item == null:
			continue
		item.current_cooldown = item.cooldown if fill_to_max and item.cooldown > 0 else 0.0

func execute_battle_tick(elapsed_time: float = BATTLE_TICK) -> bool:
	if not is_battle_active:
		return false
	# Cooldowns/effects use real elapsed time; trigger cadence still stays on BATTLE_TICK.
	var tick_time: float = maxf(elapsed_time, 0.0)
	if _check_battle_end():
		return true
	_trigger_player_items()
	if _check_battle_end():
		return true
	_trigger_monster_items()
	_process_active_effects(tick_time)
	_check_battle_end()
	return false

func _get_passive_combat_stats() -> Dictionary:
	var hero = null if game_manager == null else game_manager.selected_hero
	var stats: Dictionary = PassiveSkillDataClass.get_combat_bonuses(hero)
	stats["cd_reduction"] = clampf(float(stats.get("cd_reduction", 0.0)) + float(skill_modifiers.get("cooldown_reduction", 0.0)), 0.0, 0.8)
	return stats

func reduce_cooldowns(delta: float) -> void:
	var cooldown_delta: float = maxf(delta, 0.0)
	if cooldown_delta <= 0.0:
		return
	if inventory != null:
		for item in inventory.items:
			if item != null and item.current_cooldown > 0:
				item.current_cooldown = maxf(item.current_cooldown - cooldown_delta, 0.0)
	if current_monster == null or not current_monster.is_alive():
		return
	for item in current_monster.monster_items:
		if item.get("current_cooldown", 0.0) > 0:
			item["current_cooldown"] = maxf(float(item["current_cooldown"]) - cooldown_delta, 0.0)

func _trigger_player_items() -> void:
	if inventory == null or current_monster == null:
		return
	var hero: HeroData = null if game_manager == null else game_manager.selected_hero
	var hero_crit_rate: float = 0.05
	if hero != null:
		hero_crit_rate = hero.crit_chance
	hero_crit_rate = clampf(hero_crit_rate, 0.0, 1.0)
	var passive_stats: Dictionary = _get_passive_combat_stats()
	var lifesteal_rate: float = float(passive_stats.get("lifesteal", 0.0))
	var cd_reduction: float = float(passive_stats.get("cd_reduction", 0.0))
	var burn_bonus: float = 0.0 if hero == null else hero.skill_burn_bonus
	var poison_bonus: float = 0.0 if hero == null else hero.skill_poison_bonus
	for item in inventory.items:
		if item == null or item.current_cooldown > 0:
			continue
		var is_crit: bool = randf() < hero_crit_rate
		var crit_text: String = "（暴击!）" if is_crit else ""
		if item.damage > 0 and current_monster.is_alive():
			var total_damage: int = ItemEffectsClass.calculate_damage(item, is_crit)
			current_monster.take_damage(total_damage)
			item_triggered.emit(item.item_name, total_damage, is_crit, "enemy")
			print("🗡️ [%s] 触发！造成 %d 伤害%s" % [item.item_name, total_damage, crit_text])
			if lifesteal_rate > 0 and total_damage > 0:
				var stolen: int = int(float(total_damage) * lifesteal_rate)
				if stolen > 0:
					game_manager.heal(stolen)
		if item.shield > 0:
			var total_shield: int = ItemEffectsClass.calculate_shield(item)
			if is_crit:
				total_shield *= 2
			if hero != null:
				hero.add_shield(float(total_shield))
			effect_applied.emit(item.item_name, "shield", total_shield, "self")
			print("🛡️ [%s] 触发！获得 %d 护盾%s" % [item.item_name, total_shield, crit_text])
		if item.heal > 0:
			var total_heal: int = ItemEffectsClass.calculate_heal(item)
			if is_crit:
				total_heal *= 2
			game_manager.heal(total_heal)
			effect_applied.emit(item.item_name, "heal", total_heal, "self")
			print("💚 [%s] 触发！恢复 %d 生命%s" % [item.item_name, total_heal, crit_text])
		if item.has_special_effect():
			_apply_item_special_effects(item, is_crit, burn_bonus, poison_bonus)
		item.current_cooldown = maxf(item.cooldown * (1.0 - cd_reduction), 0.1)

func _trigger_monster_items() -> void:
	if current_monster == null or not current_monster.is_alive():
		return
	var hero: HeroData = null if game_manager == null else game_manager.selected_hero
	var reflect_rate: float = float(_get_passive_combat_stats().get("reflect", 0.0))
	if current_monster.ai != null and current_monster.ai.should_heal(current_monster):
		var heal_amount: int = current_monster.ai.heal_amount
		current_monster.current_hp = mini(current_monster.current_hp + heal_amount, current_monster.max_hp)
		print("👹 [%s] 自我治疗! 恢复 %d HP" % [current_monster.monster_name, heal_amount])
	var damage_mult: float = 1.0 if current_monster.ai == null else current_monster.ai.get_current_damage_multiplier(current_monster)
	for item in current_monster.monster_items:
		if float(item.get("current_cooldown", 0.0)) > 0:
			continue
		var damage: int = maxi(int(float(item.get("damage", 0)) * damage_mult), 0)
		var item_name: String = str(item.get("name", "怪物物品"))
		var shield_absorbed: float = 0.0 if hero == null else hero.remove_shield(float(damage))
		var remaining_damage: int = damage - int(shield_absorbed)
		if remaining_damage > 0:
			game_manager.take_damage(remaining_damage)
		monster_item_triggered.emit(current_monster.monster_name, item_name, damage)
		print("👹 [%s] 的 [%s] 触发！造成 %d 伤害" % [current_monster.monster_name, item_name, damage])
		if shield_absorbed > 0.0:
			print("🛡️ 护盾吸收 %.0f 伤害" % shield_absorbed)
		if reflect_rate > 0 and damage > 0 and current_monster.is_alive():
			var reflected: int = int(float(damage) * reflect_rate)
			if reflected > 0:
				current_monster.take_damage(reflected)
				print("🔄 反弹 %d 伤害!" % reflected)
		if game_manager.player_health <= 0:
			break
		item["current_cooldown"] = maxf(float(item.get("cooldown", 0.0)), 0.1)

func _apply_item_special_effects(item: ItemData, is_crit: bool, burn_bonus: float, poison_bonus: float) -> void:
	var effects: Array[Dictionary] = BattleEffectRuntimeClass.merge_skill_bonuses(ItemEffectsClass.build_active_effects(item, is_crit), burn_bonus, poison_bonus)
	for effect in effects:
		active_effects.append(effect)
		var log_text := BattleEffectRuntimeClass.describe_effect(effect)
		if not log_text.is_empty():
			print(log_text)

func _process_active_effects(elapsed_time: float) -> void:
	for log_text in BattleEffectRuntimeClass.process_active_effects(active_effects, elapsed_time, current_monster, game_manager):
		print(log_text)

func _check_battle_end() -> bool:
	if current_monster != null and not current_monster.is_alive():
		return true
	return game_manager != null and game_manager.player_health <= 0

func get_battle_result() -> Dictionary:
	var monster_killed: bool = current_monster != null and not current_monster.is_alive()
	var player_dead: bool = game_manager != null and game_manager.player_health <= 0
	return {"won": monster_killed, "monster_killed": monster_killed, "player_dead": player_dead}

func get_active_effects_info() -> String:
	return BattleEffectRuntimeClass.get_active_effects_info(active_effects)
