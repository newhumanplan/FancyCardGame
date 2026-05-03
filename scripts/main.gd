extends Control

## 主场景 - 大巴扎风格卡牌游戏
## 重构：移除 ATK/DEF，按原版大巴扎 1:1 复刻

## 预加载英雄数据
const HeroDataClass = preload("res://scripts/data/hero_data.gd")
const EventManagerClass = preload("res://scripts/data/event_manager.gd")
const PassiveSkillDataClass = preload("res://scripts/data/passive_skill.gd")
const EndingManagerClass = preload("res://scripts/data/ending_manager.gd")
const HeroFactory = preload("res://scripts/data/hero_factory.gd")
const LinearInventoryClass = preload("res://scripts/data/linear_inventory.gd")
const ItemDataClass = preload("res://scripts/data/item_data.gd")
const ItemAcquisitionClass = preload("res://scripts/data/item_acquisition.gd")
const BazaarContentClass = preload("res://scripts/data/bazaar_content.gd")
const PvpGhostServiceClass = preload("res://scripts/services/pvp_ghost_service.gd")
const GhostSnapshotEditorClass = preload("res://scripts/ui/ghost_snapshot_editor.gd")
const FUTURA_ART_PATH: String = "res://assets/art/events/wiki/futura.png"

## 玩家背包引用（指向 InventoryUI 的 inventory，避免两套独立系统）
var player_inventory: LinearInventoryClass = null  # 已废弃，改用 $InventoryUI.get_inventory()

## Inventory UI 引用
@onready var inventory_ui: Control = $InventoryUI

## Bazaar shell 引用（统一主流程 UI 骨架）
@onready var bazaar_shell: Control = $BazaarShell

## 底部常驻层引用（三层布局共享）
var hero_bar_layer: Control = null
var hero_bar_hp_bar: ProgressBar = null
var hero_bar_hp_label: Label = null
var hero_bar_gold_label: Label = null
var hero_bar_income_label: Label = null
var hero_bar_level_label: Label = null
var hero_bar_chest_button: Control = null

## 服务实例（重构后）
var event_manager = EventManagerClass.new()

## ============ UI 节点 ============

## 顶部栏（旧 UI 已移除）
var day_label: Label = null
var hour_label: Label = null
var hero_label: Label = null

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
@onready var mak_button: Button = $HeroSelectPanel/HeroSelectVBox/Heroes/MakButton
@onready var heroes_button_container: Container = $HeroSelectPanel/HeroSelectVBox/Heroes
var bazaar_hero_buttons: Dictionary = {}

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
var active_merchant_view: Control = null
var active_ghost_editor: Control = null
var _active_special_choice_mode: String = ""

func _ready() -> void:
	# 隐藏全屏UI（避免遮挡英雄选择）
	inventory_ui.visible = false
	shop_ui.visible = false
	battle_ui.visible = false
	bazaar_shell.setup(GameManager, inventory_ui)
	if not bazaar_shell.option_selected.is_connected(_handle_event_selection_by_index):
		bazaar_shell.option_selected.connect(_handle_event_selection_by_index)
	if not bazaar_shell.right_action_pressed.is_connected(_on_shell_right_action_pressed):
		bazaar_shell.right_action_pressed.connect(_on_shell_right_action_pressed)

	_connect_inventory_signals()
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
	GameManager.income_changed.connect(_on_income_changed)
	GameManager.xp_changed.connect(_on_xp_changed)
	GameManager.level_changed.connect(_on_level_changed)
	GameManager.level_reward_applied.connect(_on_level_reward_applied)
	GameManager.game_over.connect(_on_game_over)
	GameManager.futura_triggered.connect(_on_futura_triggered)
	if not GameFlowService.event_options_generated.is_connected(_on_game_flow_options_generated):
		GameFlowService.event_options_generated.connect(_on_game_flow_options_generated)

func _connect_inventory_signals() -> void:
	var inventory: LinearInventoryClass = _get_player_inventory()
	if inventory != null and not inventory.inventory_changed.is_connected(_on_player_inventory_changed):
		inventory.inventory_changed.connect(_on_player_inventory_changed)

