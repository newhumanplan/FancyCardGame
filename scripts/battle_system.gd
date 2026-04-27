extends Node

const PassiveSkillDataClass = preload("res://scripts/data/passive_skill.gd")
const SkillManagerClass = preload("res://scripts/data/skill_manager.gd")
const SkillEffectsClass = preload("res://scripts/data/skill_effects.gd")
const ItemEffectsClass = preload("res://scripts/data/item_effects.gd")
const BattleEffectRuntimeClass = preload("res://scripts/data/battle_effect_runtime.gd")
const BazaarContentClass = preload("res://scripts/data/bazaar_content.gd")

var game_manager: Node
var skill_manager: RefCounted = null
var skill_modifiers: Dictionary = {}
var is_battle_active: bool = false
const BATTLE_TICK: float = 0.5
const MIN_ITEM_COOLDOWN: float = 1.0
const BURN_TICK_SECONDS: float = 0.5
const POISON_REGEN_TICK_SECONDS: float = 1.0
var current_monster: MonsterData = null
var inventory: LinearInventory = null
var player_status_state: Dictionary = {}
var enemy_status_state: Dictionary = {}
var item_runtime_bonuses: Dictionary = {}
var transformed_items: Array[Dictionary] = []
var _skill_target_hero: HeroData = null

signal item_triggered(item_name: String, damage: int, is_crit: bool, target: String)
signal effect_applied(item_name: String, effect_type: String, value: int, target: String)
signal monster_item_triggered(monster_name: String, item_name: String, damage: int)

func _ready() -> void:
	_ensure_game_manager()
	_init_skill_manager()

func _ensure_game_manager() -> void:
	if game_manager == null and has_node("/root/GameManager"):
		game_manager = get_node("/root/GameManager")

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
	_ensure_game_manager()
	is_battle_active = true
	current_monster = monster
	inventory = inv
	player_status_state = _new_status_state()
	enemy_status_state = _new_status_state()
	item_runtime_bonuses.clear()
	transformed_items.clear()
	_refresh_skill_modifiers()
	_reset_player_item_cooldowns(true)
	_apply_player_start_item_effects()
	if current_monster != null:
		if current_monster.ai != null:
			current_monster.ai.apply_to_monster_items(current_monster)
		current_monster.init_item_cooldowns()
		_apply_monster_start_skills()
	_apply_passive_combat_effects()
	print("⚔️ 战斗开始! %s 出现!" % (current_monster.monster_name if current_monster else "???"))

func _apply_monster_start_skills() -> void:
	if current_monster == null or game_manager == null:
		return
	for skill in current_monster.monster_skills:
		var start_poison: int = int(skill.get("start_poison", 0))
		if start_poison > 0:
			_add_status_to_state(player_status_state, ItemEffectsClass.EFFECT_POISON, float(start_poison))
			print("👹 [%s] 技能 [%s] 生效！施加 %d 中毒" % [
				current_monster.monster_name,
				str(skill.get("name", "怪物技能")),
				start_poison
			])
		var start_burn: int = int(skill.get("start_burn", 0))
		if start_burn > 0:
			_add_status_to_state(player_status_state, ItemEffectsClass.EFFECT_BURN, float(start_burn))
			print("👹 [%s] 技能 [%s] 生效！施加 %d 燃烧" % [
				current_monster.monster_name,
				str(skill.get("name", "怪物技能")),
				start_burn
			])
		var start_shield: int = int(skill.get("start_shield", 0))
		if start_shield > 0:
			current_monster.current_shield = maxf(current_monster.current_shield + float(start_shield), 0.0)
			print("👹 [%s] 技能 [%s] 生效！获得 %d 护盾" % [
				current_monster.monster_name,
				str(skill.get("name", "怪物技能")),
				start_shield
			])

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
	_ensure_game_manager()
	is_battle_active = false
	_restore_transformed_items()
	player_status_state = _new_status_state()
	enemy_status_state = _new_status_state()
	item_runtime_bonuses.clear()
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
		item.current_cooldown = _get_effective_cooldown(_get_player_item_effective_cooldown(item)) if fill_to_max else 0.0
		if fill_to_max:
			item.reset_ammo(_get_player_item_effective_max_ammo(item))
		else:
			item.clear_runtime_ammo()

func _get_effective_cooldown(cooldown: float) -> float:
	if cooldown <= 0.0:
		return 0.0
	return maxf(cooldown, MIN_ITEM_COOLDOWN)

func refill_player_item_ammo(item: ItemData, amount: int = 1) -> int:
	_ensure_game_manager()
	if item == null or amount <= 0:
		return 0
	var restored: int = item.refill_ammo(amount)
	if restored > 0 and is_battle_active and inventory != null and inventory.has_item(item) and item.current_cooldown <= 0.0:
		_trigger_player_items()
	return restored

