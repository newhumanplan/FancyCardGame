class_name BattleUI
extends Control

## 战斗面板 UI - 管理战斗界面和自动战斗循环

## GameManager 引用
var game_manager: Node

## 战斗系统引用
var battle_system: Node

## 背包系统引用
var inventory: LinearInventory = null

## 敌人数据
var current_monster: MonsterData = null

## 敌人攻击力加成（用于PvP）
var enemy_attack_bonus: int = 0

## 是否为 PvP 战斗
var is_pvp: bool = false

## 战斗结果缓存
var _last_battle_won: bool = false
var _last_gold_reward: int = 0

## PvP 对手暴击率（运行时）
var enemy_crit_chance: float = 0.0

## 战斗状态
var is_battle_active: bool = false

## 战斗计时器
var battle_timer: float = 0.0

## 回合间隔（0.5秒）
const BATTLE_TICK: float = 0.5

## 玩家攻击冷却
var player_attack_cooldown: float = 0.0

## 敌人攻击冷却
var enemy_attack_cooldown: float = 0.0

## 信号
signal battle_ended(won: bool, gold_reward: int)
signal battle_log(message: String)

## ============ UI 节点 ============

@onready var battle_panel: PanelContainer = $BattlePanel
@onready var title_label: Label = $BattlePanel/VBox/TitleLabel
@onready var player_name_label: Label = $BattlePanel/VBox/BattleArea/PlayerArea/PlayerNameLabel
@onready var player_hp_bar: ProgressBar = $BattlePanel/VBox/BattleArea/PlayerArea/PlayerHPBar
@onready var player_hp_label: Label = $BattlePanel/VBox/BattleArea/PlayerArea/PlayerHPBar/PlayerHPText
@onready var player_atk_label: Label = $BattlePanel/VBox/BattleArea/PlayerArea/PlayerATKLabel
@onready var enemy_name_label: Label = $BattlePanel/VBox/BattleArea/EnemyArea/EnemyNameLabel
@onready var enemy_hp_bar: ProgressBar = $BattlePanel/VBox/BattleArea/EnemyArea/EnemyHPBar
@onready var enemy_hp_label: Label = $BattlePanel/VBox/BattleArea/EnemyArea/EnemyHPBar/EnemyHPText
@onready var enemy_atk_label: Label = $BattlePanel/VBox/BattleArea/EnemyArea/EnemyATKLabel
@onready var battle_log_label: RichTextLabel = $BattlePanel/VBox/BattleLogArea/BattleLogLabel
@onready var result_label: Label = $BattlePanel/VBox/ResultLabel
@onready var auto_battle_check: CheckButton = $BattlePanel/VBox/AutoBattleCheck
## 继续按钮（战斗结束后显示）
@onready var continue_button: Button = $BattlePanel/VBox/ContinueButton

## 自动战斗开关
var auto_battle: bool = true

func _ready() -> void:
	# 获取 GameManager
	game_manager = get_node("/root/GameManager")
	
	# 获取战斗系统 (autoload)
	battle_system = get_node("/root/BattleSystem")
	
	# 初始隐藏战斗面板
	battle_panel.visible = false
	
	# 自动战斗默认开启
	auto_battle_check.button_pressed = true
	auto_battle_check.toggled.connect(_on_auto_battle_toggled)
	
	# 继续按钮信号连接
	continue_button.pressed.connect(_on_continue_pressed)
	
	print("BattleUI 已初始化")

## 自动战斗开关回调
func _on_auto_battle_toggled(toggled_on: bool) -> void:
	auto_battle = toggled_on

## 开始战斗
func start_battle(monster: MonsterData = null, pvp: bool = false, enemy_atk_bonus: int = 0) -> void:
	is_pvp = pvp
	enemy_attack_bonus = enemy_atk_bonus
	
	# 获取背包系统
	var main = get_parent()
	if main.has_node("InventoryUI"):
		inventory = main.get_node("InventoryUI").get_inventory()
	
	# 生成怪物或设置 PvP 对手
	if not is_pvp:
		current_monster = _generate_random_monster()
	else:
		current_monster = _create_pvp_enemy()
	
	# 重置状态
	player_attack_cooldown = 0.0
	enemy_attack_cooldown = 0.0
	
	# 启动战斗系统
	battle_system.start_battle()
	
	# 显示战斗面板
	_show_battle_panel()
	
	# 更新 UI
	_update_battle_ui()
	
	# 开始自动战斗
	is_battle_active = true
	_log("⚔️ 战斗开始! %s 出现!" % current_monster.monster_name)

