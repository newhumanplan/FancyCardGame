extends Node

const PassiveSkillDataClass = preload("res://scripts/data/passive_skill.gd")
const PlayerSkillCatalogClass = preload("res://scripts/data/player_skill_catalog.gd")
const SkillManagerClass = preload("res://scripts/data/skill_manager.gd")
const SkillEffectsClass = preload("res://scripts/data/skill_effects.gd")
const ItemEffectsClass = preload("res://scripts/data/item_effects.gd")
const BattleEffectRuntimeClass = preload("res://scripts/data/battle_effect_runtime.gd")
const BazaarContentClass = preload("res://scripts/data/bazaar_content.gd")
const EffectDefinitionClass = preload("res://scripts/data/effect_definition.gd")

var game_manager: Node
var skill_manager: RefCounted = null
var skill_modifiers: Dictionary = {}
var player_skill_refs: Array[Dictionary] = []
var player_skill_map: Dictionary = {}
var player_skill_counters: Dictionary = {}
var is_battle_active: bool = false
const BATTLE_TICK: float = 0.5
const MIN_ITEM_COOLDOWN: float = 1.0
const BURN_TICK_SECONDS: float = 0.5
const POISON_REGEN_TICK_SECONDS: float = 1.0
const EFFECT_CHAIN_DEPTH_LIMIT: int = 8
const MAX_TRIGGERED_EFFECTS_PER_TICK: int = 64
var current_monster: MonsterData = null
var inventory: LinearInventory = null
var player_status_state: Dictionary = {}
var enemy_status_state: Dictionary = {}
var item_runtime_bonuses: Dictionary = {}
var transformed_items: Array[Dictionary] = []
var _skill_target_hero: HeroData = null
var effect_execution_trace: Array[Dictionary] = []
var effect_warnings: Array[String] = []
var _effect_runtime_state: Dictionary = {}
var _battle_elapsed_time: float = 0.0
var _effect_event_id_counter: int = 0

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
	_refresh_skill_modifiers()

func _refresh_skill_modifiers() -> void:
	skill_modifiers = {}
	player_skill_refs.clear()
	player_skill_map.clear()
	if game_manager == null or game_manager.selected_hero == null or skill_manager == null:
		return
	skill_manager.clear()
	if _skill_target_hero != game_manager.selected_hero:
		game_manager.selected_hero.refresh_skill_base_stats()
		_skill_target_hero = game_manager.selected_hero
	player_skill_refs = PlayerSkillCatalogClass.resolve_skill_refs(game_manager.selected_hero.skills)
	for skill_ref in player_skill_refs:
		var skill_id: String = str(skill_ref.get("id", ""))
		if skill_id.is_empty():
			continue
		player_skill_map[skill_id] = skill_ref
		var skill_data: SkillData = PlayerSkillCatalogClass.build_skill_data(skill_ref)
		if skill_data != null:
			skill_manager.equip_skill(skill_data)
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
	effect_execution_trace.clear()
	effect_warnings.clear()
	_effect_runtime_state.clear()
	_battle_elapsed_time = 0.0
	_effect_event_id_counter = 0
	_refresh_skill_modifiers()
	player_skill_counters.clear()
	_reset_player_item_cooldowns(true)
	_log_effect_support_warnings()
	_apply_player_start_item_effects()
	_apply_run_battle_start_status_bonuses()
	_apply_player_skill_battle_start_effects()
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
		var skill_id: String = str(skill.get("id", ""))
		match skill_id:
			"power_broker":
				_apply_monster_power_broker(skill)
			"prosperity":
				_apply_monster_prosperity(skill)

func _apply_monster_skill_item_used_triggers(item_index: int, item: Dictionary, is_crit: bool) -> void:
	if current_monster == null:
		return
	if _monster_item_starts_flying(item):
		_set_monster_item_flying(item_index, "source_item_start_flying")
	for skill_ref in PlayerSkillCatalogClass.resolve_skill_refs(current_monster.monster_skills):
		var skill_id: String = str(skill_ref.get("id", ""))
		match skill_id:
			"flashy_mechanic":
				if not _monster_item_has_tag(item, "Tool"):
					continue
				var bonus: float = PlayerSkillCatalogClass.get_tier_value(skill_ref) / 100.0
				var applied_count: int = 0
				for adjacent_index in _get_adjacent_monster_item_indexes(item_index):
					var adjacent_item: Dictionary = current_monster.monster_items[adjacent_index]
					adjacent_item["crit_chance"] = clampf(float(adjacent_item.get("crit_chance", 0.0)) + bonus, 0.0, 3.0)
					applied_count += 1
				if applied_count > 0:
					_record_monster_skill_trace(skill_id, "flashy_mechanic_tool_adjacent_crit", EffectDefinitionClass.TRIGGER_ON_TAG_USED, EffectDefinitionClass.EFFECT_RUNTIME_BONUS, bonus, applied_count)
			"flashy_reload":
				if not is_crit:
					continue
				var reload_amount: int = maxi(int(round(PlayerSkillCatalogClass.get_tier_value(skill_ref))), 1)
				if _reload_other_monster_ammo_item(item_index, reload_amount):
					_record_monster_skill_trace(skill_id, "flashy_reload_on_crit_reload_ammo", EffectDefinitionClass.TRIGGER_ON_CRIT, EffectDefinitionClass.EFFECT_RELOAD, float(reload_amount), 1)
			"haunting_flight":
				if bool(_effect_runtime_state.get("monster_haunting_flight_triggered", false)):
					continue
				var flying_count: int = maxi(int(round(PlayerSkillCatalogClass.get_tier_value(skill_ref))), 1)
				var started_count: int = _start_monster_small_items_flying(flying_count)
				if started_count > 0:
					_effect_runtime_state["monster_haunting_flight_triggered"] = true
					_record_monster_skill_trace(skill_id, "haunting_flight_first_item_small_items_start_flying", EffectDefinitionClass.TRIGGER_ON_ITEM_USED, EffectDefinitionClass.EFFECT_RUNTIME_BONUS, float(started_count), started_count)
			"into_the_void":
				if bool(_effect_runtime_state.get("monster_into_the_void_triggered", false)):
					continue
				_effect_runtime_state["monster_into_the_void_triggered"] = true
				var destroyed_total: int = _destroy_random_player_item_for_fight("into_the_void") + _destroy_random_monster_item_for_fight("into_the_void")
				_record_monster_skill_trace(skill_id, "into_the_void_first_item_destroy_each_board_for_fight", EffectDefinitionClass.TRIGGER_ON_ITEM_USED, EffectDefinitionClass.EFFECT_RUNTIME_BONUS, float(destroyed_total), destroyed_total)

func _apply_monster_skill_status_trigger(status_type: String, trigger_count: int) -> void:
	if current_monster == null or trigger_count <= 0:
		return
	for skill_ref in PlayerSkillCatalogClass.resolve_skill_refs(current_monster.monster_skills):
		var skill_id: String = str(skill_ref.get("id", ""))
		match skill_id:
			"time_to_tinker":
				if status_type != EffectDefinitionClass.EFFECT_HASTE:
					continue
				var shield_amount: int = int(round(PlayerSkillCatalogClass.get_tier_value(skill_ref) * float(trigger_count)))
				if shield_amount <= 0:
					continue
				current_monster.current_shield = maxf(current_monster.current_shield + float(shield_amount), 0.0)
				_record_monster_skill_trace(skill_id, "time_to_tinker_on_haste_shield", EffectDefinitionClass.TRIGGER_ON_ENEMY_STATUS_APPLIED, EffectDefinitionClass.EFFECT_SHIELD, float(shield_amount), 1)
			"chilling_touch":
				if status_type != EffectDefinitionClass.EFFECT_FREEZE:
					continue
				if bool(_effect_runtime_state.get("monster_chilling_touch_triggered", false)):
					continue
				var slow_seconds: float = PlayerSkillCatalogClass.get_tier_value(skill_ref)
				var slowed_count: int = _slow_player_items(99, slow_seconds)
				if slowed_count <= 0:
					continue
				_effect_runtime_state["monster_chilling_touch_triggered"] = true
				_record_monster_skill_trace(skill_id, "chilling_touch_first_freeze_slow_all_enemy_items", EffectDefinitionClass.TRIGGER_ON_ENEMY_STATUS_APPLIED, EffectDefinitionClass.EFFECT_SLOW, slow_seconds, slowed_count)

func _apply_monster_first_below_half_health_triggers() -> void:
	if current_monster == null:
		return
	for skill_ref in PlayerSkillCatalogClass.resolve_skill_refs(current_monster.monster_skills):
		var skill_id: String = str(skill_ref.get("id", ""))
		match skill_id:
			"hard_shell", "hunker_down":
				var shield_percent: float = PlayerSkillCatalogClass.get_tier_value(skill_ref) / 100.0
				var shield_amount: int = int(round(float(current_monster.max_hp) * shield_percent))
				if shield_amount <= 0:
					continue
				current_monster.current_shield = maxf(current_monster.current_shield + float(shield_amount), 0.0)
				_record_monster_skill_trace(skill_id, "%s_first_below_half_health_shield" % skill_id, EffectDefinitionClass.TRIGGER_ON_DAMAGE_TAKEN, EffectDefinitionClass.EFFECT_SHIELD, float(shield_amount), 1)
			"petrifying_gaze":
				var freeze_seconds: float = PlayerSkillCatalogClass.get_tier_value(skill_ref)
				var frozen_count: int = _slow_player_items(99, freeze_seconds)
				if frozen_count <= 0:
					continue
				_record_monster_skill_trace(skill_id, "petrifying_gaze_first_below_half_health_freeze_all_enemy_items", EffectDefinitionClass.TRIGGER_ON_DAMAGE_TAKEN, EffectDefinitionClass.EFFECT_FREEZE, freeze_seconds, frozen_count)
			"ravenous":
				var destroyed_count: int = _destroy_random_player_item_for_fight("ravenous")
				if destroyed_count <= 0:
					continue
				_record_monster_skill_trace(skill_id, "ravenous_first_below_half_health_destroy_enemy_item_for_fight", EffectDefinitionClass.TRIGGER_ON_DAMAGE_TAKEN, EffectDefinitionClass.EFFECT_RUNTIME_BONUS, float(destroyed_count), destroyed_count)

func _check_monster_first_below_half_health(previous_hp: int) -> void:
	if current_monster == null or current_monster.max_hp <= 0 or not current_monster.is_alive():
		return
	if bool(_effect_runtime_state.get("monster_first_below_half_health_triggered", false)):
		return
	var half_health: float = float(current_monster.max_hp) * 0.5
	if float(previous_hp) >= half_health and float(current_monster.current_hp) < half_health:
		_effect_runtime_state["monster_first_below_half_health_triggered"] = true
		_apply_monster_first_below_half_health_triggers()

func _damage_current_monster(damage: int, use_shield: bool = true) -> int:
	if current_monster == null or damage <= 0:
		return 0
	if _has_no_damage_window("monster"):
		return 0
	var previous_hp: int = current_monster.current_hp
	var actual_damage: int = 0
	var pending_damage: int = maxi(damage, 0)
	if use_shield and current_monster.current_shield > 0.0:
		var absorbed: float = minf(current_monster.current_shield, float(pending_damage))
		current_monster.current_shield = maxf(current_monster.current_shield - absorbed, 0.0)
		pending_damage = maxi(pending_damage - int(absorbed), 0)
	if pending_damage <= 0:
		return 0
	actual_damage = mini(pending_damage, current_monster.current_hp)
	if actual_damage >= current_monster.current_hp and _try_would_die_prevention("monster"):
		return actual_damage
	current_monster.current_hp = maxi(current_monster.current_hp - actual_damage, 0)
	_check_monster_first_below_half_health(previous_hp)
	return actual_damage

func _damage_player(damage: int) -> int:
	if game_manager == null or damage <= 0:
		return 0
	if _has_no_damage_window("player"):
		return 0
	var current_hp: int = int(game_manager.get("player_health"))
	var actual_damage: int = mini(maxi(damage, 0), current_hp)
	if actual_damage <= 0:
		return 0
	if actual_damage >= current_hp and _try_would_die_prevention("player"):
		return actual_damage
	game_manager.take_damage(actual_damage)
	return actual_damage

func _try_would_die_prevention(owner_side: String) -> bool:
	return _try_memento_mori(owner_side) or _try_sparring_partner_rebirth(owner_side) or _try_fiery_rebirth(owner_side)

func _try_memento_mori(owner_side: String) -> bool:
	if owner_side == "monster":
		if current_monster == null or bool(_effect_runtime_state.get("monster_memento_mori_triggered", false)):
			return false
		for item_index in range(current_monster.monster_items.size()):
			var monster_item: Dictionary = current_monster.monster_items[item_index]
			if str(monster_item.get("source_id", "")) != "memento_mori" or _is_monster_item_destroyed(item_index):
				continue
			_effect_runtime_state["monster_memento_mori_triggered"] = true
			current_monster.current_hp = mini(1, current_monster.max_hp)
			_set_no_damage_window("monster", float(_rarity_value_from_monster_item(monster_item, [1, 2])))
			_record_monster_skill_trace("memento_mori", "memento_mori_would_die_heal_1_no_damage", EffectDefinitionClass.TRIGGER_ON_DAMAGE_TAKEN, EffectDefinitionClass.EFFECT_HEAL, 1.0, 1)
			return true
	if owner_side == "player":
		if inventory == null or bool(_effect_runtime_state.get("player_memento_mori_triggered", false)):
			return false
		for item in inventory.items:
			if item == null or item.source_id != "memento_mori" or _is_player_item_destroyed(item):
				continue
			_effect_runtime_state["player_memento_mori_triggered"] = true
			game_manager.set("player_health", mini(1, game_manager.get_max_health()))
			_set_no_damage_window("player", _get_rarity_value(item, [1, 2], 1.0))
			_record_effect_trace({"kind": "item", "id": "memento_mori"}, {"id": "memento_mori_would_die_heal_1_no_damage", "trigger": EffectDefinitionClass.TRIGGER_ON_DAMAGE_TAKEN, "effect": {"type": EffectDefinitionClass.EFFECT_HEAL}}, EffectDefinitionClass.TRIGGER_ON_DAMAGE_TAKEN, 1.0, 1)
			return true
	return false

func _try_sparring_partner_rebirth(owner_side: String) -> bool:
	if owner_side == "monster":
		if current_monster == null or not _monster_has_skill("sparring_partner_skill"):
			return false
		if bool(_effect_runtime_state.get("monster_sparring_partner_triggered", false)):
			return false
		_effect_runtime_state["monster_sparring_partner_triggered"] = true
		_clear_statuses(enemy_status_state, [EffectDefinitionClass.EFFECT_BURN, EffectDefinitionClass.EFFECT_POISON])
		current_monster.max_hp = maxi(current_monster.max_hp * 2, 1)
		current_monster.current_hp = current_monster.max_hp
		if game_manager != null:
			game_manager.add_gold(1)
		_record_monster_skill_trace("sparring_partner_skill", "sparring_partner_would_die_cleanse_double_max_health_enemy_gold", EffectDefinitionClass.TRIGGER_ON_DAMAGE_TAKEN, EffectDefinitionClass.EFFECT_HEAL, float(current_monster.max_hp), 1)
		return true
	if owner_side == "player":
		if not _has_player_skill("sparring_partner_skill"):
			return false
		if bool(_effect_runtime_state.get("player_sparring_partner_triggered", false)):
			return false
		_effect_runtime_state["player_sparring_partner_triggered"] = true
		_clear_statuses(player_status_state, [EffectDefinitionClass.EFFECT_BURN, EffectDefinitionClass.EFFECT_POISON])
		if game_manager != null and game_manager.selected_hero != null:
			game_manager.selected_hero.max_hp = maxi(int(game_manager.selected_hero.max_hp) * 2, 1)
			game_manager.set("player_health", int(game_manager.selected_hero.max_hp))
			_record_effect_trace({"kind": "player_skill", "id": "sparring_partner_skill"}, {"id": "sparring_partner_would_die_cleanse_double_max_health_enemy_gold", "trigger": EffectDefinitionClass.TRIGGER_ON_DAMAGE_TAKEN, "effect": {"type": EffectDefinitionClass.EFFECT_HEAL}}, EffectDefinitionClass.TRIGGER_ON_DAMAGE_TAKEN, float(game_manager.selected_hero.max_hp), 1)
			return true
	return false

