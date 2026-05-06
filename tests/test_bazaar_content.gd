extends Node

const BazaarContentClass = preload("res://scripts/data/bazaar_content.gd")
const HeroDataClass = preload("res://scripts/data/hero_data.gd")
const ItemDataClass = preload("res://scripts/data/item_data.gd")
const WikiMonsterCatalogClass = preload("res://scripts/data/wiki_monster_catalog.gd")

var _total: int = 0
var _passed: int = 0

func _ready() -> void:
	if not Engine.is_editor_hint():
		print("== tests/test_bazaar_content.gd ==")
		test_mak_hero_factory_data()
		test_mak_bronze_item_values_match_wiki()
		test_full_mak_item_catalog_and_starting_tiers()
		test_all_confirmed_hero_item_collections()
		test_day1_monster_values_match_wiki()
		test_full_monster_catalog_values_match_wiki()
		test_monster_catalog_references_resolve()
		test_full_event_catalog_values_match_wiki()
		test_day1_event_catalog()
		_print_summary()

func test_mak_hero_factory_data() -> void:
	var hero: HeroDataClass = BazaarContentClass.create_mak_hero()
	_assert_eq(hero.hero_name, "Mak", "Mak hero name")
	_assert_eq(hero.hero_type, HeroDataClass.HeroType.MAK, "Mak hero type")
	_assert_eq(hero.max_hp, 100, "Mak demo health")
	_assert_true(hero.available_items.has("fire_potion"), "Mak item pool includes Fire Potion")

func test_mak_bronze_item_values_match_wiki() -> void:
	var fire_potion: ItemDataClass = BazaarContentClass.create_item("fire_potion", BazaarContentClass.RARITY_BRONZE)
	_assert_eq(fire_potion.item_name, "Fire Potion", "Fire Potion name")
	_assert_eq(fire_potion.buy_price, 2, "Fire Potion bronze cost")
	_assert_eq(fire_potion.cooldown, 5.0, "Fire Potion cooldown")
	_assert_eq(fire_potion.ammo, 1, "Fire Potion ammo")
	_assert_eq(int(fire_potion.burn_damage), 6, "Fire Potion bronze burn")

	var bottled: ItemDataClass = BazaarContentClass.create_item("bottled_lightning", BazaarContentClass.RARITY_BRONZE)
	_assert_eq(bottled.damage, 20, "Bottled Lightning bronze damage")
	_assert_eq(int(bottled.burn_damage), 2, "Bottled Lightning bronze burn")
	_assert_eq(bottled.crit_chance, 1.0, "Bottled Lightning crit")

	var carpet: ItemDataClass = BazaarContentClass.create_item("magic_carpet", BazaarContentClass.RARITY_DIAMOND)
	_assert_eq(carpet.damage, 200, "Magic Carpet diamond damage")

func test_full_mak_item_catalog_and_starting_tiers() -> void:
	var ids: Array[String] = BazaarContentClass.get_mak_item_ids()
	_assert_true(ids.size() >= 110, "Mak catalog includes full wiki item pool")
	_assert_true(ids.has("adrenal_converter"), "Mak catalog includes Adrenal Converter")
	_assert_true(ids.has("staff_of_the_moose"), "Mak catalog includes Staff of the Moose")

	var amber: ItemDataClass = BazaarContentClass.create_item("amber", BazaarContentClass.RARITY_SILVER)
	_assert_eq(amber.buy_price, 4, "Silver-start Amber uses first wiki cost tier")
	_assert_eq(amber.slow_count, 1, "Amber Silver slows one item")
	_assert_eq(amber.slow_duration, 3.0, "Amber slow duration")

	var regeneration_potion: ItemDataClass = BazaarContentClass.create_item("regeneration_potion", BazaarContentClass.RARITY_GOLD)
	_assert_eq(regeneration_potion.buy_price, 8, "Gold Regeneration Potion uses default small gold buy price")
	_assert_eq(int(regeneration_potion.regeneration), 16, "Gold Regeneration Potion regen value")

	var sulphur: ItemDataClass = BazaarContentClass.create_item("sulphur", BazaarContentClass.RARITY_BRONZE)
	_assert_eq(sulphur.buy_price, 2, "catalog cost arrays do not override default small bronze buy price")

