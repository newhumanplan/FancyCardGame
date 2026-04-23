class_name InventoryUI
extends Control

## Inventory UI - 10 槽位线性布局
## 基于 LinearInventory 类

## 预加载类
const LinearInventoryClass = preload("res://scripts/data/linear_inventory.gd")
const ItemDataClass = preload("res://scripts/data/item_data.gd")
const ItemDetailPanelClass = preload("res://scenes/ui/item_detail_panel.tscn")

## 常量
const SLOT_SIZE: int = 108
const TOTAL_SLOTS: int = 10
const SLOT_SPACING: int = 12
const HOVER_DELAY_SEC: float = 0.3
const HOVER_TOOLTIP_OFFSET: Vector2 = Vector2(16, 20)

## Inventory 数据
var inventory: LinearInventoryClass

## 槽位节点数组
var slot_panels: Array[Panel] = []
var item_panels: Array[Control] = []

## 当前拖拽
var dragging_item: ItemDataClass = null
var dragging_panel: Control = null
var drag_start_slot: int = -1
var is_dragging: bool = false
var drag_ghost: Control = null  # 拖拽时的半透明副本

## 槽位高亮
var valid_slot_overlays: Array[Panel] = []  # 有效放置位置高亮
var invalid_slot_overlays: Array[Panel] = []  # 无效位置高亮(红色)
var current_hover_slot: int = -1

## 物品详情面板
var detail_panel: Control = null
var selected_item: ItemDataClass = null
var hover_timer: Timer = null
var hovered_item: ItemDataClass = null
var hover_tooltip: Control = null

## 协同效果高亮
var synergy_highlights: Array[Control] = []  # 协同高亮效果

## 槽位容器
@onready var slot_container: HBoxContainer = $Panel/VBox/SlotContainer

## 物品显示容器层(覆盖在槽位上)
var item_display_layer: Control

## 背景层(用于点击空白处关闭面板)
var background_layer: Control

## 物品图片映射(名称 -> 图片路径)
var item_texture_map: Dictionary = {}

signal item_placed(item: ItemDataClass, slot: int)
signal item_removed(item: ItemDataClass)
signal item_drag_started(item: ItemDataClass)
signal item_drag_ended(item: ItemDataClass)

## 初始化物品图片映射
func _init_item_texture_map() -> void:
	# 武器
	item_texture_map["木剑"] = "res://assets/art/items/item_iron_sword.png"
	item_texture_map["铁剑"] = "res://assets/art/items/item_iron_sword.png"
	item_texture_map["钢剑"] = "res://assets/art/items/item_steel_sword.png"
	item_texture_map["魔法剑"] = "res://assets/art/items/item_great_sword.png"
	item_texture_map["传奇剑"] = "res://assets/art/items/item_great_sword.png"

	item_texture_map["木斧"] = "res://assets/art/items/item_battle_axe.png"
	item_texture_map["铁斧"] = "res://assets/art/items/item_battle_axe.png"
	item_texture_map["钢斧"] = "res://assets/art/items/item_battle_axe.png"
	item_texture_map["魔法斧"] = "res://assets/art/items/item_battle_axe.png"
	item_texture_map["传奇斧"] = "res://assets/art/items/item_battle_axe.png"

	item_texture_map["木弓"] = "res://assets/art/items/item_longbow.png"
	item_texture_map["铁弓"] = "res://assets/art/items/item_longbow.png"
	item_texture_map["钢弓"] = "res://assets/art/items/item_longbow.png"
	item_texture_map["魔法弓"] = "res://assets/art/items/item_longbow.png"
	item_texture_map["传奇弓"] = "res://assets/art/items/item_longbow.png"

	item_texture_map["法杖"] = "res://assets/art/items/item_magic_book.png"
	item_texture_map["魔杖"] = "res://assets/art/items/item_magic_book.png"
	item_texture_map["奥术杖"] = "res://assets/art/items/item_magic_book.png"
	item_texture_map["元素杖"] = "res://assets/art/items/item_magic_book.png"
	item_texture_map["星辉杖"] = "res://assets/art/items/item_magic_book.png"

	# 护盾
	item_texture_map["木盾"] = "res://assets/art/items/item_wooden_shield.png"
	item_texture_map["铁盾"] = "res://assets/art/items/item_iron_shield.png"
	item_texture_map["钢盾"] = "res://assets/art/items/item_tower_shield.png"
	item_texture_map["魔法盾"] = "res://assets/art/items/item_holy_shield.png"
	item_texture_map["传奇盾"] = "res://assets/art/items/item_holy_shield.png"

	# 治疗物品
	item_texture_map["草药"] = "res://assets/art/items/item_regen_potion.png"
	item_texture_map["药水"] = "res://assets/art/items/item_health_potion.png"
	item_texture_map["圣水"] = "res://assets/art/items/item_big_health_potion.png"
	item_texture_map["魔法药剂"] = "res://assets/art/items/item_big_health_potion.png"
	item_texture_map["神级药水"] = "res://assets/art/items/item_big_health_potion.png"

	# 辅助物品
	item_texture_map["幸运符"] = "res://assets/art/items/item_ring_strength.png"
	item_texture_map["力量符"] = "res://assets/art/items/item_ring_strength.png"
	item_texture_map["防御符"] = "res://assets/art/items/item_small_shield.png"
	item_texture_map["魔法符"] = "res://assets/art/items/item_poison.png"
	item_texture_map["传奇符"] = "res://assets/art/items/item_ring_strength.png"

	# 测试物品(InventoryUI 初始物品)
	item_texture_map["铁剑"] = "res://assets/art/items/item_iron_sword.png"
	item_texture_map["盾牌"] = "res://assets/art/items/item_iron_shield.png"
	item_texture_map["大斧"] = "res://assets/art/items/item_battle_axe.png"
	item_texture_map["魔法药水"] = "res://assets/art/items/item_big_health_potion.png"
	item_texture_map["毒匕首"] = "res://assets/art/items/item_dagger.png"

