class_name MerchantStateView
extends Control

## Bazaar shell state view for the merchant shelf.
## This view renders items and emits user intent; it does not spend gold or mutate inventory.

const EconomyManagerClass = preload("res://scripts/data/economy_manager.gd")
const ItemDataClass = preload("res://scripts/data/item_data.gd")
const LinearInventoryClass = preload("res://scripts/data/linear_inventory.gd")

const SHOP_CARD_BG: String = "res://assets/art/ui/ui_shop_card_bg.png"
const ITEM_CARD_BG: String = "res://assets/art/ui/ui_item_card_bg.png"
const REFRESH_COST: int = 2
const MAX_VISIBLE_ITEMS: int = 5
const RARITY_NAMES: Array[String] = ["普通", "稀有", "史诗", "传说"]

signal purchase_requested(item: ItemDataClass, index: int)
signal refresh_requested(cost: int)
signal closed()

@onready var shelf_row: HBoxContainer = $ShelfRow
@onready var feedback_label: Label = $FeedbackLabel

var shop_items: Array[ItemDataClass] = []
var inventory: LinearInventoryClass = null
var free_refresh_used: bool = false
var locked_indices: Array[int] = []

func _ready() -> void:
	visible = true

func show_merchant(inventory_ref: LinearInventoryClass) -> void:
	inventory = inventory_ref
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
			new_items.append(_create_random_item(day, max_rarity))

	shop_items = new_items
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
		shop_items.append(_create_random_item(day, max_rarity))

func _refresh_shelf() -> void:
	for child in shelf_row.get_children():
		child.queue_free()

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

	for index in range(get_visible_item_count()):
		shelf_row.add_child(_create_item_card(shop_items[index], index))

func _create_item_card(item: ItemDataClass, index: int) -> Control:
	var card: Panel = Panel.new()
	card.name = "MerchantItemCard%d" % index
	card.custom_minimum_size = Vector2(154, 164)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.add_theme_stylebox_override("panel", _make_item_card_style(item))

	var bg: TextureRect = TextureRect.new()
	bg.name = "CardBackground"
	bg.texture = load(SHOP_CARD_BG)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.modulate = Color(0.96, 0.86, 0.66, 0.70)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.add_child(bg)

	var margin: MarginContainer = MarginContainer.new()
	margin.name = "CardMargin"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 7)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 7)
	margin.add_theme_constant_override("margin_bottom", 6)
	card.add_child(margin)

	var stack: VBoxContainer = VBoxContainer.new()
	stack.name = "ItemStack"
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 3)
	margin.add_child(stack)

	var art_frame: Panel = Panel.new()
	art_frame.name = "ItemArtFrame"
	art_frame.custom_minimum_size = Vector2(84, 58)
	art_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	art_frame.add_theme_stylebox_override("panel", _make_art_frame_style(item))
	stack.add_child(art_frame)

	var texture_path: String = _get_shop_item_texture_path(item)
	if not texture_path.is_empty() and ResourceLoader.exists(texture_path):
		var art: TextureRect = TextureRect.new()
		art.name = "ItemArt"
		art.texture = load(texture_path)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art_frame.add_child(art)
	else:
		var fallback: TextureRect = TextureRect.new()
		fallback.name = "ItemArtFallback"
		fallback.texture = load(ITEM_CARD_BG)
		fallback.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fallback.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		fallback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art_frame.add_child(fallback)

	var name_label: Label = Label.new()
	name_label.name = "ItemNameLabel"
	name_label.text = item.item_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.clip_text = true
	name_label.custom_minimum_size = Vector2(132, 30)
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", _get_rarity_color(item.rarity))
	stack.add_child(name_label)

	var stats_label: Label = Label.new()
	stats_label.name = "ItemStatsLabel"
	stats_label.text = _get_item_stat_text(item)
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.clip_text = true
	stats_label.custom_minimum_size = Vector2(132, 18)
	stats_label.add_theme_font_size_override("font_size", 12)
	stats_label.add_theme_color_override("font_color", Color(0.88, 0.90, 0.88, 0.92))
	stack.add_child(stats_label)

	var bottom_row: HBoxContainer = HBoxContainer.new()
	bottom_row.name = "ItemActionRow"
	bottom_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_row.add_theme_constant_override("separation", 5)
	stack.add_child(bottom_row)

	var buy_button: Button = Button.new()
	buy_button.name = "BuyButton%d" % index
	buy_button.text = "%d" % item.buy_price
	buy_button.custom_minimum_size = Vector2(58, 28)
	buy_button.tooltip_text = "%s | %s | %d gold" % [item.item_name, _get_item_stat_text(item), item.buy_price]
	buy_button.pressed.connect(_on_buy_pressed.bind(item, index))
	_update_buy_button_state(buy_button, item)
	bottom_row.add_child(buy_button)

	var lock_button: Button = Button.new()
	var is_locked: bool = index in locked_indices
	lock_button.name = "LockButton%d" % index
	lock_button.text = "L" if is_locked else "-"
	lock_button.custom_minimum_size = Vector2(34, 28)
	lock_button.tooltip_text = "解锁" if is_locked else "锁定"
	lock_button.pressed.connect(_on_lock_pressed.bind(index))
	bottom_row.add_child(lock_button)

	return card

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
	var empty_slots: Array[int] = inventory.find_empty_slots(item.get_slot_count())
	if empty_slots.is_empty():
		button.disabled = true
		button.tooltip_text = "背包空间不足"

