extends Node
const HeroDataClass = preload("res://scripts/data/hero_data.gd")

## 游戏管理器 - 管理全局状态
## 重构：移除 ATK/DEF，按原版大巴扎 1:1 复刻
## 英雄只有 HP + 被动技能，伤害完全来自物品触发

## ============ 基础属性 ============

## 金币
var gold: int = 100

## ============ 统计系统 ============

## 总战斗场次
var stats_total_battles: int = 0

## 总胜利场次
var stats_total_wins: int = 0

## 总失败场次
var stats_total_losses: int = 0

## 总获得金币
var stats_total_gold_earned: int = 0

## ============ 统计方法 ============

## 记录战斗胜利
func record_battle_win() -> void:
	stats_total_battles += 1
	stats_total_wins += 1

## 记录战斗失败
func record_battle_loss() -> void:
	stats_total_battles += 1
	stats_total_losses += 1

## 记录获得金币
func record_gold_earned(amount: int) -> void:
	stats_total_gold_earned += amount

## 重置所有统计数据（含游戏状态）
func reset_stats() -> void:
	stats_total_battles = 0
	stats_total_wins = 0
	stats_total_losses = 0
	stats_total_gold_earned = 0
	wins = 0
	losses = 0
	pvp_wins = 0
	prestige = 20
	prestige_zero_count = 0
	gold = 100
	current_day = 1
	current_hour = 0
	player_health = 100
	day_changed.emit(current_day)
	hour_changed.emit(current_hour, get_current_phase_name())

## ============ Day/Hour 循环系统 ============

## 当前天数
var current_day: int = 1

## 当前小时阶段 (0-4)
## 阶段顺序: 0=采购, 1=采购, 2=打怪, 3=采购, 4=PvP
var current_hour: int = 0

## 小时阶段名称
const HOUR_PHASES: Array[String] = ["采购", "采购", "打怪", "采购", "PvP"]

## 信号
signal day_changed(day: int)
signal hour_changed(hour: int, phase_name: String)

## ============ 英雄系统 ============

## 当前选择的英雄
var selected_hero: HeroDataClass = null

## 玩家生命值
var player_health: int = 100

## ============ Prestige 系统 ============

## Prestige 值 (初始值 20)
var prestige: int = 20

## Prestige 最大值
var max_prestige: int = 20

## Prestige 归零次数（第二次归零 = 游戏结束）
var prestige_zero_count: int = 0

## 胜场
var wins: int = 0

## 败场
var losses: int = 0

## PvP 胜利次数（独立追踪，达到10场通关）
var pvp_wins: int = 0

## ============ 信号 ============

signal gold_changed(amount: int)
signal prestige_changed(value: int)
signal health_changed(amount: int)
signal game_over(won: bool)
signal futura_triggered()

func _ready() -> void:
	print("GameManager 已初始化")

## ============ Day/Hour 循环 ============

## 获取当前阶段名称
func get_current_phase_name() -> String:
	return HOUR_PHASES[current_hour]

## 进入下一小时
func next_hour() -> void:
	current_hour += 1
	if current_hour >= 5:
		# 新的一天
		current_hour = 0
		current_day += 1
		day_changed.emit(current_day)
	hour_changed.emit(current_hour, get_current_phase_name())

## 是否为 PvP 阶段
func is_pvp_hour() -> bool:
	return current_hour == 4

## 是否为战斗阶段（打怪或PvP）
func is_battle_hour() -> bool:
	return current_hour == 2 or current_hour == 4

## 重置 Day/Hour
func reset_day_hour() -> void:
	current_day = 1
	current_hour = 0
	day_changed.emit(current_day)
	hour_changed.emit(current_hour, get_current_phase_name())

## ============ 英雄系统 ============

## 选择英雄（只设置 HP，ATK/DEF 已移除）
func select_hero(hero: HeroDataClass) -> void:
	if hero == null:
		return
	selected_hero = hero
	# 根据英雄类型设置初始属性（只有 HP）
	if hero.hero_type == HeroDataClass.HeroType.WARRIOR:
		# 战士: HP120
		player_health = 120
	elif hero.hero_type == HeroDataClass.HeroType.MAGE:
		# 法师: HP80
		player_health = 80
	selected_hero.current_hp = player_health

	health_changed.emit(player_health)
	print("已选择英雄: %s (%s)" % [hero.hero_name, hero.get_type_name()])

## 应用被动技能加成
## ============ 金币管理 ============

## 获取金币
func get_gold() -> int:
	return gold

## 增加金币
func add_gold(amount: int) -> void:
	if amount <= 0:
		return
	gold += amount
	record_gold_earned(amount)
	gold_changed.emit(amount)

## 花费金币
func spend_gold(amount: int) -> bool:
	if amount < 0:
		return false
	if gold >= amount:
		gold -= amount
		gold_changed.emit(-amount)
		return true
	return false

## 检查是否足够
func can_afford(amount: int) -> bool:
	return gold >= amount

## ============ Prestige 系统 ============

