extends Node

var _total: int = 0
var _passed: int = 0

func _ready() -> void:
	if not Engine.is_editor_hint():
		print("== tests/test_battle_shell_layout.gd ==")
		await _run_tests()
		_print_summary()

func _run_tests() -> void:
	await test_battle_uses_shell_regions_without_duplicate_hud()

func test_battle_uses_shell_regions_without_duplicate_hud() -> void:
	var game_manager: Node = get_node("/root/GameManager")
	game_manager.call("reset_stats")

	var scene: PackedScene = load("res://scenes/main.tscn")
	var main: Control = scene.instantiate() as Control
	add_child(main)
	await get_tree().process_frame

	main.call("_on_warrior_selected")
	await get_tree().process_frame
	game_manager.set("current_hour", 2)
	main.call("_start_battle")
	await get_tree().process_frame

	var shell: Control = main.get_node("BazaarShell") as Control
	var battle_ui: Control = main.get_node("BattleUI") as Control
	var opponent_board: Node = _find_node(shell.get_node("UpperBoardPanel"), "OpponentBoardContainer")
	_assert_not_null(opponent_board, "battle opponent board is in BazaarShell upper board")
	_assert_not_null(_find_node(shell.get_node("TopContextPanel"), "OpponentContext"), "battle opponent context is in BazaarShell top context")
	_assert_not_null(_find_node(shell.get_node("RightActionArea"), "BattleActionColumn"), "battle actions are in BazaarShell right action area")
	_assert_not_null(_find_node(opponent_board, "OpponentSlotRow"), "battle opponent board uses shell slot row")
	_assert_equal(_count_named_children(_find_node(opponent_board, "OpponentSlotRow"), "OpponentSlot"), 10, "battle opponent board renders ten slots")
	_assert_true(battle_ui.mouse_filter == Control.MOUSE_FILTER_IGNORE, "BattleUI does not block shell controls in shell layout")
	_assert_true(_find_node(battle_ui, "PlayerBar") == null, "legacy green player bar is not created in shell battle layout")
	_assert_true(_find_node(battle_ui, "ChestBox") == null, "legacy duplicate chest is not created in shell battle layout")
	_assert_true(_find_node(battle_ui, "PlayerHandContainer") == null, "legacy duplicate player hand is not created in shell battle layout")

	main.queue_free()

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

func _count_named_children(root: Node, name_prefix: String) -> int:
	if root == null:
		return 0
	var count: int = 0
	for child in root.get_children():
		if child.name.begins_with(name_prefix):
			count += 1
	return count

func _assert_true(condition: bool, label: String) -> void:
	_total += 1
	if condition:
		_passed += 1
		print("PASS: %s" % label)
	else:
		push_error("FAIL: %s" % label)

func _assert_not_null(value: Variant, label: String) -> void:
	_assert_true(value != null, label)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	_assert_true(actual == expected, "%s (expected=%s actual=%s)" % [label, str(expected), str(actual)])

func _print_summary() -> void:
	print("SUMMARY: %d/%d passed" % [_passed, _total])
	get_tree().quit(1 if _passed < _total else 0)
