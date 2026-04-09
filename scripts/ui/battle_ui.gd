class_name BattleUI
extends Control

## 战斗面板 UI - 管理战斗界面和自动战斗循环
## 重构：纯物品触发战斗，移除独立攻击逻辑

## GameManager 引用
var game_manager: Node

## 战斗系统引用
var battle_system: Node

## 背包系统引用
var inventory: LinearInventory = null

## 敌人数据
var current_monster: MonsterData = null

## 是否为 PvP 战斗
var is_pvp: bool = false

## 战斗结果缓存
var _last_battle_won: bool = false
var _last_gold_reward: int = 0

## 战斗状态
var is_battle_active: bool = false

## 战斗计时器
var battle_timer: float = 0.0

## 回合间隔（0.5秒）
const BATTLE_TICK: float = 0.5

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

	# 初始隐藏战斗面板，设置鼠标穿透
	battle_panel.visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 自动战斗默认开启
	auto_battle_check.button_pressed = true
	auto_battle_check.toggled.connect(_on_auto_battle_toggled)

	# 继续按钮信号连接
	continue_button.pressed.connect(_on_continue_pressed)

	# 连接战斗系统信号
	if battle_system.has_signal("item_triggered"):
		battle_system.item_triggered.connect(_on_item_triggered)
	if battle_system.has_signal("monster_item_triggered"):
		battle_system.monster_item_triggered.connect(_on_monster_item_triggered)
	if battle_system.has_signal("effect_applied"):
		battle_system.effect_applied.connect(_on_effect_applied)

	print("BattleUI 已初始化")

## 自动战斗开关回调
func _on_auto_battle_toggled(toggled_on: bool) -> void:
	auto_battle = toggled_on

## ============ 战斗系统信号回调 ============

## 玩家物品触发
func _on_item_triggered(item_name: String, damage: int, is_crit: bool, target: String) -> void:
	var crit_text: String = "（暴击!）" if is_crit else ""
	_log("🗡️ [%s] 触发！造成 %d 伤害%s" % [item_name, damage, crit_text])

## 怪物物品触发
func _on_monster_item_triggered(monster_name: String, item_name: String, damage: int) -> void:
	_log("👹 [%s] 的 [%s] 触发！造成 %d 伤害" % [monster_name, item_name, damage])

## 物品效果触发（护盾/治疗）
func _on_effect_applied(item_name: String, effect_type: String, value: int, target: String) -> void:
	match effect_type:
		"shield":
			_log("🛡️ [%s] 触发！获得 %d 护盾" % [item_name, value])
		"heal":
			_log("💚 [%s] 触发！恢复 %d 生命" % [item_name, value])

## ============ 战斗控制 ============

## 开始战斗
func start_battle(monster: MonsterData = null, pvp: bool = false, enemy_atk_bonus: int = 0) -> void:
	is_pvp = pvp

	# 获取背包系统
	var main = get_parent()
	if main.has_node("InventoryUI"):
		inventory = main.get_node("InventoryUI").get_inventory()

	# 生成怪物或设置 PvP 对手
	if not is_pvp:
		current_monster = _generate_random_monster()
	else:
		current_monster = _create_pvp_enemy()

	# 启动战斗系统（传入怪物和背包）
	battle_system.start_battle(current_monster, inventory)

	# 显示战斗面板
	_show_battle_panel()

	# 拦截鼠标事件（战斗进行中）
	mouse_filter = Control.MOUSE_FILTER_STOP

	# 更新 UI
	_update_battle_ui()

	# 开始自动战斗
	is_battle_active = true
	_log("⚔️ 战斗开始! %s 出现!" % current_monster.monster_name)

	# 显示怪物物品信息
	if current_monster.monster_items.size() > 0:
		for mi in current_monster.monster_items:
			_log("   → %s (伤害:%d, CD:%.1fs)" % [mi["name"], mi["damage"], mi["cooldown"]])

const MonsterAIClass = preload("res://scripts/data/monster_ai.gd")

## ============ 怪物生成 ============

## 根据 MonsterTier 分配 AI 模式
func _assign_monster_ai(monster: MonsterData, day: int) -> void:
	match monster.tier:
		MonsterData.MonsterTier.TIER_1:
			# Tier 1: 蜂群或激进
			monster.ai = MonsterAIClass.create_swarm()
		MonsterData.MonsterTier.TIER_2:
			# Tier 2: 技术或防御
			if randf() < 0.5:
				monster.ai = MonsterAIClass.create_technical()
			else:
				monster.ai = MonsterAIClass.create_defensive()
		MonsterData.MonsterTier.TIER_3:
			# Tier 3: Boss AI
			monster.ai = MonsterAIClass.create_boss()
	print("👹 [%s] AI模式: %s" % [monster.monster_name, monster.ai.get_mode_name()])

