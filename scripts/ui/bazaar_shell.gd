class_name BazaarShell
extends Control

## Shared Bazaar-like screen shell for run UI states.

const TimeSelectViewScene: PackedScene = preload("res://scenes/ui/time_select_view.tscn")
const MerchantStateViewScene: PackedScene = preload("res://scenes/ui/merchant_state_view.tscn")
const InventoryUIScene: PackedScene = preload("res://scenes/inventory_ui.tscn")
const LinearInventoryClass = preload("res://scripts/data/linear_inventory.gd")
const BazaarContentClass = preload("res://scripts/data/bazaar_content.gd")
const ItemArtCatalogClass = preload("res://scripts/data/item_art_catalog.gd")
const CHEST_ICON_PATH: String = "res://assets/art/ui/ui_chest_icon.png"
const STASH_OVERLAY_Z_INDEX: int = 200

signal option_selected(index: int)
signal right_action_pressed(action_id: String)
signal stash_requested()

var _game_manager: Node = null
var _inventory_source: Control = null
var _stash_inventory: LinearInventoryClass = LinearInventoryClass.new()
var _stash_overlay: Control = null
var _stash_inventory_ui: Control = null

@onready var top_context_panel: Control = $TopContextPanel
@onready var upper_board_panel: Control = $UpperBoardPanel
@onready var player_board_panel: Control = $PlayerBoardPanel
@onready var bottom_hud_panel: Control = $BottomHudPanel
@onready var left_clock_panel: Control = $LeftClockPanel
@onready var right_action_area: Control = $RightActionArea
@onready var overlay_layer: Control = $OverlayLayer

func _ready() -> void:
	overlay_layer.z_index = STASH_OVERLAY_Z_INDEX
	overlay_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
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

func get_stash_inventory() -> Resource:
	return _stash_inventory

func get_overlay_layer() -> Control:
	return overlay_layer

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
	hide_stash()
	if _inventory_source != null:
		_inventory_source.visible = false

func clear_dynamic_regions() -> void:
	_clear_children(top_context_panel)
	_clear_children(upper_board_panel)
	_clear_children(right_action_area)

func show_time_select(options: Array[Dictionary]) -> void:
	clear_dynamic_regions()
	var view: Control = TimeSelectViewScene.instantiate() as Control
	view.name = "TimeSelectView"
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	upper_board_panel.add_child(view)
	if view.has_method("set_options"):
		view.call("set_options", options)
	view.connect("option_selected", Callable(self, "_on_option_pressed"))

func show_merchant(inventory: Resource, merchant_info: Dictionary = {}) -> Control:
	clear_dynamic_regions()
	_add_merchant_context(merchant_info)
	var view: Control = MerchantStateViewScene.instantiate() as Control
	view.name = "MerchantStateView"
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	upper_board_panel.add_child(view)
	if view.has_method("show_merchant"):
		view.call("show_merchant", inventory, _stash_inventory, merchant_info)
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

func set_right_actions(actions: Array) -> void:
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

func toggle_stash() -> void:
	if _stash_overlay != null and is_instance_valid(_stash_overlay) and _stash_overlay.visible:
		hide_stash()
	else:
		show_stash()

func show_stash() -> void:
	if _stash_overlay == null or not is_instance_valid(_stash_overlay):
		_create_stash_overlay()
	overlay_layer.z_index = STASH_OVERLAY_Z_INDEX
	overlay_layer.move_to_front()
	_stash_overlay.visible = true
	_stash_overlay.z_index = STASH_OVERLAY_Z_INDEX
	_stash_overlay.move_to_front()
	if _stash_inventory_ui != null and _stash_inventory_ui.has_method("set_inventory"):
		_stash_inventory_ui.call("set_inventory", _stash_inventory)
		_stash_inventory_ui.call("set_item_interaction_enabled", true)

func hide_stash() -> void:
	if _stash_overlay != null and is_instance_valid(_stash_overlay):
		_stash_overlay.visible = false