func execute_battle_tick(elapsed_time: float = BATTLE_TICK) -> bool:
	_ensure_game_manager()
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
	return _check_battle_end()

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
	for item in inventory.items.duplicate():
		if item == null or item.current_cooldown > 0:
			continue
		if not _is_active_player_item(item):
			continue
		if not item.can_pay_ammo():
			continue
		if _try_transform_potion_potion(item):
			item.consume_ammo()
			item.current_cooldown = _get_effective_cooldown(_get_player_item_effective_cooldown(item) * (1.0 - cd_reduction))
			continue
		var total_context: Dictionary = _new_use_context()
		var multicast_count: int = _get_player_item_multicast_count(item)
		var item_crit_rate: float = _get_player_item_crit_rate(item, hero_crit_rate)
		for _cast_index in range(multicast_count):
			var is_crit: bool = randf() < item_crit_rate
			var use_context: Dictionary = _trigger_player_item_once(item, is_crit, lifesteal_rate, burn_bonus, poison_bonus)
			_merge_use_context(total_context, use_context)
			if _check_battle_end():
				break
		item.consume_ammo()
		item.current_cooldown = _get_effective_cooldown(_get_player_item_effective_cooldown(item) * (1.0 - cd_reduction))
		_after_player_item_used(item, total_context)

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
	for item_index in range(current_monster.monster_items.size()):
		var item: Dictionary = current_monster.monster_items[item_index]
		var item_cooldown: float = float(item.get("cooldown", 0.0))
		if item_cooldown <= 0.0:
			continue
		if float(item.get("current_cooldown", 0.0)) > 0:
			continue
		var damage: int = maxi(int(float(item.get("damage", 0)) * damage_mult), 0)
		var burn: int = maxi(int(item.get("burn", 0)), 0)
		var poison: int = maxi(int(item.get("poison", 0)), 0)
		var regen: int = maxi(int(item.get("regen", 0)), 0)
		var heal: int = maxi(int(item.get("heal", 0)), 0)
		var shield: int = maxi(int(item.get("shield", 0)), 0)
		var slow_count: int = maxi(int(item.get("slow", 0)), 0)
		var slow_duration: float = maxf(float(item.get("slow_duration", 0.0)), 0.0)
		var freeze_count: int = maxi(int(item.get("freeze", 0)), 0)
		var freeze_duration: float = maxf(float(item.get("freeze_duration", 0.0)), 0.0)
		var haste_count: int = maxi(int(item.get("haste", 0)), 0)
		var haste_duration: float = maxf(float(item.get("haste_duration", 0.0)), 0.0)
		var total_player_damage: int = damage
		var item_name: String = str(item.get("name", "怪物物品"))
		if str(item.get("source_id", "")) == "duct_tape":
			shield = 0
		if heal > 0:
			current_monster.current_hp = mini(current_monster.current_hp + heal, current_monster.max_hp)
			print("👹 [%s] 的 [%s] 触发！恢复 %d 生命" % [current_monster.monster_name, item_name, heal])
		if shield > 0:
			current_monster.current_shield = maxf(current_monster.current_shield + float(shield), 0.0)
			print("👹 [%s] 的 [%s] 触发！获得 %d 护盾" % [current_monster.monster_name, item_name, shield])
		var shield_absorbed: float = 0.0 if hero == null else hero.remove_shield(float(total_player_damage))
		var remaining_damage: int = total_player_damage - int(shield_absorbed)
		if remaining_damage > 0:
			game_manager.take_damage(remaining_damage)
		if burn > 0:
			_add_status_to_state(player_status_state, ItemEffectsClass.EFFECT_BURN, float(burn))
		if poison > 0:
			_add_status_to_state(player_status_state, ItemEffectsClass.EFFECT_POISON, float(poison))
		if regen > 0:
			_add_status_to_state(enemy_status_state, ItemEffectsClass.EFFECT_REGEN, float(regen))
		if slow_count > 0 and slow_duration > 0.0:
			_slow_player_items(slow_count, slow_duration)
		if freeze_count > 0 and freeze_duration > 0.0:
			_slow_player_items(freeze_count, freeze_duration)
		if haste_count > 0 and haste_duration > 0.0:
			_haste_monster_items(haste_count, haste_duration, item_index)
		monster_item_triggered.emit(current_monster.monster_name, item_name, total_player_damage)
		if total_player_damage > 0 or burn > 0 or poison > 0 or regen > 0 or slow_count > 0 or freeze_count > 0 or haste_count > 0:
			var detail_parts: Array[String] = []
			if damage > 0:
				detail_parts.append("%d 伤害" % damage)
			if burn > 0:
				detail_parts.append("%d 燃烧" % burn)
			if poison > 0:
				detail_parts.append("%d 中毒" % poison)
			if regen > 0:
				detail_parts.append("%d 再生" % regen)
			if slow_count > 0 and slow_duration > 0.0:
				detail_parts.append("减速 %d 件 %.1fs" % [slow_count, slow_duration])
			if freeze_count > 0 and freeze_duration > 0.0:
				detail_parts.append("冻结 %d 件 %.1fs" % [freeze_count, freeze_duration])
			if haste_count > 0 and haste_duration > 0.0:
				detail_parts.append("急速 %d 件 %.1fs" % [haste_count, haste_duration])
			print("👹 [%s] 的 [%s] 触发！%s" % [current_monster.monster_name, item_name, "，".join(detail_parts)])
		if shield_absorbed > 0.0:
			print("🛡️ 护盾吸收 %.0f 伤害" % shield_absorbed)
		if reflect_rate > 0 and total_player_damage > 0 and current_monster.is_alive():
			var reflected: int = int(float(total_player_damage) * reflect_rate)
			if reflected > 0:
				current_monster.take_damage(reflected)
				print("🔄 反弹 %d 伤害!" % reflected)
		if game_manager.player_health <= 0:
			break
		item["current_cooldown"] = _get_effective_cooldown(item_cooldown)
		_after_monster_item_used(item_index)

func _new_use_context() -> Dictionary:
	return {
		"use_count": 0,
		"crit_count": 0,
		"damage": 0,
		"heal_proc_count": 0,
		"regen_proc_count": 0,
		"poison_proc_count": 0,
		"burn_proc_count": 0,
		"slow_proc_count": 0,
		"freeze_proc_count": 0,
		"haste_proc_count": 0,
	}

func _merge_use_context(total: Dictionary, context: Dictionary) -> void:
	for key in total.keys():
		total[key] = int(total.get(key, 0)) + int(context.get(key, 0))

