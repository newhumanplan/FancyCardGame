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
		print("== tests/test_full_content_parity_p2b_item_effect_families.gd ==")
		test_p2b_item_effect_family_reasons_are_resolved()
		test_charge_and_multicast_definitions_are_explicit()
		test_charge_family_reactive_triggers()
		test_multicast_family_counts_source_backed_amounts()
		_print_summary()

func test_p2b_item_effect_family_reasons_are_resolved() -> void:
	var report: Dictionary = BazaarContentClass.get_all_monster_parity_report()
	var reason_counts: Dictionary = report.get("grouped_missing_mechanics", {}).get("reason_counts", {})
	for reason in [
		"item:blk_sp1d3r:unsupported_item_effect:blk_sp1d3r:charge",
		"item:dooltron:unsupported_item_effect:dooltron:charge",
		"item:dragon_wing:unsupported_item_effect:dragon_wing:charge",
		"item:guardian_shell:unsupported_item_effect:guardian_shell:charge",
		"item:knife_set:unsupported_item_effect:knife_set:charge",
		"item:lumboars:unsupported_item_effect:lumboars:multicast",
		"item:micro_dave:unsupported_item_effect:micro_dave:charge",
		"item:plasma_rifle:unsupported_item_effect:plasma_rifle:charge",
		"item:rocket_launcher:unsupported_item_effect:rocket_launcher:multicast",
		"item:snow_globe:unsupported_item_effect:snow_globe:multicast",
		"item:throwing_knives:unsupported_item_effect:throwing_knives:charge",
		"item:z_sword:unsupported_item_effect:z_sword:multicast",
	]:
		_assert_true(not reason_counts.has(reason), "P2B item-effect residual reason resolved: %s" % reason)

func test_charge_and_multicast_definitions_are_explicit() -> void:
	var expected_ids := {
		"blk_sp1d3r": ["blk_sp1d3r_on_enemy_status_applied_charge"],
		"dive_weights": ["dive_weights_on_cooldown_ready_multicast", "dive_weights_on_battle_start_runtime_bonus"],
		"dooltron": ["dooltron_on_enemy_status_applied_charge", "dooltron_on_tag_used_shield"],
		"dragon_wing": ["dragon_wing_on_enemy_status_applied_charge"],
		"flagship": ["flagship_on_cooldown_ready_multicast"],
		"guardian_shell": ["guardian_shell_on_enemy_status_applied_charge"],
		"illusoray": ["illusoray_on_cooldown_ready_multicast"],
		"knife_set": ["knife_set_on_tag_used_charge"],
		"lumboars": ["lumboars_on_cooldown_ready_multicast", "lumboars_on_cooldown_ready_runtime_bonus"],
		"micro_dave": ["micro_dave_on_item_used_charge"],
		"plasma_rifle": ["plasma_rifle_on_enemy_status_applied_charge", "plasma_rifle_on_enemy_status_applied_runtime_bonus"],
		"rocket_launcher": ["rocket_launcher_on_cooldown_ready_multicast"],
		"snow_globe": ["snow_globe_on_cooldown_ready_multicast"],
		"throwing_knives": ["throwing_knives_on_crit_charge"],
		"z_sword": ["z_sword_on_cooldown_ready_multicast"],
	}
	for item_id in expected_ids.keys():
		var item: ItemDataClass = _create_item(str(item_id), BazaarContentClass.RARITY_GOLD)
		var ids: Array[String] = _definition_ids(item)
		for definition_id in expected_ids[item_id]:
			_assert_true(ids.has(str(definition_id)), "%s has %s" % [item_id, str(definition_id)])

