extends Node

const BazaarContentClass = preload("res://scripts/data/bazaar_content.gd")
const EventManagerClass = preload("res://scripts/data/event_manager.gd")
const LinearInventoryClass = preload("res://scripts/data/linear_inventory.gd")
const RunSimulatorServiceClass = preload("res://scripts/services/run_simulator_service.gd")

const COVERAGE_TARGET: int = 70

var _total: int = 0
var _passed: int = 0

func _ready() -> void:
	if not Engine.is_editor_hint():
		print("== tests/test_event_service_coverage.gd ==")
		_run_tests()
		_print_summary()

func _run_tests() -> void:
	test_event_gameplay_coverage_reaches_70_plus()
	test_remaining_unsupported_events_have_reasons()
	test_new_reward_events_mutate_through_services()
	test_seeded_run_reports_build_hour_variety()

func test_event_gameplay_coverage_reaches_70_plus() -> void:
	var report: Dictionary = EventManagerClass.new().get_event_gameplay_coverage_report()
	_assert_true(int(report.get("total", 0)) >= 88, "coverage probe sees the full event catalog")
	_assert_true(int(report.get("implemented_total", 0)) >= COVERAGE_TARGET, "implemented event gameplay coverage is >=70")
	_assert_true((report.get("implemented_ids", []) as Array).has("cabin_fishing"), "new Vanessa event coverage includes Cabin Fishing")
	_assert_true((report.get("implemented_ids", []) as Array).has("economic_seminar"), "new economy event coverage includes Economic Seminar")
	_assert_true((report.get("implemented_ids", []) as Array).has("workshop"), "new service-like event coverage includes Workshop")

func test_remaining_unsupported_events_have_reasons() -> void:
	var report: Dictionary = EventManagerClass.new().get_event_gameplay_coverage_report()
	var unsupported: Array = report.get("unsupported", [])
	_assert_true(not unsupported.is_empty(), "coverage probe keeps unsupported events visible")
	for entry in unsupported:
		var reason: String = str((entry as Dictionary).get("reason", ""))
		_assert_true(not reason.strip_edges().is_empty(), "unsupported event %s has an explicit reason" % str((entry as Dictionary).get("id", "")))
		_assert_true(reason != "no gameplay effect registered", "unsupported event %s reason is specific" % str((entry as Dictionary).get("id", "")))
	var result: String = EventManagerClass.new().execute_random_event("dabora", 2, GameManager)
	_assert_true(result.find("disabled") >= 0, "disabled event fallback explains why it is unsupported")

func test_new_reward_events_mutate_through_services() -> void:
	_reset_runtime()
	var inventory: LinearInventoryClass = LinearInventoryClass.new()
	var stash: LinearInventoryClass = LinearInventoryClass.new()
	var manager: EventManagerClass = EventManagerClass.new()
	var starting_income: int = EconomyService.income
	var result: String = manager.execute_random_event("economic_seminar", 3, GameManager, inventory, stash)
	_assert_true(result.find("Economic Seminar") >= 0, "event result names the mapped event")
	_assert_true(EconomyService.income > starting_income, "Economic Seminar mutates income through EconomyService")
	var gold_after_seminar: int = EconomyService.gold
	manager.execute_random_event("mountain_pass", 4, GameManager, inventory, stash)
	_assert_true(EconomyService.gold > gold_after_seminar, "Mountain Pass applies gold through RewardService/EconomyService")
	manager.execute_random_event("cabin_fishing", 2, GameManager, inventory, stash)
	_assert_true(inventory.items.size() + stash.items.size() >= 1, "Cabin Fishing grants an item through RewardService")
	manager.execute_random_event("workshop", 4, GameManager, inventory, stash)
	_assert_true(RewardService.has_pending_choice() or inventory.items.size() + stash.items.size() >= 1, "Workshop leaves gameplay state actionable")

func test_seeded_run_reports_build_hour_variety() -> void:
	var report: Dictionary = RunSimulatorServiceClass.run_balance_suite({"seed_count": 24, "base_seed": 430100, "max_days": 10})
	var acceptance: Dictionary = report.get("acceptance", {})
	_assert_true(bool(acceptance.get("event_coverage_70_plus", false)), "balance report includes event coverage gate")
	_assert_true(bool(acceptance.get("build_hour_option_variety_ok", false)), "seeded runs avoid stale build-hour choices")
	var variety: Dictionary = report.get("option_variety", {})
	_assert_true(int(variety.get("unique_event_ids", 0)) >= 10, "seeded runs expose at least 10 unique event ids")
	_assert_true(int(variety.get("unique_service_ids", 0)) >= 6, "seeded runs expose all service vendor ids")
	_assert_true(int(variety.get("unique_build_hour_signatures", 0)) >= 12, "seeded runs expose varied build-hour option signatures")

func _reset_runtime() -> void:
	RewardService.reset_runtime_state()
	EconomyService.reset()
	RunStateService.reset(true)
	HeroStateService.reset()
	GameManager.reset_stats()
	GameManager.select_hero(BazaarContentClass.create_mak_hero())

func _assert_true(condition: bool, label: String) -> void:
	_total += 1
	if condition:
		_passed += 1
		print("PASS: %s" % label)
	else:
		push_error("FAIL: %s" % label)

func _print_summary() -> void:
	print("SUMMARY: %d/%d passed" % [_passed, _total])
	get_tree().quit(1 if _passed < _total else 0)