func _get_player_inventory() -> LinearInventoryClass:
	if bazaar_shell != null and bazaar_shell.has_method("get_player_inventory"):
		var shell_inventory: Resource = bazaar_shell.get_player_inventory()
		if shell_inventory is LinearInventoryClass:
			return shell_inventory as LinearInventoryClass
	if inventory_ui != null and inventory_ui.has_method("get_inventory"):
		return inventory_ui.get_inventory()
	return null

func _get_stash_inventory() -> LinearInventoryClass:
	if bazaar_shell != null and bazaar_shell.has_method("get_stash_inventory"):
		var stash_inventory: Resource = bazaar_shell.get_stash_inventory()
		if stash_inventory is LinearInventoryClass:
			return stash_inventory as LinearInventoryClass
	return null

## ============ 按钮设置 ============

func _setup_buttons() -> void:
	# 英雄选择按钮
	warrior_button.pressed.connect(_on_warrior_selected)
	mage_button.pressed.connect(_on_mage_selected)
	mak_button.pressed.connect(_on_mak_selected)
	_setup_bazaar_hero_buttons()

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
	_close_ghost_editor()
	bazaar_shell.hide_run_shell()
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

func _on_mak_selected() -> void:
	_on_bazaar_hero_selected(HeroDataClass.HeroType.MAK)

func _setup_bazaar_hero_buttons() -> void:
	var specs: Array[Dictionary] = BazaarContentClass.get_hero_profile_specs()
	for spec in specs:
		var hero_type: HeroDataClass.HeroType = spec.get("type", HeroDataClass.HeroType.MAK)
		if hero_type == HeroDataClass.HeroType.MAK:
			mak_button.text = _format_bazaar_hero_button(spec)
			continue
		var button: Button = bazaar_hero_buttons.get(hero_type, null)
		if button == null:
			button = Button.new()
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			heroes_button_container.add_child(button)
			bazaar_hero_buttons[hero_type] = button
		button.text = _format_bazaar_hero_button(spec)
		if not button.pressed.is_connected(_on_bazaar_hero_selected.bind(hero_type)):
			button.pressed.connect(_on_bazaar_hero_selected.bind(hero_type))

func _format_bazaar_hero_button(spec: Dictionary) -> String:
	var item_count: int = BazaarContentClass.get_hero_item_ids(spec.get("type", HeroDataClass.HeroType.MAK)).size()
	return "%s\nHP: %d | 暴击: %.0f%% | %d wiki items" % [
		str(spec.get("name", "Hero")),
		int(spec.get("max_hp", 100)),
		float(spec.get("crit", 0.05)) * 100.0,
		item_count,
	]

func _on_bazaar_hero_selected(hero_type: HeroDataClass.HeroType) -> void:
	var hero = HeroFactoryService.create_hero(hero_type)
	if hero == null:
		push_error("Unable to create Bazaar hero: %s" % str(hero_type))
		return
	BazaarContentClass.apply_phase1_player_skill_loadout(hero)
	GameManager.select_hero(hero)
	_apply_passive_skills(hero)
	_on_game_started()

## 应用被动技能（统一使用 PassiveSkillDataClass 新版）
func _apply_passive_skills(hero: HeroDataClass) -> void:
	for ps in hero.passive_skills:
		PassiveSkillDataClass.apply_to_hero(ps, hero)

## 游戏开始
func _on_game_started() -> void:
	_hide_hero_selection()
	bazaar_shell.show_run_shell()
	_show_event_panel()
	_generate_event_options()
	_update_button_visibility()
	_update_ui()
	print("游戏开始! Day %d, Hour %d - %s" % [GameManager.current_day, GameManager.current_hour, GameManager.get_current_phase_name()])
	$VBox.visible = false
	if hero_bar_layer:
		hero_bar_layer.visible = true

## ============ 事件选择系统 ============

## 显示事件选择面板
func _show_event_panel() -> void:
	bazaar_shell.show_run_shell()
	active_merchant_view = null
	if hero_bar_layer:
		hero_bar_layer.visible = true
	event_panel.visible = false
	var options: Array[Dictionary] = GameFlowService.get_current_options()
	if not options.is_empty():
		bazaar_shell.show_time_select(options)
	_refresh_shell_editor_action()

