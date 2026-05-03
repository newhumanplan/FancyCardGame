extends Node

const BazaarContentClass = preload("res://scripts/data/bazaar_content.gd")
const HeroDataClass = preload("res://scripts/data/hero_data.gd")
const LinearInventoryClass = preload("res://scripts/data/linear_inventory.gd")

class MockGameManager:
	extends Node
	var gold: int = 50
	var income: int = 7
	var health: int = 40
	var max_health_value: int = 100
	var prestige: int = 0
	var damage_taken: int = 0
	var xp: int = 0
	var level: int = 1
	var selected_hero = null

	func setup() -> void:
		var hero: HeroDataClass = HeroDataClass.new()
		hero.hero_name = "Mak"
		hero.hero_type = HeroDataClass.HeroType.MAK
		hero.max_hp = max_health_value
		hero.current_hp = health
		selected_hero = hero

	func add_gold(amount: int) -> void:
		gold += amount

	func spend_gold(amount: int) -> void:
		gold -= amount

	func add_income(amount: int) -> void:
		income += amount

	func add_xp(amount: int) -> Dictionary:
		xp += amount
		return {"xp": xp}

	func heal(amount: int) -> void:
		health = mini(health + amount, max_health_value)

	func take_damage(amount: int) -> void:
		damage_taken += amount
		health = maxi(health - amount, 0)

	func add_prestige(amount: int) -> void:
		prestige += amount

	func add_max_health(amount: int) -> int:
		max_health_value += amount
		health = mini(health + amount, max_health_value)
		if selected_hero != null:
			selected_hero.max_hp += amount
			selected_hero.current_hp = health
		return max_health_value

	func get_max_health() -> int:
		return max_health_value

var _total: int = 0
var _passed: int = 0

func _ready() -> void:
	if not Engine.is_editor_hint():
		print("== tests/test_monster_event_rewards.gd ==")
		_run_tests()
		_print_summary()

func _run_tests() -> void:
	test_day_1_to_3_monster_reward_pools_are_gameplay_ready()
	test_pve_win_queues_monster_item_and_skill_reward_choices()
	test_high_frequency_event_effects_have_gameplay_results()
	test_unsupported_event_fallback_is_explicit()

func _manager():
	return load("res://scripts/data/event_manager.gd").new()

func _mock_game_manager() -> MockGameManager:
	var game_manager := MockGameManager.new()
	game_manager.setup()
	return game_manager

func _reset_services_with_mak() -> void:
	EconomyService.reset()
	RunStateService.reset(true)
	HeroStateService.reset()
	GameManager.reset_stats()
	var hero = BazaarContentClass.create_mak_hero()
	GameManager.select_hero(hero)

func test_day_1_to_3_monster_reward_pools_are_gameplay_ready() -> void:
	var monster_cases: int = 0
	var item_reward_cases: int = 0
	var skill_reward_cases: int = 0
	for day in [1, 2, 3]:
		for spec in BazaarContentClass.get_monster_specs_for_day(day):
			var monster = BazaarContentClass.create_monster(str(spec.get("id", "")), day)
			_assert_true(monster != null, "creates Day %d monster %s" % [day, str(spec.get("id", ""))])
			if monster == null:
				continue
			monster_cases += 1
			var reward: Dictionary = monster.get_reward()
			_assert_true(int(reward.get("gold", 0)) > 0, "%s has gold reward" % monster.monster_name)
			_assert_true(int(reward.get("xp", 0)) > 0, "%s has XP reward" % monster.monster_name)
			item_reward_cases += (reward.get("item_pool", []) as Array).size()
			skill_reward_cases += (reward.get("skill_pool", []) as Array).size()

	_assert_true(monster_cases >= 10, "Day 1-3 monster catalog has real encounter coverage")
	_assert_true(item_reward_cases >= 15, "Day 1-3 monsters expose at least 15 item reward pool entries")
	_assert_true(skill_reward_cases >= 10, "Day 1-3 monsters expose skill reward pool entries")

