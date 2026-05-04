extends Node

const BazaarContentClass = preload("res://scripts/data/bazaar_content.gd")
const EffectDefinitionClass = preload("res://scripts/data/effect_definition.gd")
const EnchantmentCatalogClass = preload("res://scripts/data/enchantment_catalog.gd")
const ItemAcquisitionClass = preload("res://scripts/data/item_acquisition.gd")
const LinearInventoryClass = preload("res://scripts/data/linear_inventory.gd")
const SellServiceClass = preload("res://scripts/services/sell_service.gd")

var _total: int = 0
var _passed: int = 0

func _ready() -> void:
	if not Engine.is_editor_hint():
		print("== tests/test_item_effect_noncombat_hooks.gd ==")
		_run_tests()
		_print_summary()

func _run_tests() -> void:
	test_on_buy_hooks_mutate_income_items_and_observers()
	test_hour_start_hooks_grant_transform_spend_and_upgrade()
	test_on_sell_hooks_mutate_stats_durations_services_and_types()
	test_on_transform_and_on_enchant_hooks_mutate_item_state()
	test_p1b_reachable_trigger_warnings_are_reduced()

func test_on_buy_hooks_mutate_income_items_and_observers() -> void:
	GameManager.call("reset_stats")
	var inventory: LinearInventoryClass = LinearInventoryClass.new()
	var atm = BazaarContentClass.create_item("atm", BazaarContentClass.RARITY_SILVER)
	_assert_true(inventory.place_item(atm, 0), "places ATM")
	var atm_summary: Dictionary = ItemAcquisitionClass.apply_on_buy_hooks(atm, inventory)
	_assert_eq(int(atm_summary.get("income", 0)), 2, "ATM on-buy records rarity-scaled Income")
	_assert_eq(int(EconomyService.get("income")), 9, "ATM on-buy mutates EconomyService Income")

	var hatchet = BazaarContentClass.create_item("hatchet", BazaarContentClass.RARITY_BRONZE)
	_assert_true(inventory.place_item(hatchet, 2), "places Hatchet")
	var hatchet_summary: Dictionary = ItemAcquisitionClass.apply_on_buy_hooks(hatchet, inventory)
	_assert_true(_summary_has_item(hatchet_summary, "truffles"), "Hatchet on-buy grants Truffles")

	var lightbulb_inventory: LinearInventoryClass = LinearInventoryClass.new()
	var lightbulb = BazaarContentClass.create_item("lightbulb", BazaarContentClass.RARITY_SILVER)
	_assert_true(lightbulb_inventory.place_item(lightbulb, 0), "places Lightbulb")
	var lightbulb_summary: Dictionary = ItemAcquisitionClass.apply_on_buy_hooks(lightbulb, lightbulb_inventory)
	_assert_true(_summary_has_item(lightbulb_summary, "battery"), "Lightbulb on-buy grants a deterministic small Tech item")

	var satchel_inventory: LinearInventoryClass = LinearInventoryClass.new()
	var satchel = BazaarContentClass.create_item("satchel", BazaarContentClass.RARITY_GOLD)
	var potion = BazaarContentClass.create_item("fire_potion", BazaarContentClass.RARITY_BRONZE)
	_assert_true(satchel_inventory.place_item(satchel, 0), "places Satchel")
	_assert_true(satchel_inventory.place_item(potion, 2), "places purchased Potion")
	var before_regen: float = satchel.regeneration
	var satchel_summary: Dictionary = ItemAcquisitionClass.apply_on_buy_hooks(potion, satchel_inventory)
	_assert_true(satchel.regeneration > before_regen, "Satchel observes Potion buys and permanently gains Regen")
	_assert_eq((satchel_summary.get("stat_mutations", []) as Array).size(), 1, "Satchel on-buy observer records stat mutation")

