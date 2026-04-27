extends Node

const BazaarContentClass = preload("res://scripts/data/bazaar_content.gd")
const ItemDataClass = preload("res://scripts/data/item_data.gd")
const LinearInventoryClass = preload("res://scripts/data/linear_inventory.gd")
const MonsterDataClass = preload("res://scripts/data/monster_data.gd")

var _total: int = 0
var _passed: int = 0

func _ready() -> void:
	if not Engine.is_editor_hint():
		print("== tests/test_battle_status_runtime.gd ==")
		_run_tests()
		_print_summary()

func _run_tests() -> void:
	test_poison_ticks_once_per_second_and_persists()
	test_burn_ticks_twice_per_second_and_decays()
	test_regeneration_heals_and_reduces_poison_before_damage()
	test_quill_and_ink_applies_poison_and_regeneration_states()
	test_potion_potion_transforms_for_one_fight_then_restores()
	test_status_damage_can_end_battle_on_the_same_tick()
	test_venom_observes_left_weapon_and_remains_passive()
	test_fungal_spores_buffs_venom_before_weapon_use()
	test_emerald_gives_other_active_items_poison()
	test_ruby_boosts_other_burn_items()
	test_candles_charge_when_small_item_is_used()
	test_hourglass_reduces_adjacent_item_cooldown()
	test_aludel_multicasts_for_adjacent_potion()
	test_barbed_claws_multicasts_for_poisoned_players()
	test_nightshade_gains_poison_after_regen()
	test_sword_cane_uses_adjacent_status_item_types()
	test_venomous_dose_poisons_both_sides()
	test_monster_duct_tape_observes_left_item_use()
	test_ammo_item_cools_down_then_waits_until_refilled()
	test_tazidian_dagger_increases_left_potion_ammo_for_the_fight()

func _battle_system() -> Node:
	return get_node("/root/BattleSystem")

func _game_manager() -> Node:
	return get_node("/root/GameManager")

func _start_battle(monster_hp: int = 100, inv: LinearInventoryClass = null) -> MonsterDataClass:
	var game_manager: Node = _game_manager()
	game_manager.call("reset_stats")
	game_manager.set("selected_hero", BazaarContentClass.create_mak_hero())
	game_manager.set("player_health", 100)
	var monster: MonsterDataClass = MonsterDataClass.new()
	monster.monster_name = "Runtime Test"
	monster.max_hp = monster_hp
	monster.current_hp = monster_hp
	_battle_system().call("start_battle", monster, inv if inv != null else LinearInventoryClass.new())
	return monster

func _start_battle_with_monster(monster: MonsterDataClass, inv: LinearInventoryClass = null) -> MonsterDataClass:
	var game_manager: Node = _game_manager()
	game_manager.call("reset_stats")
	game_manager.set("selected_hero", BazaarContentClass.create_mak_hero())
	game_manager.set("player_health", 100)
	_battle_system().call("start_battle", monster, inv if inv != null else LinearInventoryClass.new())
	return monster

func _create_item(item_id: String, rarity: int = BazaarContentClass.RARITY_BRONZE) -> ItemDataClass:
	var item: ItemDataClass = BazaarContentClass.create_item(item_id, rarity)
	_assert_true(item != null, "test setup creates %s" % item_id)
	return item

func _set_ready(item: ItemDataClass) -> void:
	item.current_cooldown = 0.0

func _set_blocked(item: ItemDataClass) -> void:
	item.current_cooldown = 999.0

func _apply_status(target: String, status_type: String, value: float) -> void:
	_battle_system().call("_apply_status_effect", {
		"type": status_type,
		"value": value,
		"target": target,
		"item_name": "Test Status"
	})

func _process_status(seconds: float) -> void:
	_battle_system().call("_process_active_effects", seconds)

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

func test_poison_ticks_once_per_second_and_persists() -> void:
	var monster: MonsterDataClass = _start_battle()
	_apply_status("enemy", "poison", 1.0)

	_process_status(0.5)
	_assert_eq(monster.current_hp, 100, "poison waits for one-second tick")
	_process_status(0.5)
	_assert_eq(monster.current_hp, 99, "poison deals its stack value after one second")
	_process_status(1.0)
	_assert_eq(monster.current_hp, 98, "poison persists after ticking")

	_battle_system().call("end_battle")

