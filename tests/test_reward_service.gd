extends Node

const HeroDataClass = preload("res://scripts/data/hero_data.gd")
const BazaarContentClass = preload("res://scripts/data/bazaar_content.gd")
const ItemDataClass = preload("res://scripts/data/item_data.gd")
const LinearInventoryClass = preload("res://scripts/data/linear_inventory.gd")

var _total: int = 0
var _passed: int = 0

func _ready() -> void:
	if not Engine.is_editor_hint():
		print("== tests/test_reward_service.gd ==")
		_run_tests()
		_print_summary()

func _run_tests() -> void:
	test_apply_basic_reward()
	test_level_reward_choice_queues_until_selected()
	test_monster_item_choice_uses_stash_when_board_is_full()
	test_monster_item_choice_merges_when_board_and_stash_are_full()

func _reset_services_with_hero() -> void:
	RewardService.reset_runtime_state()
	EconomyService.reset()
	RunStateService.reset(true)
	HeroStateService.reset()
	var hero = HeroFactoryService.create_hero(HeroDataClass.HeroType.WARRIOR)
	GameManager.select_hero(hero)

func test_apply_basic_reward() -> void:
	_reset_services_with_hero()
	GameManager.take_damage(10)
	var summary: Dictionary = RewardService.apply_reward({"gold": 4, "income": 2, "heal": 5}, "test_basic")
	_assert_eq(int(summary["gold"]), 4, "basic reward summary tracks gold")
	_assert_eq(EconomyService.gold, EconomyService.STARTING_GOLD + 4, "basic reward adds gold")
	_assert_eq(EconomyService.income, EconomyService.STARTING_INCOME + 2, "basic reward adds income")
	_assert_eq(HeroStateService.player_health, 115, "basic reward heals current hero")

func test_level_reward_choice_queues_until_selected() -> void:
	_reset_services_with_hero()
	var inventory: LinearInventoryClass = LinearInventoryClass.new()
	var stash: LinearInventoryClass = LinearInventoryClass.new()
	var starting_income: int = EconomyService.income
	var starting_max_health: int = GameManager.get_max_health()
	var summary: Dictionary = RewardService.apply_reward(
		{"xp": HeroStateService.XP_PER_LEVEL},
		"test_level",
		inventory,
		stash
	)

	_assert_eq(HeroStateService.level, 2, "8 XP still levels hero to 2")
	_assert_eq(HeroStateService.xp, 0, "level-up still consumes XP")
	_assert_eq(EconomyService.income, starting_income, "income does not change before choosing reward")
	_assert_eq(GameManager.get_max_health(), starting_max_health, "max health does not change before choosing reward")
	_assert_true(RewardService.has_pending_choice(), "level-up queues a pending reward choice")
	_assert_eq(summary["level_rewards"].size(), 1, "summary still records one level reward entry")
	_assert_true(bool(summary["level_rewards"][0].get("choice_queued", false)), "level reward entry is marked as queued")

	var choice: Dictionary = RewardService.get_active_choice()
	var income_index: int = _find_choice_index(choice, "income")
	_assert_true(income_index >= 0, "level-up choice offers an income option")
	if income_index >= 0:
		var resolved: Dictionary = RewardService.resolve_active_choice(income_index, inventory, stash)
		_assert_true(bool(resolved.get("resolved", false)), "income choice resolves successfully")
	_assert_eq(EconomyService.income, starting_income + 1, "choosing income applies the level reward")
	_assert_true(not RewardService.has_pending_choice(), "pending level-up choice is cleared after selection")

