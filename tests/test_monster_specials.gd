extends Node

const BazaarContentClass = preload("res://scripts/data/bazaar_content.gd")
const EventManagerClass = preload("res://scripts/data/event_manager.gd")
const HeroDataClass = preload("res://scripts/data/hero_data.gd")
const LinearInventoryClass = preload("res://scripts/data/linear_inventory.gd")
const RunSimulatorServiceClass = preload("res://scripts/services/run_simulator_service.gd")

var _total: int = 0
var _passed: int = 0

func _ready() -> void:
	if not Engine.is_editor_hint():
		print("== tests/test_monster_specials.gd ==")
		_run_tests()
		_print_summary()

func _run_tests() -> void:
	test_top_30_monster_special_report_has_evidence_or_reasons()
	test_monster_options_surface_risk_and_reward_paths()
	test_reward_choice_exposes_item_skill_and_payout_paths()
	test_representative_monster_runtime_specials_are_deterministic()
	test_simulator_reports_pve_win_loss_reward_curve()

func _reset_services() -> void:
	RewardService.reset_runtime_state()
	EconomyService.reset()
	RunStateService.reset(true)
	HeroStateService.reset()
	GameManager.reset_stats()
	var hero = HeroFactoryService.create_hero(HeroDataClass.HeroType.MAK)
	GameManager.select_hero(hero)
	if GameManager.selected_hero != null:
		GameManager.selected_hero.crit_chance = 0.0

func test_top_30_monster_special_report_has_evidence_or_reasons() -> void:
	var report: Dictionary = BazaarContentClass.get_top_monster_special_report(30)
	_assert_eq(int(report.get("monster_count", 0)), 30, "top monster report covers exactly 30 representatives")
	_assert_true(int(report.get("supported_count", 0)) >= 30, "all top monsters have at least board/item runtime mechanics")
	var reward_counts: Dictionary = report.get("reward_path_count", {})
	_assert_true(int(reward_counts.get("item", 0)) >= 30, "top monsters expose item reward paths")
	_assert_true(int(reward_counts.get("skill", 0)) >= 20, "top monsters expose skill reward paths where catalog skills exist")
	_assert_true(int(reward_counts.get("payout", 0)) >= 30, "top monsters expose payout reward paths")
	for entry in report.get("monsters", []):
		if not entry is Dictionary:
			_assert_true(false, "monster report entry is a dictionary")
			continue
		var supported_mechanics: Array = (entry as Dictionary).get("supported_mechanics", [])
		var unsupported_reasons: Array = (entry as Dictionary).get("unsupported_reasons", [])
		_assert_true(not supported_mechanics.is_empty() or not unsupported_reasons.is_empty(), "%s has deterministic mechanics or exact unsupported reasons" % str((entry as Dictionary).get("id", "")))
		for reason in unsupported_reasons:
			_assert_true(str(reason).find(":") >= 0, "%s unsupported reason is exact: %s" % [str((entry as Dictionary).get("id", "")), str(reason)])

func test_monster_options_surface_risk_and_reward_paths() -> void:
	seed(221451)
	var options: Array[Dictionary] = EventManagerClass.new().generate_options(PhaseService.PHASE_PVE, 5)
	_assert_true(options.size() > 0, "PvE hour generates monster options")
	for option in options:
		_assert_eq(str(option.get("type", "")), "monster", "PvE option is a monster")
		_assert_true(int(option.get("risk_score", 0)) >= 5, "monster option includes day-scaled risk score")
		_assert_true(not (option.get("risk_tags", []) as Array).is_empty(), "monster option includes risk tags")
		var reward_paths: Array = option.get("reward_paths", [])
		_assert_true(reward_paths.has("item"), "monster option includes item reward path")
		_assert_true(reward_paths.has("payout"), "monster option includes payout reward path")
		_assert_true(str(option.get("summary", "")).begins_with("Risk"), "monster option summary communicates risk/reward")

