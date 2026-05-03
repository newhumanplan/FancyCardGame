extends Node

const BattleUIClass = preload("res://scripts/ui/battle_ui.gd")
const BazaarContentClass = preload("res://scripts/data/bazaar_content.gd")
const MonsterDataClass = preload("res://scripts/data/monster_data.gd")

var _total: int = 0
var _passed: int = 0

func _ready() -> void:
	if not Engine.is_editor_hint():
		print("== tests/test_battle_ui_opponent_skills.gd ==")
		test_opponent_skill_labels_use_monster_skills()
		test_opponent_skill_labels_show_empty_without_skill_entries()
		test_bazaar_pve_monster_skill_labels_stay_on_skill_names()
		_print_summary()

func test_opponent_skill_labels_use_monster_skills() -> void:
	var battle_ui: BattleUI = BattleUIClass.new()
	var monster: MonsterData = MonsterDataClass.new()
	monster.monster_skills = [
		{"name": "Hard Shell"},
		{"name": "Lash Out"},
	]
	monster.monster_items = [
		{"name": "Tusked Helm"},
		{"name": "Cargo"},
	]
	battle_ui.current_monster = monster
	battle_ui.pvp_opponent_skill_labels = _make_skill_labels(4)

	battle_ui._update_pvp_opponent_skills()

	_assert_eq(battle_ui.pvp_opponent_skill_labels[0].text, "Hard Shell", "opponent skill label uses first monster skill")
	_assert_eq(battle_ui.pvp_opponent_skill_labels[1].text, "Lash Out", "opponent skill label uses second monster skill")
	_assert_eq(battle_ui.pvp_opponent_skill_labels[2].text, "Empty", "unused opponent skill slots stay empty")
	_assert_true(not _labels_contain_text(battle_ui.pvp_opponent_skill_labels, "Tusked Helm"), "opponent skill labels do not fall back to monster item names")
	_assert_true(not _labels_contain_text(battle_ui.pvp_opponent_skill_labels, "Cargo"), "opponent skill labels exclude other monster item names")
	_free_skill_labels(battle_ui.pvp_opponent_skill_labels)
	battle_ui.free()

func test_opponent_skill_labels_show_empty_without_skill_entries() -> void:
	var battle_ui: BattleUI = BattleUIClass.new()
	var monster: MonsterData = MonsterDataClass.new()
	monster.monster_items = [{"name": "Poison Fang"}]
	battle_ui.current_monster = monster
	battle_ui.pvp_opponent_skill_labels = _make_skill_labels(3)

	battle_ui._update_pvp_opponent_skills()

	for label in battle_ui.pvp_opponent_skill_labels:
		_assert_eq(label.text, "Empty", "monsters without skills keep Empty placeholder")
	_free_skill_labels(battle_ui.pvp_opponent_skill_labels)
	battle_ui.free()

func test_bazaar_pve_monster_skill_labels_stay_on_skill_names() -> void:
	var battle_ui: BattleUI = BattleUIClass.new()
	var monster: MonsterData = BazaarContentClass.create_day1_monster("viper")
	battle_ui.current_monster = monster
	battle_ui.pvp_opponent_skill_labels = _make_skill_labels(4)

	battle_ui._update_pvp_opponent_skills()

	var expected_skill_name: String = str(monster.monster_skills[0].get("name", ""))
	var first_item_name: String = str(monster.monster_items[0].get("name", ""))
	_assert_eq(battle_ui.pvp_opponent_skill_labels[0].text, expected_skill_name, "PvE monster skill label matches Bazaar monster_skills data")
	_assert_true(expected_skill_name != first_item_name, "test fixture distinguishes skill names from item names")
	_assert_true(not _labels_contain_text(battle_ui.pvp_opponent_skill_labels, first_item_name), "PvE monster skill labels do not show first item name")
	_free_skill_labels(battle_ui.pvp_opponent_skill_labels)
	battle_ui.free()

func _make_skill_labels(count: int) -> Array[Label]:
	var labels: Array[Label] = []
	for index in range(count):
		var label: Label = Label.new()
		label.text = "Seed %d" % index
		labels.append(label)
	return labels

func _labels_contain_text(labels: Array[Label], needle: String) -> bool:
	for label in labels:
		if label.text == needle:
			return true
	return false

func _free_skill_labels(labels: Array[Label]) -> void:
	for label in labels:
		label.free()

func _assert_true(condition: bool, label: String) -> void:
	_total += 1
	if condition:
		_passed += 1
		print("PASS: %s" % label)
	else:
		push_error("FAIL: %s" % label)

func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	_assert_true(actual == expected, "%s (expected=%s actual=%s)" % [label, str(expected), str(actual)])

func _print_summary() -> void:
	print("SUMMARY: %d/%d passed" % [_passed, _total])
	get_tree().quit(1 if _passed < _total else 0)
