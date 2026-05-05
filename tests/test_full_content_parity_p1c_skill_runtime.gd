extends Node

const BazaarContentClass = preload("res://scripts/data/bazaar_content.gd")
const PlayerSkillCatalogClass = preload("res://scripts/data/player_skill_catalog.gd")
const HeroDataClass = preload("res://scripts/data/hero_data.gd")
const LinearInventoryClass = preload("res://scripts/data/linear_inventory.gd")
const MonsterDataClass = preload("res://scripts/data/monster_data.gd")

var _total: int = 0
var _passed: int = 0

func _ready() -> void:
	print("== tests/test_full_content_parity_p1c_skill_runtime.gd ==")
	test_p1c_skill_coverage_implements_ambush_and_classifies_residuals()
	test_ambush_deals_enemy_max_health_percent_at_battle_start()
	_print_summary()

func _battle_system() -> Node:
	return get_node("/root/BattleSystem")

func _game_manager() -> Node:
	return get_node("/root/GameManager")

func test_p1c_skill_coverage_implements_ambush_and_classifies_residuals() -> void:
	var report: Dictionary = PlayerSkillCatalogClass.get_coverage_report()
	_assert_eq(int(report.get("unknown_count", -1)), 0, "P1C keeps skill unknown_total at zero")
	_assert_true(int(report.get("implemented_count", 0)) >= 101, "P1C adds Ambush to runtime-backed skill count")
	_assert_true(int(report.get("unsupported_count", 999)) <= 36, "P1C reduces unsupported skill count")
	var implemented_ids: Array = report.get("implemented_ids", [])
	_assert_true(implemented_ids.has("ambush"), "Ambush is runtime-backed")
	var ambush_definitions: Array[Dictionary] = PlayerSkillCatalogClass.get_effect_definitions({"id": "ambush", "tier": "Gold"})
	_assert_true(_definition_ids(ambush_definitions).has("ambush_battle_start_enemy_max_health_damage"), "Ambush exposes explicit battle-start DSL definition")
	var unsupported_ids: Array = report.get("unsupported_ids", [])
	for skill_id in unsupported_ids:
		var entry: Dictionary = PlayerSkillCatalogClass.get_skill_entry(str(skill_id))
		var reason: String = str(entry.get("unsupported_reason", ""))
		_assert_true(not reason.is_empty(), "%s residual unsupported reason is non-empty" % skill_id)
		_assert_true(reason != "phase1_catalog_rule_missing", "%s residual unsupported reason is no longer generic" % skill_id)

func test_ambush_deals_enemy_max_health_percent_at_battle_start() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var monster: MonsterDataClass = MonsterDataClass.new()
	monster.monster_name = "Ambush Target"
	monster.max_hp = 200
	monster.current_hp = 200
	_start_battle([{"id": "ambush", "tier": "Gold"}], inv, monster)
	_assert_eq(monster.current_hp, 170, "Gold Ambush deals 15 percent of enemy max health at battle start")
	_assert_true(_trace_has("ambush_battle_start_enemy_max_health_damage"), "Ambush emits battle-start DSL trace")
	_battle_system().call("end_battle")

func _start_battle(hero_skills: Array, inv: LinearInventoryClass, monster: MonsterDataClass) -> void:
	var hero: HeroDataClass = BazaarContentClass.create_mak_hero()
	hero.crit_chance = 0.0
	hero.skills = hero_skills.duplicate(true)
	var game_manager: Node = _game_manager()
	game_manager.call("reset_stats")
	game_manager.set("selected_hero", hero)
	game_manager.set("player_health", hero.max_hp)
	_battle_system().call("start_battle", monster, inv)

func _definition_ids(definitions: Array[Dictionary]) -> Array[String]:
	var ids: Array[String] = []
	for definition in definitions:
		ids.append(str(definition.get("id", "")))
	return ids

func _trace_has(definition_id: String) -> bool:
	for entry in _battle_system().call("get_effect_execution_trace"):
		if str(entry.get("definition_id", "")) == definition_id:
			return true
	return false

func _assert_true(condition: bool, label: String) -> void:
	_total += 1
	if condition:
		_passed += 1
		print("PASS: %s" % label)
	else:
		push_error("FAIL: %s" % label)

func _assert_eq(actual, expected, label: String) -> void:
	_assert_true(actual == expected, "%s | expected=%s actual=%s" % [label, str(expected), str(actual)])

func _print_summary() -> void:
	print("SUMMARY: %d/%d passed" % [_passed, _total])
	get_tree().quit(1 if _passed < _total else 0)
