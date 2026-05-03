extends Node

const BazaarContentClass = preload("res://scripts/data/bazaar_content.gd")
const ItemDataClass = preload("res://scripts/data/item_data.gd")
const LinearInventoryClass = preload("res://scripts/data/linear_inventory.gd")
const MonsterDataClass = preload("res://scripts/data/monster_data.gd")

var _total: int = 0
var _passed: int = 0

func _ready() -> void:
	if not Engine.is_editor_hint():
		print("== tests/test_player_skill_integration.gd ==")
		_run_tests()
		_print_summary()

func _run_tests() -> void:
	test_battle_system_uses_selected_hero_skill_set()
	test_deadly_eye_adds_weapon_crit_bonus()
	test_strength_and_edge_weapon_skills_add_damage_bonus()
	test_start_skills_add_poison_and_regeneration_item_bonuses()
	test_heated_shells_adds_burn_when_ammo_item_is_used()
	test_lash_out_and_regenerative_apply_battle_start_statuses()
	test_paralytic_poison_freezes_enemy_item_on_first_poison()
	test_slow_burn_charges_a_burn_item_when_you_slow()
	test_rush_and_pyromania_trigger_through_effect_dsl()
	test_phasep2_edge_item_and_passive_skill_bonuses()
	test_phasep2_status_runtime_bonus_skills()
	test_phasep2_trigger_skills_execute_through_dsl()
	test_phase90_numeric_passive_skill_bonuses()
	test_phase90_source_and_adjacent_trigger_skills_execute_through_dsl()
	test_phase90_size_and_tag_selector_trigger_skills_execute()
	test_phase90_status_chain_trigger_skills_execute()

func _battle_system() -> Node:
	return get_node("/root/BattleSystem")

func _game_manager() -> Node:
	return get_node("/root/GameManager")

func _create_item(item_id: String, rarity: int = BazaarContentClass.RARITY_BRONZE) -> ItemDataClass:
	var item: ItemDataClass = BazaarContentClass.create_item(item_id, rarity)
	_assert_true(item != null, "test setup creates %s" % item_id)
	return item

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
		battle_monster.monster_name = "Skill Test"
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

func _trace_has(definition_id: String) -> bool:
	for entry in _battle_system().call("get_effect_execution_trace"):
		if str(entry.get("definition_id", "")) == definition_id:
			return true
	return false

func _print_summary() -> void:
	print("SUMMARY: %d/%d passed" % [_passed, _total])
	get_tree().quit(1 if _passed < _total else 0)

func test_battle_system_uses_selected_hero_skill_set() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	_start_battle([], inv)
	var skill_manager = _battle_system().get("skill_manager")
	_assert_eq(skill_manager.get_skill_count(), 0, "battle system no longer auto-equips config skills when hero has none")
	_battle_system().call("end_battle")

func test_deadly_eye_adds_weapon_crit_bonus() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var fang: ItemDataClass = _create_item("fang")
	var med_kit: ItemDataClass = _create_item("med_kit")
	_assert_true(inv.place_item(fang, 0), "places Fang")
	_assert_true(inv.place_item(med_kit, 1), "places Med Kit")
	_start_battle([{"id": "deadly_eye", "tier": "Bronze"}], inv)

	var weapon_bonus: int = _battle_system().call("_get_player_item_skill_crit_bonus", fang)
	var support_bonus: int = _battle_system().call("_get_player_item_skill_crit_bonus", med_kit)
	var weapon_crit_rate: float = _battle_system().call("_get_player_item_crit_rate", fang, 0.05)
	var support_crit_rate: float = _battle_system().call("_get_player_item_crit_rate", med_kit, 0.05)

	_assert_eq(weapon_bonus, 5, "Deadly Eye grants a non-zero crit bonus to weapons")
	_assert_eq(support_bonus, 0, "Deadly Eye does not buff non-weapon crit rate")
	_assert_float_eq(weapon_crit_rate, 0.10, "Deadly Eye weapon crit rate stacks from the Bronze tier value")
	_assert_float_eq(support_crit_rate, 0.05, "Deadly Eye leaves non-weapon crit rate unchanged")
	_battle_system().call("end_battle")

