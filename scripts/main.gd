extends Control

## 主场景 - 大巴扎风格卡牌游戏
## 重构：移除 ATK/DEF，按原版大巴扎 1:1 复刻

## 预加载英雄数据
const HeroDataClass = preload("res://scripts/data/hero_data.gd")
const EventManagerClass = preload("res://scripts/data/event_manager.gd")
const PassiveSkillDataClass = preload("res://scripts/data/passive_skill.gd")
const EndingManagerClass = preload("res://scripts/data/ending_manager.gd")
const HeroFactory = preload("res://scripts/data/hero_factory.gd")

## 底部常驻层引用（三层布局共享）
var item_bar_layer: Control = null
var hero_bar_layer: Control = null
var hero_bar_hp_bar: ProgressBar = null
var hero_bar_hp_label: Label = null
var hero_bar_gold_label: Label = null
var hero_bar_chest_button: Control = null

## 服务实例（重构后）
var event_manager = EventManagerClass.new()

## ============ UI 节点 ============

## 顶部栏
@onready var day_label: Label = $TopBar/DayLabel
@onready var hour_label: Label = $TopBar/HourLabel
@onready var hero_label: Label = $TopBar/HeroLabel

## 属性面板
@onready var hp_label: Label = get_node_or_null("StatsPanel/HPBarLabel")
@onready var atk_label: Label = get_node_or_null("StatsPanel/ATKLabel")
@onready var def_label: Label = get_node_or_null("StatsPanel/DEFLabel")
@onready var gold_label: Label = get_node_or_null("StatsPanel/GoldLabel")
@onready var prestige_label: Label = get_node_or_null("PrestigeContainer/PrestigeLabel")
@onready var prestige_bar: ProgressBar = get_node_or_null("PrestigeContainer/PrestigeBar")

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

## 游戏结束面板
@onready var game_over_panel: PanelContainer = $GameOverPanel
@onready var game_over_title: Label = $GameOverPanel/GameOverVBox/GameOverTitle
@onready var game_over_stats: Label = $GameOverPanel/GameOverVBox/StatsLabel
@onready var restart_button: Button = $GameOverPanel/GameOverVBox/RestartButton

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
	_create_hero_bar_layer()
	print("大巴扎游戏初始化完成")

## ============ 信号连接 ============

func _connect_signals() -> void:
	# GameManager 信号
	GameManager.gold_changed.connect(_on_gold_changed)
	GameManager.day_changed.connect(_on_day_changed)
	GameManager.hour_changed.connect(_on_hour_changed)
	GameManager.health_changed.connect(_on_health_changed)
	GameManager.prestige_changed.connect(_on_prestige_changed)
	GameManager.game_over.connect(_on_game_over)
	GameManager.futura_triggered.connect(_on_futura_triggered)

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

	# 游戏结束按钮
	restart_button.pressed.connect(_on_restart_game_pressed)

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
	var warrior = HeroFactoryService.create_hero(HeroDataClass.HeroType.WARRIOR)
	GameManager.select_hero(warrior)
	_apply_passive_skills(warrior)
	_on_game_started()

func _on_mage_selected() -> void:
	var mage = HeroFactoryService.create_hero(HeroDataClass.HeroType.MAGE)
	GameManager.select_hero(mage)
	_apply_passive_skills(mage)
	_on_game_started()

## 应用被动技能（统一使用 PassiveSkillDataClass 新版）
func _apply_passive_skills(hero: HeroData) -> void:
	for ps in hero.passive_skills:
		PassiveSkillDataClass.apply_to_hero(ps, hero)

## 游戏开始
func _on_game_started() -> void:
	_hide_hero_selection()
	_show_event_panel()
	_generate_event_options()
	_update_button_visibility()
	_update_ui()
	print("游戏开始! Day %d, Hour %d - %s" % [GameManager.current_day, GameManager.current_hour, GameManager.get_current_phase_name()])
	$VBox.visible = true  # 显示游戏主UI
	# 确保 HeroBar 和 ItemBar 始终可见
	if item_bar_layer:
		item_bar_layer.visible = true
	if hero_bar_layer:
		hero_bar_layer.visible = true

