extends SceneTree

const MANIFEST_PATH := "res://scripts/data/content_image_manifest.json"
const STATUS_VALUES := {
	"confirmed_local": true,
	"confirmed_remote_only": true,
	"unavailable_after_research": true,
	"not_applicable": true,
}

var _total: int = 0
var _passed: int = 0


func _init() -> void:
	print("== tests/test_content_image_manifest.gd ==")
	var manifest := _load_json(MANIFEST_PATH)
	_assert_true(not manifest.is_empty(), "manifest JSON loads")
	_assert_eq(str(manifest.get("task_id", "")), "T-FCG-COMPLETE-CONTENT-001", "manifest task id")
	_assert_eq(str(manifest.get("phase", "")), "phase4", "manifest phase")
	var entries: Array = manifest.get("entries", [])
	_assert_true(entries.size() >= 700, "manifest covers implemented content")
	_validate_entries(entries)
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


func _validate_entries(entries: Array) -> void:
	var local_count := 0
	var missing_source := 0
	var bad_status := 0
	var bad_local_paths: Array[String] = []
	for raw_entry in entries:
		if not raw_entry is Dictionary:
			bad_status += 1
			continue
		var entry := raw_entry as Dictionary
		var status := str(entry.get("status", ""))
		if not STATUS_VALUES.has(status):
			bad_status += 1
		if str(entry.get("source_url", "")).is_empty() and str(entry.get("source_page", "")).is_empty():
			missing_source += 1
		if status == "confirmed_local":
			local_count += 1
			var local_path := str(entry.get("local_path", ""))
			if not _image_path_loads(local_path):
				bad_local_paths.append("%s:%s" % [str(entry.get("kind", "")), str(entry.get("id", ""))])
	_assert_eq(bad_status, 0, "all entries have explicit supported source status")
	_assert_eq(missing_source, 0, "all entries have source URL or source page")
	_assert_true(local_count >= 500, "manifest has substantial confirmed local art coverage")
	_assert_eq(bad_local_paths.size(), 0, "confirmed local image paths exist and load: %s" % ", ".join(bad_local_paths))


func _image_path_loads(local_path: String) -> bool:
	if local_path.is_empty():
		return false
	var res_path := "res://%s" % local_path
	if not FileAccess.file_exists(res_path):
		return false
	var bytes := FileAccess.get_file_as_bytes(res_path)
	if bytes.is_empty():
		return false
	var image := Image.new()
	var extension := local_path.get_extension().to_lower()
	if extension == "png":
		return image.load_png_from_buffer(bytes) == OK
	if extension in ["jpg", "jpeg"]:
		return image.load_jpg_from_buffer(bytes) == OK
	if extension == "webp":
		return image.load_webp_from_buffer(bytes) == OK
	return false


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