## 隐藏事件选择面板
func _hide_event_panel() -> void:
	_close_ghost_editor()
	event_panel.visible = false
	bazaar_shell.clear_dynamic_regions()

## 生成随机事件选项（使用 EventManager）
## 由 GameFlowService.event_options_generated 信号触发
func _on_game_flow_options_generated(options: Array[Dictionary]) -> void:
	bazaar_shell.refresh_static_panels()
	event_panel.visible = false
	bazaar_shell.show_time_select(options)
	_refresh_shell_editor_action()
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
	if _has_active_special_choice():
		_handle_special_choice_by_index(index)
		return
	# 通知 GameFlow 记录选择
	GameFlowService.handle_event_selection(index)
	var event_type: String = GameFlowService.get_event_type_at(index)
	print("选择了事件类型: %s" % event_type)
	_hide_event_panel()

	match event_type:
		"shop":
			_execute_shop_event()
		"monster":
			_execute_monster_event()
		"pvp":
			_execute_pvp_event()
		"random_event":
			_execute_random_event()
		_:
			_execute_random_event()

func _has_active_special_choice() -> bool:
	return not _active_special_choice_mode.is_empty()

func _show_special_choice(options: Array[Dictionary], mode: String) -> void:
	_active_special_choice_mode = mode
	bazaar_shell.show_run_shell()
	bazaar_shell.refresh_static_panels()
	active_merchant_view = null
	if hero_bar_layer:
		hero_bar_layer.visible = true
	event_panel.visible = false
	bazaar_shell.show_time_select(options)
	_refresh_shell_editor_action()

func _handle_special_choice_by_index(index: int) -> void:
	var special_mode: String = _active_special_choice_mode
	if special_mode.is_empty():
		return
	_hide_event_panel()
	_clear_special_choice_mode()
	match special_mode:
		"futura_last_chance":
			match index:
				0:
					_on_futura_bounty()
				1:
					_on_futura_crossroads()
				2:
					_on_futura_legacy()

func _clear_special_choice_mode() -> void:
	_active_special_choice_mode = ""

## ============ 事件执行 ============

## 执行商店事件
func _execute_shop_event() -> void:
	print("执行商店事件")
	if not PhaseService.can_shop(GameManager.current_hour):
		print("当前阶段不能购买!")
		_auto_advance_hour()
		return
	_open_shop_ui()

## 打开商店 UI
func _open_shop_ui() -> void:
	_write_debug("========== _open_shop_ui() 被调用 ==========")
	_write_debug("inventory_ui: " + str(inventory_ui))
	var inventory: LinearInventoryClass = _get_player_inventory()
	if inventory != null:
		_write_debug("inventory: " + str(inventory))
		bazaar_shell.show_run_shell()
		shop_ui.visible = false
		active_merchant_view = bazaar_shell.show_merchant(inventory, GameFlowService.get_selected_option())
		_connect_merchant_signals(active_merchant_view)
		_write_debug("商人货架已打开")
	else:
		_write_debug("ERROR: 无法获取 InventoryUI 实例")

## 写调试文件
func _write_debug(msg: String) -> void:
	print(msg)

## 商店关闭回调
func _on_shop_closed() -> void:
	print("商店已关闭，进入下一小时")
	active_merchant_view = null
	shop_ui.visible = false
	bazaar_shell.clear_dynamic_regions()
	_auto_advance_hour()

func _connect_merchant_signals(view: Control) -> void:
	if view == null:
		return
	var purchase_callable: Callable = Callable(self, "_on_merchant_purchase_requested")
	if view.has_signal("purchase_requested") and not view.is_connected("purchase_requested", purchase_callable):
		view.connect("purchase_requested", purchase_callable)
	var refresh_callable: Callable = Callable(self, "_on_merchant_refresh_requested")
	if view.has_signal("refresh_requested") and not view.is_connected("refresh_requested", refresh_callable):
		view.connect("refresh_requested", refresh_callable)
	var closed_callable: Callable = Callable(self, "_on_shop_closed")
	if view.has_signal("closed") and not view.is_connected("closed", closed_callable):
		view.connect("closed", closed_callable)