func test_charge_family_reactive_triggers() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var knife_set: ItemDataClass = _create_charged_item("knife_set")
	var fang: ItemDataClass = _create_item("fang")
	var blk_sp1d3r: ItemDataClass = _create_charged_item("blk_sp1d3r")
	var guardian_shell: ItemDataClass = _create_charged_item("guardian_shell")
	var plasma_rifle: ItemDataClass = _create_charged_item("plasma_rifle")
	var throwing_knives: ItemDataClass = _create_charged_item("throwing_knives")
	_assert_true(inv.place_item(knife_set, 0), "places Knife Set")
	_assert_true(inv.place_item(fang, 2), "places Fang")
	_assert_true(inv.place_item(blk_sp1d3r, 3), "places BLK-SP1D3R")
	_assert_true(inv.place_item(guardian_shell, 4), "places Guardian Shell")
	_assert_true(inv.place_item(plasma_rifle, 6), "places Plasma Rifle")
	_assert_true(inv.place_item(throwing_knives, 8), "places Throwing Knives")
	_start_battle(inv, "P2B Charge Family Test")
	for charged_item in [knife_set, blk_sp1d3r, guardian_shell, plasma_rifle, throwing_knives]:
		(charged_item as ItemDataClass).current_cooldown = 10.0

	_process_event(EffectDefinitionClass.TRIGGER_ON_TAG_USED, fang)
	_assert_float_eq(knife_set.current_cooldown, 8.0, "Knife Set charges 2 seconds when a Weapon is used")
	_process_event(EffectDefinitionClass.TRIGGER_ON_ENEMY_STATUS_APPLIED, fang, {"status_type": EffectDefinitionClass.EFFECT_POISON})
	_assert_float_eq(blk_sp1d3r.current_cooldown, 9.0, "BLK-SP1D3R charges from adjacent Poison")
	_assert_float_eq(guardian_shell.current_cooldown, 9.0, "Guardian Shell charges from Poison")
	_process_event(EffectDefinitionClass.TRIGGER_ON_ENEMY_STATUS_APPLIED, fang, {"status_type": EffectDefinitionClass.EFFECT_BURN})
	_assert_float_eq(plasma_rifle.current_cooldown, 9.0, "Plasma Rifle charges from Burn")
	_assert_float_eq(_item_runtime_bonus(plasma_rifle, EffectDefinitionClass.EFFECT_DAMAGE), 60.0, "Plasma Rifle gains Gold Damage from Burn")
	_process_event(EffectDefinitionClass.TRIGGER_ON_CRIT, fang)
	_assert_float_eq(throwing_knives.current_cooldown, 7.0, "Throwing Knives charges 3 seconds from another item Crit at Gold")
	_battle_system().call("end_battle")

func test_multicast_family_counts_source_backed_amounts() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var rocket_launcher: ItemDataClass = _create_item("rocket_launcher")
	var lumboars: ItemDataClass = _create_item("lumboars")
	var flagship: ItemDataClass = _create_item("flagship")
	var dive_weights_tool: ItemDataClass = _create_item("dive_weights")
	var snow_globe_property: ItemDataClass = _create_item("snow_globe")
	_assert_true(inv.place_item(rocket_launcher, 0), "places Rocket Launcher")
	_assert_true(inv.place_item(lumboars, 2), "places Lumboars")
	_assert_true(inv.place_item(flagship, 4), "places Flagship")
	_assert_true(inv.place_item(dive_weights_tool, 7), "places Tool item")
	_assert_true(inv.place_item(snow_globe_property, 8), "places Property item")
	_start_battle(inv, "P2B Multicast Family Test")
	_assert_eq(_multicast_count(rocket_launcher), 3, "Rocket Launcher Multicast: 3 is two extra casts")
	_assert_eq(_multicast_count(lumboars), 2, "Lumboars Multicast: 2 is one extra cast")
	_assert_eq(_multicast_count(flagship), 3, "Flagship gets +1 Multicast for each other in-board Tool, Property, Friend, or Ammo item")
	_assert_true(_trace_has("rocket_launcher_on_cooldown_ready_multicast"), "Rocket Launcher multicast trace executes")
	_assert_true(_trace_has("lumboars_on_cooldown_ready_multicast"), "Lumboars multicast trace executes")
	_assert_true(_trace_has("flagship_on_cooldown_ready_multicast"), "Flagship multicast trace executes")
	_battle_system().call("end_battle")

	var inv2: LinearInventoryClass = LinearInventoryClass.new()
	var piranha: ItemDataClass = _create_item("piranha")
	var illusoray: ItemDataClass = _create_item("illusoray")
	var void_ray: ItemDataClass = _create_item("void_ray")
	_assert_true(inv2.place_item(piranha, 0), "places adjacent Friend")
	_assert_true(inv2.place_item(illusoray, 1), "places IllusoRay")
	_assert_true(inv2.place_item(void_ray, 2), "places adjacent Ray")
	_start_battle(inv2, "P2B IllusoRay Multicast Test")
	_assert_eq(_multicast_count(illusoray), 3, "IllusoRay gets +1 Multicast for each adjacent Friend or Ray")
	_battle_system().call("end_battle")

	var inv3: LinearInventoryClass = LinearInventoryClass.new()
	var snow_globe: ItemDataClass = _create_item("snow_globe")
	var property: ItemDataClass = _create_item("poppy_field")
	_assert_true(inv3.place_item(snow_globe, 0), "places Snow Globe")
	_assert_true(inv3.place_item(property, 2), "places adjacent Property")
	_start_battle(inv3, "P2B Snow Globe Multicast Test")
	_assert_eq(_multicast_count(snow_globe), 2, "Snow Globe gets +1 Multicast for adjacent Property")
	_battle_system().call("end_battle")

	var inv4: LinearInventoryClass = LinearInventoryClass.new()
	var z_sword: ItemDataClass = _create_item("z_sword")
	var large_item: ItemDataClass = _create_item("poppy_field")
	_assert_true(inv4.place_item(z_sword, 0), "places Z-Sword")
	_assert_true(inv4.place_item(large_item, 2), "places Large item")
	_start_battle(inv4, "P2B Z-Sword Multicast Test")
	_assert_eq(_multicast_count(z_sword), 2, "Z-Sword gets +1 Multicast while you have a Large item")
	_battle_system().call("end_battle")

	var inv5: LinearInventoryClass = LinearInventoryClass.new()
	var aquatic: ItemDataClass = _create_item("piranha")
	var dive_weights: ItemDataClass = _create_item("dive_weights")
	_assert_true(inv5.place_item(aquatic, 0), "places adjacent Aquatic")
	_assert_true(inv5.place_item(dive_weights, 1), "places Dive Weights")
	_start_battle(inv5, "P2B Dive Weights Multicast Test")
	_assert_eq(_multicast_count(dive_weights), 5, "Dive Weights gets +Multicast equal to its Ammo")
	_battle_system().call("end_battle")

