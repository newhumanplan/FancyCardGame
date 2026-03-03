extends Control

## 背包 UI - 6x6 网格显示

## 预加载类
const BackpackGridClass = preload("res://scripts/backpack_grid.gd")
const ItemClass = preload("res://resources/item.gd")

const CELL_SIZE: int = 64
const GRID_WIDTH: int = 6
const GRID_HEIGHT: int = 6

## 背包数据
var backpack

## 格子节点容器
var cells: Array = []

## 当前拖拽的物品
var dragging_item = null
var drag_offset: Vector2 = Vector2.ZERO

## 格子容器
@onready var grid_container: GridContainer = $Panel/VBox/GridContainer

func _ready() -> void:
	backpack = BackpackGridClass.new()
	_create_grid()
	_connect_signals()

## 创建网格
func _create_grid() -> void:
	grid_container.columns = GRID_WIDTH
	
	for y in range(GRID_HEIGHT):
		var row: Array = []
		for x in range(GRID_WIDTH):
			var cell = _create_cell(x, y)
			grid_container.add_child(cell)
			row.append(cell)
		cells.append(row)

## 创建单个格子
func _create_cell(x: int, y: int) -> Panel:
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
	panel.name = "Cell_%d_%d" % [x, y]
	
	# 添加背景色
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.3)
	style.border_color = Color(0.4, 0.4, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	
	return panel

## 连接信号
func _connect_signals() -> void:
	backpack.backpack_changed.connect(_on_backpack_changed)

## 背包变化时刷新显示
func _on_backpack_changed() -> void:
	_refresh_display()

## 刷新显示
func _refresh_display() -> void:
	# 清除所有格子上的物品显示
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var cell = cells[y][x]
			for child in cell.get_children():
				child.queue_free()
	
	# 显示所有物品
	for item in backpack.get_all_items():
		_display_item(item)

## 显示物品
func _display_item(item) -> void:
	var cell = cells[item.grid_position.y][item.grid_position.x]
	
	# 创建物品面板
	var item_panel = Panel.new()
	item_panel.custom_minimum_size = Vector2(
		CELL_SIZE * item.size.x - 4,
		CELL_SIZE * item.size.y - 4
	)
	item_panel.position = Vector2(2, 2)
	
	# 设置颜色（根据稀有度）
	var style = StyleBoxFlat.new()
	style.bg_color = item.get_rarity_color() * 0.3
	style.border_color = item.get_rarity_color()
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	item_panel.add_theme_stylebox_override("panel", style)
	
	# 添加物品名称
	var label = Label.new()
	label.text = item.item_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	item_panel.add_child(label)
	
	cell.add_child(item_panel)

## 鼠标点击处理
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_cell_clicked(event.position)

## 格子点击处理
func _on_cell_clicked(global_pos: Vector2) -> void:
	var grid_pos = _get_grid_position(global_pos)
	if grid_pos.x < 0:
		return
	
	var item = backpack.get_item_at(grid_pos)
	if item:
		# 开始拖拽
		print("开始拖拽: %s" % item.item_name)

## 获取格子位置
func _get_grid_position(global_pos: Vector2) -> Vector2i:
	var local_pos = grid_container.get_local_mouse_position()
	var x = int(local_pos.x / CELL_SIZE)
	var y = int(local_pos.y / CELL_SIZE)
	
	if x >= 0 and x < GRID_WIDTH and y >= 0 and y < GRID_HEIGHT:
		return Vector2i(x, y)
	return Vector2i(-1, -1)

## 添加测试物品
func add_test_items() -> void:
	# 创建一个 1x1 的物品
	var item1 = ItemClass.new()
	item1.item_name = "铁剑"
	item1.item_type = 0  # WEAPON
	item1.size = Vector2i(1, 1)
	item1.attack = 5
	item1.rarity = 1
	
	# 创建一个 2x1 的物品
	var item2 = ItemClass.new()
	item2.item_name = "长剑"
	item2.item_type = 0  # WEAPON
	item2.size = Vector2i(2, 1)
	item2.attack = 10
	item2.rarity = 2
	
	# 创建一个 1x2 的物品
	var item3 = ItemClass.new()
	item3.item_name = "盾牌"
	item3.item_type = 1  # ARMOR
	item3.size = Vector2i(1, 2)
	item3.defense = 8
	item3.rarity = 2
	
	# 放置物品
	backpack.place_item(item1, Vector2i(0, 0))
	backpack.place_item(item2, Vector2i(2, 0))
	backpack.place_item(item3, Vector2i(5, 0))
