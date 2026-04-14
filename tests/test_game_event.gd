extends Node

## game_event 测试 — 游戏事件数据结构

func _ready():
	var GameEvent = load("res://scripts/data/game_event.gd")
	var passed = 0
	var total = 5

	# Test 1: 创建事件
	var evt = GameEvent.new()
	evt.event_id = "treasure"
	evt.event_name = "发现宝藏"
	evt.description = "你发现了一个装满金币的箱子！"
	evt.event_type = GameEvent.EventType.TREASURE
	evt.gold_reward = 50
	var t1 = evt.event_id == "treasure" and evt.event_type == GameEvent.EventType.TREASURE
	print("test_create_event: %s" % ["PASS" if t1 else "FAIL"])
	if t1: passed += 1

	# Test 2: 默认值
	var evt2 = GameEvent.new()
	var t2 = evt2.gold_reward == 0 and evt2.hp_reward == 0 and evt2.weight == 1
	print("test_default_values: %s" % ["PASS" if t2 else "FAIL"])
	if t2: passed += 1

	# Test 3: 权重设置
	var evt3 = GameEvent.new()
	evt3.weight = 5
	evt3.min_day = 3
	evt3.max_day = 7
	var t3 = evt3.weight == 5 and evt3.min_day == 3 and evt3.max_day == 7
	print("test_weight_day_range: %s" % ["PASS" if t3 else "FAIL"])
	if t3: passed += 1

	# Test 4: 奖励设置
	var evt4 = GameEvent.new()
	evt4.event_id = "heal_camp"
	evt4.event_type = GameEvent.EventType.CAMP
	evt4.hp_reward = 30
	evt4.prestige_reward = 2
	var t4 = evt4.hp_reward == 30 and evt4.prestige_reward == 2
	print("test_rewards: %s" % ["PASS" if t4 else "FAIL"])
	if t4: passed += 1

	# Test 5: 事件类型枚举
	var t5 = (GameEvent.EventType.TREASURE >= 0 and
	          GameEvent.EventType.CAMP >= 0 and
	          GameEvent.EventType.MERCHANT >= 0)
	print("test_event_types: %s" % ["PASS" if t5 else "FAIL"])
	if t5: passed += 1

	print("\nGameEvent Tests: %d/%d passed" % [passed, total])
