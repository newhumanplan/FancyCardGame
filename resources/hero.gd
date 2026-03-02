## 英雄数据结构
class_name Hero
extends Unit

## 英雄职业枚举
enum HeroClass {
    WARRIOR,   # 战士
    MAGE,      # 法师
    ROGUE,     # 盗贼
    CLERIC     # 牧师
}

## 英雄名称
@export var hero_name: String = "英雄"

## 英雄职业
@export var hero_class: HeroClass = HeroClass.WARRIOR

## 英雄描述
@export var description: String = ""

## 职业加成属性
@export var class_bonus_attack: int = 0
@export var class_bonus_defense: int = 0
@export var class_bonus_hp: int = 0
@export var class_bonus_speed: int = 0

## 初始装备
@export var initial_weapon: Weapon = null
@export var initial_armor: Armor = null

## 构造函数
func _init(
	p_name: String = "英雄",
	p_class: HeroClass = HeroClass.WARRIOR,
	p_max_hp: int = 100,
	p_attack: int = 10,
	p_defense: int = 5,
	p_speed: int = 10,
	p_crit_rate: float = 0.05,
	p_crit_damage: float = 1.5,
	p_description: String = ""
).(
	p_name,
	p_max_hp,
	p_attack,
	p_defense,
	p_speed,
	p_crit_rate,
	p_crit_damage
) -> void:
	hero_name = p_name
	hero_class = p_class
	description = p_description
	_apply_class_bonus()

## 应用职业加成
func _apply_class_bonus() -> void:
	match hero_class:
		HeroClass.WARRIOR:
			class_bonus_attack = 2
			class_bonus_defense = 3
			class_bonus_hp = 20
			class_bonus_speed = 0
		HeroClass.MAGE:
			class_bonus_attack = 5
			class_bonus_defense = 0
			class_bonus_hp = -10
			class_bonus_speed = 2
		HeroClass.ROGUE:
			class_bonus_attack = 3
			class_bonus_defense = 0
			class_bonus_hp = 0
			class_bonus_speed = 5
		HeroClass.CLERIC:
			class_bonus_attack = 1
			class_bonus_defense = 2
			class_bonus_hp = 10
			class_bonus_speed = 1

## 获取总攻击力（含职业加成）
func get_total_attack() -> int:
	return attack + class_bonus_attack

## 获取总防御力（含职业加成）
func get_total_defense() -> int:
	return defense + class_bonus_defense

## 获取总生命值（含职业加成）
func get_total_max_hp() -> int:
	return max_hp + class_bonus_hp

## 获取总速度（含职业加成）
func get_total_speed() -> int:
	return speed + class_bonus_speed

## 获取职业名称
func get_class_name() -> String:
	match hero_class:
		HeroClass.WARRIOR: return "战士"
		HeroClass.MAGE: return "法师"
		HeroClass.ROGUE: return "盗贼"
		HeroClass.CLERIC: return "牧师"
		_: return "未知"

## 获取完整描述
func get_full_description() -> String:
	var desc := "%s - %s\n" % [hero_name, get_class_name()]
	if description != "":
		desc += "%s\n" % description
	desc += "生命: %d/%d  攻击: %d  防御: %d  速度: %d" % [
		current_hp, get_total_max_hp(),
		get_total_attack(),
		get_total_defense(),
		get_total_speed()
	]
	return desc

## 重置英雄状态
func reset() -> void:
	super.reset()
	current_hp = get_total_max_hp()

## 克隆英雄
func duplicate() -> Hero:
	var new_hero = Hero.new(
		name,
		hero_class,
		max_hp,
		attack,
		defense,
		speed,
		crit_rate,
		crit_damage,
		description
	)
	new_hero.current_hp = current_hp
	new_hero.initial_weapon = initial_weapon
	new_hero.initial_armor = initial_armor
	return new_hero


## 战士职业
class_name WarriorHero
extends Hero

func _init(
	p_name: String = "战士",
	p_max_hp: int = 120,
	p_attack: int = 12,
	p_defense: int = 8,
	p_speed: int = 8
).(
	p_name,
	HeroClass.WARRIOR,
	p_max_hp,
	p_attack,
	p_defense,
	p_speed,
	0.10,
	1.5,
	"身经百战的战士，擅长近身战斗"
) -> void:
	pass


## 法师职业
class_name MageHero
extends Hero

func _init(
	p_name: String = "法师",
	p_max_hp: int = 80,
	p_attack: int = 18,
	p_defense: int = 3,
	p_speed: int = 12
).(
	p_name,
	HeroClass.MAGE,
	p_max_hp,
	p_attack,
	p_defense,
	p_speed,
	0.15,
	1.8,
	"掌握元素魔法的法师，擅长远程攻击"
) -> void:
	pass