func _try_fiery_rebirth(owner_side: String) -> bool:
	if owner_side == "monster":
		if current_monster == null or not _monster_has_skill("fiery_rebirth"):
			return false
		if bool(_effect_runtime_state.get("monster_fiery_rebirth_triggered", false)):
			return false
		_effect_runtime_state["monster_fiery_rebirth_triggered"] = true
		current_monster.current_hp = current_monster.max_hp
		_record_monster_skill_trace("fiery_rebirth", "fiery_rebirth_would_die_heal_to_full", EffectDefinitionClass.TRIGGER_ON_DAMAGE_TAKEN, EffectDefinitionClass.EFFECT_HEAL, float(current_monster.max_hp), 1)
		return true
	if owner_side == "player":
		if not _has_player_skill("fiery_rebirth"):
			return false
		if bool(_effect_runtime_state.get("player_fiery_rebirth_triggered", false)):
			return false
		_effect_runtime_state["player_fiery_rebirth_triggered"] = true
		var max_health: int = game_manager.get_max_health() if game_manager != null else 0
		if max_health <= 0:
			return false
		game_manager.set("player_health", max_health)
		_record_effect_trace(
			{"kind": "player_skill", "id": "fiery_rebirth"},
			{"id": "fiery_rebirth_would_die_heal_to_full", "trigger": EffectDefinitionClass.TRIGGER_ON_DAMAGE_TAKEN, "effect": {"type": EffectDefinitionClass.EFFECT_HEAL}},
			EffectDefinitionClass.TRIGGER_ON_DAMAGE_TAKEN,
			float(max_health),
			1
		)
		return true
	return false

func _monster_has_skill(skill_id: String) -> bool:
	if current_monster == null:
		return false
	for skill_ref in PlayerSkillCatalogClass.resolve_skill_refs(current_monster.monster_skills):
		if str(skill_ref.get("id", "")) == skill_id:
			return true
	return false

func _clear_statuses(status_state: Dictionary, status_types: Array) -> void:
	for status_type in status_types:
		status_state[str(status_type)] = 0.0

func _set_no_damage_window(owner_side: String, seconds: float) -> void:
	if seconds <= 0.0:
		return
	_effect_runtime_state["%s_no_damage_until" % owner_side] = maxf(float(_effect_runtime_state.get("%s_no_damage_until" % owner_side, 0.0)), _battle_elapsed_time + seconds)

func _has_no_damage_window(owner_side: String) -> bool:
	return _battle_elapsed_time < float(_effect_runtime_state.get("%s_no_damage_until" % owner_side, 0.0))

func _enter_enrage(owner_side: String, duration: float = 5.0) -> void:
	if duration <= 0.0:
		return
	_effect_runtime_state["%s_enrage_until" % owner_side] = maxf(float(_effect_runtime_state.get("%s_enrage_until" % owner_side, 0.0)), _battle_elapsed_time + duration)
	_clear_own_item_slow_freeze(owner_side)
	_apply_enrage_cooldown_entry_modifier(owner_side)
	_record_effect_trace({"kind": "runtime", "id": "%s_enrage" % owner_side}, {"id": "%s_enter_enrage_clear_slow_freeze_cooldown_modifier" % owner_side, "trigger": "enrage_enter", "effect": {"type": EffectDefinitionClass.EFFECT_RUNTIME_BONUS}}, "enrage_enter", duration, 1)

func _exit_enrage(owner_side: String) -> void:
	_effect_runtime_state["%s_enrage_until" % owner_side] = 0.0

func _is_enraged(owner_side: String) -> bool:
	return _battle_elapsed_time < float(_effect_runtime_state.get("%s_enrage_until" % owner_side, 0.0))

func _clear_own_item_slow_freeze(owner_side: String) -> void:
	if owner_side == "player" and inventory != null:
		for item in inventory.items:
			if item == null or _is_player_item_destroyed(item):
				continue
			var base_cooldown: float = _get_effective_cooldown(_get_player_item_effective_cooldown(item, false))
			item.current_cooldown = minf(item.current_cooldown, base_cooldown)
	if owner_side == "monster" and current_monster != null:
		for index in range(current_monster.monster_items.size()):
			if _is_monster_item_destroyed(index):
				continue
			var monster_item: Dictionary = current_monster.monster_items[index]
			var base_cooldown: float = _get_effective_cooldown(float(monster_item.get("cooldown", 0.0)))
			monster_item["current_cooldown"] = minf(float(monster_item.get("current_cooldown", 0.0)), base_cooldown)

func _apply_enrage_cooldown_entry_modifier(owner_side: String) -> void:
	if owner_side == "player" and inventory != null:
		for item in inventory.items:
			if item != null and not _is_player_item_destroyed(item) and item.current_cooldown > 0.0:
				item.current_cooldown *= 0.9
	if owner_side == "monster" and current_monster != null:
		for index in range(current_monster.monster_items.size()):
			if _is_monster_item_destroyed(index):
				continue
			var monster_item: Dictionary = current_monster.monster_items[index]
			if float(monster_item.get("current_cooldown", 0.0)) > 0.0:
				monster_item["current_cooldown"] = float(monster_item.get("current_cooldown", 0.0)) * 0.9

func _player_destroyed_item_ids() -> Array:
	if not _effect_runtime_state.has("destroyed_player_item_ids"):
		_effect_runtime_state["destroyed_player_item_ids"] = []
	return _effect_runtime_state["destroyed_player_item_ids"]

func _monster_destroyed_item_indexes() -> Array:
	if not _effect_runtime_state.has("destroyed_monster_item_indexes"):
		_effect_runtime_state["destroyed_monster_item_indexes"] = []
	return _effect_runtime_state["destroyed_monster_item_indexes"]

func _is_player_item_destroyed(item: ItemData) -> bool:
	return item != null and _player_destroyed_item_ids().has(item.get_instance_id())

func _is_monster_item_destroyed(item_index: int) -> bool:
	return _monster_destroyed_item_indexes().has(item_index)

func _destroy_random_player_item_for_fight(reason_id: String) -> int:
	if inventory == null:
		return 0
	var candidates: Array[ItemData] = []
	for item in inventory.items:
		if item != null and not _is_player_item_destroyed(item):
			candidates.append(item)
	if candidates.is_empty():
		return 0
	var item: ItemData = candidates[randi() % candidates.size()]
	_player_destroyed_item_ids().append(item.get_instance_id())
	_record_effect_trace({"kind": "runtime", "id": reason_id}, {"id": "%s_destroy_player_item_for_fight" % reason_id, "trigger": EffectDefinitionClass.TRIGGER_ON_DAMAGE_TAKEN, "effect": {"type": EffectDefinitionClass.EFFECT_RUNTIME_BONUS}}, EffectDefinitionClass.TRIGGER_ON_DAMAGE_TAKEN, 1.0, 1)
	_apply_destroy_item_triggers("player", reason_id)
	return 1

func _destroy_random_monster_item_for_fight(reason_id: String) -> int:
	if current_monster == null:
		return 0
	var candidates: Array[int] = []
	for index in range(current_monster.monster_items.size()):
		if not _is_monster_item_destroyed(index):
			candidates.append(index)
	if candidates.is_empty():
		return 0
	var item_index: int = candidates[randi() % candidates.size()]
	_monster_destroyed_item_indexes().append(item_index)
	_record_effect_trace({"kind": "runtime", "id": reason_id}, {"id": "%s_destroy_monster_item_for_fight" % reason_id, "trigger": EffectDefinitionClass.TRIGGER_ON_DAMAGE_TAKEN, "effect": {"type": EffectDefinitionClass.EFFECT_RUNTIME_BONUS}}, EffectDefinitionClass.TRIGGER_ON_DAMAGE_TAKEN, 1.0, 1)
	_apply_destroy_item_triggers("monster", reason_id)
	return 1

func _player_flying_item_ids() -> Array:
	if not _effect_runtime_state.has("player_flying_item_ids"):
		_effect_runtime_state["player_flying_item_ids"] = []
	return _effect_runtime_state["player_flying_item_ids"]

func _monster_flying_item_indexes() -> Array:
	if not _effect_runtime_state.has("monster_flying_item_indexes"):
		_effect_runtime_state["monster_flying_item_indexes"] = []
	return _effect_runtime_state["monster_flying_item_indexes"]

func _is_player_item_flying(item: ItemData) -> bool:
	return item != null and _player_flying_item_ids().has(item.get_instance_id())

func _is_monster_item_flying(item_index: int) -> bool:
	return _monster_flying_item_indexes().has(item_index)

func _set_player_item_flying(item: ItemData, reason_id: String) -> bool:
	if item == null or _is_player_item_flying(item) or _is_player_item_destroyed(item):
		return false
	_player_flying_item_ids().append(item.get_instance_id())
	_apply_flying_start_triggers("player")
	_record_effect_trace({"kind": "runtime", "id": reason_id}, {"id": "%s_player_item_start_flying" % reason_id, "trigger": EffectDefinitionClass.TRIGGER_ON_ITEM_USED, "effect": {"type": EffectDefinitionClass.EFFECT_RUNTIME_BONUS}}, EffectDefinitionClass.TRIGGER_ON_ITEM_USED, 1.0, 1)
	return true

func _set_monster_item_flying(item_index: int, reason_id: String) -> bool:
	if current_monster == null or item_index < 0 or item_index >= current_monster.monster_items.size() or _is_monster_item_flying(item_index) or _is_monster_item_destroyed(item_index):
		return false
	_monster_flying_item_indexes().append(item_index)
	_apply_flying_start_triggers("monster")
	_record_effect_trace({"kind": "runtime", "id": reason_id}, {"id": "%s_monster_item_start_flying" % reason_id, "trigger": EffectDefinitionClass.TRIGGER_ON_ITEM_USED, "effect": {"type": EffectDefinitionClass.EFFECT_RUNTIME_BONUS}}, EffectDefinitionClass.TRIGGER_ON_ITEM_USED, 1.0, 1)
	return true

func _start_player_small_items_flying(count: int) -> int:
	if inventory == null:
		return 0
	var started: int = 0
	for item in inventory.items:
		if started >= count:
			break
		if item != null and _matches_player_item_selector(item, "small") and _set_player_item_flying(item, "haunting_flight"):
			started += 1
	return started

func _start_monster_small_items_flying(count: int) -> int:
	if current_monster == null:
		return 0
	var started: int = 0
	for index in range(current_monster.monster_items.size()):
		if started >= count:
			break
		var item: Dictionary = current_monster.monster_items[index]
		if _monster_item_size_matches(item, "Small") and _set_monster_item_flying(index, "haunting_flight"):
			started += 1
	return started

func _apply_flying_start_triggers(owner_side: String) -> void:
	if owner_side == "monster" and _monster_has_skill("aerial_assault"):
		if _charge_monster_weapon(1.0):
			_record_monster_skill_trace("aerial_assault", "aerial_assault_item_start_flying_charge_weapon", EffectDefinitionClass.TRIGGER_ON_ITEM_USED, EffectDefinitionClass.EFFECT_CHARGE, 1.0, 1)
	if owner_side == "player" and _has_player_skill("aerial_assault"):
		if _charge_matching_player_item("weapon", 1.0):
			_record_effect_trace({"kind": "player_skill", "id": "aerial_assault"}, {"id": "aerial_assault_item_start_flying_charge_weapon", "trigger": EffectDefinitionClass.TRIGGER_ON_ITEM_USED, "effect": {"type": EffectDefinitionClass.EFFECT_CHARGE}}, EffectDefinitionClass.TRIGGER_ON_ITEM_USED, 1.0, 1)

func _monster_item_starts_flying(item: Dictionary) -> bool:
	var effect_text: String = str(item.get("effect", "")).to_lower()
	return effect_text.contains("starts flying") or effect_text.contains("start flying")

func _monster_item_size_matches(item: Dictionary, size_name: String) -> bool:
	return str(item.get("size", "")).to_lower() == size_name.to_lower()

func _charge_monster_weapon(seconds: float) -> bool:
	if current_monster == null or seconds <= 0.0:
		return false
	var best_index: int = -1
	var best_cooldown: float = -1.0
	for index in range(current_monster.monster_items.size()):
		if _is_monster_item_destroyed(index):
			continue
		var item: Dictionary = current_monster.monster_items[index]
		if not _monster_item_has_tag(item, "Weapon"):
			continue
		var current_cooldown: float = float(item.get("current_cooldown", 0.0))
		if current_cooldown > best_cooldown:
			best_index = index
			best_cooldown = current_cooldown
	if best_index < 0:
		return false
	var weapon: Dictionary = current_monster.monster_items[best_index]
	weapon["current_cooldown"] = maxf(float(weapon.get("current_cooldown", 0.0)) - seconds, 0.0)
	return true

func _apply_destroy_item_triggers(destroyed_owner_side: String, reason_id: String) -> void:
	if destroyed_owner_side == "player" and current_monster != null and _monster_has_skill("void_render"):
		var damage_bonus: int = 100
		var burn_bonus: int = 10
		for skill_ref in PlayerSkillCatalogClass.resolve_skill_refs(current_monster.monster_skills):
			if str(skill_ref.get("id", "")) == "void_render":
				damage_bonus = int(round(PlayerSkillCatalogClass.get_tier_value(skill_ref)))
				burn_bonus = int(round(PlayerSkillCatalogClass.get_tier_value(skill_ref, "burn_values", 10.0)))
		for index in range(current_monster.monster_items.size()):
			if _is_monster_item_destroyed(index):
				continue
			var item: Dictionary = current_monster.monster_items[index]
			if _monster_item_has_tag(item, "Weapon"):
				item["damage"] = int(item.get("damage", 0)) + damage_bonus
			if _monster_item_has_tag(item, "Burn"):
				item["burn"] = int(item.get("burn", 0)) + burn_bonus
		_record_monster_skill_trace("void_render", "void_render_destroy_item_weapon_damage_burn_bonus", EffectDefinitionClass.TRIGGER_ON_DAMAGE_TAKEN, EffectDefinitionClass.EFFECT_RUNTIME_BONUS, float(damage_bonus), 1)
	if destroyed_owner_side == "monster" and _has_player_skill("void_render") and inventory != null:
		var player_damage_bonus: int = int(round(_get_player_skill_value("void_render")))
		var player_burn_bonus: int = int(round(_get_player_skill_value("void_render", "burn_values")))
		for item in inventory.items:
			if item == null or _is_player_item_destroyed(item):
				continue
			if _is_weapon_item(item):
				_add_item_runtime_bonus(item, EffectDefinitionClass.EFFECT_DAMAGE, float(player_damage_bonus))
			if _is_burn_item(item):
				_add_item_runtime_bonus(item, EffectDefinitionClass.EFFECT_BURN, float(player_burn_bonus))
		_record_effect_trace({"kind": "player_skill", "id": "void_render"}, {"id": "void_render_destroy_item_weapon_damage_burn_bonus", "trigger": EffectDefinitionClass.TRIGGER_ON_DAMAGE_TAKEN, "effect": {"type": EffectDefinitionClass.EFFECT_RUNTIME_BONUS}}, EffectDefinitionClass.TRIGGER_ON_DAMAGE_TAKEN, float(player_damage_bonus), 1)