func _on_shell_right_action_pressed(action_id: String) -> void:
	if action_id == "ghost_editor":
		_toggle_ghost_editor()
		return
	if not is_instance_valid(active_merchant_view):
		return
	match action_id:
		"merchant_refresh":
			if active_merchant_view.has_method("request_refresh"):
				active_merchant_view.call("request_refresh")
		"merchant_leave":
			if active_merchant_view.has_method("request_close"):
				active_merchant_view.call("request_close")

func _on_merchant_purchase_requested(
	item: ItemDataClass,
	index: int,
	target_slot: int = -1,
	target_inventory: LinearInventoryClass = null
) -> void:
	if item == null:
		_show_merchant_feedback("商品无效", true)
		return
	var inventory: LinearInventoryClass = _get_player_inventory()
	if inventory == null:
		_show_merchant_feedback("无法读取背包", true)
		return
	if not GameManager.can_afford(item.buy_price):
		_show_merchant_feedback("金币不足", true)
		_update_active_merchant_buttons()
		return
	var stash_inventory: LinearInventoryClass = _get_stash_inventory()
	var target_inventory_ref: LinearInventoryClass = target_inventory if target_inventory != null else inventory
	var can_accept: bool = ItemAcquisitionClass.can_accept_item(item, inventory, stash_inventory, false)
	if target_slot >= 0 and target_inventory_ref != null:
		can_accept = ItemAcquisitionClass.can_accept_item_at_slot(item, inventory, stash_inventory, target_inventory_ref, target_slot, false)
	if not can_accept:
		_show_merchant_feedback("背包空间不足", true)
		_update_active_merchant_buttons()
		return
	if not GameManager.spend_gold(item.buy_price):
		_show_merchant_feedback("购买失败", true)
		_update_active_merchant_buttons()
		return

	var item_copy: ItemDataClass = item.duplicate() as ItemDataClass
	item_copy.slot_index = -1
	var grant_result: Dictionary = {}
	if target_slot >= 0 and target_inventory_ref != null:
		grant_result = ItemAcquisitionClass.grant_item_at_slot(item_copy, inventory, stash_inventory, target_inventory_ref, target_slot, false)
	else:
		grant_result = ItemAcquisitionClass.grant_item(item_copy, inventory, stash_inventory, false)
	if not bool(grant_result.get("success", false)):
		GameManager.add_gold(item.buy_price)
		_show_merchant_feedback("背包放置失败", true)
		_update_active_merchant_buttons()
		return

	if is_instance_valid(active_merchant_view) and active_merchant_view.has_method("apply_purchase_success"):
		active_merchant_view.call("apply_purchase_success", index)
	bazaar_shell.refresh_static_panels()
	_update_ui()
	print("购买成功: %s (花费 %d 金币)" % [item.item_name, item.buy_price])

func _on_merchant_refresh_requested(cost: int) -> void:
	if not is_instance_valid(active_merchant_view):
		return
	if cost > 0:
		if not GameManager.can_afford(cost):
			_show_merchant_feedback("金币不足，无法刷新", true)
			_update_active_merchant_buttons()
			return
		if not GameManager.spend_gold(cost):
			_show_merchant_feedback("刷新失败", true)
			_update_active_merchant_buttons()
			return
	if active_merchant_view.has_method("apply_refresh"):
		active_merchant_view.call("apply_refresh")
	bazaar_shell.refresh_static_panels()
	_update_ui()

func _show_merchant_feedback(message: String, is_error: bool = false) -> void:
	if is_instance_valid(active_merchant_view) and active_merchant_view.has_method("show_feedback"):
		active_merchant_view.call("show_feedback", message, is_error)
	else:
		print(message)

func _update_active_merchant_buttons() -> void:
	if is_instance_valid(active_merchant_view) and active_merchant_view.has_method("update_button_states"):
		active_merchant_view.call("update_button_states")

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

	var result = event_manager.execute_random_event(event_id, day, GameManager, _get_player_inventory(), _get_stash_inventory())
	print("随机事件: %s" % result)
	_auto_advance_hour()

