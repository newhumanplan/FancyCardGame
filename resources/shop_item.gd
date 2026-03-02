## 商店物品
## 扩展 Item，添加价格和库存属性
class_name ShopItem
extends Item

## 购买价格
@export var price: int = 0

## 库存数量（-1 表示无限）
@export var stock: int = -1

## 是否已解锁
@export var unlocked: bool = true

## 构造函数
func _init(
	p_name: String = "物品",
	p_description: String = "",
	p_type: ItemType = ItemType.MATERIAL,
	p_effect_value: int = 0,
	p_rarity: int = 1,
	p_usable: bool = false,
	p_uses: int = 1,
	p_price: int = 0,
	p_stock: int = -1
).(
	p_name,
	p_description,
	p_type,
	p_effect_value,
	p_rarity,
	p_usable,
	p_uses
) -> void:
	price = p_price
	stock = p_stock

## 从现有 Item 创建 ShopItem
static func from_item(item: Item, p_price: int = 0, p_stock: int = -1) -> ShopItem:
	var shop_item := ShopItem.new(
		item.name,
		item.description,
		item.type,
		item.effect_value,
		item.rarity,
		item.usable,
		item.uses_remaining,
		p_price,
		p_stock
	)
	# 复制额外属性
	shop_item.icon_path = item.icon_path
	return shop_item

## 检查是否有库存
func has_stock() -> bool:
	return stock == -1 or stock > 0

## 购买一件（减少库存）
func purchase() -> bool:
	if stock == -1:
		return true  # 无限库存
	if stock > 0:
		stock -= 1
		return true
	return false

## 获得一件（增加库存，用于出售后）
func restock(amount: int = 1) -> void:
	if stock != -1:
		stock += amount

## 获取价格文本
func get_price_text() -> String:
	if price <= 0:
		return "免费"
	return "%d 金币" % price

## 获取库存文本
func get_stock_text() -> String:
	if stock == -1:
		return "无限"
	return "剩余: %d" % stock
