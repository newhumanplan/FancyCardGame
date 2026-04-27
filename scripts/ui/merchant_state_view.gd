class_name MerchantStateView
extends Control

## Bazaar shell state view for the merchant shelf.
## This view renders items and emits user intent; it does not spend gold or mutate inventory.

const EconomyManagerClass = preload("res://scripts/data/economy_manager.gd")
const ItemDataClass = preload("res://scripts/data/item_data.gd")
const LinearInventoryClass = preload("res://scripts/data/linear_inventory.gd")
const BazaarContentClass = preload("res://scripts/data/bazaar_content.gd")
const ItemAcquisitionClass = preload("res://scripts/data/item_acquisition.gd")
const ItemArtCatalogClass = preload("res://scripts/data/item_art_catalog.gd")
const ItemDetailPanelScene = preload("res://scenes/ui/item_detail_panel.tscn")

const SHOP_CARD_BG: String = "res://assets/art/ui/ui_shop_card_bg.png"
const ITEM_CARD_BG: String = "res://assets/art/ui/ui_item_card_bg.png"
const REFRESH_COST: int = 2
const MAX_VISIBLE_ITEMS: int = 5
const SHOP_TOTAL_SLOTS: int = 10
const SHOP_SLOT_SPACING: int = 8
const SHOP_SLOT_INSET: float = 4.0
const SHOP_SLOT_SIZE: Vector2 = Vector2(96.0, 192.0)
const SHOP_BOARD_MIN_SIZE: Vector2 = Vector2(1080.0, 220.0)
const RARITY_NAMES: Array[String] = ["普通", "稀有", "史诗", "传说"]

signal purchase_requested(item: ItemDataClass, index: int)
signal refresh_requested(cost: int)
signal closed()

@onready var shelf_row: HBoxContainer = $ShelfRow
@onready var feedback_label: Label = $FeedbackLabel

var shop_items: Array[ItemDataClass] = []
var inventory: LinearInventoryClass = null
var stash_inventory: LinearInventoryClass = null
var merchant_info: Dictionary = {}
var free_refresh_used: bool = false
var locked_indices: Array[int] = []
var hover_tooltip: Control = null
var shop_slot_panels: Array[Panel] = []
var shop_item_panels: Array[Control] = []
var shop_item_slot_starts: Array[int] = []
var shop_item_layer: Control = null

func _ready() -> void:
	visible = true

func show_merchant(inventory_ref: LinearInventoryClass, stash_inventory_ref: LinearInventoryClass = null, merchant_info_ref: Dictionary = {}) -> void:
	inventory = inventory_ref
	stash_inventory = stash_inventory_ref
	merchant_info = merchant_info_ref.duplicate(true)
	free_refresh_used = false
	locked_indices.clear()
	_generate_shop_items()
	_refresh_shelf()
	show_feedback("")
	visible = true

func request_refresh() -> void:
	refresh_requested.emit(get_refresh_cost())

func request_close() -> void:
	closed.emit()

func get_refresh_cost() -> int:
	return 0 if not free_refresh_used else REFRESH_COST

func get_visible_item_count() -> int:
	return mini(shop_items.size(), MAX_VISIBLE_ITEMS)

func is_item_locked(index: int) -> bool:
	return index in locked_indices

func apply_refresh() -> void:
	var item_count: int = maxi(shop_items.size(), 3)
	item_count = mini(item_count, MAX_VISIBLE_ITEMS)
	var day: int = maxi(int(GameManager.current_day), 1)
	var max_rarity: int = _get_max_rarity_for_day(day)
	var new_items: Array[ItemDataClass] = []

	for index in range(item_count):
		if index in locked_indices and index < shop_items.size():
			new_items.append(shop_items[index])
		else:
			var generated_item: ItemDataClass = _create_random_item(day, max_rarity)
			if generated_item != null:
				new_items.append(generated_item)

	shop_items = new_items
	_filter_invalid_shop_items()
	free_refresh_used = true
	_refresh_shelf()
	show_feedback("货架已刷新")

