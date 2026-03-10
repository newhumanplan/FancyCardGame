extends Node

var game_manager = null

func _ready():
	# 等待一帧让 autoload 初始化
	await get_tree().process_frame
	_run_tests()

func _run_tests():
	# 获取 GameManager
	game_manager = get_node("/root/GameManager")
	if not game_manager:
		print("错误: 找不到 GameManager")
		get_tree().quit()
		return
	
	print("========== MVP 验收测试 ==========")
	
	# 测试1: 检查 GameManager
	print("\n[测试1] GameManager 初始化")
	print("  gold: %d" % game_manager.gold)
	print("  prestige: %d (期望: 10)" % game_manager.prestige)
	print("  current_day: %d" % game_manager.current_day)
	print("  current_hour: %d" % game_manager.current_hour)
	
	# 测试2: 检查 Day/Hour 循环
	print("\n[测试2] Day/Hour 循环")
	print("  阶段: %s" % str(game_manager.HOUR_PHASES))
	
	# 测试3: 检查英雄系统
	print("\n[测试3] 英雄系统")
	var warrior = HeroData.new()
	warrior.hero_name = "战士"
	warrior.hero_type = HeroData.HeroType.WARRIOR
	warrior.max_hp = 120
	warrior.attack = 15
	warrior.defense = 10
	warrior.crit_chance = 0.05
	game_manager.select_hero(warrior)
	print("  战士属性: HP=%d, ATK=%d, DEF=%d" % [game_manager.player_health, game_manager.player_attack, game_manager.player_defense])
	print("  战士期望: HP=120, ATK=15, DEF=10")
	
	# 测试4: 检查 Prestige 扣减
	print("\n[测试4] Prestige 扣减机制")
	game_manager.full_reset()  # 重置
	var initial_prestige = game_manager.prestige
	print("  初始 Prestige: %d" % initial_prestige)
	game_manager.current_day = 3
	game_manager.on_pvp_lose()
	print("  PvP失败(Day3)后 Prestige: %d (扣除 %d, 期望扣除3)" % [game_manager.prestige, initial_prestige - game_manager.prestige])
	
	# 测试5: 检查物品数据
	print("\n[测试5] 物品数据")
	var iron_sword = load("res://resources/items/iron_sword.tres")
	print("  铁剑: damage=%d, cooldown=%.1f, crit=%.0f%%, size=%s" % [iron_sword.damage, iron_sword.cooldown, iron_sword.crit_chance * 100, iron_sword.get_size_text()])
	print("  期望: damage=15, cooldown=3.0, crit=5%%, size=SMALL")
	
	var wood_shield = load("res://resources/items/wood_shield.tres")
	print("  木盾: shield=%d, cooldown=%.1f, size=%s" % [wood_shield.shield, wood_shield.cooldown, wood_shield.get_size_text()])
	print("  期望: shield=20, cooldown=5.0, size=SMALL")
	
	print("\n========== 测试完成 ==========")
	get_tree().quit()
