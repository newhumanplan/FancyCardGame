extends Node

const BazaarContentClass = preload("res://scripts/data/bazaar_content.gd")
const HeroDataClass = preload("res://scripts/data/hero_data.gd")
const ItemDataClass = preload("res://scripts/data/item_data.gd")
const LinearInventoryClass = preload("res://scripts/data/linear_inventory.gd")
const MonsterDataClass = preload("res://scripts/data/monster_data.gd")
const PlayerSkillCatalogClass = preload("res://scripts/data/player_skill_catalog.gd")

var _total: int = 0
var _passed: int = 0

func _ready() -> void:
	if not Engine.is_editor_hint():
		print("== tests/test_hero_identity_pack.gd ==")
		await _run_tests()
		_print_summary()

func _run_tests() -> void:
	test_vanessa_and_pygmalien_identity_data()
	test_representative_identity_runtime_coverage()
	await test_hero_selection_start_run_flow_for_identity_heroes()

func test_vanessa_and_pygmalien_identity_data() -> void:
	for hero_type in [HeroDataClass.HeroType.VANESSA, HeroDataClass.HeroType.PYGMALIEN]:
		var summary: Dictionary = BazaarContentClass.get_hero_identity_summary(hero_type)
		var hero_name: String = str(summary.get("name", ""))
		var item_ids: Array = summary.get("item_ids", [])
		var starter_skills: Array = summary.get("starter_skills", [])
		var archetypes: Array = summary.get("archetypes", [])
		_assert_true(not hero_name.is_empty(), "identity summary names hero %s" % str(hero_type))
		_assert_true(item_ids.size() >= 30, "%s has a real item pool" % hero_name)
		_assert_true(starter_skills.size() >= 5, "%s has starter skills" % hero_name)
		_assert_true(archetypes.size() >= 2, "%s has at least two archetypes" % hero_name)
		_assert_true(FileAccess.file_exists(str(summary.get("art_path", ""))), "%s has local hero art" % hero_name)
		for skill_id in starter_skills:
			_assert_skill_runtime_backed(str(skill_id), "%s starter skill %s" % [hero_name, str(skill_id)])
		for archetype in archetypes:
			_assert_archetype_resolves(hero_type, hero_name, archetype as Dictionary)

func test_representative_identity_runtime_coverage() -> void:
	var vanessa_inv: LinearInventoryClass = LinearInventoryClass.new()
	var jellyfish: ItemDataClass = _create_item("jellyfish")
	var cutlass: ItemDataClass = _create_item("cutlass")
	_assert_true(vanessa_inv.place_item(jellyfish, 0), "places Vanessa Aquatic source")
	_assert_true(vanessa_inv.place_item(cutlass, 1), "places Vanessa Weapon haste target")
	_start_battle(HeroDataClass.HeroType.VANESSA, vanessa_inv)
	jellyfish.current_cooldown = 0.0
	cutlass.current_cooldown = 6.0
	_battle_system().call("execute_battle_tick", 0.0)
	_assert_true(_trace_has("crashing_waves_aquatic_haste_weapon"), "Vanessa Crashing Waves executes from a real Aquatic item")
	_assert_true(float(_battle_system().call("get_status_totals", "enemy").get("poison", 0.0)) > 0.0, "Vanessa Jellyfish applies real Poison")
	_assert_true(cutlass.current_cooldown < 6.0, "Vanessa Aquatic archetype hastes a Weapon")
	_battle_system().call("end_battle")

	var pyg_inv: LinearInventoryClass = LinearInventoryClass.new()
	var bandages: ItemDataClass = _create_item("bandages")
	var tusked_helm: ItemDataClass = _create_item("tusked_helm")
	var silk_scarf: ItemDataClass = _create_item("silk_scarf")
	_assert_true(pyg_inv.place_item(bandages, 0), "places Pygmalien Heal source")
	_assert_true(pyg_inv.place_item(tusked_helm, 1), "places Pygmalien Weapon target")
	_assert_true(pyg_inv.place_item(silk_scarf, 2), "places Pygmalien Shield target")
	_start_battle(HeroDataClass.HeroType.PYGMALIEN, pyg_inv)
	_assert_float_eq(_battle_system().call("_get_item_runtime_bonus", bandages, "heal"), 0.0, "Pygmalien starts from item data, not fake support counts")
	_assert_eq(_battle_system().call("_get_player_item_skill_damage_bonus", tusked_helm), 10, "Pygmalien Strength buffs a real Weapon")
	_assert_eq(_battle_system().call("_get_player_item_skill_crit_bonus", bandages), 5, "Pygmalien Critical Aid buffs Heal items")
	_assert_float_eq(_battle_system().call("_get_item_runtime_bonus", bandages, "shield"), 20.0, "Pygmalien Frontal Shielding buffs the leftmost Shield item")
	bandages.current_cooldown = 0.0
	tusked_helm.current_cooldown = 8.0
	silk_scarf.current_cooldown = 6.0
	_battle_system().call("execute_battle_tick", 0.0)
	_assert_true(_trace_has("overheal_haste_on_overheal_haste_all"), "Pygmalien Overheal Haste executes from a real Heal item")
	_assert_true(tusked_helm.current_cooldown < 8.0, "Pygmalien overheal hastes Weapon board item")
	_assert_true(silk_scarf.current_cooldown < 6.0, "Pygmalien overheal hastes Shield board item")
	_battle_system().call("end_battle")