func apply_purchase_success(index: int) -> void:
	if index < 0 or index >= shop_items.size():
		_refresh_shelf()
		return

	var purchased_name: String = shop_items[index].item_name
	shop_items.remove_at(index)
	_reindex_locks_after_remove(index)
	_filter_invalid_shop_items()
	_refresh_shelf()
	show_feedback("已购买 %s" % purchased_name)

func show_feedback(message: String, is_error: bool = false) -> void:
	if feedback_label == null:
		return
	feedback_label.text = message
	feedback_label.visible = not message.is_empty()
	feedback_label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.44, 0.36, 1.0) if is_error else Color(0.82, 0.96, 0.74, 1.0)
	)

func update_button_states() -> void:
	if is_node_ready():
		_refresh_shelf()

func _generate_shop_items() -> void:
	shop_items.clear()
	var day: int = maxi(int(GameManager.current_day), 1)
	var max_rarity: int = _get_max_rarity_for_day(day)
	var item_count: int = randi_range(3, MAX_VISIBLE_ITEMS)

	for i in range(item_count):
		var generated_item: ItemDataClass = _create_random_item(day, max_rarity)
		if generated_item != null:
			shop_items.append(generated_item)
	_filter_invalid_shop_items()

func _refresh_shelf() -> void:
	_hide_item_tooltip()
	for child in shelf_row.get_children():
		shelf_row.remove_child(child)
		child.queue_free()
	shop_slot_panels.clear()
	shop_item_panels.clear()
	shop_item_slot_starts.clear()
	shop_item_layer = null

	if shop_items.is_empty():
		var empty_label: Label = Label.new()
		empty_label.name = "EmptyShelfLabel"
		empty_label.text = "售罄"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.custom_minimum_size = Vector2(240, 150)
		empty_label.add_theme_font_size_override("font_size", 24)
		empty_label.add_theme_color_override("font_color", Color(0.92, 0.86, 0.72, 0.85))
		shelf_row.add_child(empty_label)
		return

	var board: Panel = _create_shop_board()
	shelf_row.add_child(board)
	_populate_shop_item_layer()
	call_deferred("_position_shop_item_panels")

func _create_item_card(item: ItemDataClass, index: int) -> Control:
	var card: Panel = Panel.new()
	card.name = "MerchantItemCard%d" % index
	card.clip_contents = true
	card.custom_minimum_size = Vector2(96, 96)
	card.size = card.custom_minimum_size
	card.set_meta("shop_index", index)
	card.set_meta("item_data", item)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.add_theme_stylebox_override("panel", _make_item_card_style(item))
	card.mouse_entered.connect(_show_item_tooltip.bind(item, card))
	card.mouse_exited.connect(_hide_item_tooltip)

	var texture_path: String = _get_shop_item_texture_path(item)
	var item_texture: Texture2D = ItemArtCatalogClass.load_texture(texture_path)
	if item_texture != null:
		var art: TextureRect = TextureRect.new()
		art.name = "ItemArt"
		art.texture = item_texture
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.offset_left = 2.0
		art.offset_top = 2.0
		art.offset_right = -2.0
		art.offset_bottom = -2.0
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(art)
	else:
		var fallback: TextureRect = TextureRect.new()
		fallback.name = "ItemArtFallback"
		fallback.texture = load(ITEM_CARD_BG)
		fallback.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fallback.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		fallback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(fallback)

	var name_label: Label = Label.new()
	name_label.name = "ItemNameLabel"
	name_label.text = item.item_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.75))
	name_label.add_theme_constant_override("outline_size", 2)
	name_label.anchor_left = 0.0
	name_label.anchor_top = 1.0
	name_label.anchor_right = 1.0
	name_label.anchor_bottom = 1.0
	name_label.offset_left = 4.0
	name_label.offset_top = -28.0
	name_label.offset_right = -4.0
	name_label.offset_bottom = -4.0
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(name_label)

	var stat_grid: GridContainer = _create_item_stat_badge_grid(item)
	if stat_grid.get_child_count() > 0:
		card.add_child(stat_grid)

	var buy_button: Button = _create_item_value_button(item.buy_price, index)
	buy_button.tooltip_text = "%s | %s | %d gold" % [item.item_name, _get_item_stat_text(item), item.buy_price]
	buy_button.pressed.connect(_on_buy_pressed.bind(item, index))
	_update_buy_button_state(buy_button, item)
	card.add_child(buy_button)

	return card

