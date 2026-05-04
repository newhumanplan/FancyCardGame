extends Node

const PvpGhostServiceClass = preload("res://scripts/services/pvp_ghost_service.gd")
const GhostSnapshotClass = preload("res://scripts/data/ghost_snapshot.gd")
const ItemArtCatalogClass = preload("res://scripts/data/item_art_catalog.gd")

var _total: int = 0
var _passed: int = 0

func _ready() -> void:
	if not Engine.is_editor_hint():
		print("== tests/test_pvp_ghost_snapshots.gd ==")
		await _run_tests()
		_print_summary()

func _run_tests() -> void:
	test_snapshot_json_roundtrip_is_deterministic()
	test_curated_archetype_validation_success_and_snapshot_conversion()
	test_curated_archetype_validation_failures()
	test_over_slot_save_error_preserves_previous_document()
	test_seed_pool_loads_days_1_to_10()
	test_power_score_is_roughly_monotonic_by_day()
	test_local_playtest_snapshot_files_validate_as_ghost_schema()
	test_power_profile_and_index_include_match_dimensions()
	test_local_match_report_scores_and_rotates_same_band_candidates()
	test_local_power_bucket_match_precedes_curated_fallback()
	test_curated_fallback_when_no_local_power_band_match()
	test_battle_replay_summary_extracts_major_drivers()
	test_runic_daggers_item_art_loads_without_raw_resource_fallback()
	await test_curated_editor_entry_opens_from_bazaar_shell()
	await test_pvp_battle_uses_ghost_snapshot_path()

func test_snapshot_json_roundtrip_is_deterministic() -> void:
	var store_dir: String = "user://ghost_pool_test/roundtrip_empty"
	_remove_tree(store_dir)
	var snapshot = PvpGhostServiceClass.pick_snapshot_for_day(
		5,
		PvpGhostServiceClass.DEFAULT_CURATED_PATH,
		-1,
		store_dir
	)
	_assert_true(snapshot != null and not str(snapshot.snapshot_id).is_empty(), "pick_snapshot_for_day returns a ghost")
	if snapshot == null or str(snapshot.snapshot_id).is_empty():
		return

	var original_json: String = snapshot.to_json_string("\t")
	var parser := JSON.new()
	_assert_eq(parser.parse(original_json), OK, "ghost snapshot JSON serializes cleanly")
	if parser.parse(original_json) != OK:
		return
	var restored = GhostSnapshotClass.from_dictionary(parser.get_data() as Dictionary)
	var restored_json: String = restored.to_json_string("\t")
	_assert_eq(restored_json, original_json, "ghost snapshot JSON roundtrip stays deterministic")
	_assert_eq(restored.to_dictionary(), snapshot.to_dictionary(), "ghost snapshot dictionary roundtrip preserves fields")
	_remove_tree(store_dir)

func test_curated_archetype_validation_success_and_snapshot_conversion() -> void:
	var loaded: Dictionary = PvpGhostServiceClass.load_curated_file()
	_assert_true(bool(loaded.get("success", false)), "curated archetype seed file loads")
	var archetypes: Array[Dictionary] = loaded.get("archetypes", [])
	_assert_true(not archetypes.is_empty(), "curated archetype seed file is not empty")
	if archetypes.is_empty():
		return

	var validation: Dictionary = PvpGhostServiceClass.validate_curated_archetype(archetypes[0])
	_assert_true(bool(validation.get("valid", false)), "seed archetype validates successfully")
	var snapshot = PvpGhostServiceClass.curated_archetype_to_snapshot(archetypes[0])
	_assert_true(not str(snapshot.snapshot_id).is_empty(), "curated archetype converts to ghost snapshot")
	_assert_true(snapshot.power_score > 0, "converted ghost snapshot has a power score")
	_assert_true(not str(snapshot.power_bucket).is_empty(), "converted ghost snapshot has a power bucket")

