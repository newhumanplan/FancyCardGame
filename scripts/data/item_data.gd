class_name ItemData
extends Resource

## 物品尺寸枚举
enum Size { SMALL, MEDIUM, LARGE }

## 物品类型枚举
enum Type { WEAPON, SHIELD, HEAL, UTILITY }

## ============ 保留属性 ============

## 物品名称
@export var item_name: String = "物品"

## 物品描述
@export var description: String = ""

## 稀有度 (1-5)
@export var rarity: int = 1

## 购买价格
@export var buy_price: int = 10

## ============ 修改/新增属性 ============

## 物品尺寸
@export var size: Size = Size.SMALL

## 物品类型
@export var type: Type = Type.WEAPON

## 当前槽位索引（运行时）
var slot_index: int = -1

## 当前冷却进度（运行时）
var current_cooldown: float = 0.0

## ============ 战斗属性 ============

## 攻击力/伤害
@export var damage: int = 0

## 护盾值
@export var shield: int = 0

## 治疗值
@export var heal: int = 0

## 冷却时间
@export var cooldown: float = 5.0

## 暴击几率
@export var crit_chance: float = 0.05

## ============ 特殊效果 ============

## 中毒：持续伤害（伤害值/秒）
@export var poison_damage: float = 0.0

## 再生：持续治疗（治疗值/秒）
@export var regeneration: float = 0.0

## 眩晕：暂停冷却（秒）
@export var stun_duration: float = 0.0

## 免疫：免疫控制效果
@export var is_immune: bool = false

## ============ 运行时方法 ============

## 获取物品占用的槽位数量
func get_slot_count() -> int:
	match size:
		Size.SMALL: return 1
		Size.MEDIUM: return 2
		Size.LARGE: return 3
	return 1

## 检查是否可以触发（冷却是否完毕）
func can_trigger() -> bool:
	return current_cooldown <= 0

## 重置冷却
func reset_cooldown():
	current_cooldown = cooldown

## ============ 工具方法 ============

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
	match type:
		Type.WEAPON: return "武器"
		Type.SHIELD: return "护盾"
		Type.HEAL: return "治疗"
		Type.UTILITY: return "辅助"
		_: return "未知"

## 获取尺寸文本
func get_size_text() -> String:
	match size:
		Size.SMALL: return "小"
		Size.MEDIUM: return "中"
		Size.LARGE: return "大"
		_: return "未知"

## 获取稀有度属性倍率
## 返回: 1.0=100%, 1.2=120%, 1.5=150%, 2.0=200%
func get_rarity_multiplier() -> float:
	match rarity:
		1: return 1.0    # 普通
		2: return 1.2    # 稀有
		3: return 1.5    # 史诗
		4: return 2.0    # 传说
		5: return 2.0    # 传说（最高）
		_: return 1.0

## 应用稀有度加成到属性
## 返回: 加成后的属性值
func get_rarity_adjusted_damage() -> int:
	return int(float(damage) * get_rarity_multiplier())

func get_rarity_adjusted_shield() -> int:
	return int(float(shield) * get_rarity_multiplier())

func get_rarity_adjusted_heal() -> int:
	return int(float(heal) * get_rarity_multiplier())

## 是否有特殊效果
func has_special_effect() -> bool:
	return poison_damage > 0 or regeneration > 0 or stun_duration > 0 or is_immune

## 获取特殊效果描述
func get_special_effect_description() -> String:
	var effects: Array[String] = []
	if poison_damage > 0:
		effects.append("中毒(%.1f DPS)" % poison_damage)
	if regeneration > 0:
		effects.append("再生(%.1f HPS)" % regeneration)
	if stun_duration > 0:
		effects.append("眩晕(%.1fs)" % stun_duration)
	if is_immune:
		effects.append("免疫控制")
	return ", ".join(effects)