func _trigger_player_item_once(item: ItemData, is_crit: bool, passive_lifesteal_rate: float, burn_bonus: float, poison_bonus: float) -> Dictionary:
	var context: Dictionary = _new_use_context()
	context["use_count"] = 1
	if is_crit:
		context["crit_count"] = 1
	var crit_text: String = "（暴击!）" if is_crit else ""
	var hero: HeroData = null if game_manager == null else game_manager.selected_hero
	var runtime_damage: int = int(round(_get_item_runtime_bonus(item, "damage")))
	var item_lifesteal_rate: float = 1.0 if _item_has_lifesteal(item) else 0.0
	var lifesteal_rate: float = clampf(passive_lifesteal_rate + item_lifesteal_rate, 0.0, 1.0)

	if item.damage > 0 and current_monster != null and current_monster.is_alive():
		var base_damage: int = maxi(item.get_rarity_adjusted_damage() + runtime_damage, 0)
		var total_damage: int = base_damage * (2 if is_crit else 1)
		current_monster.take_damage(total_damage)
		context["damage"] = total_damage
		item_triggered.emit(item.item_name, total_damage, is_crit, "enemy")
		print("🗡️ [%s] 触发！造成 %d 伤害%s" % [item.item_name, total_damage, crit_text])
		if lifesteal_rate > 0.0 and total_damage > 0 and game_manager != null:
			var stolen: int = int(float(total_damage) * lifesteal_rate)
			if stolen > 0:
				game_manager.heal(stolen)
				print("💚 [%s] 生命偷取恢复 %d 生命" % [item.item_name, stolen])

	if item.shield > 0 and item.source_id != "duct_tape":
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
		if game_manager != null:
			game_manager.heal(total_heal)
		context["heal_proc_count"] = 1
		effect_applied.emit(item.item_name, "heal", total_heal, "self")
		print("💚 [%s] 触发！恢复 %d 生命%s" % [item.item_name, total_heal, crit_text])

	var status_context: Dictionary = _apply_player_item_status_effects(item, is_crit, burn_bonus, poison_bonus)
	_merge_use_context(context, status_context)
	var tempo_context: Dictionary = _apply_player_item_tempo_effects(item, is_crit)
	_merge_use_context(context, tempo_context)
	return context

func _apply_player_item_status_effects(item: ItemData, is_crit: bool, burn_bonus: float, poison_bonus: float) -> Dictionary:
	var context: Dictionary = _new_use_context()
	var effects: Array = BattleEffectRuntimeClass.merge_skill_bonuses(ItemEffectsClass.build_active_effects(item, is_crit), burn_bonus, poison_bonus)
	var crit_mult: float = 2.0 if is_crit else 1.0
	var extra_poison: float = _get_item_runtime_bonus(item, "poison") + _get_other_emerald_poison_bonus(item)
	if extra_poison > 0.0:
		_add_or_merge_effect(effects, ItemEffectsClass.EFFECT_POISON, "enemy", extra_poison * crit_mult, item.item_name)

	var extra_burn: float = _get_item_runtime_bonus(item, "burn")
	if item.burn_damage > 0.0:
		extra_burn += _get_other_ruby_burn_bonus(item)
	if extra_burn > 0.0:
		_add_or_merge_effect(effects, ItemEffectsClass.EFFECT_BURN, "enemy", extra_burn * crit_mult, item.item_name)

	var extra_regen: float = _get_item_runtime_bonus(item, "regeneration")
	if extra_regen > 0.0:
		_add_or_merge_effect(effects, ItemEffectsClass.EFFECT_REGEN, "self", extra_regen * crit_mult, item.item_name)

	_apply_sword_cane_conditional_effects(item, effects, crit_mult)
	_apply_venomous_dose_self_poison(item, effects, crit_mult)

	for effect in effects:
		if not effect is Dictionary:
			continue
		_apply_status_effect(effect)
		match str((effect as Dictionary).get("type", "")):
			ItemEffectsClass.EFFECT_POISON:
				context["poison_proc_count"] = int(context["poison_proc_count"]) + 1
			ItemEffectsClass.EFFECT_BURN:
				context["burn_proc_count"] = int(context["burn_proc_count"]) + 1
			ItemEffectsClass.EFFECT_REGEN:
				context["regen_proc_count"] = int(context["regen_proc_count"]) + 1
		var log_text := BattleEffectRuntimeClass.describe_effect(effect)
		if not log_text.is_empty():
			print(log_text)
	return context

func _apply_player_item_tempo_effects(item: ItemData, is_crit: bool) -> Dictionary:
	var context: Dictionary = _new_use_context()
	if item == null:
		return context
	var crit_mult: float = 2.0 if is_crit else 1.0

	if item.slow_count > 0 and item.slow_duration > 0.0:
		var slow_count: int = int(round(float(item.slow_count) * crit_mult))
		var slow_duration: float = item.slow_duration * crit_mult
		if _slow_monster_items(slow_count, slow_duration) > 0:
			context["slow_proc_count"] = 1
			effect_applied.emit(item.item_name, ItemEffectsClass.EFFECT_SLOW, int(round(slow_duration)), "enemy")
			print("🐌 [%s] 触发！减速 %d 个敌方物品 %.1f 秒" % [item.item_name, slow_count, slow_duration])

	if item.freeze_count > 0 and item.freeze_duration > 0.0:
		var freeze_count: int = int(round(float(item.freeze_count) * crit_mult))
		var freeze_duration: float = item.freeze_duration * crit_mult
		if _slow_monster_items(freeze_count, freeze_duration) > 0:
			context["freeze_proc_count"] = 1
			effect_applied.emit(item.item_name, ItemEffectsClass.EFFECT_FREEZE, int(round(freeze_duration)), "enemy")
			print("❄️ [%s] 触发！冻结 %d 个敌方物品 %.1f 秒" % [item.item_name, freeze_count, freeze_duration])

	if item.haste_count > 0 and item.haste_duration > 0.0:
		var haste_count: int = int(round(float(item.haste_count) * crit_mult))
		var haste_duration: float = item.haste_duration * crit_mult
		if _haste_player_items(haste_count, haste_duration, item) > 0:
			context["haste_proc_count"] = 1
			effect_applied.emit(item.item_name, ItemEffectsClass.EFFECT_HASTE, int(round(haste_duration)), "self")
			print("⚡ [%s] 触发！急速 %d 个己方物品 %.1f 秒" % [item.item_name, haste_count, haste_duration])

	return context

func _add_or_merge_effect(effects: Array, effect_type: String, target: String, value: float, item_name: String) -> void:
	if value <= 0.0:
		return
	for effect in effects:
		if not effect is Dictionary:
			continue
		var effect_dict: Dictionary = effect
		if str(effect_dict.get("type", "")) == effect_type and str(effect_dict.get("target", "")) == target:
			effect_dict["value"] = float(effect_dict.get("value", 0.0)) + value
			return
	effects.append({
		"type": effect_type,
		"value": value,
		"duration": 0.0,
		"item_name": item_name,
		"target": target,
	})

