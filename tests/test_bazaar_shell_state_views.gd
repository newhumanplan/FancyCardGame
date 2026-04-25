extends Node

const LinearInventoryClass = preload("res://scripts/data/linear_inventory.gd")

var _total: int = 0
var _passed: int = 0

func _ready() -> void:
	if not Engine.is_editor_hint():
		print("== tests/test_bazaar_shell_state_views.gd ==")
		_run_tests()
		_print_summary()

func _run_tests() -> void:
	test_time_select_view_in_shell_emits_selection()
	test_merchant_view_emits_purchase_without_spending()
	test_merchant_refresh_reports_free_then_paid_cost()
	test_shell_merchant_uses_upper_board_and_right_actions()

func test_time_select_view_in_shell_emits_selection() -> void:
	var shell: Control = _create_shell()
	var options: Array[Dictionary] = [
		{"text": "商人", "type": "shop"},
		{"text": "宝库", "type": "treasure"},
		{"text": "营地", "type": "camp"},
	]
	var selected: Dictionary = {"index": -1}
	shell.connect("option_selected", func(index: int) -> void:
		selected["index"] = index
	)

	shell.call("show_time_select", options)
	var view: Node = _find_node(shell, "TimeSelectView")
	_assert_not_null(view, "shell adds TimeSelectView")
	_assert_equal(int(view.call("get_option_count")), 3, "time select renders three option nodes")

	var button: Button = _find_node(view, "OptionHitButton1") as Button
	_assert_not_null(button, "time select option has a hit button")
	button.emit_signal("pressed")
	_assert_equal(int(selected["index"]), 1, "time select forwards selected index through shell")
	shell.queue_free()

func test_merchant_view_emits_purchase_without_spending() -> void:
	var game_manager: Node = _game_manager()
	game_manager.call("reset_stats")
	game_manager.set("gold", 500)
	var merchant: Control = _create_merchant_view()
	var inventory: LinearInventoryClass = LinearInventoryClass.new()
	var before_gold: int = int(game_manager.get("gold"))
	var purchase: Dictionary = {"called": false, "index": -1}

	merchant.connect("purchase_requested", func(item, index: int) -> void:
		purchase["called"] = item != null
		purchase["index"] = index
	)
	merchant.call("show_merchant", inventory)

	var count: int = int(merchant.call("get_visible_item_count"))
	_assert_true(count >= 3 and count <= 5, "merchant shelf renders three to five items")
	var buy_button: Button = _find_node(merchant, "BuyButton0") as Button
	_assert_not_null(buy_button, "merchant item has buy intent button")
	buy_button.emit_signal("pressed")

	_assert_true(bool(purchase["called"]), "merchant emits purchase intent")
	_assert_equal(int(purchase["index"]), 0, "merchant purchase intent includes shelf index")
	_assert_equal(int(game_manager.get("gold")), before_gold, "merchant view does not spend gold")
	merchant.queue_free()

func test_merchant_refresh_reports_free_then_paid_cost() -> void:
	var game_manager: Node = _game_manager()
	game_manager.call("reset_stats")
	game_manager.set("gold", 500)
	var merchant: Control = _create_merchant_view()
	var inventory: LinearInventoryClass = LinearInventoryClass.new()
	var costs: Array[int] = []
	merchant.connect("refresh_requested", func(cost: int) -> void:
		costs.append(cost)
	)
	merchant.call("show_merchant", inventory)

	merchant.call("request_refresh")
	_assert_equal(costs[0], 0, "first merchant refresh is free")
	merchant.call("apply_refresh")
	merchant.call("request_refresh")
	_assert_equal(costs[1], 2, "second merchant refresh reports paid cost")
	_assert_equal(int(game_manager.get("gold")), 500, "merchant refresh intent does not spend gold")
	merchant.queue_free()

func test_shell_merchant_uses_upper_board_and_right_actions() -> void:
	var shell: Control = _create_shell()
	var inventory_ui: Control = _create_inventory_ui()
	shell.call("setup", _game_manager(), inventory_ui)
	var inventory: Resource = shell.call("get_player_inventory")
	var merchant: Control = shell.call("show_merchant", inventory) as Control

	_assert_not_null(merchant, "shell returns MerchantStateView")
	_assert_not_null(_find_node(shell.get_node("UpperBoardPanel"), "MerchantStateView"), "merchant view is placed in UpperBoardPanel")
	_assert_not_null(_find_node(shell.get_node("TopContextPanel"), "MerchantPortrait"), "merchant portrait is placed in TopContextPanel")
	_assert_not_null(_find_node(shell.get_node("RightActionArea"), "Action_merchant_refresh"), "merchant refresh action is in RightActionArea")
	_assert_not_null(_find_node(shell.get_node("RightActionArea"), "Action_merchant_leave"), "merchant leave action is in RightActionArea")
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

func _create_merchant_view() -> Control:
	var scene: PackedScene = load("res://scenes/ui/merchant_state_view.tscn")
	var merchant: Control = scene.instantiate() as Control
	add_child(merchant)
	return merchant

func _game_manager() -> Node:
	return get_node("/root/GameManager")

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

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	_assert_true(actual == expected, "%s (expected=%s actual=%s)" % [label, str(expected), str(actual)])

func _assert_not_null(value: Variant, label: String) -> void:
	_assert_true(value != null, label)

func _print_summary() -> void:
	print("SUMMARY: %d/%d passed" % [_passed, _total])
	get_tree().quit(1 if _passed < _total else 0)
