extends Node

const BazaarContentClass = preload("res://scripts/data/bazaar_content.gd")
const ItemDataClass = preload("res://scripts/data/item_data.gd")
const LinearInventoryClass = preload("res://scripts/data/linear_inventory.gd")
const MonsterDataClass = preload("res://scripts/data/monster_data.gd")
const PlayerSkillCatalogClass = preload("res://scripts/data/player_skill_catalog.gd")

var _total: int = 0
var _passed: int = 0

func _ready() -> void:
	if not Engine.is_editor_hint():
		print("== tests/test_effect_dsl_runtime.gd ==")
		_run_tests()
		_print_summary()

func _run_tests() -> void:
	test_definition_anchors_cover_priority_slice()
	test_root_damage_trace_comes_from_dsl()
	test_listener_traces_cover_poison_charge_shield_and_haste()
	test_multicast_traces_execute_through_dsl()
	test_skill_trigger_traces_execute_through_dsl()
	test_phasec_battle_start_skills_execute_through_dsl()
	test_phasec_item_use_skills_execute_through_dsl()
	test_phasec_numeric_skills_affect_runtime_values()
	test_reload_and_unsupported_warnings_are_explicit()

func _battle_system() -> Node:
	return get_node("/root/BattleSystem")

func _game_manager() -> Node:
	return get_node("/root/GameManager")

func _create_item(item_id: String, rarity: int = BazaarContentClass.RARITY_BRONZE) -> ItemDataClass:
	var item: ItemDataClass = BazaarContentClass.create_item(item_id, rarity)
	_assert_true(item != null, "test setup creates %s" % item_id)
	return item

func _definition_ids(definitions: Array[Dictionary]) -> Array[String]:
	var ids: Array[String] = []
	for definition in definitions:
		ids.append(str(definition.get("id", "")))
	return ids

func _assert_has_definition(definitions: Array[Dictionary], definition_id: String, label: String) -> void:
	_assert_true(_definition_ids(definitions).has(definition_id), label)

func _set_ready(item: ItemDataClass) -> void:
	item.current_cooldown = 0.0

func _set_blocked(item: ItemDataClass) -> void:
	item.current_cooldown = 999.0

func _trace_has(definition_id: String) -> bool:
	for entry in _battle_system().call("get_effect_execution_trace"):
		if str(entry.get("definition_id", "")) == definition_id:
			return true
	return false

func _warnings() -> Array:
	return _battle_system().call("get_effect_warnings")

func _start_battle(hero_skills: Array, inv: LinearInventoryClass, monster: MonsterDataClass = null) -> MonsterDataClass:
	var hero = BazaarContentClass.create_mak_hero()
	hero.crit_chance = 0.0
	hero.skills = hero_skills.duplicate()
	var game_manager: Node = _game_manager()
	game_manager.call("reset_stats")
	game_manager.set("selected_hero", hero)
	game_manager.set("player_health", hero.max_hp)
	var battle_monster: MonsterDataClass = monster if monster != null else MonsterDataClass.new()
	if monster == null:
		battle_monster.monster_name = "Effect DSL Test"
		battle_monster.max_hp = 100
		battle_monster.current_hp = 100
	_battle_system().call("start_battle", battle_monster, inv)
	return battle_monster

func _assert_true(condition: bool, label: String) -> void:
	_total += 1
	if condition:
		_passed += 1
		print("PASS: %s" % label)
	else:
		push_error("FAIL: %s" % label)

func _assert_eq(actual, expected, label: String) -> void:
	_assert_true(actual == expected, "%s | expected=%s actual=%s" % [label, str(expected), str(actual)])

func _assert_float_eq(actual: float, expected: float, label: String, tolerance: float = 0.001) -> void:
	_assert_true(absf(actual - expected) <= tolerance, "%s | expected=%.3f actual=%.3f" % [label, expected, actual])

func _print_summary() -> void:
	print("SUMMARY: %d/%d passed" % [_passed, _total])
	get_tree().quit(1 if _passed < _total else 0)