## ============ 事件选择系统 ============

## 显示事件选择面板
func _show_event_panel() -> void:
	if item_bar_layer:
		item_bar_layer.visible = true
	if hero_bar_layer:
		hero_bar_layer.visible = true
	event_panel.visible = true

## 隐藏事件选择面板
func _hide_event_panel() -> void:
	event_panel.visible = false

## 生成随机事件选项（使用 EventManager）
## 由 GameFlowService.event_options_generated 信号触发
func _on_game_flow_options_generated(options: Array[Dictionary]) -> void:
	# 更新事件选项UI
	if options.is_empty():
		event_option_1.visible = false
		event_option_2.visible = false
		event_option_3.visible = false
		return

	event_option_1.text = str(options[0].get("text", ""))
	event_option_1.visible = true

	if options.size() > 1:
		event_option_2.text = str(options[1].get("text", ""))
		event_option_2.visible = true
	else:
		event_option_2.visible = false

	if options.size() > 2:
		event_option_3.text = str(options[2].get("text", ""))
		event_option_3.visible = true
	else:
		event_option_3.visible = false

func _generate_event_options() -> void:
	# 委托给 GameFlow
	GameFlowService.generate_event_options()

## 事件选项被选中
func _on_event_option_1_selected() -> void:
	_handle_event_selection_by_index(0)

func _on_event_option_2_selected() -> void:
	_handle_event_selection_by_index(1)

func _on_event_option_3_selected() -> void:
	_handle_event_selection_by_index(2)

func _handle_event_selection_by_index(index: int) -> void:
	# 通知 GameFlow 记录选择
	GameFlowService.handle_event_selection(index)
	var event_type: String = GameFlowService.get_event_type_at(index)
	print("选择了事件类型: %s" % event_type)

	match event_type:
		"shop":
			_execute_shop_event()
		"monster":
			_execute_monster_event()
		"pvp":
			_execute_pvp_event()
		"treasure":
			_execute_treasure_event()
		"camp":
			_execute_camp_event()
		"random_event":
			_execute_random_event()
		_:
			_execute_random_event()

## ============ 事件执行 ============

## 执行商店事件
func _execute_shop_event() -> void:
	print("执行商店事件")
	if GameManager.is_pvp_hour():
		print("PvP阶段不能购买!")
		_auto_advance_hour()
		return
	_open_shop_ui()

## 打开商店 UI
func _open_shop_ui() -> void:
	_write_debug("========== _open_shop_ui() 被调用 ==========")
	_write_debug("inventory_ui: " + str(inventory_ui))
	if inventory_ui and inventory_ui.has_method("get_inventory"):
		var inventory = inventory_ui.get_inventory()
		_write_debug("inventory: " + str(inventory))
		if item_bar_layer:
			item_bar_layer.visible = true
		if hero_bar_layer:
			hero_bar_layer.visible = true
		shop_ui.visible = true
		shop_ui.show_shop(inventory)
		if not shop_ui.shop_closed.is_connected(_on_shop_closed):
			shop_ui.shop_closed.connect(_on_shop_closed)
		_write_debug("商店已打开")
	else:
		_write_debug("ERROR: 无法获取背包实例")

## 写调试文件
func _write_debug(msg: String) -> void:
	print(msg)

## 商店关闭回调
func _on_shop_closed() -> void:
	print("商店已关闭，进入下一小时")
	_auto_advance_hour()

## 执行怪物事件
func _execute_monster_event() -> void:
	print("执行怪物战斗事件")
	_start_battle()

## 执行 PvP 事件
func _execute_pvp_event() -> void:
	print("执行 PvP 对战事件")
	_start_pvp_battle()

