extends Node

var _total: int = 0
var _passed: int = 0

func _ready() -> void:
	if not Engine.is_editor_hint():
		print("== tests/test_unified_player_board_grid.gd ==")
		await _run_tests()
		_print_summary()

func _run_tests() -> void:
	await test_player_board_has_single_shell_owned_inventory_ui()

func test_player_board_has_single_shell_owned_inventory_ui() -> void:
	var game_manager: Node = get_node("/root/GameManager")
	game_manager.call("reset_stats")

	var scene: PackedScene = load("res://scenes/main.tscn")
	var main: Control = scene.instantiate() as Control
	add_child(main)
	await get_tree().process_frame

	main.call("_on_warrior_selected")
	await get_tree().process_frame
	await get_tree().process_frame

	var shell: Control = main.get_node("BazaarShell") as Control
	var player_board: Control = shell.get_node("PlayerBoardPanel") as Control
	var inventory_ui: Control = shell.call("get_player_inventory_ui") as Control

	_assert_true(main.get_node_or_null("InventoryUI") == null, "main scene has no root InventoryUI board overlay")
	_assert_not_null(inventory_ui, "shell exposes hosted player InventoryUI")
	_assert_true(player_board != null and player_board.is_ancestor_of(inventory_ui), "PlayerBoardPanel owns the visible player board renderer")
	_assert_equal(_count_visible_inventory_ui(main, player_board), 1, "exactly one visible player InventoryUI exists after run start")
	_assert_true(_anchors_close(player_board, 0.20, 0.53, 0.82, 0.76), "PlayerBoardPanel keeps the shared board anchors")

	main.queue_free()

func _count_visible_inventory_ui(root: Node, player_board: Control) -> int:
	var count: int = 0
	for node in _collect_inventory_ui_nodes(root):
		var control: Control = node as Control
		if control != null and control.is_visible_in_tree() and player_board.is_ancestor_of(control):
			count += 1
	return count

func _collect_inventory_ui_nodes(root: Node) -> Array[Node]:
	var result: Array[Node] = []
	if root == null:
		return result
	if root is InventoryUI:
		result.append(root)
	for child in root.get_children():
		result.append_array(_collect_inventory_ui_nodes(child))
	return result

func _anchors_close(control: Control, left: float, top: float, right: float, bottom: float) -> bool:
	if control == null:
		return false
	return absf(control.anchor_left - left) <= 0.001 \
		and absf(control.anchor_top - top) <= 0.001 \
		and absf(control.anchor_right - right) <= 0.001 \
		and absf(control.anchor_bottom - bottom) <= 0.001

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	_assert_true(actual == expected, "%s | expected=%s actual=%s" % [label, str(expected), str(actual)])

func _assert_not_null(value: Variant, label: String) -> void:
	_assert_true(value != null, label)

func _assert_true(condition: bool, label: String) -> void:
	_total += 1
	if condition:
		_passed += 1
		print("PASS: %s" % label)
	else:
		push_error("FAIL: %s" % label)

func _print_summary() -> void:
	print("SUMMARY: %d/%d passed" % [_passed, _total])
	get_tree().quit(1 if _passed < _total else 0)
