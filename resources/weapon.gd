## 武器类型
class_name Weapon
extends Item

func _init(p_name: String = "武器", p_attack: int = 0, p_rarity: int = 1):
	name = p_name
	type = Item.ItemType.WEAPON
	effect_value = p_attack
	rarity = p_rarity
	usable = false
	uses_remaining = 1