func _on_buy_pressed(item: ItemDataClass, index: int) -> void:
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

func _get_max_rarity_for_day(day: int) -> int:
	if day == 1:
		return 1
	if day <= 3:
		return 2
	if day <= 5:
		return 3
	return 4

func _create_random_item(day: int, max_rarity: int) -> ItemDataClass:
	var item: ItemDataClass = ItemDataClass.new()
	item.rarity = randi_range(1, max_rarity)

	match randi() % 4:
		0:
			item.type = ItemDataClass.Type.WEAPON
			item.damage = randi_range(5, 15) * item.rarity
			item.item_name = _get_weapon_name(item.rarity)
		1:
			item.type = ItemDataClass.Type.SHIELD
			item.shield = randi_range(5, 15) * item.rarity
			item.item_name = _get_shield_name(item.rarity)
		2:
			item.type = ItemDataClass.Type.HEAL
			item.heal = randi_range(5, 15) * item.rarity
			item.item_name = _get_heal_name(item.rarity)
		_:
			item.type = ItemDataClass.Type.UTILITY
			item.crit_chance = 0.05 * item.rarity
			item.item_name = _get_utility_name(item.rarity)

	var size_roll: float = randf()
	if size_roll < 0.6:
		item.size = ItemDataClass.Size.SMALL
	elif size_roll < 0.9:
		item.size = ItemDataClass.Size.MEDIUM
	else:
		item.size = ItemDataClass.Size.LARGE

	item.buy_price = _calculate_price(item)
	var cd_range: Dictionary = item.get_size_cd_range()
	item.cooldown = randf_range(float(cd_range["min"]), float(cd_range["max"]))
	item.current_cooldown = 0.0
	return item

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
	match item.type:
		ItemDataClass.Type.WEAPON:
			return "DMG %d  %.1fs" % [item.damage, item.cooldown]
		ItemDataClass.Type.SHIELD:
			return "SHD %d  %.1fs" % [item.shield, item.cooldown]
		ItemDataClass.Type.HEAL:
			return "HEAL %d  %.1fs" % [item.heal, item.cooldown]
		ItemDataClass.Type.UTILITY:
			return "CRIT %.0f%%" % (item.crit_chance * 100.0)
	return ""

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
	style.bg_color = Color(0.12, 0.11, 0.15, 0.92)
	style.border_color = _get_rarity_color(item.rarity)
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.30)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 3)
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