func test_hero_selection_start_run_flow_for_identity_heroes() -> void:
	for hero_type in [HeroDataClass.HeroType.VANESSA, HeroDataClass.HeroType.PYGMALIEN]:
		_reset_services()
		var scene: PackedScene = load("res://scenes/main.tscn")
		var main: Control = scene.instantiate() as Control
		add_child(main)
		await get_tree().process_frame
		await get_tree().process_frame
		var hero_button: Button = _find_hero_button(main, hero_type)
		_assert_not_null(hero_button, "hero selection renders button for %s" % str(hero_type))
		_assert_true(hero_button != null and hero_button.text.find("wiki items") >= 0, "hero selection button shows verified item count for %s" % str(hero_type))
		if hero_button != null:
			hero_button.emit_signal("pressed")
		await get_tree().process_frame
		_assert_true(not bool(main.get("is_in_hero_selection")), "selecting %s leaves hero selection" % str(hero_type))
		_assert_true(GameManager.selected_hero != null and GameManager.selected_hero.hero_type == hero_type, "start-run selects %s" % str(hero_type))
		_assert_true(GameManager.selected_hero.skills.size() >= 5, "start-run applies starter skill loadout for %s" % str(hero_type))
		main.queue_free()
		await get_tree().process_frame

func _start_battle(hero_type: HeroDataClass.HeroType, inv: LinearInventoryClass) -> void:
	var hero: HeroDataClass = BazaarContentClass.create_bazaar_hero(hero_type)
	hero.crit_chance = 0.0
	GameManager.call("reset_stats")
	GameManager.set("selected_hero", hero)
	GameManager.set("player_health", hero.max_hp)
	var monster: MonsterDataClass = MonsterDataClass.new()
	monster.monster_name = "Identity Target"
	monster.max_hp = 300
	monster.current_hp = 300
	monster.monster_items = [{"name": "Target", "damage": 1, "cooldown": 5.0, "current_cooldown": 5.0}]
	_battle_system().call("start_battle", monster, inv)

func _create_item(item_id: String, rarity: int = BazaarContentClass.RARITY_BRONZE) -> ItemDataClass:
	var item: ItemDataClass = BazaarContentClass.create_item(item_id, rarity)
	_assert_not_null(item, "creates item %s" % item_id)
	return item

func _assert_archetype_resolves(hero_type: HeroDataClass.HeroType, hero_name: String, archetype: Dictionary) -> void:
	var item_pool: Array[String] = BazaarContentClass.get_hero_item_ids(hero_type)
	_assert_true(not str(archetype.get("id", "")).is_empty(), "%s archetype has id" % hero_name)
	_assert_true(not str(archetype.get("summary", "")).is_empty(), "%s archetype has summary" % hero_name)
	_assert_true((archetype.get("tags", []) as Array).size() >= 2, "%s archetype has build tags" % hero_name)
	for item_id in archetype.get("core_items", []):
		var clean_item_id: String = str(item_id)
		_assert_true(item_pool.has(clean_item_id), "%s archetype item belongs to hero pool: %s" % [hero_name, clean_item_id])
		_assert_not_null(BazaarContentClass.create_item(clean_item_id), "%s archetype item can be created: %s" % [hero_name, clean_item_id])
	for skill_id in archetype.get("core_skills", []):
		_assert_skill_runtime_backed(str(skill_id), "%s archetype skill %s" % [hero_name, str(skill_id)])

func _assert_skill_runtime_backed(skill_id: String, label: String) -> void:
	var entry: Dictionary = PlayerSkillCatalogClass.get_skill_entry(skill_id)
	_assert_eq(str(entry.get("support_status", "")), PlayerSkillCatalogClass.SUPPORT_IMPLEMENTED, "%s is implemented" % label)
	var has_runtime_rule: bool = not (entry.get("numeric_rule", {}) as Dictionary).is_empty() or not (entry.get("trigger_rule", {}) as Dictionary).is_empty()
	_assert_true(has_runtime_rule, "%s has runtime rule" % label)

func _find_hero_button(root: Node, hero_type: HeroDataClass.HeroType) -> Button:
	var hero_name: String = str(BazaarContentClass.get_hero_profile_spec(hero_type).get("name", ""))
	return _find_button_containing(root, hero_name)

func _find_button_containing(root: Node, text: String) -> Button:
	if root is Button and (root as Button).text.find(text) >= 0:
		return root as Button
	for child in root.get_children():
		var found: Button = _find_button_containing(child, text)
		if found != null:
			return found
	return null

func _battle_system() -> Node:
	return get_node("/root/BattleSystem")

func _trace_has(definition_id: String) -> bool:
	for entry in _battle_system().call("get_effect_execution_trace"):
		if str(entry.get("definition_id", "")) == definition_id:
			return true
	return false

func _reset_services() -> void:
	RewardService.reset_runtime_state()
	EconomyService.reset()
	RunStateService.reset(true)
	HeroStateService.reset()
	GameFlowService.set("_current_event_options", [])
	GameFlowService.set("_current_random_event_id", "")
	GameFlowService.set("_current_selected_option", {})
	GameManager.stats_total_battles = 0
	GameManager.stats_total_wins = 0
	GameManager.stats_total_losses = 0
	GameManager.stats_total_gold_earned = 0

func _assert_true(condition: bool, label: String) -> void:
	_total += 1
	if condition:
		_passed += 1
		print("PASS: %s" % label)
	else:
		push_error("FAIL: %s" % label)

func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	_assert_true(actual == expected, "%s | expected=%s actual=%s" % [label, str(expected), str(actual)])

func _assert_float_eq(actual: float, expected: float, label: String, tolerance: float = 0.001) -> void:
	_assert_true(absf(actual - expected) <= tolerance, "%s | expected=%.3f actual=%.3f" % [label, expected, actual])

func _assert_not_null(value: Variant, label: String) -> void:
	_assert_true(value != null, label)

func _print_summary() -> void:
	print("SUMMARY: %d/%d passed" % [_passed, _total])
	get_tree().quit(1 if _passed < _total else 0)