## ============ 战斗系统 ============

func _start_battle() -> void:
	if GameManager.selected_hero == null:
		print("错误: 未选择英雄!")
		return

	_hide_event_panel()
	battle_ui.visible = true
	# 确保底部常驻层在进入战斗时可见
	if hero_bar_layer:
		hero_bar_layer.visible = true
	var selected_option: Dictionary = GameFlowService.get_selected_option()
	var monster_id: String = str(selected_option.get("monster_id", ""))
	var monster = null
	if not monster_id.is_empty():
		monster = BazaarContentClass.create_monster(monster_id, GameManager.current_day)
	battle_ui.start_battle(monster, false, 0)

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
	if hero_bar_layer:
		hero_bar_layer.visible = true

	var snapshot = PvpGhostServiceClass.pick_snapshot_for_day(GameManager.current_day)
	if snapshot != null and not snapshot.snapshot_id.is_empty():
		battle_ui.start_ghost_battle(snapshot)
	else:
		var enemy_bonus = randi() % 5 + 1
		battle_ui.start_battle(null, true, enemy_bonus)

	if not battle_ui.battle_ended.is_connected(_on_battle_ended):
		battle_ui.battle_ended.connect(_on_battle_ended)

	print("开始 PvP 对战!")

## 战斗结束回调
func _on_battle_ended(won: bool, gold_reward: int) -> void:
	var result: Dictionary = BattleProgressionService.apply_battle_result(
		won,
		battle_ui.is_pvp,
		battle_ui.current_monster,
		_get_player_inventory(),
		_get_stash_inventory()
	)
	var settled_gold: int = int(result.get("gold_reward", gold_reward))
	print("战斗结束: 胜利=%s, 金币=%d" % [won, settled_gold])
	_update_ui()
	if bool(result.get("run_won", false)):
		GameManager.finish_run(true)
		return
	if bool(result.get("run_failed", false)):
		return
	if bool(result.get("last_chance", false)):
		return
	_show_event_panel()
	_auto_advance_hour()

## 计算属性（物品触发系统下显示物品总属性）
func _calculate_stats() -> void:
	var inventory: LinearInventoryClass = _get_player_inventory()
	if inventory != null:
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

	shop_button.visible = PhaseService.can_shop(hour)
	battle_button.visible = PhaseService.can_battle(hour)

	next_hour_button.visible = false

## ============ UI 更新 ============

func _update_ui() -> void:
	# 金币
	if gold_label != null:
		gold_label.text = "金币: %d  收入: %d" % [GameManager.gold, GameManager.income]

	# Day/Hour
	if day_label != null:
		day_label.text = "Day %d" % GameManager.current_day
	if hour_label != null:
		hour_label.text = "[%s]" % GameManager.get_current_phase_name()

	# 英雄信息
	if hero_label != null:
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
		def_label.text = "Lv %d  XP %d/%d" % [GameManager.level, GameManager.xp, HeroStateService.XP_PER_LEVEL]

	# Prestige
	if prestige_label != null:
		prestige_label.text = "Prestige: %d/%d" % [GameManager.prestige, GameManager.max_prestige]
	if prestige_bar != null:
		prestige_bar.max_value = GameManager.max_prestige
		prestige_bar.value = GameManager.prestige

	# 回合
	round_label.text = "回合: %d / %d" % [GameManager.current_hour + 1, PhaseService.MAX_HOURS_PER_DAY]

## 获取背包物品数量
func _get_item_count() -> int:
	var inventory: LinearInventoryClass = _get_player_inventory()
	if inventory != null:
		return inventory.get_item_count()
	return 0

## ============ 信号回调 ============

func _on_gold_changed(amount: int) -> void:
	if gold_label != null:
		gold_label.text = "金币: %d  收入: %d" % [GameManager.gold, GameManager.income]
	if hero_bar_gold_label != null:
		hero_bar_gold_label.text = "金币 %d" % GameManager.gold
	_update_active_merchant_buttons()