## 生成随机怪物
func _generate_random_monster() -> MonsterData:
	var monster = MonsterData.new()
	var day = game_manager.current_day
	
	# 根据天数调整怪物难度
	var tier = MonsterData.MonsterTier.TIER_1
	if day >= 3:
		tier = [MonsterData.MonsterTier.TIER_1, MonsterData.MonsterTier.TIER_2].pick_random()
	if day >= 5:
		tier = [MonsterData.MonsterTier.TIER_1, MonsterData.MonsterTier.TIER_2, MonsterData.MonsterTier.TIER_3].pick_random()
	
	match tier:
		MonsterData.MonsterTier.TIER_1:
			monster.monster_name = "史莱姆"
			monster.max_hp = 30 + day * 5
			monster.attack = 5 + day
			monster.defense = 0 + day / 2
			monster.gold_reward_min = 5 + day
			monster.gold_reward_max = 10 + day * 2
		MonsterData.MonsterTier.TIER_2:
			monster.monster_name = "哥布林"
			monster.max_hp = 50 + day * 8
			monster.attack = 10 + day * 2
			monster.defense = 2 + day
			monster.gold_reward_min = 10 + day * 2
			monster.gold_reward_max = 20 + day * 3
		MonsterData.MonsterTier.TIER_3:
			monster.monster_name = "食人魔"
			monster.max_hp = 80 + day * 10
			monster.attack = 15 + day * 2
			monster.defense = 5 + day
			monster.gold_reward_min = 20 + day * 3
			monster.gold_reward_max = 40 + day * 5
	
	monster.tier = tier
	monster.current_hp = monster.max_hp
	return monster

## 创建 PvP 对手（随机英雄 + 随机物品）
func _create_pvp_enemy() -> MonsterData:
	var monster = MonsterData.new()
	
	# 随机选择对手英雄类型
	var hero_types = [0, 1]  # WARRIOR = 0, MAGE = 1
	var random_hero_type = hero_types.pick_random()
	
	if random_hero_type == 0:
		# 战士对手
		monster.monster_name = "PvP 战士"
		monster.max_hp = 120
		monster.attack = 15 + enemy_attack_bonus
		monster.defense = 10
		enemy_crit_chance = 0.05 + randf() * 0.1
	else:
		# 法师对手
		monster.monster_name = "PvP 法师"
		monster.max_hp = 80
		monster.attack = 25 + enemy_attack_bonus
		monster.defense = 5
		enemy_crit_chance = 0.15 + randf() * 0.15
	
	# 根据天数增加难度
	var day = game_manager.current_day
	monster.max_hp += day * 5
	monster.attack += day
	monster.defense += day / 2
	
	# 随机物品加成（模拟对手有物品）
	var random_item_bonus = randi() % 10
	monster.attack += random_item_bonus
	
	monster.gold_reward_min = 0
	monster.gold_reward_max = 0
	monster.current_hp = monster.max_hp
	
	# 记录对手信息
	if is_pvp:
		_log("⚔️ 对手: %s (ATK: %d, DEF: %d, HP: %.0f, 暴击率: %.0f%%)" % [monster.monster_name, monster.attack, monster.defense, monster.max_hp, enemy_crit_chance * 100])
	
	return monster

## 显示战斗面板
func _show_battle_panel() -> void:
	battle_panel.visible = true
	result_label.visible = false
	continue_button.visible = false
	battle_log_label.clear()

## 隐藏战斗面板
func _hide_battle_panel() -> void:
	battle_panel.visible = false
	is_battle_active = false

## 战斗循环（每帧更新）
func _process(delta: float) -> void:
	if not is_battle_active:
		return
	
	# 自动战斗关闭时不自动进行
	if not auto_battle:
		return
	
	# 更新战斗计时器
	battle_timer += delta
	
	# 每 0.5 秒执行一个回合
	if battle_timer >= BATTLE_TICK:
		battle_timer = 0.0
		_execute_battle_tick()

## 执行一个战斗回合
func _execute_battle_tick() -> void:
	# 检查战斗是否结束
	if current_monster == null or not current_monster.is_alive():
		_on_battle_win()
		return
	
	if game_manager.player_health <= 0:
		_on_battle_lose()
		return
	
	# 更新战斗系统的持续效果
	battle_system._process(BATTLE_TICK)
	
	# 更新物品冷却并触发
	if inventory:
		battle_system.update_cooldowns(inventory, BATTLE_TICK)
	
	# 玩家攻击
	_player_attack()
	
	# 检查敌人是否死亡
	if current_monster != null and not current_monster.is_alive():
		_on_battle_win()
		return
	
	# 敌人攻击
	_enemy_attack()
	
	# 更新 UI
	_update_battle_ui()
	
	# 检查玩家是否死亡
	if game_manager.player_health <= 0:
		_on_battle_lose()
		return

