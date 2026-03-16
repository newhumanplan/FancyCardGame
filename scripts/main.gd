extends Control

## 主场景 - 大巴扎风格卡牌游戏

## 预加载英雄数据
const HeroDataClass = preload("res://scripts/data/hero_data.gd")

## ============ UI 节点 ============

## 顶部栏
@onready var day_label: Label = $TopBar/DayLabel
@onready var hour_label: Label = $TopBar/HourLabel
@onready var hero_label: Label = $TopBar/HeroLabel

## 属性面板
@onready var hp_label: Label = $StatsPanel/HPBarLabel
@onready var atk_label: Label = $StatsPanel/ATKLabel
@onready var def_label: Label = $StatsPanel/DEFLabel
@onready var gold_label: Label = $StatsPanel/GoldLabel
@onready var prestige_label: Label = $PrestigeContainer/PrestigeLabel
@onready var prestige_bar: ProgressBar = $PrestigeContainer/PrestigeBar

## 英雄选择面板
@onready var hero_select_panel: PanelContainer = $HeroSelectPanel
@onready var warrior_button: Button = $HeroSelectPanel/HeroSelectVBox/Heroes/WarriorButton
@onready var mage_button: Button = $HeroSelectPanel/HeroSelectVBox/Heroes/MageButton

## 主界面区域
@onready var title_label: Label = $VBox/Title
@onready var round_label: Label = $VBox/RoundLabel

## 按钮区域
@onready var button_box: HBoxContainer = $VBox/ButtonBox
@onready var shop_button: Button = $VBox/ButtonBox/ShopButton
@onready var battle_button: Button = $VBox/ButtonBox/BattleButton
@onready var next_hour_button: Button = $VBox/ButtonBox/NextHourButton

## 事件选择面板（新增）
@onready var event_panel: PanelContainer = $EventPanel
@onready var event_option_1: Button = $EventPanel/EventVBox/EventOptions/Option1
@onready var event_option_2: Button = $EventPanel/EventVBox/EventOptions/Option2
@onready var event_option_3: Button = $EventPanel/EventVBox/EventOptions/Option3

## 背包 UI
@onready var inventory_ui: Control = $InventoryUI

## 商店 UI
@onready var shop_ui: Control = $ShopUI

## 战斗 UI
@onready var battle_ui: Control = $BattleUI

## 当前是否在英雄选择阶段
var is_in_hero_selection: bool = true

## 当前事件选项（用于自动流转）
var current_event_type: String = ""

func _ready() -> void:
	# 隐藏全屏UI（避免遮挡英雄选择）
	shop_ui.visible = false
	battle_ui.visible = false
	
	_connect_signals()
	_setup_buttons()
	_show_hero_selection()
	_hide_game_buttons()
	_update_ui()
	print("大巴扎游戏初始化完成")

## ============ 信号连接 ============

func _connect_signals() -> void:
	# GameManager 信号
	GameManager.gold_changed.connect(_on_gold_changed)
	GameManager.day_changed.connect(_on_day_changed)
	GameManager.hour_changed.connect(_on_hour_changed)
	GameManager.health_changed.connect(_on_health_changed)
	GameManager.attack_changed.connect(_on_attack_changed)
	GameManager.defense_changed.connect(_on_defense_changed)
	GameManager.prestige_changed.connect(_on_prestige_changed)
	GameManager.game_over.connect(_on_game_over)

## ============ 按钮设置 ============

func _setup_buttons() -> void:
	# 英雄选择按钮
	warrior_button.pressed.connect(_on_warrior_selected)
	mage_button.pressed.connect(_on_mage_selected)
	
	# 游戏按钮
	shop_button.pressed.connect(_on_shop_pressed)
	battle_button.pressed.connect(_on_battle_pressed)
	next_hour_button.pressed.connect(_on_next_hour_pressed)
	
	# 事件选项按钮
	event_option_1.pressed.connect(_on_event_option_1_selected)
	event_option_2.pressed.connect(_on_event_option_2_selected)
	event_option_3.pressed.connect(_on_event_option_3_selected)