func test_curated_archetype_validation_failures() -> void:
	var invalid_hero: Dictionary = PvpGhostServiceClass.get_default_archetype()
	invalid_hero["hero_id"] = "not_a_hero"
	_assert_has_error(
		PvpGhostServiceClass.validate_curated_archetype(invalid_hero),
		"unknown_hero:",
		"unknown hero fails validation"
	)

	var invalid_skill: Dictionary = PvpGhostServiceClass.get_default_archetype()
	invalid_skill["skills"] = [{"id": "not_a_skill", "tier": "bronze"}]
	_assert_has_error(
		PvpGhostServiceClass.validate_curated_archetype(invalid_skill),
		"unknown_skill:",
		"unknown skill fails validation"
	)

	var unsupported_skill: Dictionary = PvpGhostServiceClass.get_default_archetype()
	unsupported_skill["skills"] = [{"id": "initial_chill", "tier": "bronze"}]
	_assert_has_error(
		PvpGhostServiceClass.validate_curated_archetype(unsupported_skill),
		"unsupported_skill:",
		"explicitly unsupported skill stays visible at validation time"
	)

	var invalid_item: Dictionary = PvpGhostServiceClass.get_default_archetype()
	invalid_item["items"] = [{"item_id": "not_an_item", "tier": "bronze", "size": 1, "slot_index": 0, "enchantment": "", "cooldown": 0.0, "ammo": 0, "charges": 0}]
	_assert_has_error(
		PvpGhostServiceClass.validate_curated_archetype(invalid_item),
		"unknown_item:",
		"unknown item fails validation"
	)

	var invalid_enchantment: Dictionary = PvpGhostServiceClass.get_default_archetype()
	invalid_enchantment["items"] = [{"item_id": "lighter", "tier": "bronze", "size": 1, "slot_index": 0, "enchantment": "arcane", "cooldown": 4.0, "ammo": 0, "charges": 0}]
	_assert_has_error(
		PvpGhostServiceClass.validate_curated_archetype(invalid_enchantment),
		"invalid_enchantment:",
		"invalid enchantment fails validation"
	)

func test_over_slot_save_error_preserves_previous_document() -> void:
	var path: String = "user://ghost_snapshot_save_validation.json"
	var valid: Dictionary = {
		"id": "ghost_validation_saved",
		"name": "Validation Save Seed",
		"day": 2,
		"level": 2,
		"slot_capacity": 3,
		"hero_id": "mak",
		"prestige": 20,
		"max_health": 120,
		"health": 120,
		"regeneration": 0.0,
		"skills": [{"id": "fiery", "tier": "bronze"}],
		"items": [
			{"item_id": "lighter", "tier": "bronze", "size": 1, "slot_index": 0, "enchantment": "", "cooldown": 4.0, "ammo": 0, "charges": 0},
			{"item_id": "cinders", "tier": "bronze", "size": 1, "slot_index": 1, "enchantment": "", "cooldown": 0.0, "ammo": 0, "charges": 0},
		],
	}
	var saved: Dictionary = PvpGhostServiceClass.save_curated_archetype(path, valid)
	_assert_true(bool(saved.get("success", false)), "baseline user snapshot document saves")
	if not bool(saved.get("success", false)):
		return

	var previous_contents: String = FileAccess.get_file_as_string(path)
	var invalid: Dictionary = valid.duplicate(true)
	invalid["items"] = [
		{"item_id": "lighter", "tier": "bronze", "size": 1, "slot_index": 0, "enchantment": "", "cooldown": 4.0, "ammo": 0, "charges": 0},
		{"item_id": "cinders", "tier": "bronze", "size": 1, "slot_index": 1, "enchantment": "", "cooldown": 0.0, "ammo": 0, "charges": 0},
		{"item_id": "myrrh", "tier": "bronze", "size": 2, "slot_index": 2, "enchantment": "", "cooldown": 6.0, "ammo": 0, "charges": 0},
	]
	var failed_save: Dictionary = PvpGhostServiceClass.save_curated_archetype(path, invalid)
	_assert_true(not bool(failed_save.get("success", false)), "over-slot ghost save fails")
	_assert_true(_errors_contain_prefix(failed_save.get("errors", []), "slot_capacity_exceeded"), "over-slot failure reports a capacity error")
	_assert_eq(FileAccess.get_file_as_string(path), previous_contents, "failed over-slot save preserves previous JSON document")
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func test_seed_pool_loads_days_1_to_10() -> void:
	var snapshots = PvpGhostServiceClass.load_seed_snapshots()
	_assert_eq(snapshots.size(), 10, "seed snapshot pool loads ten curated day entries")
	var days: Array[int] = []
	for snapshot in snapshots:
		days.append(int(snapshot.day))
		_assert_true(not str(snapshot.snapshot_id).is_empty(), "seed snapshot has an id for day %d" % int(snapshot.day))
	_assert_eq(days, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10], "seed pool covers day 1 through day 10 exactly once")