func _after_player_item_used(item: ItemData, context: Dictionary) -> void:
	if item == null or int(context.get("use_count", 0)) <= 0:
		return
	var use_count: int = int(context.get("use_count", 0))
	if item.source_id == "fungal_spores":
		_apply_fungal_spores_bonus(item, use_count)
	if item.source_id == "mortar_pestle":
		_apply_mortar_pestle_bonus(item, use_count)
	if item.source_id == "magic_carpet" and int(context.get("crit_count", 0)) > 0:
		_add_item_runtime_bonus(item, "cooldown_flat_reduction", float(context.get("crit_count", 0)))
	if _is_small_item(item):
		_charge_items_by_source_id("candles", 2.0 * float(use_count))

	var heal_or_regen_triggers: int = int(context.get("heal_proc_count", 0)) + int(context.get("regen_proc_count", 0))
	if heal_or_regen_triggers > 0:
		_apply_nightshade_heal_reference_bonus(heal_or_regen_triggers)

	var observer_poison_events: int = _apply_right_observer_effects(item, use_count)
	var poison_events: int = int(context.get("poison_proc_count", 0)) + observer_poison_events
	var burn_events: int = int(context.get("burn_proc_count", 0))
	var slow_events: int = int(context.get("slow_proc_count", 0))
	var freeze_events: int = int(context.get("freeze_proc_count", 0))
	var haste_events: int = int(context.get("haste_proc_count", 0))
	if poison_events > 0:
		_handle_player_status_reference(ItemEffectsClass.EFFECT_POISON, poison_events)
	if burn_events > 0:
		_handle_player_status_reference(ItemEffectsClass.EFFECT_BURN, burn_events)
	if slow_events > 0:
		_handle_player_status_reference(ItemEffectsClass.EFFECT_SLOW, slow_events)
	if freeze_events > 0:
		_handle_player_status_reference(ItemEffectsClass.EFFECT_FREEZE, freeze_events)
	if haste_events > 0:
		_handle_player_status_reference(ItemEffectsClass.EFFECT_HASTE, haste_events)
	if slow_events > 0:
		_apply_smelling_salts_haste(item, slow_events)

func _after_monster_item_used(item_index: int) -> void:
	if current_monster == null:
		return
	if item_index < 0 or item_index + 1 >= current_monster.monster_items.size():
		return
	var observer: Dictionary = current_monster.monster_items[item_index + 1]
	if str(observer.get("source_id", "")) != "duct_tape":
		return
	var shield_amount: int = _rarity_value_from_monster_item(observer, [5, 10, 15, 15])
	if shield_amount <= 0:
		return
	current_monster.current_shield = maxf(current_monster.current_shield + float(shield_amount), 0.0)
	print("🛡️ [%s] 的 [Duct Tape] 响应左侧物品，获得 %d 护盾" % [current_monster.monster_name, shield_amount])

func _is_active_player_item(item: ItemData) -> bool:
	if item == null:
		return false
	if item.source_id in ["potion_potion", "fungal_spores", "mortar_pestle", "mothmeal", "smelling_salts", "duct_tape"]:
		return item.cooldown > 0.0
	if item.cooldown <= 0.0:
		return false
	return item.damage > 0 or item.shield > 0 or item.heal > 0 or item.has_special_effect()

func _get_player_item_effective_cooldown(item: ItemData) -> float:
	if item == null or item.cooldown <= 0.0:
		return 0.0
	var cooldown: float = item.cooldown
	for adjacent in _get_adjacent_player_items(item):
		if adjacent != null and adjacent.source_id == "hourglass":
			cooldown *= 1.0 - _get_rarity_value(adjacent, [0.03, 0.06, 0.09, 0.12], 0.0)
	cooldown -= _get_item_runtime_bonus(item, "cooldown_flat_reduction")
	return maxf(cooldown, 0.0)

func _get_player_item_effective_max_ammo(item: ItemData) -> int:
	if item == null:
		return 0
	var max_ammo: int = maxi(item.ammo, 0)
	if inventory == null or not _is_potion_item(item):
		return max_ammo
	var right_item: ItemData = inventory.get_right_adjacent_item(item)
	if right_item != null and right_item.source_id == "tazidian_dagger":
		max_ammo += int(_get_rarity_value(right_item, [1, 2, 3, 4], 1.0))
	return max_ammo

func _get_player_item_crit_rate(item: ItemData, hero_crit_rate: float) -> float:
	if item == null:
		return clampf(hero_crit_rate, 0.0, 1.0)
	var crit_rate: float = hero_crit_rate + item.crit_chance
	var right_item: ItemData = null if inventory == null else inventory.get_right_adjacent_item(item)
	if right_item != null and right_item.source_id == "optical_augment":
		crit_rate += float(player_status_state.get("poison", 0.0)) / 100.0
	return clampf(crit_rate, 0.0, 1.0)

func _get_player_item_multicast_count(item: ItemData) -> int:
	if item == null:
		return 1
	var count: int = 1
	if item.source_id == "aludel":
		for adjacent in _get_adjacent_player_items(item):
			if _is_potion_item(adjacent) or _is_reagent_item(adjacent):
				count += 1
	elif item.source_id == "quill_and_ink" and not _has_other_weapon_item(item):
		count += 1
	elif item.source_id == "barbed_claws":
		if float(player_status_state.get("poison", 0.0)) > 0.0:
			count += 1
		if float(enemy_status_state.get("poison", 0.0)) > 0.0:
			count += 1
	return maxi(count, 1)

func _get_item_runtime_bonus(item: ItemData, key: String) -> float:
	if item == null:
		return 0.0
	var item_id: int = item.get_instance_id()
	if not item_runtime_bonuses.has(item_id):
		return 0.0
	var bonuses: Dictionary = item_runtime_bonuses.get(item_id, {})
	return float(bonuses.get(key, 0.0))

func _add_item_runtime_bonus(item: ItemData, key: String, value: float) -> void:
	if item == null or value == 0.0:
		return
	var item_id: int = item.get_instance_id()
	if not item_runtime_bonuses.has(item_id):
		item_runtime_bonuses[item_id] = {}
	var bonuses: Dictionary = item_runtime_bonuses[item_id]
	bonuses[key] = float(bonuses.get(key, 0.0)) + value

