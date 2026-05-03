extends SceneTree

const MANIFEST_PATH := "res://scripts/data/content_image_manifest.json"

const BazaarContentClass = preload("res://scripts/data/bazaar_content.gd")
const ItemArtCatalogClass = preload("res://scripts/data/item_art_catalog.gd")
const SkillArtCatalogClass = preload("res://scripts/data/skill_art_catalog.gd")

var _total: int = 0
var _passed: int = 0


func _init() -> void:
	print("== tests/test_remote_asset_localization.gd ==")
	var manifest := _load_json(MANIFEST_PATH)
	_assert_true(not manifest.is_empty(), "manifest JSON loads")
	var entries: Array = manifest.get("entries", [])
	_assert_true(not entries.is_empty(), "manifest has entries")
	_validate_remote_status(entries)
	_validate_confirmed_local_paths(entries)
	_validate_alias_lookup_paths()
	_print_summary()


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	return {}


func _validate_remote_status(entries: Array) -> void:
	var remote_counts := {
		"item_icon": 0,
		"skill_icon": 0,
		"event_art": 0,
	}
	var unavailable_event_ids: Array[String] = []
	for raw_entry in entries:
		if not raw_entry is Dictionary:
			continue
		var entry := raw_entry as Dictionary
		var kind := str(entry.get("kind", ""))
		if not remote_counts.has(kind):
			continue
		var status := str(entry.get("status", ""))
		if status == "confirmed_remote_only":
			remote_counts[kind] += 1
		elif kind == "event_art" and status == "unavailable_after_research":
			unavailable_event_ids.append(str(entry.get("id", "")))

	unavailable_event_ids.sort()
	_assert_eq(remote_counts["item_icon"], 0, "all item icons are localized or explicitly retired")
	_assert_eq(remote_counts["skill_icon"], 0, "all skill icons are localized or explicitly retired")
	_assert_eq(remote_counts["event_art"], 0, "event art no longer uses confirmed_remote_only markers")
	_assert_eq(
		",".join(unavailable_event_ids),
		"dooleys_workshop,jules_cafe,start_of_run",
		"only the explicitly researched event-art blockers remain unavailable"
	)


func _validate_confirmed_local_paths(entries: Array) -> void:
	var broken_entries: Array[String] = []
	for raw_entry in entries:
		if not raw_entry is Dictionary:
			continue
		var entry := raw_entry as Dictionary
		var kind := str(entry.get("kind", ""))
		if kind not in ["item_icon", "skill_icon", "event_art"]:
			continue
		if str(entry.get("status", "")) != "confirmed_local":
			continue
		var local_path := str(entry.get("local_path", ""))
		if local_path.is_empty():
			broken_entries.append("%s:%s:missing_local_path" % [kind, str(entry.get("id", ""))])
			continue
		var res_path := "res://%s" % local_path
		if not FileAccess.file_exists(res_path):
			broken_entries.append("%s:%s:missing_file" % [kind, str(entry.get("id", ""))])
			continue
		var image := Image.new()
		if image.load(res_path) != OK:
			broken_entries.append("%s:%s:unloadable" % [kind, str(entry.get("id", ""))])
			continue
		if str(entry.get("source_url", "")).is_empty() or str(entry.get("source_page", "")).is_empty():
			broken_entries.append("%s:%s:missing_provenance" % [kind, str(entry.get("id", ""))])
	_assert_eq(broken_entries.size(), 0, "confirmed local icon/event art files exist, load, and retain provenance: %s" % ", ".join(broken_entries))


func _validate_alias_lookup_paths() -> void:
	var item_ids := [
		"nargile",
		"powder_flask",
		"precision_callipers",
		"red_piggles_x",
		"silencer",
		"uzi",
		"captain",
		"clockwork_blade",
		"crow",
		"cryomastery",
		"fossilized_femur",
		"hakurvian_launcher",
		"ouroborus_statue",
		"s_nest",
		"s_ring",
	]
	for item_id in item_ids:
		_assert_true(
			not ItemArtCatalogClass.get_item_texture_path_by_source_id(item_id).is_empty(),
			"localized alias item icon resolves locally: %s" % item_id
		)

	_assert_true(not SkillArtCatalogClass.get_skill_texture_path_by_source_id("heavy_weaponry").is_empty(), "legacy heavy_weaponry skill icon resolves locally")
	_assert_true(not BazaarContentClass.get_event_art_path("haddy").is_empty(), "Haddy event art resolves locally")
	_assert_true(not BazaarContentClass.get_event_art_path("flambe").is_empty(), "Flambe event art resolves locally")
	_assert_true(BazaarContentClass.get_event_art_path("jules_cafe").is_empty(), "Jules' Cafe remains explicitly unresolved instead of using a bad placeholder")


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
	quit(1 if _passed < _total else 0)
