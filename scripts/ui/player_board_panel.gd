class_name PlayerBoardPanel
extends Control

## Persistent shell-level player board host.

const InventoryUIScene: PackedScene = preload("res://scenes/inventory_ui.tscn")
const LinearInventoryClass = preload("res://scripts/data/linear_inventory.gd")

var _inventory_ui: InventoryUI = null
var _owns_inventory_ui: bool = false

@onready var inventory_host: Control = $BoardFrame/InventoryHost

func _ready() -> void:
	_ensure_inventory_ui()
	refresh_layout()

func bind_inventory_source(inventory_source: Control) -> void:
	if inventory_source is InventoryUI:
		_host_inventory_ui(inventory_source as InventoryUI, false)
	elif inventory_source != null and inventory_source.has_method("get_inventory"):
		_ensure_inventory_ui()
		var inventory: LinearInventoryClass = inventory_source.call("get_inventory") as LinearInventoryClass
		set_inventory(inventory)
	else:
		_ensure_inventory_ui()
	refresh_layout()

func set_inventory(inventory: LinearInventoryClass) -> void:
	_ensure_inventory_ui()
	if _inventory_ui != null:
		_inventory_ui.set_inventory(inventory)

func get_inventory_ui() -> InventoryUI:
	_ensure_inventory_ui()
	return _inventory_ui

func get_inventory() -> Resource:
	_ensure_inventory_ui()
	if _inventory_ui != null:
		return _inventory_ui.get_inventory()
	return null

func set_interaction_enabled(enabled: bool) -> void:
	_ensure_inventory_ui()
	if _inventory_ui == null:
		return
	_inventory_ui.mouse_filter = Control.MOUSE_FILTER_STOP
	_inventory_ui.set_item_interaction_enabled(enabled)

func refresh_layout() -> void:
	_ensure_inventory_ui()
	if _inventory_ui != null and _inventory_ui.has_method("_queue_inventory_layout_refresh"):
		_inventory_ui.call("_queue_inventory_layout_refresh")

func _ensure_inventory_ui() -> void:
	if _inventory_ui != null and is_instance_valid(_inventory_ui):
		return
	var inventory_ui: InventoryUI = InventoryUIScene.instantiate() as InventoryUI
	inventory_ui.name = "InventoryUI"
	_host_inventory_ui(inventory_ui, true)

func _host_inventory_ui(inventory_ui: InventoryUI, owned: bool) -> void:
	if inventory_ui == null:
		return
	var host: Control = _get_inventory_host()
	if host == null:
		return
	if _inventory_ui != null and _inventory_ui != inventory_ui and is_instance_valid(_inventory_ui) and _owns_inventory_ui:
		_inventory_ui.queue_free()
	if inventory_ui.get_parent() != host:
		var previous_parent: Node = inventory_ui.get_parent()
		if previous_parent != null:
			previous_parent.remove_child(inventory_ui)
		host.add_child(inventory_ui)
	_configure_inventory_ui_layout(inventory_ui)
	_inventory_ui = inventory_ui
	_owns_inventory_ui = owned
	_inventory_ui.visible = true

func _get_inventory_host() -> Control:
	if inventory_host != null:
		return inventory_host
	return get_node_or_null("BoardFrame/InventoryHost") as Control

func _configure_inventory_ui_layout(inventory_ui: Control) -> void:
	inventory_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inventory_ui.offset_left = 0.0
	inventory_ui.offset_top = 0.0
	inventory_ui.offset_right = 0.0
	inventory_ui.offset_bottom = 0.0
	inventory_ui.mouse_filter = Control.MOUSE_FILTER_STOP
