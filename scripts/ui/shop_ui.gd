class_name ShopUI
extends Control

## 商店 UI 控制器
## 核心功能：
## 1. 显示可购买物品
## 2. 购买逻辑（金币检查、扣除、添加到背包）
## 3. 合成升级（两个相同稀有度 → 更高稀有度）

## 预加载
const ItemDataClass = preload("res://scripts/data/item_data.gd")
const LinearInventoryClass = preload("res://scripts/data/linear_inventory.gd")

## UI 节点
@onready var panel: PanelContainer = $Panel
@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var shop_items_container: VBoxContainer = $Panel/VBox/ShopItemsContainer
@onready var close_button: Button = $Panel/VBox/CloseButton
@onready var gold_label: Label = $Panel/VBox/GoldLabel

## 商店物品列表
var shop_items: Array[ItemData] = []

## 玩家金币（引用 GameManager）
var player_gold: int = 0

## 背包实例（引用 InventoryUI）
var inventory: LinearInventory = null

## 信号
signal shop_closed()
signal item_purchased(item: ItemData)

## 回调函数引用
var on_shop_closed_callback: Callable = Callable()

## 稀有度名称映射
const RARITY_NAMES: Array[String] = ["普通", "优秀", "稀有", "史诗", "传说"]

func _ready() -> void:
	# 连接关闭按钮
	close_button.pressed.connect(_on_close_pressed)
	
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
	print("  shop_items generated: " + str(shop_items.size()))
	
	# 更新 UI
	_update_gold_label()
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

## 根据 Day 获取最大稀有度
func _get_max_rarity_for_day(day: int) -> int:
	if day == 1:
		return 1  # 普通
	elif day <= 3:
		return 2  # 优秀
	elif day <= 5:
		return 3  # 稀有
	elif day <= 8:
		return 4  # 史诗
	else:
		return 5  # 传说

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
	
	# 冷却时间
	item.cooldown = randf_range(2.0, 8.0)
	item.current_cooldown = 0.0
	
	return item

## 获取武器名称
func _get_weapon_name(rarity: int) -> String:
	var names = [
		["木剑", "铁剑", "钢剑", "魔法剑", "传奇剑"],
		["木斧", "铁斧", "钢斧", "魔法斧", "传奇斧"],
		["木弓", "铁弓", "钢弓", "魔法弓", "传奇弓"],
		["法杖", "魔杖", "奥术杖", "元素杖", "星辉杖"]
	]
	var type_idx = randi() % names.size()
	return names[type_idx][rarity - 1]

## 获取护盾名称
func _get_shield_name(rarity: int) -> String:
	var names = ["木盾", "铁盾", "钢盾", "魔法盾", "传奇盾"]
	return names[rarity - 1]

## 获取治疗物品名称
func _get_heal_name(rarity: int) -> String:
	var names = ["草药", "药水", "圣水", "魔法药剂", "神级药水"]
	return names[rarity - 1]

## 获取辅助物品名称
func _get_utility_name(rarity: int) -> String:
	var names = ["幸运符", "力量符", "防御符", "魔法符", "传奇符"]
	return names[rarity - 1]

## 计算价格
func _calculate_price(item: ItemData) -> int:
	var base_price = 10
	
	# 稀有度加成
	base_price *= item.rarity
	
	# 尺寸加成
	match item.size:
		ItemDataClass.Size.SMALL: base_price *= 1
		ItemDataClass.Size.MEDIUM: base_price *= 1.5
		ItemDataClass.Size.LARGE: base_price *= 2.5
	
	# 类型加成
	match item.type:
		ItemDataClass.Type.WEAPON: base_price *= 1.2
		ItemDataClass.Type.SHIELD: base_price *= 1.0
		ItemDataClass.Type.HEAL: base_price *= 0.8
		ItemDataClass.Type.UTILITY: base_price *= 1.5
	
	return int(base_price)

## 刷新商店物品显示
func _refresh_shop_items() -> void:
	# 清除现有物品显示
	for child in shop_items_container.get_children():
		child.queue_free()
	
	# 创建每个物品的显示
	for item in shop_items:
		var item_display = _create_item_display(item)
		shop_items_container.add_child(item_display)

## 创建物品显示面板
func _create_item_display(item: ItemData) -> Control:
	var container = HBoxContainer.new()
	container.custom_minimum_size = Vector2(0, 120)
	
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
	name_label.text = "%s [%s]" % [item.item_name, RARITY_NAMES[item.rarity - 1]]
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
	
	container.add_child(buy_vbox)
	
	return container

## 获取稀有度颜色
func _get_rarity_color(rarity: int) -> Color:
	match rarity:
		1: return Color(0.7, 0.7, 0.7)  # 普通 - 灰
		2: return Color(0.2, 0.9, 0.2)  # 优秀 - 绿
		3: return Color(0.3, 0.6, 1.0)  # 稀有 - 蓝
		4: return Color(0.7, 0.4, 1.0)  # 史诗 - 紫
		5: return Color(1.0, 0.7, 0.2)  # 传说 - 金
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

