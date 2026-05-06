extends Node

const BazaarContentClass = preload("res://scripts/data/bazaar_content.gd")
const EventManagerClass = preload("res://scripts/data/event_manager.gd")
const HeroDataClass = preload("res://scripts/data/hero_data.gd")
const ItemDataClass = preload("res://scripts/data/item_data.gd")
const LinearInventoryClass = preload("res://scripts/data/linear_inventory.gd")
const EconomyManagerClass = preload("res://scripts/data/economy_manager.gd")

var _total: int = 0
var _passed: int = 0

func _ready() -> void:
	if not Engine.is_editor_hint():
		print("== tests/test_shop_service_vendors.gd ==")
		_run_tests()
		_print_summary()

func _run_tests() -> void:
	test_build_hour_options_include_shop_service_and_event()
	test_service_vendor_catalog_exposes_required_vendor_kinds()
	test_service_vendor_rewards_apply_through_reward_service()
	test_economy_service_generates_and_refreshes_merchant_shelves()

func test_build_hour_options_include_shop_service_and_event() -> void:
	var manager = EventManagerClass.new()
	var options: Array[Dictionary] = manager.generate_options(0, 3)
	var types: Array[String] = []
	for option in options:
		types.append(str(option.get("type", "")))
	_assert_true("shop" in types, "build hour can include an item vendor option")
	_assert_true("service_vendor" in types, "build hour can include a service vendor option")
	_assert_true("random_event" in types, "build hour can include an event option")

func test_service_vendor_catalog_exposes_required_vendor_kinds() -> void:
	var specs: Array[Dictionary] = EconomyService.get_service_vendor_specs(6)
	var kinds: Dictionary = {}
	for spec in specs:
		kinds[str(spec.get("kind", ""))] = true
	_assert_true(kinds.has("skill_trainer"), "service catalog exposes Skill Trainer")
	_assert_true(kinds.has("enchanter"), "service catalog exposes Enchanter")
	_assert_true(kinds.has("healer"), "service catalog exposes Healer")
	_assert_true(kinds.has("upgrade"), "service catalog exposes Upgrade")
	_assert_true(kinds.has("free_reward"), "service catalog exposes Free Reward")
	_assert_true(kinds.has("finance"), "service catalog exposes Income/Finance")

func test_service_vendor_rewards_apply_through_reward_service() -> void:
	var manager = EventManagerClass.new()
	var inventory: LinearInventoryClass = LinearInventoryClass.new()
	var stash: LinearInventoryClass = LinearInventoryClass.new()

	_reset_services_with_hero()
	var starting_gold: int = EconomyService.gold
	var starting_income: int = EconomyService.income
	manager.execute_service_vendor("finance_office", 2, GameManager, inventory, stash)
	_assert_true(EconomyService.gold > starting_gold, "finance service applies gold through EconomyService")
	_assert_equal(EconomyService.income, starting_income + 1, "finance service applies income through RewardService")

	_reset_services_with_hero()
	GameManager.selected_hero.skills.clear()
	manager.execute_service_vendor("skill_trainer", 2, GameManager, inventory, stash)
	_assert_true(GameManager.selected_hero.skills.size() == 1, "skill trainer grants a hero skill")

	_reset_services_with_hero()
	var upgrade_item = BazaarContentClass.create_item("fire_potion", BazaarContentClass.RARITY_BRONZE)
	inventory = LinearInventoryClass.new()
	inventory.place_item(upgrade_item, 0)
	manager.execute_service_vendor("upgrade_vendor", 2, GameManager, inventory, stash)
	_assert_equal(upgrade_item.rarity, BazaarContentClass.RARITY_SILVER, "upgrade service upgrades leftmost item")

	_reset_services_with_hero()
	var enchant_item = BazaarContentClass.create_item("fire_potion", BazaarContentClass.RARITY_BRONZE)
	inventory = LinearInventoryClass.new()
	inventory.place_item(enchant_item, 0)
	manager.execute_service_vendor("enchanter", 2, GameManager, inventory, stash)
	_assert_equal(enchant_item.enchantment_id, "toxic", "enchanter service enchants leftmost item through RewardService")

	_reset_services_with_hero()
	GameManager.take_damage(30)
	var damaged_health: int = HeroStateService.player_health
	manager.execute_service_vendor("healer", 2, GameManager, inventory, stash)
	_assert_true(HeroStateService.player_health > damaged_health, "healer service heals through RewardService")

func test_economy_service_generates_and_refreshes_merchant_shelves() -> void:
	_reset_services_with_hero()
	var inventory: LinearInventoryClass = LinearInventoryClass.new()
	var stash: LinearInventoryClass = LinearInventoryClass.new()
	var merchant_info: Dictionary = {"id": "aila", "merchant_type": "Weapon", "rarity": "Bronze"}
	var shelf: Array[ItemDataClass] = EconomyService.generate_merchant_shelf(
		merchant_info,
		inventory,
		stash,
		3,
		HeroDataClass.HeroType.MAK,
		4
	)
	_assert_equal(shelf.size(), 4, "EconomyService generates requested merchant shelf size")
	_assert_true(shelf[0].buy_price > 0, "EconomyService prices generated merchant items")
	for item in shelf:
		_assert_equal(
			item.buy_price,
			EconomyManagerClass.calculate_item_price(item.rarity, item.size as int, item.type as int, 3),
			"EconomyService normalizes generated source-backed shop item default price: %s" % item.source_id
		)

	var locked_indices: Array[int] = [0]
	var refreshed: Array[ItemDataClass] = EconomyService.refresh_merchant_shelf(
		shelf,
		locked_indices,
		merchant_info,
		inventory,
		stash,
		3,
		HeroDataClass.HeroType.MAK
	)
	_assert_true(refreshed.size() >= 3, "EconomyService refresh keeps a playable shelf")
	_assert_true(refreshed[0] == shelf[0], "EconomyService refresh preserves locked items")
	_assert_equal(EconomyService.get_shop_refresh_cost(false), 0, "first refresh is free through EconomyService")
	_assert_equal(EconomyService.get_shop_refresh_cost(true), 2, "paid refresh cost is owned by EconomyService")

func _reset_services_with_hero() -> void:
	RewardService.reset_runtime_state()
	EconomyService.reset()
	RunStateService.reset(true)
	RunStateService.prestige = 0
	HeroStateService.reset()
	var hero = HeroFactoryService.create_hero(HeroDataClass.HeroType.MAK)
	GameManager.select_hero(hero)

func _assert_true(condition: bool, label: String) -> void:
	_total += 1
	if condition:
		_passed += 1
		print("PASS: %s" % label)
	else:
		push_error("FAIL: %s" % label)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	_assert_true(actual == expected, "%s (expected=%s actual=%s)" % [label, str(expected), str(actual)])

func _print_summary() -> void:
	print("SUMMARY: %d/%d passed" % [_passed, _total])
	if not get_tree().has_meta("node_test_runner_controls_quit"):
		get_tree().quit(1 if _passed < _total else 0)
