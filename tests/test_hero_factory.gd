extends Node

const HeroDataClass = preload("res://scripts/data/hero_data.gd")
const PassiveSkillDataClass = preload("res://scripts/data/passive_skill.gd")

var _total: int = 0
var _passed: int = 0


func _ready() -> void:
	if not Engine.is_editor_hint():
		print("== tests/test_hero_factory.gd ==")
		_run_tests()
		_print_summary()


func _run_tests() -> void:
	test_hero_factory_autoload_exists()
	test_create_warrior()
	test_create_mage()
	test_create_mak()
	test_warrior_has_correct_stats()
	test_mage_has_correct_stats()
	test_mak_has_real_item_pool()
	test_warrior_passive_skills_count()
	test_mage_passive_skills_count()
	test_warrior_passive_skill_types()
	test_mage_passive_skill_types()


func test_hero_factory_autoload_exists() -> void:
	# HeroFactoryService must be registered as the single autoload name.
	var hf = get_node_or_null("/root/HeroFactoryService")
	_assert_not_null(hf, "HeroFactoryService autoload should exist at /root/HeroFactoryService")


func test_create_warrior() -> void:
	var hf = get_node("/root/HeroFactoryService")
	var hero = hf.create_hero(HeroDataClass.HeroType.WARRIOR)
	_assert_not_null(hero, "create_hero(WARRIOR) should return a HeroData")
	_assert_eq(hero.hero_name, "战士", "warrior hero_name")
	_assert_eq(hero.hero_type, HeroDataClass.HeroType.WARRIOR, "warrior hero_type")


func test_create_mage() -> void:
	var hf = get_node("/root/HeroFactoryService")
	var hero = hf.create_hero(HeroDataClass.HeroType.MAGE)
	_assert_not_null(hero, "create_hero(MAGE) should return a HeroData")
	_assert_eq(hero.hero_name, "法师", "mage hero_name")
	_assert_eq(hero.hero_type, HeroDataClass.HeroType.MAGE, "mage hero_type")

func test_create_mak() -> void:
	var hf = get_node("/root/HeroFactoryService")
	var hero = hf.create_hero(HeroDataClass.HeroType.MAK)
	_assert_not_null(hero, "create_hero(MAK) should return a HeroData")
	_assert_eq(hero.hero_name, "Mak", "mak hero_name")
	_assert_eq(hero.hero_type, HeroDataClass.HeroType.MAK, "mak hero_type")


func test_warrior_has_correct_stats() -> void:
	var hf = get_node("/root/HeroFactoryService")
	var hero = hf.create_hero(HeroDataClass.HeroType.WARRIOR)
	_assert_eq(hero.max_hp, 120, "warrior max_hp")
	_assert_eq(hero.crit_chance, 0.05, "warrior crit_chance")


func test_mage_has_correct_stats() -> void:
	var hf = get_node("/root/HeroFactoryService")
	var hero = hf.create_hero(HeroDataClass.HeroType.MAGE)
	_assert_eq(hero.max_hp, 80, "mage max_hp")
	_assert_eq(hero.crit_chance, 0.15, "mage crit_chance")

func test_mak_has_real_item_pool() -> void:
	var hf = get_node("/root/HeroFactoryService")
	var hero = hf.create_hero(HeroDataClass.HeroType.MAK)
	_assert_eq(hero.max_hp, 100, "mak max_hp")
	_assert_true(hero.available_items.has("fire_potion"), "mak available_items include real Mak item")
	_assert_true(hero.available_items.has("magic_carpet"), "mak available_items include Magic Carpet")


func test_warrior_passive_skills_count() -> void:
	var hf = get_node("/root/HeroFactoryService")
	var hero = hf.create_hero(HeroDataClass.HeroType.WARRIOR)
	_assert_eq(hero.passive_skills.size(), 2, "warrior should have 2 passive skills")


func test_mage_passive_skills_count() -> void:
	var hf = get_node("/root/HeroFactoryService")
	var hero = hf.create_hero(HeroDataClass.HeroType.MAGE)
	_assert_eq(hero.passive_skills.size(), 2, "mage should have 2 passive skills")


func test_warrior_passive_skill_types() -> void:
	var hf = get_node("/root/HeroFactoryService")
	var hero = hf.create_hero(HeroDataClass.HeroType.WARRIOR)
	var types = hero.passive_skills.map(func(ps): return ps.effect_type)
	_assert_true(types.has(PassiveSkillDataClass.EffectType.HEALTH_BONUS), "warrior should have HEALTH_BONUS skill")
	_assert_true(types.has(PassiveSkillDataClass.EffectType.CRIT_BONUS), "warrior should have CRIT_BONUS skill")


func test_mage_passive_skill_types() -> void:
	var hf = get_node("/root/HeroFactoryService")
	var hero = hf.create_hero(HeroDataClass.HeroType.MAGE)
	var types = hero.passive_skills.map(func(ps): return ps.effect_type)
	_assert_true(types.has(PassiveSkillDataClass.EffectType.CRIT_BONUS), "mage should have CRIT_BONUS skill")
	_assert_true(types.has(PassiveSkillDataClass.EffectType.HEALTH_BONUS), "mage should have HEALTH_BONUS skill")


# ─── Helpers ───────────────────────────────────────────────

func _assert_true(condition: bool, msg: String) -> void:
	_total += 1
	if condition:
		_passed += 1
		print("PASS: %s" % msg)
	else:
		push_error("FAIL: %s" % msg)

func _assert_eq(actual, expected, msg: String) -> void:
	_total += 1
	var ok = (actual == expected) or (str(actual) == str(expected))
	if ok:
		_passed += 1
		print("PASS: %s | expected=%s actual=%s" % [msg, expected, actual])
	else:
		push_error("FAIL: %s | expected=%s actual=%s" % [msg, expected, actual])

func _assert_not_null(val, msg: String) -> void:
	_total += 1
	if val != null:
		_passed += 1
		print("PASS: %s" % msg)
	else:
		push_error("FAIL: %s" % msg)

func _print_summary() -> void:
	print("SUMMARY: %d/%d passed" % [_passed, _total])
	get_tree().quit(1 if _passed < _total else 0)