func test_power_score_is_roughly_monotonic_by_day() -> void:
	var snapshots = PvpGhostServiceClass.load_seed_snapshots()
	if snapshots.size() < 2:
		_assert_true(false, "seed snapshot pool is large enough for power-score checks")
		return
	var previous_score: int = int(snapshots[0].power_score)
	for index in range(1, snapshots.size()):
		var snapshot = snapshots[index]
		var current_score: int = int(snapshot.power_score)
		_assert_true(current_score >= previous_score, "power score does not go backwards at day %d" % int(snapshot.day))
		previous_score = current_score

func test_local_playtest_snapshot_files_validate_as_ghost_schema() -> void:
	var store_dir: String = "user://ghost_pool_test/schema"
	_remove_tree(store_dir)
	var snapshot = _make_local_snapshot("schema_seed", 4, 1180, "P50")
	var saved: Dictionary = PvpGhostServiceClass.save_local_snapshot(snapshot, store_dir)
	_assert_true(bool(saved.get("success", false)), "local playtest ghost snapshot saves")
	_assert_true(str(saved.get("path", "")).begins_with(store_dir), "local snapshot is stored under user playtest path")
	var loaded: Array[GhostSnapshotClass] = PvpGhostServiceClass.load_local_snapshots(store_dir)
	_assert_eq(loaded.size(), 1, "local playtest ghost snapshot reloads from disk")
	if not loaded.is_empty():
		var validation: Dictionary = PvpGhostServiceClass.validate_ghost_snapshot(loaded[0].to_dictionary())
		_assert_true(bool(validation.get("valid", false)), "local playtest snapshot validates with ghost schema")
		_assert_eq(loaded[0].source, PvpGhostServiceClass.LOCAL_SOURCE, "local snapshot source is marked local only")
	_remove_tree(store_dir)

func test_power_profile_and_index_include_match_dimensions() -> void:
	var store_dir: String = "user://ghost_pool_test/profile"
	_remove_tree(store_dir)
	var snapshot = _make_local_snapshot("profile_seed", 6, 0, "P50", "mak", 2, "fiery")
	var saved: Dictionary = PvpGhostServiceClass.save_local_snapshot(snapshot, store_dir)
	_assert_true(bool(saved.get("success", false)), "profile fixture saves")
	var loaded: Array[GhostSnapshotClass] = PvpGhostServiceClass.load_local_snapshots(store_dir)
	_assert_eq(loaded.size(), 1, "profile fixture reloads")
	if not loaded.is_empty():
		var profile: Dictionary = PvpGhostServiceClass.build_power_profile(loaded[0])
		_assert_eq(int(profile.get("day", 0)), 6, "power profile tracks day")
		_assert_eq(str(profile.get("hero_id", "")), "mak", "power profile tracks hero")
		_assert_eq(int(profile.get("skill_count", 0)), 2, "power profile tracks skill count")
		_assert_eq(int(profile.get("enchantment_count", 0)), 1, "power profile tracks enchantment count")
		_assert_true(str(profile.get("match_bucket", "")).contains("D06-L06-mak"), "match bucket includes day level and hero")
	var index_text: String = FileAccess.get_file_as_string("%s/index.json" % store_dir)
	_assert_true(index_text.contains("match_profile"), "local index exposes match profile for debug/report output")
	_assert_true(index_text.contains("match_bucket"), "local index exposes match bucket for debug/report output")
	_remove_tree(store_dir)