## 执行随机事件（使用 EventManager）
func _execute_random_event() -> void:
	print("执行随机事件")
	var day = GameManager.current_day

	# 如果有预选的随机事件ID，使用它；否则随机选择
	var event_id: String = GameFlowService.get_selected_event_id()
	if event_id == "":
		var evt = GameFlowService.execute_random_event_fallback(day)
		if evt.is_empty():
			_auto_advance_hour()
			return
		else:
			event_id = str(evt.get("id", ""))

	var result = event_manager.execute_random_event(event_id, day, GameManager)
	print("随机事件: %s" % result)
	_auto_advance_hour()

## 执行宝库事件（使用 EventManager）
func _execute_treasure_event() -> void:
	print("执行宝库事件")
	var day = GameManager.current_day
	var result = event_manager.execute_treasure_event(day, GameManager)
	print("宝库事件: %s" % result)
	_auto_advance_hour()

## 执行营地事件（使用 EventManager）
func _execute_camp_event() -> void:
	print("执行营地事件")
	var day = GameManager.current_day
	var result = event_manager.execute_camp_event(day, GameManager)
	print("营地事件: %s" % result)
	_auto_advance_hour()

## ============ 战斗系统 ============

func _start_battle() -> void:
	if GameManager.selected_hero == null:
		print("错误: 未选择英雄!")
		return

	_hide_event_panel()
	battle_ui.visible = true
	# 确保底部常驻层在进入战斗时可见
	if item_bar_layer:
		item_bar_layer.visible = true
	if hero_bar_layer:
		hero_bar_layer.visible = true
	battle_ui.start_battle(null, false, 0)

	if not battle_ui.battle_ended.is_connected(_on_battle_ended):
		battle_ui.battle_ended.connect(_on_battle_ended)

	print("开始怪物战斗!")

func _start_pvp_battle() -> void:
	if GameManager.selected_hero == null:
		print("错误: 未选择英雄!")
		return

	_hide_event_panel()
	battle_ui.visible = true
	# 确保底部常驻层在进入战斗时可见
	if item_bar_layer:
		item_bar_layer.visible = true
	if hero_bar_layer:
		hero_bar_layer.visible = true

	var enemy_bonus = randi() % 5 + 1
	battle_ui.start_battle(null, true, enemy_bonus)

	if not battle_ui.battle_ended.is_connected(_on_battle_ended):
		battle_ui.battle_ended.connect(_on_battle_ended)

	print("开始 PvP 对战!")

## 战斗结束回调
func _on_battle_ended(won: bool, gold_reward: int) -> void:
	print("战斗结束: 胜利=%s, 金币=%d" % [won, gold_reward])
	_show_event_panel()
	_auto_advance_hour()

## 计算属性（物品触发系统下显示物品总属性）
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
		print("物品属性 - 伤害: %d, 护盾: %d, 治疗: %d" % [total_damage, total_shield, total_heal])

## ============ 自动流转 ============

func _auto_advance_hour() -> void:
	print("事件完成，自动进入下一小时...")
	await get_tree().create_timer(1.0).timeout
	GameManager.next_hour()
	print("进入 Hour %d: %s" % [GameManager.current_hour, GameManager.get_current_phase_name()])
	_update_ui()
	_generate_event_options()
	_update_button_visibility()

## ============ 按钮可见性控制 ============

func _hide_game_buttons() -> void:
	shop_button.visible = false
	battle_button.visible = false
	next_hour_button.visible = false

func _update_button_visibility() -> void:
	var hour = GameManager.current_hour

	if hour == 0 or hour == 1 or hour == 3 or hour == 4:
		shop_button.visible = true
		battle_button.visible = false
	elif hour == 2:
		shop_button.visible = false
		battle_button.visible = true
	elif hour == 5:
		shop_button.visible = false
		battle_button.visible = true

	next_hour_button.visible = false

## ============ UI 更新 ============