## 更新金币显示
func _update_gold_label() -> void:
	gold_label.text = "当前金币: %d" % GameManager.gold

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
		_update_gold_label()
		_refresh_shop_items()
		
		# 发送信号
		item_purchased.emit(item)
		
		print("购买成功: %s (花费 %d 金币)" % [item.item_name, item.buy_price])
	else:
		print("[DEBUG] 购买失败: 金币不足")

## 添加物品到背包（包含合成逻辑）
func _add_item_to_inventory(item: ItemData) -> void:
	print("[DEBUG] _add_item_to_inventory() called!")
	if inventory == null:
		print("[DEBUG] inventory is null, cannot add item!")
		return
	
	# 检查是否可以合成
	var upgraded_item = _try_craft_upgrade(item)
	
	if upgraded_item != null:
		# 合成成功
		print("合成升级: %s -> %s" % [item.item_name, upgraded_item.item_name])
		item = upgraded_item
	
	# 查找空位
	var empty_slots = inventory.find_empty_slots(item.get_slot_count())
	print("[DEBUG] empty_slots: " + str(empty_slots))
	if not empty_slots.is_empty():
		var slot = empty_slots[0]
		inventory.place_item(item, slot)
		print("物品已放入背包，槽位: %d" % slot)
		print("[DEBUG] 物品添加成功! 背包物品数量: " + str(inventory.items.size()))
	else:
		print("警告: 没有可用槽位")

## 尝试合成升级
## 检查背包中是否有相同稀有度的物品
## 如果有，合成一个更高稀有度的物品
func _try_craft_upgrade(new_item: ItemData) -> ItemData:
	if inventory == null:
		return null
	
	# 最高稀有度无法合成
	if new_item.rarity >= 5:
		return null
	
	# 查找背包中相同稀有度的物品
	var same_rarity_items: Array[ItemData] = []
	
	for existing_item in inventory.items:
		if existing_item != null and existing_item.rarity == new_item.rarity:
			same_rarity_items.append(existing_item)
	
	if same_rarity_items.size() >= 1:
		# 找到一个相同稀有度的物品，合成更高稀有度
		var item_to_remove = same_rarity_items[0]
		
		# 移除用于合成的物品
		inventory.remove_item(item_to_remove)
		
		# 创建升级后的物品
		var upgraded_item = _create_upgraded_item(new_item)
		
		print("========== 合成升级成功！==========")
		print("材料1: %s [%s]" % [item_to_remove.item_name, RARITY_NAMES[item_to_remove.rarity - 1]])
		print("材料2: %s [%s]" % [new_item.item_name, RARITY_NAMES[new_item.rarity - 1]])
		print("产物: %s [%s]" % [upgraded_item.item_name, RARITY_NAMES[upgraded_item.rarity - 1]])
		print("====================================")
		
		return upgraded_item
	
	return null

## 创建升级后的物品
func _create_upgraded_item(original: ItemData) -> ItemData:
	var upgraded = ItemDataClass.new()
	
	# 提升稀有度
	upgraded.rarity = original.rarity + 1
	
	# 复制基本属性
	upgraded.type = original.type
	upgraded.size = original.size
	upgraded.cooldown = original.cooldown
	upgraded.current_cooldown = 0.0
	
	# 提升属性
	match original.type:
		ItemDataClass.Type.WEAPON:
			upgraded.damage = int(float(original.damage) * 1.5)
			upgraded.item_name = _get_upgraded_name(original)
		ItemDataClass.Type.SHIELD:
			upgraded.shield = int(float(original.shield) * 1.5)
			upgraded.item_name = _get_upgraded_name(original)
		ItemDataClass.Type.HEAL:
			upgraded.heal = int(float(original.heal) * 1.5)
			upgraded.item_name = _get_upgraded_name(original)
		ItemDataClass.Type.UTILITY:
			upgraded.crit_chance = original.crit_chance * 1.5
			upgraded.item_name = _get_upgraded_name(original)
	
	# 设置价格
	upgraded.buy_price = _calculate_price(upgraded)
	
	return upgraded

## 获取升级后的物品名称
func _get_upgraded_name(original: ItemData) -> String:
	var rarity = original.rarity
	var type_name = ""
	
	match original.type:
		ItemDataClass.Type.WEAPON:
			type_name = "武器"
		ItemDataClass.Type.SHIELD:
			type_name = "护盾"
		ItemDataClass.Type.HEAL:
			type_name = "药剂"
		ItemDataClass.Type.UTILITY:
			type_name = "符咒"
	
	# 如果是最高稀有度，加"神圣"前缀
	if rarity >= 4:
		return "神圣%s" % type_name
	
	return "进阶%s" % type_name

## 关闭按钮点击
func _on_close_pressed() -> void:
	hide_shop()

## 更新按钮状态（每次显示时调用）
func update_button_states() -> void:
	player_gold = GameManager.gold
	_refresh_shop_items()