func test_burn_ticks_twice_per_second_and_decays() -> void:
	var monster: MonsterDataClass = _start_battle()
	_apply_status("enemy", "burn", 3.0)

	_process_status(0.5)
	_assert_eq(monster.current_hp, 97, "burn deals current stacks at the half-second tick")
	_assert_float_eq(float(_battle_system().call("get_status_totals", "enemy").get("burn", 0.0)), 2.0, "burn decays by one after ticking")
	_process_status(0.5)
	_assert_eq(monster.current_hp, 95, "burn ticks again after another half second")
	_assert_float_eq(float(_battle_system().call("get_status_totals", "enemy").get("burn", 0.0)), 1.0, "burn keeps decaying")

	_battle_system().call("end_battle")

func test_regeneration_heals_and_reduces_poison_before_damage() -> void:
	var game_manager: Node = _game_manager()
	_start_battle()
	game_manager.set("player_health", 50)
	_apply_status("self", "poison", 3.0)
	_apply_status("self", "regeneration", 1.0)

	_process_status(1.0)
	var player_status: Dictionary = _battle_system().call("get_status_totals", "player")
	_assert_eq(int(game_manager.get("player_health")), 49, "regeneration heals before poison damage resolves")
	_assert_float_eq(float(player_status.get("poison", 0.0)), 2.0, "regeneration reduces poison by its amount")
	_assert_float_eq(float(player_status.get("regeneration", 0.0)), 1.0, "regeneration persists for the fight")

	_battle_system().call("end_battle")

func test_quill_and_ink_applies_poison_and_regeneration_states() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var quill: ItemDataClass = BazaarContentClass.create_item("quill_and_ink", BazaarContentClass.RARITY_BRONZE)
	_assert_true(inv.place_item(quill, 0), "test setup places Quill and Ink")
	var monster: MonsterDataClass = _start_battle(100, inv)
	_game_manager().get("selected_hero").crit_chance = 0.0
	quill.current_cooldown = 0.0

	_battle_system().call("execute_battle_tick", 0.5)
	var enemy_status: Dictionary = _battle_system().call("get_status_totals", "enemy")
	var player_status: Dictionary = _battle_system().call("get_status_totals", "player")
	_assert_float_eq(float(enemy_status.get("poison", 0.0)), 2.0, "Quill and Ink applies poison stacks to enemy")
	_assert_float_eq(float(player_status.get("regeneration", 0.0)), 2.0, "Quill and Ink applies regeneration stacks to player")
	_assert_eq(monster.current_hp, 100, "Quill poison does not deal damage before the one-second poison tick")

	_battle_system().call("execute_battle_tick", 0.5)
	_assert_eq(monster.current_hp, 98, "Quill poison damages enemy on the next one-second tick")

	_battle_system().call("end_battle")

func test_potion_potion_transforms_for_one_fight_then_restores() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var potion_potion: ItemDataClass = BazaarContentClass.create_item("potion_potion", BazaarContentClass.RARITY_BRONZE)
	_assert_true(inv.place_item(potion_potion, 0), "test setup places Potion Potion")
	_start_battle(100, inv)
	potion_potion.current_cooldown = 0.0

	_battle_system().call("execute_battle_tick", 0.5)
	_assert_eq(inv.items.size(), 2, "Potion Potion becomes two generated items during combat")
	_assert_true(inv.get_item_at(0) != potion_potion and inv.get_item_at(1) != potion_potion, "original Potion Potion is removed during combat")
	_assert_true(inv.get_item_at(0) != null and inv.get_item_at(0).get_slot_count() == 1, "first generated item is small")
	_assert_true(inv.get_item_at(1) != null and inv.get_item_at(1).get_slot_count() == 1, "second generated item is small")

	_battle_system().call("end_battle")
	_assert_eq(inv.items.size(), 1, "Potion Potion generated items are removed after combat")
	_assert_true(inv.get_item_at(0) == potion_potion and inv.get_item_at(1) == potion_potion, "original medium Potion Potion returns to its two slots")

func test_status_damage_can_end_battle_on_the_same_tick() -> void:
	var monster: MonsterDataClass = _start_battle(1)
	_apply_status("enemy", "poison", 1.0)

	var ended: bool = bool(_battle_system().call("execute_battle_tick", 1.0))
	_assert_true(ended, "status damage reports battle end on the same tick")
	_assert_eq(monster.current_hp, 0, "status damage killed the monster")

	_battle_system().call("end_battle")

