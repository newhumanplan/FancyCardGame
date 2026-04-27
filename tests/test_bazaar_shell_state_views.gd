extends Node

const LinearInventoryClass = preload("res://scripts/data/linear_inventory.gd")
const BazaarContentClass = preload("res://scripts/data/bazaar_content.gd")

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
	test_merchant_uses_slot_board_layout_and_wiki_art()
	test_curio_merchant_does_not_open_sold_out()
	test_merchant_refresh_reports_free_then_paid_cost()
	test_shell_merchant_uses_upper_board_and_right_actions()
	test_shell_stash_toggles_inventory_overlay()

func test_time_select_view_in_shell_emits_selection() -> void:
	var shell: Control = _create_shell()
	var options: Array[Dictionary] = [
		{"text": "商人", "type": "shop"},
		{"text": "Borrow", "type": "random_event", "event_id": "borrow"},
		{"text": "Armory", "type": "random_event", "event_id": "armory"},
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

	merchant.connect("purchase_requested", func(item, index: int, target_slot: int, target_inventory) -> void:
		purchase["called"] = item != null
		purchase["index"] = index
		purchase["target_slot"] = target_slot
		purchase["target_inventory"] = target_inventory
	)
	merchant.call("show_merchant", inventory)

	var count: int = int(merchant.call("get_visible_item_count"))
	_assert_true(count >= 3 and count <= 5, "merchant shelf renders three to five items")
	var item_card: Control = _find_node(merchant, "MerchantItemCard0") as Control
	_assert_not_null(item_card, "merchant item has a card hit area")
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.double_click = true
	item_card.emit_signal("gui_input", click)

	_assert_true(bool(purchase["called"]), "merchant emits purchase intent")
	_assert_equal(int(purchase["index"]), 0, "merchant purchase intent includes shelf index")
	_assert_equal(int(purchase["target_slot"]), -1, "merchant double-click purchase uses first available slot")
	_assert_true(purchase["target_inventory"] == null, "merchant double-click purchase does not force a target inventory")
	_assert_equal(int(game_manager.get("gold")), before_gold, "merchant view does not spend gold")
	merchant.queue_free()

func test_merchant_uses_slot_board_layout_and_wiki_art() -> void:
	var game_manager: Node = _game_manager()
	game_manager.call("reset_stats")
	game_manager.set("gold", 500)
	var merchant: Control = _create_merchant_view()
	var inventory: LinearInventoryClass = LinearInventoryClass.new()
	var stat_item = BazaarContentClass.create_item("aludel")

	merchant.call("show_merchant", inventory)
	merchant.set("shop_items", [stat_item])
	merchant.call("_refresh_shelf")

	var board: Control = _find_node(merchant, "MerchantShopBoard") as Control
	var slot_row: Control = _find_node(merchant, "MerchantShopSlotRow") as Control
	var item_card: Control = _find_node(merchant, "MerchantItemCard0") as Control
	var art: TextureRect = _find_node(item_card, "ItemArt") as TextureRect

	_assert_not_null(board, "merchant shelf uses a slot board container")
	_assert_not_null(slot_row, "merchant shelf has a shop slot row")
	_assert_equal(slot_row.get_child_count(), 10, "merchant shelf renders ten shop slots")
	_assert_not_null(item_card, "merchant slot board renders item card")
	_assert_not_null(art, "merchant item card uses source art")
	_assert_true(art.texture != null, "merchant source art texture is loaded")
	_assert_not_null(_find_node(item_card, "ItemStatBadgeGrid"), "merchant item card shows top effect badges")
	var price_badge: Control = _find_node(item_card, "PriceBadge0") as Control
	_assert_not_null(price_badge, "merchant item card shows a price badge")
	_assert_true(not (price_badge is Button), "merchant item value badge is not a purchase button")
	_assert_true(_find_node(item_card, "LockButton0") == null, "merchant item card does not show placeholder lock button")
	merchant.queue_free()

func test_curio_merchant_does_not_open_sold_out() -> void:
	var game_manager: Node = _game_manager()
	game_manager.call("reset_stats")
	game_manager.set("gold", 500)
	var merchant: Control = _create_merchant_view()
	var inventory: LinearInventoryClass = LinearInventoryClass.new()

	merchant.call("show_merchant", inventory, null, {
		"id": "curio",
		"name": "Curio",
		"type": "Bronze, Junk",
		"starting_tier": "Silver",
	})

	_assert_true(int(merchant.call("get_visible_item_count")) > 0, "Curio merchant opens with sellable items")
	_assert_true(_find_node(merchant, "EmptyShelfLabel") == null, "Curio merchant does not show sold out on open")
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

func test_shell_stash_toggles_inventory_overlay() -> void:
	var shell: Control = _create_shell()
	var inventory_ui: Control = _create_inventory_ui()
	shell.call("setup", _game_manager(), inventory_ui)

	shell.call("toggle_stash")
	var overlay: Control = _find_node(shell, "StashOverlay") as Control
	var stash_ui: Control = _find_node(shell, "StashInventoryUI") as Control
	var stash_inventory: Resource = shell.call("get_stash_inventory")

	_assert_not_null(overlay, "shell creates stash overlay")
	_assert_true(overlay.visible, "stash overlay is visible after toggle")
	_assert_not_null(stash_ui, "stash overlay contains InventoryUI")
	_assert_true(stash_inventory != null and int(stash_inventory.call("get_total_slots")) == 10, "stash defaults to ten slots")

	shell.call("toggle_stash")
	_assert_true(not overlay.visible, "second toggle hides stash overlay")
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
