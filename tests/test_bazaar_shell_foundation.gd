extends Node

var _total: int = 0
var _passed: int = 0

func _ready() -> void:
	if not Engine.is_editor_hint():
		print("== tests/test_bazaar_shell_foundation.gd ==")
		_run_tests()
		_print_summary()

func _run_tests() -> void:
	test_shell_instantiates_required_regions()
	test_shell_reuses_external_inventory()
	test_shell_visibility_controls_inventory_source()

func test_shell_instantiates_required_regions() -> void:
	var shell: Control = _create_shell()
	_assert_not_null(shell.get_node_or_null("LeftClockPanel"), "shell has LeftClockPanel")
	_assert_not_null(shell.get_node_or_null("PlayerBoardPanel"), "shell has PlayerBoardPanel")
	_assert_not_null(shell.get_node_or_null("BottomHudPanel"), "shell has BottomHudPanel")
	_assert_not_null(shell.get_node_or_null("TopContextPanel"), "shell has TopContextPanel")
	_assert_not_null(shell.get_node_or_null("UpperBoardPanel"), "shell has UpperBoardPanel")
	_assert_not_null(shell.get_node_or_null("RightActionArea"), "shell has RightActionArea")
	shell.queue_free()

func test_shell_reuses_external_inventory() -> void:
	var shell: Control = _create_shell()
	var inventory_ui: Control = _create_inventory_ui()
	shell.setup(GameManager, inventory_ui)
	var shell_inventory: Resource = shell.get_player_inventory()
	var source_inventory: Resource = inventory_ui.get_inventory()
	_assert_true(shell_inventory == source_inventory, "shell returns the external InventoryUI inventory")
	shell.queue_free()
	inventory_ui.queue_free()

func test_shell_visibility_controls_inventory_source() -> void:
	var shell: Control = _create_shell()
	var inventory_ui: Control = _create_inventory_ui()
	shell.setup(GameManager, inventory_ui)
	shell.hide_run_shell()
	_assert_true(not shell.visible and not inventory_ui.visible, "hide_run_shell hides shell and inventory source")
	shell.show_run_shell()
	_assert_true(shell.visible and inventory_ui.visible, "show_run_shell shows shell and inventory source")
	shell.queue_free()
	inventory_ui.queue_free()

func _create_shell() -> Control:
	var scene: PackedScene = load("res://scenes/ui/bazaar_shell.tscn")
	var shell: Control = scene.instantiate() as Control
	add_child(shell)
	return shell

func _create_inventory_ui() -> Control:
	var scene: PackedScene = load("res://scenes/inventory_ui.tscn")
	var inventory_ui: Control = scene.instantiate() as Control
	add_child(inventory_ui)
	return inventory_ui

func _assert_true(condition: bool, label: String) -> void:
	_total += 1
	if condition:
		_passed += 1
		print("PASS: %s" % label)
	else:
		push_error("FAIL: %s" % label)

func _assert_not_null(value: Variant, label: String) -> void:
	_assert_true(value != null, label)

func _print_summary() -> void:
	print("SUMMARY: %d/%d passed" % [_passed, _total])
	get_tree().quit(1 if _passed < _total else 0)