func test_venom_observes_left_weapon_and_remains_passive() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var fang: ItemDataClass = _create_item("fang")
	var venom: ItemDataClass = _create_item("venom")
	_assert_true(inv.place_item(fang, 0), "test setup places Fang")
	_assert_true(inv.place_item(venom, 1), "test setup places Venom")
	var monster: MonsterDataClass = _start_battle(100, inv)
	_game_manager().get("selected_hero").crit_chance = 0.0
	_set_ready(fang)
	_set_ready(venom)

	_battle_system().call("execute_battle_tick", 0.5)
	_assert_eq(monster.current_hp, 95, "Fang deals damage while Venom waits for status tick")
	_assert_float_eq(float(_battle_system().call("get_status_totals", "enemy").get("poison", 0.0)), 2.0, "Venom poisons when the left weapon is used")

	_battle_system().call("execute_battle_tick", 0.5)
	_assert_float_eq(float(_battle_system().call("get_status_totals", "enemy").get("poison", 0.0)), 2.0, "Venom does not self-trigger as a passive item")
	_assert_eq(monster.current_hp, 93, "Venom poison ticks after one second")

	_battle_system().call("end_battle")

func test_fungal_spores_buffs_venom_before_weapon_use() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var fungal_spores: ItemDataClass = _create_item("fungal_spores")
	var fang: ItemDataClass = _create_item("fang")
	var venom: ItemDataClass = _create_item("venom")
	_assert_true(inv.place_item(fungal_spores, 0), "test setup places Fungal Spores")
	_assert_true(inv.place_item(fang, 1), "test setup places Fang")
	_assert_true(inv.place_item(venom, 2), "test setup places Venom")
	var monster: MonsterDataClass = _start_battle(100, inv)
	_game_manager().get("selected_hero").crit_chance = 0.0
	_set_ready(fungal_spores)
	_set_ready(fang)
	_set_ready(venom)

	_battle_system().call("execute_battle_tick", 0.0)
	_assert_eq(monster.current_hp, 95, "Fang still deals its base damage")
	_assert_float_eq(float(_battle_system().call("get_status_totals", "enemy").get("poison", 0.0)), 4.0, "Fungal Spores buffs Venom's poison trigger")

	_battle_system().call("end_battle")

func test_emerald_gives_other_active_items_poison() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var fang: ItemDataClass = _create_item("fang")
	var emerald: ItemDataClass = _create_item("emerald")
	_assert_true(inv.place_item(fang, 0), "test setup places Fang")
	_assert_true(inv.place_item(emerald, 1), "test setup places Emerald")
	_start_battle(100, inv)
	_game_manager().get("selected_hero").crit_chance = 0.0
	_set_ready(fang)
	_set_blocked(emerald)

	_battle_system().call("execute_battle_tick", 0.0)
	_assert_float_eq(float(_battle_system().call("get_status_totals", "enemy").get("poison", 0.0)), 3.0, "Emerald adds poison to another active item")

	_battle_system().call("end_battle")

func test_ruby_boosts_other_burn_items() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var lighter: ItemDataClass = _create_item("lighter")
	var ruby: ItemDataClass = _create_item("ruby")
	_assert_true(inv.place_item(lighter, 0), "test setup places Lighter")
	_assert_true(inv.place_item(ruby, 1), "test setup places Ruby")
	_start_battle(100, inv)
	_game_manager().get("selected_hero").crit_chance = 0.0
	_set_ready(lighter)
	_set_blocked(ruby)

	_battle_system().call("execute_battle_tick", 0.0)
	_assert_float_eq(float(_battle_system().call("get_status_totals", "enemy").get("burn", 0.0)), 5.0, "Ruby adds burn to another Burn item")

	_battle_system().call("end_battle")

func test_candles_charge_when_small_item_is_used() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var fang: ItemDataClass = _create_item("fang")
	var candles: ItemDataClass = _create_item("candles")
	_assert_true(inv.place_item(fang, 0), "test setup places Fang")
	_assert_true(inv.place_item(candles, 1), "test setup places Candles")
	_start_battle(100, inv)
	_game_manager().get("selected_hero").crit_chance = 0.0
	_set_ready(fang)

	_battle_system().call("execute_battle_tick", 0.0)
	_assert_float_eq(candles.current_cooldown, 7.0, "Candles is charged by two seconds when a small item is used")

	_battle_system().call("end_battle")