## 玩家攻击
func _player_attack() -> void:
	# 计算玩家攻击力（基础 + 物品加成）
	var player_atk = _calculate_player_attack()
	
	# 造成伤害
	var actual_damage = current_monster.take_damage(player_atk)
	_log("⚔️ 你对 %s 造成 %d 伤害!" % [current_monster.monster_name, actual_damage])
	
	# 检查暴击
	if _check_crit():
		var bonus_damage = int(player_atk * 0.5)
		current_monster.take_damage(bonus_damage)
		_log("💥 暴击! 额外 %d 伤害!" % bonus_damage)

## 敌人攻击
func _enemy_attack() -> void:
	if current_monster == null or not current_monster.is_alive():
		return
	
	# 计算敌人攻击力
	var enemy_atk = current_monster.attack
	
	# 造成伤害
	var actual_damage = game_manager.take_damage(enemy_atk)
	_log("%s 对你造成 %d 伤害!" % [current_monster.monster_name, actual_damage])
	
	# 检查是否游戏结束
	if game_manager.player_health <= 0:
		_log("💀 你被击败了!")

## 计算玩家攻击力
func _calculate_player_attack() -> int:
	var base_atk = game_manager.player_attack
	var item_atk = 0
	
	# 获取物品攻击力加成
	if inventory:
		for item in inventory.items:
			if item != null:
				item_atk += item.get_rarity_adjusted_damage()
	
	return base_atk + item_atk

## 检查是否暴击
func _check_crit() -> bool:
	var crit_chance = 0.05  # 基础暴击率
	if game_manager.selected_hero:
		crit_chance = game_manager.selected_hero.crit_chance
	return randf() < crit_chance

## 更新战斗 UI
func _update_battle_ui() -> void:
	# 玩家信息
	var max_hp = game_manager.get_max_health()
	player_name_label.text = game_manager.selected_hero.hero_name if game_manager.selected_hero else "玩家"
	player_hp_bar.max_value = max_hp
	player_hp_bar.value = game_manager.player_health
	player_hp_label.text = "%d/%d" % [game_manager.player_health, max_hp]
	player_atk_label.text = "ATK: %d" % _calculate_player_attack()
	
	# 敌人信息
	if current_monster:
		enemy_name_label.text = current_monster.monster_name
		enemy_hp_bar.max_value = current_monster.max_hp
		enemy_hp_bar.value = current_monster.current_hp
		enemy_hp_label.text = "%d/%d" % [current_monster.current_hp, current_monster.max_hp]
		enemy_atk_label.text = "ATK: %d" % current_monster.attack

## 记录战斗日志
func _log(message: String) -> void:
	battle_log_label.append_text(message + "\n")
	battle_log_label.scroll_to_line(battle_log_label.get_line_count() - 1)
	battle_log.emit(message)
	print(message)

## 战斗胜利
func _on_battle_win() -> void:
	is_battle_active = false
	
	# 计算金币奖励
	var gold_reward = 0
	if not is_pvp and current_monster:
		gold_reward = current_monster.get_gold_reward()
		game_manager.add_gold(gold_reward)
		game_manager.on_battle_win()
	
	# 显示胜利
	result_label.text = "🎉 胜利! 获得 %d 金币!" % gold_reward if not is_pvp else "🎉 胜利!"
	result_label.visible = true
	_log("🎉 战斗胜利! 获得 %d 金币!" % gold_reward)
	
	# 缓存战斗结果
	_last_battle_won = true
	_last_gold_reward = gold_reward
	
	# 关闭战斗系统
	battle_system.end_battle()
	
	# 显示继续按钮，等待玩家点击
	continue_button.visible = true

## 战斗失败
func _on_battle_lose() -> void:
	is_battle_active = false
	
	# PvP 失败扣除 Prestige
	if is_pvp:
		game_manager.on_pvp_lose()
	else:
		game_manager.on_battle_lose()
	
	# 显示失败
	result_label.text = "💀 失败! Prestige 已扣除" if is_pvp else "💀 战斗失败!"
	result_label.visible = true
	_log("💀 战斗失败!")
	
	# 缓存战斗结果
	_last_battle_won = false
	_last_gold_reward = 0
	
	# 关闭战斗系统
	battle_system.end_battle()
	
	# 显示继续按钮，等待玩家点击
	continue_button.visible = true

## 继续按钮回调 - 隐藏战斗面板并发出信号
func _on_continue_pressed() -> void:
	_hide_battle_panel()
	battle_ended.emit(_last_battle_won, _last_gold_reward)

## 获取战斗系统实例（供外部调用）
func get_battle_system() -> Node:
	return battle_system
