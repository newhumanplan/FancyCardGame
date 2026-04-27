extends Node

const LinearInventoryClass = preload("res://scripts/data/linear_inventory.gd")
const ItemDataClass = preload("res://scripts/data/item_data.gd")

var _total: int = 0
var _passed: int = 0

func _ready() -> void:
	if not Engine.is_editor_hint():
		print("== tests/test_linear_inventory_drag.gd ==")
		_run_tests()
		_print_summary()

func _run_tests() -> void:
	test_same_inventory_inserts_and_shifts_right()
	test_large_drop_on_empty_slot_shifts_overlapped_items()
	test_full_inventory_swaps_drag_span_group()
	test_cross_inventory_inserts_and_shifts_target()
	test_cross_inventory_fails_when_group_cannot_fit_source()
	test_can_move_preview_does_not_mutate()

func _item(name: String, size: int = ItemDataClass.Size.SMALL) -> ItemDataClass:
	var item: ItemDataClass = ItemDataClass.new()
	item.item_name = name
	item.size = size
	return item

func test_same_inventory_inserts_and_shifts_right() -> void:
	var inventory: LinearInventoryClass = LinearInventoryClass.new()
	var a: ItemDataClass = _item("A")
	var b: ItemDataClass = _item("B")
	var c: ItemDataClass = _item("C")
	inventory.place_item(a, 0)
	inventory.place_item(b, 1)
	inventory.place_item(c, 2)

	_assert_true(inventory.move_item_to_slot(c, 1), "moving onto occupied slot inserts and shifts right")
	_assert_eq(a.slot_index, 0, "left item stays in place")
	_assert_eq(c.slot_index, 1, "dragged item lands at target")
	_assert_eq(b.slot_index, 2, "target item shifts right")

func test_large_drop_on_empty_slot_shifts_overlapped_items() -> void:
	var inventory: LinearInventoryClass = LinearInventoryClass.new()
	var overlapped: ItemDataClass = _item("Overlapped")
	var medium: ItemDataClass = _item("Medium", ItemDataClass.Size.MEDIUM)
	inventory.place_item(overlapped, 2)
	inventory.place_item(medium, 5)

	_assert_true(inventory.move_item_to_slot(medium, 1), "medium item can drop on empty slot and shift right overlap")
	_assert_eq(medium.slot_index, 1, "medium item starts at empty target")
	_assert_eq(overlapped.slot_index, 3, "overlapped item shifts after medium span")

func test_full_inventory_swaps_drag_span_group() -> void:
	var inventory: LinearInventoryClass = LinearInventoryClass.new()
	var large: ItemDataClass = _item("Large", ItemDataClass.Size.LARGE)
	inventory.place_item(large, 0)
	var smalls: Array[ItemDataClass] = []
	for slot in range(3, 10):
		var small: ItemDataClass = _item("S%d" % slot)
		smalls.append(small)
		inventory.place_item(small, slot)

	_assert_true(inventory.move_item_to_slot(large, 7), "full inventory swaps large item with target group")
	_assert_eq(large.slot_index, 7, "large item lands on the three-slot target span")
	_assert_eq(smalls[4].slot_index, 0, "first target small moves to source start")
	_assert_eq(smalls[5].slot_index, 1, "second target small moves to source middle")
	_assert_eq(smalls[6].slot_index, 2, "third target small moves to source end")

func test_cross_inventory_inserts_and_shifts_target() -> void:
	var board: LinearInventoryClass = LinearInventoryClass.new()
	var stash: LinearInventoryClass = LinearInventoryClass.new()
	var medium: ItemDataClass = _item("Board Medium", ItemDataClass.Size.MEDIUM)
	var a: ItemDataClass = _item("Stash A")
	var b: ItemDataClass = _item("Stash B")
	board.place_item(medium, 0)
	stash.place_item(a, 0)
	stash.place_item(b, 1)

	_assert_true(board.move_item_to_inventory(medium, stash, 0), "cross inventory move inserts into target and shifts")
	_assert_eq(board.get_item_count(), 0, "source inventory removes moved item")
	_assert_eq(medium.slot_index, 0, "moved item lands in target inventory")
	_assert_eq(a.slot_index, 2, "first target item shifts after moved item")
	_assert_eq(b.slot_index, 3, "second target item shifts after moved item")

func test_cross_inventory_fails_when_group_cannot_fit_source() -> void:
	var board: LinearInventoryClass = LinearInventoryClass.new()
	var stash: LinearInventoryClass = LinearInventoryClass.new()
	var dragged: ItemDataClass = _item("Small")
	var large: ItemDataClass = _item("Large", ItemDataClass.Size.LARGE)
	board.place_item(dragged, 0)
	stash.place_item(large, 0)
	for slot in range(3, 10):
		stash.place_item(_item("F%d" % slot), slot)

	_assert_true(not board.move_item_to_inventory(dragged, stash, 0), "cross inventory move fails when target group cannot fit source span")
	_assert_eq(dragged.slot_index, 0, "failed move keeps dragged item in source")
	_assert_eq(large.slot_index, 0, "failed move keeps target group unchanged")

func test_can_move_preview_does_not_mutate() -> void:
	var inventory: LinearInventoryClass = LinearInventoryClass.new()
	var a: ItemDataClass = _item("A")
	var b: ItemDataClass = _item("B")
	inventory.place_item(a, 0)
	inventory.place_item(b, 1)

	_assert_true(inventory.can_move_item_to_inventory(a, inventory, 1), "preview reports valid move")
	_assert_eq(a.slot_index, 0, "preview keeps dragged item slot")
	_assert_eq(b.slot_index, 1, "preview keeps target item slot")

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
