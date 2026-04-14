class_name EconomyManager
extends RefCounted

## 经济管理器 — 管理商店定价、收益曲线、经济平衡

## ============ 收入来源配置 ============

## 怪物战斗金币基础值
const MONSTER_GOLD_BASE: int = 8

## 怪物战斗金币天数缩放系数
const MONSTER_GOLD_DAY_SCALE: int = 3

## PvP 胜利金币奖励
const PVP_WIN_GOLD_BASE: int = 12
const PVP_WIN_GOLD_DAY_SCALE: int = 5

## 事件金币范围
const EVENT_GOLD_MIN: int = 5
const EVENT_GOLD_MAX: int = 40

## ============ 商店定价配置 ============

## 物品基础价格（按稀有度）
## 索引: 0=不使用, 1=普通, 2=稀有, 3=史诗, 4=传说
const ITEM_BASE_PRICES: Array[int] = [0, 10, 25, 50, 80]

## 尺寸价格倍率
const SIZE_PRICE_MULTIPLIER: Dictionary = {
	0: 1.0,   # SMALL
	1: 1.5,   # MEDIUM
	2: 2.5,   # LARGE
}

## 类型价格倍率
const TYPE_PRICE_MULTIPLIER: Dictionary = {
	0: 1.2,   # WEAPON
	1: 1.0,   # SHIELD
	2: 0.8,   # HEAL
	3: 1.5,   # UTILITY
}

## ============ 经济曲线 ============

## 起始金币
const STARTING_GOLD: int = 100

## 每日被动金币（维护费概念，可选）
const DAILY_PASSIVE_GOLD: int = 0

## 声望商店折扣（声望/最大声望 * 折扣比例）
const PRESTIGE_DISCOUNT_RATE: float = 0.2

## ============ 平衡参数 ============

## 目标：每天纯收益（购买后剩余）应保持正增长
## Day 1 目标收入: ~30 gold
## Day 5 目标收入: ~50 gold
## Day 10 目标收入: ~80 gold

## 最大商品价格上限（防止通胀）
const MAX_ITEM_PRICE: int = 200

## 稀有度解锁天数（商店物品最大稀有度）
## Day 1: 普通, Day 2-3: 稀有, Day 4-5: 史诗, Day 6+: 传说
const RARITY_UNLOCK_DAYS: Array[int] = [0, 1, 2, 4, 6]

## ============ 核心方法 ============

static func _resolve_multiplier(source: Dictionary, key: int) -> float:
	return float(source.get(key, 1.0))

## 计算物品价格（基于稀有度、尺寸、类型、天数）
static func calculate_item_price(item_rarity: int, item_size: int, item_type: int, day: int) -> int:
	day = maxi(day, 1)
	if item_rarity < 1 or item_rarity > 4:
		return 10

	var price: int = ITEM_BASE_PRICES[item_rarity]
	price = int(float(price) * _resolve_multiplier(SIZE_PRICE_MULTIPLIER, item_size))
	price = int(float(price) * _resolve_multiplier(TYPE_PRICE_MULTIPLIER, item_type))
	price = int(float(price) * (1.0 + day * 0.05))
	price = mini(price, MAX_ITEM_PRICE)
	price = maxi(price, 5)
	return price

## 计算怪物战斗预期收入
static func calculate_monster_gold(day: int) -> int:
	return MONSTER_GOLD_BASE + maxi(day, 1) * MONSTER_GOLD_DAY_SCALE

## 计算 PvP 胜利预期收入
static func calculate_pvp_gold(day: int) -> int:
	return PVP_WIN_GOLD_BASE + maxi(day, 1) * PVP_WIN_GOLD_DAY_SCALE

## 计算声望折扣价格
static func apply_prestige_discount(base_price: int, prestige: int, max_prestige: int) -> int:
	if max_prestige <= 0:
		return base_price
	var clamped_prestige: int = clampi(prestige, 0, max_prestige)
	var discount_ratio: float = float(clamped_prestige) / float(max_prestige) * PRESTIGE_DISCOUNT_RATE
	var discount: int = int(float(base_price) * discount_ratio)
	return maxi(base_price - discount, 1)

## 获取商店物品数量范围
static func get_shop_item_count(day: int) -> Dictionary:
	var min_items: int = 3
	var max_items: int = 6
	# 后期商店物品略多
	if day >= 5:
		max_items = 8
	return {"min": min_items, "max": max_items}

## 获取最大稀有度
static func get_max_rarity(day: int) -> int:
	var safe_day := maxi(day, 1)
	for rarity in range(RARITY_UNLOCK_DAYS.size() - 1, 0, -1):
		if safe_day >= RARITY_UNLOCK_DAYS[rarity]:
			return rarity
	return 1

## 验证经济平衡（调试用）
static func debug_economy_balance(day: int, gold: int) -> String:
	var monster_gold = calculate_monster_gold(day)
	var pvp_gold = calculate_pvp_gold(day)
	var avg_item_price = calculate_item_price(2, 0, 0, day)  # 稀有小武器
	return "Day %d 经济分析:\n  怪物收入: %d gold/次\n  PvP收入: %d gold/次\n  稀有武器价: %d gold\n  当前金币: %d\n" % [
		day,
		monster_gold,
		pvp_gold,
		avg_item_price,
		gold
	]