func test_definition_anchors_cover_priority_slice() -> void:
	_assert_has_definition(_create_item("fang").effects, "fang_root_damage", "anchor fang_root_damage exists")
	_assert_has_definition(_create_item("silk_scarf").effects, "silk_scarf_root_shield", "anchor silk_scarf_root_shield exists")
	_assert_has_definition(_create_item("bluenanas").effects, "bluenanas_root_heal", "anchor bluenanas_root_heal exists")
	_assert_has_definition(_create_item("lighter").effects, "lighter_root_burn", "anchor lighter_root_burn exists")
	_assert_has_definition(_create_item("noxious_potion").effects, "noxious_potion_root_poison", "anchor noxious_potion_root_poison exists")
	_assert_has_definition(_create_item("quill_and_ink").effects, "quill_and_ink_root_regeneration", "anchor quill_and_ink_root_regeneration exists")
	_assert_has_definition(_create_item("smelling_salts").effects, "smelling_salts_root_slow", "anchor smelling_salts_root_slow exists")
	_assert_has_definition(_create_item("frost_potion", BazaarContentClass.RARITY_SILVER).effects, "frost_potion_root_freeze", "anchor frost_potion_root_freeze exists")
	_assert_has_definition(_create_item("energy_potion", BazaarContentClass.RARITY_SILVER).effects, "energy_potion_root_haste", "anchor energy_potion_root_haste exists")
	_assert_has_definition(_create_item("battery", BazaarContentClass.RARITY_BRONZE).effects, "battery_root_charge_left", "anchor battery_root_charge_left exists")
	_assert_has_definition(_create_item("infinite_potion", BazaarContentClass.RARITY_SILVER).effects, "infinite_potion_root_reload_self", "anchor infinite_potion_root_reload_self exists")
	_assert_has_definition(_create_item("venom").effects, "venom_on_left_weapon_poison", "anchor venom_on_left_weapon_poison exists")
	_assert_has_definition(_create_item("duct_tape").effects, "duct_tape_on_left_item_shield", "anchor duct_tape_on_left_item_shield exists")
	_assert_has_definition(_create_item("candles").effects, "candles_on_small_item_charge", "anchor candles_on_small_item_charge exists")
	_assert_has_definition(_create_item("quill_and_ink").effects, "quill_and_ink_no_other_weapon_multicast", "anchor quill_and_ink_no_other_weapon_multicast exists")
	_assert_has_definition(_create_item("aludel").effects, "aludel_adjacent_potion_multicast", "anchor aludel_adjacent_potion_multicast exists")
	_assert_has_definition(_create_item("barbed_claws").effects, "barbed_claws_self_poison_multicast", "anchor barbed_claws_self_poison_multicast exists")
	_assert_has_definition(_create_item("barbed_claws").effects, "barbed_claws_enemy_poison_multicast", "anchor barbed_claws_enemy_poison_multicast exists")
	_assert_has_definition(PlayerSkillCatalogClass.get_effect_definitions({"id": "heated_shells", "tier": "Silver"}), "heated_shells_on_ammo_burn", "anchor heated_shells_on_ammo_burn exists")
	_assert_has_definition(PlayerSkillCatalogClass.get_effect_definitions({"id": "paralytic_poison", "tier": "Silver"}), "paralytic_poison_on_first_poison_freeze", "anchor paralytic_poison_on_first_poison_freeze exists")
	_assert_has_definition(PlayerSkillCatalogClass.get_effect_definitions({"id": "slow_burn", "tier": "Gold"}), "slow_burn_on_slow_charge", "anchor slow_burn_on_slow_charge exists")

func test_root_damage_trace_comes_from_dsl() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var fang: ItemDataClass = _create_item("fang")
	_assert_true(inv.place_item(fang, 0), "places Fang for root damage trace")
	var monster: MonsterDataClass = _start_battle([], inv)
	_set_ready(fang)

	_battle_system().call("execute_battle_tick", 0.0)
	_assert_eq(monster.current_hp, 95, "fang root damage still resolves in combat")
	_assert_true(_trace_has("fang_root_damage"), "fang root damage emits a DSL trace entry")

	_battle_system().call("end_battle")

