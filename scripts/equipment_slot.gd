## 装备槽位 UI 组件
class_name EquipmentSlotUI
extends Control

## 槽位类型
@export var slot_type: int = 0  # 0=武器, 1=护甲, 2=饰品, 3=护符

## 槽位名称
@export var slot_name: String = "武器"

## 当前装备的物品
var current_item: Item = null

## 背景
var bg: TextureRect

## 图标
var icon: TextureRect

## 名称标签
var name_label: Label

## 父级装备面板
var equipment_panel: Control

## 初始化
func _ready() -> void:
	_setup_ui()

## 设置 UI
func _setup_ui() -> void:
	custom_minimum_size = Vector2(80, 80)
	
	# 背景
	bg = TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_TILE
	_add_stylebox_bg(bg)
	add_child(bg)
	
	# 图标
	icon = TextureRect.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.expand_mode = TextureRect.EXPAND_FIT_CONTENT
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate.a = 0.3
	icon.mouse_entered.connect(_on_mouse_entered)
	icon.mouse_exited.connect(_on_mouse_exited)
	add_child(icon)
	
	# 名称标签
	name_label = Label.new()
	name_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1.0))
	name_label.text = slot_name
	name_label.position.y = -20
	add_child(name_label)

## 添加背景样式
func _add_stylebox_bg(texture_rect: TextureRect) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2, 0.95)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	
	# 根据槽位类型设置不同颜色
	match slot_type:
		0: style.border_color = Color(0.8, 0.3, 0.3, 1.0)  # 红色 - 武器
		1: style.border_color = Color(0.3, 0.3, 0.8, 1.0)  # 蓝色 - 护甲
		2: style.border_color = Color(0.8, 0.8, 0.3, 1.0)  # 黄色 - 饰品
		3: style.border_color = Color(0.6, 0.3, 0.8, 1.0)  # 紫色 - 护符
	
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	texture_rect.add_theme_stylebox_override("normal", style)

## 设置物品
func set_item(item: Item) -> void:
	current_item = item
	
	if item:
		# 加载图标
		if item.icon_path != "":
			var texture = load(item.icon_path) as Texture2D
			if texture:
				icon.texture = texture
				icon.modulate.a = 1.0
			else:
				icon.modulate.a = 0.3
		else:
			icon.modulate.a = 0.3
	else:
		icon.texture = null
		icon.modulate.a = 0.3

## 鼠标进入
func _on_mouse_entered() -> void:
	# 高亮
	if bg:
		bg.modulate = Color(1.2, 1.2, 1.2, 1.0)

## 鼠标离开
func _on_mouse_exited() -> void:
	bg.modulate = Color(1, 1, 1, 1.0)

## 开始拖拽
func _get_drag_data(_at_position: Vector2) -> Variant:
	if not current_item:
		return null
	
	# 创建拖拽预览
	var preview = TextureRect.new()
	preview.texture = icon.texture
	preview.expand_mode = TextureRect.EXPAND_FIT_CONTENT
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.custom_minimum_size = Vector2(48, 48)
	preview.modulate = Color(1, 1, 1, 0.8)
	
	var center = Control.new()
	center.add_child(preview)
	preview.position = -preview.size / 2
	
	set_drag_preview(center)
	
	return {
		"slot_type": slot_type,
		"item": current_item,
		"from_equipment": true
	}

## 放置拖拽
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not data.has("item"):
		return false
	
	var item = data["item"]
	
	# 检查物品是否可以装备到当前槽位
	match slot_type:
		0: return item is Weapon
		1: return item is Armor
		2, 3: return item is Item  # 暂不限制
	
	return false

## 处理放置
func _drop_data(_at_position: Vector2, data: Variant) -> void:
	# 由父级处理
	pass
