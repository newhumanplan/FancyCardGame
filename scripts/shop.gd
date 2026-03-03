## 商店系统
## 负责商店物品管理、购买和出售逻辑
class_name Shop
extends Node

## 商店物品列表
var shop_items = []

## 基础折扣率（出售时获得的金币比例）
const SELL_DISCOUNT: float = 0.5

## 信号：商店物品变化
signal shop_updated()

## 初始化商店
func _ready() -> void:
	_generate_shop_items()

## 生成商店物品
func _generate_shop_items() -> void:
	shop_items.clear()

	# 武器 (0), 护甲 (1), 消耗品 (2), 材料 (3)
	shop_items.append(_create_shop_item("铁剑", 0, 10, 1, 50, 3))
	shop_items.append(_create_shop_item("钢剑", 0, 18, 2, 120, 2))
	shop_items.append(_create_shop_item("魔法杖", 0, 15, 2, 100, 2))
	shop_items.append(_create_shop_item("匕首", 0, 8, 1, 30, 5))

	# 护甲
	shop_items.append(_create_shop_item("皮甲", 1, 5, 1, 40, 3))
	shop_items.append(_create_shop_item("锁甲", 1, 10, 2, 90, 2))
	shop_items.append(_create_shop_item("板甲", 1, 18, 3, 200, 1))

	# 消耗品
	shop_items.append(_create_shop_item("治疗药水", 2, 30, 1, 25, 10, true, 3))
	shop_items.append(_create_shop_item("强力治疗药水", 2, 60, 2, 60, 5, true, 2))
	shop_items.append(_create_shop_item("魔法药水", 2, 20, 1, 30, 8, true, 3))
	shop_items.append(_create_shop_item("敏捷药水", 2, 10, 2, 45, 5, true, 2))

	# 材料
	shop_items.append(_create_shop_item("铁矿石", 3, 0, 1, 10, 20))
	shop_items.append(_create_shop_item("魔法粉尘", 3, 0, 2, 25, 10))
	shop_items.append(_create_shop_item("兽皮", 3, 0, 1, 8, 25))

	shop_updated.emit()

## 创建商店物品辅助函数
func _create_shop_item(
	name: String,
	type: int,
	effect_value: int,
	rarity: int,
	price: int,
	stock: int,
	usable: bool = false,
	uses: int = 1
):
	var item = ShopItem.new(
		name,
		"",
		type,
		effect_value,
		rarity,
		usable,
		uses,
		price,
		stock
	)

	# 设置描述
	match type:
		0: item.description = "攻击力 +%d" % effect_value
		1: item.description = "防御力 +%d" % effect_value
		2: item.description = "效果 +%d" % effect_value

	return item

## 购买物品
func buy_item(item_index: int, inventory: Inventory, gold_manager) -> bool:
	if item_index < 0 or item_index >= shop_items.size():
		return false

	var shop_item = shop_items[item_index]
	
	# 检查库存
	if not shop_item.has_stock():
		print("商店: %s 已售罄" % shop_item.name)
		return false
	
	# 检查金币
	if not gold_manager.can_afford(shop_item.price):
		print("商店: 金币不足，需要 %d，当前 %d" % [shop_item.price, gold_manager.get_gold()])
		return false
	
	# 检查背包空间
	if inventory.is_full():
		print("商店: 背包已满")
		return false
	
	# 扣款
	if not gold_manager.spend_gold(shop_item.price):
		return false
	
	# 减少库存
	shop_item.purchase()
	
	# 添加到背包（复制一个普通 Item）
	var new_item: Item = _shop_item_to_item(shop_item)
	inventory.add_item(new_item)
	
	print("商店: 购买了 %s，花费 %d 金币" % [shop_item.name, shop_item.price])
	shop_updated.emit()
	return true

## 出售物品
func sell_item(slot_index: int, inventory: Inventory, gold_manager) -> bool:
	var item := inventory.get_item(slot_index)
	if item == null:
		return false
	
	# 计算出售价格
	var sell_price := _calculate_sell_price(item)
	
	# 移除物品
	inventory.remove_item(slot_index)
	
	# 增加金币
	gold_manager.add_gold(sell_price)
	
	print("商店: 出售了 %s，获得 %d 金币" % [item.name, sell_price])
	return true

## 计算出售价格
func _calculate_sell_price(item) -> int:
	var base_price := 10

	match item.type:
		0: base_price = 10 + item.effect_value * 3  # WEAPON
		1: base_price = 10 + item.effect_value * 3  # ARMOR
		2: base_price = 5 + item.effect_value  # CONSUMABLE
		3: base_price = 5  # MATERIAL
	
	# 稀有度加成
	base_price *= (1 + item.rarity * 0.2)
	
	# 折扣
	return int(base_price * SELL_DISCOUNT)

## 将 ShopItem 转换为普通 Item
func _shop_item_to_item(shop_item):
	match shop_item.type:
		0:  # WEAPON
			return Weapon.new(shop_item.name, shop_item.effect_value, shop_item.rarity)
		1:  # ARMOR
			return Armor.new(shop_item.name, shop_item.effect_value, shop_item.rarity)
		2:  # CONSUMABLE
			return Consumable.new(shop_item.name, shop_item.effect_value, shop_item.uses_remaining, shop_item.rarity)
		_:
			return Item.new(shop_item.name, shop_item.description, shop_item.type, shop_item.effect_value, shop_item.rarity)

## 刷新商店（每关卡开始时调用）
func refresh_shop() -> void:
	_generate_shop_items()

## 获取商店物品列表
func get_shop_items():
	return shop_items
