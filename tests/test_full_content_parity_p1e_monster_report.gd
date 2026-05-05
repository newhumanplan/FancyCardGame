extends Node

const BazaarContentClass = preload("res://scripts/data/bazaar_content.gd")

var _total: int = 0
var _passed: int = 0

func _ready() -> void:
	if not Engine.is_editor_hint():
		print("== tests/test_full_content_parity_p1e_monster_report.gd ==")
		test_all_101_monster_parity_report_shape()
		test_missing_mechanics_are_grouped_by_required_axes()
		test_report_artifact_is_written()
		_print_summary()

func test_all_101_monster_parity_report_shape() -> void:
	var report: Dictionary = BazaarContentClass.get_all_monster_parity_report()
	_assert_eq(int(report.get("schema_version", 0)), 2, "monster parity report schema version")
	_assert_eq(str(report.get("selection", "")), "all 101 wiki catalog monsters", "report documents all-catalog selection")
	_assert_eq(int(report.get("monster_count", 0)), 101, "report covers all 101 catalog monsters")
	_assert_eq((report.get("monsters", []) as Array).size(), 101, "report includes one entry per monster")
	_assert_true(int(report.get("supported_count", 0)) > 0, "report counts supported monster runtime evidence")
	_assert_true(int(report.get("missing_mechanics_count", 0)) > 0, "report preserves explicit missing mechanics")
	var reward_counts: Dictionary = report.get("reward_path_count", {})
	_assert_true(int(reward_counts.get("payout", 0)) == 101, "every catalog monster has payout fallback path")
	_assert_true(int(reward_counts.get("item", 0)) >= 90, "catalog monsters expose item reward paths where source items exist")
	_assert_true(int(reward_counts.get("skill", 0)) >= 70, "catalog monsters expose skill reward paths where source skills exist")
	var first_entry: Dictionary = (report.get("monsters", []) as Array)[0]
	_assert_eq(str(first_entry.get("deterministic_evidence", "")), "tests/test_full_content_parity_p1e_monster_report.gd", "all-101 report marks P1E deterministic evidence")

func test_missing_mechanics_are_grouped_by_required_axes() -> void:
	var report: Dictionary = BazaarContentClass.get_all_monster_parity_report()
	var grouped: Dictionary = report.get("grouped_missing_mechanics", {})
	var by_monster: Array = grouped.get("by_monster", [])
	var by_level: Array = grouped.get("by_level", [])
	var by_day: Array = grouped.get("by_day", [])
	var by_risk: Array = grouped.get("by_risk", [])
	var reason_counts: Dictionary = grouped.get("reason_counts", {})
	_assert_eq(by_monster.size(), int(report.get("missing_mechanics_count", 0)), "by_monster count matches missing mechanics count")
	_assert_true(not by_level.is_empty(), "missing mechanics are grouped by level")
	_assert_true(not by_day.is_empty(), "missing mechanics are grouped by encounter day")
	_assert_true(not by_risk.is_empty(), "missing mechanics are grouped by risk")
	_assert_true(not reason_counts.is_empty(), "missing mechanics include reason counts")
	for entry in by_monster:
		var monster: Dictionary = entry as Dictionary
		_assert_true(not str(monster.get("id", "")).is_empty(), "missing entry keeps monster id")
		_assert_true(monster.has("level"), "missing entry keeps level")
		_assert_true(monster.has("day"), "missing entry keeps day")
		_assert_true(monster.has("risk_score"), "missing entry keeps risk score")
		_assert_true(not (monster.get("unsupported_reasons", []) as Array).is_empty(), "missing entry has exact unsupported reasons")
		for reason in monster.get("unsupported_reasons", []):
			_assert_true(str(reason).find(":") >= 0 or str(reason) == "missing_monster_spec", "unsupported reason remains exact: %s" % str(reason))

func test_report_artifact_is_written() -> void:
	var report: Dictionary = BazaarContentClass.get_all_monster_parity_report()
	var output_dir: String = ProjectSettings.globalize_path("res://.codex-status/T-FCG-FULL-CONTENT-PARITY-001/P1E")
	var err: Error = DirAccess.make_dir_recursive_absolute(output_dir)
	_assert_eq(err, OK, "P1E status directory is writable")
	var output_path: String = output_dir.path_join("monster_parity_101_report.json")
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	_assert_true(file != null, "P1E monster parity report artifact can be opened")
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	_assert_true(FileAccess.file_exists(output_path), "P1E monster parity report artifact exists")
	var loaded := FileAccess.open(output_path, FileAccess.READ)
	_assert_true(loaded != null, "P1E monster parity report artifact can be read")
	if loaded != null:
		var parsed = JSON.parse_string(loaded.get_as_text())
		loaded.close()
		_assert_true(parsed is Dictionary, "P1E report artifact contains JSON object")
		if parsed is Dictionary:
			_assert_eq(int((parsed as Dictionary).get("monster_count", 0)), 101, "P1E report artifact preserves all-101 count")

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