func test_strength_and_edge_weapon_skills_add_damage_bonus() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var left_fang: ItemDataClass = _create_item("fang")
	var right_fang: ItemDataClass = _create_item("basilisk_fang", BazaarContentClass.RARITY_GOLD)
	_assert_true(inv.place_item(left_fang, 0), "places left weapon")
	_assert_true(inv.place_item(right_fang, 1), "places right weapon")
	_start_battle([
		{"id": "strength", "tier": "Bronze"},
		{"id": "left_handed", "tier": "Bronze"},
		{"id": "right_handed", "tier": "Bronze"},
	], inv)

	_assert_eq(_battle_system().call("_get_player_item_skill_damage_bonus", left_fang), 30, "Strength plus Left Handed buff the leftmost weapon")
	_assert_eq(_battle_system().call("_get_player_item_skill_damage_bonus", right_fang), 30, "Strength plus Right Handed buff the rightmost weapon")
	_battle_system().call("end_battle")

func test_start_skills_add_poison_and_regeneration_item_bonuses() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var noxious_potion: ItemDataClass = _create_item("noxious_potion")
	var quill_and_ink: ItemDataClass = _create_item("quill_and_ink")
	_assert_true(inv.place_item(noxious_potion, 0), "places Poison item")
	_assert_true(inv.place_item(quill_and_ink, 1), "places Regeneration item")
	_start_battle([
		{"id": "initial_dose", "tier": "Bronze"},
		{"id": "vital_reserve", "tier": "Bronze"},
	], inv)

	_assert_float_eq(_battle_system().call("_get_item_runtime_bonus", noxious_potion, "poison"), 2.0, "Initial Dose buffs the leftmost Poison item at battle start")
	_assert_float_eq(_battle_system().call("_get_item_runtime_bonus", quill_and_ink, "regeneration"), 2.0, "Vital Reserve buffs the rightmost Regeneration item at battle start")
	_battle_system().call("end_battle")

func test_heated_shells_adds_burn_when_ammo_item_is_used() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var fire_potion: ItemDataClass = _create_item("fire_potion")
	_assert_true(inv.place_item(fire_potion, 0), "places Fire Potion")
	var monster: MonsterDataClass = _start_battle(["heated_shells"], inv)
	fire_potion.current_cooldown = 0.0

	_battle_system().call("execute_battle_tick", 0.5)
	var enemy_status: Dictionary = _battle_system().call("get_status_totals", "enemy")
	_assert_float_eq(float(enemy_status.get("burn", 0.0)), 7.0, "Heated Shells adds extra burn before the first burn decay tick")
	_assert_eq(monster.current_hp, 92, "burn damage is processed during the same combat tick")
	_battle_system().call("end_battle")

func test_lash_out_and_regenerative_apply_battle_start_statuses() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	_start_battle(["lash_out", "regenerative"], inv)
	var enemy_status: Dictionary = _battle_system().call("get_status_totals", "enemy")
	var player_status: Dictionary = _battle_system().call("get_status_totals", "self")
	_assert_float_eq(float(enemy_status.get("poison", 0.0)), 3.0, "Lash Out applies enemy Poison at battle start")
	_assert_float_eq(float(player_status.get("regeneration", 0.0)), 10.0, "Regenerative applies self Regeneration at battle start")
	_assert_true(_trace_has("lash_out_battle_start_poison"), "Lash Out battle-start trigger executes through the DSL")
	_assert_true(_trace_has("regenerative_battle_start_regeneration"), "Regenerative battle-start trigger executes through the DSL")
	_battle_system().call("end_battle")

func test_paralytic_poison_freezes_enemy_item_on_first_poison() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var poison_item: ItemDataClass = _create_item("noxious_potion")
	_assert_true(inv.place_item(poison_item, 0), "places Noxious Potion")
	var monster: MonsterDataClass = MonsterDataClass.new()
	monster.monster_name = "Freeze Target"
	monster.max_hp = 100
	monster.current_hp = 100
	monster.monster_items = [
		{"name": "Target Dummy", "damage": 10, "cooldown": 4.0},
	]
	_start_battle(["paralytic_poison"], inv, monster)
	poison_item.current_cooldown = 0.0

	_battle_system().call("execute_battle_tick", 0.5)
	_assert_float_eq(float(monster.monster_items[0].get("current_cooldown", 0.0)), 6.0, "Paralytic Poison freezes one enemy item on first poison trigger")
	_battle_system().call("end_battle")

