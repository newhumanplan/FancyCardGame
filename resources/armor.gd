## 护甲类型
class_name Armor
extends Item

func _init(p_name: String = "护甲", p_defense: int = 0, p_rarity: int = 1):
	name = p_name
	type = Item.ItemType.ARMOR
	effect_value = p_defense
	rarity = p_rarity
	usable = false
	uses_remaining = 1