## 获取物品图片路径
func _get_item_texture_path(item: ItemDataClass) -> String:
	if item == null:
		return ""

	# 精确匹配
	if item_texture_map.has(item.item_name):
		return item_texture_map[item.item_name]

	# 模糊匹配 - 根据物品类型
	match item.type:
		ItemDataClass.Type.WEAPON:
			if item.damage >= 30:
				return "res://assets/art/items/item_great_sword.png"
			elif item.damage >= 15:
				return "res://assets/art/items/item_steel_sword.png"
			else:
				return "res://assets/art/items/item_iron_sword.png"
		ItemDataClass.Type.SHIELD:
			if item.shield >= 25:
				return "res://assets/art/items/item_tower_shield.png"
			elif item.shield >= 15:
				return "res://assets/art/items/item_iron_shield.png"
			else:
				return "res://assets/art/items/item_wooden_shield.png"
		ItemDataClass.Type.HEAL:
			if item.heal >= 20:
				return "res://assets/art/items/item_big_health_potion.png"
			elif item.heal >= 10:
				return "res://assets/art/items/item_health_potion.png"
			else:
				return "res://assets/art/items/item_regen_potion.png"
		ItemDataClass.Type.UTILITY:
			return "res://assets/art/items/item_ring_strength.png"

	return ""

func _ready() -> void:
	# 初始化物品图片映射
	_init_item_texture_map()

	# 创建 Inventory 实例
	inventory = LinearInventoryClass.new()

	# 连接信号
	_ensure_inventory_signal_connection()

	# 创建 hover 延迟计时器
	hover_timer = Timer.new()
	hover_timer.name = "HoverTimer"
	hover_timer.one_shot = true
	hover_timer.timeout.connect(_on_hover_timer_timeout)
	add_child(hover_timer)

	# 创建背景层(用于处理点击空白处)
	_create_background_layer()

	# 创建槽位 UI
	_create_slots()

	# 创建物品显示层
	_create_item_display_layer()

	# 创建槽位高亮层
	_create_slot_overlay_layer()

	# 初始刷新协同高亮
	_update_synergy_highlights()

	# 默认显示背包
	visible = true

func _ensure_inventory_signal_connection() -> void:
	if inventory != null and not inventory.inventory_changed.is_connected(_on_inventory_changed):
		inventory.inventory_changed.connect(_on_inventory_changed)

## 创建背景层
func _create_background_layer() -> void:
	background_layer = Control.new()
	background_layer.name = "BackgroundLayer"
	background_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	background_layer.mouse_filter = Control.MOUSE_FILTER_STOP

	# 透明背景但能接收鼠标事件
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.001)  # 几乎透明
	background_layer.add_theme_stylebox_override("panel", style)

	background_layer.gui_input.connect(_on_background_input)
	add_child(background_layer)
	background_layer.move_to_front()

## 创建槽位
func _create_slots() -> void:
	slot_container.add_theme_constant_override("separation", SLOT_SPACING)

	for i in range(TOTAL_SLOTS):
		var slot = _create_slot(i)
		slot_container.add_child(slot)
		slot_panels.append(slot)

## 创建单个槽位
func _create_slot(index: int) -> Panel:
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	panel.name = "Slot_%d" % index

	# 添加背景样式
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2)
	style.border_color = Color(0.35, 0.35, 0.45)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)

	# 添加槽位编号标签
	var label = Label.new()
	label.name = "SlotLabel"
	label.text = str(index + 1)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	label.position = Vector2(0, 4)
	panel.add_child(label)

	# 添加鼠标输入处理
	panel.gui_input.connect(_on_slot_input.bind(index))

	return panel

## 创建物品显示层
func _create_item_display_layer() -> void:
	item_display_layer = Control.new()
	item_display_layer.name = "ItemDisplayLayer"
	item_display_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_display_layer.set_anchors_preset(Control.PRESET_FULL_RECT)

	# 放到 slot_container 的父节点(VBox)中,避免 HBoxContainer 干扰布局
	slot_container.get_parent().add_child(item_display_layer)
	item_display_layer.z_index = 10  # 放在上层

