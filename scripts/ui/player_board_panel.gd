class_name PlayerBoardPanel
extends Control

## Persistent player board slot for the Bazaar shell.

const EXPECTED_SLOT_COUNT: int = 10

var _inventory_source: Control = null

@onready var slot_container: HBoxContainer = $BoardFrame/Margin/SlotContainer
@onready var status_label: Label = $BoardFrame/StatusLabel

func _ready() -> void:
	_create_placeholder_slots()
	refresh_layout()

func bind_inventory_source(inventory_source: Control) -> void:
	_inventory_source = inventory_source
	refresh_layout()

func get_inventory() -> Resource:
	if _inventory_source != null and _inventory_source.has_method("get_inventory"):
		return _inventory_source.get_inventory()
	return null

func set_interaction_enabled(enabled: bool) -> void:
	if _inventory_source == null:
		return
	_inventory_source.mouse_filter = Control.MOUSE_FILTER_STOP
	if _inventory_source.has_method("set_item_interaction_enabled"):
		_inventory_source.call("set_item_interaction_enabled", enabled)

func refresh_layout() -> void:
	var inventory: Resource = get_inventory()
	var item_count: int = 0
	if inventory != null and inventory.has_method("get_item_count"):
		item_count = int(inventory.get_item_count())
	status_label.text = "Board %d/%d" % [item_count, EXPECTED_SLOT_COUNT]

func _create_placeholder_slots() -> void:
	for child in slot_container.get_children():
		child.queue_free()
	slot_container.alignment = BoxContainer.ALIGNMENT_BEGIN
	slot_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for index in range(EXPECTED_SLOT_COUNT):
		var slot: Panel = Panel.new()
		slot.name = "BoardSlot%d" % index
		slot.custom_minimum_size = Vector2(48, 96)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
		slot.add_theme_stylebox_override("panel", _create_slot_style(index))
		slot_container.add_child(slot)

func _create_slot_style(index: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.13, 0.18, 0.55)
	style.border_color = Color(0.44, 0.51, 0.62, 0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	if index == 0 or index == EXPECTED_SLOT_COUNT - 1:
		style.border_color = Color(0.66, 0.50, 0.22, 0.75)
	return style