func _apply_monster_power_broker(skill_ref: Dictionary) -> void:
	if current_monster == null or game_manager == null:
		return
	var income_bonus: int = int(round(PlayerSkillCatalogClass.get_tier_value(skill_ref) * float(game_manager.get("income"))))
	if income_bonus <= 0:
		return
	var applied_count: int = 0
	for index in range(current_monster.monster_items.size()):
		if _is_monster_item_destroyed(index):
			continue
		var item: Dictionary = current_monster.monster_items[index]
		if _monster_item_has_tag(item, "Weapon"):
			item["damage"] = int(item.get("damage", 0)) + income_bonus
			applied_count += 1
	if applied_count > 0:
		_record_monster_skill_trace("power_broker", "power_broker_weapon_damage_from_income", EffectDefinitionClass.TRIGGER_ON_BATTLE_START, EffectDefinitionClass.EFFECT_RUNTIME_BONUS, float(income_bonus), applied_count)

func _apply_monster_prosperity(skill_ref: Dictionary) -> void:
	if current_monster == null:
		return
	var total_value: int = 0
	for item in current_monster.monster_items:
		total_value += maxi(int(item.get("cost", item.get("value", 0))), 0)
	if total_value <= 0:
		return
	var applied_count: int = 0
	for index in range(current_monster.monster_items.size()):
		if _is_monster_item_destroyed(index):
			continue
		var candidate: Dictionary = current_monster.monster_items[index]
		if _monster_item_has_tag(candidate, "Shield") or int(candidate.get("shield", 0)) > 0:
			candidate["shield"] = int(candidate.get("shield", 0)) + int(round(float(total_value) * PlayerSkillCatalogClass.get_tier_value(skill_ref)))
			applied_count += 1
	if applied_count > 0:
		_record_monster_skill_trace("prosperity", "prosperity_shield_from_total_item_value", EffectDefinitionClass.TRIGGER_ON_BATTLE_START, EffectDefinitionClass.EFFECT_RUNTIME_BONUS, float(total_value), applied_count)

func _record_monster_skill_trace(skill_id: String, definition_id: String, trigger: String, effect_type: String, amount: float, target_count: int) -> void:
	_record_effect_trace(
		{"kind": "monster_skill", "id": skill_id},
		{"id": definition_id, "trigger": trigger, "effect": {"type": effect_type}},
		trigger,
		amount,
		target_count
	)

func _monster_item_has_tag(item: Dictionary, tag: String) -> bool:
	for value in item.get("tags", []):
		if str(value).to_lower() == tag.to_lower():
			return true
	return false

func _get_adjacent_monster_item_indexes(item_index: int) -> Array[int]:
	var indexes: Array[int] = []
	if current_monster == null:
		return indexes
	for adjacent_index in [item_index - 1, item_index + 1]:
		if adjacent_index >= 0 and adjacent_index < current_monster.monster_items.size():
			indexes.append(adjacent_index)
	return indexes

func _reload_other_monster_ammo_item(source_index: int, amount: int) -> bool:
	if current_monster == null or amount <= 0:
		return false
	for index in range(current_monster.monster_items.size()):
		if index == source_index:
			continue
		var candidate: Dictionary = current_monster.monster_items[index]
		var max_ammo: int = int(candidate.get("max_ammo", candidate.get("ammo", 0)))
		if max_ammo <= 0:
			continue
		var current_ammo: int = int(candidate.get("current_ammo", candidate.get("ammo", max_ammo)))
		if current_ammo >= max_ammo:
			continue
		candidate["current_ammo"] = mini(current_ammo + amount, max_ammo)
		candidate["ammo"] = candidate["current_ammo"]
		return true
	return false

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
	var player_won: bool = current_monster != null and not current_monster.is_alive()
	if player_won:
		_apply_player_fight_win_value_effects()
	is_battle_active = false
	_restore_transformed_items()
	player_status_state = _new_status_state()
	enemy_status_state = _new_status_state()
	item_runtime_bonuses.clear()
	effect_execution_trace.clear()
	effect_warnings.clear()
	_effect_runtime_state.clear()
	_battle_elapsed_time = 0.0
	_effect_event_id_counter = 0
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
	_battle_elapsed_time += tick_time
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
			if item != null and not _is_player_item_destroyed(item) and item.current_cooldown > 0:
				item.current_cooldown = maxf(item.current_cooldown - cooldown_delta, 0.0)
	if current_monster == null or not current_monster.is_alive():
		return
	for index in range(current_monster.monster_items.size()):
		if _is_monster_item_destroyed(index):
			continue
		var item: Dictionary = current_monster.monster_items[index]
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
	var burn_bonus: float = 0.0 if hero == null else hero.skill_burn_bonus
	var poison_bonus: float = 0.0 if hero == null else hero.skill_poison_bonus
	for item in inventory.items.duplicate():
		if item == null or item.current_cooldown > 0 or _is_player_item_destroyed(item):
			continue
		if not _is_active_player_item(item):
			continue
		if not item.can_pay_ammo():
			continue
		if _try_transform_potion_potion(item):
			item.consume_ammo()
			item.current_cooldown = _get_effective_cooldown(_get_player_item_effective_cooldown(item))
			continue
		var total_context: Dictionary = _new_use_context()
		var reactive_events: Array[Dictionary] = []
		var multicast_count: int = _get_player_item_multicast_count(item)
		var item_crit_rate: float = _get_player_item_crit_rate(item, hero_crit_rate)
		for _cast_index in range(multicast_count):
			var is_crit: bool = randf() < item_crit_rate
			var use_result: Dictionary = _trigger_player_item_once(
				item,
				is_crit,
				lifesteal_rate,
				burn_bonus,
				poison_bonus
			)
			_merge_use_context(total_context, use_result.get("context", {}))
			reactive_events.append_array(use_result.get("events", []))
			if _check_battle_end():
				break
		item.consume_ammo()
		item.current_cooldown = _get_effective_cooldown(_get_player_item_effective_cooldown(item))
		var post_consume_result: Dictionary = _execute_item_effect_definitions(
			item,
			{
				"is_crit": false,
				"crit_multiplier": 1.0,
				"lifesteal_rate": lifesteal_rate,
				"burn_bonus": burn_bonus,
				"poison_bonus": poison_bonus,
			},
			"after_consume"
		)
		if bool(post_consume_result.get("executed", false)):
			item.current_cooldown = minf(item.current_cooldown, _get_effective_cooldown(_get_player_item_effective_cooldown(item)))
		_merge_use_context(total_context, post_consume_result.get("context", {}))
		reactive_events.append_array(post_consume_result.get("events", []))
		_merge_use_context(total_context, _process_reactive_effect_events(reactive_events))
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
		if _is_monster_item_destroyed(item_index):
			continue
		var item: Dictionary = current_monster.monster_items[item_index]
		var item_cooldown: float = float(item.get("cooldown", 0.0))
		if item_cooldown <= 0.0:
			continue
		if float(item.get("current_cooldown", 0.0)) > 0:
			continue
		var item_crit_rate: float = clampf(float(item.get("crit_chance", 0.0)), 0.0, 1.0)
		var is_crit: bool = randf() < item_crit_rate
		var damage: int = maxi(int(float(item.get("damage", 0)) * damage_mult), 0)
		if is_crit:
			damage *= 2
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
			_damage_player(remaining_damage)
		if burn > 0:
			_add_status_to_state(player_status_state, ItemEffectsClass.EFFECT_BURN, float(burn))
		if poison > 0:
			_add_status_to_state(player_status_state, ItemEffectsClass.EFFECT_POISON, float(poison))
		if regen > 0:
			_add_status_to_state(enemy_status_state, ItemEffectsClass.EFFECT_REGEN, float(regen))
		if slow_count > 0 and slow_duration > 0.0:
			_slow_player_items(slow_count, slow_duration)
		if freeze_count > 0 and freeze_duration > 0.0:
			var frozen_count: int = _slow_player_items(freeze_count, freeze_duration)
			if frozen_count > 0:
				_apply_monster_skill_status_trigger(EffectDefinitionClass.EFFECT_FREEZE, 1)
		if haste_count > 0 and haste_duration > 0.0:
			var hasted_count: int = _haste_monster_items(haste_count, haste_duration, item_index)
			if hasted_count > 0:
				_apply_monster_skill_status_trigger(EffectDefinitionClass.EFFECT_HASTE, hasted_count)
		monster_item_triggered.emit(current_monster.monster_name, item_name, total_player_damage)
		_apply_monster_skill_item_used_triggers(item_index, item, is_crit)
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
				_damage_current_monster(reflected)
				print("🔄 反弹 %d 伤害!" % reflected)
		if game_manager.player_health <= 0:
			break
		item["current_cooldown"] = _get_monster_item_effective_cooldown(item_cooldown)
		_after_monster_item_used(item_index)

