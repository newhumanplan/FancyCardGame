extends Node

const ItemDataClass = preload("res://scripts/data/item_data.gd")

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
	var inventory_ui: Control = main.get_node("InventoryUI") as Control
	var player_item: ItemDataClass = ItemDataClass.new()
	player_item.item_name = "法杖"
	player_item.type = ItemDataClass.Type.WEAPON
	player_item.damage = 5
	player_item.cooldown = 2.0
	inventory_ui.call("get_inventory").place_item(player_item, 0)
	await get_tree().process_frame
	var event_background_layer: Control = _find_node(inventory_ui, "BackgroundLayer") as Control
	var event_item_layer: Control = _find_node(inventory_ui, "ItemDisplayLayer") as Control
	var event_player_item_panel: Control = _find_node_by_prefix(inventory_ui, "Item_") as Control
	var event_player_item_center: Vector2 = Vector2.ZERO
	if event_player_item_panel != null:
		event_player_item_center = event_player_item_panel.get_global_rect().get_center()
	_assert_not_null(event_player_item_panel, "event selection player board renders item panel")
	_assert_true(event_background_layer != null and event_background_layer.mouse_filter == Control.MOUSE_FILTER_IGNORE, "event selection player board background does not block hover")
	_assert_true(event_item_layer != null and event_item_layer.size.x > 0.0 and event_item_layer.size.y > 0.0, "event selection player item layer has a real hit area")
	_assert_true(event_item_layer != null and event_item_layer.get_global_rect().has_point(event_player_item_center), "event selection player item layer covers rendered item")
	_assert_true(event_player_item_panel != null and event_player_item_panel.mouse_filter == Control.MOUSE_FILTER_STOP, "event selection player item accepts hover")
	var event_item_background: Control = null
	if event_player_item_panel != null:
		event_item_background = event_player_item_panel.get_node_or_null("ItemBackground") as Control
	_assert_true(event_item_background != null and event_item_background.mouse_filter == Control.MOUSE_FILTER_IGNORE, "event selection item background does not steal hover")
	_assert_not_null(_find_node(event_player_item_panel, "ItemStatBadgeGrid"), "event selection player item shows top effect badges")
	_assert_not_null(_find_node(event_player_item_panel, "ItemValueBadge"), "event selection player item shows bottom-left value badge")
	inventory_ui.call("_show_hover_tooltip", player_item)
	var event_hover_tooltip: Control = _find_node(inventory_ui, "HoverTooltip") as Control
	_assert_not_null(event_hover_tooltip, "event selection player item can show hover tooltip")
	_assert_true(event_hover_tooltip != null and event_hover_tooltip.size.x > 0.0 and event_hover_tooltip.size.y > 0.0, "event selection player hover tooltip has visible size")
	inventory_ui.call("_hide_hover_tooltip")
	game_manager.set("current_hour", 2)
	main.call("_start_battle")
	await get_tree().process_frame

	var shell: Control = main.get_node("BazaarShell") as Control
	var battle_ui: Control = main.get_node("BattleUI") as Control
	var opponent_board: Node = _find_node(shell.get_node("UpperBoardPanel"), "OpponentBoardContainer")
	var opponent_context: Node = _find_node(shell.get_node("TopContextPanel"), "OpponentContext")
	_assert_not_null(opponent_board, "battle opponent board is in BazaarShell upper board")
	_assert_not_null(opponent_context, "battle opponent context is in BazaarShell top context")
	_assert_not_null(_find_node(opponent_context, "OpponentPortraitArea"), "battle opponent context mirrors player portrait area")
	_assert_not_null(_find_node(opponent_context, "StatusLabel"), "battle opponent context has burn poison status label")
	_assert_not_null(_find_node(shell.get_node("BottomHudPanel"), "CombatStatusLabel"), "battle player bottom HUD has burn poison status label")
	_assert_not_null(_find_node(shell.get_node("RightActionArea"), "BattleActionColumn"), "battle actions are in BazaarShell right action area")
	var tooltip_panel: PanelContainer = _find_node(battle_ui, "PvPTooltip") as PanelContainer
	_assert_not_null(tooltip_panel, "battle shell creates item tooltip layer")
	_assert_not_null(_find_node(opponent_board, "OpponentSlotRow"), "battle opponent board uses shell slot row")
	_assert_equal(_sum_shell_slot_spans(_find_node(opponent_board, "OpponentSlotRow")), 10, "battle opponent board renders ten board slot units")
	var opponent_item_panel: Panel = _find_opponent_item_with_cooldown(opponent_board) as Panel
	if opponent_item_panel == null:
		opponent_item_panel = _find_node_by_prefix(opponent_board, "OpponentItem_") as Panel
	_assert_not_null(opponent_item_panel, "battle opponent board renders monster item cards")
	var opponent_cooldown_label: Label = null
	var opponent_cooldown_overlay: ColorRect = null
	if opponent_item_panel != null:
		opponent_cooldown_label = opponent_item_panel.get_node_or_null("OpponentItemText/CooldownLabel") as Label
		opponent_cooldown_overlay = opponent_item_panel.get_node_or_null("CooldownOverlay") as ColorRect
	_assert_not_null(opponent_cooldown_label, "battle opponent item has cooldown label")
	_assert_not_null(opponent_cooldown_overlay, "battle opponent item has cooldown overlay")
	_assert_true(opponent_item_panel != null and opponent_item_panel.get_node_or_null("TextBacking") == null, "battle opponent item has no bottom debug backing mask")
	_assert_not_null(_find_node(opponent_item_panel, "ItemStatBadgeGrid"), "battle opponent item shows top effect badges")
	_assert_true(_find_node(opponent_item_panel, "PriceBadge") == null, "battle opponent item does not show bottom-left value")
	_assert_true(opponent_item_panel != null and opponent_item_panel.mouse_filter == Control.MOUSE_FILTER_PASS, "battle opponent item accepts hover for tooltip")
	if tooltip_panel != null and opponent_item_panel != null:
		battle_ui.call("_show_monster_item_tooltip", opponent_item_panel)
		var tooltip_label: RichTextLabel = tooltip_panel.get_child(0) as RichTextLabel
		var tooltip_text: String = "" if tooltip_label == null else tooltip_label.text
		_assert_true(tooltip_panel.visible, "battle opponent tooltip becomes visible on hover")
		_assert_true(tooltip_text.find("冷却") >= 0, "battle opponent tooltip shows cooldown in Chinese")
		_assert_true(_has_any_effect_word(tooltip_text), "battle opponent tooltip shows real item effect")
		_assert_true(tooltip_text.find("ATK") < 0 and tooltip_text.find("Ready") < 0, "battle opponent tooltip hides debug wording")
		battle_ui.call("_hide_pvp_tooltip")
		_assert_true(not tooltip_panel.visible, "battle opponent tooltip hides after hover exit")
	var initial_cooldown_text: String = "" if opponent_cooldown_label == null else opponent_cooldown_label.text
	var initial_overlay_top: float = 0.0 if opponent_cooldown_overlay == null else opponent_cooldown_overlay.anchor_top
	var battle_system: Node = get_node("/root/BattleSystem")
	battle_system.call("reduce_cooldowns", 1.0)
	battle_ui.call("_update_pvp_cooldown_overlays")
	var updated_cooldown_text: String = "" if opponent_cooldown_label == null else opponent_cooldown_label.text
	var updated_overlay_top: float = 0.0 if opponent_cooldown_overlay == null else opponent_cooldown_overlay.anchor_top
	_assert_true(updated_cooldown_text != initial_cooldown_text, "battle opponent cooldown label updates from live cooldown")
	_assert_true(updated_overlay_top > initial_overlay_top, "battle opponent cooldown overlay shrinks from live cooldown")
	_assert_true(not _has_label_text_containing(opponent_item_panel, "ATK"), "battle opponent item card does not show ATK debug text")
	battle_system.call("reduce_cooldowns", 10.0)
	battle_ui.call("_update_pvp_cooldown_overlays")
	var ready_text: String = "" if opponent_cooldown_label == null else opponent_cooldown_label.text
	_assert_equal(ready_text, "", "battle opponent item card hides ready text when cooldown is zero")
	battle_system.call("execute_battle_tick", 0.5)
	var current_monster: Resource = battle_system.get("current_monster") as Resource
	var reset_cooldown: float = 0.0
	var passive_items_stayed_passive: bool = true
	var saw_passive_monster_item: bool = false
	if current_monster != null:
		var monster_items: Array = current_monster.get("monster_items")
		for monster_item in monster_items:
			if float(monster_item.get("cooldown", 0.0)) > 0.0:
				reset_cooldown = maxf(reset_cooldown, float(monster_item.get("current_cooldown", 0.0)))
			else:
				saw_passive_monster_item = true
				passive_items_stayed_passive = passive_items_stayed_passive and float(monster_item.get("current_cooldown", -1.0)) == 0.0
	_assert_true(reset_cooldown >= 1.0, "battle opponent item reset cooldown respects 1s minimum")
	_assert_true(saw_passive_monster_item and passive_items_stayed_passive, "battle opponent passive monster items do not become timed attacks")
	_assert_true(battle_ui.mouse_filter == Control.MOUSE_FILTER_IGNORE, "BattleUI does not block shell controls in shell layout")
	_assert_true(inventory_ui.mouse_filter == Control.MOUSE_FILTER_STOP, "battle keeps player inventory mouse layer active for hover")
	_assert_true(not bool(inventory_ui.call("is_item_interaction_enabled")), "battle disables player board click and drag")
	var player_item_panel: Control = _find_node_by_prefix(inventory_ui, "Item_") as Control
	_assert_not_null(player_item_panel, "battle player board keeps player item panel")
	_assert_true(player_item_panel != null and player_item_panel.mouse_filter == Control.MOUSE_FILTER_STOP, "battle player item accepts hover for tooltip")
	inventory_ui.call("_show_hover_tooltip", player_item)
	_assert_not_null(_find_node(inventory_ui, "HoverTooltip"), "battle player item can show hover tooltip while drag is disabled")
	inventory_ui.call("_hide_hover_tooltip")
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

