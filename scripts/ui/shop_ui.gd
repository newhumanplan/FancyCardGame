class_name ShopUI
extends Control

## 商店 UI 控制器
## 核心功能：
## 1. 显示可购买物品
## 2. 购买逻辑（金币检查、扣除、添加到背包）

## 预加载
const EconomyManagerClass = preload("res://scripts/data/economy_manager.gd")
const ItemDataClass = preload("res://scripts/data/item_data.gd")
const LinearInventoryClass = preload("res://scripts/data/linear_inventory.gd")

## Bazaar风格 UI 资源
const SHOP_CARD_BG: String = "res://assets/art/ui/ui_shop_card_bg.png"
const EVENT_CARD_BG: String = "res://assets/art/ui/ui_event_card_bg.png"

## UI 节点
@onready var panel: PanelContainer = $Panel
@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var shop_items_container: HBoxContainer = $Panel/VBox/ShopItemsContainer
@onready var close_button: Button = $Panel/VBox/BottomBar/CloseBtn
@onready var refresh_button: Button = $Panel/VBox/BottomBar/RefreshBtn

## 商店物品列表
var shop_items: Array[ItemData] = []

## 玩家金币（引用 GameManager）
var player_gold: int = 0

## 背包实例（引用 InventoryUI）
var inventory: LinearInventory = null

## 刷新/锁定机制
var free_refresh_used: bool = false  ## 今日免费刷新已使用
var locked_indices: Array[int] = []  ## 锁定的槽位索引
const REFRESH_COST: int = 2  ## 刷新费用（金币）

## 信号
signal shop_closed()
signal item_purchased(item: ItemData)

## 回调函数引用
var on_shop_closed_callback: Callable = Callable()

## 稀有度名称映射（4 级稀有度：普通/稀有/史诗/传说）
const RARITY_NAMES: Array[String] = ["普通", "稀有", "史诗", "传说"]

func _ready() -> void:
	# 连接关闭按钮
	close_button.pressed.connect(_on_close_pressed)
	# 连接刷新按钮
	refresh_button.pressed.connect(_on_refresh_pressed.bind(refresh_button))

	# 初始隐藏
	visible = false

## 显示商店
func show_shop(inventory_ref: LinearInventory) -> void:
	print("[DEBUG] show_shop() called!")
	print("  inventory_ref: " + str(inventory_ref))
	inventory = inventory_ref
	player_gold = GameManager.gold

	# 生成商店物品
	_generate_shop_items()
	free_refresh_used = false
	locked_indices.clear()
	print("  shop_items generated: " + str(shop_items.size()))

	# 更新 UI
	_refresh_shop_items()

	# 显示
	visible = true
	print("[DEBUG] ShopUI visible = " + str(visible))
	print("商店已打开")

## 隐藏商店
func hide_shop() -> void:
	visible = false
	shop_closed.emit()
	print("商店已关闭")

## 生成商店物品（根据当前 Day）
func _generate_shop_items() -> void:
	shop_items.clear()

	# 根据 Day 确定稀有度概率
	var day = GameManager.current_day
	var max_rarity = _get_max_rarity_for_day(day)

	# 生成 3-6 个物品
	var item_count = randi_range(3, 6)

	for i in range(item_count):
		var item = _create_random_item(day, max_rarity)
		shop_items.append(item)

	print("生成了 %d 个商店物品" % shop_items.size())

## 根据 Day 获取最大稀有度（1-4: 普通/稀有/史诗/传说）
func _get_max_rarity_for_day(day: int) -> int:
	if day == 1:
		return 1  # 普通
	elif day <= 3:
		return 2  # 稀有
	elif day <= 5:
		return 3  # 史诗
	else:
		return 4  # 传说

