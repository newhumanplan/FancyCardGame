extends Node

const BazaarContentClass = preload("res://scripts/data/bazaar_content.gd")
const ItemAcquisitionClass = preload("res://scripts/data/item_acquisition.gd")
const ItemDataClass = preload("res://scripts/data/item_data.gd")
const LinearInventoryClass = preload("res://scripts/data/linear_inventory.gd")

var _total: int = 0
var _passed: int = 0

func _ready() -> void:
	if not Engine.is_editor_hint():
		print("== tests/test_item_acquisition.gd ==")
		_run_tests()
		_print_summary()

func _run_tests() -> void:
	test_duplicate_purchase_merges_into_existing_upgrade()
	test_merge_priority_prefers_player_board_before_stash()
	test_merge_can_cascade_after_lower_event_drop()
	test_shop_filter_uses_owned_rarity_floor_and_diamond_block()
	test_start_of_day_mortar_grants_catalyst_from_stash()
	test_hour_start_hooks_cover_expanded_catalyst_generators()
	test_on_buy_philosophers_stone_grants_catalyst()

func test_duplicate_purchase_merges_into_existing_upgrade() -> void:
	var inventory: LinearInventoryClass = LinearInventoryClass.new()
	var owned: ItemDataClass = BazaarContentClass.create_item("fire_potion", BazaarContentClass.RARITY_BRONZE)
	_assert_true(inventory.place_item(owned, 0), "test setup places existing Fire Potion")
	var incoming: ItemDataClass = BazaarContentClass.create_item("fire_potion", BazaarContentClass.RARITY_BRONZE)

	var result: Dictionary = ItemAcquisitionClass.grant_item(incoming, inventory)

	_assert_true(bool(result.get("success", false)), "duplicate acquisition succeeds")
	_assert_true(bool(result.get("merged", false)), "duplicate acquisition merges")
	_assert_eq(inventory.get_item_count(), 1, "incoming duplicate is consumed")
	_assert_true(inventory.get_item_at(0) == owned, "existing item remains in place")
	_assert_eq(owned.rarity, BazaarContentClass.RARITY_SILVER, "existing item upgrades to Silver")
	_assert_eq(int(owned.burn_damage), 8, "upgraded item refreshes rarity-scaled stats")

func test_merge_priority_prefers_player_board_before_stash() -> void:
	var inventory: LinearInventoryClass = LinearInventoryClass.new()
	var stash: LinearInventoryClass = LinearInventoryClass.new()
	var board_item: ItemDataClass = BazaarContentClass.create_item("venom", BazaarContentClass.RARITY_BRONZE)
	var stash_item: ItemDataClass = BazaarContentClass.create_item("venom", BazaarContentClass.RARITY_BRONZE)
	_assert_true(inventory.place_item(board_item, 4), "test setup places board Venom")
	_assert_true(stash.place_item(stash_item, 0), "test setup places stash Venom")

	var result: Dictionary = ItemAcquisitionClass.grant_item(BazaarContentClass.create_item("venom", BazaarContentClass.RARITY_BRONZE), inventory, stash)

	_assert_true(bool(result.get("merged", false)), "duplicate merge happens across board and stash")
	_assert_eq(board_item.rarity, BazaarContentClass.RARITY_SILVER, "left-to-right board item is upgraded first")
	_assert_eq(stash_item.rarity, BazaarContentClass.RARITY_BRONZE, "stash duplicate is not chosen before board item")
	_assert_eq(inventory.get_item_count(), 1, "no new item is placed on board after merge")

func test_merge_can_cascade_after_lower_event_drop() -> void:
	var inventory: LinearInventoryClass = LinearInventoryClass.new()
	var stash: LinearInventoryClass = LinearInventoryClass.new()
	var board_silver: ItemDataClass = BazaarContentClass.create_item("venom", BazaarContentClass.RARITY_SILVER)
	var stash_bronze: ItemDataClass = BazaarContentClass.create_item("venom", BazaarContentClass.RARITY_BRONZE)
	_assert_true(inventory.place_item(board_silver, 0), "test setup places board Silver Venom")
	_assert_true(stash.place_item(stash_bronze, 0), "test setup places stash Bronze Venom")

	var result: Dictionary = ItemAcquisitionClass.grant_item(BazaarContentClass.create_item("venom", BazaarContentClass.RARITY_BRONZE), inventory, stash)

	_assert_eq(int(result.get("merge_count", 0)), 2, "bronze drop can cascade through a second matching rarity")
	_assert_eq(board_silver.rarity, BazaarContentClass.RARITY_GOLD, "board Silver Venom becomes Gold after cascade")
	_assert_eq(stash.get_item_count(), 0, "lower-priority stash item is consumed by cascade")