func test_pve_win_queues_monster_item_and_skill_reward_choices() -> void:
	_reset_services_with_mak()
	var inventory: LinearInventoryClass = LinearInventoryClass.new()
	var stash: LinearInventoryClass = LinearInventoryClass.new()
	var monster = BazaarContentClass.create_day1_monster("viper")
	var result: Dictionary = BattleProgressionService.apply_battle_result(true, false, monster, inventory, stash)
	var summary: Dictionary = result.get("reward_summary", {})
	_assert_true(bool(result.get("reward_choice_queued", false)), "Viper win queues a reward choice")
	_assert_eq(int(result.get("gold_reward", 0)), 0, "Viper win does not grant gold before a reward is chosen")
	_assert_eq(int(result.get("xp_reward", 0)), 0, "Viper win does not grant XP before a reward is chosen")
	_assert_true(bool(summary.get("choice_queued", false)), "reward summary marks the Viper reward as queued")
	var choice: Dictionary = RewardService.get_active_choice()
	_assert_true(_find_choice_index(choice, "item") >= 0, "Viper reward exposes an item choice from its pool")
	var skill_index: int = _find_choice_index(choice, "skill")
	_assert_true(skill_index >= 0, "Viper reward exposes a skill choice from its pool")
	if skill_index >= 0:
		RewardService.resolve_active_choice(skill_index, inventory, stash)
	_assert_true(GameManager.selected_hero.skills.size() >= 1, "selected monster skill reward is stored on the hero")

func test_high_frequency_event_effects_have_gameplay_results() -> void:
	var event_ids: Array[String] = [
		"a_strange_mushroom", "armory", "b1_b2", "battlefield", "borrow",
		"botanical_gardens", "cache_of_riches", "candy_stash", "cinder_chase",
		"extract_extract", "finns_big_bite", "furnace", "guard_locker",
		"gumball_machine_event", "house_party", "invest_in_yourself", "jungle_ruins",
		"look_for_spare_change", "lost_and_found", "medicine_cabinet", "obstacle_course",
		"procure_medkit", "racetrack", "regenerative_tincture", "relax", "recycling_center",
		"scrap_salvage", "security_center", "sharpening_kit", "snack_time", "start_of_run",
		"study", "the_docks", "the_lost_crate", "tiny_furry_monster", "treasure_chest",
		"utility_box"
	]
	var covered: int = 0
	for event_id in event_ids:
		var game_manager: MockGameManager = _mock_game_manager()
		var inventory: LinearInventoryClass = LinearInventoryClass.new()
		var stash: LinearInventoryClass = LinearInventoryClass.new()
		if event_id == "b1_b2":
			inventory.place_item(BazaarContentClass.create_item("fire_potion", BazaarContentClass.RARITY_BRONZE), 0)
		var result: String = _manager().execute_random_event(event_id, 2, game_manager, inventory, stash)
		_assert_true(not result.begins_with("Unsupported event"), "%s has a gameplay implementation" % event_id)
		covered += 1
		game_manager.free()
	_assert_true(covered >= 20, "at least 20 high-frequency event effects are covered")

	var study_manager: MockGameManager = _mock_game_manager()
	_manager().execute_random_event("study", 2, study_manager)
	_assert_eq(study_manager.xp, 2, "Study grants XP")
	study_manager.free()

	var skill_manager: MockGameManager = _mock_game_manager()
	_manager().execute_random_event("security_center", 2, skill_manager)
	_assert_true(skill_manager.selected_hero.skills.size() == 1, "Security Center grants a skill")
	skill_manager.free()

	var risk_manager: MockGameManager = _mock_game_manager()
	_manager().execute_random_event("the_docks", 4, risk_manager)
	_assert_eq(risk_manager.damage_taken, 10, "The Docks applies risk damage")
	_assert_eq(risk_manager.gold, 55, "The Docks grants early reward gold")
	risk_manager.free()

func test_unsupported_event_fallback_is_explicit() -> void:
	var game_manager: MockGameManager = _mock_game_manager()
	var result: String = _manager().execute_random_event("unimplemented_product_event", 3, game_manager)
	_assert_true(result.begins_with("Unsupported event unimplemented_product_event"), "unsupported event fallback names the missing event")
	game_manager.free()

func _assert_true(condition: bool, label: String) -> void:
	_total += 1
	if condition:
		_passed += 1
		print("PASS: %s" % label)
	else:
		push_error("FAIL: %s" % label)

func _assert_eq(actual, expected, label: String) -> void:
	_assert_true(actual == expected, "%s | expected=%s actual=%s" % [label, str(expected), str(actual)])

func _find_choice_index(choice: Dictionary, kind: String) -> int:
	var options: Array = choice.get("options", [])
	for index in range(options.size()):
		if options[index] is Dictionary and str((options[index] as Dictionary).get("kind", "")) == kind:
			return index
	return -1

func _print_summary() -> void:
	print("SUMMARY: %d/%d passed" % [_passed, _total])
	get_tree().quit(1 if _passed < _total else 0)