## 创建随机物品
func _create_random_item(day: int, max_rarity: int) -> ItemData:
	var item = ItemDataClass.new()

	# 随机稀有度（1 到 max_rarity）
	var rarity = randi_range(1, max_rarity)
	item.rarity = rarity

	# 随机类型
	var item_type = randi() % 4
	match item_type:
		0:
			item.type = ItemDataClass.Type.WEAPON
			item.damage = randi_range(5, 15) * rarity
			item.item_name = _get_weapon_name(rarity)
		1:
			item.type = ItemDataClass.Type.SHIELD
			item.shield = randi_range(5, 15) * rarity
			item.item_name = _get_shield_name(rarity)
		2:
			item.type = ItemDataClass.Type.HEAL
			item.heal = randi_range(5, 15) * rarity
			item.item_name = _get_heal_name(rarity)
		3:
			item.type = ItemDataClass.Type.UTILITY
			item.crit_chance = 0.05 * rarity
			item.item_name = _get_utility_name(rarity)

	# 随机尺寸
	var size_roll = randf()
	if size_roll < 0.6:
		item.size = ItemDataClass.Size.SMALL
	elif size_roll < 0.9:
		item.size = ItemDataClass.Size.MEDIUM
	else:
		item.size = ItemDataClass.Size.LARGE

	# 设置价格（基于稀有度和尺寸）
	item.buy_price = _calculate_price(item)

	# 冷却时间（按尺寸分级: Small 2-3s, Medium 3-5s, Large 5-8s）
	var cd_range = item.get_size_cd_range()
	item.cooldown = randf_range(cd_range["min"], cd_range["max"])
	item.current_cooldown = 0.0

	return item

## 获取武器名称（4 级稀有度）
func _get_weapon_name(rarity: int) -> String:
	var names = [
		["木剑", "钢剑", "魔法剑", "传奇剑"],
		["木斧", "钢斧", "魔法斧", "传奇斧"],
		["木弓", "钢弓", "魔法弓", "传奇弓"],
		["法杖", "魔杖", "元素杖", "星辉杖"]
	]
	var type_idx = randi() % names.size()
	return names[type_idx][rarity - 1]

## 获取护盾名称（4 级稀有度）
func _get_shield_name(rarity: int) -> String:
	var names = ["木盾", "铁盾", "魔法盾", "传奇盾"]
	return names[rarity - 1]

## 获取治疗物品名称（4 级稀有度）
func _get_heal_name(rarity: int) -> String:
	var names = ["草药", "药水", "圣水", "神级药水"]
	return names[rarity - 1]

## 获取辅助物品名称（4 级稀有度）
func _get_utility_name(rarity: int) -> String:
	var names = ["幸运符", "力量符", "魔法符", "传奇符"]
	return names[rarity - 1]

## 计算价格（委托 EconomyManager：基础→尺寸→类型→天数通胀→声望折扣）
func _calculate_price(item: ItemData) -> int:
	var base_price: int = EconomyManagerClass.calculate_item_price(
		item.rarity, item.size as int, item.type as int, GameManager.current_day
	)
	return EconomyManagerClass.apply_prestige_discount(
		base_price, GameManager.prestige, GameManager.max_prestige
	)

## 刷新商店物品显示
func _refresh_shop_items() -> void:
	# 清除现有物品显示
	for child in shop_items_container.get_children():
		child.queue_free()

	# 顶部间距
	var top_spacer = Control.new()
	top_spacer.custom_minimum_size = Vector2(0, 8)
	shop_items_container.add_child(top_spacer)

	# 创建每个物品的显示（水平排列，最多5张）
	for i in range(min(shop_items.size(), 5)):
		if i > 0:
			var spacer = Control.new()
			spacer.custom_minimum_size = Vector2(16, 0)
			shop_items_container.add_child(spacer)
		var item_display = _create_item_display(shop_items[i], i)
		shop_items_container.add_child(item_display)

	# 底部间距
	var bottom_spacer = Control.new()
	bottom_spacer.custom_minimum_size = Vector2(0, 8)
	shop_items_container.add_child(bottom_spacer)

	# 刷新按钮已直接在 tscn 中，无需动态创建