func _create_shop_board() -> Panel:
	var board: Panel = Panel.new()
	board.name = "MerchantShopBoard"
	board.custom_minimum_size = SHOP_BOARD_MIN_SIZE
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.add_theme_stylebox_override("panel", _make_shop_board_style())

	var margin: MarginContainer = MarginContainer.new()
	margin.name = "MerchantShopBoardMargin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	board.add_child(margin)

	var board_root: Control = Control.new()
	board_root.name = "MerchantShopBoardRoot"
	board_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(board_root)

	var slot_row: HBoxContainer = HBoxContainer.new()
	slot_row.name = "MerchantShopSlotRow"
	slot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	slot_row.add_theme_constant_override("separation", SHOP_SLOT_SPACING)
	slot_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slot_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board_root.add_child(slot_row)

	for slot_index in range(SHOP_TOTAL_SLOTS):
		var slot: Panel = _create_shop_slot(slot_index)
		shop_slot_panels.append(slot)
		slot_row.add_child(slot)

	shop_item_layer = Control.new()
	shop_item_layer.name = "MerchantShopItemLayer"
	shop_item_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shop_item_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shop_item_layer.z_index = 5
	board_root.add_child(shop_item_layer)
	return board

func _create_shop_slot(slot_index: int) -> Panel:
	var slot: Panel = Panel.new()
	slot.name = "MerchantShopSlot%d" % slot_index
	slot.custom_minimum_size = SHOP_SLOT_SIZE
	slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slot.add_theme_stylebox_override("panel", _make_shop_slot_style())
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var label: Label = Label.new()
	label.name = "SlotLabel"
	label.text = str(slot_index + 1)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.63, 0.63, 0.74, 0.75))
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 4.0
	label.offset_top = 4.0
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(label)
	return slot

func _populate_shop_item_layer() -> void:
	if shop_item_layer == null:
		return
	for child in shop_item_layer.get_children():
		child.queue_free()
	shop_item_panels.clear()
	shop_item_slot_starts = _calculate_shop_item_slot_starts()
	var count: int = mini(get_visible_item_count(), shop_item_slot_starts.size())
	for index in range(count):
		var item: ItemDataClass = shop_items[index]
		var item_panel: Control = _create_item_card(item, index)
		item_panel.set_meta("shop_slot", shop_item_slot_starts[index])
		shop_item_layer.add_child(item_panel)
		shop_item_panels.append(item_panel)
	_position_shop_item_panels()

func _position_shop_item_panels() -> void:
	if shop_item_layer == null or shop_slot_panels.is_empty():
		return
	for panel in shop_item_panels:
		if not is_instance_valid(panel):
			continue
		var item: ItemDataClass = panel.get_meta("item_data", null) as ItemDataClass
		if item == null:
			continue
		var start_slot: int = int(panel.get_meta("shop_slot", 0))
		var slot_count: int = _get_shop_item_slot_count(item)
		var item_rect: Rect2 = _get_shop_slot_span_rect(start_slot, slot_count)
		panel.position = item_rect.position
		panel.size = item_rect.size
		panel.custom_minimum_size = item_rect.size