## 计算 Prestige 加成
func get_prestige_bonus() -> float:
	return 1.0 + (float(prestige) / 100.0)

## 获取 Prestige 百分比
func get_prestige_percent() -> float:
	return float(prestige) / float(max_prestige)

## 增加 Prestige
func add_prestige(amount: int) -> void:
	prestige = clampi(prestige + amount, 0, max_prestige)
	prestige_changed.emit(prestige)

## 减少 Prestige
func remove_prestige(amount: int) -> void:
	var old_prestige = prestige
	prestige = max(prestige - amount, 0)
	prestige_changed.emit(prestige)

	# 检查是否归零
	if old_prestige > 0 and prestige == 0:
		prestige_zero_count += 1
		if prestige_zero_count == 1:
			# 第一次归零 → 黄金升级，声望恢复到 1
			_gold_upgrade()
		elif prestige_zero_count >= 2:
			# 第二次归零 → 游戏结束
			game_over.emit(false)

## 黄金升级：触发 Futura 事件，声望恢复到 1
func _gold_upgrade() -> void:
	print("⭐ 声望归零第1次! Futura 事件触发!")
	prestige = 1
	prestige_changed.emit(prestige)
	futura_triggered.emit()

## Prestige 加成购买
func buy_prestige(amount: int, cost: int) -> bool:
	if spend_gold(cost):
		add_prestige(amount)
		return true
	return false

## 战斗胜利
func on_battle_win() -> void:
	wins += 1
	record_battle_win()
	# 根据连胜增加 Prestige
	var bonus: int = 1
	if wins >= 3:
		bonus = 2
	if wins >= 5:
		bonus = 3
	add_prestige(bonus)

## 显示胜利画面
func _show_victory() -> void:
	game_over.emit(true)

## 战斗失败（非PvP）
func on_battle_lose() -> void:
	losses += 1
	wins = 0
	record_battle_loss()
	print("怪物战斗失败!")

## PvP 胜利（独立计数，10场通关）
func on_pvp_win() -> void:
	pvp_wins += 1
	on_battle_win()
	print("PvP 胜利! PvP 胜场: %d/10" % pvp_wins)
	if pvp_wins >= 10:
		_show_victory()

## PvP 失败 - 扣除当前天数的 Prestige
func on_pvp_lose() -> void:
	losses += 1
	wins = 0
	record_battle_loss()
	# 扣除当前 Day 数作为惩罚
	var penalty: int = current_day
	remove_prestige(penalty)
	print("PvP 失败! 扣除 %d Prestige" % penalty)

## ============ 生命值管理 ============

## 获取玩家最大生命值
func get_max_health() -> int:
	if selected_hero != null:
		return selected_hero.max_hp
	return 100

## 扣除生命值（直接扣除，MVP 无防御属性）
## 返回实际伤害值
## 注意：HP 归零不触发 game_over，游戏结束仅由 Prestige 归零判定
func take_damage(amount: int) -> int:
	var actual_amount: int = maxi(amount, 0)
	player_health = max(0, player_health - actual_amount)
	if selected_hero != null:
		selected_hero.current_hp = player_health
	health_changed.emit(player_health)
	return actual_amount

## 治疗
func heal(amount: int) -> void:
	var max_hp: int = get_max_health()
	player_health = min(player_health + maxi(amount, 0), max_hp)
	if selected_hero != null:
		selected_hero.current_hp = player_health
	health_changed.emit(player_health)

## ============ 游戏流程 ============

## 重置游戏
func reset() -> void:
	gold = 100
	current_day = 1
	current_hour = 0
	player_health = 100
	wins = 0
	losses = 0
	day_changed.emit(current_day)
	hour_changed.emit(current_hour, get_current_phase_name())

## 统一重置接口（合并三个 reset）
## mode: "partial" = 保留Prestige, "full" = 全重置, "stats" = 仅统计数据
func reset_run(mode: String = "partial") -> void:
	match mode:
		"partial":
			# 重置游戏状态，保留Prestige
			gold = 100
			current_day = 1
			current_hour = 0
			player_health = 100
			wins = 0
			losses = 0
			selected_hero = null
			day_changed.emit(current_day)
			hour_changed.emit(current_hour, get_current_phase_name())
		"full":
			# 完全重置包括Prestige
			gold = 100
			current_day = 1
			current_hour = 0
			player_health = 100
			prestige = 20
			prestige_zero_count = 0
			pvp_wins = 0
			wins = 0
			losses = 0
			selected_hero = null
			day_changed.emit(current_day)
			hour_changed.emit(current_hour, get_current_phase_name())
		"stats":
			# 仅重置统计数据
			stats_total_battles = 0
			stats_total_wins = 0
			stats_total_losses = 0
			stats_total_gold_earned = 0
			wins = 0
			losses = 0
			pvp_wins = 0
		_:
			pass  # unknown mode, do nothing

## 完全重置（Prestige 也重置）- 保留作为别名
func full_reset() -> void:
	reset_run("full")