func test_shop_filter_uses_owned_rarity_floor_and_diamond_block() -> void:
	var gold_venom: ItemDataClass = BazaarContentClass.create_item("venom", BazaarContentClass.RARITY_GOLD)
	_assert_true(not BazaarContentClass.is_shop_candidate_allowed("venom", BazaarContentClass.RARITY_BRONZE, [gold_venom]), "shop hides Bronze below owned Gold")
	_assert_true(not BazaarContentClass.is_shop_candidate_allowed("venom", BazaarContentClass.RARITY_SILVER, [gold_venom]), "shop hides Silver below owned Gold")
	_assert_true(BazaarContentClass.is_shop_candidate_allowed("venom", BazaarContentClass.RARITY_GOLD, [gold_venom]), "shop may offer same rarity for merging")

	var silver_venom: ItemDataClass = BazaarContentClass.create_item("venom", BazaarContentClass.RARITY_SILVER)
	_assert_true(BazaarContentClass.is_shop_candidate_allowed("venom", BazaarContentClass.RARITY_SILVER, [gold_venom, silver_venom]), "lower event/drop copy reopens that rarity in shop")

	var diamond_venom: ItemDataClass = BazaarContentClass.create_item("venom", BazaarContentClass.RARITY_DIAMOND)
	_assert_true(not BazaarContentClass.is_shop_candidate_allowed("venom", BazaarContentClass.RARITY_DIAMOND, [diamond_venom]), "shop blocks item id once Diamond is owned")

func test_start_of_day_mortar_grants_catalyst_from_stash() -> void:
	var inventory: LinearInventoryClass = LinearInventoryClass.new()
	var stash: LinearInventoryClass = LinearInventoryClass.new()
	var mortar: ItemDataClass = BazaarContentClass.create_item("mortar_pestle", BazaarContentClass.RARITY_BRONZE)
	_assert_true(stash.place_item(mortar, 0), "test setup places Mortar & Pestle in stash")

	var summary: Dictionary = ItemAcquisitionClass.grant_start_of_day_items(inventory, stash)
	var catalyst: ItemDataClass = inventory.get_item_at(0)

	_assert_eq(int(summary.get("catalysts", 0)), 1, "one Mortar & Pestle grants one Catalyst at day start")
	_assert_true(catalyst != null and catalyst.source_id == "catalyst", "Catalyst is granted into available board space")

func test_hour_start_hooks_cover_expanded_catalyst_generators() -> void:
	for item_id in ["aludel", "sifting_pan", "laboratory", "athanor"]:
		var inventory: LinearInventoryClass = LinearInventoryClass.new()
		var stash: LinearInventoryClass = LinearInventoryClass.new()
		var item: ItemDataClass = BazaarContentClass.create_item(item_id, BazaarContentClass.RARITY_SILVER)
		_assert_true(stash.place_item(item, 0), "test setup places %s in stash" % item_id)

		var summary: Dictionary = ItemAcquisitionClass.apply_hour_start_hooks(inventory, stash, "test_hour_start")

		_assert_eq(int(summary.get("catalysts", 0)), 1, "%s grants Catalyst from hour-start hook" % item_id)
		_assert_eq(int(summary.get("failed", 0)), 0, "%s generated item fits inventory" % item_id)

func test_on_buy_philosophers_stone_grants_catalyst() -> void:
	var inventory: LinearInventoryClass = LinearInventoryClass.new()
	var stone: ItemDataClass = BazaarContentClass.create_item("philosophers_stone", BazaarContentClass.RARITY_BRONZE)
	_assert_true(inventory.place_item(stone, 0), "test setup places Philosopher's Stone")

	var summary: Dictionary = ItemAcquisitionClass.apply_on_buy_hooks(stone, inventory)
	var granted: ItemDataClass = inventory.get_item_at(1)

	_assert_eq((summary.get("items", []) as Array).size(), 1, "on-buy hook records one generated item")
	_assert_true(granted != null and granted.source_id == "catalyst", "Philosopher's Stone on-buy grants Catalyst through acquisition service")

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