## 创建物品显示面板（返回带背景的Panel卡片）
func _create_item_display(item: ItemData, idx: int) -> Control:
	# 外层Panel作为卡片背景（固定尺寸）
	var card_panel = Panel.new()
	card_panel.custom_minimum_size = Vector2(180, 220)
	card_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	# 卡片样式
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.15, 0.15, 0.25, 0.95)
	card_style.set_border_width_all(1)
	card_style.border_color = Color(0.4, 0.4, 0.6, 0.8)
	card_style.set_corner_radius_all(6)
	card_panel.add_theme_stylebox_override("panel", card_style)
	
	# 内层VBox排列内容（固定尺寸，不受父容器拉伸影响）
	var container = VBoxContainer.new()
	container.name = "ItemVBox"
	container.add_theme_constant_override("separation", 4)
	container.custom_minimum_size = Vector2(140, 180)
	card_panel.add_child(container)

	# 尝试加载物品图片
	var texture_path = _get_shop_item_texture_path(item)
	if texture_path != "" and ResourceLoader.exists(texture_path):
		var texture = load(texture_path)
		if texture:
			var texture_rect = TextureRect.new()
			texture_rect.texture = texture
			texture_rect.custom_minimum_size = Vector2(96, 96)
			texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			container.add_child(texture_rect)

	# 物品信息
	var info_vbox = VBoxContainer.new()

	# 名称和稀有度
	var name_label = Label.new()
	var rarity_index: int = clampi(item.rarity - 1, 0, RARITY_NAMES.size() - 1)
	name_label.text = "%s [%s]" % [item.item_name, RARITY_NAMES[rarity_index]]
	name_label.add_theme_color_override("font_color", _get_rarity_color(item.rarity))
	info_vbox.add_child(name_label)

	# 属性
	var stats_label = Label.new()
	var stats_text = ""
	match item.type:
		ItemDataClass.Type.WEAPON:
			stats_text = "伤害: %d | 冷却: %.1fs" % [item.damage, item.cooldown]
		ItemDataClass.Type.SHIELD:
			stats_text = "护盾: %d | 冷却: %.1fs" % [item.shield, item.cooldown]
		ItemDataClass.Type.HEAL:
			stats_text = "治疗: %d | 冷却: %.1fs" % [item.heal, item.cooldown]
		ItemDataClass.Type.UTILITY:
			stats_text = "暴击: %.0f%%" % [item.crit_chance * 100]
	stats_label.text = stats_text
	stats_label.add_theme_font_size_override("font_size", 18)
	info_vbox.add_child(stats_label)

	# 尺寸
	var size_label = Label.new()
	size_label.text = "尺寸: %s格" % item.get_size_text()
	size_label.add_theme_font_size_override("font_size", 16)
	size_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	info_vbox.add_child(size_label)

	container.add_child(info_vbox)

	# 价格和购买按钮
	var buy_vbox = VBoxContainer.new()
	buy_vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	# 价格标签
	var price_label = Label.new()
	price_label.text = "%d 金币" % item.buy_price
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	buy_vbox.add_child(price_label)

	# 购买按钮
	var buy_button = Button.new()
	buy_button.text = "购买"
	buy_button.pressed.connect(_on_buy_pressed.bind(item, buy_button))
	buy_vbox.add_child(buy_button)

	# 检查金币是否足够
	if not GameManager.can_afford(item.buy_price):
		buy_button.disabled = true
		price_label.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3))

	# 检查背包是否有空间
	if inventory != null:
		var empty_slots = inventory.find_empty_slots(item.get_slot_count())
		if empty_slots.is_empty():
			buy_button.disabled = true
			buy_button.tooltip_text = "背包空间不足"

	# 锁定按钮
	var lock_btn = Button.new()
	var is_locked = idx in locked_indices
	lock_btn.text = "🔒 解锁" if is_locked else "🔓 锁定"
	lock_btn.custom_minimum_size = Vector2(60, 30)
	lock_btn.pressed.connect(_on_lock_pressed.bind(idx, lock_btn))
	buy_vbox.add_child(lock_btn)

	container.add_child(buy_vbox)

	return card_panel

## 获取稀有度颜色（4 级系统）
func _get_rarity_color(rarity: int) -> Color:
	match rarity:
		1: return Color(0.7, 0.7, 0.7)  # 普通 - 灰
		2: return Color(0.2, 0.9, 0.2)  # 稀有 - 绿
		3: return Color(0.7, 0.4, 1.0)  # 史诗 - 紫
		4: return Color(1.0, 0.7, 0.2)  # 传说 - 金
		_: return Color.WHITE

