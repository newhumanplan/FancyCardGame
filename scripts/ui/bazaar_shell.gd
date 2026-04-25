class_name BazaarShell
extends Control

## Shared Bazaar-like screen shell for run UI states.

const TimeSelectViewScene: PackedScene = preload("res://scenes/ui/time_select_view.tscn")
const MerchantStateViewScene: PackedScene = preload("res://scenes/ui/merchant_state_view.tscn")

signal option_selected(index: int)
signal right_action_pressed(action_id: String)
signal stash_requested()

var _game_manager: Node = null
var _inventory_source: Control = null

@onready var top_context_panel: Control = $TopContextPanel
@onready var upper_board_panel: Control = $UpperBoardPanel
@onready var player_board_panel: Control = $PlayerBoardPanel
@onready var bottom_hud_panel: Control = $BottomHudPanel
@onready var left_clock_panel: Control = $LeftClockPanel
@onready var right_action_area: Control = $RightActionArea
@onready var overlay_layer: Control = $OverlayLayer

func _ready() -> void:
	hide_run_shell()
	if not bottom_hud_panel.stash_requested.is_connected(_on_stash_requested):
		bottom_hud_panel.stash_requested.connect(_on_stash_requested)

func setup(game_manager: Node, inventory_source: Control = null) -> void:
	_game_manager = game_manager
	_inventory_source = inventory_source
	left_clock_panel.bind_run_state(RunStateService, PhaseService)
	bottom_hud_panel.bind_services(game_manager, HeroStateService, EconomyService)
	player_board_panel.bind_inventory_source(inventory_source)
	if _inventory_source != null:
		_inventory_source.visible = visible

func get_player_inventory() -> Resource:
	return player_board_panel.get_inventory()

func show_run_shell() -> void:
	visible = true
	if _inventory_source != null:
		_inventory_source.visible = true
	left_clock_panel.refresh(
		int(RunStateService.current_day),
		int(RunStateService.current_hour),
		int(RunStateService.prestige),
		int(RunStateService.pvp_wins)
	)
	bottom_hud_panel.refresh_all()
	player_board_panel.refresh_layout()

func hide_run_shell() -> void:
	visible = false
	if _inventory_source != null:
		_inventory_source.visible = false

func clear_dynamic_regions() -> void:
	_clear_children(top_context_panel)
	_clear_children(upper_board_panel)
	_clear_children(right_action_area)

func show_time_select(options: Array[Dictionary]) -> void:
	clear_dynamic_regions()
	_add_time_context()
	var view: Control = TimeSelectViewScene.instantiate() as Control
	view.name = "TimeSelectView"
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	upper_board_panel.add_child(view)
	if view.has_method("set_options"):
		view.call("set_options", options)
	view.connect("option_selected", Callable(self, "_on_option_pressed"))

func show_merchant(inventory: Resource) -> Control:
	clear_dynamic_regions()
	_add_merchant_context()
	var view: Control = MerchantStateViewScene.instantiate() as Control
	view.name = "MerchantStateView"
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	upper_board_panel.add_child(view)
	if view.has_method("show_merchant"):
		view.call("show_merchant", inventory)
	set_right_actions([
		{"id": "merchant_refresh", "label": "刷新"},
		{"id": "merchant_leave", "label": "离开"},
	])
	return view

func show_merchant_placeholder() -> void:
	show_merchant(get_player_inventory())

func show_battle_placeholder() -> void:
	clear_dynamic_regions()
	_add_context_label("Opponent")
	_add_upper_placeholder("Opponent board will fill this area.")

func set_right_actions(actions: Array[Dictionary]) -> void:
	_clear_children(right_action_area)
	var column: VBoxContainer = VBoxContainer.new()
	column.name = "RightActionColumn"
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 10)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	right_action_area.add_child(column)
	for action in actions:
		var button: Button = Button.new()
		var action_id: String = str(action.get("id", "action"))
		button.name = "Action_%s" % action_id
		button.text = str(action.get("label", action_id))
		button.custom_minimum_size = Vector2(120, 42)
		button.pressed.connect(_on_right_action_pressed.bind(action_id))
		column.add_child(button)

func set_board_interaction_enabled(enabled: bool) -> void:
	player_board_panel.set_interaction_enabled(enabled)

func refresh_static_panels() -> void:
	left_clock_panel.refresh(
		int(RunStateService.current_day),
		int(RunStateService.current_hour),
		int(RunStateService.prestige),
		int(RunStateService.pvp_wins)
	)
	bottom_hud_panel.refresh_all()
	player_board_panel.refresh_layout()

func _add_context_label(text: String) -> void:
	var label: Label = Label.new()
	label.name = "ContextLabel"
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(0.95, 0.88, 0.68, 1.0))
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	top_context_panel.add_child(label)

func _add_time_context() -> void:
	var label: Label = Label.new()
	label.name = "HourContextLabel"
	label.text = "Day %d  Hour %d" % [int(RunStateService.current_day), int(RunStateService.current_hour) + 1]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(0.92, 0.88, 0.76, 0.86))
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	top_context_panel.add_child(label)

func _add_merchant_context() -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "MerchantContextRow"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	top_context_panel.add_child(row)

	row.add_child(_create_context_decor_panel("left"))
	row.add_child(_create_merchant_portrait())
	row.add_child(_create_context_decor_panel("right"))

func _create_context_decor_panel(side: String) -> Control:
	var panel: Panel = Panel.new()
	panel.name = "MerchantDecor_%s" % side
	panel.custom_minimum_size = Vector2(220, 112)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.22, 0.12, 0.08, 0.42)
	style.border_color = Color(0.78, 0.54, 0.28, 0.52)
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _create_merchant_portrait() -> Control:
	var portrait: Panel = Panel.new()
	portrait.name = "MerchantPortrait"
	portrait.custom_minimum_size = Vector2(156, 124)
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.13, 0.12, 0.88)
	style.border_color = Color(0.88, 0.65, 0.34, 0.92)
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 4)
	portrait.add_theme_stylebox_override("panel", style)

	var label: Label = Label.new()
	label.name = "MerchantNameLabel"
	label.text = "Merchant"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(0.96, 0.84, 0.56, 1.0))
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait.add_child(label)
	return portrait

func _add_upper_placeholder(text: String) -> void:
	var label: Label = Label.new()
	label.name = "UpperPlaceholder"
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.80, 0.83, 0.88, 0.8))
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	upper_board_panel.add_child(label)

func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()

func _on_option_pressed(index: int) -> void:
	option_selected.emit(index)

func _on_right_action_pressed(action_id: String) -> void:
	right_action_pressed.emit(action_id)

func _on_stash_requested() -> void:
	stash_requested.emit()