func _start_battle(inv: LinearInventoryClass, monster_name: String) -> MonsterDataClass:
	var hero = BazaarContentClass.create_mak_hero()
	var game_manager: Node = _game_manager()
	game_manager.call("reset_stats")
	game_manager.set("selected_hero", hero)
	game_manager.set("player_health", hero.max_hp)
	var monster: MonsterDataClass = MonsterDataClass.new()
	monster.monster_name = monster_name
	monster.max_hp = 1000
	monster.current_hp = 1000
	monster.monster_items = []
	monster.monster_skills = []
	_battle_system().call("start_battle", monster, inv)
	return monster

func _process_event(event_name: String, source_item: ItemDataClass, extra: Dictionary = {}) -> void:
	var event_data: Dictionary = _battle_system().call("_make_effect_event", event_name, source_item, extra)
	var events: Array[Dictionary] = [event_data]
	_battle_system().call("_process_reactive_effect_events", events)

func _create_charged_item(item_id: String) -> ItemDataClass:
	var item: ItemDataClass = _create_item(item_id, BazaarContentClass.RARITY_GOLD)
	item.current_cooldown = 10.0
	return item

func _create_item(item_id: String, rarity: int = BazaarContentClass.RARITY_GOLD) -> ItemDataClass:
	var item: ItemDataClass = BazaarContentClass.create_item(item_id, rarity)
	_assert_true(item != null, "creates %s" % item_id)
	if item != null:
		item.effects = EffectDefinitionClass.build_item_effects(item)
		item.effect_warnings = EffectDefinitionClass.collect_item_warnings(item, item.effects)
	return item

func _definition_ids(item: ItemDataClass) -> Array[String]:
	var ids: Array[String] = []
	if item == null:
		return ids
	for definition in item.effects:
		ids.append(str((definition as Dictionary).get("id", "")))
	return ids

func _multicast_count(item: ItemDataClass) -> int:
	return int(_battle_system().call("_get_player_item_multicast_count", item))

func _trace_has(definition_id: String) -> bool:
	for entry in _battle_system().call("get_effect_execution_trace"):
		if str(entry.get("definition_id", "")) == definition_id:
			return true
	return false

func _item_runtime_bonus(item: ItemDataClass, key: String) -> float:
	return float(_battle_system().call("_get_item_runtime_bonus", item, key))

func _battle_system() -> Node:
	return get_node("/root/BattleSystem")

func _game_manager() -> Node:
	return get_node("/root/GameManager")

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