## ============ 英雄选择 ============

func _show_hero_selection() -> void:
	is_in_hero_selection = true
	hero_select_panel.visible = true
	_hide_game_buttons()
	_hide_event_panel()

func _hide_hero_selection() -> void:
	is_in_hero_selection = false
	hero_select_panel.visible = false

func _on_warrior_selected() -> void:
	var warrior = HeroDataClass.new()
	warrior.hero_name = "战士"
	warrior.hero_type = HeroDataClass.HeroType.WARRIOR
	warrior.max_hp = 120
	warrior.attack = 15
	warrior.defense = 10
	warrior.crit_chance = 0.05
	# 战士被动技能: 铁壁
	warrior.passive_skill_name = "铁壁"
	warrior.passive_skill_description = "减少受到的伤害"
	warrior.passive_bonus_type = "defense"
	warrior.passive_bonus_value = 3
	
	GameManager.select_hero(warrior)
	_apply_passive_skill(warrior)
	_on_game_started()

func _on_mage_selected() -> void:
	var mage = HeroDataClass.new()
	mage.hero_name = "法师"
	mage.hero_type = HeroDataClass.HeroType.MAGE
	mage.max_hp = 80
	mage.attack = 25
	mage.defense = 5
	mage.crit_chance = 0.15
	# 法师被动技能: 奥术智慧
	mage.passive_skill_name = "奥术智慧"
	mage.passive_skill_description = "增加暴击率"
	mage.passive_bonus_type = "crit"
	mage.passive_bonus_value = 10
	
	GameManager.select_hero(mage)
	_apply_passive_skill(mage)
	_on_game_started()

## 应用被动技能
func _apply_passive_skill(hero: HeroData) -> void:
	if not hero.has_passive_skill():
		return
	
	match hero.passive_bonus_type:
		"attack":
			GameManager.apply_skill_bonus(hero.passive_skill_name, "attack", hero.passive_bonus_value)
		"defense":
			GameManager.apply_skill_bonus(hero.passive_skill_name, "defense", hero.passive_bonus_value)
		"health":
			GameManager.apply_skill_bonus(hero.passive_skill_name, "health", hero.passive_bonus_value)
	
	print("激活被动技能: %s" % hero.get_passive_skill_full_description())

## 游戏开始
func _on_game_started() -> void:
	_hide_hero_selection()
	_show_event_panel()
	_generate_event_options()
	_update_button_visibility()
	_update_ui()
	print("游戏开始! Day %d, Hour %d - %s" % [GameManager.current_day, GameManager.current_hour, GameManager.get_current_phase_name()])
	$VBox.visible = true  # 显示游戏主UI

## ============ 事件选择系统 ============

## 显示事件选择面板
func _show_event_panel() -> void:
	event_panel.visible = true

## 隐藏事件选择面板
func _hide_event_panel() -> void:
	event_panel.visible = false

## 生成随机事件选项
func _generate_event_options() -> void:
	var hour = GameManager.current_hour
	
	# Hour 4 固定为 PvP 战斗
	if hour == 4:
		event_option_1.text = "⚔️ PvP 对战"
		event_option_1.visible = true
		event_option_2.visible = false
		event_option_3.visible = false
		current_event_type = "pvp"
		return
	
	# 其他 Hour: 随机生成 3 个选项
	var options = []
	
	# 商人选项（购买物品）
	options.append({"type": "shop", "text": "🏪 商人", "desc": "购买物品"})
	
	# 怪物选项（PvE 战斗）
	options.append({"type": "monster", "text": "👹 怪物", "desc": "PvE 战斗"})
	
	# 随机事件选项
	var event_types = ["随机事件", "宝库", "营地", "商人", "怪物"]
	var random_event = event_types.pick_random()
	match random_event:
		"随机事件":
			options.append({"type": "random_event", "text": "✨ 随机事件", "desc": "随机事件"})
		"宝库":
			options.append({"type": "treasure", "text": "💎 宝库", "desc": "获取宝藏"})
		"营地":
			options.append({"type": "camp", "text": "⛺ 营地", "desc": "休息恢复"})
		"商人":
			options.append({"type": "shop", "text": "🏪 商人", "desc": "购买物品"})
		"怪物":
			options.append({"type": "monster", "text": "👹 怪物", "desc": "PvE 战斗"})
	
	# 打乱顺序
	options.shuffle()
	
	# 显示选项
	event_option_1.text = options[0].text
	event_option_1.visible = true
	current_event_type = options[0].type
	
	if options.size() > 1:
		event_option_2.text = options[1].text
		event_option_2.visible = true
	else:
		event_option_2.visible = false
	
	if options.size() > 2:
		event_option_3.text = options[2].text
		event_option_3.visible = true
	else:
		event_option_3.visible = false