func test_local_match_report_scores_and_rotates_same_band_candidates() -> void:
	var store_dir: String = "user://ghost_pool_test/rotation"
	_remove_tree(store_dir)
	var player = _make_local_snapshot("current_player", 5, 0, "P50", "mak", 1, "")
	player.power_score = PvpGhostServiceClass.calculate_power_score(player)
	player.power_bucket = PvpGhostServiceClass.calculate_power_bucket(player.power_score)
	var saved_a: Dictionary = PvpGhostServiceClass.save_local_snapshot(_make_local_snapshot("local_a", 5, 0, "P50", "mak", 1, ""), store_dir)
	var saved_b: Dictionary = PvpGhostServiceClass.save_local_snapshot(_make_local_snapshot("local_b", 5, 0, "P50", "mak", 1, ""), store_dir)
	_assert_true(bool(saved_a.get("success", false)) and bool(saved_b.get("success", false)), "rotation fixtures save")
	var report_a: Dictionary = PvpGhostServiceClass.pick_snapshot_for_opponent(player, PvpGhostServiceClass.DEFAULT_CURATED_PATH, store_dir, "current_player", 0)
	var report_b: Dictionary = PvpGhostServiceClass.pick_snapshot_for_opponent(player, PvpGhostServiceClass.DEFAULT_CURATED_PATH, store_dir, "current_player", 1)
	var picked_a = report_a.get("snapshot", null)
	var picked_b = report_b.get("snapshot", null)
	_assert_eq(str(report_a.get("source", "")), PvpGhostServiceClass.LOCAL_SOURCE, "match report selects local source")
	_assert_true(bool(report_a.get("power_band_match", false)), "match report marks same power band")
	_assert_eq(int(report_a.get("rotation_band_count", 0)), 2, "nearby same-band candidates are eligible for rotation")
	_assert_true(picked_a != null and picked_b != null and str(picked_a.snapshot_id) != str(picked_b.snapshot_id), "selection seed varies opponents inside the matching band")
	_remove_tree(store_dir)

func test_local_power_bucket_match_precedes_curated_fallback() -> void:
	var store_dir: String = "user://ghost_pool_test/match"
	_remove_tree(store_dir)
	var local_snapshot = _make_local_snapshot("local_match", 5, 1180, "P50")
	var saved: Dictionary = PvpGhostServiceClass.save_local_snapshot(local_snapshot, store_dir)
	_assert_true(bool(saved.get("success", false)), "local match fixture saves")
	var picked = PvpGhostServiceClass.pick_snapshot_for_day(
		5,
		PvpGhostServiceClass.DEFAULT_CURATED_PATH,
		1190,
		store_dir,
		"current_player"
	)
	_assert_eq(picked.snapshot_id, "local_match", "PvP matching prefers same-day local power-band ghost")
	_assert_eq(picked.source, PvpGhostServiceClass.LOCAL_SOURCE, "picked local ghost keeps local source")
	_remove_tree(store_dir)

func test_curated_fallback_when_no_local_power_band_match() -> void:
	var store_dir: String = "user://ghost_pool_test/fallback"
	_remove_tree(store_dir)
	var only_current = _make_local_snapshot("current_player", 5, 1180, "P50")
	var saved: Dictionary = PvpGhostServiceClass.save_local_snapshot(only_current, store_dir)
	_assert_true(bool(saved.get("success", false)), "current-player local snapshot fixture saves")
	var report: Dictionary = PvpGhostServiceClass.pick_snapshot_for_day_report(
		5,
		PvpGhostServiceClass.DEFAULT_CURATED_PATH,
		1190,
		store_dir,
		"current_player"
	)
	var picked = report.get("snapshot", null)
	_assert_true(picked != null and picked.snapshot_id != "current_player", "current player snapshot is excluded from opponent selection")
	_assert_eq(picked.source, GhostSnapshotClass.DEFAULT_SOURCE, "curated fallback is used when local match only contains current player")
	_assert_true(str(report.get("local_fallback_reason", "")).begins_with("no_local_candidates"), "curated fallback report includes local mismatch reason")
	_remove_tree(store_dir)