func test_all_confirmed_hero_item_collections() -> void:
	var minimums: Dictionary = {
		HeroDataClass.HeroType.VANESSA: 50,
		HeroDataClass.HeroType.PYGMALIEN: 30,
		HeroDataClass.HeroType.DOOLEY: 30,
		HeroDataClass.HeroType.MAK: 100,
		HeroDataClass.HeroType.STELLE: 15,
		HeroDataClass.HeroType.JULES: 8,
		HeroDataClass.HeroType.KARNOK: 20,
	}
	for hero_type in minimums.keys():
		var ids: Array[String] = BazaarContentClass.get_hero_item_ids(hero_type)
		_assert_true(ids.size() >= int(minimums[hero_type]), "confirmed hero collection has enough items: %s" % str(hero_type))
		var item: ItemDataClass = BazaarContentClass.create_random_hero_shop_item(hero_type, BazaarContentClass.RARITY_DIAMOND, [], "", "")
		_assert_true(item != null, "hero shop can generate item: %s" % str(hero_type))
	_assert_true(BazaarContentClass.get_hero_item_ids(HeroDataClass.HeroType.KARNOK).has("hunters_axe"), "Karnok BazaarDB subset includes Hunter's Axe")
	_assert_true(BazaarContentClass.get_hero_item_ids(HeroDataClass.HeroType.KARNOK).has("adrenaline_shot"), "Karnok Mobalytics list includes Adrenaline Shot")
	_assert_true(BazaarContentClass.get_hero_item_ids(HeroDataClass.HeroType.KARNOK).has("bear_trap"), "Karnok Mobalytics list includes Bear Trap")

func test_day1_monster_values_match_wiki() -> void:
	var viper = BazaarContentClass.create_day1_monster("viper")
	_assert_eq(viper.monster_name, "Viper", "Viper name")
	_assert_eq(viper.max_hp, 75, "Viper health")
	_assert_eq(viper.gold_reward_min, 3, "Viper gold reward")
	_assert_eq(viper.xp_reward, 2, "Viper XP reward")
	_assert_eq(viper.monster_items.size(), 3, "Viper item count")
	_assert_eq(str(viper.monster_skills[0].get("name", "")), "Lash Out", "Viper skill")

	var pyro = BazaarContentClass.create_day1_monster("pyro")
	var lighter: Dictionary = pyro.monster_items[1]
	_assert_eq(str(lighter.get("name", "")), "Lighter", "Pyro has Lighter")
	_assert_eq(int(lighter.get("burn", 0)), 3, "Pyro Fiery adds +1 burn to Lighter")

	var kimono = BazaarContentClass.create_day1_monster("haunted_kimono")
	var silk_scarf: Dictionary = kimono.monster_items[1]
	_assert_eq(str(silk_scarf.get("name", "")), "Silk Scarf", "Haunted Kimono has Silk Scarf")
	_assert_eq(int(silk_scarf.get("slot_count", 0)), 2, "Silk Scarf occupies two board slots")

func test_full_monster_catalog_values_match_wiki() -> void:
	var all_monsters: Array[Dictionary] = BazaarContentClass.get_all_monster_specs()
	_assert_true(all_monsters.size() >= 100, "Full wiki monster catalog is available")
	var day2_monsters: Array[Dictionary] = BazaarContentClass.get_monster_specs_for_day(2)
	var day2_ids: Array[String] = []
	for monster_spec in day2_monsters:
		day2_ids.append(str(monster_spec.get("id", "")))
	_assert_true(day2_ids.has("coconut_crab"), "Level 2 catalog includes Coconut Crab")
	_assert_true(day2_ids.has("giant_mosquito"), "Level 2 catalog includes Giant Mosquito")

	var crab = BazaarContentClass.create_monster("coconut_crab", 2)
	_assert_eq(crab.monster_name, "Coconut Crab", "Coconut Crab can be created from wiki catalog")
	_assert_eq(crab.max_hp, 200, "Coconut Crab health")
	_assert_eq(crab.monster_items.size(), 3, "Coconut Crab item count")
	_assert_eq(str(crab.monster_skills[0].get("name", "")), "Hard Shell", "Coconut Crab skill")

	var boarrior = BazaarContentClass.create_monster("boarrior", 3)
	_assert_eq(boarrior.monster_items.size(), 7, "Boarrior item list supports single Cargo item queries")
	_assert_eq(str(boarrior.monster_skills[0].get("name", "")), "Frontal Shielding", "Boarrior skill list excludes item Cargo rows")

	_assert_true(WikiMonsterCatalogClass.find_item_spec("tusked_helm").has("damage"), "Monster-related item mechanics are parsed")
	_assert_true(WikiMonsterCatalogClass.find_skill_spec("lash_out").has("start_poison"), "Monster skill start effects are parsed")

