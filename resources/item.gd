class_name Item
extends Resource

## 物品类型
enum ItemType {
	WEAPON,      # 武器
	ARMOR,       # 护甲
	ACCESSORY,   # 饰品
	CONSUMABLE   # 消耗品
}

## 物品名称
@export var item_name: String = "物品"

## 物品描述
@export var description: String = ""

## 物品类型
@export var item_type: ItemType = ItemType.WEAPON

## 物品尺寸（网格格数）- 核心！
@export var size: Vector2i = Vector2i(1, 1)

## 攻击力加成
@export var attack: int = 0

## 防御力加成
@export var defense: int = 0

## 稀有度 (1-5)
@export var rarity: int = 1

## 购买价格
@export var buy_price: int = 10

## 图标路径
@export var icon_path: String = ""

## 在背包中的位置（运行时）
var grid_position: Vector2i = Vector2i(-1, -1)

## 获取稀有度名称
func get_rarity_name() -> String:
	match rarity:
		1: return "普通"
		2: return "优秀"
		3: return "稀有"
		4: return "史诗"
		5: return "传说"
		_: return "未知"

## 获取稀有度颜色
func get_rarity_color() -> Color:
	match rarity:
		1: return Color.GRAY
		2: return Color.GREEN
		3: return Color.BLUE
		4: return Color.PURPLE
		5: return Color.ORANGE
		_: return Color.WHITE

## 获取类型名称
func get_type_name() -> String:
	match item_type:
		ItemType.WEAPON: return "武器"
		ItemType.ARMOR: return "护甲"
		ItemType.ACCESSORY: return "饰品"
		ItemType.CONSUMABLE: return "消耗品"
		_: return "未知"

## 获取尺寸文本
func get_size_text() -> String:
	return "%dx%d" % [size.x, size.y]