func _apply_fungal_spores_bonus(source_item: ItemData, use_count: int) -> void:
	if inventory == null or source_item == null:
		return
	var bonus: float = _get_rarity_value(source_item, [2, 3, 4, 5], 2.0) * float(maxi(use_count, 1))
	for candidate in inventory.items:
		if candidate != null and candidate != source_item and _is_poison_item(candidate):
			_add_item_runtime_bonus(candidate, "poison", bonus)
	print("☠️ [%s] 触发！所有 Poison 物品本场战斗获得 +%.0f Poison" % [source_item.item_name, bonus])

func _apply_mortar_pestle_bonus(source_item: ItemData, use_count: int) -> void:
	if inventory == null or source_item == null:
		return
	var bonus: float = _get_rarity_value(source_item, [10, 15, 20, 25], 10.0) * float(maxi(use_count, 1))
	for candidate in inventory.items:
		if candidate != null and _is_weapon_item(candidate) and _item_has_lifesteal(candidate):
			_add_item_runtime_bonus(candidate, "damage", bonus)
	print("🗡️ [%s] 触发！生命偷取武器本场战斗获得 +%.0f 伤害" % [source_item.item_name, bonus])

func _apply_nightshade_heal_reference_bonus(trigger_count: int) -> void:
	if inventory == null or trigger_count <= 0:
		return
	for candidate in inventory.items:
		if candidate != null and candidate.source_id == "nightshade":
			var bonus: float = _get_rarity_value(candidate, [2, 4, 6, 8], 2.0) * float(trigger_count)
			_add_item_runtime_bonus(candidate, "poison", bonus)
			print("☠️ [%s] 因治疗/再生获得 +%.0f Poison" % [candidate.item_name, bonus])

func _apply_right_observer_effects(item: ItemData, use_count: int) -> int:
	if inventory == null or item == null or use_count <= 0:
		return 0
	var poison_events: int = 0
	var right_item: ItemData = inventory.get_right_adjacent_item(item)
	if right_item == null:
		return 0
	if right_item.source_id == "venom" and _is_weapon_item(item):
		var poison_amount: float = (_get_rarity_value(right_item, [2, 3, 4, 5], 2.0) + _get_item_runtime_bonus(right_item, "poison")) * float(use_count)
		_apply_status_effect({
			"type": ItemEffectsClass.EFFECT_POISON,
			"value": poison_amount,
			"duration": 0.0,
			"item_name": right_item.item_name,
			"target": "enemy",
		})
		poison_events += use_count
		print("☠️ [%s] 响应左侧武器，施加中毒 +%d!" % [right_item.item_name, int(round(poison_amount))])
	elif right_item.source_id == "duct_tape":
		var hero: HeroData = null if game_manager == null else game_manager.selected_hero
		var shield_amount: int = int(round(_get_rarity_value(right_item, [5, 10, 15, 15], 5) * float(use_count)))
		if hero != null:
			hero.add_shield(float(shield_amount))
		effect_applied.emit(right_item.item_name, "shield", shield_amount, "self")
		print("🛡️ [%s] 响应左侧物品，获得 %d 护盾" % [right_item.item_name, shield_amount])
	return poison_events

func _handle_player_status_reference(status_type: String, trigger_count: int) -> void:
	if inventory == null or trigger_count <= 0:
		return
	for candidate in inventory.items:
		if candidate == null:
			continue
		if status_type == ItemEffectsClass.EFFECT_POISON:
			if candidate.source_id == "leeches":
				_add_item_runtime_bonus(candidate, "damage", _get_rarity_value(candidate, [10, 15, 20, 25], 10.0) * float(trigger_count))
			elif candidate.source_id == "spider_mace":
				_charge_player_item(candidate, 2.0 * float(trigger_count))
			elif candidate.source_id == "refractor":
				_add_item_runtime_bonus(candidate, "damage", _get_rarity_value(candidate, [10, 20, 30, 40], 10.0) * float(trigger_count))
		elif status_type == ItemEffectsClass.EFFECT_BURN and candidate.source_id == "refractor":
			_add_item_runtime_bonus(candidate, "damage", _get_rarity_value(candidate, [10, 20, 30, 40], 10.0) * float(trigger_count))
		elif status_type == ItemEffectsClass.EFFECT_SLOW:
			if candidate.source_id == "fireflies":
				_add_item_runtime_bonus(candidate, "burn", _get_rarity_value(candidate, [1, 2, 3, 4], 1.0) * float(trigger_count))
			elif candidate.source_id == "spider_mace":
				_charge_player_item(candidate, 2.0 * float(trigger_count))
			elif candidate.source_id == "refractor":
				_add_item_runtime_bonus(candidate, "damage", _get_rarity_value(candidate, [10, 20, 30, 40], 10.0) * float(trigger_count))
			elif candidate.source_id == "magnus_femur":
				_charge_player_item(candidate, 2.0 * float(trigger_count))
				_add_item_runtime_bonus(candidate, "damage", _get_rarity_value(candidate, [25, 50, 75], 25.0) * float(trigger_count))
		elif status_type == ItemEffectsClass.EFFECT_FREEZE:
			if candidate.source_id == "refractor":
				_add_item_runtime_bonus(candidate, "damage", _get_rarity_value(candidate, [10, 20, 30, 40], 10.0) * float(trigger_count))
			elif candidate.source_id == "ice_claw":
				_add_item_runtime_bonus(candidate, "damage", _get_rarity_value(candidate, [20, 30, 40, 50], 20.0) * float(trigger_count))
			elif candidate.source_id == "black_ice":
				_apply_status_effect({
					"type": ItemEffectsClass.EFFECT_POISON,
					"value": _get_rarity_value(candidate, [6, 8, 10], 6.0) * float(trigger_count),
					"duration": 0.0,
					"item_name": candidate.item_name,
					"target": "enemy",
				})
			elif candidate.source_id == "frozen_flame":
				_add_item_runtime_bonus(candidate, "burn", _get_rarity_value(candidate, [4, 8, 12], 4.0) * float(trigger_count))
		elif status_type == ItemEffectsClass.EFFECT_HASTE:
			if candidate.source_id == "earrings":
				_charge_player_item(candidate, 1.0 * float(trigger_count))

