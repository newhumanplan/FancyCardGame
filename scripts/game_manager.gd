extends Node

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
	prestige = 20
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
var selected_hero: HeroData = null

## 玩家生命值
var player_health: int = 100

## ============ Prestige 系统 ============

## Prestige 值 (初始值 20)
var prestige: int = 20

## Prestige 最大值
var max_prestige: int = 100

## 胜场
var wins: int = 0

## 败场
var losses: int = 0

## ============ 信号 ============

signal gold_changed(amount: int)
signal prestige_changed(value: int)
signal health_changed(amount: int)
signal game_over(won: bool)

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
func select_hero(hero: HeroData) -> void:
	selected_hero = hero
	# 根据英雄类型设置初始属性（只有 HP）
	if hero.hero_type == HeroData.HeroType.WARRIOR:
		# 战士: HP120
		player_health = 120
	elif hero.hero_type == HeroData.HeroType.MAGE:
		# 法师: HP80
		player_health = 80

	health_changed.emit(player_health)
	print("已选择英雄: %s (%s)" % [hero.hero_name, hero.get_type_name()])

## 应用被动技能加成
func apply_skill_bonus(skill_name: String, bonus_type: String, value: float) -> void:
	match bonus_type:
		"health":
			player_health += int(value)
			health_changed.emit(player_health)
		"crit":
			if selected_hero:
				selected_hero.crit_chance += value / 100.0

## ============ 金币管理 ============

## 获取金币
func get_gold() -> int:
	return gold

## 增加金币
func add_gold(amount: int) -> void:
	gold += amount
	record_gold_earned(amount)
	gold_changed.emit(amount)

## 花费金币
func spend_gold(amount: int) -> bool:
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
	prestige = min(prestige + amount, max_prestige)
	prestige_changed.emit(prestige)

## 减少 Prestige
func remove_prestige(amount: int) -> void:
	var old_prestige = prestige
	prestige = max(prestige - amount, 0)
	prestige_changed.emit(prestige)

	# 检查是否归零
	if old_prestige > 0 and prestige == 0:
		_show_gold_upgrade_option()

## 显示黄金升级选项提示
func _show_gold_upgrade_option() -> void:
	print("💰 黄金升级选项已解锁!")
	add_gold(100)
	print("💰 获得 100 金币奖励!")

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

	# 检查 10 胜胜利条件
	if wins >= 10:
		_show_victory()
		print("🎉 恭喜! 10 胜达成! 游戏胜利!")

## 显示胜利画面
func _show_victory() -> void:
	game_over.emit(true)

## 战斗失败（非PvP）
func on_battle_lose() -> void:
	losses += 1
	wins = 0  # 重置连胜
	record_battle_loss()

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
func take_damage(amount: int) -> int:
	player_health = max(0, player_health - amount)
	health_changed.emit(player_health)
	if player_health <= 0:
		game_over.emit(false)
	return amount

## 治疗
func heal(amount: int) -> void:
	var max_hp: int = get_max_health()
	player_health = min(player_health + amount, max_hp)
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

## 完全重置（Prestige 也重置）
func full_reset() -> void:
	gold = 100
	current_day = 1
	current_hour = 0
	player_health = 100
	prestige = 20
	wins = 0
	losses = 0
	selected_hero = null
	day_changed.emit(current_day)
	hour_changed.emit(current_hour, get_current_phase_name())
