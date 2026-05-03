extends Node

var _total: int = 0
var _passed: int = 0

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	print("== tests/test_special_choice_time_select.gd ==")
	call_deferred("_run_tests_async")

func _run_tests_async() -> void:
	await test_last_chance_uses_shell_time_select_and_hides_event_panel()
	await test_futura_choice_selection_uses_shell_hit_area()
	await test_normal_event_selection_still_opens_merchant_view()
	_print_summary()

func test_last_chance_uses_shell_time_select_and_hides_event_panel() -> void:
	_reset_services()
	var main: Control = await _create_started_main()
	RunStateService.prestige = 1
	RunStateService.remove_prestige(1)
	await get_tree().process_frame

	var shell: Control = main.get_node("BazaarShell")
	var event_panel: Control = main.get_node("EventPanel")
	var upper_board: Control = shell.get_node("UpperBoardPanel")
	var view: Node = _find_node(upper_board, "TimeSelectView")
	_assert_true(not event_panel.visible, "Last Chance keeps old EventPanel hidden")
	_assert_not_null(view, "Last Chance renders TimeSelectView in BazaarShell")
	if view == null:
		main.queue_free()
		await get_tree().process_frame
		return
	_assert_equal(int(view.call("get_option_count")), 3, "Last Chance renders three special options")
	_assert_equal(_option_title(view, 0), "Fate's Bounty", "Last Chance shows Futura bounty option in shell")
	_assert_true(shell.get_node("LeftClockPanel").is_visible_in_tree(), "Last Chance keeps LeftClockPanel visible")
	_assert_true(shell.get_node("PlayerBoardPanel").is_visible_in_tree(), "Last Chance keeps PlayerBoardPanel visible")
	_assert_true(shell.get_node("BottomHudPanel").is_visible_in_tree(), "Last Chance keeps BottomHudPanel visible")

	main.queue_free()
	await get_tree().process_frame

func test_futura_choice_selection_uses_shell_hit_area() -> void:
	_reset_services()
	var main: Control = await _create_started_main()
	var shell: Control = main.get_node("BazaarShell")
	var event_panel: Control = main.get_node("EventPanel")
	var before_gold: int = int(GameManager.gold)

	GameManager.futura_triggered.emit()
	await get_tree().process_frame

	var view: Node = _find_node(shell.get_node("UpperBoardPanel"), "TimeSelectView")
	var button: Button = _find_node(view, "OptionHitButton0") as Button
	_assert_not_null(button, "Futura special choice exposes shell hit button")
	if button == null:
		main.queue_free()
		await get_tree().process_frame
		return
	button.emit_signal("pressed")
	await get_tree().process_frame

	_assert_equal(int(GameManager.gold), before_gold + 20, "Futura bounty still grants gold")
	_assert_true(not event_panel.visible, "Futura selection does not reveal EventPanel")
	_assert_true(_find_node(shell.get_node("UpperBoardPanel"), "TimeSelectView") == null, "Futura shell choice clears TimeSelectView after selection")

	main.queue_free()
	await get_tree().process_frame

func test_normal_event_selection_still_opens_merchant_view() -> void:
	_reset_services()
	var main: Control = await _create_started_main()
	var shell: Control = main.get_node("BazaarShell")
	var options: Array[Dictionary] = [
		{"text": "Test Merchant", "type": "shop", "summary": "Regression shop option"},
		{"text": "Borrow", "type": "random_event", "event_id": "borrow"},
		{"text": "Armory", "type": "random_event", "event_id": "armory"},
	]

	GameFlowService.set("_current_event_options", options.duplicate(true))
	main.call("_on_game_flow_options_generated", options)
	await get_tree().process_frame

	var view: Node = _find_node(shell.get_node("UpperBoardPanel"), "TimeSelectView")
	var button: Button = _find_node(view, "OptionHitButton0") as Button
	_assert_not_null(button, "Normal event regression keeps time select button")
	if button == null:
		main.queue_free()
		await get_tree().process_frame
		return
	button.emit_signal("pressed")
	await get_tree().process_frame

	_assert_not_null(_find_node(shell.get_node("UpperBoardPanel"), "MerchantStateView"), "Normal shop selection still opens merchant view")
	_assert_true(not main.get_node("EventPanel").visible, "Normal shop selection still leaves EventPanel hidden")

	main.queue_free()
	await get_tree().process_frame

func _create_started_main() -> Control:
	var scene: PackedScene = load("res://scenes/main.tscn")
	var main: Control = scene.instantiate() as Control
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	main.call("_on_mak_selected")
	await get_tree().process_frame
	return main

func _reset_services() -> void:
	EconomyService.reset()
	RunStateService.reset(true)
	HeroStateService.reset()
	GameFlowService.set("_current_event_options", [])
	GameFlowService.set("_current_random_event_id", "")
	GameFlowService.set("_current_selected_option", {})
	GameManager.stats_total_battles = 0
	GameManager.stats_total_wins = 0
	GameManager.stats_total_losses = 0
	GameManager.stats_total_gold_earned = 0

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

func _option_title(view: Node, index: int) -> String:
	var title: Label = _find_node(view, "TitleLabel") as Label
	if title != null:
		return title.text
	var card: Node = _find_node(view, "OptionCard%d" % index)
	if card == null:
		return ""
	var label: Label = _find_node(card, "TitleLabel") as Label
	return "" if label == null else label.text

func _assert_true(condition: bool, label: String) -> void:
	_total += 1
	if condition:
		_passed += 1
		print("PASS: %s" % label)
	else:
		push_error("FAIL: %s" % label)

func _assert_equal(actual, expected, label: String) -> void:
	_assert_true(actual == expected, "%s | expected=%s actual=%s" % [label, str(expected), str(actual)])

func _assert_not_null(value, label: String) -> void:
	_assert_true(value != null, label)

func _print_summary() -> void:
	print("SUMMARY: %d/%d passed" % [_passed, _total])
	get_tree().quit(1 if _passed < _total else 0)
