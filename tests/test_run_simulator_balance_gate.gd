extends Node

const RunSimulatorServiceClass = preload("res://scripts/services/run_simulator_service.gd")

const TASK_ID: String = "T-FCG-BAZAAR-P0-RUN-QA-BALANCE-SIM-001"
const STATUS_DIR: String = "user://" + TASK_ID

var _total: int = 0
var _passed: int = 0

func _ready() -> void:
	if not Engine.is_editor_hint():
		print("== tests/test_run_simulator_balance_gate.gd ==")
		_run_tests()
		_print_summary()

func _run_tests() -> void:
	test_seeded_balance_suite_completes_and_writes_report()
	test_seeded_single_run_is_deterministic()

func test_seeded_balance_suite_completes_and_writes_report() -> void:
	var report: Dictionary = RunSimulatorServiceClass.run_balance_suite({
		"seed_count": 32,
		"base_seed": 420240,
		"max_days": 10,
	})
	var write_result: Dictionary = RunSimulatorServiceClass.write_report(report, STATUS_DIR)
	_assert_true(bool(write_result.get("success", false)), "balance report writes JSON and Markdown artifacts")

	var acceptance: Dictionary = report.get("acceptance", {})
	_assert_equal(int(report.get("runs_completed", 0)), 32, "32 seeded runs complete")
	_assert_true(bool(acceptance.get("seed_run_count_ok", false)), "seed count is inside 20-50 acceptance range")
	_assert_true(bool(acceptance.get("no_crash_or_soft_lock", false)), "seeded runs have no soft-locks")
	_assert_true(bool(acceptance.get("major_phases_covered", false)), "all required major phases are covered")
	_assert_true(bool(acceptance.get("curves_reported", false)), "economy and health curves are reported")
	_assert_true(bool(acceptance.get("outliers_flagged", false)), "outlier detection is explicitly reported")

	var coverage: Dictionary = report.get("coverage", {})
	for phase in ["merchant", "service_vendor", "event", "pve", "pvp", "reward_choice", "level_up"]:
		_assert_true(bool(coverage.get(phase, false)), "coverage includes %s" % phase)
	_assert_true(bool(coverage.get("last_chance", false)), "Last Chance path is reachable in seeded probe")

	var aggregate: Dictionary = report.get("aggregate", {})
	for metric in ["gold", "health", "prestige", "level", "item_count"]:
		_assert_true(aggregate.has(metric), "aggregate report includes %s curve" % metric)
		var stats: Dictionary = aggregate.get(metric, {})
		_assert_true(stats.has("min") and stats.has("max") and stats.has("avg"), "%s curve includes min/max/avg" % metric)

func test_seeded_single_run_is_deterministic() -> void:
	var first: Dictionary = RunSimulatorServiceClass.simulate_run({"seed": 424242, "max_days": 5})
	var second: Dictionary = RunSimulatorServiceClass.simulate_run({"seed": 424242, "max_days": 5})
	_assert_equal(first.get("terminal_state", ""), second.get("terminal_state", ""), "same seed has same terminal state")
	_assert_equal(first.get("final", {}), second.get("final", {}), "same seed has same final state")
	_assert_equal(first.get("coverage", {}), second.get("coverage", {}), "same seed has same coverage")
	_assert_true((first.get("soft_locks", []) as Array).is_empty(), "single deterministic run has no soft-lock")

func _assert_true(condition: bool, label: String) -> void:
	_total += 1
	if condition:
		_passed += 1
		print("PASS: %s" % label)
	else:
		push_error("FAIL: %s" % label)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	_assert_true(actual == expected, "%s (expected=%s actual=%s)" % [label, str(expected), str(actual)])

func _print_summary() -> void:
	print("SUMMARY: %d/%d passed" % [_passed, _total])
	get_tree().quit(1 if _passed < _total else 0)