func _update_ui() -> void:
	# 金币
	if gold_label != null:
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
	if hp_label != null:
		hp_label.text = "HP: %d/%d" % [GameManager.player_health, max_hp]
	# ATK 标签改为显示暴击率（保持节点引用不变）
	if atk_label != null:
		if GameManager.selected_hero:
			atk_label.text = "暴击: %.0f%%" % (GameManager.selected_hero.crit_chance * 100)
		else:
			atk_label.text = "暴击: 5%"
	# DEF 标签改为显示物品数
	if def_label != null:
		def_label.text = "物品: %d" % _get_item_count()

	# Prestige
	if prestige_label != null:
		prestige_label.text = "Prestige: %d/%d" % [GameManager.prestige, GameManager.max_prestige]
	if prestige_bar != null:
		prestige_bar.max_value = GameManager.max_prestige
		prestige_bar.value = GameManager.prestige

	# 回合
	round_label.text = "回合: %d / 5" % [GameManager.current_hour + 1]

## 获取背包物品数量
func _get_item_count() -> int:
	if inventory_ui and inventory_ui.has_method("get_inventory"):
		return inventory_ui.get_inventory().get_item_count()
	return 0

## ============ 信号回调 ============

func _on_gold_changed(amount: int) -> void:
	if gold_label != null:
		gold_label.text = "金币: %d" % GameManager.gold
	if hero_bar_gold_label != null:
		hero_bar_gold_label.text = "💰 %d" % GameManager.gold

func _on_day_changed(day: int) -> void:
	day_label.text = "Day %d" % day

func _on_hour_changed(hour: int, phase_name: String) -> void:
	hour_label.text = "[%s]" % phase_name
	round_label.text = "回合: %d / 5" % [hour + 1]

func _on_health_changed(amount: int) -> void:
	var max_hp = GameManager.get_max_health()
	if hp_label != null:
		hp_label.text = "HP: %d/%d" % [amount, max_hp]
	if hero_bar_hp_bar != null:
		hero_bar_hp_bar.max_value = max_hp
		hero_bar_hp_bar.value = amount
	if hero_bar_hp_label != null:
		hero_bar_hp_label.text = "%d/%d" % [amount, max_hp]

func _on_prestige_changed(value: int) -> void:
	if prestige_label != null:
		prestige_label.text = "Prestige: %d/%d" % [value, GameManager.max_prestige]
	if prestige_bar != null:
		prestige_bar.value = value

## 游戏结束回调
func _on_game_over(won: bool) -> void:
	# 使用 EndingManager 判定结局
	var ending = EndingManagerClass.determine_ending(GameManager)
	var title = EndingManagerClass.get_ending_title(ending)

	game_over_title.text = "%s — %s" % [title, ("胜利" if won else "失败")]
	if won:
		game_over_title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	else:
		game_over_title.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	print("%s" % EndingManagerClass.get_ending_description(ending))

	game_over_stats.text = EndingManagerClass.generate_summary(GameManager, ending)

	_show_game_over_panel()
	_hide_event_panel()
	_hide_game_buttons()
	$VBox.visible = false

func _show_game_over_panel() -> void:
	game_over_panel.visible = true

func _hide_game_over_panel() -> void:
	game_over_panel.visible = false

func _on_restart_game_pressed() -> void:
	GameManager.reset_stats()
	_hide_game_over_panel()
	_show_hero_selection()
	_hide_game_buttons()
	_update_ui()

## ============ Futura 事件系统 ============

func _on_futura_triggered() -> void:
	_hide_event_panel()
	# 用现有 EventPanel 显示3个 Futura 选项
	event_option_1.text = "🔮 Fate's Bounty: +20 Gold"
	event_option_1.visible = true
	event_option_2.text = "🔮 Fate's Crossroads: 随机附魔"
	event_option_2.visible = true
	event_option_3.text = "🔮 Fate's Legacy: 升级铜/银物品到金级"
	event_option_3.visible = true
	# 临时替换按钮回调为 Futura 选项
	if event_option_1.pressed.is_connected(_on_event_option_1_selected):
		event_option_1.pressed.disconnect(_on_event_option_1_selected)
	if event_option_2.pressed.is_connected(_on_event_option_2_selected):
		event_option_2.pressed.disconnect(_on_event_option_2_selected)
	if event_option_3.pressed.is_connected(_on_event_option_3_selected):
		event_option_3.pressed.disconnect(_on_event_option_3_selected)
	event_option_1.pressed.connect(_on_futura_bounty)
	event_option_2.pressed.connect(_on_futura_crossroads)
	event_option_3.pressed.connect(_on_futura_legacy)
	print("⭐ Futura 事件触发!")

