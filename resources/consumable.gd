## 消耗品类型
class_name Consumable
extends Item

func _init(
    p_name: String = "消耗品",
    p_effect: int = 0,
    p_uses: int = 1,
    p_rarity: int = 1
) -> void:
    name = p_name
    type = 2  # Item.ItemType.CONSUMABLE
    effect_value = p_effect
    rarity = p_rarity
    usable = true
    uses_remaining = p_uses
