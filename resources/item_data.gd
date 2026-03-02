## 物品配置文件
## 预设游戏中的各种物品

class_name ItemData

## 获取所有基础武器
static func get_weapons() -> Array[Weapon]:
	return [
		get_iron_sword(),
		get_staff(),
		get_dagger(),
	]

## 获取所有基础护甲
static func get_armors() -> Array[Armor]:
	return [
		get_cloth_armor(),
		get_leather_armor(),
	]

## 铁剑 - 基础武器
static func get_iron_sword() -> Weapon:
	return Weapon.new("铁剑", 5, 1)

## 法杖 - 法师武器
static func get_staff() -> Weapon:
	return Weapon.new("法杖", 8, 2)

## 匕首 - 盗贼武器
static func get_dagger() -> Weapon:
	return Weapon.new("匕首", 3, 1)

## 布甲 - 基础护甲
static func get_cloth_armor() -> Armor:
	return Armor.new("布甲", 2, 1)

## 皮甲 - 中级护甲
static func get_leather_armor() -> Armor:
	return Armor.new("皮甲", 4, 2)

## 获取物品实例（通过名称）
static func get_item_by_name(item_name: String) -> Item:
	match item_name:
		"铁剑": return get_iron_sword()
		"法杖": return get_staff()
		"匕首": return get_dagger()
		"布甲": return get_cloth_armor()
		"皮甲": return get_leather_armor()
		_: return null