func test_slow_burn_charges_a_burn_item_when_you_slow() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var smelling_salts: ItemDataClass = _create_item("smelling_salts")
	var lighter: ItemDataClass = _create_item("lighter")
	_assert_true(inv.place_item(smelling_salts, 0), "places Smelling Salts")
	_assert_true(inv.place_item(lighter, 1), "places Lighter")
	var monster: MonsterDataClass = MonsterDataClass.new()
	monster.monster_name = "Slow Target"
	monster.max_hp = 100
	monster.current_hp = 100
	monster.monster_items = [
		{"name": "Target Dummy", "damage": 10, "cooldown": 4.0},
	]
	_start_battle(["slow_burn"], inv, monster)
	smelling_salts.current_cooldown = 0.0
	lighter.current_cooldown = 4.0

	_battle_system().call("execute_battle_tick", 0.5)
	_assert_float_eq(lighter.current_cooldown, 3.0, "Slow Burn charges a Burn item after a Slow trigger")
	_battle_system().call("end_battle")

func test_rush_and_pyromania_trigger_through_effect_dsl() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var fang: ItemDataClass = _create_item("fang")
	var large_weapon: ItemDataClass = _create_item("runic_great_axe", BazaarContentClass.RARITY_SILVER)
	_assert_true(inv.place_item(fang, 0), "places lower-cooldown Weapon decoy")
	_assert_true(inv.place_item(large_weapon, 1), "places Large Weapon item for Rush and Pyromania")
	_start_battle(["rush", "pyromania"], inv)
	fang.current_cooldown = 5.0
	large_weapon.current_cooldown = 0.0

	_battle_system().call("execute_battle_tick", 0.0)
	var enemy_status: Dictionary = _battle_system().call("get_status_totals", "enemy")
	_assert_float_eq(large_weapon.current_cooldown, 8.0, "Rush hastes the highest-cooldown Weapon after the first item use")
	_assert_float_eq(float(enemy_status.get("burn", 0.0)), 10.0, "Pyromania burns when a Large item is used")
	_assert_true(_trace_has("rush_first_item_haste_weapon"), "Rush trigger executes through the DSL")
	_assert_true(_trace_has("pyromania_on_large_item_burn"), "Pyromania trigger executes through the DSL")
	_battle_system().call("end_battle")

func test_phasep2_edge_item_and_passive_skill_bonuses() -> void:
	var start_bonus_inv: LinearInventoryClass = LinearInventoryClass.new()
	var left_heal_item: ItemDataClass = _create_item("bandages")
	var lighter: ItemDataClass = _create_item("lighter")
	var right_heal_item: ItemDataClass = _create_item("bluenanas")
	_assert_true(start_bonus_inv.place_item(left_heal_item, 0), "places left heal item for PhaseP2 start bonuses")
	_assert_true(start_bonus_inv.place_item(lighter, 1), "places burn item for PhaseP2 start bonuses")
	_assert_true(start_bonus_inv.place_item(right_heal_item, 2), "places right heal item for PhaseP2 start bonuses")
	_start_battle(["first_responder", "follow_up_care", "final_flame"], start_bonus_inv)
	_assert_float_eq(_battle_system().call("_get_item_runtime_bonus", left_heal_item, "heal"), 20.0, "First Responder buffs the leftmost Heal item")
	_assert_float_eq(_battle_system().call("_get_item_runtime_bonus", right_heal_item, "heal"), 20.0, "Follow-Up Care buffs the rightmost Heal item")
	_assert_float_eq(_battle_system().call("_get_item_runtime_bonus", lighter, "burn"), 2.0, "Final Flame buffs the rightmost Burn item")
	_battle_system().call("end_battle")

	var shield_inv: LinearInventoryClass = LinearInventoryClass.new()
	var silk_scarf: ItemDataClass = _create_item("silk_scarf")
	_assert_true(shield_inv.place_item(silk_scarf, 0), "places left shield item for Frontal Shielding")
	_start_battle(["frontal_shielding"], shield_inv)
	_assert_float_eq(_battle_system().call("_get_item_runtime_bonus", silk_scarf, "shield"), 20.0, "Frontal Shielding buffs the leftmost Shield item")
	_battle_system().call("end_battle")

	var passive_inv: LinearInventoryClass = LinearInventoryClass.new()
	var heal_item: ItemDataClass = _create_item("bluenanas")
	var burn_item: ItemDataClass = _create_item("lighter")
	var lifesteal_weapon: ItemDataClass = _create_item("fang", BazaarContentClass.RARITY_DIAMOND)
	_assert_true(passive_inv.place_item(heal_item, 0), "places Heal item for Critical Aid")
	_assert_true(passive_inv.place_item(burn_item, 1), "places Burn item for Flamedancer")
	_assert_true(passive_inv.place_item(lifesteal_weapon, 2), "places Weapon for Big Ego and cooldown passives")
	_start_battle(["critical_aid", "flamedancer", "big_ego", "vengeance", "diamond_fangs"], passive_inv)
	_assert_eq(_battle_system().call("_get_player_item_skill_crit_bonus", heal_item), 5, "Critical Aid grants crit to Heal items")
	_assert_eq(_battle_system().call("_get_player_item_skill_crit_bonus", burn_item), 5, "Flamedancer grants crit to Burn items")
	_assert_true(_battle_system().call("_item_has_lifesteal", lifesteal_weapon), "Big Ego grants Lifesteal to Weapons")
	var expected_cooldown: float = lifesteal_weapon.cooldown * 0.95 * 0.80
	_assert_float_eq(_battle_system().call("_get_player_item_effective_cooldown", lifesteal_weapon), expected_cooldown, "Vengeance and Diamond Fangs reduce edge Diamond item cooldown")
	_game_manager().set("player_health", _game_manager().get("selected_hero").max_hp - 25)
	lifesteal_weapon.current_cooldown = 0.0
	_battle_system().call("execute_battle_tick", 0.0)
	_assert_eq(_game_manager().get("player_health"), _game_manager().get("selected_hero").max_hp - 5, "Big Ego lifesteal heals after weapon damage")
	_battle_system().call("end_battle")