func _apply_smelling_salts_haste(source_item: ItemData, trigger_count: int) -> void:
	if inventory == null or source_item == null or trigger_count <= 0:
		return
	for salts in inventory.items:
		if salts == null or salts.source_id != "smelling_salts":
			continue
		if salts != source_item and not _get_adjacent_player_items(salts).has(source_item):
			continue
		var left_item: ItemData = inventory.get_left_adjacent_item(salts)
		if left_item == null:
			continue
		var seconds: float = _get_rarity_value(salts, [1, 2, 3, 4], 1.0) * float(trigger_count)
		_charge_player_item(left_item, seconds)
		print("⚡ [Smelling Salts] 响应减速，急速左侧物品 %.1f 秒" % seconds)

func _apply_sword_cane_conditional_effects(item: ItemData, effects: Array, crit_mult: float) -> void:
	if item == null or item.source_id != "sword_cane":
		return
	var amount: float = _get_rarity_value(item, [2, 4, 6, 8], 2.0)
	if _has_adjacent_status_item(item, ItemEffectsClass.EFFECT_REGEN):
		_add_or_merge_effect(effects, ItemEffectsClass.EFFECT_REGEN, "self", amount * crit_mult, item.item_name)
	if _has_adjacent_status_item(item, ItemEffectsClass.EFFECT_BURN):
		var burn_amount: float = amount + _get_other_ruby_burn_bonus(item)
		_add_or_merge_effect(effects, ItemEffectsClass.EFFECT_BURN, "enemy", burn_amount * crit_mult, item.item_name)
	if _has_adjacent_status_item(item, ItemEffectsClass.EFFECT_POISON):
		_add_or_merge_effect(effects, ItemEffectsClass.EFFECT_POISON, "enemy", amount * crit_mult, item.item_name)

func _apply_venomous_dose_self_poison(item: ItemData, effects: Array, crit_mult: float) -> void:
	if item == null or item.source_id != "venomous_dose":
		return
	var self_poison: float = item.poison_damage * item.get_rarity_multiplier() * crit_mult
	self_poison += (_get_item_runtime_bonus(item, "poison") + _get_other_emerald_poison_bonus(item)) * crit_mult
	if self_poison > 0.0:
		_add_or_merge_effect(effects, ItemEffectsClass.EFFECT_POISON, "self", self_poison, item.item_name)

func _apply_player_start_item_effects() -> void:
	if inventory == null:
		return
	for item in inventory.items:
		if item == null or item.source_id != "optical_augment":
			continue
		var poison_amount: float = _get_rarity_value(item, [4, 8, 12, 16], 4.0)
		_apply_status_effect({
			"type": ItemEffectsClass.EFFECT_POISON,
			"value": poison_amount,
			"duration": 0.0,
			"item_name": item.item_name,
			"target": "self",
		})
		print("☠️ [%s] 开战时对自己施加中毒 +%d" % [item.item_name, int(poison_amount)])

func _get_other_emerald_poison_bonus(item: ItemData) -> float:
	if inventory == null or item == null:
		return 0.0
	var bonus: float = 0.0
	for candidate in inventory.items:
		if candidate != null and candidate != item and candidate.source_id == "emerald":
			bonus += _get_rarity_value(candidate, [3, 4, 5, 6], 3.0)
	return bonus

func _get_other_ruby_burn_bonus(item: ItemData) -> float:
	if inventory == null or item == null:
		return 0.0
	var bonus: float = 0.0
	for candidate in inventory.items:
		if candidate != null and candidate != item and candidate.source_id == "ruby":
			bonus += _get_rarity_value(candidate, [3, 4, 5, 6], 3.0)
	return bonus

func _charge_items_by_source_id(source_id: String, seconds: float) -> void:
	if inventory == null or seconds <= 0.0:
		return
	for candidate in inventory.items:
		if candidate != null and candidate.source_id == source_id:
			_charge_player_item(candidate, seconds)

func _charge_player_item(item: ItemData, seconds: float) -> void:
	if item == null or seconds <= 0.0 or item.current_cooldown <= 0.0:
		return
	item.current_cooldown = maxf(item.current_cooldown - seconds, 0.0)

func _slow_monster_items(count: int, seconds: float) -> int:
	if current_monster == null or count <= 0 or seconds <= 0.0:
		return 0
	var candidates: Array[int] = []
	for index in range(current_monster.monster_items.size()):
		var monster_item: Dictionary = current_monster.monster_items[index]
		if float(monster_item.get("cooldown", 0.0)) > 0.0:
			candidates.append(index)
	candidates.sort_custom(func(a: int, b: int) -> bool:
		return float(current_monster.monster_items[a].get("current_cooldown", 0.0)) > float(current_monster.monster_items[b].get("current_cooldown", 0.0))
	)
	var applied: int = 0
	for index in candidates:
		if applied >= count:
			break
		var monster_item: Dictionary = current_monster.monster_items[index]
		monster_item["current_cooldown"] = maxf(float(monster_item.get("current_cooldown", 0.0)) + seconds, 0.0)
		applied += 1
	return applied

func _slow_player_items(count: int, seconds: float) -> int:
	if inventory == null or count <= 0 or seconds <= 0.0:
		return 0
	var candidates: Array[ItemData] = []
	for item in inventory.items:
		if item != null and item.cooldown > 0.0:
			candidates.append(item)
	candidates.sort_custom(func(a: ItemData, b: ItemData) -> bool:
		return a.current_cooldown > b.current_cooldown
	)
	var applied: int = 0
	for item in candidates:
		if applied >= count:
			break
		item.current_cooldown = maxf(item.current_cooldown + seconds, 0.0)
		applied += 1
	return applied