## 事件选项被选中
func _on_event_option_1_selected() -> void:
	_handle_event_selection(event_option_1.text)

func _on_event_option_2_selected() -> void:
	_handle_event_selection(event_option_2.text)

func _on_event_option_3_selected() -> void:
	_handle_event_selection(event_option_3.text)

## 处理事件选择
func _handle_event_selection(event_text: String) -> void:
	print("选择了事件: %s" % event_text)
	
	if "商人" in event_text or "🏪" in event_text:
		print("[DEBUG] 检测到商人事件，准备打开商店")
		_execute_shop_event()
	elif "怪物" in event_text or "👹" in event_text:
		_execute_monster_event()
	elif "PvP" in event_text or "⚔️" in event_text:
		_execute_pvp_event()
	elif "随机事件" in event_text or "✨" in event_text:
		_execute_random_event()
	elif "宝库" in event_text or "💎" in event_text:
		_execute_treasure_event()
	elif "营地" in event_text or "⛺" in event_text:
		_execute_camp_event()
	else:
		# 未知事件，默认执行
		_execute_random_event()

## ============ 事件执行 ============

## 执行商店事件
func _execute_shop_event() -> void:
	print("执行商店事件")
	# 根据当前 Hour 判断是否可购买
	if GameManager.is_pvp_hour():
		print("PvP阶段不能购买!")
		# 仍然进入下一小时
		_auto_advance_hour()
		return
	
	# 打开商店 UI
	_open_shop_ui()

## 打开商店 UI
func _open_shop_ui() -> void:
	_write_debug("========== _open_shop_ui() 被调用 ==========")
	_write_debug("inventory_ui: " + str(inventory_ui))
	if inventory_ui and inventory_ui.has_method("get_inventory"):
		var inventory = inventory_ui.get_inventory()
		_write_debug("inventory: " + str(inventory))
		shop_ui.visible = true  # 确保商店 UI 可见
		shop_ui.show_shop(inventory)
		
		# 设置关闭回调：商店关闭后进入下一小时
		shop_ui.shop_closed.connect(_on_shop_closed)
		_write_debug("商店已打开")
	else:
		_write_debug("ERROR: 无法获取背包实例")

## 写调试文件
func _write_debug(msg: String) -> void:
	print(msg)
	var file = FileAccess.open("user://debug.log", FileAccess.READ_WRITE)
	if file:
		file.seek_end()
		file.store_line(msg)
		file.close()

## 商店关闭回调
func _on_shop_closed() -> void:
	print("商店已关闭，进入下一小时")
	_auto_advance_hour()

## 执行怪物事件
func _execute_monster_event() -> void:
	print("执行怪物战斗事件")
	# 开始战斗
	_start_battle()

## 执行 PvP 事件
func _execute_pvp_event() -> void:
	print("执行 PvP 对战事件")
	# 开始 PvP 战斗
	_start_pvp_battle()