func test_hour_start_hooks_grant_transform_spend_and_upgrade() -> void:
	GameManager.call("reset_stats")
	var alembic_inventory: LinearInventoryClass = LinearInventoryClass.new()
	var reagent = BazaarContentClass.create_item("hemlock", BazaarContentClass.RARITY_BRONZE)
	var alembic = BazaarContentClass.create_item("alembic", BazaarContentClass.RARITY_SILVER)
	_assert_true(alembic_inventory.place_item(reagent, 0), "places Alembic transform target")
	_assert_true(alembic_inventory.place_item(alembic, 1), "places Alembic")
	var alembic_summary: Dictionary = ItemAcquisitionClass.apply_hour_start_hooks(alembic_inventory, null, "test_alembic")
	_assert_true(_summary_has_item(alembic_summary, "catalyst"), "Alembic hour-start grants Catalyst")
	_assert_eq((alembic_summary.get("transforms", []) as Array).size(), 1, "Alembic transforms the small item to its left")
	_assert_eq(alembic_inventory.get_item_at(0).source_id, "fire_potion", "Alembic replacement is deterministic Potion")

	var spend_inventory: LinearInventoryClass = LinearInventoryClass.new()
	var calcinator = BazaarContentClass.create_item("calcinator", BazaarContentClass.RARITY_BRONZE)
	_assert_true(spend_inventory.place_item(calcinator, 0), "places Calcinator")
	var gold_before: int = int(EconomyService.get("gold"))
	var spend_summary: Dictionary = ItemAcquisitionClass.apply_hour_start_hooks(spend_inventory, null, "test_calcinator")
	_assert_eq(int(spend_summary.get("spent_gold", 0)), 3, "Calcinator spends Gold at hour start")
	_assert_eq(int(EconomyService.get("gold")), gold_before - 3, "Calcinator mutates EconomyService Gold")
	_assert_true(_summary_has_item(spend_summary, "chunk_of_lead"), "Calcinator grants Chunk of Lead after spending")

	var tome_inventory: LinearInventoryClass = LinearInventoryClass.new()
	_assert_true(tome_inventory.place_item(BazaarContentClass.create_item("the_tome_of_yyahan", BazaarContentClass.RARITY_SILVER), 0), "places Tome")
	var tome_summary: Dictionary = ItemAcquisitionClass.apply_hour_start_hooks(tome_inventory, null, "test_tome")
	_assert_true(_summary_has_item(tome_summary, "hemlock"), "Tome hour-start grants a small Reagent")

	var tropical_inventory: LinearInventoryClass = LinearInventoryClass.new()
	_assert_true(tropical_inventory.place_item(BazaarContentClass.create_item("tropical_island", BazaarContentClass.RARITY_GOLD), 0), "places Tropical Island")
	var tropical_summary: Dictionary = ItemAcquisitionClass.apply_hour_start_hooks(tropical_inventory, null, "test_tropical")
	_assert_true(_summary_has_item(tropical_summary, "coconut"), "Tropical Island hour-start grants Coconut deterministically")

	var piggles_inventory: LinearInventoryClass = LinearInventoryClass.new()
	var piggles = BazaarContentClass.create_item("piggles", BazaarContentClass.RARITY_BRONZE)
	_assert_true(piggles_inventory.place_item(piggles, 0), "places Piggles")
	var piggles_summary: Dictionary = ItemAcquisitionClass.apply_hour_start_hooks(piggles_inventory, null, "test_piggles")
	_assert_eq(piggles.rarity, BazaarContentClass.RARITY_SILVER, "Piggles hour-start upgrades a Piggle")
	_assert_eq((piggles_summary.get("upgrades", []) as Array).size(), 1, "Piggles hour-start records upgrade")

func test_on_sell_hooks_mutate_stats_durations_services_and_types() -> void:
	GameManager.call("reset_stats")
	RunStateService.reset()
	var inventory: LinearInventoryClass = LinearInventoryClass.new()
	var target = BazaarContentClass.create_item("fang", BazaarContentClass.RARITY_BRONZE)
	target.cooldown = 10.0
	var feather = BazaarContentClass.create_item("feather", BazaarContentClass.RARITY_SILVER)
	_assert_true(inventory.place_item(target, 0), "places cooldown target")
	_assert_true(inventory.place_item(feather, 1), "places Feather")
	_assert_true(bool(SellServiceClass.sell_item(feather, inventory).get("success", false)), "Feather sell succeeds")
	_assert_true(target.cooldown < 10.0, "Feather reduces leftmost item Cooldown")

	var duration_inventory: LinearInventoryClass = LinearInventoryClass.new()
	var slow_item = BazaarContentClass.create_item("honey_jar", BazaarContentClass.RARITY_BRONZE)
	var haste_item = BazaarContentClass.create_item("energy_potion", BazaarContentClass.RARITY_SILVER)
	var freeze_item = BazaarContentClass.create_item("frost_potion", BazaarContentClass.RARITY_SILVER)
	var bludgeon = BazaarContentClass.create_item("improvised_bludgeon", BazaarContentClass.RARITY_BRONZE)
	var boots = BazaarContentClass.create_item("rocket_boots", BazaarContentClass.RARITY_BRONZE)
	var snowflake = BazaarContentClass.create_item("snowflake", BazaarContentClass.RARITY_DIAMOND)
	_assert_true(duration_inventory.place_item(slow_item, 0), "places Slow item")
	_assert_true(duration_inventory.place_item(haste_item, 1), "places Haste item")
	_assert_true(duration_inventory.place_item(freeze_item, 2), "places Freeze item")
	_assert_true(duration_inventory.place_item(bludgeon, 3), "places Bludgeon")
	_assert_true(duration_inventory.place_item(boots, 5), "places Rocket Boots")
	_assert_true(duration_inventory.place_item(snowflake, 7), "places Snowflake")
	var slow_before: float = slow_item.slow_duration
	var haste_before: float = haste_item.haste_duration
	var freeze_before: float = freeze_item.freeze_duration
	SellServiceClass.sell_item(bludgeon, duration_inventory)
	SellServiceClass.sell_item(boots, duration_inventory)
	SellServiceClass.sell_item(snowflake, duration_inventory)
	_assert_true(slow_item.slow_duration > slow_before, "Improvised Bludgeon sell increases Slow duration")
	_assert_true(haste_item.haste_duration > haste_before, "Rocket Boots sell increases Haste duration")
	_assert_true(freeze_item.freeze_duration > freeze_before, "Snowflake sell increases Freeze duration")

	var service_inventory: LinearInventoryClass = LinearInventoryClass.new()
	var lamp = BazaarContentClass.create_item("genie_lamp", BazaarContentClass.RARITY_DIAMOND)
	var medallion = BazaarContentClass.create_item("thieves_guild_medallion", BazaarContentClass.RARITY_DIAMOND)
	_assert_true(service_inventory.place_item(lamp, 0), "places Genie Lamp")
	_assert_true(service_inventory.place_item(medallion, 1), "places Thieves Guild Medallion")
	SellServiceClass.sell_item(lamp, service_inventory)
	SellServiceClass.sell_item(medallion, service_inventory)
	var unlocks: Dictionary = RunStateService.get_service_unlocks()
	_assert_eq(int(unlocks.get("genie_rit", 0)), 1, "Genie Lamp sell unlocks Genie service state")
	_assert_eq(int(unlocks.get("thieves_guild", 0)), 1, "Thieves Guild Medallion sell unlocks service state")

	var vat_inventory: LinearInventoryClass = LinearInventoryClass.new()
	var vat = BazaarContentClass.create_item("vat_of_acid", BazaarContentClass.RARITY_SILVER)
	var weapon = BazaarContentClass.create_item("fang", BazaarContentClass.RARITY_BRONZE)
	_assert_true(vat_inventory.place_item(vat, 0), "places Vat of Acid")
	_assert_true(vat_inventory.place_item(weapon, 3), "places sold Weapon")
	SellServiceClass.sell_item(weapon, vat_inventory)
	_assert_true(_has_tag(vat, "Weapon"), "Vat of Acid gains sold item type tag")