func test_reward_choice_exposes_item_skill_and_payout_paths() -> void:
	_reset_services()
	var inventory: LinearInventoryClass = LinearInventoryClass.new()
	var stash: LinearInventoryClass = LinearInventoryClass.new()
	var monster = BazaarContentClass.create_day1_monster("viper")
	var result: Dictionary = BattleProgressionService.apply_battle_result(true, false, monster, inventory, stash)
	_assert_true(bool(result.get("reward_choice_queued", false)), "Viper win queues monster reward choice")
	var choice: Dictionary = RewardService.get_active_choice()
	_assert_eq(str(choice.get("monster_id", "")), "viper", "reward choice keeps monster id")
	_assert_true(int(choice.get("risk_score", 0)) > 0, "reward choice includes monster risk score")
	_assert_true(_find_choice_index(choice, "item") >= 0, "reward choice has monster item path")
	_assert_true(_find_choice_index(choice, "skill") >= 0, "reward choice has monster skill path")
	var payout_index: int = _find_choice_index(choice, "fallback")
	_assert_true(payout_index >= 0, "reward choice has payout path")
	if payout_index >= 0:
		var payout: Dictionary = (choice.get("options", []) as Array)[payout_index]
		_assert_eq(str(payout.get("reward_path", "")), "payout", "fallback option is labelled as payout path")
		var payout_reward: Dictionary = payout.get("reward", {})
		_assert_true(int(payout_reward.get("gold", 0)) > 0 and int(payout_reward.get("xp", 0)) > 0, "payout combines gold and XP")

func test_representative_monster_runtime_specials_are_deterministic() -> void:
	_reset_services()
	var inventory: LinearInventoryClass = LinearInventoryClass.new()
	var viper = BazaarContentClass.create_day1_monster("viper")
	BattleSystem.start_battle(viper, inventory)
	var status: Dictionary = BattleSystem.get_status_totals("player")
	_assert_eq(int(status.get("poison", 0)), 3, "Viper Lash Out applies start poison")
	BattleSystem.end_battle()

	_reset_services()
	inventory = LinearInventoryClass.new()
	var pyro = BazaarContentClass.create_day1_monster("pyro")
	var lighter: Dictionary = _find_monster_item(pyro, "lighter")
	_assert_true(int(lighter.get("burn", 0)) >= 3, "Pyro Lighter carries deterministic burn before combat")
	BattleSystem.start_battle(pyro, inventory)
	_force_item_ready(pyro, "lighter")
	BattleSystem.execute_battle_tick(0.0)
	status = BattleSystem.get_status_totals("player")
	_assert_true(int(status.get("burn", 0)) >= 3, "Pyro Lighter applies burn in combat")
	BattleSystem.end_battle()

	_reset_services()
	inventory = LinearInventoryClass.new()
	var crab = BazaarContentClass.create_monster("coconut_crab", 2)
	BattleSystem.start_battle(crab, inventory)
	_force_item_ready(crab, "sea_shell")
	BattleSystem.execute_battle_tick(0.5)
	_assert_true(crab.current_shield > 0.0, "Coconut Crab Sea Shell creates monster shield")
	BattleSystem.end_battle()

func test_simulator_reports_pve_win_loss_reward_curve() -> void:
	var report: Dictionary = RunSimulatorServiceClass.run_balance_suite({"seed_count": 8, "base_seed": 6221451, "max_days": 10})
	var pve_curve: Dictionary = report.get("pve_curve", {})
	_assert_true(int(pve_curve.get("encounters", 0)) > 0, "simulator records PvE encounters")
	_assert_true(int(pve_curve.get("wins", 0)) > 0, "simulator records PvE wins")
	_assert_true(int(pve_curve.get("losses", 0)) > 0, "simulator records PvE losses")
	_assert_true(int(pve_curve.get("reward_choices", 0)) > 0, "simulator records PvE reward choice curve")
	var acceptance: Dictionary = report.get("acceptance", {})
	_assert_true(bool(acceptance.get("pve_win_loss_curve_reported", false)), "acceptance reports PvE win/loss curve")
	_assert_true(bool(acceptance.get("pve_reward_curve_reported", false)), "acceptance reports PvE reward curve")
	var special_report: Dictionary = report.get("monster_special_report", {})
	_assert_eq(int(special_report.get("monster_count", 0)), 30, "simulator includes top-30 monster special report")

func _force_item_ready(monster, source_id: String) -> void:
	for item in monster.monster_items:
		if str(item.get("source_id", "")) == source_id:
			item["current_cooldown"] = 0.0

func _find_monster_item(monster, source_id: String) -> Dictionary:
	for item in monster.monster_items:
		if str(item.get("source_id", "")) == source_id:
			return item
	return {}

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

func _print_summary() -> void:
	print("SUMMARY: %d/%d passed" % [_passed, _total])
	get_tree().quit(1 if _passed < _total else 0)
