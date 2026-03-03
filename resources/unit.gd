extends Resource
class_name Unit

## 单位数据资源
## 用于定义游戏中的战斗单位（玩家、敌人等）

@export var name: String = "单位"
@export var max_hp: int = 100          # 最大生命值
@export var current_hp: int = 100      # 当前生命值
@export var attack: int = 10            # 攻击力
@export var defense: int = 5           # 防御力
@export var speed: int = 10             # 速度（决定行动顺序）
@export var crit_rate: float = 0.05     # 暴击率（默认5%）
@export var crit_damage: float = 1.5    # 暴击伤害倍率（默认150%）

## 技能倍率（可扩展为技能系统）
var skill_multiplier: float = 1.0

func _init(
	p_name: String = "单位",
	p_max_hp: int = 100,
	p_attack: int = 10,
	p_defense: int = 5,
	p_speed: int = 10,
	p_crit_rate: float = 0.05,
	p_crit_damage: float = 1.5
) -> void:
	name = p_name
	max_hp = p_max_hp
	current_hp = p_max_hp
	attack = p_attack
	defense = p_defense
	speed = p_speed
	crit_rate = p_crit_rate
	crit_damage = p_crit_damage

## 检查单位是否存活
func is_alive() -> bool:
	return current_hp > 0

## 受到伤害
func take_damage(damage: int) -> void:
	current_hp = max(0, current_hp - damage)

## 恢复生命值
func heal(amount: int) -> void:
	current_hp = min(max_hp, current_hp + amount)

## 重置单位状态
func reset() -> void:
	current_hp = max_hp
	skill_multiplier = 1.0

## 获取暴击伤害
func get_crit_damage() -> int:
	if randf() < crit_rate:
		return int(crit_damage * 100)  # 返回暴击标记（实际计算在伤害公式中处理）
	return 100  # 正常伤害标记

## 克隆单位（重命名避免与 Resource.duplicate() 冲突）
func clone():
	var new_unit = get_script().new(name, max_hp, attack, defense, speed, crit_rate, crit_damage)
	new_unit.current_hp = current_hp
	return new_unit

## 获取状态文本描述
func get_stats_text() -> String:
	return "HP: %d/%d ATK: %d DEF: %d SPD: %d" % [current_hp, max_hp, attack, defense, speed]
