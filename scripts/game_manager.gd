extends Node

## 游戏管理器 - 管理全局状态

## ============ 基础属性 ============

## 金币
var gold: int = 100

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

## 玩家攻击力
var player_attack: int = 10

## 玩家防御力
var player_defense: int = 5

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
signal attack_changed(value: int)
signal defense_changed(value: int)
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

## 选择英雄
func select_hero(hero: HeroData) -> void:
	selected_hero = hero
	# 根据英雄类型设置初始属性
	if hero.hero_type == HeroData.HeroType.WARRIOR:
		# 战士: HP120, ATK15, DEF10
		player_health = 120
		player_attack = 15
		player_defense = 10
	elif hero.hero_type == HeroData.HeroType.MAGE:
		# 法师: HP80, ATK25, DEF5
		player_health = 80
		player_attack = 25
		player_defense = 5
	
	health_changed.emit(player_health)
	attack_changed.emit(player_attack)
	defense_changed.emit(player_defense)
	print("已选择英雄: %s (%s)" % [hero.hero_name, hero.get_type_name()])

## 应用被动技能加成
func apply_skill_bonus(skill_name: String, bonus_type: String, value: int) -> void:
	match bonus_type:
		"attack":
			player_attack += value
			attack_changed.emit(player_attack)
		"defense":
			player_defense += value
			defense_changed.emit(player_defense)
		"health":
			player_health += value
			health_changed.emit(player_health)

## ============ 金币管理 ============

## 获取金币
func get_gold() -> int:
	return gold

## 增加金币
func add_gold(amount: int) -> void:
	gold += amount
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
	# Prestige 越高，奖励加成越多
	# 公式: 1 + (prestige / 100)
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
	print("选择 1: 升级所有卡牌 (+50% 属性)")
	print("选择 2: 附魔 (+1 暴击率)")
	print("选择 3: 获得金币和经验 (+100 金币, +1 胜场)")
	# 简化实现：自动选择选项3，获得奖励
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

## PvP 失败 - 扣除当前天数的 Prestige
func on_pvp_lose() -> void:
	losses += 1
	wins = 0
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

## 扣除生命值
func take_damage(amount: int) -> void:
	# 计算实际伤害（考虑防御力）
	var actual_damage: int = maxi(amount - player_defense, 1)
	player_health = max(0, player_health - actual_damage)
	health_changed.emit(player_health)
	if player_health <= 0:
		game_over.emit(false)

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
	player_attack = 10
	player_defense = 5
	wins = 0
	losses = 0
	# Prestige 保留
	day_changed.emit(current_day)
	hour_changed.emit(current_hour, get_current_phase_name())

## 完全重置（Prestige 也重置）
func full_reset() -> void:
	gold = 100
	current_day = 1
	current_hour = 0
	player_health = 100
	player_attack = 10
	player_defense = 5
	prestige = 20  # 使用初始值 20
	wins = 0
	losses = 0
	selected_hero = null
	day_changed.emit(current_day)
	hour_changed.emit(current_hour, get_current_phase_name())