func _create_stash_overlay() -> void:
	_stash_overlay = Control.new()
	_stash_overlay.name = "StashOverlay"
	_stash_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stash_overlay.z_index = STASH_OVERLAY_Z_INDEX
	_stash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_layer.add_child(_stash_overlay)

	var dim: ColorRect = ColorRect.new()
	dim.name = "StashDim"
	dim.color = Color(0.0, 0.0, 0.0, 0.28)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stash_overlay.add_child(dim)

	var frame: Panel = Panel.new()
	frame.name = "StashFrame"
	frame.anchor_left = 0.20
	frame.anchor_top = 0.11
	frame.anchor_right = 0.82
	frame.anchor_bottom = 0.52
	frame.z_index = 1
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	frame.add_theme_stylebox_override("panel", _make_stash_frame_style())
	_stash_overlay.add_child(frame)

	var header: Panel = Panel.new()
	header.name = "StashHeader"
	header.anchor_left = 0.43
	header.anchor_top = -0.22
	header.anchor_right = 0.57
	header.anchor_bottom = 0.15
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_stylebox_override("panel", _make_stash_header_style())
	frame.add_child(header)

	var icon: TextureRect = TextureRect.new()
	icon.name = "ChestIcon"
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 12
	icon.offset_top = 8
	icon.offset_right = -12
	icon.offset_bottom = -8
	if ResourceLoader.exists(CHEST_ICON_PATH):
		icon.texture = load(CHEST_ICON_PATH)
	header.add_child(icon)

	var close_button: Button = Button.new()
	close_button.name = "CloseStashButton"
	close_button.text = "X"
	close_button.anchor_left = 0.96
	close_button.anchor_top = 0.03
	close_button.anchor_right = 0.995
	close_button.anchor_bottom = 0.13
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(hide_stash)
	frame.add_child(close_button)

	var inventory_margin: MarginContainer = MarginContainer.new()
	inventory_margin.name = "StashInventoryMargin"
	inventory_margin.anchor_left = 0.0
	inventory_margin.anchor_top = 0.42
	inventory_margin.anchor_right = 1.0
	inventory_margin.anchor_bottom = 0.98
	inventory_margin.add_theme_constant_override("margin_left", 0)
	inventory_margin.add_theme_constant_override("margin_top", 0)
	inventory_margin.add_theme_constant_override("margin_right", 0)
	inventory_margin.add_theme_constant_override("margin_bottom", 0)
	frame.add_child(inventory_margin)

	_stash_inventory_ui = InventoryUIScene.instantiate() as Control
	_stash_inventory_ui.name = "StashInventoryUI"
	_stash_inventory_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inventory_margin.add_child(_stash_inventory_ui)
	if _stash_inventory_ui.has_method("set_inventory"):
		_stash_inventory_ui.call("set_inventory", _stash_inventory)

func _make_stash_frame_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.18, 0.11, 0.90)
	style.border_color = Color(1.0, 0.74, 0.16, 0.92)
	style.set_border_width_all(4)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	style.shadow_size = 18
	style.shadow_offset = Vector2(0, 8)
	return style

func _make_stash_header_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.13, 0.10, 0.92)
	style.border_color = Color(0.92, 0.66, 0.28, 0.95)
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	return style

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

func _add_merchant_context(merchant_info: Dictionary = {}) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "MerchantContextRow"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	top_context_panel.add_child(row)

	row.add_child(_create_context_decor_panel("left"))
	row.add_child(_create_merchant_portrait(merchant_info))
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

func _create_merchant_portrait(merchant_info: Dictionary = {}) -> Control:
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

	var merchant_id: String = str(merchant_info.get("merchant_id", "jay_jay"))
	var art_path: String = str(merchant_info.get("art_path", ""))
	if art_path.is_empty():
		art_path = BazaarContentClass.get_merchant_art_path(merchant_id)
	var art_texture: Texture2D = ItemArtCatalogClass.load_texture(art_path)
	if art_texture != null:
		var art: TextureRect = TextureRect.new()
		art.name = "MerchantPortraitArt"
		art.texture = art_texture
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.offset_left = 6.0
		art.offset_top = 6.0
		art.offset_right = -6.0
		art.offset_bottom = -6.0
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait.add_child(art)

	var ribbon: ColorRect = ColorRect.new()
	ribbon.name = "MerchantNameRibbon"
	ribbon.color = Color(0.02, 0.02, 0.03, 0.58)
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ribbon.anchor_left = 0.0
	ribbon.anchor_top = 1.0
	ribbon.anchor_right = 1.0
	ribbon.anchor_bottom = 1.0
	ribbon.offset_left = 0.0
	ribbon.offset_top = -36.0
	ribbon.offset_right = 0.0
	ribbon.offset_bottom = 0.0
	portrait.add_child(ribbon)

	var label: Label = Label.new()
	label.name = "MerchantNameLabel"
	label.text = str(merchant_info.get("text", merchant_info.get("name", "Merchant")))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.96, 0.84, 0.56, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.80))
	label.add_theme_constant_override("outline_size", 2)
	label.anchor_left = 0.0
	label.anchor_top = 1.0
	label.anchor_right = 1.0
	label.anchor_bottom = 1.0
	label.offset_left = 4.0
	label.offset_top = -34.0
	label.offset_right = -4.0
	label.offset_bottom = -4.0
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
		node.remove_child(child)
		child.queue_free()

func _on_option_pressed(index: int) -> void:
	option_selected.emit(index)

func _on_right_action_pressed(action_id: String) -> void:
	right_action_pressed.emit(action_id)

func _on_stash_requested() -> void:
	toggle_stash()
	stash_requested.emit()