## 执行随机事件
func _execute_random_event() -> void:
	print("执行随机事件")
	var events = ["gold_boost", "heal", "damage", "treasure"]
	var random_event = events.pick_random()
	
	match random_event:
		"gold_boost":
			GameManager.add_gold(5)
			print("随机事件: 获得 5 金币!")
		"heal":
			GameManager.heal(10)
			print("随机事件: 恢复 10 HP!")
		"damage":
			GameManager.take_damage(5)
			print("随机事件: 受到 5 点伤害!")
		"treasure":
			GameManager.add_gold(10)
			print("随机事件: 发现宝藏，获得 10 金币!")
	
	# 事件完成后自动进入下一小时
	_auto_advance_hour()

## 执行宝库事件
func _execute_treasure_event() -> void:
	print("执行宝库事件")
	GameManager.add_gold(15)
	print("宝库事件: 获得 15 金币!")
	_auto_advance_hour()

## 执行营地事件
func _execute_camp_event() -> void:
	print("执行营地事件")
	GameManager.heal(20)
	print("营地事件: 休息恢复 20 HP!")
	_auto_advance_hour()

## ============ 战斗系统 ============

func _start_battle() -> void:
	if GameManager.selected_hero == null:
		print("错误: 未选择英雄!")
		return
	
	# 隐藏事件面板
	_hide_event_panel()
	
	# 确保战斗 UI 可见
	battle_ui.visible = true
	
	# 开始真正的战斗
	battle_ui.start_battle(null, false, 0)
	
	# 连接战斗结束回调
	if not battle_ui.battle_ended.is_connected(_on_battle_ended):
		battle_ui.battle_ended.connect(_on_battle_ended)
	
	print("开始怪物战斗!")

func _start_pvp_battle() -> void:
	if GameManager.selected_hero == null:
		print("错误: 未选择英雄!")
		return
	
	# 隐藏事件面板
	_hide_event_panel()
	
	# 确保战斗 UI 可见
	battle_ui.visible = true
	
	# 根据玩家当前属性生成 PvP 对手（稍微强一点）
	var enemy_bonus = randi() % 5 + 1  # 1-5 的随机加成
	battle_ui.start_battle(null, true, enemy_bonus)
	
	# 连接战斗结束回调
	if not battle_ui.battle_ended.is_connected(_on_battle_ended):
		battle_ui.battle_ended.connect(_on_battle_ended)
	
	print("开始 PvP 对战!")

## 战斗结束回调
func _on_battle_ended(won: bool, gold_reward: int) -> void:
	print("战斗结束: 胜利=%s, 金币=%d" % [won, gold_reward])
	# 显示事件面板并进入下一小时
	_show_event_panel()
	_auto_advance_hour()

## 计算属性
func _calculate_stats() -> void:
	if inventory_ui and inventory_ui.has_method("get_inventory"):
		var inventory = inventory_ui.get_inventory()
		var total_damage = 0
		var total_shield = 0
		var total_heal = 0
		for item in inventory.items:
			if item != null:
				total_damage += item.damage
				total_shield += item.shield
				total_heal += item.heal
		print("物品加成 - 攻击力: %d, 防御力: %d, 治疗: %d" % [total_damage, total_shield, total_heal])
		
		var total_attack = GameManager.player_attack + total_damage
		print("最终攻击力: %d" % total_attack)

## ============ 自动流转 ============

## 自动进入下一小时
func _auto_advance_hour() -> void:
	print("事件完成，自动进入下一小时...")
	
	# 延迟一点时间，让玩家看到事件结果
	await get_tree().create_timer(1.0).timeout
	
	# 进入下一小时
	GameManager.next_hour()
	print("进入 Hour %d: %s" % [GameManager.current_hour, GameManager.get_current_phase_name()])
	
	# 更新 UI
	_update_ui()
	
	# 生成新的事件选项
	_generate_event_options()
	_update_button_visibility()

## ============ 按钮可见性控制 ============

## 隐藏游戏按钮
func _hide_game_buttons() -> void:
	shop_button.visible = false
	battle_button.visible = false
	next_hour_button.visible = false