## 生成随机怪物（使用物品系统）
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
			monster.max_hp = 80 + day * 15
			monster.gold_reward_min = 5 + day
			monster.gold_reward_max = 10 + day * 2
			# 史莱姆物品：酸液喷射
			monster.monster_items = [
				{"name": "酸液喷射", "damage": 8 + day, "cooldown": 3.0, "current_cooldown": 3.0}
			]
		MonsterData.MonsterTier.TIER_2:
			monster.monster_name = "哥布林"
			monster.max_hp = 140 + day * 25
			monster.gold_reward_min = 10 + day * 2
			monster.gold_reward_max = 20 + day * 3
			# 哥布林物品：石斧
			monster.monster_items = [
				{"name": "石斧", "damage": 12 + day * 2, "cooldown": 3.5, "current_cooldown": 3.5}
			]
		MonsterData.MonsterTier.TIER_3:
			monster.monster_name = "食人魔"
			monster.max_hp = 200 + day * 30
			monster.gold_reward_min = 20 + day * 3
			monster.gold_reward_max = 40 + day * 5
			# 食人魔物品：重锤 + 碎骨（2个物品）
			monster.monster_items = [
				{"name": "重锤", "damage": 18 + day * 2, "cooldown": 4.0, "current_cooldown": 4.0},
				{"name": "碎骨", "damage": 10 + day, "cooldown": 3.0, "current_cooldown": 3.0}
			]

	monster.tier = tier
	monster.current_hp = monster.max_hp
	_assign_monster_ai(monster, day)
	return monster

## 创建 PvP 对手（使用物品系统）
func _create_pvp_enemy() -> MonsterData:
	var monster = MonsterData.new()

	# 随机选择对手英雄类型
	var hero_types = [0, 1]  # WARRIOR = 0, MAGE = 1
	var random_hero_type = hero_types.pick_random()
	var day = game_manager.current_day

	if random_hero_type == 0:
		# PvP 战士对手
		monster.monster_name = "PvP 战士"
		monster.max_hp = 200 + day * 5
		# 战士物品：剑 + 盾
		monster.monster_items = [
			{"name": "战士之剑", "damage": 15 + day, "cooldown": 3.0, "current_cooldown": 3.0},
			{"name": "铁盾反击", "damage": 5 + day, "cooldown": 2.5, "current_cooldown": 2.5}
		]
	else:
		# PvP 法师对手
		monster.monster_name = "PvP 法师"
		monster.max_hp = 160 + day * 5
		# 法师物品：法杖（高伤慢CD）
		monster.monster_items = [
			{"name": "奥术法杖", "damage": 22 + day * 2, "cooldown": 4.5, "current_cooldown": 4.5}
		]

	monster.gold_reward_min = 0
	monster.gold_reward_max = 0
	monster.current_hp = monster.max_hp

	# PvP 对手使用激进型 AI
	monster.ai = MonsterAIClass.create_aggressive()

	if is_pvp:
		_log("⚔️ 对手: %s (HP: %.0f, 物品数: %d)" % [
			monster.monster_name, monster.max_hp, monster.monster_items.size()])

	return monster

## ============ UI 管理 ============

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
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 战斗结束由 battle_system.end_battle() 处理

## ============ 战斗循环 ============

## 战斗循环（每帧更新）
func _process(delta: float) -> void:
	if not is_battle_active:
		return

	# 自动战斗关闭时不自动进行
	if not auto_battle:
		return

	# 更新战斗计时器
	battle_timer += delta

	# 每 0.5 秒执行一个 tick
	if battle_timer >= BATTLE_TICK:
		battle_timer = 0.0
		_execute_battle_tick()

## 执行一个战斗 tick（纯物品触发）
func _execute_battle_tick() -> void:
	# 委托给战斗系统处理
	var battle_ended: bool = battle_system.execute_battle_tick()

	# 更新 UI
	_update_battle_ui()

	# 检查战斗结果
	if battle_ended:
		var result = battle_system.get_battle_result()
		if result["won"]:
			_on_battle_win()
		else:
			_on_battle_lose()

## 更新战斗 UI
func _update_battle_ui() -> void:
	# 玩家信息
	var max_hp = game_manager.get_max_health()
	player_name_label.text = game_manager.selected_hero.hero_name if game_manager.selected_hero else "玩家"
	player_hp_bar.max_value = max_hp
	player_hp_bar.value = game_manager.player_health
	player_hp_label.text = "%d/%d" % [game_manager.player_health, max_hp]
	# ATK 标签改为显示暴击率（保持节点引用不变，避免修改 .tscn）
	if game_manager.selected_hero:
		player_atk_label.text = "暴击: %.0f%%" % (game_manager.selected_hero.crit_chance * 100)
	else:
		player_atk_label.text = ""

	# 敌人信息
	if current_monster:
		enemy_name_label.text = current_monster.monster_name
		enemy_hp_bar.max_value = current_monster.max_hp
		enemy_hp_bar.value = current_monster.current_hp
		enemy_hp_label.text = "%d/%d" % [current_monster.current_hp, current_monster.max_hp]
		# 敌人 ATK 标签改为显示怪物物品数
		var item_count = current_monster.monster_items.size()
		enemy_atk_label.text = "物品: %d" % item_count

## 记录战斗日志
func _log(message: String) -> void:
	battle_log_label.append_text(message + "\n")
	battle_log_label.scroll_to_line(battle_log_label.get_line_count() - 1)
	battle_log.emit(message)
	print(message)

## ============ 战斗结果 ============

## 战斗胜利
func _on_battle_win() -> void:
	is_battle_active = false

	# 计算金币奖励
	var gold_reward = 0
	if is_pvp:
		game_manager.on_pvp_win()
	elif current_monster:
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