func test_phasep2_status_runtime_bonus_skills() -> void:
	var poison_inv: LinearInventoryClass = LinearInventoryClass.new()
	var poison_item: ItemDataClass = _create_item("noxious_potion")
	var poison_target: ItemDataClass = _create_item("fang")
	_assert_true(poison_inv.place_item(poison_item, 0), "places Poison item for Exposing Toxins")
	_assert_true(poison_inv.place_item(poison_target, 1), "places target item for Exposing Toxins")
	_start_battle(["exposing_toxins"], poison_inv)
	poison_item.current_cooldown = 0.0
	_battle_system().call("execute_battle_tick", 0.0)
	_assert_float_eq(_battle_system().call("_get_item_runtime_bonus", poison_target, "crit_rate"), 1.0, "Exposing Toxins grants crit rate after Poison")
	_battle_system().call("end_battle")

	var burn_inv: LinearInventoryClass = LinearInventoryClass.new()
	var burn_source: ItemDataClass = _create_item("lighter")
	var burn_weapon: ItemDataClass = _create_item("fang")
	_assert_true(burn_inv.place_item(burn_source, 0), "places Burn source for Burning Rage")
	_assert_true(burn_inv.place_item(burn_weapon, 1), "places Weapon target for Burning Rage")
	_start_battle(["burning_rage"], burn_inv)
	burn_source.current_cooldown = 0.0
	_battle_system().call("execute_battle_tick", 0.0)
	_assert_float_eq(_battle_system().call("_get_item_runtime_bonus", burn_weapon, "damage"), 2.0, "Burning Rage grants weapon damage after Burn")
	_battle_system().call("end_battle")

	var heal_inv: LinearInventoryClass = LinearInventoryClass.new()
	var heal_source: ItemDataClass = _create_item("bluenanas")
	var shield_target: ItemDataClass = _create_item("silk_scarf")
	_assert_true(heal_inv.place_item(heal_source, 0), "places Heal source for Extreme Comfort")
	_assert_true(heal_inv.place_item(shield_target, 1), "places Shield target for Extreme Comfort")
	_start_battle(["extreme_comfort"], heal_inv)
	heal_source.current_cooldown = 0.0
	_battle_system().call("execute_battle_tick", 0.0)
	_assert_float_eq(_battle_system().call("_get_item_runtime_bonus", shield_target, "shield"), 1.0, "Extreme Comfort grants shield bonus after Heal")
	_battle_system().call("end_battle")