func test_monster_catalog_references_resolve() -> void:
	var missing_items: Array[String] = []
	var missing_skills: Array[String] = []
	for monster in BazaarContentClass.get_all_monster_specs():
		if int(monster.get("level", 0)) <= 0:
			continue
		for item_id in monster.get("item_ids", []):
			if WikiMonsterCatalogClass.find_item_spec(str(item_id)).is_empty():
				missing_items.append("%s:%s" % [str(monster.get("id", "")), str(item_id)])
		for skill_id in monster.get("skill_ids", []):
			if WikiMonsterCatalogClass.find_skill_spec(str(skill_id)).is_empty():
				missing_skills.append("%s:%s" % [str(monster.get("id", "")), str(skill_id)])
	_assert_eq(missing_items.size(), 0, "all leveled monster item references resolve: %s" % ", ".join(missing_items))
	_assert_eq(missing_skills.size(), 0, "all leveled monster skill references resolve: %s" % ", ".join(missing_skills))

func test_full_event_catalog_values_match_wiki() -> void:
	var events: Array[Dictionary] = BazaarContentClass.get_all_event_specs()
	_assert_true(events.size() >= 80, "Full wiki event table is available")
	_assert_true(not BazaarContentClass.find_event_spec("mandala").is_empty(), "Event catalog includes Mandala")
	_assert_true(not BazaarContentClass.find_event_spec("the_docks").is_empty(), "Event catalog includes The Docks")
	_assert_true(not BazaarContentClass.find_event_spec("futura").is_empty(), "Event catalog includes Futura")
	var day10_events: Array[Dictionary] = BazaarContentClass.get_event_specs_for_day(10)
	var day10_ids: Array[String] = []
	for event in day10_events:
		day10_ids.append(str(event.get("id", "")))
	_assert_true(day10_ids.has("frozen_tomb"), "Day 10 event catalog includes Frozen Tomb")
	_assert_true(day10_ids.has("guardians_gorge"), "Day 10 event catalog includes Guardian's Gorge")
	_assert_true(not day10_ids.has("dabora"), "Disabled events are excluded from day pools")

func test_day1_event_catalog() -> void:
	var events: Array[Dictionary] = BazaarContentClass.get_day1_events()
	_assert_true(events.size() >= 10, "Day 1 event catalog has real events")
	var ids: Array[String] = []
	for event in events:
		ids.append(str(event.get("id", "")))
	_assert_true(ids.has("tiny_furry_monster"), "Day 1 events include Tiny Furry Monster")
	_assert_true(ids.has("battlefield"), "Day 1 events include Battlefield")
	_assert_true(ids.has("relax"), "Day 1 events include Relax")
	_assert_true(not BazaarContentClass.get_event_art_path("relax").is_empty(), "Relax has wiki art")

func _assert_true(condition: bool, label: String) -> void:
	_total += 1
	if condition:
		_passed += 1
		print("PASS: %s" % label)
	else:
		push_error("FAIL: %s" % label)

func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	_assert_true(actual == expected, "%s (expected=%s actual=%s)" % [label, str(expected), str(actual)])

func _print_summary() -> void:
	print("SUMMARY: %d/%d passed" % [_passed, _total])
	get_tree().quit(1 if _passed < _total else 0)