func test_battle_replay_summary_extracts_major_drivers() -> void:
	var snapshot = _make_local_snapshot("replay_seed", 5, 1180, "P50")
	var monster = PvpGhostServiceClass.ghost_snapshot_to_monster(snapshot)
	monster.current_hp = 0
	monster.current_shield = 8.0
	var logs: Array[String] = [
		"⚔️ 战斗开始! Mak 出现!",
		"🗡️ [Lighter] 触发！造成 12 伤害",
		"👹 [Mak] 的 [Cinders] 触发！造成 5 伤害",
		"🛡️ [Shield] 触发！获得 10 护盾",
		"🎉 战斗胜利!",
	]
	var trace: Array = [{"effect_type": "damage", "amount": 12.0, "target_count": 1}]
	var summary: Dictionary = PvpGhostServiceClass.build_battle_replay_summary(snapshot, monster, trace, logs, true, "opponent_defeated", 44, 3.0)
	_assert_eq(str(summary.get("snapshot_id", "")), "replay_seed", "replay summary keeps snapshot id")
	_assert_eq(str(summary.get("result_reason", "")), "opponent_defeated", "replay summary records result reason")
	_assert_true((summary.get("key_triggers", []) as Array).size() >= 3, "replay summary records key triggers")
	_assert_true((summary.get("major_drivers", []) as Array).size() >= 2, "replay summary explains major outcome drivers")
	var replay_dir: String = "user://ghost_pool_test/replays"
	_remove_tree(replay_dir)
	var saved: Dictionary = PvpGhostServiceClass.save_battle_replay_summary(summary, replay_dir)
	_assert_true(bool(saved.get("success", false)), "replay summary persists locally")
	_assert_true(str(saved.get("path", "")).begins_with("%s/day05" % replay_dir), "replay summary path is grouped by day")
	_remove_tree(replay_dir)

func test_curated_editor_entry_opens_from_bazaar_shell() -> void:
	var main: Control = await _instantiate_main_scene()
	main.call("_on_warrior_selected")
	await _drain_frames(2)
	main.call("_show_event_panel")
	await _drain_frames(2)

	var shell: Control = main.get_node("BazaarShell") as Control
	var right_actions: Control = shell.get_node("RightActionArea") as Control
	var action_button: Button = _find_node(right_actions, "Action_ghost_editor") as Button
	_assert_true(action_button != null, "BazaarShell exposes a Ghost Editor quick entry")
	if action_button != null:
		action_button.pressed.emit()
		await _drain_frames(2)

	var overlay: Control = shell.get_node("OverlayLayer") as Control
	var editor: Control = _find_node(overlay, "GhostSnapshotEditor") as Control
	_assert_true(editor != null, "Ghost Editor opens inside BazaarShell overlay layer")
	if editor != null:
		editor.call("_close_editor")
		await _drain_frames(2)
	_assert_true(_find_node(overlay, "GhostSnapshotEditor") == null, "Ghost Editor can be closed cleanly")
	main.queue_free()
	await _drain_frames(2)

func test_runic_daggers_item_art_loads_without_raw_resource_fallback() -> void:
	var texture_path: String = ItemArtCatalogClass.get_item_texture_path_by_source_id("runic_daggers")
	_assert_true(texture_path.ends_with("runic_daggers.jpeg"), "runic daggers art path resolves to local wiki asset")
	var texture: Texture2D = ItemArtCatalogClass.load_texture(texture_path)
	_assert_true(texture != null, "runic daggers art loader returns an export-safe texture or fallback")