## 创建槽位高亮层
var slot_overlay_layer: Control

func _create_slot_overlay_layer() -> void:
	slot_overlay_layer = Control.new()
	slot_overlay_layer.name = "SlotOverlayLayer"
	slot_overlay_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	slot_overlay_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_display_layer.add_child(slot_overlay_layer)
	slot_overlay_layer.z_index = 5

## 库存变化回调
func _on_inventory_changed() -> void:
	_refresh_display()
	_update_synergy_highlights()

## 刷新物品显示
func _refresh_display() -> void:
	hover_timer.stop()
	hovered_item = null
	_hide_hover_tooltip()

	# 清除所有物品显示
	for child in item_display_layer.get_children():
		if child.name != "SlotOverlayLayer":
			child.queue_free()
	item_panels.clear()

	# 遍历所有物品并显示
	for item in inventory.items:
		if item != null and item.slot_index >= 0:
			_display_item(item)

## 显示物品
func _display_item(item: ItemDataClass, is_synergy_highlight: bool = false) -> void:
	var slot_count: int = item.get_slot_count()
	var start_slot: int = item.slot_index

	if start_slot >= slot_panels.size():
		return

	# 使用槽位的实际全局位置来定位物品
	var first_slot_panel = slot_panels[start_slot]
	var slot_global_pos = first_slot_panel.global_position
	var layer_global_pos = item_display_layer.global_position if is_instance_valid(item_display_layer) else Vector2.ZERO
	var local_pos = slot_global_pos - layer_global_pos

	# 创建物品面板
	var item_panel = Control.new()
	item_panel.name = "Item_%s_%d" % [item.item_name, start_slot]
	item_panel.position = Vector2(local_pos.x + 4, local_pos.y + 4)
	var panel_size = Vector2(
		slot_count * SLOT_SIZE + (slot_count - 1) * SLOT_SPACING - 8,
		SLOT_SIZE - 8
	)
	item_panel.size = panel_size
	item_panel.custom_minimum_size = panel_size

	# 添加背景样式
	var bg = Panel.new()
	bg.size = panel_size
	bg.position = Vector2.ZERO

	var style = StyleBoxFlat.new()
	var item_color = _get_item_color(item)

	if is_synergy_highlight:
		# 协同高亮效果 - 金色发光
		style.bg_color = item_color * 0.5
		style.border_color = Color(1.0, 0.84, 0.0)  # 金色
		style.set_border_width_all(3)
	else:
		style.bg_color = item_color * 0.4
		style.border_color = item_color
		style.set_border_width_all(2)

	style.set_corner_radius_all(4)
	bg.add_theme_stylebox_override("panel", style)
	item_panel.add_child(bg)

	# 尝试加载并显示物品图片
	var texture_path = _get_item_texture_path(item)
	if texture_path != "" and ResourceLoader.exists(texture_path):
		var texture = load(texture_path)
		if texture:
			var texture_rect = TextureRect.new()
			texture_rect.texture = texture
			texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			texture_rect.position = Vector2(4, 4)
			texture_rect.size = Vector2(
				slot_count * SLOT_SIZE + (slot_count - 1) * SLOT_SPACING - 16,
				SLOT_SIZE - 16
			)
			item_panel.add_child(texture_rect)

	# 添加物品名称标签(放在底部)
	var label = Label.new()
	label.name = "ItemName"
	label.text = item.item_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.position = Vector2(0, panel_size.y - 24)
	label.size = Vector2(panel_size.x, 20)
	item_panel.add_child(label)

	# 如果物品有 Cooldown,添加遮罩层(盖在图标上方)
	if item.cooldown > 0:
		var cooldown_overlay = _create_cooldown_overlay(item)
		cooldown_overlay.name = "CooldownOverlay"
		item_panel.add_child(cooldown_overlay)

	# 添加鼠标输入(拖拽)
	item_panel.gui_input.connect(_on_item_input.bind(item, item_panel))

	# 添加鼠标悬停效果
	item_panel.mouse_entered.connect(_on_item_hover.bind(item, item_panel, true))
	item_panel.mouse_exited.connect(_on_item_hover.bind(item, item_panel, false))

	# 存储物品引用以便后续访问
	item_panel.set_meta("item_data", item)

	item_display_layer.add_child(item_panel)
	item_panels.append(item_panel)

## 创建 Cooldown 遮罩(盖在物品图标上,显示冷却进度)
func _create_cooldown_overlay(item: ItemDataClass) -> ColorRect:
	var overlay = ColorRect.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.color = Color(0, 0, 0, 0.5)

	# 添加冷却时间文字
	var timer_label = Label.new()
	timer_label.name = "CooldownTimerLabel"
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size", 15)
	timer_label.add_theme_color_override("font_color", Color.WHITE)
	timer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 居中在遮罩上
	timer_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	overlay.add_child(timer_label)

	_update_cooldown_overlay(overlay, item)

	return overlay