func _haste_player_items(count: int, seconds: float, source_item: ItemData = null) -> int:
	if inventory == null or count <= 0 or seconds <= 0.0:
		return 0
	var candidates: Array[ItemData] = []
	for item in inventory.items:
		if item != null and item != source_item and item.cooldown > 0.0:
			candidates.append(item)
	candidates.sort_custom(func(a: ItemData, b: ItemData) -> bool:
		return a.current_cooldown > b.current_cooldown
	)
	var applied: int = 0
	for item in candidates:
		if applied >= count:
			break
		_charge_player_item(item, seconds)
		applied += 1
	return applied

func _haste_monster_items(count: int, seconds: float, source_index: int = -1) -> int:
	if current_monster == null or count <= 0 or seconds <= 0.0:
		return 0
	var candidates: Array[int] = []
	for index in range(current_monster.monster_items.size()):
		if index == source_index:
			continue
		var monster_item: Dictionary = current_monster.monster_items[index]
		if float(monster_item.get("cooldown", 0.0)) > 0.0:
			candidates.append(index)
	candidates.sort_custom(func(a: int, b: int) -> bool:
		return float(current_monster.monster_items[a].get("current_cooldown", 0.0)) > float(current_monster.monster_items[b].get("current_cooldown", 0.0))
	)
	var applied: int = 0
	for index in candidates:
		if applied >= count:
			break
		var monster_item: Dictionary = current_monster.monster_items[index]
		monster_item["current_cooldown"] = maxf(float(monster_item.get("current_cooldown", 0.0)) - seconds, 0.0)
		applied += 1
	return applied

func _get_adjacent_player_items(item: ItemData) -> Array:
	if inventory == null or item == null:
		return []
	return inventory.get_adjacent_items(item)

func _has_adjacent_status_item(item: ItemData, status_type: String) -> bool:
	for adjacent in _get_adjacent_player_items(item):
		if status_type == ItemEffectsClass.EFFECT_POISON and _is_poison_item(adjacent):
			return true
		if status_type == ItemEffectsClass.EFFECT_BURN and _is_burn_item(adjacent):
			return true
		if status_type == ItemEffectsClass.EFFECT_REGEN and _is_regen_item(adjacent):
			return true
	return false

func _has_other_weapon_item(item: ItemData) -> bool:
	if inventory == null:
		return false
	for candidate in inventory.items:
		if candidate != null and candidate != item and _is_weapon_item(candidate):
			return true
	return false

func _item_has_lifesteal(item: ItemData) -> bool:
	if item == null:
		return false
	if _item_has_tag(item, "Lifesteal"):
		return true
	if inventory == null or not _is_weapon_item(item):
		return false
	var left_item: ItemData = inventory.get_left_adjacent_item(item)
	return left_item != null and left_item.source_id == "mortar_pestle"

func _is_weapon_item(item: ItemData) -> bool:
	return item != null and (_item_has_tag(item, "Weapon") or item.type == ItemData.Type.WEAPON)

func _is_potion_item(item: ItemData) -> bool:
	return item != null and _item_has_tag(item, "Potion")

func _is_reagent_item(item: ItemData) -> bool:
	return item != null and _item_has_tag(item, "Reagent")

func _is_small_item(item: ItemData) -> bool:
	return item != null and item.get_slot_count() == 1

func _is_poison_item(item: ItemData) -> bool:
	return item != null and (_item_has_tag(item, "Poison") or item.poison_damage > 0.0 or _get_item_runtime_bonus(item, "poison") > 0.0)

func _is_burn_item(item: ItemData) -> bool:
	return item != null and (_item_has_tag(item, "Burn") or item.burn_damage > 0.0 or _get_item_runtime_bonus(item, "burn") > 0.0)

func _is_regen_item(item: ItemData) -> bool:
	return item != null and (_item_has_tag(item, "Regen") or item.regeneration > 0.0 or _get_item_runtime_bonus(item, "regeneration") > 0.0)

func _item_has_tag(item: ItemData, tag: String) -> bool:
	if item == null:
		return false
	var needle: String = tag.to_lower()
	for item_tag in item.tags:
		if item_tag.to_lower() == needle:
			return true
	return false

func _get_rarity_value(item: ItemData, values: Array, fallback: float = 0.0) -> float:
	if item == null or values.is_empty():
		return fallback
	var index: int = clampi(item.rarity - 1, 0, values.size() - 1)
	return float(values[index])

func _rarity_value_from_monster_item(item: Dictionary, values: Array) -> int:
	if values.is_empty():
		return 0
	var rarity: int = int(item.get("rarity", 1))
	var index: int = clampi(rarity - 1, 0, values.size() - 1)
	return int(values[index])

func _process_active_effects(elapsed_time: float) -> void:
	_process_status_state("player", player_status_state, elapsed_time)
	_process_status_state("enemy", enemy_status_state, elapsed_time)

func get_status_totals(target: String) -> Dictionary:
	return _status_public_values(enemy_status_state if target == "enemy" else player_status_state)

func _check_battle_end() -> bool:
	if current_monster != null and not current_monster.is_alive():
		return true
	return game_manager != null and game_manager.player_health <= 0

func get_battle_result() -> Dictionary:
	var monster_killed: bool = current_monster != null and not current_monster.is_alive()
	var player_dead: bool = game_manager != null and game_manager.player_health <= 0
	return {"won": monster_killed, "monster_killed": monster_killed, "player_dead": player_dead}

func get_active_effects_info() -> String:
	var player_status: Dictionary = _status_public_values(player_status_state)
	var enemy_status: Dictionary = _status_public_values(enemy_status_state)
	return "状态效果:\n玩家: Burn %.0f / Poison %.0f / Regen %.0f\n敌方: Burn %.0f / Poison %.0f / Regen %.0f\n" % [
		float(player_status.get("burn", 0.0)),
		float(player_status.get("poison", 0.0)),
		float(player_status.get("regeneration", 0.0)),
		float(enemy_status.get("burn", 0.0)),
		float(enemy_status.get("poison", 0.0)),
		float(enemy_status.get("regeneration", 0.0)),
	]

func _new_status_state() -> Dictionary:
	return {
		"burn": 0.0,
		"poison": 0.0,
		"regeneration": 0.0,
		"burn_tick": 0.0,
		"poison_regen_tick": 0.0,
	}