func test_pvp_battle_uses_ghost_snapshot_path() -> void:
	var main: Control = await _instantiate_main_scene()
	main.call("_on_warrior_selected")
	await _drain_frames(2)
	GameManager.current_day = 5
	GameManager.current_hour = 5
	main.call("_start_pvp_battle")
	await _drain_frames(2)

	var battle_ui: Control = main.get_node("BattleUI") as Control
	var current_monster = battle_ui.get("current_monster")
	var current_snapshot = battle_ui.get("current_ghost_snapshot")
	_assert_true(current_monster != null and bool(current_monster.get("is_ghost_snapshot")), "PvP battle enemy is instantiated from a ghost snapshot")
	_assert_true(str(current_monster.get("source_snapshot_id")) != "", "snapshot-backed PvP enemy keeps snapshot metadata")
	_assert_true(not str(current_monster.get("monster_name")).begins_with("PvP "), "snapshot-backed PvP enemy does not use placeholder naming")
	_assert_true(current_snapshot != null and int(current_snapshot.get("day")) == 5, "PvP battle loads the day-matched ghost snapshot")
	if battle_ui.has_method("_hide_battle_panel"):
		battle_ui.call("_hide_battle_panel")
	main.queue_free()
	await _drain_frames(2)

func _make_local_snapshot(
	snapshot_id: String,
	day: int,
	power_score: int,
	power_bucket: String,
	hero_id: String = "mak",
	skill_count: int = 1,
	enchantment: String = ""
):
	var snapshot = GhostSnapshotClass.new()
	snapshot.snapshot_id = snapshot_id
	snapshot.day = day
	snapshot.hour = 5
	snapshot.hero_id = hero_id
	snapshot.hero_name = PvpGhostServiceClass.get_hero_display_name(hero_id)
	snapshot.level = day
	snapshot.slot_capacity = 6
	snapshot.prestige = 20
	snapshot.max_health = 120 + day * 10
	snapshot.health = snapshot.max_health
	snapshot.regeneration = 0.0
	var skills: Array[Dictionary] = []
	for index in range(maxi(skill_count, 0)):
		skills.append({"id": "fiery" if index == 0 else "rush", "tier": "bronze"})
	var items: Array[Dictionary] = [
		{"item_id": "lighter", "tier": "bronze", "size": 1, "slot_index": 0, "enchantment": enchantment, "cooldown": 4.0, "ammo": 0, "charges": 0},
		{"item_id": "cinders", "tier": "bronze", "size": 1, "slot_index": 1, "enchantment": "", "cooldown": 0.0, "ammo": 0, "charges": 0},
	]
	snapshot.skills = skills
	snapshot.items = items
	snapshot.source = PvpGhostServiceClass.LOCAL_SOURCE
	snapshot.power_score = power_score
	snapshot.power_bucket = power_bucket
	snapshot.created_at = "2026-05-04T02:30:00"
	snapshot.generator_version = PvpGhostServiceClass.DEFAULT_LOCAL_GENERATOR_VERSION
	return snapshot

func _remove_tree(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry_name: String = dir.get_next()
	while not entry_name.is_empty():
		var child_path: String = "%s/%s" % [path, entry_name]
		if dir.current_is_dir():
			_remove_tree(child_path)
		else:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(child_path))
		entry_name = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _instantiate_main_scene() -> Control:
	GameManager.reset_stats()
	var scene: PackedScene = load("res://scenes/main.tscn")
	var main: Control = scene.instantiate() as Control
	add_child(main)
	await _drain_frames(2)
	return main

func _drain_frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame

func _assert_has_error(validation_result: Dictionary, prefix: String, label: String) -> void:
	_assert_true(_errors_contain_prefix(validation_result.get("errors", []), prefix), label)

func _errors_contain_prefix(errors: Variant, prefix: String) -> bool:
	if not errors is Array:
		return false
	for error_entry in errors:
		if str(error_entry).begins_with(prefix):
			return true
	return false

func _find_node(root: Node, node_name: String) -> Node:
	if root == null:
		return null
	if root.name == node_name:
		return root
	for child in root.get_children():
		var found: Node = _find_node(child, node_name)
		if found != null:
			return found
	return null

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