func _on_futura_bounty() -> void:
	GameManager.add_gold(20)
	print("🔮 Fate's Bounty: +20 Gold")
	_restore_event_connections()
	_auto_advance_hour()

func _on_futura_crossroads() -> void:
	# MVP: 随机附魔简化为增加暴击率
	if GameManager.selected_hero:
		GameManager.selected_hero.crit_chance += 0.03
	print("🔮 Fate's Crossroads: 随机附魔 (暴击+3%%)")
	_restore_event_connections()
	_auto_advance_hour()

func _on_futura_legacy() -> void:
	# MVP: 升级物品简化为增加暴击率
	if GameManager.selected_hero:
		GameManager.selected_hero.crit_chance += 0.05
	print("🔮 Fate's Legacy: 升级物品品质 (暴击+5%%)")
	_restore_event_connections()
	_auto_advance_hour()

func _restore_event_connections() -> void:
	event_panel.visible = false
	if event_option_1.pressed.is_connected(_on_futura_bounty):
		event_option_1.pressed.disconnect(_on_futura_bounty)
	if event_option_2.pressed.is_connected(_on_futura_crossroads):
		event_option_2.pressed.disconnect(_on_futura_crossroads)
	if event_option_3.pressed.is_connected(_on_futura_legacy):
		event_option_3.pressed.disconnect(_on_futura_legacy)
	if not event_option_1.pressed.is_connected(_on_event_option_1_selected):
		event_option_1.pressed.connect(_on_event_option_1_selected)
	if not event_option_2.pressed.is_connected(_on_event_option_2_selected):
		event_option_2.pressed.connect(_on_event_option_2_selected)
	if not event_option_3.pressed.is_connected(_on_event_option_3_selected):
		event_option_3.pressed.connect(_on_event_option_3_selected)

## ============ 按钮回调（备用） ============

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
	print("下一小时按钮被点击")
	_auto_advance_hour()


## ============ 验收测试入口 (临时) ============

var _test_state := 0

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F12:
				_advance_test_state()

func _advance_test_state() -> void:
	_test_state += 1
	print("[TEST] Advance to state %d" % _test_state)

	match _test_state:
		1:
			_on_warrior_selected()
		2:
			# 第一次必定触发商店（确定性测试）
			print("[TEST] Forcing shop event for deterministic testing...")
			_execute_shop_event()
		3:
			_auto_advance_hour()
		4:
			if has_node("InventoryUI"):
				$InventoryUI.visible = true

## ============ HeroBar 层（Y: 80%~100%）============

