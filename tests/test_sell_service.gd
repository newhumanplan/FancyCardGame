extends Node

const BazaarContentClass = preload("res://scripts/data/bazaar_content.gd")
const EffectDefinitionClass = preload("res://scripts/data/effect_definition.gd")
const ItemDataClass = preload("res://scripts/data/item_data.gd")
const LinearInventoryClass = preload("res://scripts/data/linear_inventory.gd")
const SellServiceClass = preload("res://scripts/services/sell_service.gd")

var _total: int = 0
var _passed: int = 0

func _ready() -> void:
	if not Engine.is_editor_hint():
		print("== tests/test_sell_service.gd ==")
		_run_tests()
		_print_summary()

func _run_tests() -> void:
	test_sell_price_respects_explicit_value_and_no_base_value_rules()
	test_sell_service_removes_item_and_adds_gold()
	test_catalyst_sale_transforms_leftmost_small_item()
	test_catalyst_sale_transforms_reagent_and_applies_enchant_observers()
	test_sell_loot_hooks_mutate_leftmost_eligible_items_and_run_state()
	test_effect_definitions_record_non_combat_hooks_and_warnings()
	test_inventory_ui_sell_button_uses_sell_service()

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

func test_sell_price_respects_explicit_value_and_no_base_value_rules() -> void:
	var spare_change = BazaarContentClass.create_item("spare_change", BazaarContentClass.RARITY_BRONZE)
	var chocolate_bar = BazaarContentClass.create_item("chocolate_bar", BazaarContentClass.RARITY_BRONZE)
	var fang = BazaarContentClass.create_item("fang", BazaarContentClass.RARITY_BRONZE)

	_assert_eq(SellServiceClass.calculate_sell_price(spare_change), 1, "explicit sell-value item uses wiki worth value")
	_assert_eq(SellServiceClass.calculate_sell_price(chocolate_bar), 0, "no-base-value item sells for zero")
	_assert_eq(SellServiceClass.calculate_sell_price(fang), fang.buy_price, "normal item sells for its current base value")

func test_sell_service_removes_item_and_adds_gold() -> void:
	var inventory: LinearInventoryClass = LinearInventoryClass.new()
	var fang = BazaarContentClass.create_item("fang", BazaarContentClass.RARITY_BRONZE)
	_assert_true(inventory.place_item(fang, 0), "places Fang for sell test")
	GameManager.call("reset_stats")
	GameManager.set("gold", 10)

	var result: Dictionary = SellServiceClass.sell_item(fang, inventory)

	_assert_true(bool(result.get("success", false)), "sell service reports success")
	_assert_eq(inventory.get_item_count(), 0, "sold item is removed from inventory")
	_assert_eq(int(GameManager.get("gold")), 12, "selling adds gold using sell service rule")

func test_catalyst_sale_transforms_leftmost_small_item() -> void:
	var inventory: LinearInventoryClass = LinearInventoryClass.new()
	var catalyst = BazaarContentClass.create_item("catalyst", BazaarContentClass.RARITY_BRONZE)
	var original = BazaarContentClass.create_item("fang", BazaarContentClass.RARITY_BRONZE)
	_assert_true(inventory.place_item(catalyst, 0), "places Catalyst")
	_assert_true(inventory.place_item(original, 1), "places sell target")
	GameManager.call("reset_stats")

	var result: Dictionary = SellServiceClass.sell_item(catalyst, inventory)
	var transformed = inventory.get_item_at(1)

	_assert_true(bool(result.get("success", false)), "catalyst sale succeeds")
	_assert_eq(inventory.get_item_count(), 1, "catalyst is removed while transformed item remains")
	_assert_true(transformed != null and transformed != original, "catalyst replaces the leftmost small item with a new item instance")