func _calculate_shop_item_slot_starts() -> Array[int]:
	var starts: Array[int] = []
	var cursor: int = 0
	for index in range(get_visible_item_count()):
		var item: ItemDataClass = shop_items[index]
		var slot_count: int = _get_shop_item_slot_count(item)
		if cursor + slot_count > SHOP_TOTAL_SLOTS:
			break
		starts.append(cursor)
		cursor += slot_count
	return starts

func _get_shop_item_slot_count(item: ItemDataClass) -> int:
	if item == null:
		return 1
	return clampi(item.get_slot_count(), 1, 3)

func _get_shop_slot_span_rect(start_slot: int, slot_count: int) -> Rect2:
	if start_slot < 0 or start_slot >= shop_slot_panels.size() or slot_count <= 0:
		return Rect2(Vector2.ZERO, SHOP_SLOT_SIZE)
	var end_slot: int = mini(start_slot + slot_count - 1, shop_slot_panels.size() - 1)
	var first_slot: Control = shop_slot_panels[start_slot] as Control
	var last_slot: Control = shop_slot_panels[end_slot] as Control
	if first_slot == null or last_slot == null:
		return Rect2(Vector2.ZERO, SHOP_SLOT_SIZE)

	var layer_global: Vector2 = shop_item_layer.global_position if shop_item_layer != null else Vector2.ZERO
	if first_slot.size.x <= 0.0 or first_slot.size.y <= 0.0 or last_slot.size.x <= 0.0:
		var fallback_width: float = float(slot_count) * SHOP_SLOT_SIZE.x + float(slot_count - 1) * SHOP_SLOT_SPACING - SHOP_SLOT_INSET * 2.0
		return Rect2(Vector2(SHOP_SLOT_INSET, SHOP_SLOT_INSET), Vector2(fallback_width, SHOP_SLOT_SIZE.y - SHOP_SLOT_INSET * 2.0))

	var left: float = first_slot.global_position.x - layer_global.x + SHOP_SLOT_INSET
	var top: float = first_slot.global_position.y - layer_global.y + SHOP_SLOT_INSET
	var right: float = last_slot.global_position.x - layer_global.x + last_slot.size.x - SHOP_SLOT_INSET
	var bottom: float = first_slot.global_position.y - layer_global.y + first_slot.size.y - SHOP_SLOT_INSET
	return Rect2(Vector2(left, top), Vector2(maxf(right - left, 1.0), maxf(bottom - top, 1.0)))

func _update_buy_button_state(button: Button, item: ItemDataClass) -> void:
	if item == null:
		button.disabled = true
		return
	if not GameManager.can_afford(item.buy_price):
		button.disabled = true
		button.tooltip_text = "金币不足"
		return
	if inventory == null:
		return
	if not ItemAcquisitionClass.can_accept_item(item, inventory, stash_inventory, false):
		button.disabled = true
		button.tooltip_text = "背包空间不足"

func _show_item_tooltip(item: ItemDataClass, anchor: Control) -> void:
	if item == null or anchor == null:
		return

	_hide_item_tooltip()
	hover_tooltip = ItemDetailPanelScene.instantiate()
	hover_tooltip.name = "MerchantItemTooltip"
	hover_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hover_tooltip)
	hover_tooltip.call("set_item", item, inventory)
	hover_tooltip.move_to_front()
	_position_item_tooltip(anchor)

func _hide_item_tooltip() -> void:
	if hover_tooltip != null:
		hover_tooltip.queue_free()
		hover_tooltip = null