func _status_public_values(state: Dictionary) -> Dictionary:
	return {
		"burn": float(state.get("burn", 0.0)),
		"poison": float(state.get("poison", 0.0)),
		"regeneration": float(state.get("regeneration", 0.0)),
	}

func _apply_status_effect(effect: Dictionary) -> void:
	var effect_type: String = str(effect.get("type", ""))
	var value: float = float(effect.get("value", 0.0))
	if value <= 0.0:
		return
	var target: String = str(effect.get("target", "enemy"))
	_add_status_to_state(enemy_status_state if target == "enemy" else player_status_state, effect_type, value)
	effect_applied.emit(str(effect.get("item_name", "物品")), effect_type, int(round(value)), target)

func _add_status_to_state(state: Dictionary, effect_type: String, value: float) -> void:
	if value <= 0.0:
		return
	match effect_type:
		ItemEffectsClass.EFFECT_BURN:
			state["burn"] = maxf(float(state.get("burn", 0.0)) + value, 0.0)
		ItemEffectsClass.EFFECT_POISON:
			state["poison"] = maxf(float(state.get("poison", 0.0)) + value, 0.0)
		ItemEffectsClass.EFFECT_REGEN:
			state["regeneration"] = maxf(float(state.get("regeneration", 0.0)) + value, 0.0)

func _process_status_state(target: String, state: Dictionary, elapsed_time: float) -> void:
	var delta: float = maxf(elapsed_time, 0.0)
	if delta <= 0.0:
		return

	state["burn_tick"] = float(state.get("burn_tick", 0.0)) + delta
	while float(state["burn_tick"]) >= BURN_TICK_SECONDS:
		state["burn_tick"] = float(state["burn_tick"]) - BURN_TICK_SECONDS
		var burn_value: float = float(state.get("burn", 0.0))
		if burn_value <= 0.0:
			continue
		_apply_status_damage(target, int(round(burn_value)), true)
		state["burn"] = maxf(burn_value - 1.0, 0.0)

	state["poison_regen_tick"] = float(state.get("poison_regen_tick", 0.0)) + delta
	while float(state["poison_regen_tick"]) >= POISON_REGEN_TICK_SECONDS:
		state["poison_regen_tick"] = float(state["poison_regen_tick"]) - POISON_REGEN_TICK_SECONDS
		var regen_value: float = float(state.get("regeneration", 0.0))
		if regen_value > 0.0:
			_apply_status_heal(target, int(round(regen_value)))
			state["poison"] = maxf(float(state.get("poison", 0.0)) - regen_value, 0.0)
		var poison_value: float = float(state.get("poison", 0.0))
		if poison_value > 0.0:
			_apply_status_damage(target, int(round(poison_value)), false)

func _apply_status_damage(target: String, raw_damage: int, is_burn: bool) -> void:
	var damage: int = maxi(raw_damage, 0)
	if damage <= 0:
		return
	if target == "enemy":
		if current_monster == null or not current_monster.is_alive():
			return
		if is_burn and current_monster.current_shield > 0.0:
			damage = maxi(int(ceil(float(damage) * 0.5)), 1)
		if is_burn:
			current_monster.take_damage(damage)
		else:
			current_monster.current_hp = maxi(current_monster.current_hp - damage, 0)
		return

	if game_manager == null:
		return
	var hero: HeroData = null if game_manager.selected_hero == null else game_manager.selected_hero
	if is_burn:
		if hero != null and hero.current_shield > 0.0:
			damage = maxi(int(ceil(float(damage) * 0.5)), 1)
			var absorbed: float = hero.remove_shield(float(damage))
			damage = maxi(damage - int(absorbed), 0)
		if damage > 0:
			game_manager.take_damage(damage)
	else:
		game_manager.take_damage(damage)

func _apply_status_heal(target: String, amount: int) -> void:
	var heal_amount: int = maxi(amount, 0)
	if heal_amount <= 0:
		return
	if target == "enemy":
		if current_monster != null and current_monster.is_alive():
			current_monster.current_hp = mini(current_monster.current_hp + heal_amount, current_monster.max_hp)
	else:
		if game_manager != null:
			game_manager.heal(heal_amount)

func _try_transform_potion_potion(item: ItemData) -> bool:
	if item == null:
		return false
	if item.source_id != "potion_potion" and item.item_name != "Potion Potion":
		return false
	if inventory == null or item.slot_index < 0:
		return false
	var start_slot: int = item.slot_index
	var potion_a: ItemData = BazaarContentClass.create_random_mak_day1_item(item.rarity, "Small", "Potion", false)
	var potion_b: ItemData = BazaarContentClass.create_random_mak_day1_item(item.rarity, "Small", "Potion", false)
	if potion_a == null or potion_b == null:
		return false
	potion_a.current_cooldown = 0.0
	potion_b.current_cooldown = 0.0
	if not inventory.remove_item(item):
		return false
	if not inventory.place_item(potion_a, start_slot):
		inventory.place_item(item, start_slot)
		return false
	if not inventory.place_item(potion_b, start_slot + 1):
		inventory.remove_item(potion_a)
		inventory.place_item(item, start_slot)
		return false
	transformed_items.append({
		"original": item,
		"start_slot": start_slot,
		"generated": [potion_a, potion_b],
	})
	item_triggered.emit(item.item_name, 0, false, "self")
	print("🧪 [%s] 触发！本场战斗变形成两个小型药水" % item.item_name)
	return true

func _restore_transformed_items() -> void:
	if inventory == null or transformed_items.is_empty():
		transformed_items.clear()
		return
	for transform in transformed_items:
		var generated: Array = transform.get("generated", [])
		for generated_item in generated:
			if generated_item is ItemData and generated_item.slot_index >= 0:
				inventory.remove_item(generated_item)
		var original: ItemData = transform.get("original", null) as ItemData
		var start_slot: int = int(transform.get("start_slot", -1))
		if original != null and start_slot >= 0 and inventory.can_place_item(original, start_slot):
			inventory.place_item(original, start_slot)
	transformed_items.clear()