## 获取商店物品图片路径
func _get_shop_item_texture_path(item: ItemData) -> String:
	if item == null:
		return ""

	# 武器
	if item.type == ItemDataClass.Type.WEAPON:
		if item.damage >= 30:
			return "res://assets/art/items/item_great_sword.png"
		elif item.damage >= 20:
			return "res://assets/art/items/item_steel_sword.png"
		elif item.damage >= 15:
			return "res://assets/art/items/item_battle_axe.png"
		else:
			return "res://assets/art/items/item_iron_sword.png"

	# 护盾
	if item.type == ItemDataClass.Type.SHIELD:
		if item.shield >= 25:
			return "res://assets/art/items/item_tower_shield.png"
		elif item.shield >= 15:
			return "res://assets/art/items/item_iron_shield.png"
		else:
			return "res://assets/art/items/item_wooden_shield.png"

	# 治疗
	if item.type == ItemDataClass.Type.HEAL:
		if item.heal >= 20:
			return "res://assets/art/items/item_big_health_potion.png"
		elif item.heal >= 10:
			return "res://assets/art/items/item_health_potion.png"
		else:
			return "res://assets/art/items/item_regen_potion.png"

	# 辅助
	if item.type == ItemDataClass.Type.UTILITY:
		return "res://assets/art/items/item_ring_strength.png"

	return ""

## 购买按钮点击
func _on_buy_pressed(item: ItemData, button: Button) -> void:
	# 检查金币
	if not GameManager.can_afford(item.buy_price):
		print("金币不足！")
		return

	# 检查背包空间
	if inventory != null:
		var empty_slots = inventory.find_empty_slots(item.get_slot_count())
		if empty_slots.is_empty():
			print("[DEBUG] 背包空间不足！")
			return
	else:
		print("[DEBUG] inventory is null!")

	# 扣除金币
	if GameManager.spend_gold(item.buy_price):
		print("[DEBUG] 金币已扣除，准备添加物品到背包")
		# 添加物品到背包
		_add_item_to_inventory(item)

		# 刷新显示
		_refresh_shop_items()

		# 发送信号
		item_purchased.emit(item)

		print("购买成功: %s (花费 %d 金币)" % [item.item_name, item.buy_price])
	else:
		print("[DEBUG] 购买失败: 金币不足")

## 添加物品到背包
func _add_item_to_inventory(item: ItemData) -> void:
	if inventory == null:
		return

	# 创建物品副本，避免多个同类物品共享同一个实例
	var item_copy = item.duplicate()
	item_copy.slot_index = -1

	var empty_slots = inventory.find_empty_slots(item_copy.get_slot_count())
	if not empty_slots.is_empty():
		var slot = empty_slots[0]
		inventory.place_item(item_copy, slot)
		print("物品已放入背包，槽位: %d" % slot)
	else:
		print("警告: 没有可用槽位")

## 刷新商店（保留锁定物品）
func _on_refresh_pressed(refresh_btn: Button) -> void:
	# 扣费
	if not free_refresh_used:
		free_refresh_used = true
	else:
		if not GameManager.can_afford(REFRESH_COST):
			print("金币不足，无法刷新！")
			return
		GameManager.spend_gold(REFRESH_COST)

	# 保留锁定物品
	var locked_items: Array[ItemData] = []
	var locked_idx_map: Array[int] = []
	for idx in locked_indices:
		if idx < shop_items.size():
			locked_items.append(shop_items[idx])
			locked_idx_map.append(idx)

	# 重新生成未锁定的物品
	var day = GameManager.current_day
	var max_rarity = _get_max_rarity_for_day(day)
	var new_items: Array[ItemData] = []
	for i in range(shop_items.size()):
		if i in locked_indices:
			new_items.append(shop_items[i])
		else:
			new_items.append(_create_random_item(day, max_rarity))

	shop_items = new_items
	# 更新锁定索引（保持锁定状态）
	var new_locked: Array[int] = []
	var li = 0
	for i in range(shop_items.size()):
		if li < locked_idx_map.size() and i == locked_idx_map[li]:
			new_locked.append(i)
			li += 1
	locked_indices = new_locked

	_refresh_shop_items()
	print("商店已刷新！锁定了 %d 个物品" % locked_indices.size())

## 锁定/解锁物品
func _on_lock_pressed(idx: int, lock_btn: Button) -> void:
	if idx in locked_indices:
		locked_indices.erase(idx)
		lock_btn.text = "🔓 锁定"
	else:
		locked_indices.append(idx)
		lock_btn.text = "🔒 解锁"
	print("商店物品 %d %s" % [idx, "已锁定" if idx in locked_indices else "已解锁"])

## 关闭按钮点击
func _on_close_pressed() -> void:
	hide_shop()

## 更新按钮状态（每次显示时调用）
func update_button_states() -> void:
	player_gold = GameManager.gold
	_refresh_shop_items()
