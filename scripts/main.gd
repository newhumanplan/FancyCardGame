extends Control

## 主场景 - 大巴扎风格卡牌游戏
## 重构：移除 ATK/DEF，按原版大巴扎 1:1 复刻

## 预加载英雄数据
const HeroDataClass = preload("res://scripts/data/hero_data.gd")
const EventManagerClass = preload("res://scripts/data/event_manager.gd")
const PassiveSkillDataClass = preload("res://scripts/data/passive_skill.gd")
const EndingManagerClass = preload("res://scripts/data/ending_manager.gd")

## 底部常驻层引用（Y: 50%~100%），三场景共享
var bottom_resident_layer: Control = null
var bottom_hp_bar: ProgressBar = null
var bottom_hp_label: Label = null
var bottom_gold_label: Label = null
var bottom_chest_icon: Control = null

## 事件管理器
var event_manager = EventManagerClass.new()

## 当前随机事件ID（用于随机事件选项）
var _current_random_event_id: String = ""
var _current_event_options: Array[Dictionary] = []

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
	_create_bottom_resident_layer()
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
	var warrior = HeroDataClass.new()
	warrior.hero_name = "战士"
	warrior.hero_type = HeroDataClass.HeroType.WARRIOR
	warrior.max_hp = 120
	warrior.crit_chance = 0.05
	# 战士被动技能: 铁壁
	warrior.passive_skill_name = "铁壁"
	warrior.passive_skill_description = "增加生命值上限"
	warrior.passive_bonus_type = "health"
	warrior.passive_bonus_value = 20

	# 装备2个英雄专属被动技能
	var ps1 = PassiveSkillDataClass.new()
	ps1.skill_name = "铁壁"
	ps1.description = "坚韧体质，生命值上限+20"
	ps1.effect_type = PassiveSkillDataClass.EffectType.HEALTH_BONUS
	ps1.effect_value = 20.0
	warrior.passive_skills.append(ps1)

	var ps2 = PassiveSkillDataClass.new()
	ps2.skill_name = "战斗本能"
	ps2.description = "丰富的战斗经验，暴击率+2%"
	ps2.effect_type = PassiveSkillDataClass.EffectType.CRIT_BONUS
	ps2.effect_value = 2.0
	warrior.passive_skills.append(ps2)

	GameManager.select_hero(warrior)
	_apply_passive_skills(warrior)
	_on_game_started()

func _on_mage_selected() -> void:
	var mage = HeroDataClass.new()
	mage.hero_name = "法师"
	mage.hero_type = HeroDataClass.HeroType.MAGE
	mage.max_hp = 80
	mage.crit_chance = 0.15
	# 法师被动技能: 奥术智慧
	mage.passive_skill_name = "奥术智慧"
	mage.passive_skill_description = "增加暴击率"
	mage.passive_bonus_type = "crit"
	mage.passive_bonus_value = 10

	# 装备2个英雄专属被动技能
	var ps1 = PassiveSkillDataClass.new()
	ps1.skill_name = "奥术智慧"
	ps1.description = "对魔法的深刻理解，暴击率+5%"
	ps1.effect_type = PassiveSkillDataClass.EffectType.CRIT_BONUS
	ps1.effect_value = 5.0
	mage.passive_skills.append(ps1)

	var ps2 = PassiveSkillDataClass.new()
	ps2.skill_name = "魔力涌动"
	ps2.description = "魔力充沛，生命值上限+10"
	ps2.effect_type = PassiveSkillDataClass.EffectType.HEALTH_BONUS
	ps2.effect_value = 10.0
	mage.passive_skills.append(ps2)

	GameManager.select_hero(mage)
	_apply_passive_skills(mage)
	_on_game_started()

## 应用被动技能（兼容旧版+新版被动技能列表）
func _apply_passive_skills(hero: HeroData) -> void:
	# 旧版被动技能兼容
	if hero.has_passive_skill():
		match hero.passive_bonus_type:
			"health":
				GameManager.apply_skill_bonus(hero.passive_skill_name, "health", hero.passive_bonus_value)
			"crit":
				GameManager.apply_skill_bonus(hero.passive_skill_name, "crit", hero.passive_bonus_value)
		print("激活被动技能(旧版): %s" % hero.get_passive_skill_full_description())

	# 新版被动技能列表
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

## ============ 事件选择系统 ============

## 显示事件选择面板
func _show_event_panel() -> void:
	if bottom_resident_layer:
		bottom_resident_layer.visible = true
	event_panel.visible = true

## 隐藏事件选择面板
func _hide_event_panel() -> void:
	event_panel.visible = false

## 生成随机事件选项（使用 EventManager）
func _generate_event_options() -> void:
	var hour = GameManager.current_hour
	var day = GameManager.current_day

	# 使用 EventManager 生成选项
	var options: Array[Dictionary] = event_manager.generate_options(hour, day)
	_current_event_options = options
	_current_random_event_id = ""

	if options.is_empty():
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

## 事件选项被选中
func _on_event_option_1_selected() -> void:
	_handle_event_selection_by_index(0)

func _on_event_option_2_selected() -> void:
	_handle_event_selection_by_index(1)

func _on_event_option_3_selected() -> void:
	_handle_event_selection_by_index(2)