func test_monster_item_choice_uses_stash_when_board_is_full() -> void:
	_reset_services_with_hero()
	var inventory: LinearInventoryClass = LinearInventoryClass.new()
	var stash: LinearInventoryClass = LinearInventoryClass.new()
	_fill_board_with_dummy_items(inventory, 10, "board_fill")
	_fill_board_with_dummy_items(stash, 9, "stash_fill")
	var before_stash_count: int = stash.get_item_count()

	var reward_result: Dictionary = RewardService.apply_monster_reward({
		"gold": 2,
		"xp": 1,
		"item_pool": [{"id": "chocolate_bar", "tier": "Bronze"}],
		"skill_pool": [{"id": "toughness", "tier": "Bronze"}],
	}, "test_monster_reward", inventory, stash)
	_assert_true(bool(reward_result.get("choice_queued", false)), "monster reward queues a choice when item or skill rewards exist")

	var choice: Dictionary = RewardService.get_active_choice()
	var item_index: int = _find_choice_index(choice, "item")
	_assert_true(item_index >= 0, "monster reward choice offers an item option")
	if item_index >= 0:
		var resolved: Dictionary = RewardService.resolve_active_choice(item_index, inventory, stash)
		_assert_true(bool(resolved.get("resolved", false)), "item reward choice resolves successfully")
	_assert_eq(stash.get_item_count(), before_stash_count + 1, "item reward falls back to stash when the board is full")
	_assert_true(stash.get_item_at(9) != null and stash.get_item_at(9).source_id == "chocolate_bar", "stash receives the selected reward item")

func test_monster_item_choice_merges_when_board_and_stash_are_full() -> void:
	_reset_services_with_hero()
	var inventory: LinearInventoryClass = LinearInventoryClass.new()
	var stash: LinearInventoryClass = LinearInventoryClass.new()
	var merge_target = BazaarContentClass.create_item("scrap", BazaarContentClass.RARITY_BRONZE)
	_assert_not_null(merge_target, "merge test can build a real scrap target")
	if merge_target == null:
		return
	inventory.place_item(merge_target, 0)
	_fill_board_with_dummy_items(inventory, 9, "board_merge_fill", 1)
	_fill_board_with_dummy_items(stash, 10, "stash_merge_fill")
	var target_item = inventory.get_item_at(0)
	_assert_not_null(target_item, "merge test has a leftmost reward target item")
	if target_item == null:
		return

	var reward_result: Dictionary = RewardService.apply_monster_reward({
		"gold": 2,
		"xp": 1,
		"item_pool": [{"id": "scrap", "tier": "Bronze"}],
		"skill_pool": [{"id": "toughness", "tier": "Bronze"}],
	}, "test_monster_merge", inventory, stash)
	_assert_true(bool(reward_result.get("choice_queued", false)), "merge test queues the monster reward choice")

	var choice: Dictionary = RewardService.get_active_choice()
	var item_index: int = _find_choice_index(choice, "item")
	if item_index >= 0:
		var resolved: Dictionary = RewardService.resolve_active_choice(item_index, inventory, stash)
		_assert_true(bool(resolved.get("resolved", false)), "merge reward choice resolves successfully")
	_assert_eq(target_item.rarity, BazaarContentClass.RARITY_SILVER, "reward item merges into the owned copy when all slots are full")
	_assert_eq(inventory.get_item_count(), 10, "merge keeps the board item count stable")
	_assert_eq(stash.get_item_count(), 10, "merge keeps the stash item count stable")

func _fill_board_with_dummy_items(
	inventory: LinearInventoryClass,
	count: int,
	prefix: String,
	start_slot: int = 0
) -> void:
	for offset in range(count):
		var item: ItemDataClass = ItemDataClass.new()
		item.source_id = "%s_%d" % [prefix, offset]
		item.item_name = "Dummy %s %d" % [prefix, offset]
		item.base_item_name = item.item_name
		item.type = ItemDataClass.Type.UTILITY
		item.size = ItemDataClass.Size.SMALL
		inventory.place_item(item, start_slot + offset)

func _find_choice_index(choice: Dictionary, kind: String) -> int:
	var options: Array = choice.get("options", [])
	for index in range(options.size()):
		if options[index] is Dictionary and str((options[index] as Dictionary).get("kind", "")) == kind:
			return index
	return -1

func _assert_true(condition: bool, label: String) -> void:
	_total += 1
	if condition:
		_passed += 1
		print("PASS: %s" % label)
	else:
		push_error("FAIL: %s" % label)

func _assert_eq(actual, expected, label: String) -> void:
	_assert_true(actual == expected, "%s | expected=%s actual=%s" % [label, str(expected), str(actual)])

func _assert_not_null(value: Variant, label: String) -> void:
	_assert_true(value != null, label)

func _print_summary() -> void:
	print("SUMMARY: %d/%d passed" % [_passed, _total])
	get_tree().quit(1 if _passed < _total else 0)
