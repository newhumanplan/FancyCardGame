extends Node

const BATTLE_UI_PATH: String = "res://scripts/ui/battle_ui.gd"
const CLOCK_ICON_PATH: String = "res://assets/art/ui/pvp/pvp_clock_icon.png"
const AVATAR_FRAME_PATH: String = "res://assets/art/ui/pvp/pvp_avatar_frame.png"
const HERO_AVATAR_PATH: String = "res://assets/art/ui/pvp/pvp_hero_avatar.png"

var _total: int = 0
var _passed: int = 0


func _ready() -> void:
	if not Engine.is_editor_hint():
		print("== tests/test_pvp_decorations.gd ==")
		_run_tests()
		_print_summary()
		get_tree().quit(0)


func _run_tests() -> void:
	test_pvp_resource_path_constants_exist()
	test_pvp_png_files_exist()
	test_pve_update_branch_has_zero_pvp_decoration_references()


func test_pvp_resource_path_constants_exist() -> void:
	_total += 1
	var battle_ui: Control = _new_battle_ui_instance()
	var passed: bool = battle_ui.PVP_CLOCK_ICON == CLOCK_ICON_PATH \
		and battle_ui.PVP_AVATAR_FRAME == AVATAR_FRAME_PATH \
		and battle_ui.PVP_HERO_AVATAR == HERO_AVATAR_PATH
	_assert(
		"BattleUI PvP decoration resource constants match expected PNG paths",
		passed
	)
	battle_ui.free()


func test_pvp_png_files_exist() -> void:
	_total += 1
	var clock_exists: bool = FileAccess.file_exists(CLOCK_ICON_PATH)
	var frame_exists: bool = FileAccess.file_exists(AVATAR_FRAME_PATH)
	var hero_exists: bool = FileAccess.file_exists(HERO_AVATAR_PATH)
	_assert(
		"PvP decoration PNG files exist on disk",
		clock_exists and frame_exists and hero_exists
	)


func test_pve_update_branch_has_zero_pvp_decoration_references() -> void:
	_total += 1
	var source: String = _load_battle_ui_source()
	var update_block: String = _extract_function_block(source, "_update_battle_ui")
	var pve_branch: String = _extract_pve_branch(update_block)

	var branch_found: bool = not pve_branch.is_empty()
	var direct_reference_free: bool = pve_branch.find("PVP_CLOCK_ICON") == -1 \
		and pve_branch.find("PVP_AVATAR_FRAME") == -1 \
		and pve_branch.find("PVP_HERO_AVATAR") == -1

	var direct_usage_functions: Array[String] = []
	direct_usage_functions.append_array(_extract_usage_functions(source, "PVP_CLOCK_ICON"))
	direct_usage_functions.append_array(_extract_usage_functions(source, "PVP_AVATAR_FRAME"))
	direct_usage_functions.append_array(_extract_usage_functions(source, "PVP_HERO_AVATAR"))
	var usage_ok: bool = not direct_usage_functions.has("_update_battle_ui")

	_assert(
		"_update_battle_ui PvE branch does not reference PvP decoration constants",
		branch_found and direct_reference_free and usage_ok
	)


func _new_battle_ui_instance() -> Control:
	var battle_ui_script: Script = load(BATTLE_UI_PATH) as Script
	return battle_ui_script.new() as Control


func _load_battle_ui_source() -> String:
	var file: FileAccess = FileAccess.open(BATTLE_UI_PATH, FileAccess.READ)
	if file == null:
		return ""
	var source: String = file.get_as_text()
	file.close()
	return source


func _extract_function_block(source: String, function_name: String) -> String:
	var lines: PackedStringArray = source.split("\n")
	var block_lines: Array[String] = []
	var capture: bool = false

	for line in lines:
		var stripped_line: String = line.strip_edges()
		if stripped_line.begins_with("func "):
			var found_name: String = stripped_line.split("(")[0].replace("func ", "")
			if capture and found_name != function_name:
				break
			if found_name == function_name:
				capture = true
		if capture:
			block_lines.append(line)

	return "\n".join(block_lines)


func _extract_pve_branch(update_block: String) -> String:
	if update_block.is_empty():
		return ""

	var lines: PackedStringArray = update_block.split("\n")
	var branch_lines: Array[String] = []
	var capture: bool = false

	for line in lines:
		var stripped_line: String = line.strip_edges()
		if stripped_line == "var max_hp: int = game_manager.get_max_health()":
			capture = true
		if capture:
			branch_lines.append(line)

	return "\n".join(branch_lines).strip_edges()


func _extract_usage_functions(source: String, identifier: String) -> Array[String]:
	var usage_functions: Array[String] = []
	var current_function: String = ""

	for line in source.split("\n"):
		var stripped_line: String = line.strip_edges()
		if stripped_line.begins_with("func "):
			current_function = stripped_line.split("(")[0].replace("func ", "")
		if stripped_line.find(identifier) == -1:
			continue
		if stripped_line.begins_with("const %s" % identifier):
			continue
		if stripped_line.begins_with("func ") and stripped_line.find(identifier + "(") >= 0:
			continue
		usage_functions.append(current_function)

	return usage_functions


func _assert(description: String, passed: bool) -> void:
	if passed:
		_passed += 1
		print("  PASS: %s" % description)
	else:
		print("  FAIL: %s" % description)


func _print_summary() -> void:
	print("\nResults: %d/%d passed" % [_passed, _total])