func test_phasep2_trigger_skills_execute_through_dsl() -> void:
	var battle_start_inv: LinearInventoryClass = LinearInventoryClass.new()
	_start_battle(["firestarter", "heat_lover"], battle_start_inv)
	_assert_true(_trace_has("firestarter_battle_start_enemy_burn"), "Firestarter battle-start burn executes through the DSL")
	_assert_true(_trace_has("heat_lover_on_burn_regeneration"), "Heat Lover reacts to Burn through the DSL")
	_assert_float_eq(float(_battle_system().call("get_status_totals", "enemy").get("burn", 0.0)), 17.0, "Firestarter applies enemy Burn at battle start")
	_assert_float_eq(float(_battle_system().call("get_status_totals", "self").get("regeneration", 0.0)), 2.0, "Heat Lover gains Regeneration after Burn")
	_battle_system().call("end_battle")

	var heal_trigger_inv: LinearInventoryClass = LinearInventoryClass.new()
	var healer: ItemDataClass = _create_item("bluenanas")
	var poison_target: ItemDataClass = _create_item("noxious_potion")
	_assert_true(heal_trigger_inv.place_item(healer, 0), "places Heal item for Equivalent Exchange")
	_assert_true(heal_trigger_inv.place_item(poison_target, 1), "places Poison item for Equivalent Exchange")
	_start_battle(["equivalent_exchange"], heal_trigger_inv)
	healer.current_cooldown = 0.0
	poison_target.current_cooldown = 4.0
	_battle_system().call("execute_battle_tick", 0.0)
	_assert_true(_trace_has("equivalent_exchange_on_heal_charge_poison_item"), "Equivalent Exchange executes through the DSL")
	_assert_float_eq(poison_target.current_cooldown, 3.0, "Equivalent Exchange charges a Poison item after Heal")
	_battle_system().call("end_battle")

	var crit_inv: LinearInventoryClass = LinearInventoryClass.new()
	var crit_source: ItemDataClass = _create_item("fang")
	var crit_target: ItemDataClass = _create_item("lighter")
	_assert_true(crit_inv.place_item(crit_source, 0), "places crit source for Cosmic Wind")
	_assert_true(crit_inv.place_item(crit_target, 1), "places haste target for Cosmic Wind")
	_start_battle(["cosmic_wind"], crit_inv)
	_game_manager().get("selected_hero").crit_chance = 1.0
	crit_source.current_cooldown = 0.0
	crit_target.current_cooldown = 7.0
	_battle_system().call("execute_battle_tick", 0.0)
	_assert_true(_trace_has("cosmic_wind_on_crit_haste_item"), "Cosmic Wind executes through the DSL")
	_assert_float_eq(crit_target.current_cooldown, 6.0, "Cosmic Wind hastes an item after a crit")
	_battle_system().call("end_battle")

	var shield_inv: LinearInventoryClass = LinearInventoryClass.new()
	var shield_source: ItemDataClass = _create_item("silk_scarf")
	_assert_true(shield_inv.place_item(shield_source, 0), "places shield source for Cryomastery")
	var freeze_monster: MonsterDataClass = MonsterDataClass.new()
	freeze_monster.monster_name = "Cryomastery Target"
	freeze_monster.max_hp = 100
	freeze_monster.current_hp = 100
	freeze_monster.monster_items = [{"name": "Target Dummy", "damage": 10, "cooldown": 4.0}]
	_start_battle(["cryomastery"], shield_inv, freeze_monster)
	shield_source.current_cooldown = 0.0
	_battle_system().call("execute_battle_tick", 0.0)
	_assert_true(_trace_has("cryomastery_on_shield_freeze_item"), "Cryomastery executes through the DSL")
	_assert_float_eq(float(freeze_monster.monster_items[0].get("current_cooldown", 0.0)), 5.0, "Cryomastery freezes an enemy item after Shield")
	_battle_system().call("end_battle")

	var weapon_inv: LinearInventoryClass = LinearInventoryClass.new()
	var weapon_source: ItemDataClass = _create_item("fang")
	var charge_target: ItemDataClass = _create_item("lighter")
	_assert_true(weapon_inv.place_item(weapon_source, 0), "places Weapon source for Flurry of Blows")
	_assert_true(weapon_inv.place_item(charge_target, 1), "places charge target for Flurry of Blows")
	_start_battle(["flurry_of_blows"], weapon_inv)
	weapon_source.current_cooldown = 0.0
	charge_target.current_cooldown = 7.0
	_battle_system().call("execute_battle_tick", 0.0)
	_assert_true(_trace_has("flurry_of_blows_on_weapon_charge_item"), "Flurry of Blows executes through the DSL")
	_assert_float_eq(charge_target.current_cooldown, 6.0, "Flurry of Blows charges an item after a Weapon use")
	_battle_system().call("end_battle")