func test_listener_traces_cover_poison_charge_shield_and_haste() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var fang: ItemDataClass = _create_item("fang")
	var venom: ItemDataClass = _create_item("venom")
	var candles: ItemDataClass = _create_item("candles")
	_assert_true(inv.place_item(fang, 0), "places Fang for listener trace")
	_assert_true(inv.place_item(venom, 1), "places Venom for listener trace")
	_assert_true(inv.place_item(candles, 2), "places Candles for listener trace")
	_start_battle([], inv)
	_set_ready(fang)
	_set_blocked(venom)

	_battle_system().call("execute_battle_tick", 0.0)
	_assert_true(_trace_has("venom_on_left_weapon_poison"), "Venom listener executes through the DSL")
	_assert_true(_trace_has("candles_on_small_item_charge"), "Candles listener executes through the DSL")
	_assert_float_eq(float(_battle_system().call("get_status_totals", "enemy").get("poison", 0.0)), 2.0, "Venom still poisons after a left weapon use")
	_assert_float_eq(candles.current_cooldown, 7.0, "Candles still charges itself after a small item use")
	_battle_system().call("end_battle")

	var shield_inv: LinearInventoryClass = LinearInventoryClass.new()
	var shield_fang: ItemDataClass = _create_item("fang")
	var duct_tape: ItemDataClass = _create_item("duct_tape")
	_assert_true(shield_inv.place_item(shield_fang, 0), "places Fang left of Duct Tape")
	_assert_true(shield_inv.place_item(duct_tape, 1), "places Duct Tape for shield trace")
	_start_battle([], shield_inv)
	_set_ready(shield_fang)
	_set_blocked(duct_tape)

	_battle_system().call("execute_battle_tick", 0.0)
	_assert_true(_trace_has("duct_tape_on_left_item_shield"), "Duct Tape shield listener executes through the DSL")
	_battle_system().call("end_battle")

	var haste_inv: LinearInventoryClass = LinearInventoryClass.new()
	var haste_target: ItemDataClass = _create_item("fang")
	var smelling_salts: ItemDataClass = _create_item("smelling_salts")
	var filler: ItemDataClass = _create_item("lighter")
	_assert_true(haste_inv.place_item(haste_target, 0), "places left haste target")
	_assert_true(haste_inv.place_item(smelling_salts, 1), "places Smelling Salts for haste trace")
	_assert_true(haste_inv.place_item(filler, 2), "places filler item")
	var haste_monster: MonsterDataClass = MonsterDataClass.new()
	haste_monster.monster_name = "Haste Trace"
	haste_monster.max_hp = 100
	haste_monster.current_hp = 100
	haste_monster.monster_items = [{"name": "Target Dummy", "damage": 10, "cooldown": 4.0}]
	_start_battle([], haste_inv, haste_monster)
	haste_target.current_cooldown = 5.0
	_set_ready(smelling_salts)
	_set_blocked(filler)

	_battle_system().call("execute_battle_tick", 0.0)
	_assert_true(_trace_has("smelling_salts_on_slow_haste_left"), "Smelling Salts haste listener executes through the DSL")
	_assert_float_eq(haste_target.current_cooldown, 4.0, "Smelling Salts still hastes the item to its left")
	_battle_system().call("end_battle")

func test_multicast_traces_execute_through_dsl() -> void:
	var aludel_inv: LinearInventoryClass = LinearInventoryClass.new()
	var aludel: ItemDataClass = _create_item("aludel")
	var adjacent_potion: ItemDataClass = _create_item("noxious_potion")
	_assert_true(aludel_inv.place_item(aludel, 0), "places Aludel for multicast trace")
	_assert_true(aludel_inv.place_item(adjacent_potion, 2), "places adjacent Potion for Aludel")
	_start_battle([], aludel_inv)
	_set_ready(aludel)
	_set_blocked(adjacent_potion)

	_battle_system().call("execute_battle_tick", 0.0)
	_assert_true(_trace_has("aludel_adjacent_potion_multicast"), "Aludel multicast condition is evaluated through the DSL")
	_assert_float_eq(float(_battle_system().call("get_status_totals", "enemy").get("poison", 0.0)), 8.0, "Aludel still multicasts for an adjacent Potion")
	_battle_system().call("end_battle")

	var claws_inv: LinearInventoryClass = LinearInventoryClass.new()
	var barbed_claws: ItemDataClass = _create_item("barbed_claws")
	_assert_true(claws_inv.place_item(barbed_claws, 0), "places Barbed Claws for multicast trace")
	var monster: MonsterDataClass = _start_battle([], claws_inv)
	_game_manager().get("selected_hero").crit_chance = 0.0
	_battle_system().call("_apply_status_effect", {"type": "poison", "value": 1.0, "target": "self", "item_name": "Trace"})
	_battle_system().call("_apply_status_effect", {"type": "poison", "value": 1.0, "target": "enemy", "item_name": "Trace"})
	_set_ready(barbed_claws)

	_battle_system().call("execute_battle_tick", 0.0)
	_assert_true(_trace_has("barbed_claws_self_poison_multicast"), "Barbed Claws self-poison multicast executes through the DSL")
	_assert_true(_trace_has("barbed_claws_enemy_poison_multicast"), "Barbed Claws enemy-poison multicast executes through the DSL")
	_assert_eq(monster.current_hp, 85, "Barbed Claws still multicasts once per poisoned player")
	_battle_system().call("end_battle")

