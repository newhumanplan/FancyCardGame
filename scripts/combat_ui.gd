## 战斗 UI 管理器
class_name CombatUI
extends Control

## 玩家名称标签
@onready var player_name_label: Label = $"../VBox/PlayerInfo/NameLabel"
## 玩家血条
@onready var player_hp_bar: ProgressBar = $"../VBox/PlayerInfo/HPBar"
## 玩家血量文本
@onready var player_hp_label: Label = $"../VBox/PlayerInfo/HPLabel"

## 敌人名称标签
@onready var enemy_name_label: Label = $"../VBox/EnemyInfo/NameLabel"
## 敌人血条
@onready var enemy_hp_bar: ProgressBar = $"../VBox/EnemyInfo/HPBar"
## 敌人血量文本
@onready var enemy_hp_label: Label = $"../VBox/EnemyInfo/HPLabel"

## 阶段显示
@onready var phase_label: Label = $"../VBox/PhaseLabel"

## 攻击按钮
@onready var attack_button: Button = $"../VBox/ButtonContainer/AttackButton"

## 技能按钮
@onready var skill_button: Button = $"../VBox/ButtonContainer/SkillButton"

## 战斗日志
@onready var combat_log: RichTextLabel = $"../VBox/CombatLog"

## 引用 Combat 系统
var combat: Combat

## 玩家单位引用
var player: Unit

## 敌人单位引用
var enemy: Unit

## 是否正在等待敌人回合
var waiting_for_enemy: bool = false

func _ready() -> void:
	# 连接按钮信号
	attack_button.pressed.connect(_on_attack_pressed)
	skill_button.pressed.connect(_on_skill_pressed)
	
	# 初始状态 - 按钮禁用
	set_buttons_enabled(false)

## 初始化 UI
func init(combat_system: Combat, p_player: Unit, p_enemy: Unit) -> void:
	combat = combat_system
	player = p_player
	enemy = p_enemy
	
	# 连接信号
	combat.phase_changed.connect(_on_phase_changed)
	combat.damage_dealt.connect(_on_damage_dealt)
	combat.unit_defeated.connect(_on_unit_defeated)
	combat.combat_ended.connect(_on_combat_ended)
	
	# 更新 UI 显示
	_update_unit_display()
	_update_phase_display()
	
	# 启用按钮（如果玩家回合）
	_update_button_state()
	
	# 添加初始日志
	add_log("战斗开始！")
	add_log("%s vs %s" % [player.name, enemy.name])

## 更新单位显示
func _update_unit_display() -> void:
	if player:
		player_name_label.text = player.name
		player_hp_bar.max_value = player.max_hp
		player_hp_bar.value = player.current_hp
		player_hp_label.text = "%d / %d" % [player.current_hp, player.max_hp]
	
	if enemy:
		enemy_name_label.text = enemy.name
		enemy_hp_bar.max_value = enemy.max_hp
		enemy_hp_bar.value = enemy.current_hp
		enemy_hp_label.text = "%d / %d" % [enemy.current_hp, enemy.max_hp]

## 更新阶段显示
func _update_phase_display() -> void:
	var phase_name := ""
	match combat.current_phase:
		Combat.CombatPhase.PREPARATION:
			phase_name = "准备阶段"
		Combat.CombatPhase.PLAYER_TURN:
			phase_name = "你的回合"
		Combat.CombatPhase.ENEMY_TURN:
			phase_name = "敌人回合"
		Combat.CombatPhase.VICTORY:
			phase_name = "胜利！"
		Combat.CombatPhase.DEFEAT:
			phase_name = "失败..."
	phase_label.text = phase_name

## 更新按钮状态
func _update_button_state() -> void:
	var is_player_turn := combat.current_phase == Combat.CombatPhase.PLAYER_TURN
	set_buttons_enabled(is_player_turn)

## 设置按钮启用状态
func set_buttons_enabled(enabled: bool) -> void:
	attack_button.disabled = not enabled
	skill_button.disabled = not enabled

## 添加日志
func add_log(message: String) -> void:
	combat_log.append_text(message + "\n")

## 攻击按钮回调
func _on_attack_pressed() -> void:
	if not combat or combat.current_phase != Combat.CombatPhase.PLAYER_TURN:
		return
	
	set_buttons_enabled(false)
	add_log("%s 发起攻击！" % player.name)
	
	var result = combat.player_turn(1.0)  # 普通攻击倍率 1.0
	_update_unit_display()

## 技能按钮回调
func _on_skill_pressed() -> void:
	if not combat or combat.current_phase != Combat.CombatPhase.PLAYER_TURN:
		return
	
	set_buttons_enabled(false)
	add_log("%s 使用技能！" % player.name)
	
	# 技能伤害倍率 1.5
	var result = combat.player_turn(1.5)
	_update_unit_display()

## 阶段变化回调
func _on_phase_changed(phase: Combat.CombatPhase) -> void:
	_update_phase_display()
	
	if phase == Combat.CombatPhase.ENEMY_TURN:
		waiting_for_enemy = true
		# 延迟执行敌人回合，模拟思考时间
		await get_tree().create_timer(1.0).timeout
		_execute_enemy_turn()
	elif phase == Combat.CombatPhase.PLAYER_TURN:
		waiting_for_enemy = false
		_update_button_state()

## 执行敌人回合
func _execute_enemy_turn() -> void:
	if not combat:
		return
	
	add_log("%s 的回合..." % enemy.name)
	
	# 敌人普通攻击
	var result = combat.enemy_turn(1.0)
	_update_unit_display()

## 伤害结算回调
func _on_damage_dealt(target: Unit, damage: int, is_crit: bool) -> void:
	var crit_text := " (暴击!)" if is_crit else ""
	add_log("%s 受到 %d 伤害%s" % [target.name, damage, crit_text])

## 单位死亡回调
func _on_unit_defeated(unit: Unit) -> void:
	add_log("%s 被击败！" % unit.name)

## 战斗结束回调
func _on_combat_ended(victory: bool) -> void:
	set_buttons_enabled(false)
	if victory:
		add_log("🎉 战斗胜利！")
	else:
		add_log("💀 战斗失败...")
