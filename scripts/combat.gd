## 战斗系统核心
class_name Combat
extends Node

## 预加载资源类型
const Unit = preload("res://resources/unit.gd")

## 战斗阶段枚举
enum CombatPhase {
    PREPARATION,  # 准备阶段
    PLAYER_TURN,  # 玩家回合
    ENEMY_TURN,   # 敌人回合
    VICTORY,      # 胜利
    DEFEAT        # 失败
}

## 当前战斗阶段
var current_phase: CombatPhase = CombatPhase.PREPARATION

## 玩家单位
var player: Unit

## 敌人单位
var enemy: Unit

## 伤害计算结果
class DamageResult:
    var base_damage: int = 0
    var actual_damage: int = 0
    var is_crit: bool = false
    var crit_multiplier: float = 1.0
    
    func _init(bd: int, ad: int, crit: bool, cm: float) -> void:
        base_damage = bd
        actual_damage = ad
        is_crit = crit
        crit_multiplier = cm

## 信号定义
signal phase_changed(phase: CombatPhase)
signal damage_dealt(target: Unit, damage: int, is_crit: bool)
signal unit_defeated(unit: Unit)
signal combat_ended(victory: bool)

## 初始化战斗
func init_combat(p_player: Unit, p_enemy: Unit) -> void:
    player = p_player
    enemy = p_enemy
    player.reset()
    enemy.reset()
    current_phase = CombatPhase.PREPARATION
    _change_phase(CombatPhase.PLAYER_TURN)

## 计算伤害
## 公式：实际伤害 = (攻击力 - 防御力 × 0.5) × 技能倍率 × 随机系数
## 暴击：5%概率，150%伤害
func calculate_damage(attacker: Unit, defender: Unit, skill_mult: float = 1.0) -> DamageResult:
    # 基础伤害 = 攻击力 - 防御力 × 0.5
    var base_damage: int = max(1, attacker.attack - int(defender.defense * 0.5))
    
    # 随机系数 (0.9 - 1.1)
    var random_factor := randf_range(0.9, 1.1)
    
    # 计算技能倍率
    var skill_factor := skill_mult * attacker.skill_multiplier
    
    # 初步伤害
    var damage := int(base_damage * skill_factor * random_factor)
    
    # 暴击判定 (5% 概率)
    var is_crit := randf() < attacker.crit_rate
    var crit_mult := 1.0
    
    if is_crit:
        crit_mult = attacker.crit_damage
        damage = int(damage * crit_mult)
    
    return DamageResult.new(base_damage, damage, is_crit, crit_mult)

## 执行攻击
func attack(attacker: Unit, defender: Unit, skill_mult: float = 1.0) -> DamageResult:
    var result := calculate_damage(attacker, defender, skill_mult)
    defender.take_damage(result.actual_damage)
    
    damage_dealt.emit(defender, result.actual_damage, result.is_crit)
    
    if not defender.is_alive:
        unit_defeated.emit(defender)
    
    return result

## 玩家回合
func player_turn(skill_mult: float = 1.0) -> DamageResult:
    if current_phase != CombatPhase.PLAYER_TURN:
        return null
    
    var result := attack(player, enemy, skill_mult)
    
    if not enemy.is_alive:
        _end_combat(true)
    else:
        _change_phase(CombatPhase.ENEMY_TURN)
    
    return result

## 敌人回合
func enemy_turn(skill_mult: float = 1.0) -> DamageResult:
    if current_phase != CombatPhase.ENEMY_TURN:
        return null
    
    var result := attack(enemy, player, skill_mult)
    
    if not player.is_alive:
        _end_combat(false)
    else:
        _change_phase(CombatPhase.PLAYER_TURN)
    
    return result

## 切换阶段
func _change_phase(new_phase: CombatPhase) -> void:
    current_phase = new_phase
    phase_changed.emit(new_phase)

## 结束战斗
func _end_combat(victory: bool) -> void:
    if victory:
        _change_phase(CombatPhase.VICTORY)
    else:
        _change_phase(CombatPhase.DEFEAT)
    
    combat_ended.emit(victory)

## 获取战斗状态描述
func get_combat_status() -> String:
    var status := "阶段: %s\n" % _get_phase_name()
    status += "玩家: %s\n" % player.get_stats_text()
    status += "敌人: %s" % enemy.get_stats_text()
    return status

## 获取阶段名称
func _get_phase_name() -> String:
    match current_phase:
        CombatPhase.PREPARATION: return "准备"
        CombatPhase.PLAYER_TURN: return "玩家回合"
        CombatPhase.ENEMY_TURN: return "敌人回合"
        CombatPhase.VICTORY: return "胜利"
        CombatPhase.DEFEAT: return "失败"
        _: return "未知"

## 是否可以继续
func can_continue() -> bool:
    return current_phase == CombatPhase.PLAYER_TURN or current_phase == CombatPhase.ENEMY_TURN

## 跳过当前回合
func skip_turn() -> void:
    if current_phase == CombatPhase.PLAYER_TURN:
        _change_phase(CombatPhase.ENEMY_TURN)
    elif current_phase == CombatPhase.ENEMY_TURN:
        _change_phase(CombatPhase.PLAYER_TURN)
