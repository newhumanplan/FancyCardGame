extends Control

## 主场景 - 大巴扎风格卡牌游戏
## 重构：移除 ATK/DEF，按原版大巴扎 1:1 复刻

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

	GameManager.select_hero(warrior)
	_apply_passive_skill(warrior)
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

	GameManager.select_hero(mage)
	_apply_passive_skill(mage)
	_on_game_started()

## 应用被动技能
func _apply_passive_skill(hero: HeroData) -> void:
	if not hero.has_passive_skill():
		return

	match hero.passive_bonus_type:
		"health":
			GameManager.apply_skill_bonus(hero.passive_skill_name, "health", hero.passive_bonus_value)
		"crit":
			GameManager.apply_skill_bonus(hero.passive_skill_name, "crit", hero.passive_bonus_value)

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
		shop_ui.visible = true
		shop_ui.show_shop(inventory)
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

## 执行随机事件
func _execute_random_event() -> void:
	print("执行随机事件")
	var day = GameManager.current_day
	var events = [
		"merchant_bonus",
		"healing_fountain",
		"pickpocket",
		"treasure",
		"heal",
		"bandits",
		"wounded_hero",
		"storm",
		"strange_merchant",
		"ancient_shrine",
		"thief_guild",
		"blessed_rest",
	]
	var random_event = events.pick_random()

	match random_event:
		"merchant_bonus":
			GameManager.add_gold(8 + day * 2)
			print("随机事件: 慷慨商人! 获得 %d 金币!" % (8 + day * 2))
		"healing_fountain":
			var heal_amount = GameManager.get_max_health() / 4
			GameManager.heal(heal_amount)
			print("随机事件: 治愈之泉! 恢复 %d HP!" % heal_amount)
		"pickpocket":
			var stolen = mini(GameManager.gold, 5 + day * 2)
			GameManager.spend_gold(stolen)
			print("随机事件: 遭遇小偷! 损失 %d 金币!" % stolen)
		"treasure":
			GameManager.add_gold(10 + day * 3)
			print("随机事件: 发现隐藏宝藏! 获得 %d 金币!" % (10 + day * 3))
		"heal":
			GameManager.heal(15 + day * 2)
			print("随机事件: 遇到好心旅人! 恢复 %d HP!" % (15 + day * 2))
		"bandits":
			var damage = 5 + day * 3
			GameManager.take_damage(damage)
			print("随机事件: 遭遇盗贼! 受到 %d 点伤害!" % damage)
		"wounded_hero":
			GameManager.add_prestige(3)
			GameManager.add_gold(5)
			print("随机事件: 救助受伤英雄! 获得 5 金币，+3 声望!")
		"storm":
			var lost = 3 + day * 2
			GameManager.spend_gold(lost)
			GameManager.take_damage(3)
			print("随机事件: 暴风雨! 损失 %d 金币，受到 3 点伤害!" % lost)
		"strange_merchant":
			GameManager.add_gold(20 + day * 3)
			GameManager.take_damage(5)
			print("随机事件: 神秘商人! 获得 %d 金币但受到诅咒损失 5 HP!" % (20 + day * 3))
		"ancient_shrine":
			# 古老祭坛改为增加暴击率（不再是 ATK）
			var bonus_crit = 0.02 + float(day) * 0.005
			if GameManager.selected_hero:
				GameManager.selected_hero.crit_chance += bonus_crit
			print("随机事件: 古老祭坛! 暴击率 +%.1f%% (永久)!" % (bonus_crit * 100))
		"thief_guild":
			var stolen = 5 + day * 2
			GameManager.spend_gold(stolen)
			print("随机事件: 盗贼公会! 被收取保护费 %d 金币!" % stolen)
		"blessed_rest":
			var heal_amount = GameManager.get_max_health() / 3
			GameManager.heal(heal_amount)
			GameManager.add_gold(5)
			print("随机事件: 受到祝福的休息! 恢复 %d HP，获得 5 金币!" % heal_amount)

	_auto_advance_hour()

## 执行宝库事件
func _execute_treasure_event() -> void:
	print("执行宝库事件")
	var day = GameManager.current_day
	var gold = 15 + day * 5
	GameManager.add_gold(gold)
	print("宝库事件: 发现古代宝库! 获得 %d 金币!" % gold)
	_auto_advance_hour()

## 执行营地事件
func _execute_camp_event() -> void:
	print("执行营地事件")
	var day = GameManager.current_day
	var heal = 20 + day * 5
	GameManager.heal(heal)
	GameManager.add_prestige(2)
	print("营地事件: 营地休息! 恢复 %d HP，+2 声望!" % heal)
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

func _on_day_changed(day: int) -> void:
	day_label.text = "Day %d" % day

func _on_hour_changed(hour: int, phase_name: String) -> void:
	hour_label.text = "[%s]" % phase_name
	round_label.text = "回合: %d / 5" % [hour + 1]

func _on_health_changed(amount: int) -> void:
	var max_hp = GameManager.get_max_health()
	hp_label.text = "HP: %d/%d" % [amount, max_hp]

func _on_prestige_changed(value: int) -> void:
	prestige_label.text = "Prestige: %d/%d" % [value, GameManager.max_prestige]
	prestige_bar.value = value

## 游戏结束回调
func _on_game_over(won: bool) -> void:
	if won:
		game_over_title.text = "🎉 游戏胜利!"
		game_over_title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
		print("🎉 游戏胜利! 10 胜达成!")
	else:
		game_over_title.text = "💀 游戏失败!"
		game_over_title.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		print("💀 游戏失败!")

	game_over_stats.text = (
		"存活天数: %d\n总金币: %d\nPvP胜场: %d/10\n总胜利: %d\n总失败: %d"
		% [GameManager.current_day, GameManager.stats_total_gold_earned,
		   GameManager.pvp_wins,
		   GameManager.stats_total_wins, GameManager.stats_total_losses]
	)

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
