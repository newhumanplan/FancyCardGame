extends Node

const BATTLE_UI_PATH: String = "res://scripts/ui/battle_ui.gd"
const ITEM_DATA_PATH: String = "res://scripts/data/item_data.gd"

var _total: int = 0
var _passed: int = 0


func _ready() -> void:
	if not Engine.is_editor_hint():
		print("== tests/test_pvp_card_visual.gd ==")
		_run_tests()
		_print_summary()
		get_tree().quit(0)


func _run_tests() -> void:
	test_pvp_card_size_constant_is_80x110()
	test_create_price_badge_signature_and_return_type()
	test_illustration_color_mapping()
	test_create_illustration_block_uses_color_mapping()
	test_pvp_visual_helpers_are_only_used_in_pvp_paths()


func test_pvp_card_size_constant_is_80x110() -> void:
	_total += 1
	var battle_ui: Control = _new_battle_ui_instance()
	var actual_size: Vector2 = battle_ui.PVP_CARD_SIZE
	var passed: bool = actual_size == Vector2(80.0, 110.0)
	_assert("BattleUI.PVP_CARD_SIZE == Vector2(80.0, 110.0)", passed)
	battle_ui.free()


func test_create_price_badge_signature_and_return_type() -> void:
	_total += 1
	var source: String = _load_battle_ui_source()
	var signature_line: String = _extract_function_signature_line(source, "_create_price_badge")
	var signature_ok: bool = signature_line == "func _create_price_badge(price: int) -> Panel:"

	var battle_ui: Control = _new_battle_ui_instance()
	var badge: Panel = battle_ui.call("_create_price_badge", 7) as Panel
	var runtime_ok: bool = badge != null
	_assert("_create_price_badge(price: int) -> Panel exists and returns Panel", signature_ok and runtime_ok)
	if badge != null:
		badge.free()
	battle_ui.free()


func test_illustration_color_mapping() -> void:
	_total += 1
	var item_data_script: Script = load(ITEM_DATA_PATH) as Script
	var battle_ui: Control = _new_battle_ui_instance()

	var weapon_color: Color = battle_ui.call("_get_illustration_color", item_data_script.Type.WEAPON)
	var shield_color: Color = battle_ui.call("_get_illustration_color", item_data_script.Type.SHIELD)
	var heal_color: Color = battle_ui.call("_get_illustration_color", item_data_script.Type.HEAL)
	var utility_color: Color = battle_ui.call("_get_illustration_color", item_data_script.Type.UTILITY)

	var weapon_ok: bool = weapon_color.r > 0.5 and weapon_color.g < 0.3 and weapon_color.b < 0.3
	var shield_ok: bool = shield_color.r < 0.3 and shield_color.g > 0.3 and shield_color.b > 0.5
	var heal_ok: bool = heal_color.r < 0.3 and heal_color.g > 0.5 and heal_color.b < 0.4
	var utility_ok: bool = utility_color.r > 0.4 and utility_color.g < 0.3 and utility_color.b > 0.4

	_assert("Illustration colors map to weapon/shield/heal/utility palettes", weapon_ok and shield_ok and heal_ok and utility_ok)
	battle_ui.free()


func test_create_illustration_block_uses_color_mapping() -> void:
	_total += 1
	var item_data_script: Script = load(ITEM_DATA_PATH) as Script
	var battle_ui: Control = _new_battle_ui_instance()
	var expected_color: Color = battle_ui.call("_get_illustration_color", item_data_script.Type.SHIELD)
	var illustration: ColorRect = battle_ui.call("_create_illustration_block", item_data_script.Type.SHIELD) as ColorRect
	var passed: bool = illustration != null and illustration.color == expected_color
	_assert("_create_illustration_block returns ColorRect with mapped illustration color", passed)
	if illustration != null:
		illustration.free()
	battle_ui.free()


func test_pvp_visual_helpers_are_only_used_in_pvp_paths() -> void:
	_total += 1
	var source: String = _load_battle_ui_source()

	var show_panel_block: String = _extract_function_block(source, "_show_battle_panel")
	var player_hand_block: String = _extract_function_block(source, "_update_pvp_player_hand")
	var illustration_block: String = _extract_function_block(source, "_create_illustration_block")

	var show_panel_ok: bool = show_panel_block.find("if is_pvp:") >= 0 \
		and show_panel_block.find("_update_pvp_player_hand()") >= 0 \
		and show_panel_block.find("_update_pvp_opponent_hand()") >= 0
	var player_hand_ok: bool = player_hand_block.find("card_panel.custom_minimum_size = PVP_CARD_SIZE") >= 0 \
		and player_hand_block.find("_create_illustration_block(item_data.type)") >= 0 \
		and player_hand_block.find("_create_price_badge(item_data.buy_price)") >= 0
	var illustration_ok: bool = illustration_block.find("illustration.color = _get_illustration_color(item_type)") >= 0

	var card_size_funcs: Array[String] = _extract_usage_functions(source, "PVP_CARD_SIZE")
	var price_badge_funcs: Array[String] = _extract_usage_functions(source, "_create_price_badge")
	var illustration_color_funcs: Array[String] = _extract_usage_functions(source, "_get_illustration_color")
	var illustration_block_funcs: Array[String] = _extract_usage_functions(source, "_create_illustration_block")

	var card_size_ok: bool = _all_functions_allowed(
		card_size_funcs,
		["_update_pvp_player_hand", "_update_pvp_opponent_hand", "_add_empty_player_slots"]
	)
	var price_badge_ok: bool = _all_functions_allowed(price_badge_funcs, ["_update_pvp_player_hand"])
	var illustration_color_usage_ok: bool = _all_functions_allowed(illustration_color_funcs, ["_create_illustration_block"])
	var illustration_block_usage_ok: bool = _all_functions_allowed(illustration_block_funcs, ["_update_pvp_player_hand"])

	_assert(
		"PVP visual helpers stay inside is_pvp-only update paths",
		show_panel_ok and player_hand_ok and illustration_ok and card_size_ok and price_badge_ok and illustration_color_usage_ok and illustration_block_usage_ok
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


func _extract_function_signature_line(source: String, function_name: String) -> String:
	for line in source.split("\n"):
		var stripped_line: String = line.strip_edges()
		if stripped_line.begins_with("func %s(" % function_name):
			return stripped_line
	return ""


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


func _all_functions_allowed(functions: Array[String], allowed: Array[String]) -> bool:
	if functions.is_empty():
		return false

	for function_name in functions:
		if not allowed.has(function_name):
			return false

	return true


func _assert(description: String, passed: bool) -> void:
	if passed:
		_passed += 1
		print("  PASS: %s" % description)
	else:
		print("  FAIL: %s" % description)


func _print_summary() -> void:
	print("\nResults: %d/%d passed" % [_passed, _total])