func test_hourglass_reduces_adjacent_item_cooldown() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var fang: ItemDataClass = _create_item("fang")
	var hourglass: ItemDataClass = _create_item("hourglass")
	_assert_true(inv.place_item(fang, 0), "test setup places Fang")
	_assert_true(inv.place_item(hourglass, 1), "test setup places Hourglass")
	_start_battle(100, inv)

	_assert_float_eq(fang.current_cooldown, 2.91, "Hourglass reduces adjacent item cooldown at battle start", 0.01)

	_battle_system().call("end_battle")

func test_aludel_multicasts_for_adjacent_potion() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var aludel: ItemDataClass = _create_item("aludel")
	var potion: ItemDataClass = _create_item("noxious_potion")
	_assert_true(inv.place_item(aludel, 0), "test setup places Aludel")
	_assert_true(inv.place_item(potion, 2), "test setup places adjacent Potion")
	_start_battle(100, inv)
	_game_manager().get("selected_hero").crit_chance = 0.0
	_set_ready(aludel)
	_set_blocked(potion)

	_battle_system().call("execute_battle_tick", 0.0)
	_assert_float_eq(float(_battle_system().call("get_status_totals", "enemy").get("poison", 0.0)), 8.0, "Aludel multicasts once for an adjacent Potion")

	_battle_system().call("end_battle")

func test_barbed_claws_multicasts_for_poisoned_players() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var barbed_claws: ItemDataClass = _create_item("barbed_claws")
	_assert_true(inv.place_item(barbed_claws, 0), "test setup places Barbed Claws")
	var monster: MonsterDataClass = _start_battle(100, inv)
	_game_manager().get("selected_hero").crit_chance = 0.0
	_apply_status("self", "poison", 1.0)
	_apply_status("enemy", "poison", 1.0)
	_set_ready(barbed_claws)

	_battle_system().call("execute_battle_tick", 0.0)
	_assert_eq(monster.current_hp, 85, "Barbed Claws multicasts once for each poisoned player")

	_battle_system().call("end_battle")

func test_nightshade_gains_poison_after_regen() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var quill: ItemDataClass = _create_item("quill_and_ink")
	var nightshade: ItemDataClass = _create_item("nightshade")
	var fang: ItemDataClass = _create_item("fang")
	_assert_true(inv.place_item(quill, 0), "test setup places Quill and Ink")
	_assert_true(inv.place_item(nightshade, 1), "test setup places Nightshade")
	_assert_true(inv.place_item(fang, 3), "test setup places a weapon to disable Quill multicast")
	_start_battle(100, inv)
	_game_manager().get("selected_hero").crit_chance = 0.0
	_set_ready(quill)
	_set_ready(nightshade)
	_set_blocked(fang)

	_battle_system().call("execute_battle_tick", 0.0)
	_assert_float_eq(float(_battle_system().call("get_status_totals", "enemy").get("poison", 0.0)), 9.0, "Nightshade gains poison after Quill grants Regen")

	_battle_system().call("end_battle")

func test_sword_cane_uses_adjacent_status_item_types() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var myrrh: ItemDataClass = _create_item("myrrh")
	var sword_cane: ItemDataClass = _create_item("sword_cane")
	var noxious_potion: ItemDataClass = _create_item("noxious_potion")
	_assert_true(inv.place_item(myrrh, 0), "test setup places Myrrh")
	_assert_true(inv.place_item(sword_cane, 1), "test setup places Sword Cane")
	_assert_true(inv.place_item(noxious_potion, 3), "test setup places Noxious Potion")
	var monster: MonsterDataClass = _start_battle(100, inv)
	_game_manager().get("selected_hero").crit_chance = 0.0
	_set_blocked(myrrh)
	_set_ready(sword_cane)
	_set_blocked(noxious_potion)

	_battle_system().call("execute_battle_tick", 0.0)
	_assert_eq(monster.current_hp, 90, "Sword Cane deals damage")
	_assert_float_eq(float(_battle_system().call("get_status_totals", "enemy").get("poison", 0.0)), 2.0, "Sword Cane poisons when adjacent to a Poison item")
	_assert_float_eq(float(_battle_system().call("get_status_totals", "player").get("regeneration", 0.0)), 2.0, "Sword Cane gains Regen when adjacent to a Regen item")

	_battle_system().call("end_battle")