func _create_hero_bar_layer() -> void:
	hero_bar_layer = Control.new()
	hero_bar_layer.name = "HeroBarLayer"
	# 使用 anchors 定位，Y:80%-100%，不受视口大小影响
	hero_bar_layer.anchor_top = 0.80
	hero_bar_layer.anchor_bottom = 1.0
	hero_bar_layer.anchor_left = 0.0
	hero_bar_layer.anchor_right = 1.0
	hero_bar_layer.offset_left = 0.0
	hero_bar_layer.offset_top = 0.0
	hero_bar_layer.offset_right = 0.0
	hero_bar_layer.offset_bottom = 0.0
	hero_bar_layer.z_index = 10
	hero_bar_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero_bar_layer.visible = false
	add_child(hero_bar_layer)

	# 底部实色背景，确保可见
	var bg: ColorRect = ColorRect.new()
	bg.name = "HeroBarBackground"
	bg.color = Color(0.08, 0.08, 0.12, 0.95)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hero_bar_layer.add_child(bg)

	# HP条（左上角，Y:0-30%）
	var hp_bar: ProgressBar = ProgressBar.new()
	hp_bar.name = "HPBar"
	hp_bar.anchor_top = 0.0
	hp_bar.anchor_bottom = 0.5
	hp_bar.anchor_left = 0.0
	hp_bar.anchor_right = 0.3
	hp_bar.offset_left = 0.0
	hp_bar.offset_top = 0.0
	hp_bar.offset_right = 0.0
	hp_bar.offset_bottom = 0.0
	hp_bar.max_value = 100.0
	hp_bar.value = 100.0
	hero_bar_layer.add_child(hp_bar)
	hero_bar_hp_bar = hp_bar

	var hp_label: Label = Label.new()
	hp_label.name = "HPLabel"
	hp_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hp_label.offset_left = 0.0
	hp_label.offset_top = 0.0
	hp_label.offset_right = 0.0
	hp_label.offset_bottom = 0.0
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_label.text = "%d/%d" % [GameManager.player_health, GameManager.get_max_health()]
	hp_bar.add_child(hp_label)
	hero_bar_hp_label = hp_label

	# 金币Label（右上角）
	var gold_label: Label = Label.new()
	gold_label.name = "GoldLabel"
	gold_label.anchor_top = 0.0
	gold_label.anchor_bottom = 0.5
	gold_label.anchor_left = 0.7
	gold_label.anchor_right = 1.0
	gold_label.offset_left = 0.0
	gold_label.offset_top = 0.0
	gold_label.offset_right = 0.0
	gold_label.offset_bottom = 0.0
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gold_label.text = "💰 %d" % GameManager.gold
	hero_bar_layer.add_child(gold_label)
	hero_bar_gold_label = gold_label

	# 角色头像（中央偏左）
	var avatar: TextureRect = TextureRect.new()
	avatar.name = "HeroAvatar"
	avatar.anchor_top = 0.0
	avatar.anchor_bottom = 1.0
	avatar.anchor_left = 0.32
	avatar.anchor_right = 0.42
	avatar.offset_left = 0.0
	avatar.offset_top = 0.0
	avatar.offset_right = 0.0
	avatar.offset_bottom = 0.0
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var avatar_path = "res://assets/art/ui/ui_avatar_warrior.png"
	if GameManager.selected_hero != null:
		var ht = GameManager.selected_hero.hero_type
		if ht == 1:  # MAGE
			avatar_path = "res://assets/art/ui/ui_avatar_mage.png"
	var avatar_tex = load(avatar_path)
	if avatar_tex == null:
		avatar_tex = AtlasTexture.new()
		if ResourceLoader.exists("res://assets/art/ui/pvp/pvp_avatar_frame.png"):
			avatar_tex.atlas = load("res://assets/art/ui/pvp/pvp_avatar_frame.png")
			avatar_tex.region = Rect2(0, 0, 64, 64)
	avatar.texture = avatar_tex
	hero_bar_layer.add_child(avatar)

	# 3个被动技能图标（右侧）
	var passive_anchors = [0.55, 0.60, 0.65]
	for idx in range(3):
		var passive_icon: TextureRect = TextureRect.new()
		passive_icon.name = "Passive_%d" % idx
		passive_icon.anchor_top = 0.0
		passive_icon.anchor_bottom = 0.7
		passive_icon.anchor_left = passive_anchors[idx]
		passive_icon.anchor_right = passive_anchors[idx] + 0.04
		passive_icon.offset_left = 0.0
		passive_icon.offset_top = 0.0
		passive_icon.offset_right = 0.0
		passive_icon.offset_bottom = 0.0
		passive_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		passive_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		var placeholder = StyleBoxFlat.new()
		placeholder.bg_color = Color(0.3, 0.3, 0.5, 0.9)
		placeholder.set_corner_radius_all(4)
		passive_icon.add_theme_stylebox_override("panel", placeholder)
		hero_bar_layer.add_child(passive_icon)

	_on_health_changed(GameManager.player_health)
	_on_gold_changed(GameManager.gold)