func test_phase90_numeric_passive_skill_bonuses() -> void:
	var start_status_inv: LinearInventoryClass = LinearInventoryClass.new()
	var fire_potion: ItemDataClass = _create_item("fire_potion")
	var noxious_potion: ItemDataClass = _create_item("noxious_potion")
	var silk_scarf: ItemDataClass = _create_item("silk_scarf")
	_assert_true(start_status_inv.place_item(fire_potion, 0), "places Fire Potion for Adaptive Ordinance")
	_assert_true(start_status_inv.place_item(noxious_potion, 1), "places Noxious Potion for Adaptive Ordinance")
	_assert_true(start_status_inv.place_item(silk_scarf, 2), "places Silk Scarf for Augmented Defenses")
	_start_battle(["adaptive_ordinance", "waters_of_infinity", "augmented_defenses"], start_status_inv)
	var player_status: Dictionary = _battle_system().call("get_status_totals", "self")
	_assert_float_eq(float(player_status.get("regeneration", 0.0)), 64.0, "Adaptive Ordinance and Waters of Infinity add battle-start Regeneration from real board state")
	_assert_float_eq(_battle_system().call("_get_item_runtime_bonus", silk_scarf, "shield"), 1.0, "Augmented Defenses buffs Shield items at battle start")
	_battle_system().call("end_battle")

	var crit_damage_inv: LinearInventoryClass = LinearInventoryClass.new()
	var fang: ItemDataClass = _create_item("fang")
	var magic_carpet: ItemDataClass = _create_item("magic_carpet")
	var lighter: ItemDataClass = _create_item("lighter")
	_assert_true(crit_damage_inv.place_item(fang, 0), "places first Weapon for Arms Race")
	_assert_true(crit_damage_inv.place_item(magic_carpet, 1), "places second Weapon for Dual Wield")
	_assert_true(crit_damage_inv.place_item(lighter, 3), "places Tool for The Right Tool")
	_start_battle(["augmented_weaponry", "all_talk", "arms_race", "dual_wield", "the_right_tool"], crit_damage_inv)
	_assert_eq(_battle_system().call("_get_player_item_skill_damage_bonus", fang), 26, "Augmented Weaponry and All Talk add weapon damage from health and tags")
	_assert_eq(_battle_system().call("_get_player_item_skill_crit_bonus", fang), 59, "Arms Race, Dual Wield, and The Right Tool add crit from board composition")
	_battle_system().call("end_battle")

	var cooldown_inv: LinearInventoryClass = LinearInventoryClass.new()
	var vehicle_weapon: ItemDataClass = _create_item("magic_carpet")
	var non_vehicle_weapon: ItemDataClass = _create_item("fang")
	var tool_item: ItemDataClass = _create_item("lighter")
	_assert_true(cooldown_inv.place_item(vehicle_weapon, 0), "places Vehicle for Command Ship")
	_assert_true(cooldown_inv.place_item(non_vehicle_weapon, 2), "places non-Vehicle Weapon for Command Ship")
	_assert_true(cooldown_inv.place_item(tool_item, 3), "places Tool for Full Arsenal")
	_start_battle(["command_ship", "full_arsenal"], cooldown_inv)
	_assert_float_eq(_battle_system().call("_get_player_item_effective_cooldown", non_vehicle_weapon), 2.314, "Command Ship and Full Arsenal reduce cooldown from Vehicle/Weapon/Tool presence", 0.001)
	_battle_system().call("end_battle")

	var solo_weapon_inv: LinearInventoryClass = LinearInventoryClass.new()
	var solo_weapon: ItemDataClass = _create_item("fang")
	_assert_true(solo_weapon_inv.place_item(solo_weapon, 0), "places solo Weapon for One Shot One Kill")
	_start_battle(["one_shot_one_kill"], solo_weapon_inv)
	_assert_float_eq(_battle_system().call("_get_player_item_effective_cooldown", solo_weapon), 4.5, "One Shot One Kill increases the only Weapon cooldown")
	_assert_eq(_battle_system().call("_get_player_item_skill_damage_bonus", solo_weapon), 10, "One Shot One Kill triples damage via +2x base damage bonus")
	_battle_system().call("end_battle")

