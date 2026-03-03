## 背包格子组件
class_name InventorySlot
extends Control

## 格子索引
var slot_index: int = -1

## 当前物品
var current_item

## 背景
var bg: TextureRect

## 图标
var icon: TextureRect

## 稀有度边框
var rarity_border: ColorRect

## 数量标签
var count_label: Label

## 是否可拖拽
var draggable: bool = true

## 父级背包 UI
var backpack_ui:
	get:
		var parent = get_parent()
		while parent:
			if parent has "BackpackUI":
				return parent
			parent = parent.get_parent()
		return null

## 初始化
func _ready() -> void:
	_setup_ui()

## 设置 UI
func _setup_ui() -> void:
	custom_minimum_size = Vector2(64, 64)
	
	# 背景
	bg = TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_TILE
	_add_stylebox_bg(bg)
	add_child(bg)
	
	# 稀有度边框
	rarity_border = ColorRect.new()
	rarity_border.set_anchors_preset(Control.PRESET_FULL_RECT)
	rarity_border.color = Color(0, 0, 0, 0)
	add_child(rarity_border)
	
	# 图标
	icon = TextureRect.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate.a = 0  # 初始隐藏
	icon.mouse_entered.connect(_on_mouse_entered)
	icon.mouse_exited.connect(_on_mouse_exited)
	add_child(icon)
	
	# 数量标签
	count_label = Label.new()
	count_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	count_label.add_theme_font_size_override("font_size", 12)
	count_label.add_theme_color_override("font_color", Color.WHITE)
	count_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	count_label.add_theme_constant_override("shadow_offset_x", 1)
	count_label.add_theme_constant_override("shadow_offset_y", 1)
	count_label.visible = false
	add_child(count_label)

## 添加背景样式
func _add_stylebox_bg(texture_rect: TextureRect) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.25, 0.9)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.4, 0.4, 0.5, 1.0)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	texture_rect.add_theme_stylebox_override("normal", style)

## 设置物品
func set_item(item) -> void:
	current_item = item
	
	if item:
		# 加载图标
		if item.icon_path != "" and icon:
			var texture = load(item.icon_path) as Texture2D
			if texture:
				icon.texture = texture
				icon.modulate.a = 1.0
			else:
				icon.modulate.a = 0.0
		elif icon:
			icon.modulate.a = 0.0
		
		# 设置稀有度边框颜色
		if rarity_border:
			rarity_border.color = item.get_rarity_color()
			rarity_border.color.a = 0.8
		
		# 显示数量（如果是消耗品且有多个）
		if item is Consumable and item.uses_remaining > 1:
			if count_label:
				count_label.text = str(item.uses_remaining)
				count_label.visible = true
		elif count_label:
			count_label.visible = false
	else:
		# 清空
		if icon:
			icon.texture = null
			icon.modulate.a = 0.0
		if rarity_border:
			rarity_border.color = Color(0, 0, 0, 0)
		if count_label:
			count_label.visible = false

## 鼠标进入
func _on_mouse_entered() -> void:
	if current_item and backpack_ui:
		var global_pos = get_global_mouse_position()
		backpack_ui.show_tooltip(current_item, global_pos)

## 鼠标离开
func _on_mouse_exited() -> void:
	if backpack_ui:
		backpack_ui.hide_tooltip()

## 开始拖拽
func _get_drag_data(_at_position: Vector2) -> Variant:
	if not current_item or not draggable:
		return null
	
	# 创建拖拽预览
	var preview = TextureRect.new()
	preview.texture = icon.texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.custom_minimum_size = Vector2(48, 48)
	preview.modulate = Color(1, 1, 1, 0.8)
	
	# 设置居中
	var center = Control.new()
	center.add_child(preview)
	preview.position = -preview.size / 2
	
	set_drag_preview(center)
	
	return {
		"slot_index": slot_index,
		"item": current_item
	}

## 放置拖拽
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	# 来自背包格子
	if data.has("slot_index") and data.has("item"):
		return true
	# 来自装备槽
	if data.has("from_equipment") and data["from_equipment"]:
		return true
	return false

## 处理放置
func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not backpack_ui or not backpack_ui.inventory:
		return
	
	# 来自背包格子 - 交换
	if data.has("slot_index"):
		var from_slot = data["slot_index"]
		var to_slot = slot_index
		backpack_ui.inventory.swap_items(from_slot, to_slot)
	# 来自装备槽 - 卸下到背包
	elif data.has("from_equipment") and data["from_equipment"]:
		var item = data.get("item")
		var from_type = data.get("slot_type", -1)
		
		# 通过 character_panel 处理卸下
		var char_panel = backpack_ui.find_parent("CharacterPanelUI")
		if char_panel and char_panel.handle_inventory_drop(from_type, item):
			# 刷新背包
			backpack_ui.refresh()