func _new_use_context() -> Dictionary:
	return {
		"use_count": 0,
		"crit_count": 0,
		"damage": 0,
		"shield_proc_count": 0,
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

func _trigger_player_item_once(
	item: ItemData,
	is_crit: bool,
	passive_lifesteal_rate: float,
	burn_bonus: float,
	poison_bonus: float
) -> Dictionary:
	var context: Dictionary = _new_use_context()
	context["use_count"] = 1
	if is_crit:
		context["crit_count"] = 1
	var result: Dictionary = {
		"context": context,
		"events": [],
	}
	var root_result: Dictionary = _execute_item_effect_definitions(
		item,
		{
			"is_crit": is_crit,
			"crit_multiplier": 2.0 if is_crit else 1.0,
			"lifesteal_rate": passive_lifesteal_rate,
			"burn_bonus": burn_bonus,
			"poison_bonus": poison_bonus,
		}
	)
	_merge_use_context(context, root_result.get("context", {}))
	result["events"].append_array(root_result.get("events", []))
	result["events"].append(_make_effect_event(EffectDefinitionClass.TRIGGER_ON_ITEM_USED, item))
	result["events"].append(_make_effect_event(EffectDefinitionClass.TRIGGER_ON_TAG_USED, item))
	if is_crit:
		result["events"].append(_make_effect_event(EffectDefinitionClass.TRIGGER_ON_CRIT, item))
	return result

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
	if _item_starts_flying(item):
		_set_player_item_flying(item, "source_item_start_flying")
	if _has_player_skill("haunting_flight") and not bool(_effect_runtime_state.get("player_haunting_flight_triggered", false)):
		var started_count: int = _start_player_small_items_flying(maxi(int(round(_get_player_skill_value("haunting_flight"))), 1))
		if started_count > 0:
			_effect_runtime_state["player_haunting_flight_triggered"] = true
			_record_effect_trace({"kind": "player_skill", "id": "haunting_flight"}, {"id": "haunting_flight_first_item_small_items_start_flying", "trigger": EffectDefinitionClass.TRIGGER_ON_ITEM_USED, "effect": {"type": EffectDefinitionClass.EFFECT_RUNTIME_BONUS}}, EffectDefinitionClass.TRIGGER_ON_ITEM_USED, float(started_count), started_count)
	if _has_player_skill("into_the_void") and not bool(_effect_runtime_state.get("player_into_the_void_triggered", false)):
		_effect_runtime_state["player_into_the_void_triggered"] = true
		var destroyed_total: int = _destroy_random_player_item_for_fight("into_the_void") + _destroy_random_monster_item_for_fight("into_the_void")
		_record_effect_trace({"kind": "player_skill", "id": "into_the_void"}, {"id": "into_the_void_first_item_destroy_each_board_for_fight", "trigger": EffectDefinitionClass.TRIGGER_ON_ITEM_USED, "effect": {"type": EffectDefinitionClass.EFFECT_RUNTIME_BONUS}}, EffectDefinitionClass.TRIGGER_ON_ITEM_USED, float(destroyed_total), destroyed_total)
	if item.source_id == "magic_carpet" and int(context.get("crit_count", 0)) > 0:
		_add_item_runtime_bonus(item, "cooldown_flat_reduction", float(context.get("crit_count", 0)))

	var heal_or_regen_triggers: int = int(context.get("heal_proc_count", 0)) + int(context.get("regen_proc_count", 0))
	if heal_or_regen_triggers > 0:
		_apply_nightshade_heal_reference_bonus(heal_or_regen_triggers)
	var heal_events: int = int(context.get("heal_proc_count", 0))
	if heal_events > 0:
		_add_player_skill_bonus_to_items("extreme_comfort", "shield", "shield", heal_events)
	var regen_events: int = int(context.get("regen_proc_count", 0))
	if regen_events > 0:
		_apply_player_skill_status_runtime_bonuses(ItemEffectsClass.EFFECT_REGEN, regen_events)

	var poison_events: int = int(context.get("poison_proc_count", 0))
	var burn_events: int = int(context.get("burn_proc_count", 0))
	var slow_events: int = int(context.get("slow_proc_count", 0))
	var freeze_events: int = int(context.get("freeze_proc_count", 0))
	var haste_events: int = int(context.get("haste_proc_count", 0))
	if poison_events > 0:
		_handle_player_status_reference(ItemEffectsClass.EFFECT_POISON, poison_events)
		_apply_player_skill_status_runtime_bonuses(ItemEffectsClass.EFFECT_POISON, poison_events)
	if burn_events > 0:
		_handle_player_status_reference(ItemEffectsClass.EFFECT_BURN, burn_events)
		_apply_player_skill_status_runtime_bonuses(ItemEffectsClass.EFFECT_BURN, burn_events)
	if slow_events > 0:
		_handle_player_status_reference(ItemEffectsClass.EFFECT_SLOW, slow_events)
		_apply_player_skill_status_runtime_bonuses(ItemEffectsClass.EFFECT_SLOW, slow_events)
	if freeze_events > 0:
		_handle_player_status_reference(ItemEffectsClass.EFFECT_FREEZE, freeze_events)
		_apply_player_skill_status_runtime_bonuses(ItemEffectsClass.EFFECT_FREEZE, freeze_events)
	if haste_events > 0:
		_handle_player_status_reference(ItemEffectsClass.EFFECT_HASTE, haste_events)
		_apply_player_skill_status_runtime_bonuses(ItemEffectsClass.EFFECT_HASTE, haste_events)

func _after_monster_item_used(item_index: int) -> void:
	if current_monster == null:
		return
	_apply_electric_eels_enemy_use_charge()
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

func _apply_electric_eels_enemy_use_charge() -> void:
	if inventory == null:
		return
	for candidate in inventory.items:
		if candidate != null and candidate.source_id == "electric_eels":
			_charge_player_item(candidate, 2.0)

func _handle_player_item_gained_haste(item: ItemData, trigger_count: int) -> void:
	if inventory == null or item == null or trigger_count <= 0:
		return
	if item.source_id == "pufferfish":
		_charge_player_item(item, 2.0 * float(trigger_count))
	elif item.source_id == "goggles":
		var bonus: float = _get_rarity_value(item, [2, 4, 6, 8], 2.0) * float(trigger_count)
		for adjacent in _get_adjacent_player_items(item):
			if adjacent != null:
				_add_item_runtime_bonus(adjacent, "crit_rate", bonus)

func _is_active_player_item(item: ItemData) -> bool:
	if item == null:
		return false
	if item.source_id in ["potion_potion", "fungal_spores", "mortar_pestle", "mothmeal", "smelling_salts", "duct_tape"]:
		return item.cooldown > 0.0
	if item.cooldown <= 0.0:
		return false
	return item.damage > 0 or item.shield > 0 or item.heal > 0 or item.has_special_effect() or _has_root_item_effect_definition(item)

func _has_root_item_effect_definition(item: ItemData) -> bool:
	if item == null:
		return false
	_ensure_item_effect_definitions(item)
	for definition_variant in item.effects:
		if not definition_variant is Dictionary:
			continue
		var definition: Dictionary = definition_variant
		if str(definition.get("trigger", "")) != EffectDefinitionClass.TRIGGER_ON_COOLDOWN_READY:
			continue
		var effect_data: Dictionary = definition.get("effect", {})
		var effect_type: String = str(effect_data.get("type", ""))
		if effect_type == EffectDefinitionClass.EFFECT_MULTICAST:
			continue
		return true
	return false

func _get_monster_item_effective_cooldown(cooldown: float) -> float:
	var effective_cooldown: float = cooldown
	if _is_enraged("monster"):
		effective_cooldown *= 0.9
	return _get_effective_cooldown(effective_cooldown)

func _get_player_item_effective_cooldown(item: ItemData, include_enrage: bool = true) -> float:
	if item == null or item.cooldown <= 0.0:
		return 0.0
	var cooldown: float = item.cooldown
	for adjacent in _get_adjacent_player_items(item):
		if adjacent != null and adjacent.source_id == "hourglass":
			cooldown *= 1.0 - _get_rarity_value(adjacent, [0.03, 0.06, 0.09, 0.12], 0.0)
	if _has_player_skill("vengeance") and _is_edge_player_item(item):
		cooldown *= 1.0 - (_get_player_skill_value("vengeance") / 100.0)
	if _has_player_skill("diamond_fangs") and item.rarity == BazaarContentClass.RARITY_DIAMOND and _is_small_item(item):
		cooldown *= 1.0 - (_get_player_skill_value("diamond_fangs") / 100.0)
	if _has_player_skill("command_ship") and not _matches_player_item_selector(item, "vehicle") and _count_player_items_matching("vehicle") > 0:
		cooldown *= 1.0 - (_get_player_skill_value("command_ship") / 100.0)
	if _has_player_skill("friend_zone") and _matches_player_item_selector(item, "friend"):
		cooldown *= 1.0 - (_get_player_skill_value("friend_zone") / 100.0)
	if _has_player_skill("full_arsenal"):
		if _count_player_items_matching("vehicle") > 0:
			cooldown *= 1.0 - (_get_player_skill_value("full_arsenal") / 100.0)
		if _count_player_items_matching("weapon") > 0:
			cooldown *= 1.0 - (_get_player_skill_value("full_arsenal") / 100.0)
		if _count_player_items_matching("tool") > 0:
			cooldown *= 1.0 - (_get_player_skill_value("full_arsenal") / 100.0)
	if _has_player_skill("guardian_s_fury") and _is_weapon_item(item):
		var hero: HeroData = null if game_manager == null else game_manager.selected_hero
		if hero != null and hero.current_shield > 0.0:
			cooldown *= 1.0 - (_get_player_skill_value("guardian_s_fury") / 100.0)
	if _has_player_skill("hyper_focus") and _matches_player_item_selector(item, "medium") and _has_exactly_one_player_item_matching("medium"):
		cooldown *= 1.0 - (_get_player_skill_value("hyper_focus") / 100.0)
	if _has_player_skill("one_shot_one_kill") and _is_weapon_item(item) and _has_exactly_one_player_item_matching("weapon"):
		cooldown *= 1.0 + (_get_player_skill_value("one_shot_one_kill") / 100.0)
	var passive_reduction: float = float(_get_passive_combat_stats().get("cd_reduction", 0.0))
	cooldown *= 1.0 - passive_reduction
	if include_enrage and _is_enraged("player"):
		cooldown *= 0.9
	cooldown -= _get_item_runtime_bonus(item, "cooldown_flat_reduction")
	return maxf(cooldown, 0.0)

func _get_player_item_effective_max_ammo(item: ItemData) -> int:
	if item == null:
		return 0
	var max_ammo: int = maxi(item.ammo, 0)
	if not item.has_ammo_limit():
		return max_ammo
	max_ammo += int(round(_get_player_skill_value("gunner")))
	max_ammo += int(round(_get_player_skill_value("ammo_stash")))
	return max_ammo

func _get_player_item_crit_rate(item: ItemData, hero_crit_rate: float) -> float:
	if item == null:
		return clampf(hero_crit_rate, 0.0, 1.0)
	var crit_rate: float = hero_crit_rate + item.crit_chance
	crit_rate += float(_get_player_item_skill_crit_bonus(item)) / 100.0
	crit_rate += _get_item_runtime_bonus(item, "crit_rate") / 100.0
	var right_item: ItemData = null if inventory == null else inventory.get_right_adjacent_item(item)
	if right_item != null and right_item.source_id == "optical_augment":
		crit_rate += float(player_status_state.get("poison", 0.0)) / 100.0
	return clampf(crit_rate, 0.0, 1.0)

func _get_player_item_multicast_count(item: ItemData) -> int:
	if item == null:
		return 1
	_ensure_item_effect_definitions(item)
	var count: int = 1
	count += _get_item_multicast_bonus(item)
	count += _get_item_external_multicast_bonus(item)
	return maxi(count, 1)

func _ensure_item_effect_definitions(item: ItemData) -> void:
	if item == null or not item.effects.is_empty():
		return
	item.effects = EffectDefinitionClass.build_item_effects(item)
	item.effect_warnings = EffectDefinitionClass.collect_item_warnings(item, item.effects)

func get_effect_execution_trace() -> Array[Dictionary]:
	return effect_execution_trace.duplicate(true)

func get_effect_warnings() -> Array[String]:
	return effect_warnings.duplicate()

func _new_effect_execution_result() -> Dictionary:
	return {
		"context": _new_use_context(),
		"events": [],
		"executed": false,
	}

func _log_effect_support_warnings() -> void:
	if inventory != null:
		for item in inventory.items:
			if item == null:
				continue
			_ensure_item_effect_definitions(item)
			for warning_text in item.effect_warnings:
				_push_effect_warning(str(warning_text))
	for skill_ref in player_skill_refs:
		for warning_text in PlayerSkillCatalogClass.get_effect_warnings(skill_ref):
			_push_effect_warning(str(warning_text))

func _push_effect_warning(message: String) -> void:
	if message.is_empty() or effect_warnings.has(message):
		return
	effect_warnings.append(message)
	push_warning(message)

func _next_effect_event_id() -> int:
	_effect_event_id_counter += 1
	return _effect_event_id_counter

func _make_effect_event(
	event_name: String,
	source_item: ItemData,
	extra: Dictionary = {},
	depth: int = 0
) -> Dictionary:
	var event_data: Dictionary = {
		"id": _next_effect_event_id(),
		"name": event_name,
		"depth": depth,
		"source_item": source_item,
		"source_id": "" if source_item == null else source_item.source_id,
		"source_name": "" if source_item == null else source_item.item_name,
	}
	for key in extra.keys():
		event_data[key] = extra[key]
	return event_data

func _record_effect_trace(
	owner: Dictionary,
	definition: Dictionary,
	event_name: String,
	amount: float,
	target_count: int
) -> void:
	var owner_item: ItemData = owner.get("item", null) as ItemData
	effect_execution_trace.append({
		"owner_kind": str(owner.get("kind", "")),
		"owner_id": str(owner.get("id", owner_item.source_id if owner_item != null else "")),
		"definition_id": str(definition.get("id", "")),
		"trigger": str(definition.get("trigger", "")),
		"event_name": event_name,
		"effect_type": str((definition.get("effect", {}) as Dictionary).get("type", "")),
		"amount": amount,
		"target_count": target_count,
		"time": _battle_elapsed_time,
	})

func _get_item_multicast_bonus(item: ItemData) -> int:
	if item == null:
		return 0
	var owner := {"kind": "item", "id": item.source_id, "item": item}
	var root_event: Dictionary = _make_effect_event(
		EffectDefinitionClass.TRIGGER_ON_COOLDOWN_READY,
		item
	)
	var bonus: int = 0
	for definition_variant in item.effects:
		if not definition_variant is Dictionary:
			continue
		var definition: Dictionary = definition_variant
		if str(definition.get("trigger", "")) != EffectDefinitionClass.TRIGGER_ON_COOLDOWN_READY:
			continue
		var effect_data: Dictionary = definition.get("effect", {})
		if str(effect_data.get("type", "")) != EffectDefinitionClass.EFFECT_MULTICAST:
			continue
		if not _definition_condition_matches(owner, definition, root_event):
			continue
		_record_effect_trace(owner, definition, str(root_event.get("name", "")), 1.0, 1)
		bonus += int(round(_resolve_effect_amount(
			item,
			effect_data,
			{
				"crit_multiplier": 1.0,
				"burn_bonus": 0.0,
				"poison_bonus": 0.0,
				"lifesteal_rate": 0.0,
			}
		)))
	return maxi(bonus, 0)

func _get_item_external_multicast_bonus(item: ItemData) -> int:
	if item == null or inventory == null:
		return 0
	var bonus: int = 0
	for owner_item in inventory.items:
		if owner_item == null or owner_item == item:
			continue
		_ensure_item_effect_definitions(owner_item)
		var owner := {"kind": "item", "id": owner_item.source_id, "item": owner_item}
		var root_event: Dictionary = _make_effect_event(
			EffectDefinitionClass.TRIGGER_ON_COOLDOWN_READY,
			owner_item
		)
		for definition_variant in owner_item.effects:
			if not definition_variant is Dictionary:
				continue
			var definition: Dictionary = definition_variant
			if str(definition.get("trigger", "")) != EffectDefinitionClass.TRIGGER_ON_COOLDOWN_READY:
				continue
			var effect_data: Dictionary = definition.get("effect", {})
			if str(effect_data.get("type", "")) != EffectDefinitionClass.EFFECT_MULTICAST:
				continue
			if not _definition_condition_matches(owner, definition, root_event):
				continue
			var targets: Array[Dictionary] = _resolve_effect_targets(owner, definition, {"source_item": owner_item})
			var affects_item: bool = false
			for target in targets:
				if str(target.get("kind", "")) == "player_item" and target.get("item", null) == item:
					affects_item = true
					break
			if not affects_item:
				continue
			var amount: int = int(round(_resolve_effect_amount(owner_item, effect_data, {"source_item": owner_item})))
			if amount <= 0:
				continue
			_record_effect_trace(owner, definition, str(root_event.get("name", "")), float(amount), targets.size())
			bonus += amount
	return maxi(bonus, 0)

func _execute_item_effect_definitions(
	item: ItemData,
	execution_context: Dictionary,
	timing: String = "before_consume"
) -> Dictionary:
	var result: Dictionary = _new_effect_execution_result()
	if item == null:
		return result
	if item.effects.is_empty():
		item.effects = EffectDefinitionClass.build_item_effects(item)
		item.effect_warnings = EffectDefinitionClass.collect_item_warnings(item, item.effects)
	var owner := {"kind": "item", "id": item.source_id, "item": item}
	var root_event: Dictionary = _make_effect_event(
		EffectDefinitionClass.TRIGGER_ON_COOLDOWN_READY,
		item
	)
	var has_poison_root: bool = false
	var has_regen_root: bool = false
	for definition_variant in item.effects:
		if not definition_variant is Dictionary:
			continue
		var definition: Dictionary = definition_variant
		if str(definition.get("trigger", "")) != EffectDefinitionClass.TRIGGER_ON_COOLDOWN_READY:
			continue
		var definition_timing: String = str(definition.get("timing", "before_consume"))
		if definition_timing != timing:
			continue
		if not _should_execute_effect_definition(owner, definition, root_event):
			continue
		var effect_data: Dictionary = definition.get("effect", {})
		if str(effect_data.get("type", "")) == EffectDefinitionClass.EFFECT_MULTICAST:
			continue
		if str(effect_data.get("type", "")) == EffectDefinitionClass.EFFECT_POISON:
			has_poison_root = true
		elif str(effect_data.get("type", "")) == EffectDefinitionClass.EFFECT_REGENERATION:
			has_regen_root = true
		if not _definition_condition_matches(owner, definition, root_event):
			continue
		var execution_result: Dictionary = _apply_effect_definition(
			owner,
			definition,
			root_event,
			execution_context
		)
		_merge_use_context(result.get("context", {}), execution_result.get("context", {}))
		result["events"].append_array(execution_result.get("events", []))
		if bool(execution_result.get("executed", false)):
			_mark_effect_definition_triggered(owner, definition, root_event)
		result["executed"] = bool(result.get("executed", false)) or bool(execution_result.get("executed", false))
	if timing == "before_consume":
		var extra_poison: float = _get_item_runtime_bonus(item, "poison") + _get_other_emerald_poison_bonus(item)
		if not has_poison_root and extra_poison > 0.0:
			var extra_poison_result: Dictionary = _apply_effect_definition(
				owner,
				{
					"id": "%s_runtime_poison_bonus" % item.source_id,
					"trigger": EffectDefinitionClass.TRIGGER_ON_COOLDOWN_READY,
					"target": {"side": "enemy", "selector": "hero"},
					"effect": {"type": EffectDefinitionClass.EFFECT_POISON, "amount": extra_poison},
				},
				root_event,
				execution_context
			)
			_merge_use_context(result.get("context", {}), extra_poison_result.get("context", {}))
			result["events"].append_array(extra_poison_result.get("events", []))
			result["executed"] = bool(result.get("executed", false)) or bool(extra_poison_result.get("executed", false))
		var extra_regen: float = _get_item_runtime_bonus(item, "regeneration")
		if not has_regen_root and extra_regen > 0.0:
			var extra_regen_result: Dictionary = _apply_effect_definition(
				owner,
				{
					"id": "%s_runtime_regeneration_bonus" % item.source_id,
					"trigger": EffectDefinitionClass.TRIGGER_ON_COOLDOWN_READY,
					"target": {"side": "self", "selector": "hero"},
					"effect": {"type": EffectDefinitionClass.EFFECT_REGENERATION, "amount": extra_regen},
				},
				root_event,
				execution_context
			)
			_merge_use_context(result.get("context", {}), extra_regen_result.get("context", {}))
			result["events"].append_array(extra_regen_result.get("events", []))
			result["executed"] = bool(result.get("executed", false)) or bool(extra_regen_result.get("executed", false))
	return result

func _process_reactive_effect_events(events: Array[Dictionary]) -> Dictionary:
	var context: Dictionary = _new_use_context()
	if events.is_empty():
		return context
	var queue: Array = []
	queue.append_array(events)
	var triggered_count: int = 0
	while not queue.is_empty():
		if triggered_count >= MAX_TRIGGERED_EFFECTS_PER_TICK:
			_push_effect_warning("effect_chain_limit:max_triggered_effects_per_tick")
			break
		var event_data: Dictionary = queue.pop_front()
		var depth: int = int(event_data.get("depth", 0))
		if depth >= EFFECT_CHAIN_DEPTH_LIMIT:
			_push_effect_warning("effect_chain_limit:chain_depth")
			continue
		for owner in _collect_effect_owners():
			var definitions: Array = owner.get("effects", [])
			for definition_variant in definitions:
				if not definition_variant is Dictionary:
					continue
				var definition: Dictionary = definition_variant
				if str(definition.get("trigger", "")) != str(event_data.get("name", "")):
					continue
				if not _should_execute_effect_definition(owner, definition, event_data):
					continue
				var execution_result: Dictionary = _apply_effect_definition(
					owner,
					definition,
					event_data,
					{
						"crit_multiplier": 1.0,
						"burn_bonus": 0.0,
						"poison_bonus": 0.0,
						"lifesteal_rate": 0.0,
						"is_crit": false,
					}
				)
				if not bool(execution_result.get("executed", false)):
					continue
				_mark_effect_definition_triggered(owner, definition, event_data)
				_merge_use_context(context, execution_result.get("context", {}))
				var next_events: Array = execution_result.get("events", [])
				for next_event_variant in next_events:
					if not next_event_variant is Dictionary:
						continue
					var next_event: Dictionary = (next_event_variant as Dictionary).duplicate(true)
					next_event["depth"] = depth + 1
					queue.append(next_event)
				triggered_count += 1
				if triggered_count >= MAX_TRIGGERED_EFFECTS_PER_TICK:
					break
			if triggered_count >= MAX_TRIGGERED_EFFECTS_PER_TICK:
				break
	return context

func _collect_effect_owners() -> Array[Dictionary]:
	var owners: Array[Dictionary] = []
	if inventory != null:
		for item in inventory.items:
			if item == null or item.effects.is_empty():
				continue
			owners.append({
				"kind": "item",
				"id": item.source_id,
				"item": item,
				"effects": item.effects,
			})
	for skill_ref in player_skill_refs:
		var skill_entry: Dictionary = PlayerSkillCatalogClass.get_skill_entry(skill_ref)
		var definitions: Array[Dictionary] = PlayerSkillCatalogClass.get_effect_definitions(skill_entry)
		if definitions.is_empty():
			continue
		owners.append({
			"kind": "skill",
			"id": str(skill_entry.get("id", "")),
			"skill_ref": skill_entry,
			"effects": definitions,
		})
	return owners

func _should_execute_effect_definition(
	owner: Dictionary,
	definition: Dictionary,
	event_data: Dictionary
) -> bool:
	if not _definition_condition_matches(owner, definition, event_data):
		return false
	var definition_key: String = _effect_definition_state_key(owner, definition)
	var state: Dictionary = _effect_runtime_state.get(definition_key, {})
	var consumed_events: Dictionary = state.get("consumed_events", {})
	var event_id: int = int(event_data.get("id", -1))
	if event_id >= 0 and consumed_events.has(event_id):
		return false
	var max_triggers: int = int(definition.get("max_triggers_per_fight", 0))
	if max_triggers > 0 and int(state.get("trigger_count", 0)) >= max_triggers:
		return false
	var internal_cooldown: float = float(definition.get("internal_cooldown", 0.0))
	if internal_cooldown > 0.0:
		var last_time: float = float(state.get("last_time", -999999.0))
		if _battle_elapsed_time - last_time < internal_cooldown:
			return false
	return true

func _mark_effect_definition_triggered(
	owner: Dictionary,
	definition: Dictionary,
	event_data: Dictionary
) -> void:
	var definition_key: String = _effect_definition_state_key(owner, definition)
	var state: Dictionary = _effect_runtime_state.get(definition_key, {})
	state["trigger_count"] = int(state.get("trigger_count", 0)) + 1
	state["last_time"] = _battle_elapsed_time
	var consumed_events: Dictionary = state.get("consumed_events", {})
	var event_id: int = int(event_data.get("id", -1))
	if event_id >= 0:
		consumed_events[event_id] = true
	state["consumed_events"] = consumed_events
	_effect_runtime_state[definition_key] = state

func _effect_definition_state_key(owner: Dictionary, definition: Dictionary) -> String:
	return "%s:%s" % [str(owner.get("id", "")), str(definition.get("id", ""))]

func _definition_condition_matches(
	owner: Dictionary,
	definition: Dictionary,
	event_data: Dictionary
) -> bool:
	var condition: Dictionary = definition.get("condition", {})
	if condition.is_empty():
		return true
	var owner_item: ItemData = owner.get("item", null) as ItemData
	var source_item: ItemData = event_data.get("source_item", null) as ItemData
	if condition.has("tag") and not _item_has_tag(source_item, str(condition.get("tag", ""))):
		return false
	if condition.has("no_event_source_tag") and _item_has_tag(source_item, str(condition.get("no_event_source_tag", ""))):
		return false
	if condition.has("event_source_has_ammo"):
		if source_item == null or source_item.has_ammo_limit() != bool(condition.get("event_source_has_ammo", false)):
			return false
	if condition.has("event_source_any_tags"):
		if source_item == null or not _item_has_any_tag(source_item, condition.get("event_source_any_tags", [])):
			return false
	if bool(condition.get("event_source_is_owner", false)):
		if owner_item == null or source_item == null or owner_item != source_item:
			return false
	if bool(condition.get("event_source_not_owner", false)):
		if owner_item == null or source_item == null or owner_item == source_item:
			return false
	if bool(condition.get("event_source_is_adjacent", false)):
		if owner_item == null or source_item == null or owner_item == source_item:
			return false
		if not _get_adjacent_player_items(owner_item).has(source_item):
			return false
	if bool(condition.get("event_source_has_lifesteal", false)) and not _item_has_lifesteal(source_item):
		return false
	if condition.has("event_source_size"):
		var expected_size: String = str(condition.get("event_source_size", "")).to_lower()
		if source_item == null:
			return false
		match expected_size:
			"small", "小":
				if source_item.get_slot_count() != 1:
					return false
			"medium", "中":
				if source_item.get_slot_count() != 2:
					return false
			"large", "大":
				if source_item.get_slot_count() != 3:
					return false
			_:
				return false
	if condition.has("status_type"):
		if str(event_data.get("status_type", "")) != str(condition.get("status_type", "")):
			return false
	if condition.has("status_type_any"):
		var event_status_type: String = str(event_data.get("status_type", ""))
		var matched_status_type: bool = false
		for status_type_variant in condition.get("status_type_any", []):
			if event_status_type == str(status_type_variant):
				matched_status_type = true
				break
		if not matched_status_type:
			return false
	if condition.has("overheal"):
		if bool(event_data.get("overheal", false)) != bool(condition.get("overheal", false)):
			return false
	if condition.has("event_source_relation"):
		if not _event_source_relation_matches(owner_item, source_item, str(condition.get("event_source_relation", ""))):
			return false
	if condition.has("event_source_relation_any"):
		var matched_relation: bool = false
		for relation_variant in condition.get("event_source_relation_any", []):
			if _event_source_relation_matches(owner_item, source_item, str(relation_variant)):
				matched_relation = true
				break
		if not matched_relation:
			return false
	if bool(condition.get("event_source_is_owner_or_adjacent", false)):
		if owner_item == null or source_item == null:
			return false
		if owner_item != source_item and not _get_adjacent_player_items(owner_item).has(source_item):
			return false
	if condition.has("adjacent_any_tags"):
		if owner_item == null:
			return false
		var has_match: bool = false
		for tag in condition.get("adjacent_any_tags", []):
			for adjacent in _get_adjacent_player_items(owner_item):
				if _item_has_tag(adjacent, str(tag)):
					has_match = true
					break
			if has_match:
				break
		if not has_match:
			return false
	if condition.has("adjacent_status_type"):
		if owner_item == null or not _has_adjacent_status_item(owner_item, str(condition.get("adjacent_status_type", ""))):
			return false
	if condition.has("has_item_size"):
		if not _has_player_item_size(str(condition.get("has_item_size", "")).to_lower()):
			return false
	if condition.has("no_other_tag"):
		if owner_item == null or _has_other_tag_item(owner_item, str(condition.get("no_other_tag", ""))):
			return false
	if condition.has("status_at_least"):
		var status_requirements: Array = [condition.get("status_at_least", {})]
		if condition.get("status_at_least") is Array:
			status_requirements = condition.get("status_at_least", [])
		for requirement_variant in status_requirements:
			if not requirement_variant is Dictionary:
				return false
			var requirement: Dictionary = requirement_variant
			var minimum: float = float(requirement.get("minimum", 0.0))
			var side: String = str(requirement.get("side", "self"))
			var status_type: String = str(requirement.get("type", ""))
			if _get_status_total(side, status_type) < minimum:
				return false
	return true

func _get_status_total(side: String, status_type: String) -> float:
	var state: Dictionary = enemy_status_state if side == "enemy" else player_status_state
	return float(state.get(status_type, 0.0))

func _event_source_relation_matches(owner_item: ItemData, source_item: ItemData, relation: String) -> bool:
	if owner_item == null or source_item == null or inventory == null:
		return false
	match relation:
		"left_adjacent":
			return inventory.get_right_adjacent_item(source_item) == owner_item
		"right_adjacent":
			return inventory.get_left_adjacent_item(source_item) == owner_item
	return false

func _has_other_tag_item(item: ItemData, tag: String) -> bool:
	if inventory == null or item == null:
		return false
	for candidate in inventory.items:
		if candidate != null and candidate != item and _item_has_tag(candidate, tag):
			return true
	return false

func _resolve_effect_amount(
	owner_item: ItemData,
	effect_data: Dictionary,
	execution_context: Dictionary
) -> float:
	var amount: float = 0.0
	if effect_data.has("amount_from"):
		match str(effect_data.get("amount_from", "")):
			"source.damage":
				if owner_item != null:
					amount = float(maxi(
						owner_item.get_rarity_adjusted_damage()
						+ int(round(_get_item_runtime_bonus(owner_item, "damage")))
						+ _get_player_item_skill_damage_bonus(owner_item),
						0
					))
			"source.shield":
				if owner_item != null:
					amount = float(
						ItemEffectsClass.calculate_shield(owner_item)
						+ int(round(_get_item_runtime_bonus(owner_item, "shield")))
						+ _get_player_item_skill_shield_bonus(owner_item)
					)
			"source.heal":
				if owner_item != null:
					amount = float(ItemEffectsClass.calculate_heal(owner_item) + int(round(_get_item_runtime_bonus(owner_item, "heal"))))
			"hero.max_health_percent":
				var percent: float = 0.0
				if effect_data.has("percent"):
					percent = float(effect_data.get("percent", 0.0))
				elif effect_data.has("percent_by_rarity"):
					percent = _get_rarity_value(owner_item, effect_data.get("percent_by_rarity", []), 0.0)
				var hero: HeroData = null if game_manager == null else game_manager.selected_hero
				amount = 0.0 if hero == null else float(hero.max_hp) * percent
			"enemy.max_health_percent":
				var percent: float = 0.0
				if effect_data.has("percent"):
					percent = float(effect_data.get("percent", 0.0))
				elif effect_data.has("percent_by_rarity"):
					percent = _get_rarity_value(owner_item, effect_data.get("percent_by_rarity", []), 0.0)
				amount = 0.0 if current_monster == null else float(current_monster.max_hp) * percent
			"source.poison":
				if owner_item != null:
					amount = owner_item.poison_damage
					amount += _get_item_runtime_bonus(owner_item, "poison")
					amount += _get_other_emerald_poison_bonus(owner_item)
				amount += float(execution_context.get("poison_bonus", 0.0))
			"source.poison_bonus":
				if owner_item != null:
					amount = _get_item_runtime_bonus(owner_item, "poison")
					amount += _get_other_emerald_poison_bonus(owner_item)
				amount += float(execution_context.get("poison_bonus", 0.0))
			"source.burn":
				amount = 0.0 if owner_item == null else owner_item.burn_damage
				if owner_item != null:
					amount += _get_item_runtime_bonus(owner_item, "burn")
					if owner_item.burn_damage > 0.0:
						amount += _get_other_ruby_burn_bonus(owner_item)
				amount += float(execution_context.get("burn_bonus", 0.0))
			"source.regeneration":
				amount = 0.0 if owner_item == null else owner_item.regeneration + _get_item_runtime_bonus(owner_item, "regeneration")
			"source.slow_duration":
				amount = 0.0 if owner_item == null else owner_item.slow_duration
			"source.freeze_duration":
				amount = 0.0 if owner_item == null else owner_item.freeze_duration + _get_item_runtime_bonus(owner_item, "freeze_duration")
			"source.haste_duration":
				amount = 0.0 if owner_item == null else owner_item.haste_duration
			"source.ammo":
				amount = 0.0 if owner_item == null else float(_get_player_item_effective_max_ammo(owner_item))
			"enemy_status.poison":
				amount = _get_status_total("enemy", EffectDefinitionClass.EFFECT_POISON)
			"player_status.regeneration":
				amount = _get_status_total("self", EffectDefinitionClass.EFFECT_REGENERATION)
			"source.cooldown_percent":
				var percent: float = float(effect_data.get("percent", 0.0))
				amount = 0.0 if owner_item == null else owner_item.cooldown * percent
			"other_items.burn_percent_by_rarity":
				amount = _get_other_items_status_total(owner_item, EffectDefinitionClass.EFFECT_BURN) * _get_rarity_value(owner_item, effect_data.get("percent_by_rarity", []), 0.0)
			"other_items.matching_tag_count":
				amount = float(_count_other_player_items_matching_tag(owner_item, str(effect_data.get("tag", ""))))
			"other_items.matching_any_tag_count":
				amount = float(_count_other_player_items_matching_any_tag(owner_item, effect_data.get("tags", [])))
			"adjacent_items.matching_tag_count":
				amount = float(_count_adjacent_player_items_matching_tag(owner_item, str(effect_data.get("tag", ""))))
			"adjacent_items.matching_any_tag_count":
				amount = float(_count_adjacent_player_items_matching_any_tag(owner_item, effect_data.get("tags", [])))
			"weakest_weapon.damage":
				amount = _get_weakest_weapon_damage()
	elif effect_data.has("amount"):
		amount = float(effect_data.get("amount", 0.0))
	elif effect_data.has("amount_by_rarity"):
		amount = _get_rarity_value(owner_item, effect_data.get("amount_by_rarity", []), 0.0)
	if bool(effect_data.get("include_runtime_poison_bonus", false)) and owner_item != null:
		amount += _get_item_runtime_bonus(owner_item, "poison")
	if bool(effect_data.get("include_burn_synergy_bonus", false)) and owner_item != null:
		amount += _get_other_ruby_burn_bonus(owner_item)
	if bool(effect_data.get("crit_scaled", false)):
		amount *= float(execution_context.get("crit_multiplier", 1.0))
	return maxf(amount, 0.0)

func _resolve_target_count(
	owner_item: ItemData,
	target_data: Dictionary,
	effect_data: Dictionary,
	execution_context: Dictionary
) -> int:
	var count: int = 1
	if target_data.has("count"):
		count = int(target_data.get("count", 1))
	elif target_data.has("count_from") and owner_item != null:
		match str(target_data.get("count_from", "")):
			"source.slow_count":
				count = owner_item.slow_count + int(round(_get_item_runtime_bonus(owner_item, "slow_count")))
			"source.freeze_count":
				count = owner_item.freeze_count
			"source.haste_count":
				count = owner_item.haste_count
	if bool(effect_data.get("count_crit_scaled", false)):
		count = int(round(float(count) * float(execution_context.get("crit_multiplier", 1.0))))
	return maxi(count, 1)

func _resolve_effect_targets(
	owner: Dictionary,
	definition: Dictionary,
	execution_context: Dictionary
) -> Array[Dictionary]:
	var targets: Array[Dictionary] = []
	var owner_item: ItemData = owner.get("item", null) as ItemData
	var target_data: Dictionary = definition.get("target", {})
	var effect_data: Dictionary = definition.get("effect", {})
	var selector: String = str(target_data.get("selector", "hero"))
	var side: String = str(target_data.get("side", "self"))
	var count: int = _resolve_target_count(owner_item, target_data, effect_data, execution_context)
	match selector:
		"hero":
			targets.append({"kind": "hero", "side": side})
		"this_item":
			if owner_item != null:
				targets.append({"kind": "player_item", "item": owner_item})
		"left_item":
			if inventory != null and owner_item != null:
				var left_item: ItemData = inventory.get_left_adjacent_item(owner_item)
				if left_item != null:
					targets.append({"kind": "player_item", "item": left_item})
		"right_item":
			if inventory != null and owner_item != null:
				var right_item: ItemData = inventory.get_right_adjacent_item(owner_item)
				if right_item != null:
					targets.append({"kind": "player_item", "item": right_item})
		"right_matching_tag":
			if inventory != null and owner_item != null:
				var right_item: ItemData = inventory.get_right_adjacent_item(owner_item)
				var tag: String = str(target_data.get("tag", ""))
				if right_item != null and _item_has_tag(right_item, tag):
					targets.append({"kind": "player_item", "item": right_item})
		"adjacent":
			if owner_item != null:
				for adjacent in _get_adjacent_player_items(owner_item):
					if adjacent != null:
						targets.append({"kind": "player_item", "item": adjacent})
		"adjacent_matching_tag_items":
			var tag: String = str(target_data.get("tag", ""))
			if owner_item != null:
				for adjacent in _get_adjacent_player_items(owner_item):
					if adjacent != null and _item_has_tag(adjacent, tag):
						targets.append({"kind": "player_item", "item": adjacent})
		"source_item":
			var source_item: ItemData = execution_context.get("source_item", null) as ItemData
			if source_item != null:
				targets.append({"kind": "player_item", "item": source_item})
		"left_of_source":
			var source_item: ItemData = execution_context.get("source_item", null) as ItemData
			if inventory != null and source_item != null:
				var left_item: ItemData = inventory.get_left_adjacent_item(source_item)
				if left_item != null:
					targets.append({"kind": "player_item", "item": left_item})
		"adjacent_to_source":
			var source_item: ItemData = execution_context.get("source_item", null) as ItemData
			if source_item != null:
				for adjacent in _get_adjacent_player_items(source_item):
					if adjacent != null:
						targets.append({"kind": "player_item", "item": adjacent})
		"all_items":
			if inventory != null:
				for item in inventory.items:
					if item != null:
						targets.append({"kind": "player_item", "item": item})
		"matching_tag_items", "non_matching_tag_items", "other_matching_tag_items", "other_non_matching_tag_items":
			var tag: String = str(target_data.get("tag", ""))
			if inventory != null:
				for item in inventory.items:
					if item == null:
						continue
					var has_tag: bool = _item_has_tag(item, tag)
					if (selector == "other_matching_tag_items" or selector == "other_non_matching_tag_items") and item == owner_item:
						continue
					if (selector == "matching_tag_items" and has_tag) or (selector == "other_matching_tag_items" and has_tag) or (selector == "non_matching_tag_items" and not has_tag) or (selector == "other_non_matching_tag_items" and not has_tag):
						targets.append({"kind": "player_item", "item": item})
		"matching_any_tag_highest_cooldown":
			var tags: Array = target_data.get("tags", [])
			var candidates: Array[ItemData] = []
			if inventory != null:
				for item in inventory.items:
					if item == null or item.current_cooldown <= 0.0:
						continue
					for tag_variant in tags:
						if _item_has_tag(item, str(tag_variant)):
							candidates.append(item)
							break
			candidates.sort_custom(func(a: ItemData, b: ItemData) -> bool:
				return a.current_cooldown > b.current_cooldown
			)
			for index in range(mini(count, candidates.size())):
				targets.append({"kind": "player_item", "item": candidates[index]})
		"matching_size_highest_cooldown", "other_matching_size_highest_cooldown":
			var size_name: String = str(target_data.get("size", "")).to_lower()
			var candidates: Array[ItemData] = []
			if inventory != null:
				for item in inventory.items:
					if item == null or not _item_size_matches(item, size_name) or item.current_cooldown <= 0.0:
						continue
					if selector == "other_matching_size_highest_cooldown" and item == owner_item:
						continue
					candidates.append(item)
			candidates.sort_custom(func(a: ItemData, b: ItemData) -> bool:
				return a.current_cooldown > b.current_cooldown
			)
			for index in range(mini(count, candidates.size())):
				targets.append({"kind": "player_item", "item": candidates[index]})
		"smaller_than_source_highest_cooldown":
			var source_item: ItemData = execution_context.get("source_item", null) as ItemData
			var source_slots: int = 0 if source_item == null else source_item.get_slot_count()
			var candidates: Array[ItemData] = []
			if inventory != null and source_slots > 0:
				for item in inventory.items:
					if item != null and item != source_item and item.get_slot_count() < source_slots and item.current_cooldown > 0.0:
						candidates.append(item)
			candidates.sort_custom(func(a: ItemData, b: ItemData) -> bool:
				return a.current_cooldown > b.current_cooldown
			)
			for index in range(mini(count, candidates.size())):
				targets.append({"kind": "player_item", "item": candidates[index]})
		"ammo_items":
			if inventory != null:
				for item in inventory.items:
					if item != null and item.has_ammo_limit():
						targets.append({"kind": "player_item", "item": item})
						if targets.size() >= count:
							break
		"lifesteal_weapon_items":
			if inventory != null:
				for item in inventory.items:
					if item != null and _is_weapon_item(item) and _item_has_lifesteal(item):
						targets.append({"kind": "player_item", "item": item})
		"adjacent_matching_size_items":
			var size_name: String = str(target_data.get("size", "")).to_lower()
			if owner_item != null:
				for adjacent in _get_adjacent_player_items(owner_item):
					if adjacent != null and _item_size_matches(adjacent, size_name):
						targets.append({"kind": "player_item", "item": adjacent})
		"matching_tag_highest_cooldown":
			var tag: String = str(target_data.get("tag", ""))
			var candidates: Array[ItemData] = []
			if inventory != null:
				for item in inventory.items:
					if item != null and _item_has_tag(item, tag) and item.current_cooldown > 0.0:
						candidates.append(item)
			candidates.sort_custom(func(a: ItemData, b: ItemData) -> bool:
				return a.current_cooldown > b.current_cooldown
			)
			for index in range(mini(count, candidates.size())):
				targets.append({"kind": "player_item", "item": candidates[index]})
		"slowest_other_items":
			var other_items: Array[ItemData] = []
			if inventory != null:
				for item in inventory.items:
					if item != null and item != owner_item and item.cooldown > 0.0:
						other_items.append(item)
			other_items.sort_custom(func(a: ItemData, b: ItemData) -> bool:
				return a.current_cooldown > b.current_cooldown
			)
			for index in range(mini(count, other_items.size())):
				targets.append({"kind": "player_item", "item": other_items[index]})
		"slowest_items":
			if side == "enemy" and current_monster != null:
				var enemy_indices: Array[int] = []
				for item_index in range(current_monster.monster_items.size()):
					var monster_item: Dictionary = current_monster.monster_items[item_index]
					if float(monster_item.get("cooldown", 0.0)) > 0.0:
						enemy_indices.append(item_index)
				enemy_indices.sort_custom(func(a: int, b: int) -> bool:
					return float(current_monster.monster_items[a].get("current_cooldown", 0.0)) > float(current_monster.monster_items[b].get("current_cooldown", 0.0))
				)
				for index in range(mini(count, enemy_indices.size())):
					targets.append({"kind": "monster_item", "index": enemy_indices[index]})
			elif side != "enemy" and inventory != null:
				var player_items: Array[ItemData] = []
				for item in inventory.items:
					if item != null and item.cooldown > 0.0:
						player_items.append(item)
				player_items.sort_custom(func(a: ItemData, b: ItemData) -> bool:
					return a.current_cooldown > b.current_cooldown
				)
				for index in range(mini(count, player_items.size())):
					targets.append({"kind": "player_item", "item": player_items[index]})
		_:
			_push_effect_warning("unsupported_target_selector:%s:%s" % [
				str(owner.get("id", "")),
				selector,
			])
	return targets

func _apply_effect_definition(
	owner: Dictionary,
	definition: Dictionary,
	event_data: Dictionary,
	execution_context: Dictionary
) -> Dictionary:
	var result: Dictionary = _new_effect_execution_result()
	var effect_data: Dictionary = definition.get("effect", {})
	var effect_type: String = str(effect_data.get("type", ""))
	var owner_item: ItemData = owner.get("item", null) as ItemData
	execution_context["source_item"] = event_data.get("source_item", null)
	if effect_type == EffectDefinitionClass.EFFECT_MULTICAST:
		return result
	var amount: float = _resolve_effect_amount(owner_item, effect_data, execution_context)
	var targets: Array[Dictionary] = _resolve_effect_targets(owner, definition, execution_context)
	if targets.is_empty() and effect_type != EffectDefinitionClass.EFFECT_DAMAGE:
		return result

	match effect_type:
		EffectDefinitionClass.EFFECT_DAMAGE:
			var damage_amount: int = int(round(amount))
			if damage_amount <= 0:
				return result
			var did_damage: bool = false
			for target in targets:
				if str(target.get("kind", "")) != "hero":
					continue
				if str(target.get("side", "")) == "enemy":
					if current_monster != null and current_monster.is_alive():
						_damage_current_monster(damage_amount)
						did_damage = true
				elif game_manager != null:
					_damage_player(damage_amount)
					did_damage = true
			if not did_damage:
				return result
			result["executed"] = true
			result["context"]["damage"] = int(result["context"].get("damage", 0)) + damage_amount
			if owner_item != null:
				item_triggered.emit(
					owner_item.item_name,
					damage_amount,
					bool(execution_context.get("is_crit", false)),
					"enemy"
				)
				var crit_text: String = "（暴击!）" if bool(execution_context.get("is_crit", false)) else ""
				print("🗡️ [%s] 触发！造成 %d 伤害%s" % [owner_item.item_name, damage_amount, crit_text])
				var lifesteal_rate: float = clampf(
					float(execution_context.get("lifesteal_rate", 0.0))
					+ (1.0 if _item_has_lifesteal(owner_item) else 0.0),
					0.0,
					1.0
				)
				if lifesteal_rate > 0.0 and game_manager != null:
					var stolen: int = int(float(damage_amount) * lifesteal_rate)
					if stolen > 0:
						game_manager.heal(stolen)
						print("💚 [%s] 生命偷取恢复 %d 生命" % [owner_item.item_name, stolen])
			result["events"].append(_make_effect_event(
				EffectDefinitionClass.TRIGGER_ON_DAMAGE_DEALT,
				owner_item
			))
		EffectDefinitionClass.EFFECT_SHIELD:
			var shield_amount: int = int(round(amount))
			if shield_amount <= 0:
				return result
			var applied_shield: bool = false
			for target in targets:
				if str(target.get("kind", "")) != "hero":
					continue
				if str(target.get("side", "")) == "enemy":
					if current_monster != null:
						current_monster.current_shield = maxf(current_monster.current_shield + float(shield_amount), 0.0)
						applied_shield = true
				else:
					var hero: HeroData = null if game_manager == null else game_manager.selected_hero
					if hero != null:
						hero.add_shield(float(shield_amount))
						applied_shield = true
			if not applied_shield:
				return result
			result["executed"] = true
			result["context"]["shield_proc_count"] = int(result["context"].get("shield_proc_count", 0)) + 1
			effect_applied.emit(_owner_effect_name(owner), "shield", shield_amount, str((targets[0] as Dictionary).get("side", "self")))
			print("🛡️ [%s] 触发！获得 %d 护盾" % [_owner_effect_name(owner), shield_amount])
			result["events"].append(_make_effect_event(
				EffectDefinitionClass.TRIGGER_ON_SHIELD_GAINED,
				owner_item
			))
		EffectDefinitionClass.EFFECT_HEAL:
			var heal_amount: int = int(round(amount))
			if heal_amount <= 0:
				return result
			var applied_heal: bool = false
			var overheal_occurred: bool = false
			for target in targets:
				if str(target.get("kind", "")) != "hero":
					continue
				if str(target.get("side", "")) == "enemy":
					if current_monster != null and current_monster.is_alive():
						var enemy_missing_health: int = maxi(current_monster.max_hp - current_monster.current_hp, 0)
						overheal_occurred = overheal_occurred or heal_amount > enemy_missing_health
						current_monster.current_hp = mini(current_monster.current_hp + heal_amount, current_monster.max_hp)
						applied_heal = true
				elif game_manager != null:
					var selected_hero: HeroData = game_manager.selected_hero
					var missing_health: int = 0
					if selected_hero != null:
						missing_health = maxi(selected_hero.max_hp - int(game_manager.player_health), 0)
					overheal_occurred = overheal_occurred or heal_amount > missing_health
					game_manager.heal(heal_amount)
					applied_heal = true
			if not applied_heal:
				return result
			result["executed"] = true
			result["context"]["heal_proc_count"] = int(result["context"].get("heal_proc_count", 0)) + 1
			effect_applied.emit(_owner_effect_name(owner), "heal", heal_amount, str((targets[0] as Dictionary).get("side", "self")))
			print("💚 [%s] 触发！恢复 %d 生命" % [_owner_effect_name(owner), heal_amount])
			result["events"].append(_make_effect_event(
				EffectDefinitionClass.TRIGGER_ON_HEAL,
				owner_item,
				{"overheal": overheal_occurred}
			))
		EffectDefinitionClass.EFFECT_POISON, EffectDefinitionClass.EFFECT_BURN, EffectDefinitionClass.EFFECT_REGENERATION:
			var status_amount: float = amount
			if status_amount <= 0.0:
				return result
			var applied_status: bool = false
			for target in targets:
				if str(target.get("kind", "")) != "hero":
					continue
				var target_side: String = str(target.get("side", "enemy"))
				_apply_status_effect({
					"type": effect_type,
					"value": status_amount,
					"duration": 0.0,
					"item_name": _owner_effect_name(owner),
					"target": "enemy" if target_side == "enemy" else "self",
				})
				applied_status = true
				if target_side == "enemy":
					result["events"].append(_make_effect_event(
						EffectDefinitionClass.TRIGGER_ON_ENEMY_STATUS_APPLIED,
						owner_item,
						{"status_type": effect_type}
					))
			if not applied_status:
				return result
			result["executed"] = true
			match effect_type:
				EffectDefinitionClass.EFFECT_POISON:
					result["context"]["poison_proc_count"] = int(result["context"].get("poison_proc_count", 0)) + 1
				EffectDefinitionClass.EFFECT_BURN:
					result["context"]["burn_proc_count"] = int(result["context"].get("burn_proc_count", 0)) + 1
				EffectDefinitionClass.EFFECT_REGENERATION:
					result["context"]["regen_proc_count"] = int(result["context"].get("regen_proc_count", 0)) + 1
		EffectDefinitionClass.EFFECT_SLOW, EffectDefinitionClass.EFFECT_FREEZE, EffectDefinitionClass.EFFECT_HASTE, EffectDefinitionClass.EFFECT_CHARGE:
			if amount <= 0.0:
				return result
			var applied_count: int = 0
			for target in targets:
				match str(target.get("kind", "")):
					"player_item":
						var player_item: ItemData = target.get("item", null) as ItemData
						if player_item == null:
							continue
						if effect_type == EffectDefinitionClass.EFFECT_SLOW or effect_type == EffectDefinitionClass.EFFECT_FREEZE:
							player_item.current_cooldown = maxf(player_item.current_cooldown + amount, 0.0)
						else:
							player_item.current_cooldown = maxf(player_item.current_cooldown - amount, 0.0)
						applied_count += 1
					"monster_item":
						var item_index: int = int(target.get("index", -1))
						if current_monster == null or item_index < 0 or item_index >= current_monster.monster_items.size():
							continue
						var monster_item: Dictionary = current_monster.monster_items[item_index]
						if effect_type == EffectDefinitionClass.EFFECT_SLOW or effect_type == EffectDefinitionClass.EFFECT_FREEZE:
							monster_item["current_cooldown"] = maxf(float(monster_item.get("current_cooldown", 0.0)) + amount, 0.0)
						else:
							monster_item["current_cooldown"] = maxf(float(monster_item.get("current_cooldown", 0.0)) - amount, 0.0)
						applied_count += 1
			if applied_count <= 0:
				return result
			if effect_type == EffectDefinitionClass.EFFECT_HASTE:
				for target in targets:
					if str(target.get("kind", "")) == "player_item":
						_handle_player_item_gained_haste(target.get("item", null) as ItemData, 1)
			result["executed"] = true
			match effect_type:
				EffectDefinitionClass.EFFECT_SLOW:
					result["context"]["slow_proc_count"] = int(result["context"].get("slow_proc_count", 0)) + 1
					result["events"].append(_make_effect_event(
						EffectDefinitionClass.TRIGGER_ON_ENEMY_STATUS_APPLIED,
						owner_item,
						{"status_type": EffectDefinitionClass.EFFECT_SLOW}
					))
				EffectDefinitionClass.EFFECT_FREEZE:
					result["context"]["freeze_proc_count"] = int(result["context"].get("freeze_proc_count", 0)) + 1
					result["events"].append(_make_effect_event(
						EffectDefinitionClass.TRIGGER_ON_ENEMY_STATUS_APPLIED,
						owner_item,
						{"status_type": EffectDefinitionClass.EFFECT_FREEZE}
					))
				EffectDefinitionClass.EFFECT_HASTE:
					result["context"]["haste_proc_count"] = int(result["context"].get("haste_proc_count", 0)) + 1
				EffectDefinitionClass.EFFECT_CHARGE:
					pass
			effect_applied.emit(_owner_effect_name(owner), effect_type, int(round(amount)), str((definition.get("target", {}) as Dictionary).get("side", "self")))
		EffectDefinitionClass.EFFECT_RUNTIME_BONUS:
			var bonus_key: String = str(effect_data.get("bonus_key", ""))
			if bonus_key.is_empty() or amount == 0.0:
				return result
			var applied_bonus_count: int = 0
			var is_permanent: bool = str(effect_data.get("scope", "combat")) == "permanent" or bool(effect_data.get("permanent", false))
			for target in targets:
				if str(target.get("kind", "")) != "player_item":
					continue
				var player_item: ItemData = target.get("item", null) as ItemData
				if player_item == null:
					continue
				if is_permanent:
					if _apply_permanent_item_bonus(player_item, bonus_key, amount):
						applied_bonus_count += 1
				else:
					_add_item_runtime_bonus(player_item, bonus_key, amount)
					applied_bonus_count += 1
			if applied_bonus_count <= 0:
				return result
			result["executed"] = true
		EffectDefinitionClass.EFFECT_RELOAD:
			var reload_amount: int = maxi(int(round(amount)), 1)
			var reloaded_count: int = 0
			for target in targets:
				if str(target.get("kind", "")) != "player_item":
					continue
				var player_item: ItemData = target.get("item", null) as ItemData
				if player_item == null:
					continue
				if player_item.refill_ammo(reload_amount) > 0:
					reloaded_count += 1
			if reloaded_count <= 0:
				return result
			result["executed"] = true
			result["events"].append(_make_effect_event(
				EffectDefinitionClass.TRIGGER_ON_RELOAD,
				owner_item,
				{"reload_count": reloaded_count}
			))
			effect_applied.emit(_owner_effect_name(owner), effect_type, reload_amount, "self")
		EffectDefinitionClass.EFFECT_AMMO:
			var ammo_amount: int = int(round(amount))
			if ammo_amount <= 0:
				return result
			var ammo_target_count: int = 0
			for target in targets:
				if str(target.get("kind", "")) != "player_item":
					continue
				var player_item: ItemData = target.get("item", null) as ItemData
				if player_item == null:
					continue
				var before_max_ammo: int = player_item.get_max_ammo()
				var before_current_ammo: int = player_item.get_current_ammo()
				player_item.current_max_ammo = maxi(before_max_ammo + ammo_amount, 0)
				player_item.current_ammo = clampi(before_current_ammo + ammo_amount, 0, player_item.current_max_ammo)
				ammo_target_count += 1
			if ammo_target_count <= 0:
				return result
			result["executed"] = true
			effect_applied.emit(_owner_effect_name(owner), effect_type, ammo_amount, "self")
		_:
			_push_effect_warning("unsupported_effect_type:%s:%s" % [
				str(owner.get("id", "")),
				effect_type,
			])
			return result

	if bool(result.get("executed", false)):
		_record_effect_trace(owner, definition, str(event_data.get("name", "")), amount, targets.size())
	return result

func _owner_effect_name(owner: Dictionary) -> String:
	var owner_item: ItemData = owner.get("item", null) as ItemData
	if owner_item != null:
		return owner_item.item_name
	var skill_entry: Dictionary = owner.get("skill_ref", {})
	return PlayerSkillCatalogClass.get_skill_display_name(skill_entry)

func _apply_permanent_item_bonus(item: ItemData, key: String, value: float) -> bool:
	if item == null or value == 0.0:
		return false
	match key:
		EffectDefinitionClass.EFFECT_DAMAGE:
			item.damage = maxi(item.damage + int(round(value)), 0)
		EffectDefinitionClass.EFFECT_SHIELD:
			item.shield = maxi(item.shield + int(round(value)), 0)
		EffectDefinitionClass.EFFECT_HEAL:
			item.heal = maxi(item.heal + int(round(value)), 0)
		EffectDefinitionClass.EFFECT_POISON:
			item.poison_damage = maxf(item.poison_damage + value, 0.0)
		EffectDefinitionClass.EFFECT_BURN:
			item.burn_damage = maxf(item.burn_damage + value, 0.0)
		EffectDefinitionClass.EFFECT_REGENERATION:
			item.regeneration = maxf(item.regeneration + value, 0.0)
		"crit_rate":
			item.crit_chance = maxf(item.crit_chance + value / 100.0, 0.0)
		EffectDefinitionClass.EFFECT_AMMO:
			item.ammo = maxi(item.ammo + int(round(value)), 0)
		_:
			return false
	return true

func _get_item_runtime_bonus(item: ItemData, key: String) -> float:
	if item == null:
		return 0.0
	var stored_bonus: float = 0.0
	var item_id: int = item.get_instance_id()
	if item_runtime_bonuses.has(item_id):
		var bonuses: Dictionary = item_runtime_bonuses.get(item_id, {})
		stored_bonus = float(bonuses.get(key, 0.0))
	return stored_bonus + _get_dynamic_item_runtime_bonus(item, key)

func _get_dynamic_item_runtime_bonus(item: ItemData, key: String) -> float:
	if item == null:
		return 0.0
	if key == EffectDefinitionClass.EFFECT_DAMAGE and _is_weapon_item(item):
		return _get_poppy_field_weapon_damage_bonus(item)
	return 0.0

func _get_poppy_field_weapon_damage_bonus(item: ItemData) -> float:
	if inventory == null or item == null:
		return 0.0
	var enemy_poison: float = float(enemy_status_state.get(EffectDefinitionClass.EFFECT_POISON, 0.0))
	if enemy_poison <= 0.0:
		return 0.0
	var bonus: float = 0.0
	for candidate in inventory.items:
		if candidate != null and candidate != item and candidate.source_id == "poppy_field":
			bonus += enemy_poison * _get_rarity_value(candidate, [0.0, 0.5, 0.75, 1.0], 0.0)
	return bonus

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

func _apply_run_battle_start_status_bonuses() -> void:
	if RunStateService == null:
		return
	var bonuses: Dictionary = RunStateService.get_battle_start_status_bonuses()
	for status_id in bonuses.keys():
		var amount: float = float(bonuses.get(status_id, 0.0))
		if amount <= 0.0:
			continue
		_add_status_to_state(player_status_state, str(status_id), amount)
		effect_execution_trace.append({
			"owner_kind": "run_state",
			"owner_id": "battle_start_status_bonus",
			"definition_id": "run_state_%s_battle_start" % str(status_id),
			"trigger": EffectDefinitionClass.TRIGGER_ON_BATTLE_START,
			"event_name": "run_state_battle_start_status",
			"effect_type": str(status_id),
			"amount": amount,
			"target_count": 1,
			"time": _battle_elapsed_time,
		})

func _apply_player_skill_battle_start_effects() -> void:
	if _has_player_skill("pickpocket") and game_manager != null:
		var gold_amount: int = maxi(int(round(_get_player_skill_value("pickpocket"))), 0)
		if gold_amount > 0:
			game_manager.add_gold(gold_amount)
			_record_effect_trace({"kind": "player_skill", "id": "pickpocket"}, {"id": "pickpocket_battle_start_gain_gold", "trigger": EffectDefinitionClass.TRIGGER_ON_BATTLE_START, "effect": {"type": "gold"}}, EffectDefinitionClass.TRIGGER_ON_BATTLE_START, float(gold_amount), 1)
	_apply_player_skill_start_item_bonuses()
	_apply_player_skill_start_status_bonuses()
	_process_reactive_effect_events([
		_make_effect_event(EffectDefinitionClass.TRIGGER_ON_BATTLE_START, null)
	])

func _apply_player_skill_start_status_bonuses() -> void:
	if _has_player_skill("adaptive_ordinance"):
		var ammo_count: int = _count_player_items_matching("ammo")
		if ammo_count > 0:
			_add_status_to_state(player_status_state, ItemEffectsClass.EFFECT_REGEN, _get_player_skill_value("adaptive_ordinance") * float(ammo_count))
	if _has_player_skill("waters_of_infinity"):
		var non_weapon_count: int = 0
		if inventory != null:
			for candidate in inventory.items:
				if candidate != null and not _is_weapon_item(candidate):
					non_weapon_count += 1
		if non_weapon_count > 0:
			_add_status_to_state(player_status_state, ItemEffectsClass.EFFECT_REGEN, _get_player_skill_value("waters_of_infinity") * float(non_weapon_count))

func _apply_player_skill_start_item_bonuses() -> void:
	if inventory == null:
		return
	if _has_player_skill("initial_dose"):
		var poison_item: ItemData = _get_edge_matching_player_item("poison", true)
		if poison_item != null:
			_add_item_runtime_bonus(poison_item, "poison", _get_player_skill_value("initial_dose"))
	if _has_player_skill("vital_reserve"):
		var regen_item: ItemData = _get_edge_matching_player_item("regeneration", false)
		if regen_item != null:
			_add_item_runtime_bonus(regen_item, "regeneration", _get_player_skill_value("vital_reserve"))
	if _has_player_skill("final_flame"):
		var burn_item: ItemData = _get_edge_matching_player_item("burn", false)
		if burn_item != null:
			_add_item_runtime_bonus(burn_item, "burn", _get_player_skill_value("final_flame"))
	if _has_player_skill("first_responder"):
		var left_heal_item: ItemData = _get_edge_matching_player_item("heal", true)
		if left_heal_item != null:
			_add_item_runtime_bonus(left_heal_item, "heal", _get_player_skill_value("first_responder"))
	if _has_player_skill("follow_up_care"):
		var right_heal_item: ItemData = _get_edge_matching_player_item("heal", false)
		if right_heal_item != null:
			_add_item_runtime_bonus(right_heal_item, "heal", _get_player_skill_value("follow_up_care"))
	if _has_player_skill("frontal_shielding"):
		var shield_item: ItemData = _get_edge_matching_player_item("shield", true)
		if shield_item != null:
			_add_item_runtime_bonus(shield_item, "shield", _get_player_skill_value("frontal_shielding"))
	if _has_player_skill("augmented_defenses"):
		_add_player_skill_bonus_to_items("augmented_defenses", "shield", "shield", 1)

func _get_edge_matching_player_item(selector: String, leftmost: bool) -> ItemData:
	if inventory == null:
		return null
	var items: Array = inventory.items.duplicate()
	if not leftmost:
		items.reverse()
	for candidate in items:
		if candidate is ItemData and _matches_player_item_selector(candidate as ItemData, selector):
			return candidate as ItemData
	return null

func _apply_player_skill_status_runtime_bonuses(status_type: String, trigger_count: int) -> void:
	if inventory == null or trigger_count <= 0:
		return
	match status_type:
		ItemEffectsClass.EFFECT_BURN:
			_add_player_skill_bonus_to_items("tracer_fire", "any", "crit_rate", trigger_count)
			_add_player_skill_bonus_to_items("burning_rage", "weapon", "damage", trigger_count)
		ItemEffectsClass.EFFECT_POISON:
			_add_player_skill_bonus_to_items("exposing_toxins", "any", "crit_rate", trigger_count)
		ItemEffectsClass.EFFECT_REGEN:
			_add_player_skill_bonus_to_items("purifying_flame", "burn", "burn", trigger_count)
		ItemEffectsClass.EFFECT_SLOW:
			_add_player_skill_bonus_to_items("slow_and_steady", "weapon", "damage", trigger_count)
			_add_player_skill_bonus_to_items("slowed_targets", "any", "crit_rate", trigger_count)
			_add_player_skill_bonus_to_items("trained", "weapon", "damage", trigger_count)
		ItemEffectsClass.EFFECT_FREEZE:
			_add_player_skill_bonus_to_items("snowstorm", "weapon", "damage", trigger_count)
			_add_player_skill_bonus_to_items("reaching_the_summit", "any", "crit_rate", trigger_count)
		ItemEffectsClass.EFFECT_HASTE:
			if _has_player_skill("time_to_tinker"):
				var hero: HeroData = null if game_manager == null else game_manager.selected_hero
				if hero != null:
					hero.add_shield(_get_player_skill_value("time_to_tinker") * float(trigger_count))

func _add_player_skill_bonus_to_items(skill_id: String, selector: String, bonus_key: String, trigger_count: int) -> void:
	if not _has_player_skill(skill_id) or trigger_count <= 0:
		return
	var bonus: float = _get_player_skill_value(skill_id) * float(trigger_count)
	if bonus <= 0.0:
		return
	for candidate in inventory.items:
		if candidate is ItemData and _matches_player_item_selector(candidate as ItemData, selector):
			_add_item_runtime_bonus(candidate as ItemData, bonus_key, bonus)

func _apply_player_skill_item_use_triggers(item: ItemData, context: Dictionary) -> void:
	if item == null:
		return
	var use_count: int = int(context.get("use_count", 0))
	if use_count <= 0:
		return
	if _has_player_skill("heated_shells") and item.has_ammo_limit():
		var burn_amount: float = _get_player_skill_value("heated_shells")
		if burn_amount > 0.0:
			_apply_status_effect({
				"type": ItemEffectsClass.EFFECT_BURN,
				"value": burn_amount * float(use_count),
				"duration": 0.0,
				"item_name": _get_player_skill_name("heated_shells"),
				"target": "enemy",
			})
			print("🔥 [%s] 响应 Ammo 使用，施加 %.0f 燃烧" % [_get_player_skill_name("heated_shells"), burn_amount * float(use_count)])

func _apply_player_skill_status_triggers(status_type: String, trigger_count: int) -> void:
	if trigger_count <= 0:
		return
	match status_type:
		ItemEffectsClass.EFFECT_POISON:
			if _has_player_skill("paralytic_poison") and _increment_skill_counter("paralytic_poison", 0) == 0:
				var freeze_duration: float = _get_player_skill_value("paralytic_poison")
				if freeze_duration > 0.0 and _slow_monster_items(1, freeze_duration) > 0:
					_increment_skill_counter("paralytic_poison", 1)
					effect_applied.emit(_get_player_skill_name("paralytic_poison"), ItemEffectsClass.EFFECT_FREEZE, int(round(freeze_duration)), "enemy")
					print("❄️ [%s] 第一次 Poison 时冻结敌方物品 %.1f 秒" % [_get_player_skill_name("paralytic_poison"), freeze_duration])
		ItemEffectsClass.EFFECT_SLOW:
			if _has_player_skill("slow_burn"):
				var limit: int = int(round(_get_player_skill_value("slow_burn", "limits")))
				var charge_seconds: float = _get_player_skill_value("slow_burn", "charge_seconds")
				if limit > 0 and charge_seconds > 0.0:
					for _index in range(trigger_count):
						if _increment_skill_counter("slow_burn", 0) >= limit:
							break
						if _charge_matching_player_item("burn", charge_seconds):
							_increment_skill_counter("slow_burn", 1)
							print("⚡ [%s] 响应 Slow，急速一个 Burn 物品 %.1f 秒" % [_get_player_skill_name("slow_burn"), charge_seconds])

func _charge_matching_player_item(selector: String, seconds: float) -> bool:
	if inventory == null or seconds <= 0.0:
		return false
	var candidates: Array[ItemData] = []
	for candidate in inventory.items:
		if candidate != null and _matches_player_item_selector(candidate, selector) and candidate.current_cooldown > 0.0:
			candidates.append(candidate)
	candidates.sort_custom(func(a: ItemData, b: ItemData) -> bool:
		return a.current_cooldown > b.current_cooldown
	)
	if candidates.is_empty():
		return false
	_charge_player_item(candidates[0], seconds)
	return true

func _matches_player_item_selector(item: ItemData, selector: String) -> bool:
	if item == null or _is_player_item_destroyed(item):
		return false
	match selector:
		"any":
			return true
		"ammo":
			return item != null and item.has_ammo_limit()
		"aquatic":
			return _item_has_tag(item, "Aquatic")
		"friend":
			return _item_has_tag(item, "Friend")
		"large":
			return _item_size_matches(item, "large")
		"medium":
			return _item_size_matches(item, "medium")
		"small":
			return _item_size_matches(item, "small")
		"tool":
			return _item_has_tag(item, "Tool")
		"vehicle":
			return _item_has_tag(item, "Vehicle")
		"burn":
			return _is_burn_item(item)
		"heal":
			return _is_heal_item(item)
		"poison":
			return _is_poison_item(item)
		"regeneration":
			return _is_regen_item(item)
		"shield":
			return _is_shield_item(item)
		"weapon":
			return _is_weapon_item(item)
		_:
			return false

func _item_starts_flying(item: ItemData) -> bool:
	if item == null:
		return false
	var effect_text: String = item.source_effect_text.to_lower()
	return effect_text.contains("starts flying") or effect_text.contains("start flying")

func _count_player_items_matching(selector: String) -> int:
	if inventory == null:
		return 0
	var count: int = 0
	for candidate in inventory.items:
		if candidate is ItemData and _matches_player_item_selector(candidate as ItemData, selector):
			count += 1
	return count

func _has_exactly_one_player_item_matching(selector: String) -> bool:
	return _count_player_items_matching(selector) == 1

func _has_player_skill(skill_id: String) -> bool:
	return player_skill_map.has(skill_id)

func _get_player_skill_name(skill_id: String) -> String:
	if not _has_player_skill(skill_id):
		return skill_id
	return PlayerSkillCatalogClass.get_skill_display_name(player_skill_map[skill_id])

func _get_player_skill_value(skill_id: String, field: String = "values") -> float:
	if not _has_player_skill(skill_id):
		return 0.0
	return PlayerSkillCatalogClass.get_tier_value(player_skill_map[skill_id], field, 0.0)

func _increment_skill_counter(skill_id: String, amount: int = 1) -> int:
	var current_value: int = int(player_skill_counters.get(skill_id, 0))
	if amount != 0:
		player_skill_counters[skill_id] = current_value + amount
	return int(player_skill_counters.get(skill_id, current_value))

func _get_player_item_skill_damage_bonus(item: ItemData) -> int:
	if item == null or not _is_weapon_item(item):
		return 0
	var bonus: float = 0.0
	bonus += _get_player_skill_value("strength")
	if _is_weapon_item(item):
		bonus += _get_player_skill_value("augmented_weaponry")
		if _has_player_skill("all_talk") and game_manager != null and game_manager.selected_hero != null:
			if int(game_manager.get("player_health")) > int(game_manager.selected_hero.max_hp / 2.0):
				bonus += _get_player_skill_value("all_talk")
		if _has_player_skill("one_shot_one_kill") and _has_exactly_one_player_item_matching("weapon"):
			bonus += float(maxi(item.get_rarity_adjusted_damage(), 0)) * 2.0
	if _is_edge_weapon_item(item, true):
		bonus += _get_player_skill_value("left_handed")
	if _is_edge_weapon_item(item, false):
		bonus += _get_player_skill_value("right_handed")
	if _has_player_skill("power_broker") and game_manager != null:
		bonus += _get_player_skill_value("power_broker") * float(game_manager.get("income"))
	if _has_player_item("lockbox"):
		bonus += float(_get_total_player_item_combat_value("lockbox"))
	return int(round(bonus))

func _has_player_item(source_id: String) -> bool:
	if inventory == null:
		return false
	for item in inventory.items:
		if item != null and item.source_id == source_id and not _is_player_item_destroyed(item):
			return true
	return false

func _get_total_player_item_combat_value(source_id: String = "") -> int:
	if inventory == null:
		return 0
	var total: int = 0
	for item in inventory.items:
		if item == null or _is_player_item_destroyed(item):
			continue
		if not source_id.is_empty() and item.source_id != source_id:
			continue
		total += _get_player_item_combat_value(item)
	return total

func _get_player_item_combat_value(item: ItemData) -> int:
	if item == null:
		return 0
	var value: int = maxi(item.buy_price, 0)
	if _has_player_skill("trader"):
		value += int(round(_get_player_skill_value("trader")))
	if _has_player_skill("clean_storefront") and _get_edge_matching_player_item("any", true) == item:
		value += int(round(_get_player_skill_value("clean_storefront")))
	if _has_player_skill("master_salesman"):
		value = int(round(float(value) * _get_player_skill_value("master_salesman")))
	return value

func _apply_player_fight_win_value_effects() -> void:
	if inventory == null:
		return
	for item in inventory.items:
		if item != null and item.source_id == "lockbox":
			var gain: int = int(round(_get_rarity_value(item, [3, 6, 9], 3.0)))
			item.buy_price += gain
			_record_effect_trace({"kind": "item", "id": "lockbox"}, {"id": "lockbox_win_gain_value", "trigger": "on_win", "effect": {"type": "value_gain"}}, "on_win", float(gain), 1)

func _is_edge_weapon_item(item: ItemData, leftmost: bool) -> bool:
	if inventory == null or item == null or not _is_weapon_item(item):
		return false
	var edge_weapon: ItemData = _get_edge_matching_player_item("weapon", leftmost)
	return edge_weapon == item

func _is_edge_player_item(item: ItemData) -> bool:
	if inventory == null or item == null:
		return false
	return _get_edge_matching_player_item("any", true) == item or _get_edge_matching_player_item("any", false) == item

func _get_player_item_skill_shield_bonus(item: ItemData) -> int:
	if item == null or item.shield <= 0:
		return 0
	var hero: HeroData = null if game_manager == null else game_manager.selected_hero
	var bonus: float = 0.0 if hero == null else hero.skill_shield_bonus
	if _has_player_skill("prosperity"):
		bonus += _get_player_skill_value("prosperity") * float(_get_total_player_item_combat_value())
	return int(round(bonus))

func _get_player_item_skill_crit_bonus(item: ItemData) -> int:
	if item == null:
		return 0
	var bonus: float = 0.0
	if _has_player_skill("deadly_eye") and _is_weapon_item(item):
		bonus += _get_player_skill_value("deadly_eye")
	if _has_player_skill("critical_aid") and _is_heal_item(item):
		bonus += _get_player_skill_value("critical_aid")
	if _has_player_skill("flamedancer") and _is_burn_item(item):
		bonus += _get_player_skill_value("flamedancer")
	if _has_player_skill("arms_race"):
		bonus += _get_player_skill_value("arms_race") * float(_count_player_items_matching("weapon"))
	if _has_player_skill("dual_wield") and _count_player_items_matching("weapon") == 2:
		bonus += _get_player_skill_value("dual_wield")
	if _has_player_skill("the_right_tool") and not _matches_player_item_selector(item, "tool"):
		bonus += _get_player_skill_value("the_right_tool") * float(_count_player_items_matching("tool"))
	return int(round(bonus))

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

func _get_other_items_status_total(item: ItemData, status_key: String) -> float:
	if inventory == null or item == null:
		return 0.0
	var total: float = 0.0
	for candidate in inventory.items:
		if candidate == null or candidate == item:
			continue
		match status_key:
			EffectDefinitionClass.EFFECT_BURN:
				total += candidate.burn_damage + _get_item_runtime_bonus(candidate, EffectDefinitionClass.EFFECT_BURN)
			EffectDefinitionClass.EFFECT_POISON:
				total += candidate.poison_damage + _get_item_runtime_bonus(candidate, EffectDefinitionClass.EFFECT_POISON)
			EffectDefinitionClass.EFFECT_REGENERATION:
				total += candidate.regeneration + _get_item_runtime_bonus(candidate, EffectDefinitionClass.EFFECT_REGENERATION)
			EffectDefinitionClass.EFFECT_HEAL:
				total += float(candidate.heal) + _get_item_runtime_bonus(candidate, EffectDefinitionClass.EFFECT_HEAL)
			EffectDefinitionClass.EFFECT_DAMAGE:
				total += float(candidate.get_rarity_adjusted_damage()) + _get_item_runtime_bonus(candidate, EffectDefinitionClass.EFFECT_DAMAGE)
	return maxf(total, 0.0)

func _count_other_player_items_matching_tag(source_item: ItemData, tag: String) -> int:
	if inventory == null or tag.is_empty():
		return 0
	var count: int = 0
	for candidate in inventory.items:
		if candidate != null and candidate != source_item and _item_has_tag(candidate, tag):
			count += 1
	return count

func _count_adjacent_player_items_matching_any_tag(source_item: ItemData, tags: Array) -> int:
	if source_item == null or tags.is_empty():
		return 0
	var count: int = 0
	for adjacent in _get_adjacent_player_items(source_item):
		if adjacent == null:
			continue
		for tag_variant in tags:
			if _item_has_tag(adjacent, str(tag_variant)):
				count += 1
				break
	return count

func _count_other_player_items_matching_any_tag(source_item: ItemData, tags: Array) -> int:
	if inventory == null or tags.is_empty():
		return 0
	var count: int = 0
	for candidate in inventory.items:
		if candidate == null or candidate == source_item:
			continue
		if _item_has_any_tag(candidate, tags):
			count += 1
	return count

func _count_adjacent_player_items_matching_tag(source_item: ItemData, tag: String) -> int:
	if source_item == null or tag.is_empty():
		return 0
	var count: int = 0
	for adjacent in _get_adjacent_player_items(source_item):
		if adjacent != null and _item_has_tag(adjacent, tag):
			count += 1
	return count

func _has_player_item_size(size_name: String) -> bool:
	if inventory == null:
		return false
	for candidate in inventory.items:
		if candidate != null and _item_size_matches(candidate, size_name):
			return true
	return false

func _item_has_any_tag(item: ItemData, tags: Array) -> bool:
	if item == null:
		return false
	for tag_variant in tags:
		if _item_has_tag(item, str(tag_variant)):
			return true
	return false

func _get_weakest_weapon_damage() -> float:
	if inventory == null:
		return 0.0
	var weakest: float = INF
	for candidate in inventory.items:
		if candidate == null or not _is_weapon_item(candidate):
			continue
		var damage_value: float = float(candidate.get_rarity_adjusted_damage()) + _get_item_runtime_bonus(candidate, EffectDefinitionClass.EFFECT_DAMAGE)
		weakest = minf(weakest, damage_value)
	return 0.0 if weakest == INF else maxf(weakest, 0.0)

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
		if _is_monster_item_destroyed(index):
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
		var applied_seconds: float = seconds * (0.5 if _is_monster_item_flying(index) else 1.0)
		monster_item["current_cooldown"] = maxf(float(monster_item.get("current_cooldown", 0.0)) + applied_seconds, 0.0)
		applied += 1
	return applied

func _slow_player_items(count: int, seconds: float) -> int:
	if inventory == null or count <= 0 or seconds <= 0.0:
		return 0
	var candidates: Array[ItemData] = []
	for item in inventory.items:
		if item != null and not _is_player_item_destroyed(item) and item.cooldown > 0.0:
			candidates.append(item)
	candidates.sort_custom(func(a: ItemData, b: ItemData) -> bool:
		return a.current_cooldown > b.current_cooldown
	)
	var applied: int = 0
	for item in candidates:
		if applied >= count:
			break
		var applied_seconds: float = seconds * (0.5 if _is_player_item_flying(item) else 1.0)
		item.current_cooldown = maxf(item.current_cooldown + applied_seconds, 0.0)
		applied += 1
	return applied

func _haste_player_items(count: int, seconds: float, source_item: ItemData = null) -> int:
	if inventory == null or count <= 0 or seconds <= 0.0:
		return 0
	var candidates: Array[ItemData] = []
	for item in inventory.items:
		if item != null and item != source_item and not _is_player_item_destroyed(item) and item.cooldown > 0.0:
			candidates.append(item)
	candidates.sort_custom(func(a: ItemData, b: ItemData) -> bool:
		return a.current_cooldown > b.current_cooldown
	)
	var applied: int = 0
	for item in candidates:
		if applied >= count:
			break
		_charge_player_item(item, seconds)
		_handle_player_item_gained_haste(item, 1)
		applied += 1
	return applied

func _haste_monster_items(count: int, seconds: float, source_index: int = -1) -> int:
	if current_monster == null or count <= 0 or seconds <= 0.0:
		return 0
	var candidates: Array[int] = []
	for index in range(current_monster.monster_items.size()):
		if index == source_index or _is_monster_item_destroyed(index):
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
	if _has_player_skill("big_ego") and _is_weapon_item(item):
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

func _item_size_matches(item: ItemData, size_name: String) -> bool:
	if item == null:
		return false
	match size_name.to_lower():
		"small", "小":
			return item.get_slot_count() == 1
		"medium", "中":
			return item.get_slot_count() == 2
		"large", "大":
			return item.get_slot_count() == 3
		_:
			return false

func _is_poison_item(item: ItemData) -> bool:
	return item != null and (_item_has_tag(item, "Poison") or item.poison_damage > 0.0 or _get_item_runtime_bonus(item, "poison") > 0.0)

func _is_burn_item(item: ItemData) -> bool:
	return item != null and (_item_has_tag(item, "Burn") or item.burn_damage > 0.0 or _get_item_runtime_bonus(item, "burn") > 0.0)

func _is_heal_item(item: ItemData) -> bool:
	return item != null and (_item_has_tag(item, "Heal") or item.heal > 0 or _get_item_runtime_bonus(item, "heal") > 0.0)

func _is_regen_item(item: ItemData) -> bool:
	return item != null and (_item_has_tag(item, "Regen") or item.regeneration > 0.0 or _get_item_runtime_bonus(item, "regeneration") > 0.0)

func _is_shield_item(item: ItemData) -> bool:
	return item != null and (_item_has_tag(item, "Shield") or item.shield > 0 or _get_item_runtime_bonus(item, "shield") > 0.0)

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
		state["burn"] = _decay_burn_amount(burn_value)

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

func _decay_burn_amount(burn_value: float) -> float:
	var decayed: float = burn_value * 0.97
	return 0.0 if decayed < 0.001 else decayed

func _apply_status_damage(target: String, raw_damage: int, is_burn: bool) -> void:
	var damage: int = maxi(raw_damage, 0)
	if damage <= 0:
		return
	if target == "enemy":
		if is_burn:
			_apply_burn_damage_to_monster(damage)
		else:
			_damage_current_monster(damage, false)
		return

	if is_burn:
		_apply_burn_damage_to_player(damage)
	else:
		_damage_player(damage)

func _apply_burn_damage_to_monster(damage: int) -> void:
	if current_monster == null or not current_monster.is_alive() or damage <= 0:
		return
	if _has_no_damage_window("monster"):
		return
	var remaining_damage: int = damage
	if current_monster.current_shield > 0.0:
		var shield_spent: float = minf(current_monster.current_shield, float(damage) * 0.5)
		current_monster.current_shield = maxf(current_monster.current_shield - shield_spent, 0.0)
		remaining_damage = maxi(damage - int(floor(shield_spent * 2.0)), 0)
	if remaining_damage > 0:
		_damage_current_monster(remaining_damage, false)

func _apply_burn_damage_to_player(damage: int) -> void:
	if game_manager == null or damage <= 0:
		return
	if _has_no_damage_window("player"):
		return
	var remaining_damage: int = damage
	var hero: HeroData = null if game_manager.selected_hero == null else game_manager.selected_hero
	if hero != null and hero.current_shield > 0.0:
		var shield_spent: float = minf(hero.current_shield, float(damage) * 0.5)
		hero.remove_shield(shield_spent)
		remaining_damage = maxi(damage - int(floor(shield_spent * 2.0)), 0)
	if remaining_damage > 0:
		_damage_player(remaining_damage)

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