func test_catalyst_sale_transforms_reagent_and_applies_enchant_observers() -> void:
	var inventory: LinearInventoryClass = LinearInventoryClass.new()
	var catalyst = BazaarContentClass.create_item("catalyst", BazaarContentClass.RARITY_BRONZE)
	var reagent = BazaarContentClass.create_item("hemlock", BazaarContentClass.RARITY_BRONZE)
	var calcinator = BazaarContentClass.create_item("calcinator", BazaarContentClass.RARITY_BRONZE)
	var retort = BazaarContentClass.create_item("retort", BazaarContentClass.RARITY_BRONZE)
	_assert_true(inventory.place_item(catalyst, 0), "places Catalyst for Reagent transform")
	_assert_true(inventory.place_item(reagent, 1), "places Reagent as transform target")
	_assert_true(inventory.place_item(calcinator, 2), "places Calcinator observer")
	_assert_true(inventory.place_item(retort, 5), "places Retort observer")
	var calcinator_burn: float = calcinator.burn_damage
	var retort_poison: float = retort.poison_damage

	var result: Dictionary = SellServiceClass.sell_item(catalyst, inventory)
	var transformed = inventory.get_item_at(1)

	_assert_true(bool(result.get("success", false)), "catalyst sale succeeds for Reagent transform")
	_assert_true(not (transformed == null), "Reagent transform leaves a replacement item")
	_assert_eq(str(((result.get("transforms", []) as Array)[0] as Dictionary).get("target_id", "")), "hemlock", "transform result records original Reagent id")
	_assert_eq(str(((result.get("transforms", []) as Array)[0] as Dictionary).get("enchantment", "")), "toxic", "Reagent transform applies mapped enchantment")
	_assert_true(transformed.enchantment_id == "toxic", "replacement item receives Toxic enchantment")
	_assert_true(_has_effect_trigger(transformed, EffectDefinitionClass.TRIGGER_ON_ENCHANT), "enchanted replacement records on_enchant trigger")
	_assert_true(calcinator.burn_damage > calcinator_burn, "Calcinator gains Burn when a Reagent transforms")
	_assert_true(retort.poison_damage > retort_poison, "Retort gains Poison when a Reagent transforms")
	_assert_true((result.get("effects_applied", []) as Array).has("reagent_transformed:hemlock:Bronze"), "transform trace records reagent source and rarity")

func test_sell_loot_hooks_mutate_leftmost_eligible_items_and_run_state() -> void:
	RunStateService.reset()
	var inventory: LinearInventoryClass = LinearInventoryClass.new()
	var cinders = BazaarContentClass.create_item("cinders", BazaarContentClass.RARITY_BRONZE)
	var extract = BazaarContentClass.create_item("extract", BazaarContentClass.RARITY_BRONZE)
	var scrap = BazaarContentClass.create_item("scrap", BazaarContentClass.RARITY_BRONZE)
	var med_kit = BazaarContentClass.create_item("med_kit", BazaarContentClass.RARITY_BRONZE)
	var eagle = BazaarContentClass.create_item("eagle_talisman", BazaarContentClass.RARITY_BRONZE)
	var gland = BazaarContentClass.create_item("gland", BazaarContentClass.RARITY_BRONZE)
	var fire_potion = BazaarContentClass.create_item("fire_potion", BazaarContentClass.RARITY_BRONZE)
	var venom = BazaarContentClass.create_item("venom", BazaarContentClass.RARITY_BRONZE)
	var duct_tape = BazaarContentClass.create_item("duct_tape", BazaarContentClass.RARITY_BRONZE)
	var hot_springs = BazaarContentClass.create_item("bluenanas", BazaarContentClass.RARITY_BRONZE)
	_assert_true(inventory.place_item(cinders, 0), "places Cinders")
	_assert_true(inventory.place_item(extract, 1), "places Extract")
	_assert_true(inventory.place_item(scrap, 2), "places Scrap")
	_assert_true(inventory.place_item(med_kit, 3), "places Med Kit")
	_assert_true(inventory.place_item(eagle, 4), "places Eagle Talisman")
	_assert_true(inventory.place_item(gland, 5), "places Gland")
	_assert_true(inventory.place_item(fire_potion, 6), "places Burn item")
	_assert_true(inventory.place_item(venom, 7), "places Poison item")
	_assert_true(inventory.place_item(duct_tape, 8), "places Shield item")
	_assert_true(inventory.place_item(hot_springs, 9), "places Heal item")
	var fire_burn: float = fire_potion.burn_damage
	var venom_poison: float = venom.poison_damage
	var duct_shield: int = duct_tape.shield
	var hot_heal: int = hot_springs.heal
	var gland_crit: float = gland.crit_chance

	_assert_true(bool(SellServiceClass.sell_item(cinders, inventory).get("success", false)), "Cinders sell succeeds")
	_assert_true(bool(SellServiceClass.sell_item(extract, inventory).get("success", false)), "Extract sell succeeds")
	_assert_true(bool(SellServiceClass.sell_item(scrap, inventory).get("success", false)), "Scrap sell succeeds")
	_assert_true(bool(SellServiceClass.sell_item(med_kit, inventory).get("success", false)), "Med Kit sell succeeds")
	_assert_true(bool(SellServiceClass.sell_item(eagle, inventory).get("success", false)), "Eagle Talisman sell succeeds")
	_assert_true(bool(SellServiceClass.sell_item(gland, inventory).get("success", false)), "Gland sell succeeds")

	_assert_true(fire_potion.burn_damage > fire_burn, "Cinders grants Burn to leftmost Burn item")
	_assert_true(venom.poison_damage > venom_poison, "Extract grants Poison to leftmost Poison item")
	_assert_true(duct_tape.shield > duct_shield, "Scrap grants Shield to leftmost Shield item")
	_assert_true(hot_springs.heal > hot_heal, "Med Kit grants Heal to leftmost Heal item")
	_assert_true(gland.crit_chance > gland_crit, "Eagle Talisman grants Crit to leftmost remaining item")
	_assert_eq(int(RunStateService.get_battle_start_status_bonuses().get("regeneration", 0.0)), 1, "Gland sell stores Regen as battle-start run state")

