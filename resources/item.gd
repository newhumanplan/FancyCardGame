## 物品数据结构
class_name Item
extends Resource

## 物品类型枚举
enum ItemType {
    WEAPON,      # 武器
    ARMOR,       # 护甲
    CONSUMABLE,  # 消耗品
    MATERIAL     # 材料
}

## 物品名称
@export var name: String = "物品"

## 物品描述
@export var description: String = ""

## 物品类型
@export var type: ItemType = ItemType.MATERIAL

## 效果值（如攻击力加成、治疗量等）
@export var effect_value: int = 0

## 稀有度 (1-5)
@export var rarity: int = 1

## 图标路径
@export var icon_path: String = ""

## 是否可使用
@export var usable: bool = false

## 消耗品：使用次数
var uses_remaining: int = 1

## 初始化
func _init(
    p_name: String = "物品",
    p_description: String = "",
    p_type: ItemType = ItemType.MATERIAL,
    p_effect_value: int = 0,
    p_rarity: int = 1,
    p_usable: bool = false,
    p_uses: int = 1
) -> void:
    name = p_name
    description = p_description
    type = p_type
    effect_value = p_effect_value
    rarity = p_rarity
    usable = p_usable
    uses_remaining = p_uses

## 使用物品（需要在子类中实现具体逻辑）
func use(target: Unit) -> bool:
    if not usable:
        return false
    
    if uses_remaining <= 0:
        return false
    
    uses_remaining -= 1
    return true

## 获取稀有度颜色
func get_rarity_color() -> Color:
    match rarity:
        1: return Color.WHITE      # 普通
        2: return Color.GREEN      # 优秀
        3: return Color.BLUE       # 稀有
        4: return Color.PURPLE     # 史诗
        5: return Color.ORANGE    # 传说
        _: return Color.WHITE

## 获取物品类型名称
func get_type_name() -> String:
    match type:
        ItemType.WEAPON: return "武器"
        ItemType.ARMOR: return "护甲"
        ItemType.CONSUMABLE: return "消耗品"
        ItemType.MATERIAL: return "材料"
        _: return "未知"

## 获取描述
func get_description() -> String:
    var desc := description
    if effect_value > 0:
        match type:
            ItemType.WEAPON: desc += "\n攻击力 +%d" % effect_value
            ItemType.ARMOR: desc += "\n防御力 +%d" % effect_value
            ItemType.CONSUMABLE: desc += "\n效果 +%d" % effect_value
    desc += "\n稀有度: %s" % get_rarity_name()
    return desc

## 获取稀有度名称
func get_rarity_name() -> String:
    match rarity:
        1: return "普通"
        2: return "优秀"
        3: return "稀有"
        4: return "史诗"
        5: return "传说"
        _: return "未知"


## 武器类型
class_name Weapon
extends Item

func _init(
    p_name: String = "武器",
    p_attack: int = 0,
    p_rarity: int = 1
).(
    p_name,
    "",
    ItemType.WEAPON,
    p_attack,
    p_rarity,
    false,
    1
) -> void:
    pass


## 护甲类型
class_name Armor
extends Item

func _init(
    p_name: String = "护甲",
    p_defense: int = 0,
    p_rarity: int = 1
).(
    p_name,
    "",
    ItemType.ARMOR,
    p_defense,
    p_rarity,
    false,
    1
) -> void:
    pass


## 消耗品类型
class_name Consumable
extends Item

func _init(
    p_name: String = "消耗品",
    p_effect: int = 0,
    p_uses: int = 1,
    p_rarity: int = 1
).(
    p_name,
    "",
    ItemType.CONSUMABLE,
    p_effect,
    p_rarity,
    true,
    p_uses
) -> void:
    pass