func _find_node_by_prefix(root: Node, name_prefix: String) -> Node:
	if root == null:
		return null
	if root.name.begins_with(name_prefix):
		return root
	for child in root.get_children():
		var found: Node = _find_node_by_prefix(child, name_prefix)
		if found != null:
			return found
	return null

func _find_opponent_item_with_cooldown(root: Node) -> Node:
	if root == null:
		return null
	if root.name.begins_with("OpponentItem_") and root.get_node_or_null("CooldownOverlay") != null:
		return root
	for child in root.get_children():
		var found: Node = _find_opponent_item_with_cooldown(child)
		if found != null:
			return found
	return null

func _has_any_effect_word(text: String) -> bool:
	for word in ["造成", "燃烧", "中毒", "治疗", "护盾", "恢复", "减速"]:
		if text.find(word) >= 0:
			return true
	return false

func _has_label_text_containing(root: Node, needle: String) -> bool:
	if root == null:
		return false
	var label: Label = root as Label
	if label != null and label.text.find(needle) >= 0:
		return true
	for child in root.get_children():
		if _has_label_text_containing(child, needle):
			return true
	return false

func _count_named_children(root: Node, name_prefix: String) -> int:
	if root == null:
		return 0
	var count: int = 0
	for child in root.get_children():
		if child.name.begins_with(name_prefix):
			count += 1
	return count

func _sum_shell_slot_spans(root: Node) -> int:
	if root == null:
		return 0
	var count: int = 0
	for child in root.get_children():
		if child.name.begins_with("OpponentSlot"):
			count += int(child.get_meta("slot_span", 1))
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