## 更新单个物品的 Cooldown 遮罩
func _update_cooldown_overlay(overlay: ColorRect, item: ItemDataClass) -> void:
	if overlay == null or item == null:
		return

	var timer_label: Label = overlay.get_node_or_null("CooldownTimerLabel") as Label
	if item.current_cooldown <= 0.0 or item.cooldown <= 0.0:
		overlay.visible = false
		if timer_label != null:
			timer_label.text = ""
		return

	var ratio: float = clampf(item.current_cooldown / item.cooldown, 0.0, 1.0)
	overlay.anchor_left = 0.0
	overlay.anchor_top = 1.0 - ratio
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.offset_left = 0
	overlay.offset_top = 0
	overlay.offset_right = 0
	overlay.offset_bottom = 0
	overlay.visible = true

	if timer_label != null:
		timer_label.text = "%.1f" % item.current_cooldown

## 按帧刷新现有物品面板上的 Cooldown 显示
func _update_cooldown_overlays() -> void:
	for item_panel in item_panels:
		if not is_instance_valid(item_panel):
			continue

		var item: ItemDataClass = item_panel.get_meta("item_data", null) as ItemDataClass
		if item == null or item.cooldown <= 0.0:
			continue

		var cooldown_overlay: ColorRect = item_panel.get_node_or_null("CooldownOverlay") as ColorRect
		if cooldown_overlay == null:
			continue

		_update_cooldown_overlay(cooldown_overlay, item)

## 获取物品颜色(基于稀有度)
func _get_item_color(item: ItemDataClass) -> Color:
	match item.rarity:
		1: return Color(0.6, 0.6, 0.6)  # 普通 - 灰色
		2: return Color(0.2, 0.8, 0.2)  # 优秀 - 绿色
		3: return Color(0.2, 0.5, 0.9)  # 精良 - 蓝色
		4: return Color(0.7, 0.4, 0.9)  # 史诗 - 紫色
		5: return Color(1.0, 0.7, 0.2)  # 传说 - 橙色
		_: return Color.WHITE