func _position_item_tooltip(anchor: Control) -> void:
	if hover_tooltip == null or anchor == null:
		return

	var viewport_size: Vector2 = get_viewport_rect().size
	var panel_size: Vector2 = hover_tooltip.custom_minimum_size
	if panel_size == Vector2.ZERO:
		panel_size = hover_tooltip.size

	var anchor_rect: Rect2 = anchor.get_global_rect()
	var target_pos: Vector2 = anchor_rect.position + Vector2(anchor_rect.size.x + 16.0, 0.0)
	if target_pos.x + panel_size.x > viewport_size.x:
		target_pos.x = anchor_rect.position.x - panel_size.x - 16.0
	if target_pos.y + panel_size.y > viewport_size.y:
		target_pos.y = viewport_size.y - panel_size.y - 8.0

	target_pos.x = clampf(target_pos.x, 8.0, maxf(viewport_size.x - panel_size.x - 8.0, 8.0))
	target_pos.y = clampf(target_pos.y, 8.0, maxf(viewport_size.y - panel_size.y - 8.0, 8.0))
	hover_tooltip.global_position = target_pos

func _on_buy_pressed(item: ItemDataClass, index: int) -> void:
	_hide_item_tooltip()
	purchase_requested.emit(item, index)

func _on_lock_pressed(index: int) -> void:
	if index in locked_indices:
		locked_indices.erase(index)
	else:
		locked_indices.append(index)
	locked_indices.sort()
	_refresh_shelf()

func _reindex_locks_after_remove(removed_index: int) -> void:
	var next_indices: Array[int] = []
	for locked_index in locked_indices:
		if locked_index == removed_index:
			continue
		if locked_index > removed_index:
			next_indices.append(locked_index - 1)
		else:
			next_indices.append(locked_index)
	locked_indices = next_indices

func _filter_invalid_shop_items() -> void:
	var owned_items: Array[ItemDataClass] = _get_owned_items_for_shop()
	var filtered_items: Array[ItemDataClass] = []
	var filtered_locks: Array[int] = []
	for index in range(shop_items.size()):
		var item: ItemDataClass = shop_items[index]
		if item == null:
			continue
		if not BazaarContentClass.is_shop_candidate_allowed(item.source_id, item.rarity, owned_items):
			continue
		if index in locked_indices:
			filtered_locks.append(filtered_items.size())
		filtered_items.append(item)
	shop_items = filtered_items
	locked_indices = filtered_locks

func _get_max_rarity_for_day(day: int) -> int:
	if day == 1:
		return 1
	if day <= 3:
		return 2
	if day <= 5:
		return 3
	return 4

func _create_random_item(day: int, max_rarity: int) -> ItemDataClass:
	var required_size: String = ""
	var required_tag: String = ""
	var effective_max_rarity: int = max_rarity
	var merchant_type: String = str(merchant_info.get("merchant_type", ""))
	var merchant_tier: String = str(merchant_info.get("rarity", ""))

	if merchant_tier == "Silver":
		effective_max_rarity = maxi(effective_max_rarity, BazaarContentClass.RARITY_SILVER)

	match merchant_type:
		"Weapon":
			required_tag = "Weapon"
		"Small":
			required_size = "Small"
		"Medium, Large":
			required_size = "Medium"
		"Ammo":
			required_tag = "Ammo"
		"Bronze, Junk":
			required_tag = "Junk"
			effective_max_rarity = BazaarContentClass.RARITY_BRONZE
		"Potion":
			required_tag = "Potion"
		"Small, Large":
			required_size = "Small"
		"Silver":
			effective_max_rarity = maxi(effective_max_rarity, BazaarContentClass.RARITY_SILVER)

	return BazaarContentClass.create_random_mak_day1_shop_item(effective_max_rarity, _get_owned_items_for_shop(), required_size, required_tag)

func _get_owned_items_for_shop() -> Array[ItemDataClass]:
	return ItemAcquisitionClass.collect_owned_items(inventory, stash_inventory)

func _calculate_price(item: ItemDataClass) -> int:
	var base_price: int = EconomyManagerClass.calculate_item_price(
		item.rarity,
		item.size as int,
		item.type as int,
		GameManager.current_day
	)
	return EconomyManagerClass.apply_prestige_discount(
		base_price,
		GameManager.prestige,
		GameManager.max_prestige
	)