## 更新按钮可见性（根据当前 Hour）
func _update_button_visibility() -> void:
	var hour = GameManager.current_hour
	
	# Hour 0, 1, 3, 4: 商人阶段，显示商店按钮
	if hour == 0 or hour == 1 or hour == 3 or hour == 4:
		shop_button.visible = true
		battle_button.visible = false
	# Hour 2: 怪物战斗，显示战斗按钮
	elif hour == 2:
		shop_button.visible = false
		battle_button.visible = true
	# Hour 5: PvP，显示战斗按钮
	elif hour == 5:
		shop_button.visible = false
		battle_button.visible = true
	
	# 始终隐藏"下一小时"按钮（使用自动流转）
	next_hour_button.visible = false

## ============ UI 更新 ============

func _update_ui() -> void:
	# 金币
	gold_label.text = "金币: %d" % GameManager.gold
	
	# Day/Hour
	day_label.text = "Day %d" % GameManager.current_day
	hour_label.text = "[%s]" % GameManager.get_current_phase_name()
	
	# 英雄信息
	if GameManager.selected_hero != null:
		hero_label.text = "%s (%s)" % [GameManager.selected_hero.hero_name, GameManager.selected_hero.get_type_name()]
	else:
		hero_label.text = "未选择英雄"
	
	# 属性
	var max_hp = GameManager.get_max_health()
	hp_label.text = "HP: %d/%d" % [GameManager.player_health, max_hp]
	atk_label.text = "ATK: %d" % GameManager.player_attack
	def_label.text = "DEF: %d" % GameManager.player_defense
	
	# Prestige
	prestige_label.text = "Prestige: %d/%d" % [GameManager.prestige, GameManager.max_prestige]
	prestige_bar.max_value = GameManager.max_prestige
	prestige_bar.value = GameManager.prestige
	
	# 回合
	round_label.text = "回合: %d / 5" % [GameManager.current_hour + 1]

## ============ 信号回调 ============

func _on_gold_changed(amount: int) -> void:
	gold_label.text = "金币: %d" % GameManager.gold

func _on_day_changed(day: int) -> void:
	day_label.text = "Day %d" % day

func _on_hour_changed(hour: int, phase_name: String) -> void:
	hour_label.text = "[%s]" % phase_name
	round_label.text = "回合: %d / 5" % [hour + 1]

func _on_health_changed(amount: int) -> void:
	var max_hp = GameManager.get_max_health()
	hp_label.text = "HP: %d/%d" % [amount, max_hp]

func _on_attack_changed(value: int) -> void:
	atk_label.text = "ATK: %d" % value

func _on_defense_changed(value: int) -> void:
	def_label.text = "DEF: %d" % value

func _on_prestige_changed(value: int) -> void:
	prestige_label.text = "Prestige: %d/%d" % [value, GameManager.max_prestige]
	prestige_bar.value = value

## 游戏结束（胜利）回调
func _on_game_over(won: bool) -> void:
	if won:
		title_label.text = "🎉 10 胜达成! 你赢了!"
		print("🎉 游戏胜利! 10 胜达成!")
		# 禁用事件面板
		_hide_event_panel()

## ============ 按钮回调（备用，保留以防需要直接点击）===========

func _on_shop_pressed() -> void:
	print("商店按钮被点击")
	_execute_shop_event()

func _on_battle_pressed() -> void:
	print("战斗按钮被点击")
	if GameManager.selected_hero == null:
		print("请先选择英雄!")
		return
	
	if not GameManager.is_battle_hour():
		print("当前不是战斗阶段!")
		return
	
	if GameManager.current_hour == 5:
		_execute_pvp_event()
	else:
		_execute_monster_event()

func _on_next_hour_pressed() -> void:
	# 此按钮已被隐藏，保留以防需要手动触发
	print("下一小时按钮被点击（已禁用自动流转）")
	_auto_advance_hour()