func test_effect_definitions_record_non_combat_hooks_and_warnings() -> void:
	var catalyst = BazaarContentClass.create_item("catalyst", BazaarContentClass.RARITY_BRONZE)
	var hemlock = BazaarContentClass.create_item("hemlock", BazaarContentClass.RARITY_BRONZE)
	var philosophers_stone = BazaarContentClass.create_item("philosophers_stone", BazaarContentClass.RARITY_BRONZE)
	_assert_true(_has_effect_trigger(catalyst, EffectDefinitionClass.TRIGGER_ON_SELL), "Catalyst records on_sell trigger")
	_assert_true(_has_effect_trigger(hemlock, EffectDefinitionClass.TRIGGER_ON_TRANSFORM), "Hemlock records on_transform trigger")
	_assert_true(_has_effect_trigger(philosophers_stone, EffectDefinitionClass.TRIGGER_ON_BUY), "Philosopher's Stone records on_buy trigger")

	var unsupported = ItemDataClass.new()
	unsupported.source_id = "unsupported_transform_fixture"
	unsupported.source_effect_text = "When this is transformed, do something unknown."
	var warnings: Array[String] = EffectDefinitionClass.collect_item_warnings(unsupported, [])
	_assert_true(warnings.has("unsupported_item_trigger:unsupported_transform_fixture:on_transform"), "unsupported transform text is surfaced as warning")

func _has_effect_trigger(item: ItemDataClass, trigger: String) -> bool:
	for definition in item.effects:
		if definition is Dictionary and str((definition as Dictionary).get("trigger", "")) == trigger:
			return true
	return false

func test_inventory_ui_sell_button_uses_sell_service() -> void:
	var scene: PackedScene = load("res://scenes/inventory_ui.tscn")
	var inventory_ui: Control = scene.instantiate() as Control
	add_child(inventory_ui)
	var inventory: LinearInventoryClass = LinearInventoryClass.new()
	var fang = BazaarContentClass.create_item("fang", BazaarContentClass.RARITY_BRONZE)
	_assert_true(inventory.place_item(fang, 0), "places Fang in InventoryUI")
	inventory_ui.call("set_inventory", inventory)
	GameManager.call("reset_stats")
	GameManager.set("gold", 0)

	inventory_ui.call("_show_item_detail", fang)
	var detail_panel: Control = inventory_ui.get("detail_panel") as Control
	var sell_button: Button = detail_panel.find_child("SellButton", true, false) as Button
	_assert_true(sell_button != null, "inventory detail panel exposes a sell button")
	if sell_button != null:
		sell_button.emit_signal("pressed")

	_assert_eq(inventory.get_item_count(), 0, "InventoryUI sell button removes the item through SellService")
	_assert_eq(int(GameManager.get("gold")), 2, "InventoryUI sell button updates gold via SellService")
