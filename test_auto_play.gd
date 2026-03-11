extends Node

## 自动化测试脚本 - 模拟完整单局游戏
## 根据 P1 功能需求文档执行完整测试流程

## 测试状态
var test_step: int = 0
var test_log: Array[String] = []
var errors_found: Array[String] = []

## 游戏节点引用
var main_node: Node = null
var game_manager: Node = null
var hero_select_panel: Control = null
var event_panel: Control = null
var battle_ui: Control = null

## 分隔线
const SEP = "============================================================"

func _ready() -> void:
	print(SEP)
	print("开始自动化测试 - 完整单局模拟")
	print(SEP)
	
	# 如果当前场景不是游戏主场景，则加载它
	if get_tree().current_scene.name != "Main":
		print("📦 加载游戏主场景...")
		var main_scene = load("res://scenes/main.tscn")
		# 使用 call_deferred 延迟场景切换
		call_deferred("_change_to_main_scene", main_scene)
		return
	
	# 开始测试
	_start_test()

func _change_to_main_scene(main_scene: PackedScene) -> void:
	get_tree().change_scene_to_packed(main_scene)
	await get_tree().create_timer(3.0).timeout
	_start_test()

func _start_test() -> void:
	# 等待游戏加载完成
	await get_tree().create_timer(2.0).timeout
	
	# 获取游戏节点
	main_node = get_tree().current_scene
	game_manager = get_node("/root/GameManager")
	
	# 查找关键UI节点
	_find_ui_nodes()
	
	# 运行完整测试
	await _run_full_test()

## 查找UI节点
func _find_ui_nodes() -> void:
	_log("📋 步骤 0: 查找UI节点")
	
	hero_select_panel = main_node.get_node_or_null("HeroSelectPanel")
	event_panel = main_node.get_node_or_null("EventPanel")
	battle_ui = main_node.get_node_or_null("BattleUI")
	
	if hero_select_panel:
		_log("✅ 找到 HeroSelectPanel")
	else:
		_error("❌ 未找到 HeroSelectPanel")
	
	if event_panel:
		_log("✅ 找到 EventPanel")
	else:
		_error("❌ 未找到 EventPanel")
	
	if battle_ui:
		_log("✅ 找到 BattleUI")
	else:
		_error("❌ 未找到 BattleUI")

## 执行完整测试
func _run_full_test() -> void:
	# 步骤 1: 英雄选择
	await _test_hero_selection()
	
	# 步骤 2: 完成多个回合
	for i in range(5):
		await _test_event_phase(i)
		await get_tree().create_timer(2.0).timeout
	
	# 输出测试报告
	_print_test_report()

## 测试英雄选择
func _test_hero_selection() -> void:
	_log("\n" + SEP)
	_log("步骤 1: 英雄选择阶段")
	_log(SEP)
	
	# 检查英雄选择面板是否可见
	if not hero_select_panel.visible:
		_error("❌ 英雄选择面板未显示")
		return
	
	_log("✅ 英雄选择面板已显示")
	
	# 查找战士按钮
	var warrior_button = hero_select_panel.get_node_or_null("HeroSelectVBox/Heroes/WarriorButton")
	if not warrior_button:
		_error("❌ 未找到战士按钮")
		return
	
	_log("🖱️  点击战士按钮")
	warrior_button.emit_signal("pressed")
	
	# 等待选择完成
	await get_tree().create_timer(1.0).timeout
	
	# 验证英雄是否已选择
	if game_manager.selected_hero == null:
		_error("❌ 英雄未被正确选择")
	else:
		_log("✅ 英雄已选择: %s" % game_manager.selected_hero.hero_name)
		_log("   - HP: %d" % game_manager.player_health)
		_log("   - ATK: %d" % game_manager.player_attack)
		_log("   - DEF: %d" % game_manager.player_defense)

