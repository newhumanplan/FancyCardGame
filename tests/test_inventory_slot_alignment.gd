extends Node

const SIZE_EPSILON: float = 2.5
const RATIO_EPSILON: float = 0.04

var _total: int = 0
var _passed: int = 0

func _ready() -> void:
	if not Engine.is_editor_hint():
		print("== tests/test_inventory_slot_alignment.gd ==")
		await _run_tests()
		_print_summary()

func _run_tests() -> void:
	await test_player_stash_and_opponent_slots_align()

func test_player_stash_and_opponent_slots_align() -> void:
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
	var inventory_ui: Control = shell.call("get_player_inventory_ui") as Control
	var player_slots: HBoxContainer = _find_node(inventory_ui, "SlotContainer") as HBoxContainer
	_assert_not_null(player_slots, "player inventory slot container exists")
	var player_slot_size: Vector2 = _first_slot_size(player_slots)
	_assert_true(_uses_bazaar_slot_ratio(player_slot_size), "player slot keeps Bazaar 1:2 item ratio")
	_assert_true(_slot_row_is_centered(player_slots), "player slot row is centered instead of stretched")

	shell.call("toggle_stash")
	await get_tree().process_frame
	await get_tree().process_frame
	var stash_ui: Control = _find_node(shell, "StashInventoryUI") as Control
	var stash_slots: HBoxContainer = _find_node(stash_ui, "SlotContainer") as HBoxContainer
	_assert_not_null(stash_slots, "stash inventory slot container exists")
	_assert_vec2_close(_first_slot_size(stash_slots), player_slot_size, "stash slot size matches player slot size")
	_assert_true(_slot_row_is_centered(stash_slots), "stash slot row is centered instead of stretched")

	game_manager.set("current_hour", 2)
	main.call("_start_battle")
	await get_tree().process_frame
	await get_tree().process_frame

	var opponent_slots: HBoxContainer = _find_node(shell.get_node("UpperBoardPanel"), "OpponentSlotRow") as HBoxContainer
	var opponent_item_layer: Control = _find_node(shell.get_node("UpperBoardPanel"), "OpponentItemLayer") as Control
	var overlay_layer: Control = shell.get_node("OverlayLayer") as Control
	var stash_overlay: Control = _find_node(shell, "StashOverlay") as Control
	_assert_not_null(opponent_slots, "opponent slot row exists")
	_assert_vec2_close(_first_slot_size(opponent_slots), player_slot_size, "opponent slot size matches player slot size")
	_assert_true(_slot_row_is_centered(opponent_slots), "opponent slot row is centered instead of stretched")
	_assert_true(overlay_layer != null and opponent_item_layer != null and overlay_layer.z_index > opponent_item_layer.z_index, "stash overlay layer is above opponent item layer")
	_assert_true(stash_overlay != null and opponent_item_layer != null and stash_overlay.z_index > opponent_item_layer.z_index, "stash overlay panel is above opponent item panel")

	main.queue_free()

func _uses_bazaar_slot_ratio(size: Vector2) -> bool:
	if size.x <= 0.0 or size.y <= 0.0:
		return false
	return absf((size.x / size.y) - 0.5) <= RATIO_EPSILON

func _slot_row_is_centered(row: HBoxContainer) -> bool:
	if row == null or row.get_child_count() <= 0:
		return false
	var first: Control = row.get_child(0) as Control
	var last: Control = row.get_child(row.get_child_count() - 1) as Control
	if first == null or last == null:
		return false
	var row_rect: Rect2 = row.get_global_rect()
	var filled_left: float = first.global_position.x
	var filled_right: float = last.global_position.x + last.size.x
	return filled_left > row_rect.position.x + SIZE_EPSILON and filled_right < row_rect.end.x - SIZE_EPSILON

func _first_slot_size(row: HBoxContainer) -> Vector2:
	if row == null or row.get_child_count() == 0:
		return Vector2.ZERO
	var slot: Control = row.get_child(0) as Control
	return Vector2.ZERO if slot == null else slot.size

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

func _assert_vec2_close(actual: Vector2, expected: Vector2, label: String) -> void:
	var close_enough: bool = actual.distance_to(expected) <= SIZE_EPSILON
	_assert_true(close_enough, "%s | expected=%s actual=%s" % [label, str(expected), str(actual)])

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
