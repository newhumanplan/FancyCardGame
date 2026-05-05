extends Node

const BazaarContentClass = preload("res://scripts/data/bazaar_content.gd")
const HeroDataClass = preload("res://scripts/data/hero_data.gd")
const PlayerSkillCatalogClass = preload("res://scripts/data/player_skill_catalog.gd")

var _total: int = 0
var _passed: int = 0


func _ready() -> void:
	if not Engine.is_editor_hint():
		print("== tests/test_full_content_parity_p1d_hero_source_runtime.gd ==")
		_run_tests()
		_print_summary()


func _run_tests() -> void:
	test_karnok_source_ingested_runtime_skills()
	test_jules_and_stelle_source_backed_skill_specs_remain_runtime_aligned()


func test_karnok_source_ingested_runtime_skills() -> void:
	var skill_specs: Array[Dictionary] = BazaarContentClass.get_hero_skill_specs(HeroDataClass.HeroType.KARNOK)
	var skill_ids: Array[String] = _skill_ids(skill_specs)
	_assert_true(skill_ids.has("fiery"), "Karnok source ingestion includes Fiery")
	_assert_true(skill_ids.has("tracer_fire"), "Karnok source ingestion includes Tracer Fire")
	_assert_true(skill_specs.size() >= 2, "Karnok no longer has zero source-backed skill specs")
	_assert_source_url(skill_specs, "fiery", "bazaardb.gg/card/yn7vwphhqy8k99dw77zsfznbf6/Fiery")
	_assert_source_url(skill_specs, "tracer_fire", "bazaardb.gg/card/l6xgwy6ftvdf81y8t3jjm90w3c/Tracer-Fire")
	_assert_skill_runtime_backed("fiery", "Karnok Fiery")
	_assert_skill_runtime_backed("tracer_fire", "Karnok Tracer Fire")


func test_jules_and_stelle_source_backed_skill_specs_remain_runtime_aligned() -> void:
	var jules_ids: Array[String] = _skill_ids(BazaarContentClass.get_hero_skill_specs(HeroDataClass.HeroType.JULES))
	for skill_id in ["fiery", "tools_of_the_trade", "strength", "tracer_fire", "flashy_mechanic"]:
		_assert_true(jules_ids.has(skill_id), "Jules source-backed skill spec exists: %s" % skill_id)
		_assert_skill_runtime_backed(skill_id, "Jules %s" % skill_id)

	var stelle_ids: Array[String] = _skill_ids(BazaarContentClass.get_hero_skill_specs(HeroDataClass.HeroType.STELLE))
	for skill_id in ["command_ship", "slow_and_steady", "slowed_targets", "tools_of_the_trade", "tracer_fire"]:
		_assert_true(stelle_ids.has(skill_id), "Stelle source-backed skill spec exists: %s" % skill_id)
		_assert_skill_runtime_backed(skill_id, "Stelle %s" % skill_id)


func _skill_ids(skill_specs: Array[Dictionary]) -> Array[String]:
	var ids: Array[String] = []
	for spec in skill_specs:
		var skill_id: String = str(spec.get("id", ""))
		if not skill_id.is_empty() and not ids.has(skill_id):
			ids.append(skill_id)
	ids.sort()
	return ids


func _assert_source_url(skill_specs: Array[Dictionary], skill_id: String, expected_substring: String) -> void:
	for spec in skill_specs:
		if str(spec.get("id", "")) == skill_id:
			_assert_true(str(spec.get("source_url", "")).find(expected_substring) >= 0, "%s records source URL" % skill_id)
			return
	_assert_true(false, "%s source spec exists" % skill_id)


func _assert_skill_runtime_backed(skill_id: String, label: String) -> void:
	var entry: Dictionary = PlayerSkillCatalogClass.get_skill_entry(skill_id)
	_assert_eq(str(entry.get("support_status", "")), PlayerSkillCatalogClass.SUPPORT_IMPLEMENTED, "%s is implemented" % label)
	var has_runtime_rule: bool = not (entry.get("numeric_rule", {}) as Dictionary).is_empty() or not (entry.get("trigger_rule", {}) as Dictionary).is_empty()
	_assert_true(has_runtime_rule, "%s has runtime rule" % label)


func _assert_true(condition: bool, label: String) -> void:
	_total += 1
	if condition:
		_passed += 1
		print("PASS: %s" % label)
	else:
		push_error("FAIL: %s" % label)


func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	_assert_true(actual == expected, "%s | expected=%s actual=%s" % [label, str(expected), str(actual)])


func _print_summary() -> void:
	print("SUMMARY: %d/%d passed" % [_passed, _total])
	get_tree().quit(1 if _passed < _total else 0)