func test_phase90_source_and_adjacent_trigger_skills_execute_through_dsl() -> void:
	var weapon_inv: LinearInventoryClass = LinearInventoryClass.new()
	var bottled_lightning: ItemDataClass = _create_item("bottled_lightning")
	var fire_potion: ItemDataClass = _create_item("fire_potion")
	_assert_true(weapon_inv.place_item(bottled_lightning, 0), "places Ammo Weapon source")
	_assert_true(weapon_inv.place_item(fire_potion, 1), "places Ammo reload target")
	_start_battle(["aggressive", "flashy_reload", "parting_shot"], weapon_inv)
	_game_manager().get("selected_hero").crit_chance = 1.0
	bottled_lightning.current_cooldown = 0.0
	fire_potion.current_cooldown = 8.0
	fire_potion.current_ammo = 0
	_battle_system().call("execute_battle_tick", 0.0)
	_assert_true(_trace_has("aggressive_on_weapon_crit_source"), "Aggressive executes through the DSL")
	_assert_true(_trace_has("flashy_reload_on_crit_reload_ammo"), "Flashy Reload executes through the DSL")
	_assert_true(_trace_has("parting_shot_ammo_self_crit"), "Parting Shot executes through the DSL")
	_assert_float_eq(_battle_system().call("_get_item_runtime_bonus", bottled_lightning, "crit_rate"), 7.0, "Aggressive and Parting Shot buff the source item crit rate")
	_assert_eq(bottled_lightning.get_current_ammo(), 1, "Flashy Reload refills one Ammo item after a crit")
	_battle_system().call("end_battle")

	var tool_inv: LinearInventoryClass = LinearInventoryClass.new()
	var fang: ItemDataClass = _create_item("fang")
	var lighter: ItemDataClass = _create_item("lighter")
	var noxious_potion: ItemDataClass = _create_item("noxious_potion")
	_assert_true(tool_inv.place_item(fang, 0), "places Weapon source for Sharpened Steel")
	_assert_true(tool_inv.place_item(lighter, 1), "places Tool source for Flashy Mechanic and Retool")
	_assert_true(tool_inv.place_item(noxious_potion, 2), "places adjacent Ammo target for Retool")
	_start_battle(["flashy_mechanic", "retool", "sharpened_steel"], tool_inv)
	fang.current_cooldown = 0.0
	lighter.current_cooldown = 0.0
	noxious_potion.current_ammo = 0
	_battle_system().call("execute_battle_tick", 0.0)
	_assert_true(_trace_has("sharpened_steel_weapon_adjacent_crit"), "Sharpened Steel executes through the DSL")
	_battle_system().call("end_battle")

	_start_battle(["flashy_mechanic", "retool"], tool_inv)
	lighter.current_cooldown = 0.0
	noxious_potion.current_ammo = 0
	_battle_system().call("execute_battle_tick", 0.0)
	_assert_true(_trace_has("flashy_mechanic_tool_adjacent_crit"), "Flashy Mechanic executes through the DSL")
	_assert_true(_trace_has("retool_tool_reload_adjacent"), "Retool executes through the DSL")
	_assert_float_eq(_battle_system().call("_get_item_runtime_bonus", noxious_potion, "crit_rate"), 3.0, "Flashy Mechanic buffs adjacent item crit rate")
	_assert_eq(noxious_potion.get_current_ammo(), 1, "Retool reloads an adjacent Ammo item")
	_battle_system().call("end_battle")

func test_phase90_size_and_tag_selector_trigger_skills_execute() -> void:
	var friend_inv: LinearInventoryClass = LinearInventoryClass.new()
	var venomander: ItemDataClass = _create_item("venomander")
	var fang: ItemDataClass = _create_item("fang")
	_assert_true(friend_inv.place_item(venomander, 0), "places Friend source")
	_assert_true(friend_inv.place_item(fang, 1), "places Weapon target")
	_start_battle(["beautiful_friendship", "rigged"], friend_inv)
	venomander.current_cooldown = 0.0
	fang.current_cooldown = 8.0
	_battle_system().call("execute_battle_tick", 0.0)
	_assert_true(_trace_has("beautiful_friendship_friend_buffs_weapons"), "Beautiful Friendship executes through the DSL")
	_assert_true(_trace_has("rigged_first_item_haste_all"), "Rigged executes through the DSL")
	_assert_float_eq(_battle_system().call("_get_item_runtime_bonus", fang, "damage"), 3.0, "Beautiful Friendship gives Weapons a real damage bonus")
	_battle_system().call("end_battle")

	var large_inv: LinearInventoryClass = LinearInventoryClass.new()
	var large_source: ItemDataClass = _create_item("runic_great_axe")
	var lighter: ItemDataClass = _create_item("lighter")
	_assert_true(large_inv.place_item(large_source, 0), "places Large source")
	_assert_true(large_inv.place_item(lighter, 3), "places Small target")
	_start_battle(["blizzard", "distributed_systems"], large_inv)
	large_source.current_cooldown = 0.0
	lighter.current_cooldown = 5.0
	_battle_system().call("execute_battle_tick", 0.0)
	_assert_true(_trace_has("blizzard_first_item_freeze_non_weapons"), "Blizzard executes through the DSL")
	_assert_true(_trace_has("distributed_systems_large_haste_small"), "Distributed Systems executes through the DSL")
	_assert_float_eq(lighter.current_cooldown, 5.0, "Blizzard freeze and Distributed Systems haste both apply to the Small target")
	_battle_system().call("end_battle")

	var aquatic_inv: LinearInventoryClass = LinearInventoryClass.new()
	var pearl: ItemDataClass = _create_item("pearl")
	var aquatic_weapon: ItemDataClass = _create_item("sharkclaws")
	_assert_true(aquatic_inv.place_item(pearl, 0), "places Aquatic source")
	_assert_true(aquatic_inv.place_item(aquatic_weapon, 1), "places Aquatic Weapon haste target")
	_start_battle(["crashing_waves"], aquatic_inv)
	pearl.current_cooldown = 0.0
	aquatic_weapon.current_cooldown = 8.0
	_battle_system().call("execute_battle_tick", 0.0)
	_assert_true(_trace_has("crashing_waves_aquatic_haste_weapon"), "Crashing Waves executes through the DSL")
	_assert_float_eq(aquatic_weapon.current_cooldown, 7.0, "Crashing Waves hastes a Weapon when an Aquatic item is used")
	_battle_system().call("end_battle")

	var small_inv: LinearInventoryClass = LinearInventoryClass.new()
	var small_source: ItemDataClass = _create_item("lighter")
	var large_target: ItemDataClass = _create_item("runic_great_axe")
	var poison_target: ItemDataClass = _create_item("noxious_potion")
	_assert_true(small_inv.place_item(small_source, 0), "places Small source for Juggler and Wake Up Call")
	_assert_true(small_inv.place_item(large_target, 1), "places Large target for Juggler")
	_assert_true(small_inv.place_item(poison_target, 4), "places status-tag target for Wake Up Call")
	_start_battle(["juggler", "wake_up_call"], small_inv)
	small_source.current_cooldown = 0.0
	large_target.current_cooldown = 9.0
	poison_target.current_cooldown = 6.0
	_battle_system().call("execute_battle_tick", 0.0)
	_assert_true(_trace_has("juggler_small_item_charge_large"), "Juggler executes through the DSL")
	_assert_true(_trace_has("wake_up_call_small_haste_status_item"), "Wake Up Call executes through the DSL")
	_assert_float_eq(large_target.current_cooldown, 8.0, "Juggler charges a Large item when a Small item is used")
	_assert_float_eq(poison_target.current_cooldown, 5.0, "Wake Up Call hastes a Burn/Poison/Freeze item")
	_battle_system().call("end_battle")