func _handle_event_selection_by_index(index: int) -> void:
	if index < 0 or index >= _current_event_options.size():
		return
	var option: Dictionary = _current_event_options[index]
	var event_type: String = str(option.get("type", ""))
	_current_random_event_id = str(option.get("event_id", ""))
	print("选择了事件: %s" % option.get("text", event_type))

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
		if bottom_resident_layer:
			bottom_resident_layer.visible = true
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
	var event_id: String = _current_random_event_id
	if event_id == "":
		var evt = event_manager._pick_random_event(day)
		if not evt.is_empty():
			event_id = str(evt.get("id", ""))
		else:
			_auto_advance_hour()
			return

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
	# ATK 标签改为显示暴击率（保持节点引用不变）
	if GameManager.selected_hero:
		atk_label.text = "暴击: %.0f%%" % (GameManager.selected_hero.crit_chance * 100)
	else:
		atk_label.text = "暴击: 5%"
	# DEF 标签改为显示物品数
	def_label.text = "物品: %d" % _get_item_count()

	# Prestige
	prestige_label.text = "Prestige: %d/%d" % [GameManager.prestige, GameManager.max_prestige]
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
	gold_label.text = "金币: %d" % GameManager.gold
	if bottom_gold_label != null:
		bottom_gold_label.text = "金币: %d" % GameManager.gold

func _on_day_changed(day: int) -> void:
	day_label.text = "Day %d" % day

func _on_hour_changed(hour: int, phase_name: String) -> void:
	hour_label.text = "[%s]" % phase_name
	round_label.text = "回合: %d / 5" % [hour + 1]

func _on_health_changed(amount: int) -> void:
	var max_hp = GameManager.get_max_health()
	hp_label.text = "HP: %d/%d" % [amount, max_hp]
	if bottom_hp_bar != null:
		bottom_hp_bar.max_value = max_hp
		bottom_hp_bar.value = amount
	if bottom_hp_label != null:
		bottom_hp_label.text = "%d/%d" % [amount, max_hp]

func _on_prestige_changed(value: int) -> void:
	prestige_label.text = "Prestige: %d/%d" % [value, GameManager.max_prestige]
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
			if has_node("EventPanel/EventVBox/EventOptions/Option1"):
				var btn = $EventPanel/EventVBox/EventOptions/Option1
				btn.pressed.emit()
		3:
			_auto_advance_hour()
		4:
			if has_node("InventoryUI"):
				$InventoryUI.visible = true

## ============ 底部常驻层 ============

func _create_bottom_resident_layer() -> void:
	bottom_resident_layer = Control.new()
	bottom_resident_layer.name = "BottomResidentLayer"
	bottom_resident_layer.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	bottom_resident_layer.offset_left = -960.0
	bottom_resident_layer.offset_top = 540.0
	bottom_resident_layer.offset_right = 960.0
	bottom_resident_layer.offset_bottom = 1080.0
	bottom_resident_layer.z_index = 10
	bottom_resident_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_resident_layer.visible = false
	add_child(bottom_resident_layer)

	_create_bottom_hp_bar()
	_create_bottom_gold()
	_on_health_changed(GameManager.player_health)
	_on_gold_changed(GameManager.gold)

func _create_bottom_hp_bar() -> void:
	var container: Control = Control.new()
	container.name = "BottomHPContainer"
	container.set_anchors_and_offsets_preset(Control.PRESET_CENTER_WIDE)
	container.offset_left = -480.0
	container.offset_top = 0.0
	container.offset_right = 480.0
	container.offset_bottom = 50.0
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_resident_layer.add_child(container)

	var bar: ProgressBar = ProgressBar.new()
	bar.name = "HPBar"
	bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_WIDE)
	bar.offset_left = -240.0
	bar.offset_top = 0.0
	bar.offset_right = 240.0
	bar.offset_bottom = 30.0
	bar.max_value = 100.0
	bar.value = 100.0
	bar.custom_minimum_size = Vector2(480.0, 30.0)
	container.add_child(bar)
	bottom_hp_bar = bar

	var label: Label = Label.new()
	label.name = "HPText"
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	label.offset_left = -50.0
	label.offset_top = 0.0
	label.offset_right = 50.0
	label.offset_bottom = 30.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text = "100/100"
	bar.add_child(label)
	bottom_hp_label = label

func _create_bottom_gold() -> void:
	var gold_container: Control = Control.new()
	gold_container.name = "BottomGoldContainer"
	gold_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER_WIDE)
	gold_container.offset_left = 500.0
	gold_container.offset_top = 0.0
	gold_container.offset_right = 900.0
	gold_container.offset_bottom = 50.0
	gold_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_resident_layer.add_child(gold_container)

	var label: Label = Label.new()
	label.name = "GoldLabel"
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_WIDE)
	label.offset_left = 0.0
	label.offset_top = 0.0
	label.offset_right = 400.0
	label.offset_bottom = 50.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.text = "金币: %d" % GameManager.gold
	gold_container.add_child(label)
	bottom_gold_label = label

	var chest: Control = Control.new()
	chest.name = "ChestIcon"
	chest.set_anchors_and_offsets_preset(Control.PRESET_CENTER_WIDE)
	chest.offset_left = 410.0
	chest.offset_top = 5.0
	chest.offset_right = 470.0
	chest.offset_bottom = 55.0
	chest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gold_container.add_child(chest)
	bottom_chest_icon = chest
