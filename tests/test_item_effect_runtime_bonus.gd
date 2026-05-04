extends Node

const BazaarContentClass = preload("res://scripts/data/bazaar_content.gd")
const EffectDefinitionClass = preload("res://scripts/data/effect_definition.gd")
const ItemDataClass = preload("res://scripts/data/item_data.gd")
const LinearInventoryClass = preload("res://scripts/data/linear_inventory.gd")
const MonsterDataClass = preload("res://scripts/data/monster_data.gd")

var _total: int = 0
var _passed: int = 0

func _ready() -> void:
	if not Engine.is_editor_hint():
		print("== tests/test_item_effect_runtime_bonus.gd ==")
		_run_tests()
		_print_summary()

func _run_tests() -> void:
	test_runtime_bonus_definition_anchors_exist()
	test_fungal_spores_combat_bonus_runs_through_effect_definition()
	test_mortar_pestle_combat_bonus_runs_through_effect_definition()
	test_succulents_permanent_bonus_persists_after_fight()
	test_p1d_runtime_bonus_warning_family_is_reduced()

func _battle_system() -> Node:
	return get_node("/root/BattleSystem")

func _game_manager() -> Node:
	return get_node("/root/GameManager")

func _create_item(item_id: String, rarity: int = BazaarContentClass.RARITY_BRONZE) -> ItemDataClass:
	var item: ItemDataClass = BazaarContentClass.create_item(item_id, rarity)
	_assert_true(item != null, "creates %s" % item_id)
	return item

func _start_battle(inv: LinearInventoryClass, monster_hp: int = 500) -> MonsterDataClass:
	var hero = BazaarContentClass.create_mak_hero()
	hero.crit_chance = 0.0
	hero.skills = []
	var game_manager: Node = _game_manager()
	game_manager.call("reset_stats")
	game_manager.set("selected_hero", hero)
	game_manager.set("player_health", hero.max_hp)
	var monster: MonsterDataClass = MonsterDataClass.new()
	monster.monster_name = "P1D Runtime Bonus Test"
	monster.max_hp = monster_hp
	monster.current_hp = monster_hp
	_battle_system().call("start_battle", monster, inv)
	return monster

func _set_ready(item: ItemDataClass) -> void:
	item.current_cooldown = 0.0

func _set_blocked(item: ItemDataClass) -> void:
	item.current_cooldown = 999.0

func _definition_ids(item: ItemDataClass) -> Array[String]:
	var ids: Array[String] = []
	for definition in item.effects:
		if definition is Dictionary:
			ids.append(str((definition as Dictionary).get("id", "")))
	return ids

func _trace_has(definition_id: String) -> bool:
	for entry in _battle_system().call("get_effect_execution_trace"):
		if str(entry.get("definition_id", "")) == definition_id:
			return true
	return false

func test_runtime_bonus_definition_anchors_exist() -> void:
	_assert_true(_definition_ids(_create_item("fungal_spores")).has("fungal_spores_on_cooldown_ready_runtime_bonus"), "Fungal Spores has combat runtime_bonus definition")
	_assert_true(_definition_ids(_create_item("mortar_pestle")).has("mortar_pestle_on_cooldown_ready_runtime_bonus"), "Mortar & Pestle has combat runtime_bonus definition")
	_assert_true(_definition_ids(_create_item("succulents")).has("succulents_on_cooldown_ready_runtime_bonus"), "Succulents has permanent runtime_bonus definition")
	_assert_true(_definition_ids(_create_item("calcinator")).has("calcinator_on_transform_runtime_bonus"), "Calcinator records permanent transform runtime_bonus")
	_assert_true(_definition_ids(_create_item("retort")).has("retort_on_transform_runtime_bonus"), "Retort records permanent transform runtime_bonus")
	_assert_true(_definition_ids(_create_item("the_tome_of_yyahan")).has("the_tome_of_yyahan_on_transform_runtime_bonus"), "Tome records permanent transform runtime_bonus")

func test_fungal_spores_combat_bonus_runs_through_effect_definition() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var fungal_spores: ItemDataClass = _create_item("fungal_spores")
	var fang: ItemDataClass = _create_item("fang")
	var venom: ItemDataClass = _create_item("venom")
	_assert_true(inv.place_item(fungal_spores, 0), "places Fungal Spores")
	_assert_true(inv.place_item(fang, 1), "places Fang")
	_assert_true(inv.place_item(venom, 2), "places Venom")
	_start_battle(inv)
	_set_ready(fungal_spores)
	_set_ready(fang)
	_set_blocked(venom)

	_battle_system().call("execute_battle_tick", 0.0)
	_assert_true(_trace_has("fungal_spores_on_cooldown_ready_runtime_bonus"), "Fungal Spores runtime_bonus emits DSL trace")
	_assert_float_eq(float(_battle_system().call("get_status_totals", "enemy").get("poison", 0.0)), 4.0, "Fungal Spores gives Venom +2 Poison for the fight")
	_battle_system().call("end_battle")

func test_mortar_pestle_combat_bonus_runs_through_effect_definition() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var mortar: ItemDataClass = _create_item("mortar_pestle")
	var fang: ItemDataClass = _create_item("fang")
	_assert_true(inv.place_item(mortar, 0), "places Mortar & Pestle")
	_assert_true(inv.place_item(fang, 2), "places right Weapon")
	var monster: MonsterDataClass = _start_battle(inv)
	_set_ready(mortar)
	_set_blocked(fang)

	_battle_system().call("execute_battle_tick", 0.0)
	_assert_true(_trace_has("mortar_pestle_on_cooldown_ready_runtime_bonus"), "Mortar & Pestle runtime_bonus emits DSL trace")
	_set_ready(fang)
	_battle_system().call("execute_battle_tick", 0.0)
	_assert_eq(monster.current_hp, 485, "Mortar & Pestle gives the right Lifesteal Weapon +10 Damage for the fight")
	_battle_system().call("end_battle")

func test_succulents_permanent_bonus_persists_after_fight() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var succulents: ItemDataClass = _create_item("succulents")
	_assert_true(inv.place_item(succulents, 0), "places Succulents")
	_start_battle(inv)
	_set_ready(succulents)
	var heal_before: int = succulents.heal

	_battle_system().call("execute_battle_tick", 0.0)
	_assert_true(_trace_has("succulents_on_cooldown_ready_runtime_bonus"), "Succulents permanent runtime_bonus emits DSL trace")
	_assert_eq(succulents.heal, heal_before + 1, "Succulents permanently gains Heal after use")
	_battle_system().call("end_battle")
	_assert_eq(succulents.heal, heal_before + 1, "Succulents permanent Heal bonus survives battle cleanup")

func test_p1d_runtime_bonus_warning_family_is_reduced() -> void:
	var report: Dictionary = BazaarContentClass.get_reachable_item_effect_coverage_report()
	var families: Dictionary = report.get("warning_family_counts", {})
	_assert_true(int(families.get("unsupported_item_effect:runtime_bonus", 999)) < 182, "P1D reduces reachable runtime_bonus warning count")
	_assert_true((report.get("unknown_effect_categories", []) as Array).is_empty(), "P1D warning report introduces no unknown warning families")

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