func test_phase90_status_chain_trigger_skills_execute() -> void:
	var shield_inv: LinearInventoryClass = LinearInventoryClass.new()
	var silk_scarf: ItemDataClass = _create_item("silk_scarf")
	var lighter: ItemDataClass = _create_item("lighter")
	_assert_true(shield_inv.place_item(silk_scarf, 0), "places Shield source for Electrified Hull")
	_assert_true(shield_inv.place_item(lighter, 2), "places charge target for shield triggers")
	_start_battle(["electrified_hull", "jack_of_all_trades"], shield_inv)
	silk_scarf.current_cooldown = 0.0
	lighter.current_cooldown = 12.0
	_battle_system().call("execute_battle_tick", 0.0)
	_assert_true(_trace_has("electrified_hull_on_shield_charge"), "Electrified Hull executes through the DSL")
	_assert_true(_trace_has("jack_of_all_trades_first_item_charge"), "Jack of All Trades executes through the DSL")
	_assert_float_eq(lighter.current_cooldown, 10.0, "Shield and first-item triggers charge a real item")
	_battle_system().call("end_battle")

	var poison_inv: LinearInventoryClass = LinearInventoryClass.new()
	var noxious_potion: ItemDataClass = _create_item("noxious_potion")
	var fang: ItemDataClass = _create_item("fang")
	_assert_true(poison_inv.place_item(noxious_potion, 0), "places Poison source for Neophiliac")
	_assert_true(poison_inv.place_item(fang, 1), "places charge target for Neophiliac")
	_start_battle(["anything_to_win", "assault_focus", "neophiliac"], poison_inv)
	noxious_potion.current_cooldown = 0.0
	fang.current_cooldown = 7.0
	_battle_system().call("execute_battle_tick", 0.0)
	_assert_true(_trace_has("anything_to_win_non_weapon_burn"), "Anything to Win burn executes through the DSL")
	_assert_true(_trace_has("anything_to_win_non_weapon_poison"), "Anything to Win poison executes through the DSL")
	_assert_true(_trace_has("assault_focus_non_weapon_slow_source"), "Assault Focus executes through the DSL")
	_assert_true(_trace_has("neophiliac_first_poison_charge"), "Neophiliac reacts to Poison through the DSL")
	_assert_float_eq(fang.current_cooldown, 5.0, "Neophiliac charges a real item after Poison is applied")
	_battle_system().call("end_battle")