func _get_weapon_name(rarity: int) -> String:
	var names: Array[Array] = [
		["木剑", "钢剑", "魔法剑", "传奇剑"],
		["木斧", "钢斧", "魔法斧", "传奇斧"],
		["木弓", "钢弓", "魔法弓", "传奇弓"],
		["法杖", "魔杖", "元素杖", "星辉杖"]
	]
	var type_index: int = randi() % names.size()
	return str(names[type_index][rarity - 1])

func _get_shield_name(rarity: int) -> String:
	var names: Array[String] = ["木盾", "铁盾", "魔法盾", "传奇盾"]
	return names[rarity - 1]

func _get_heal_name(rarity: int) -> String:
	var names: Array[String] = ["草药", "药水", "圣水", "神级药水"]
	return names[rarity - 1]

func _get_utility_name(rarity: int) -> String:
	var names: Array[String] = ["幸运符", "力量符", "魔法符", "传奇符"]
	return names[rarity - 1]

func _get_item_stat_text(item: ItemDataClass) -> String:
	var parts: Array[String] = []
	for stat in _collect_item_badge_stats(item):
		parts.append(str(stat.get("text", "")))
	if item != null and item.cooldown > 0.0:
		parts.append("%.1fs" % item.cooldown)
	return " / ".join(parts)

func _create_item_stat_badge_grid(item: ItemDataClass) -> GridContainer:
	var grid: GridContainer = GridContainer.new()
	grid.name = "ItemStatBadgeGrid"
	grid.columns = 3
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.z_index = 20
	grid.anchor_left = 0.0
	grid.anchor_top = 0.0
	grid.anchor_right = 1.0
	grid.anchor_bottom = 0.0
	grid.offset_left = 4.0
	grid.offset_top = 4.0
	grid.offset_right = -4.0
	grid.offset_bottom = 52.0
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)

	for stat in _collect_item_badge_stats(item):
		grid.add_child(_create_item_stat_badge(str(stat.get("text", "")), stat.get("color", Color.WHITE)))
	return grid

func _collect_item_badge_stats(item: ItemDataClass) -> Array:
	var stats: Array = []
	if item == null:
		return stats

	var damage_value: int = item.get_rarity_adjusted_damage() if item.damage > 0 else 0
	var poison_value: int = int(round(item.poison_damage * item.get_rarity_multiplier())) if item.poison_damage > 0.0 else 0
	var burn_value: int = int(round(item.burn_damage * item.get_rarity_multiplier())) if item.burn_damage > 0.0 else 0
	var regen_value: int = int(round(item.regeneration * item.get_rarity_multiplier())) if item.regeneration > 0.0 else 0
	var heal_value: int = item.get_rarity_adjusted_heal() if item.heal > 0 else 0
	var shield_value: int = item.get_rarity_adjusted_shield() if item.shield > 0 else 0

	if damage_value > 0:
		stats.append({"text": str(damage_value), "color": Color(0.86, 0.20, 0.17, 0.94)})
	if poison_value > 0:
		stats.append({"text": "毒 %d" % poison_value, "color": Color(0.20, 0.62, 0.30, 0.94)})
	if burn_value > 0:
		stats.append({"text": "火 %d" % burn_value, "color": Color(0.93, 0.42, 0.12, 0.94)})
	if regen_value > 0:
		stats.append({"text": "再 %d" % regen_value, "color": Color(0.20, 0.58, 0.52, 0.94)})
	if heal_value > 0:
		stats.append({"text": "疗 %d" % heal_value, "color": Color(0.26, 0.70, 0.34, 0.94)})
	if shield_value > 0:
		stats.append({"text": "盾 %d" % shield_value, "color": Color(0.20, 0.46, 0.78, 0.94)})
	return stats

func _create_item_stat_badge(text: String, color: Color) -> Panel:
	var badge: Panel = Panel.new()
	badge.name = "ItemStatBadge"
	badge.custom_minimum_size = Vector2(36, 20)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = color.lightened(0.28)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	badge.add_theme_stylebox_override("panel", style)

	var label: Label = Label.new()
	label.name = "BadgeLabel"
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.75))
	label.add_theme_constant_override("outline_size", 1)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(label)
	return badge