func test_skill_trigger_traces_execute_through_dsl() -> void:
	var heated_inv: LinearInventoryClass = LinearInventoryClass.new()
	var fire_potion: ItemDataClass = _create_item("fire_potion")
	_assert_true(heated_inv.place_item(fire_potion, 0), "places Fire Potion for Heated Shells")
	_start_battle(["heated_shells"], heated_inv)
	_set_ready(fire_potion)

	_battle_system().call("execute_battle_tick", 0.0)
	_assert_true(_trace_has("heated_shells_on_ammo_burn"), "Heated Shells trigger executes through the DSL")
	_battle_system().call("end_battle")

	var poison_inv: LinearInventoryClass = LinearInventoryClass.new()
	var noxious_potion: ItemDataClass = _create_item("noxious_potion")
	_assert_true(poison_inv.place_item(noxious_potion, 0), "places Noxious Potion for Paralytic Poison")
	var freeze_monster: MonsterDataClass = MonsterDataClass.new()
	freeze_monster.monster_name = "Freeze Trace"
	freeze_monster.max_hp = 100
	freeze_monster.current_hp = 100
	freeze_monster.monster_items = [{"name": "Target Dummy", "damage": 10, "cooldown": 4.0}]
	_start_battle(["paralytic_poison"], poison_inv, freeze_monster)
	_set_ready(noxious_potion)

	_battle_system().call("execute_battle_tick", 0.0)
	_assert_true(_trace_has("paralytic_poison_on_first_poison_freeze"), "Paralytic Poison executes through the DSL")
	_assert_float_eq(float(freeze_monster.monster_items[0].get("current_cooldown", 0.0)), 6.0, "Paralytic Poison still freezes an enemy item on first poison")
	_battle_system().call("end_battle")

	var slow_inv: LinearInventoryClass = LinearInventoryClass.new()
	var slow_source: ItemDataClass = _create_item("smelling_salts")
	var slow_target: ItemDataClass = _create_item("lighter")
	_assert_true(slow_inv.place_item(slow_source, 0), "places Smelling Salts for Slow Burn")
	_assert_true(slow_inv.place_item(slow_target, 1), "places Lighter for Slow Burn")
	var slow_monster: MonsterDataClass = MonsterDataClass.new()
	slow_monster.monster_name = "Slow Burn Trace"
	slow_monster.max_hp = 100
	slow_monster.current_hp = 100
	slow_monster.monster_items = [{"name": "Target Dummy", "damage": 10, "cooldown": 4.0}]
	_start_battle(["slow_burn"], slow_inv, slow_monster)
	_set_ready(slow_source)
	slow_target.current_cooldown = 4.0

	_battle_system().call("execute_battle_tick", 0.0)
	_assert_true(_trace_has("slow_burn_on_slow_charge"), "Slow Burn executes through the DSL")
	_assert_float_eq(slow_target.current_cooldown, 3.0, "Slow Burn still charges a Burn item after a Slow trigger")
	_battle_system().call("end_battle")

func test_phasec_battle_start_skills_execute_through_dsl() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	_start_battle(["lash_out", "insect_bite", "regenerative", "valley_fever"], inv)

	_assert_true(_trace_has("lash_out_battle_start_poison"), "Lash Out battle-start poison executes through DSL")
	_assert_true(_trace_has("insect_bite_battle_start_self_poison"), "Insect Bite battle-start self poison executes through DSL")
	_assert_true(_trace_has("regenerative_battle_start_regeneration"), "Regenerative battle-start regen executes through DSL")
	_assert_true(_trace_has("valley_fever_battle_start_self_burn"), "Valley Fever battle-start self burn executes through DSL")
	_assert_float_eq(float(_battle_system().call("get_status_totals", "enemy").get("poison", 0.0)), 3.0, "Lash Out applies enemy poison at battle start")
	_assert_float_eq(float(_battle_system().call("get_status_totals", "self").get("poison", 0.0)), 2.0, "Insect Bite applies self poison at battle start")
	_assert_float_eq(float(_battle_system().call("get_status_totals", "self").get("regeneration", 0.0)), 10.0, "Regenerative applies self regeneration at battle start")
	_assert_float_eq(float(_battle_system().call("get_status_totals", "self").get("burn", 0.0)), 2.0, "Valley Fever applies self burn at battle start")
	_battle_system().call("end_battle")