## 测试事件阶段
func _test_event_phase(hour: int) -> void:
	_log("\n" + SEP)
	_log("步骤 2.%d: 事件阶段 - Hour %d" % [hour + 1, game_manager.current_hour])
	_log(SEP)
	
	# 检查事件面板是否可见
	if not event_panel.visible:
		_log("⏳ 等待事件面板显示...")
		await get_tree().create_timer(1.0).timeout
		
		if not event_panel.visible:
			_error("❌ 事件面板未显示")
			return
	
	_log("✅ 事件面板已显示")
	
	# 获取当前阶段名称
	var phase_name = game_manager.get_current_phase_name()
	_log("📍 当前阶段: %s" % phase_name)
	
	# 查找事件选项
	var option1 = event_panel.get_node_or_null("EventVBox/EventOptions/Option1")
	var option2 = event_panel.get_node_or_null("EventVBox/EventOptions/Option2")
	var option3 = event_panel.get_node_or_null("EventVBox/EventOptions/Option3")
	
	# 随机选择一个选项
	var options = []
	if option1 and option1.visible:
		options.append(option1)
	if option2 and option2.visible:
		options.append(option2)
	if option3 and option3.visible:
		options.append(option3)
	
	if options.size() == 0:
		_error("❌ 没有可用的事件选项")
		return
	
	var selected_option = options.pick_random()
	_log("🖱️  点击事件选项: %s" % selected_option.text)
	selected_option.emit_signal("pressed")
	
	# 等待事件执行
	await get_tree().create_timer(3.0).timeout
	
	# 检查是否进入战斗
	if battle_ui and battle_ui.get("is_battle_active"):
		_log("⚔️  战斗开始！等待战斗结束...")
		await _wait_for_battle_end()
	
	# 验证游戏状态
	_log("📊 游戏状态:")
	_log("   - Day: %d" % game_manager.current_day)
	_log("   - Hour: %d" % game_manager.current_hour)
	_log("   - 金币: %d" % game_manager.gold)
	_log("   - HP: %d" % game_manager.player_health)
	_log("   - Prestige: %d" % game_manager.prestige)
	_log("   - 胜场: %d" % game_manager.wins)

## 等待战斗结束
func _wait_for_battle_end() -> void:
	var max_wait_time = 30.0
	var waited = 0.0
	
	while battle_ui.get("is_battle_active") and waited < max_wait_time:
		await get_tree().create_timer(1.0).timeout
		waited += 1.0
		
		if int(waited) % 5 == 0:
			_log("⏳ 战斗进行中... (%.0fs)" % waited)
	
	if battle_ui.get("is_battle_active"):
		_error("⚠️  战斗超时（30秒）")
	else:
		_log("✅ 战斗已结束")

## 输出测试报告
func _print_test_report() -> void:
	await get_tree().create_timer(1.0).timeout
	
	print("\n" + SEP)
	print("自动化测试完成！")
	print(SEP)
	
	print("\n📋 测试日志:")
	for log_entry in test_log:
		print(log_entry)
	
	print("\n❌ 发现的错误 (%d 个):" % errors_found.size())
	if errors_found.size() == 0:
		print("   无错误！✅")
	else:
		for error in errors_found:
			print("   - " + error)
	
	print("\n📊 最终游戏状态:")
	print("   - Day: %d" % game_manager.current_day)
	print("   - Hour: %d" % game_manager.current_hour)
	print("   - 金币: %d" % game_manager.gold)
	print("   - HP: %d/%d" % [game_manager.player_health, game_manager.get_max_health()])
	print("   - Prestige: %d" % game_manager.prestige)
	print("   - 胜场: %d" % game_manager.wins)
	print("   - 败场: %d" % game_manager.losses)
	
	print("\n" + SEP)
	
	# 退出游戏（测试完成）
	await get_tree().create_timer(2.0).timeout
	get_tree().quit()

## 记录日志
func _log(message: String) -> void:
	test_log.append(message)
	print(message)

## 记录错误
func _error(message: String) -> void:
	errors_found.append(message)
	print(message)
