extends Node

const BattleUIClass = preload("res://scripts/ui/battle_ui.gd")
const BazaarContentClass = preload("res://scripts/data/bazaar_content.gd")
const BottomHudPanelScene = preload("res://scenes/ui/bottom_hud_panel.tscn")
const HeroDataClass = preload("res://scripts/data/hero_data.gd")
const LinearInventoryClass = preload("res://scripts/data/linear_inventory.gd")
const MonsterDataClass = preload("res://scripts/data/monster_data.gd")

var _total: int = 0
var _passed: int = 0

func _ready() -> void:
	if not Engine.is_editor_hint():
		print("== tests/test_playtest_ui_start_state_regression.gd ==")
		test_monster_slot_assignment_avoids_overlap()
		test_battle_skill_slots_do_not_overlap_wallet()
		test_profile_skill_pool_is_not_rendered_as_owned_skills()
		_print_summary()

func test_monster_slot_assignment_avoids_overlap() -> void:
	var ui: BattleUIClass = BattleUIClass.new()
	var monster_items: Array = [
		{"name": "First", "size": "Small", "slot_index": 0},
		{"name": "Second", "size": "Large", "slot_index": 1},
		{"name": "Third", "size": "Medium", "slot_index": 2},
		{"name": "Fourth", "size": "Small", "slot_index": 3},
		{"name": "Fifth", "size": "Medium"},
		{"name": "Sixth", "size": "Small"},
	]
	var assigned: Array = ui.call("_assign_shell_monster_item_slots", monster_items)
	_assert_eq(assigned.size(), 6, "all six monster items receive a visible slot assignment")
	var occupied: Dictionary = {}
	for placed_variant in assigned:
		var placed: Dictionary = placed_variant
		var slot_index: int = int(placed.get("slot_index", -1))
		var slot_count: int = int(placed.get("slot_count", 0))
		_assert_true(slot_index >= 0 and slot_index + slot_count <= 10, "monster item slot span remains within board")
		for slot in range(slot_index, slot_index + slot_count):
			_assert_true(not occupied.has(slot), "monster item slot %d is not double-booked" % slot)
			occupied[slot] = true
	ui.free()

func test_battle_skill_slots_do_not_overlap_wallet() -> void:
	var wallet_1280: Rect2 = _percent_rect(Vector2(1280, 720), 0.80, 0.80, 0.94, 0.85)
	var left_1280: Rect2 = _percent_rect(Vector2(1280, 720), 0.18, 0.62, 0.38, 0.74)
	var right_1280: Rect2 = _percent_rect(Vector2(1280, 720), 0.58, 0.62, 0.74, 0.74)
	_assert_true(not _rects_overlap(right_1280, wallet_1280), "right skill area does not overlap gold/income wallet at 1280x720")
	_assert_true(not _rects_overlap(left_1280, wallet_1280), "left skill area does not overlap gold/income wallet at 1280x720")

	var wallet_1920: Rect2 = _percent_rect(Vector2(1920, 1080), 0.80, 0.80, 0.94, 0.85)
	var right_1920: Rect2 = _percent_rect(Vector2(1920, 1080), 0.58, 0.62, 0.74, 0.74)
	_assert_true(not _rects_overlap(right_1920, wallet_1920), "right skill area does not overlap gold/income wallet at 1920x1080")

func test_profile_skill_pool_is_not_rendered_as_owned_skills() -> void:
	var hero: HeroDataClass = BazaarContentClass.create_bazaar_hero(HeroDataClass.HeroType.MAK)
	BazaarContentClass.apply_phase1_player_skill_loadout(hero)
	_game_manager().call("reset_stats")
	_game_manager().set("selected_hero", hero)
	_game_manager().set("player_health", hero.max_hp)
	var inv: LinearInventoryClass = LinearInventoryClass.new()
	var monster: MonsterDataClass = MonsterDataClass.new()
	monster.monster_name = "Skill Display Test"
	monster.max_hp = 100
	monster.current_hp = 100
	monster.monster_items = []
	monster.monster_skills = []
	_battle_system().call("start_battle", monster, inv)

	var ui: BattleUIClass = BattleUIClass.new()
	ui.set("game_manager", _game_manager())
	ui.set("battle_system", _battle_system())
	var names: Array = ui.call("_get_player_skill_names")
	_assert_eq(names.size(), 0, "profile starter skill pool is not rendered as owned battle skills")
	hero.skills.append("strength")
	names = ui.call("_get_player_skill_names")
	_assert_eq(names.size(), 1, "non-profile acquired skill is rendered")
	_assert_eq(str(names[0]), "Strength", "acquired skill display name is resolved")

	var skill_labels: Array[Label] = []
	for index in range(4):
		var label := Label.new()
		label.visible = true
		skill_labels.append(label)
	ui.call("_update_skill_labels", skill_labels, Array([], TYPE_STRING, &"", null), false)
	for label in skill_labels:
		_assert_true(not label.visible and label.text.is_empty(), "empty battle skill slot is hidden")
		label.free()
	ui.free()
	_battle_system().call("end_battle")

	var hud: Control = BottomHudPanelScene.instantiate() as Control
	add_child(hud)
	hud.call("bind_services", _game_manager(), null, null)
	var passive_area: Control = hud.get_node("HudFrame/PassiveSkillArea") as Control
	_assert_true(passive_area.visible, "bottom HUD shows acquired non-profile skill after reward/add")
	_assert_eq(passive_area.get_child_count(), 1, "bottom HUD does not render profile skill pool badges")
	hero.skills.clear()
	BazaarContentClass.apply_phase1_player_skill_loadout(hero)
	hud.call("refresh_all")
	_assert_true(not passive_area.visible, "bottom HUD hides skill area when only profile skill pool exists")
	_assert_eq(passive_area.get_child_count(), 0, "bottom HUD renders no placeholder skill badges")
	remove_child(hud)
	hud.free()

func _percent_rect(viewport_size: Vector2, left: float, top: float, right: float, bottom: float) -> Rect2:
	var position: Vector2 = Vector2(viewport_size.x * left, viewport_size.y * top)
	var size: Vector2 = Vector2(viewport_size.x * (right - left), viewport_size.y * (bottom - top))
	return Rect2(position, size)

func _rects_overlap(a: Rect2, b: Rect2) -> bool:
	return a.intersects(b) and a.get_area() > 0.0 and b.get_area() > 0.0

func _battle_system() -> Node:
	return get_node("/root/BattleSystem")

func _game_manager() -> Node:
	return get_node("/root/GameManager")

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
