extends Node
class_name Combat

## 战斗系统核心脚本
## 实现回合制战斗流程、伤害计算和暴击系统

signal combat_started(player: Unit, enemy: Unit)
signal turn_started(attacker: Unit)
signal damage_dealt(target: Unit, damage: int, is_crit: bool)
signal unit_defeated(unit: Unit)
signal combat_ended(winner: Unit)

## 战斗状态
enum CombatState {
	NOT_STARTED,
	PLAYER_TURN,
	ENEMY_TURN,
	COMBAT_OVER
}

var state: CombatState = CombatState.NOT_STARTED
var player: Unit
var enemy: Unit
var turn_count: int = 1

## 随机系数范围
const RANDOM_FACTOR_MIN: float = 0.9
const RANDOM_FACTOR_MAX: float = 1.1

## 暴击配置
const CRIT_RATE: float = 0.05
const CRIT_DAMAGE: float = 1.5

func _ready() -> void:
	print("战斗系统已就绪")

## 初始化战斗
func init_combat(player_unit: Unit, enemy_unit: Unit) -> void:
	player = player_unit
	enemy = enemy_unit
	turn_count = 1
	
	# 重置单位状态
	player.reset()
	enemy.reset()
	
	state = CombatState.NOT_STARTED
	emit_signal("combat_started", player, enemy)

## 开始战斗
func start_combat() -> void:
	if state != CombatState.NOT_STARTED:
		return
	
	state = CombatState.PLAYER_TURN
	_advance_turn()

## 玩家回合
func player_turn(skill_multiplier: float = 1.0) -> void:
	if state != CombatState.PLAYER_TURN:
		return
	
	player.skill_multiplier = skill_multiplier
	_attack(player, enemy)
	
	if enemy.is_alive():
		state = CombatState.ENEMY_TURN
		# 延迟执行敌人回合
		await get_tree().create_timer(1.0).timeout
		enemy_turn()
	else:
		_end_combat(player)

## 敌人回合
func enemy_turn(skill_multiplier: float = 1.0) -> void:
	if state != CombatState.ENEMY_TURN:
		return
	
	enemy.skill_multiplier = skill_multiplier
	_attack(enemy, player)
	
	if player.is_alive():
		state = CombatState.PLAYER_TURN
		turn_count += 1
		_advance_turn()
	else:
		_end_combat(enemy)

## 攻击核心逻辑
func _attack(attacker: Unit, defender: Unit) -> void:
	emit_signal("turn_started", attacker)
	
	# 计算伤害
	var damage_info = _calculate_damage(attacker, defender)
	var actual_damage = damage_info.damage
	
	# 造成伤害
	defender.take_damage(actual_damage)
	emit_signal("damage_dealt", defender, actual_damage, damage_info.is_crit)
	
	print("%s 对 %s 造成 %d 伤害%s" % [
		attacker.name,
		defender.name,
		actual_damage,
		" (暴击!)" if damage_info.is_crit else ""
	])
	
	# 检查是否击杀
	if not defender.is_alive():
		emit_signal("unit_defeated", defender)

## 伤害计算公式
## 实际伤害 = (攻击力 - 防御力 × 0.5) × 技能倍率 × 随机系数 × 暴击倍率
func _calculate_damage(attacker: Unit, defender: Unit) -> Dictionary:
	# 基础伤害：攻击力 - 防御力 × 0.5
	var base_damage = attacker.attack - (defender.defense * 0.5)
	base_damage = max(1, base_damage)  # 至少造成1点伤害
	
	# 随机系数 (0.9 ~ 1.1)
	var random_factor = randf_range(RANDOM_FACTOR_MIN, RANDOM_FACTOR_MAX)
	
	# 暴击判定
	var is_crit = randf() < CRIT_RATE
	var crit_multiplier = CRIT_DAMAGE if is_crit else 1.0
	
	# 最终伤害计算
	var actual_damage = int(
		base_damage * 
		attacker.skill_multiplier * 
		random_factor * 
		crit_multiplier
	)
	
	# 确保伤害至少为1
	actual_damage = max(1, actual_damage)
	
	return {
		"damage": actual_damage,
		"is_crit": is_crit,
		"base_damage": base_damage,
		"random_factor": random_factor,
		"crit_multiplier": crit_multiplier
	}

## 推进回合
func _advance_turn() -> void:
	print("回合 %d 开始" % turn_count)
	if state == CombatState.PLAYER_TURN:
		print("玩家回合")
	elif state == CombatState.ENEMY_TURN:
		print("敌人回合")

## 结束战斗
func _end_combat(winner: Unit) -> void:
	state = CombatState.COMBAT_OVER
	emit_signal("combat_ended", winner)
	print("战斗结束! 胜利者: %s" % winner.name)

## 获取战斗状态描述
func get_state_name() -> String:
	match state:
		CombatState.NOT_STARTED:
			return "战斗未开始"
		CombatState.PLAYER_TURN:
			return "玩家回合"
		CombatState.ENEMY_TURN:
			return "敌人回合"
		CombatState.COMBAT_OVER:
			return "战斗结束"
		_:
			return "未知状态"

## 跳过当前回合
func skip_turn() -> void:
	if state == CombatState.PLAYER_TURN:
		enemy_turn()
	elif state == CombatState.ENEMY_TURN:
		player_turn()