func _on_income_changed(amount: int) -> void:
	if gold_label != null:
		gold_label.text = "金币: %d  收入: %d" % [GameManager.gold, amount]
	if hero_bar_income_label != null:
		hero_bar_income_label.text = "收入 %d" % amount

func _on_xp_changed(value: int) -> void:
	_update_level_labels()

func _on_level_changed(value: int) -> void:
	_update_level_labels()
	_update_ui()

func _on_level_reward_applied(level_value: int, reward: Dictionary, summary: Dictionary) -> void:
	print("升级到 Lv %d，奖励: %s" % [level_value, str(reward)])
	_update_ui()

func _update_level_labels() -> void:
	if hero_bar_level_label != null:
		hero_bar_level_label.text = "Lv %d  XP %d/%d" % [GameManager.level, GameManager.xp, HeroStateService.XP_PER_LEVEL]
	if def_label != null:
		def_label.text = "Lv %d  XP %d/%d" % [GameManager.level, GameManager.xp, HeroStateService.XP_PER_LEVEL]

func _on_day_changed(day: int) -> void:
	if day_label != null:
		day_label.text = "Day %d" % day
	_apply_start_of_day_item_effects(day)

func _apply_start_of_day_item_effects(day: int) -> void:
	if day <= 1:
		return
	var summary: Dictionary = ItemAcquisitionClass.grant_start_of_day_items(_get_player_inventory(), _get_stash_inventory())
	var catalyst_count: int = int(summary.get("catalysts", 0))
	if catalyst_count > 0:
		print("新的一天: 获得 %d 个 Catalyst" % catalyst_count)
		bazaar_shell.refresh_static_panels()
		_update_ui()

func _on_hour_changed(hour: int, phase_name: String) -> void:
	if hour_label != null:
		hour_label.text = "[%s]" % phase_name
	round_label.text = "回合: %d / %d" % [hour + 1, PhaseService.MAX_HOURS_PER_DAY]

func _on_player_inventory_changed() -> void:
	_update_ui()
	_update_active_merchant_buttons()

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
	_close_ghost_editor()
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
	bazaar_shell.hide_run_shell()
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

func _refresh_shell_editor_action() -> void:
	if bazaar_shell == null or not bazaar_shell.visible:
		return
	if battle_ui != null and battle_ui.visible:
		return
	if is_instance_valid(active_merchant_view):
		return
	var action_label: String = "Close Ghost Editor" if _is_ghost_editor_open() else "Ghost Editor"
	bazaar_shell.set_right_actions([{"id": "ghost_editor", "label": action_label}])

func _toggle_ghost_editor() -> void:
	if _is_ghost_editor_open():
		_close_ghost_editor()
	else:
		_open_ghost_editor()
	_refresh_shell_editor_action()

func _open_ghost_editor() -> void:
	if _is_ghost_editor_open():
		return
	if bazaar_shell == null or not bazaar_shell.has_method("get_overlay_layer"):
		return
	var overlay_layer: Control = bazaar_shell.get_overlay_layer()
	if overlay_layer == null:
		return
	var editor: Control = GhostSnapshotEditorClass.new()
	if editor.has_method("set_document_path"):
		editor.call("set_document_path", PvpGhostServiceClass.DEFAULT_CURATED_PATH)
	editor.connect("closed", Callable(self, "_on_ghost_editor_closed"))
	editor.connect("saved", Callable(self, "_on_ghost_editor_saved"))
	editor.connect("validation_failed", Callable(self, "_on_ghost_editor_validation_failed"))
	overlay_layer.add_child(editor)
	overlay_layer.move_to_front()
	editor.move_to_front()
	active_ghost_editor = editor
	print("Ghost snapshot editor opened")

func _close_ghost_editor() -> void:
	if not _is_ghost_editor_open():
		active_ghost_editor = null
		return
	active_ghost_editor.queue_free()
	active_ghost_editor = null

func _is_ghost_editor_open() -> bool:
	return active_ghost_editor != null and is_instance_valid(active_ghost_editor)