func test_on_transform_and_on_enchant_hooks_mutate_item_state() -> void:
	var inventory: LinearInventoryClass = LinearInventoryClass.new()
	var catalyst = BazaarContentClass.create_item("catalyst", BazaarContentClass.RARITY_BRONZE)
	var reagent = BazaarContentClass.create_item("hemlock", BazaarContentClass.RARITY_BRONZE)
	var stone = BazaarContentClass.create_item("philosophers_stone", BazaarContentClass.RARITY_GOLD)
	_assert_true(inventory.place_item(catalyst, 0), "places Catalyst")
	_assert_true(inventory.place_item(reagent, 1), "places Reagent")
	_assert_true(inventory.place_item(stone, 2), "places Philosopher's Stone observer")
	var regen_before: float = stone.regeneration
	var transform_result: Dictionary = SellServiceClass.sell_item(catalyst, inventory)
	_assert_true(bool(transform_result.get("success", false)), "Catalyst transform succeeds")
	_assert_true(stone.regeneration > regen_before, "Philosopher's Stone observes Reagent transform and gains Regen")

	var enchanted = BazaarContentClass.create_item("fang", BazaarContentClass.RARITY_BRONZE)
	var damage_before: int = enchanted.damage
	EnchantmentCatalogClass.apply_to_item(enchanted, "heavy")
	_assert_eq(enchanted.enchantment_id, "heavy", "EnchantmentCatalog mutates enchantment state")
	_assert_true(enchanted.damage > damage_before, "Heavy enchant mutates item stats")
	_assert_true(_has_effect_trigger(enchanted, EffectDefinitionClass.TRIGGER_ON_ENCHANT), "enchanted item records on_enchant definition")

func test_p1b_reachable_trigger_warnings_are_reduced() -> void:
	var report: Dictionary = BazaarContentClass.get_reachable_item_effect_coverage_report()
	var families: Dictionary = report.get("warning_family_counts", {})
	_assert_true(int(families.get("unsupported_item_trigger:on_sell", 0)) < 13, "P1B reduces reachable on_sell warning count")
	_assert_true(int(families.get("unsupported_item_trigger:on_buy", 0)) < 4, "P1B reduces reachable on_buy warning count")
	_assert_true(int(families.get("unsupported_item_trigger:on_hour_start", 0)) < 7, "P1B reduces reachable hour-start warning count")
	_assert_true(int(families.get("unsupported_item_trigger:on_transform", 0)) < 1, "P1B closes reachable on_transform warning count")

func _summary_has_item(summary: Dictionary, item_id: String) -> bool:
	for entry in summary.get("items", []):
		if entry is Dictionary and str((entry as Dictionary).get("id", "")) == item_id:
			return true
	return false

func _has_effect_trigger(item, trigger: String) -> bool:
	for definition in item.effects:
		if definition is Dictionary and str((definition as Dictionary).get("trigger", "")) == trigger:
			return true
	return false

func _has_tag(item, tag: String) -> bool:
	for item_tag in item.tags:
		if str(item_tag).to_lower() == tag.to_lower():
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