## 槽位输入处理
func _on_slot_input(event: InputEvent, slot_index: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# 检查该槽位是否有物品可以拖动
				var item = _get_item_at_slot(slot_index)
				if item == null:
					# 尝试放置拖拽中的物品
					_on_slot_clicked_for_place(slot_index)
			else:
				# 释放鼠标
				if is_dragging:
					_end_drag(slot_index)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# 右键点击显示物品详情
			var item = _get_item_at_slot(slot_index)
			if item != null:
				_show_item_detail(item)

## 物品输入处理(拖拽)
func _on_item_input(event: InputEvent, item: ItemDataClass, panel: Control) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_start_drag(item, panel)
		elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_end_drag(item.slot_index)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# 右键点击显示物品详情
			hover_timer.stop()
			_hide_hover_tooltip()
			hovered_item = null
			_show_item_detail(item)

## 物品悬停效果
func _on_item_hover(item: ItemDataClass, panel: Control, hovering: bool) -> void:
	var style = panel.get_child(0).get_theme_stylebox("panel")
	if style != null:
		if hovering:
			style.border_width_left = 3
			style.border_width_right = 3
			style.border_width_top = 3
			style.border_width_bottom = 3
		else:
			style.border_width_left = 2
			style.border_width_right = 2
			style.border_width_top = 2
			style.border_width_bottom = 2

	if hovering:
		hover_timer.stop()
		_hide_hover_tooltip()
		hovered_item = item
		hover_timer.start(HOVER_DELAY_SEC)
	else:
		hover_timer.stop()
		_hide_hover_tooltip()
		hovered_item = null

func _on_hover_timer_timeout() -> void:
	if hovered_item == null or is_dragging:
		return
	_show_hover_tooltip(hovered_item)

func _show_hover_tooltip(item: ItemDataClass) -> void:
	if item == null:
		return

	_hide_hover_tooltip()

	hover_tooltip = ItemDetailPanelClass.instantiate()
	hover_tooltip.name = "HoverTooltip"
	add_child(hover_tooltip)
	hover_tooltip.set_item(item, inventory)
	hover_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_tooltip.move_to_front()
	_position_hover_tooltip()

func _hide_hover_tooltip() -> void:
	if hover_tooltip != null:
		hover_tooltip.queue_free()
		hover_tooltip = null

func _position_hover_tooltip() -> void:
	if hover_tooltip == null:
		return

	var viewport_size: Vector2 = get_viewport_rect().size
	var panel_size: Vector2 = hover_tooltip.custom_minimum_size
	if panel_size == Vector2.ZERO:
		panel_size = hover_tooltip.size

	var mouse_pos: Vector2 = get_global_mouse_position()
	var target_pos: Vector2 = mouse_pos + HOVER_TOOLTIP_OFFSET

	if target_pos.x + panel_size.x > viewport_size.x:
		target_pos.x = mouse_pos.x - panel_size.x - HOVER_TOOLTIP_OFFSET.x
	if target_pos.y + panel_size.y > viewport_size.y:
		target_pos.y = mouse_pos.y - panel_size.y - HOVER_TOOLTIP_OFFSET.y

	target_pos.x = clampf(target_pos.x, 0.0, maxf(viewport_size.x - panel_size.x, 0.0))
	target_pos.y = clampf(target_pos.y, 0.0, maxf(viewport_size.y - panel_size.y, 0.0))
	hover_tooltip.global_position = target_pos

## ========== 拖拽系统增强 ==========

## 开始拖拽
func _start_drag(item: ItemDataClass, panel: Control) -> void:
	hover_timer.stop()
	_hide_hover_tooltip()
	hovered_item = null

	is_dragging = true
	dragging_item = item
	dragging_panel = panel
	drag_start_slot = item.slot_index

	# 隐藏原始面板
	panel.visible = false

	# 创建拖拽中的面板(半透明)
	drag_ghost = panel.duplicate()
	drag_ghost.name = "DragGhost"
	drag_ghost.visible = true
	drag_ghost.modulate.a = 0.8
	item_display_layer.add_child(drag_ghost)

	# 隐藏原始 item_panels 中的对应面板
	for p in item_panels:
		if p.get_meta("item_data") == item:
			p.visible = false
			break

	# 更新槽位高亮
	_update_drag_overlays()

	# 发送信号
	item_drag_started.emit(item)

## 更新拖拽时的槽位高亮
func _update_drag_overlays() -> void:
	# 清除旧的高亮
	_clear_drag_overlays()

	if not is_dragging or dragging_item == null:
		return

	var item_slot_count = dragging_item.get_slot_count()

	# 检查每个槽位
	for slot_idx in range(TOTAL_SLOTS):
		# 跳过原物品占据的槽位
		if slot_idx >= drag_start_slot and slot_idx < drag_start_slot + dragging_item.get_slot_count():
			continue

		var can_place = inventory.can_place_item(dragging_item, slot_idx)
		_create_slot_overlay(slot_idx, can_place, item_slot_count)

## 创建槽位高亮覆盖层
func _create_slot_overlay(slot_idx: int, is_valid: bool, item_slot_count: int) -> void:
	var overlay = Panel.new()
	overlay.name = "SlotOverlay_%d" % slot_idx

	# 计算位置(跨越多个槽位)
	var start_pos = slot_panels[slot_idx].global_position
	var width = item_slot_count * SLOT_SIZE + (item_slot_count - 1) * SLOT_SPACING - 8

	overlay.custom_minimum_size = Vector2(width, SLOT_SIZE - 8)
	overlay.global_position = start_pos + Vector2(4, 4)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 设置样式
	var style = StyleBoxFlat.new()
	if is_valid:
		# 绿色半透明表示可以放置
		style.bg_color = Color(0.2, 0.8, 0.2, 0.3)
		style.border_color = Color(0.2, 0.8, 0.2, 0.8)
	else:
		# 红色半透明表示不能放置
		style.bg_color = Color(0.8, 0.2, 0.2, 0.3)
		style.border_color = Color(0.8, 0.2, 0.2, 0.8)

	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	overlay.add_theme_stylebox_override("panel", style)

	slot_overlay_layer.add_child(overlay)

	if is_valid:
		valid_slot_overlays.append(overlay)
	else:
		invalid_slot_overlays.append(overlay)

## 清除拖拽高亮
func _clear_drag_overlays() -> void:
	for overlay in valid_slot_overlays:
		if is_instance_valid(overlay):
			overlay.queue_free()
	for overlay in invalid_slot_overlays:
		if is_instance_valid(overlay):
			overlay.queue_free()
	valid_slot_overlays.clear()
	invalid_slot_overlays.clear()

## 结束拖拽
func _end_drag(target_slot: int) -> void:
	if not is_dragging or dragging_item == null:
		return
	var emitted_item: ItemDataClass = dragging_item
	var source_slot: int = drag_start_slot

	# 清除高亮
	_clear_drag_overlays()

	# 移除拖拽面板
	if drag_ghost != null:
		drag_ghost.queue_free()
		drag_ghost = null

	# 重置拖拽状态
	is_dragging = false
	dragging_item = null
	dragging_panel = null
	drag_start_slot = -1

	# 检查目标槽位情况
	var target_item: ItemDataClass = inventory._get_item_at_slot(target_slot)
	var final_slot: int = target_slot

	if target_item != null and source_slot != target_slot:
		# 目标槽位有物品 → 交换
		# 检查交换后两边槽位是否都合法
		var source_size: int = emitted_item.get_slot_count()
		var target_size: int = target_item.get_slot_count()

		# 粗略检查：两边起始位置不同且目标物品能放入源位置
		if target_item.get_slot_count() <= emitted_item.get_slot_count():
			# 目标物品更小/相等，可以交换
			inventory.swap_items(source_slot, target_slot)
			_ani_swap_items(emitted_item, target_item, source_slot, target_slot)
		else:
			# 放回原位（目标物品更大放不下）
			_ani_return_to_source(emitted_item)
	elif target_slot == source_slot:
		# 放回同槽位，刷新显示
		_refresh_display()
		item_drag_ended.emit(emitted_item)
	else:
		# 目标槽位空，放置物品
		inventory.remove_item(emitted_item)
		if inventory.can_place_item(emitted_item, target_slot):
			inventory.place_item(emitted_item, target_slot)
			final_slot = target_slot
			item_placed.emit(emitted_item, final_slot)
		else:
			# 放回原位
			inventory.place_item(emitted_item, source_slot)
			final_slot = source_slot
		_ani_place_item(emitted_item, final_slot)

	item_drag_ended.emit(emitted_item)

## 交换动画
func _ani_swap_items(item_a: ItemDataClass, item_b: ItemDataClass, slot_a: int, slot_b: int) -> void:
	_refresh_display()
	# 找到两个物品的面板
	for panel in item_panels:
		var panel_item: ItemDataClass = panel.get_meta("item_data")
		if panel_item == item_a:
			_animate_panel_swap(panel, slot_a, slot_b)
		elif panel_item == item_b:
			_animate_panel_swap(panel, slot_b, slot_a)

func _animate_panel_swap(panel: Control, from_slot: int, to_slot: int) -> void:
	if from_slot < 0 or from_slot >= slot_panels.size() or to_slot < 0 or to_slot >= slot_panels.size():
		return
	var target_pos: Vector2 = slot_panels[to_slot].global_position - item_display_layer.global_position + Vector2(4, 4)
	var tween: Tween = create_tween()
	tween.tween_property(panel, "position", target_pos, 0.2).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate:a", 0.0, 0.05)
	tween.tween_property(panel, "modulate:a", 1.0, 0.05)

## 放回原位动画
func _ani_return_to_source(item: ItemDataClass) -> void:
	_refresh_display()

## 放置物品动画
func _ani_place_item(item: ItemDataClass, slot: int) -> void:
	_refresh_display()
	# 入槽动画：scale 从 1.2 缩回 1.0
	await get_tree().process_frame
	for panel in item_panels:
		var panel_item: ItemDataClass = panel.get_meta("item_data")
		if panel_item == item:
			panel.modulate.a = 0.0
			var tween: Tween = create_tween()
			tween.tween_property(panel, "modulate:a", 1.0, 0.15)
			tween.parallel().tween_property(panel, "scale", Vector2(1.1, 1.1), 0.05)
			tween.parallel().tween_property(panel, "scale", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_OUT)
		break

## 槽位点击放置
func _on_slot_clicked_for_place(slot_index: int) -> void:
	# 这个方法可以用于从商店拖入物品到背包
	pass

## ========== 物品详情面板 ==========

## 显示物品详情
func _show_item_detail(item: ItemDataClass) -> void:
	# 关闭已有面板
	_close_detail_panel()

	selected_item = item

	# 尝试加载场景
	if ItemDetailPanelClass:
		detail_panel = ItemDetailPanelClass.instantiate()
		detail_panel.name = "ItemDetailPanel"

		# 连接关闭信号
		if detail_panel.has_signal("close_requested"):
			detail_panel.close_requested.connect(_close_detail_panel)

		add_child(detail_panel)
		detail_panel.move_to_front()
		detail_panel.set_item(item, inventory)

		# 定位到物品附近
		_position_detail_panel(item)
	else:
		# 如果场景不存在,创建一个简单的内联面板
		_create_inline_detail_panel(item)

## 创建内联详情面板(如果场景不存在)
func _create_inline_detail_panel(item: ItemDataClass) -> void:
	detail_panel = Panel.new()
	detail_panel.name = "ItemDetailPanel"
	detail_panel.custom_minimum_size = Vector2(300, 270)

	# 添加样式
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style.border_color = _get_item_color(item)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	detail_panel.add_theme_stylebox_override("panel", style)

	# 标题
	var title = Label.new()
	title.text = item.item_name
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", _get_item_color(item))
	title.position = Vector2(15, 15)
	detail_panel.add_child(title)

	# 稀有度
	var rarity_label = Label.new()
	rarity_label.text = "稀有度: %s" % item.get_rarity_name()
	rarity_label.add_theme_font_size_override("font_size", 18)
	rarity_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	rarity_label.position = Vector2(15, 52)
	detail_panel.add_child(rarity_label)

	# 尺寸
	var size_label = Label.new()
	size_label.text = "尺寸: %s (%d槽位)" % [item.get_size_text(), item.get_slot_count()]
	size_label.add_theme_font_size_override("font_size", 18)
	size_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	size_label.position = Vector2(15, 82)
	detail_panel.add_child(size_label)

	# 属性
	var y_offset = 120
	if item.damage > 0:
		var dmg = Label.new()
		dmg.text = "攻击: %d" % item.damage
		dmg.add_theme_font_size_override("font_size", 18)
		dmg.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
		dmg.position = Vector2(15, y_offset)
		detail_panel.add_child(dmg)
		y_offset += 30

	if item.shield > 0:
		var shield = Label.new()
		shield.text = "防御: %d" % item.shield
		shield.add_theme_font_size_override("font_size", 18)
		shield.add_theme_color_override("font_color", Color(0.4, 0.6, 1))
		shield.position = Vector2(15, y_offset)
		detail_panel.add_child(shield)
		y_offset += 30

	if item.heal > 0:
		var heal = Label.new()
		heal.text = "治疗: %d" % item.heal
		heal.add_theme_font_size_override("font_size", 18)
		heal.add_theme_color_override("font_color", Color(0.4, 1, 0.4))
		heal.position = Vector2(15, y_offset)
		detail_panel.add_child(heal)
		y_offset += 30

	# 特殊效果
	if item.has_special_effect():
		y_offset += 8
		var effect_label = Label.new()
		effect_label.text = "特殊效果:"
		effect_label.add_theme_font_size_override("font_size", 16)
		effect_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
		effect_label.position = Vector2(15, y_offset)
		detail_panel.add_child(effect_label)
		y_offset += 27

		var effect_desc = Label.new()
		effect_desc.text = item.get_special_effect_description()
		effect_desc.add_theme_font_size_override("font_size", 16)
		effect_desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		effect_desc.position = Vector2(15, y_offset)
		detail_panel.add_child(effect_desc)
		y_offset += 30

	# 协同加成显示
	var synergy = inventory.get_item_synergy_bonus(item)
	if synergy["damage"] > 0 or synergy["defense"] > 0 or synergy["heal"] > 0:
		y_offset += 8
		var synergy_label = Label.new()
		synergy_label.text = "协同加成:"
		synergy_label.add_theme_font_size_override("font_size", 16)
		synergy_label.add_theme_color_override("font_color", Color(1, 0.84, 0))
		synergy_label.position = Vector2(15, y_offset)
		detail_panel.add_child(synergy_label)
		y_offset += 27

		var bonus_text = ""
		if synergy["damage"] > 0:
			bonus_text += "伤害+%d " % synergy["damage"]
		if synergy["defense"] > 0:
			bonus_text += "防御+%d " % synergy["defense"]
		if synergy["heal"] > 0:
			bonus_text += "治疗+%d " % synergy["heal"]

		var bonus_label = Label.new()
		bonus_label.text = bonus_text
		bonus_label.add_theme_font_size_override("font_size", 16)
		bonus_label.add_theme_color_override("font_color", Color(1, 0.84, 0))
		bonus_label.position = Vector2(15, y_offset)
		detail_panel.add_child(bonus_label)

	add_child(detail_panel)
	detail_panel.move_to_front()

	# 出售按钮
	var sell_price: int = _calculate_sell_price(item)
	var sell_btn = Button.new()
	sell_btn.text = "出售 (%d金币)" % sell_price
	sell_btn.custom_minimum_size = Vector2(130, 36)
	sell_btn.position = Vector2(15, 230)
	var sell_style = StyleBoxFlat.new()
	sell_style.bg_color = Color(0.2, 0.4, 0.2, 0.9)
	sell_style.set_corner_radius_all(6)
	sell_btn.add_theme_stylebox_override("normal", sell_style)
	sell_btn.add_theme_font_size_override("font_size", 18)
	sell_btn.pressed.connect(_on_sell_pressed.bind(item, sell_price))
	detail_panel.add_child(sell_btn)

	# 定位
	_position_detail_panel(item)

## 定位详情面板
func _position_detail_panel(item: ItemDataClass) -> void:
	if detail_panel == null:
		return

	var item_pos = slot_panels[item.slot_index].global_position
	var panel_size = detail_panel.custom_minimum_size

	# 计算位置(避免超出屏幕)
	var target_pos = item_pos + Vector2(SLOT_SIZE + 15, 0)

	# 如果右侧空间不足,放到左边
	if target_pos.x + panel_size.x > get_viewport_rect().size.x:
		target_pos = item_pos - Vector2(panel_size.x + 15, 0)

	# 如果下方空间不足,放到上面
	if target_pos.y + panel_size.y > get_viewport_rect().size.y:
		target_pos.y = item_pos.y - panel_size.y

	detail_panel.global_position = target_pos

## 计算出售价格(购买价的 60%)
func _calculate_sell_price(item: ItemDataClass) -> int:
	if item == null or item.buy_price <= 0:
		return 0
	return maxi(int(float(item.buy_price) * 0.6), 1)

## 出售物品
func _on_sell_pressed(item: ItemDataClass, sell_price: int) -> void:
	if item == null or inventory == null:
		return
	var slot_idx = item.slot_index
	inventory.remove_item(item)
	GameManager.add_gold(sell_price)
	_close_detail_panel()
	_refresh_display()
	print("出售 %s 获得 %d 金币" % [item.item_name, sell_price])

## 关闭详情面板
func _close_detail_panel() -> void:
	if detail_panel != null:
		detail_panel.queue_free()
		detail_panel = null
	selected_item = null

## 背景输入处理(点击空白处关闭面板)
func _on_background_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_close_detail_panel()

## ========== 协同效果高亮 ==========

## 更新协同高亮
func _update_synergy_highlights() -> void:
	# 清除旧的协同高亮
	for highlight in synergy_highlights:
		if is_instance_valid(highlight):
			highlight.queue_free()
	synergy_highlights.clear()

	# 检查每个物品的相邻物品
	for item in inventory.items:
		if item == null:
			continue

		var adjacent = inventory.get_adjacent_items(item)
		for adj_item in adjacent:
			if adj_item == null:
				continue

			# 检查是否是同类型
			if item.type == adj_item.type:
				# 添加协同高亮效果
				_add_synergy_effect(item, adj_item)

## 添加协同效果显示
func _add_synergy_effect(item1: ItemDataClass, item2: ItemDataClass) -> void:
	# 在两个物品之间添加连线效果
	var start_slot = item1.slot_index + item1.get_slot_count() - 1
	var end_slot = item2.slot_index

	# 创建连接线面板
	var connector = Panel.new()
	connector.name = "SynergyConnector"
	connector.custom_minimum_size = Vector2(abs(end_slot - start_slot) * (SLOT_SIZE + SLOT_SPACING), 4)
	connector.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 计算位置
	var start_pos = slot_panels[start_slot].global_position
	var end_pos = slot_panels[end_slot].global_position
	connector.global_position = Vector2(
		min(start_pos.x, end_pos.x) + SLOT_SIZE / 2,
		start_pos.y + SLOT_SIZE / 2 - 2
	)

	# 金色半透明样式
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.84, 0.0, 0.6)
	style.set_corner_radius_all(2)
	connector.add_theme_stylebox_override("panel", style)

	item_display_layer.add_child(connector)
	synergy_highlights.append(connector)