func test_venomous_dose_poisons_both_sides() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var venomous_dose: ItemDataClass = _create_item("venomous_dose")
	_assert_true(inv.place_item(venomous_dose, 0), "test setup places Venomous Dose")
	_start_battle(100, inv)
	_game_manager().get("selected_hero").crit_chance = 0.0
	_set_ready(venomous_dose)

	_battle_system().call("execute_battle_tick", 0.0)
	_assert_float_eq(float(_battle_system().call("get_status_totals", "enemy").get("poison", 0.0)), 2.0, "Venomous Dose poisons the enemy")
	_assert_float_eq(float(_battle_system().call("get_status_totals", "player").get("poison", 0.0)), 2.0, "Venomous Dose poisons the player")
	_assert_float_eq(float(_battle_system().call("get_status_totals", "player").get("regeneration", 0.0)), 2.0, "Venomous Dose grants Regen")

	_battle_system().call("end_battle")

func test_monster_duct_tape_observes_left_item_use() -> void:
	var monster: MonsterDataClass = BazaarContentClass.create_day1_monster("banannabal")
	_start_battle_with_monster(monster, LinearInventoryClass.new())
	for item in monster.monster_items:
		item["current_cooldown"] = 999.0
		if str(item.get("source_id", "")) == "bluenanas":
			item["current_cooldown"] = 0.0

	_battle_system().call("execute_battle_tick", 0.0)
	_assert_float_eq(monster.current_shield, 10.0, "Monster Duct Tape shields when the item to its left is used")

	_battle_system().call("end_battle")

func test_ammo_item_cools_down_then_waits_until_refilled() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var ammo_weapon: ItemDataClass = ItemDataClass.new()
	ammo_weapon.item_name = "Ammo Test Weapon"
	ammo_weapon.source_id = "ammo_test_weapon"
	ammo_weapon.damage = 10
	ammo_weapon.cooldown = 2.0
	ammo_weapon.ammo = 1
	ammo_weapon.crit_chance = 0.0
	ammo_weapon.tags = ["Weapon", "Ammo"]
	_assert_true(inv.place_item(ammo_weapon, 0), "test setup places ammo weapon")
	var monster: MonsterDataClass = _start_battle(100, inv)
	_game_manager().get("selected_hero").crit_chance = 0.0
	_set_ready(ammo_weapon)
	_assert_eq(ammo_weapon.get_current_ammo(), 1, "battle start fills ammo")

	_battle_system().call("execute_battle_tick", 0.0)
	_assert_eq(monster.current_hp, 90, "ammo item fires once while loaded")
	_assert_eq(ammo_weapon.get_current_ammo(), 0, "ammo item consumes one ammo after firing")
	_assert_float_eq(ammo_weapon.current_cooldown, 2.0, "ammo item starts cooldown after spending its last ammo")

	ammo_weapon.current_cooldown = 0.0
	_battle_system().call("execute_battle_tick", 0.0)
	_assert_eq(monster.current_hp, 90, "empty ammo item waits when cooldown is ready")
	_assert_float_eq(ammo_weapon.current_cooldown, 0.0, "empty ammo item remains ready instead of restarting cooldown")

	_assert_eq(int(_battle_system().call("refill_player_item_ammo", ammo_weapon, 1)), 1, "refilling restores one ammo")
	_assert_eq(monster.current_hp, 80, "ready ammo item fires immediately after refill")
	_assert_eq(ammo_weapon.get_current_ammo(), 0, "immediate refill shot consumes the restored ammo")
	_assert_float_eq(ammo_weapon.current_cooldown, 2.0, "immediate refill shot restarts cooldown")

	_battle_system().call("end_battle")

func test_tazidian_dagger_increases_left_potion_ammo_for_the_fight() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var potion: ItemDataClass = _create_item("fire_potion")
	var dagger: ItemDataClass = _create_item("tazidian_dagger")
	_assert_true(inv.place_item(potion, 0), "test setup places Potion left of Tazidian Dagger")
	_assert_true(inv.place_item(dagger, 1), "test setup places Tazidian Dagger")
	_start_battle(100, inv)

	_assert_eq(potion.get_max_ammo(), 2, "Tazidian Dagger increases the left Potion's max ammo")
	_assert_eq(potion.get_current_ammo(), 2, "battle start fills the Potion to its effective max ammo")

	_battle_system().call("end_battle")
	_assert_eq(potion.get_max_ammo(), 1, "Potion max ammo returns to base after combat")