func _create_item_value_button(value: int, index: int) -> Button:
	var button: Button = Button.new()
	button.name = "BuyButton%d" % index
	button.text = str(maxi(value, 0))
	button.focus_mode = Control.FOCUS_NONE
	button.z_index = 21
	button.anchor_left = 0.0
	button.anchor_top = 1.0
	button.anchor_right = 0.0
	button.anchor_bottom = 1.0
	button.offset_left = 4.0
	button.offset_top = -30.0
	button.offset_right = 50.0
	button.offset_bottom = -4.0
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.75))
	button.add_theme_constant_override("outline_size", 1)
	button.add_theme_stylebox_override("normal", _make_value_button_style(false))
	button.add_theme_stylebox_override("hover", _make_value_button_style(true))
	button.add_theme_stylebox_override("pressed", _make_value_button_style(true))
	button.add_theme_stylebox_override("disabled", _make_value_button_disabled_style())
	return button

func _make_value_button_style(hovered: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.72, 0.41, 0.10, 0.98) if hovered else Color(0.64, 0.36, 0.08, 0.95)
	style.border_color = Color(1.0, 0.74, 0.30, 0.95)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	return style

func _make_value_button_disabled_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = _make_value_button_style(false)
	style.bg_color = Color(0.30, 0.24, 0.18, 0.78)
	style.border_color = Color(0.55, 0.46, 0.33, 0.70)
	return style

func _get_rarity_color(rarity: int) -> Color:
	match rarity:
		1:
			return Color(0.78, 0.78, 0.74, 1.0)
		2:
			return Color(0.34, 0.95, 0.44, 1.0)
		3:
			return Color(0.78, 0.52, 1.00, 1.0)
		4:
			return Color(1.00, 0.76, 0.30, 1.0)
	return Color.WHITE

func _make_item_card_style(item: ItemDataClass) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.88)
	style.border_color = _get_rarity_color(item.rarity)
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.30)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 3)
	return style

func _make_shop_board_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.16, 0.72)
	style.border_color = Color(0.44, 0.31, 0.12, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	return style

func _make_shop_slot_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.10, 0.16, 0.82)
	style.border_color = Color(0.36, 0.36, 0.50, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	return style

func _make_art_frame_style(item: ItemDataClass) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.03, 0.04, 0.55)
	style.border_color = _get_rarity_color(item.rarity).darkened(0.25)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	return style

func _get_shop_item_texture_path(item: ItemDataClass) -> String:
	if item == null:
		return ""

	var catalog_path: String = ItemArtCatalogClass.get_item_texture_path(item)
	if not catalog_path.is_empty():
		return catalog_path

	if item.type == ItemDataClass.Type.WEAPON:
		if item.damage >= 30:
			return "res://assets/art/items/item_great_sword.png"
		if item.damage >= 20:
			return "res://assets/art/items/item_steel_sword.png"
		if item.damage >= 15:
			return "res://assets/art/items/item_battle_axe.png"
		return "res://assets/art/items/item_iron_sword.png"

	if item.type == ItemDataClass.Type.SHIELD:
		if item.shield >= 25:
			return "res://assets/art/items/item_tower_shield.png"
		if item.shield >= 15:
			return "res://assets/art/items/item_iron_shield.png"
		return "res://assets/art/items/item_wooden_shield.png"

	if item.type == ItemDataClass.Type.HEAL:
		if item.heal >= 20:
			return "res://assets/art/items/item_big_health_potion.png"
		if item.heal >= 10:
			return "res://assets/art/items/item_health_potion.png"
		return "res://assets/art/items/item_regen_potion.png"

	if item.type == ItemDataClass.Type.UTILITY:
		return "res://assets/art/items/item_ring_strength.png"

	return ""