## 获取指定槽位的物品
func _get_item_at_slot(slot_index: int) -> ItemDataClass:
	return null if inventory == null else inventory.get_item_at(slot_index)

## 添加测试物品
func _add_test_items() -> void:
	# 创建一个 Small 物品 (1 槽位) - 武器
	var item1 = ItemDataClass.new()
	item1.item_name = "铁剑"
	item1.size = ItemDataClass.Size.SMALL
	item1.type = ItemDataClass.Type.WEAPON
	item1.damage = 15
	item1.rarity = 1  # 普通
	item1.cooldown = 3.0
	item1.current_cooldown = 0.0

	# 创建一个 Medium 物品 (2 槽位) - 护盾
	var item2 = ItemDataClass.new()
	item2.item_name = "盾牌"
	item2.size = ItemDataClass.Size.MEDIUM
	item2.type = ItemDataClass.Type.SHIELD
	item2.shield = 20
	item2.rarity = 2  # 优秀
	item2.cooldown = 5.0
	item2.current_cooldown = 2.0

	# 创建一个 Large 物品 (3 槽位) - 武器
	var item3 = ItemDataClass.new()
	item3.item_name = "大斧"
	item3.size = ItemDataClass.Size.LARGE
	item3.type = ItemDataClass.Type.WEAPON
	item3.damage = 35
	item3.rarity = 3  # 稀有
	item3.cooldown = 8.0
	item3.current_cooldown = 0.0

	# 创建一个治疗物品 (带特殊效果)
	var item4 = ItemDataClass.new()
	item4.item_name = "魔法药水"
	item4.size = ItemDataClass.Size.SMALL
	item4.type = ItemDataClass.Type.HEAL
	item4.heal = 25
	item4.rarity = 2
	item4.cooldown = 4.0
	item4.current_cooldown = 0.0
	item4.regeneration = 5.0  # 持续治疗

	# 创建一个有毒武器
	var item5 = ItemDataClass.new()
	item5.item_name = "毒匕首"
	item5.size = ItemDataClass.Size.SMALL
	item5.type = ItemDataClass.Type.WEAPON
	item5.damage = 12
	item5.rarity = 2
	item5.cooldown = 2.5
	item5.current_cooldown = 0.0
	item5.poison_damage = 3.0  # 中毒效果

	# 放置物品
	inventory.place_item(item1, 0)  # 铁剑
	inventory.place_item(item2, 2)  # 盾牌
	inventory.place_item(item3, 5)  # 大斧
	inventory.place_item(item4, 9)  # 魔法药水(最右边)
	inventory.place_item(item5, 8)  # 毒匕首(紧邻药水)

## 更新 Cooldown 显示(每帧调用)
## 注意:冷却倒计时由 battle_system.update_cooldowns() 统一管理
## 这里只负责刷新显示,不修改 cooldown 数据
func _process(delta: float) -> void:
	# 只在战斗中刷新冷却显示
	var battle_ui_node = get_parent().get_node_or_null("BattleUI")
	if battle_ui_node and not battle_ui_node.is_battle_active:
		return
	_update_cooldown_overlays()

## 获取库存实例(供外部使用)
func get_inventory() -> LinearInventoryClass:
	_ensure_inventory_signal_connection()
	return inventory

## 获取选中的物品
func get_selected_item() -> ItemDataClass:
	return selected_item
