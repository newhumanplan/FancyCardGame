extends Node

const BazaarContentClass = preload("res://scripts/data/bazaar_content.gd")
const ItemDataClass = preload("res://scripts/data/item_data.gd")
const LinearInventoryClass = preload("res://scripts/data/linear_inventory.gd")
const MonsterDataClass = preload("res://scripts/data/monster_data.gd")

var _total: int = 0
var _passed: int = 0

func _ready() -> void:
	if not Engine.is_editor_hint():
		print("== tests/test_player_skill_integration.gd ==")
		_run_tests()
		_print_summary()

func _run_tests() -> void:
	test_battle_system_uses_selected_hero_skill_set()
	test_deadly_eye_adds_weapon_crit_bonus()
	test_heated_shells_adds_burn_when_ammo_item_is_used()
	test_paralytic_poison_freezes_enemy_item_on_first_poison()
	test_slow_burn_charges_a_burn_item_when_you_slow()

func _battle_system() -> Node:
	return get_node("/root/BattleSystem")

func _game_manager() -> Node:
	return get_node("/root/GameManager")

func _create_item(item_id: String, rarity: int = BazaarContentClass.RARITY_BRONZE) -> ItemDataClass:
	var item: ItemDataClass = BazaarContentClass.create_item(item_id, rarity)
	_assert_true(item != null, "test setup creates %s" % item_id)
	return item

func _start_battle(hero_skills: Array, inv: LinearInventoryClass, monster: MonsterDataClass = null) -> MonsterDataClass:
	var hero = BazaarContentClass.create_mak_hero()
	hero.skills = hero_skills.duplicate()
	var game_manager: Node = _game_manager()
	game_manager.call("reset_stats")
	game_manager.set("selected_hero", hero)
	game_manager.set("player_health", hero.max_hp)
	var battle_monster: MonsterDataClass = monster if monster != null else MonsterDataClass.new()
	if monster == null:
		battle_monster.monster_name = "Skill Test"
		battle_monster.max_hp = 100
		battle_monster.current_hp = 100
	_battle_system().call("start_battle", battle_monster, inv)
	return battle_monster

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

func test_battle_system_uses_selected_hero_skill_set() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	_start_battle([], inv)
	var skill_manager = _battle_system().get("skill_manager")
	_assert_eq(skill_manager.get_skill_count(), 0, "battle system no longer auto-equips config skills when hero has none")
	_battle_system().call("end_battle")

func test_deadly_eye_adds_weapon_crit_bonus() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var fang: ItemDataClass = _create_item("fang")
	var med_kit: ItemDataClass = _create_item("med_kit")
	_assert_true(inv.place_item(fang, 0), "places Fang")
	_assert_true(inv.place_item(med_kit, 1), "places Med Kit")
	_start_battle([{"id": "deadly_eye", "tier": "Bronze"}], inv)

	var weapon_bonus: int = _battle_system().call("_get_player_item_skill_crit_bonus", fang)
	var support_bonus: int = _battle_system().call("_get_player_item_skill_crit_bonus", med_kit)
	var weapon_crit_rate: float = _battle_system().call("_get_player_item_crit_rate", fang, 0.05)
	var support_crit_rate: float = _battle_system().call("_get_player_item_crit_rate", med_kit, 0.05)

	_assert_eq(weapon_bonus, 5, "Deadly Eye grants a non-zero crit bonus to weapons")
	_assert_eq(support_bonus, 0, "Deadly Eye does not buff non-weapon crit rate")
	_assert_float_eq(weapon_crit_rate, 0.10, "Deadly Eye weapon crit rate stacks from the Bronze tier value")
	_assert_float_eq(support_crit_rate, 0.05, "Deadly Eye leaves non-weapon crit rate unchanged")
	_battle_system().call("end_battle")

func test_heated_shells_adds_burn_when_ammo_item_is_used() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var fire_potion: ItemDataClass = _create_item("fire_potion")
	_assert_true(inv.place_item(fire_potion, 0), "places Fire Potion")
	var monster: MonsterDataClass = _start_battle(["heated_shells"], inv)
	fire_potion.current_cooldown = 0.0

	_battle_system().call("execute_battle_tick", 0.5)
	var enemy_status: Dictionary = _battle_system().call("get_status_totals", "enemy")
	_assert_float_eq(float(enemy_status.get("burn", 0.0)), 7.0, "Heated Shells adds extra burn before the first burn decay tick")
	_assert_eq(monster.current_hp, 92, "burn damage is processed during the same combat tick")
	_battle_system().call("end_battle")

func test_paralytic_poison_freezes_enemy_item_on_first_poison() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var poison_item: ItemDataClass = _create_item("noxious_potion")
	_assert_true(inv.place_item(poison_item, 0), "places Noxious Potion")
	var monster: MonsterDataClass = MonsterDataClass.new()
	monster.monster_name = "Freeze Target"
	monster.max_hp = 100
	monster.current_hp = 100
	monster.monster_items = [
		{"name": "Target Dummy", "damage": 10, "cooldown": 4.0},
	]
	_start_battle(["paralytic_poison"], inv, monster)
	poison_item.current_cooldown = 0.0

	_battle_system().call("execute_battle_tick", 0.5)
	_assert_float_eq(float(monster.monster_items[0].get("current_cooldown", 0.0)), 6.0, "Paralytic Poison freezes one enemy item on first poison trigger")
	_battle_system().call("end_battle")

func test_slow_burn_charges_a_burn_item_when_you_slow() -> void:
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var smelling_salts: ItemDataClass = _create_item("smelling_salts")
	var lighter: ItemDataClass = _create_item("lighter")
	_assert_true(inv.place_item(smelling_salts, 0), "places Smelling Salts")
	_assert_true(inv.place_item(lighter, 1), "places Lighter")
	var monster: MonsterDataClass = MonsterDataClass.new()
	monster.monster_name = "Slow Target"
	monster.max_hp = 100
	monster.current_hp = 100
	monster.monster_items = [
		{"name": "Target Dummy", "damage": 10, "cooldown": 4.0},
	]
	_start_battle(["slow_burn"], inv, monster)
	smelling_salts.current_cooldown = 0.0
	lighter.current_cooldown = 4.0

	_battle_system().call("execute_battle_tick", 0.5)
	_assert_float_eq(lighter.current_cooldown, 3.0, "Slow Burn charges a Burn item after a Slow trigger")
	_battle_system().call("end_battle")