func test_phasec_item_use_skills_execute_through_dsl() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var fang: ItemDataClass = _create_item("fang")
	_assert_true(inv.place_item(fang, 0), "places Fang for PhaseC item-use skill triggers")
	var monster: MonsterDataClass = MonsterDataClass.new()
	monster.monster_name = "Skill Trigger Trace"
	monster.max_hp = 100
	monster.current_hp = 100
	monster.monster_items = [{"name": "Target Dummy", "damage": 10, "cooldown": 4.0}]
	_start_battle(["small_refresh", "unwavering", "rust"], inv, monster)
	var hero = _game_manager().get("selected_hero")
	_game_manager().set("player_health", hero.max_hp - 20)
	_set_ready(fang)

	_battle_system().call("execute_battle_tick", 0.0)
	_assert_true(_trace_has("small_refresh_on_small_item_heal"), "Small Refresh item-use heal executes through DSL")
	_assert_true(_trace_has("unwavering_on_item_used_shield"), "Unwavering item-use shield executes through DSL")
	_assert_true(_trace_has("rust_first_item_slow_enemy"), "Rust first-use slow executes through DSL")
	_assert_eq(_game_manager().get("player_health"), hero.max_hp - 15, "Small Refresh heals after a small item use")
	_assert_float_eq(hero.current_shield, 20.0, "Unwavering grants shield after item use")
	_assert_float_eq(float(monster.monster_items[0].get("current_cooldown", 0.0)), 7.0, "Rust slows an enemy item on first item use")
	_battle_system().call("end_battle")

func test_phasec_numeric_skills_affect_runtime_values() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var fire_potion: ItemDataClass = _create_item("fire_potion")
	var fang: ItemDataClass = _create_item("fang")
	_assert_true(inv.place_item(fire_potion, 0), "places Fire Potion for ammo skill runtime")
	_assert_true(inv.place_item(fang, 1), "places Fang for damage skill runtime")
	_start_battle(["gunner", "ammo_stash", "strength", "left_handed", "right_handed"], inv)

	var base_ammo: int = fire_potion.ammo
	_assert_eq(_battle_system().call("_get_player_item_effective_max_ammo", fire_potion), base_ammo + 2, "Gunner and Ammo Stash increase max ammo")
	_assert_eq(_battle_system().call("_get_player_item_skill_damage_bonus", fang), 50, "Strength and edge-handed skills add weapon damage")
	_battle_system().call("end_battle")

func test_reload_and_unsupported_warnings_are_explicit() -> void:
	var reload_inv: LinearInventoryClass = LinearInventoryClass.new()
	var infinite_potion: ItemDataClass = _create_item("infinite_potion", BazaarContentClass.RARITY_SILVER)
	_assert_true(reload_inv.place_item(infinite_potion, 0), "places Infinite Potion for reload trace")
	_start_battle([], reload_inv)
	_set_ready(infinite_potion)
	_assert_eq(infinite_potion.get_current_ammo(), 1, "Infinite Potion starts loaded")

	_battle_system().call("execute_battle_tick", 0.0)
	_assert_true(_trace_has("infinite_potion_root_reload_self"), "Infinite Potion reload executes through the DSL")
	_assert_eq(infinite_potion.get_current_ammo(), 1, "Infinite Potion reloads itself after use")
	_battle_system().call("end_battle")

	var warning_inv: LinearInventoryClass = LinearInventoryClass.new()
	var runic_daggers: ItemDataClass = _create_item("runic_daggers")
	_assert_true(warning_inv.place_item(runic_daggers, 0), "places Runic Daggers for warning trace")
	_start_battle([], warning_inv)
	_assert_true(_warnings().has("unsupported_item_effect:runic_daggers:multicast"), "unsupported multicast coverage is explicit in warnings")
	_battle_system().call("end_battle")