func _on_ghost_editor_closed() -> void:
	active_ghost_editor = null
	_refresh_shell_editor_action()

func _on_ghost_editor_saved(snapshot_id: String, path: String) -> void:
	print("Ghost snapshot saved: %s -> %s" % [snapshot_id, path])
	_refresh_shell_editor_action()

func _on_ghost_editor_validation_failed(errors: Array[String]) -> void:
	print("Ghost snapshot validation failed: %s" % JSON.stringify(errors))

## ============ Futura 事件系统 ============

func _on_futura_triggered() -> void:
	var options: Array[Dictionary] = [
		{
			"text": "Fate's Bounty",
			"summary": "+20 Gold",
			"type": "special_event",
			"art_path": FUTURA_ART_PATH,
		},
		{
			"text": "Fate's Crossroads",
			"summary": "随机附魔",
			"type": "special_event",
			"art_path": FUTURA_ART_PATH,
		},
		{
			"text": "Fate's Legacy",
			"summary": "升级铜/银物品到金级",
			"type": "special_event",
			"art_path": FUTURA_ART_PATH,
		},
	]
	_show_special_choice(options, "futura_last_chance")
	print("⭐ Futura 事件触发!")

func _on_futura_bounty() -> void:
	GameManager.add_gold(20)
	print("🔮 Fate's Bounty: +20 Gold")
	_auto_advance_hour()

func _on_futura_crossroads() -> void:
	# MVP: 随机附魔简化为增加暴击率
	if GameManager.selected_hero:
		GameManager.selected_hero.crit_chance += 0.03
	print("🔮 Fate's Crossroads: 随机附魔 (暴击+3%%)")
	_auto_advance_hour()

func _on_futura_legacy() -> void:
	# MVP: 升级物品简化为增加暴击率
	if GameManager.selected_hero:
		GameManager.selected_hero.crit_chance += 0.05
	print("🔮 Fate's Legacy: 升级物品品质 (暴击+5%%)")
	_auto_advance_hour()

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
	if PhaseService.is_pvp_phase(GameManager.current_hour):
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
	gold_label.text = "金币 %d" % GameManager.gold
	hero_bar_layer.add_child(gold_label)
	hero_bar_gold_label = gold_label

	var income_label: Label = Label.new()
	income_label.name = "IncomeLabel"
	income_label.anchor_top = 0.5
	income_label.anchor_bottom = 1.0
	income_label.anchor_left = 0.7
	income_label.anchor_right = 1.0
	income_label.offset_left = 0.0
	income_label.offset_top = 0.0
	income_label.offset_right = 0.0
	income_label.offset_bottom = 0.0
	income_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	income_label.text = "收入 %d" % GameManager.income
	hero_bar_layer.add_child(income_label)
	hero_bar_income_label = income_label

	var level_label: Label = Label.new()
	level_label.name = "LevelLabel"
	level_label.anchor_top = 0.0
	level_label.anchor_bottom = 0.5
	level_label.anchor_left = 0.42
	level_label.anchor_right = 0.55
	level_label.offset_left = 0.0
	level_label.offset_top = 0.0
	level_label.offset_right = 0.0
	level_label.offset_bottom = 0.0
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.text = "Lv %d  XP %d/%d" % [GameManager.level, GameManager.xp, HeroStateService.XP_PER_LEVEL]
	hero_bar_layer.add_child(level_label)
	hero_bar_level_label = level_label

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
	_on_income_changed(GameManager.income)
	_update_level_labels()

## Debug: 验证 inventory 引用一致性
func debug_verify_inventory() -> void:
	var inv_from_ui: LinearInventoryClass = _get_player_inventory()
	print("[DEBUG] main.inventory_ui address: %s" % str(inventory_ui))
	print("[DEBUG] inv_from_ui address: %s" % str(inv_from_ui))
	print("[DEBUG] shop_ui.inventory address: %s" % str(shop_ui.inventory if shop_ui else "shop_ui is null"))
	if inv_from_ui != shop_ui.inventory:
		print("[BUG!] inventory mismatch! inv_from_ui != shop_ui.inventory")
	else:
		print("[OK] inventory references match")
