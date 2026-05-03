class_name ItemData
extends Resource

const MIN_ITEM_COOLDOWN: float = 1.0

## 物品尺寸枚举
enum Size { SMALL, MEDIUM, LARGE }

## 物品类型枚举
enum Type { WEAPON, SHIELD, HEAL, UTILITY }

## ============ 保留属性 ============

## 物品名称
@export var item_name: String = "物品"
var base_item_name: String = "物品"

## 物品描述
@export var description: String = ""

## 稀有度 (1-4: 普通/稀有/史诗/传说)
@export var rarity: int = 1

## 购买价格
@export var buy_price: int = 10

## 外部数据源 ID（用于 Wiki/真实数据对齐）
@export var source_id: String = ""

## Wiki 原始效果文本（用于 tooltip 和验收对照）
@export_multiline var source_effect_text: String = ""

## 当前附魔的规范化 ID。空字符串表示未附魔。
@export var enchantment_id: String = ""

## 物品标签（Weapon/Potion/Reagent/Burn/Poison 等）
@export var tags: Array[String] = []

## ============ 修改/新增属性 ============

## 物品尺寸
@export var size: Size = Size.SMALL

## 物品类型
@export var type: Type = Type.WEAPON

## 当前槽位索引（运行时）
var slot_index: int = -1

## 当前冷却进度（运行时）
var current_cooldown: float = 0.0

## ============ 战斗属性 ============

## 攻击力/伤害
@export var damage: int = 0

## 护盾值
@export var shield: int = 0

## 治疗值
@export var heal: int = 0

## 冷却时间
@export var cooldown: float = 5.0

## 最大弹药。0 表示无弹药限制。
@export var ammo: int = 0

## 当前弹药（运行时）。-1 表示尚未进入战斗初始化。
var current_ammo: int = -1

## 当前战斗的有效最大弹药（运行时）。用于处理临近物品增加 Ammo 的效果。
var current_max_ammo: int = -1

## 暴击几率
@export var crit_chance: float = 0.05

## 标准化战斗效果定义（Trigger / Condition / Target / Effect）。
@export var effects: Array[Dictionary] = []

## ============ 特殊效果 ============

## 中毒：状态叠层。每秒造成等同层数的伤害，忽略护盾。
@export var poison_damage: float = 0.0

## 燃烧：状态叠层。每 0.5 秒造成等同层数的伤害，结算后层数 -1。
@export var burn_damage: float = 0.0

## 再生：状态叠层。每秒治疗，并在中毒结算前抵消等量中毒。
@export var regeneration: float = 0.0

## 眩晕：暂停冷却（秒）
@export var stun_duration: float = 0.0

## 减速：影响敌方物品冷却的数量与时长。
@export var slow_count: int = 0
@export var slow_duration: float = 0.0

## 冻结：影响敌方物品冷却的数量与时长。
@export var freeze_count: int = 0
@export var freeze_duration: float = 0.0

## 急速：影响己方物品冷却的数量与时长。
@export var haste_count: int = 0
@export var haste_duration: float = 0.0

## 免疫：免疫控制效果
@export var is_immune: bool = false

## 由 Effect DSL 构建阶段收集的显式告警，避免静默丢失效果语义。
var effect_warnings: Array[String] = []

## ============ 运行时方法 ============

## 获取物品占用的槽位数量
func get_slot_count() -> int:
	match size:
		Size.SMALL: return 1
		Size.MEDIUM: return 2
		Size.LARGE: return 3
	return 1

## 检查是否可以触发（冷却是否完毕）
func can_trigger() -> bool:
	return current_cooldown <= 0

## 重置冷却
func reset_cooldown():
	current_cooldown = maxf(cooldown, MIN_ITEM_COOLDOWN) if cooldown > 0.0 else 0.0

## 当前是否受弹药限制
func has_ammo_limit() -> bool:
	return get_max_ammo() > 0

## 获取当前战斗的最大弹药
func get_max_ammo() -> int:
	if current_max_ammo >= 0:
		return current_max_ammo
	return maxi(ammo, 0)

## 开战或重新装填时设置当前弹药
func reset_ammo(max_ammo_override: int = -1) -> void:
	current_max_ammo = maxi(max_ammo_override, 0) if max_ammo_override >= 0 else maxi(ammo, 0)
	current_ammo = current_max_ammo

## 离开战斗时清理运行时弹药状态
func clear_runtime_ammo() -> void:
	current_ammo = -1
	current_max_ammo = -1

## 获取当前弹药。尚未初始化时按当前最大弹药懒初始化。
func get_current_ammo() -> int:
	if not has_ammo_limit():
		return 0
	if current_ammo < 0:
		reset_ammo(get_max_ammo())
	return current_ammo

## 弹药是否足以触发一次冷却完成后的使用
func can_pay_ammo() -> bool:
	return not has_ammo_limit() or get_current_ammo() > 0

## 消耗一次弹药。无弹药限制的物品视为消耗成功。
func consume_ammo(amount: int = 1) -> bool:
	if not has_ammo_limit():
		return true
	var cost: int = maxi(amount, 1)
	if get_current_ammo() < cost:
		return false
	current_ammo = maxi(current_ammo - cost, 0)
	return true

## 补充弹药，不能超过当前战斗最大弹药。
func refill_ammo(amount: int = 1) -> int:
	if not has_ammo_limit():
		return 0
	var before: int = get_current_ammo()
	current_ammo = clampi(before + maxi(amount, 0), 0, get_max_ammo())
	return current_ammo - before

## ============ 工具方法 ============

## 获取稀有度名称
func get_rarity_name() -> String:
	match rarity:
		1: return "普通"
		2: return "稀有"
		3: return "史诗"
		4: return "传说"
		_: return "未知"

## 获取稀有度颜色
func get_rarity_color() -> Color:
	match rarity:
		1: return Color.GRAY
		2: return Color.GREEN
		3: return Color.PURPLE
		4: return Color.ORANGE
		_: return Color.WHITE

## 获取类型名称
func get_type_name() -> String:
	match type:
		Type.WEAPON: return "武器"
		Type.SHIELD: return "护盾"
		Type.HEAL: return "治疗"
		Type.UTILITY: return "辅助"
		_: return "未知"

## 获取尺寸文本
func get_size_text() -> String:
	match size:
		Size.SMALL: return "小"
		Size.MEDIUM: return "中"
		Size.LARGE: return "大"
		_: return "未知"

## 获取稀有度属性倍率。
## Wiki 数据已经按 Bronze/Silver/Gold/Diamond 分档写入，运行时不再二次放大。
func get_rarity_multiplier() -> float:
	return 1.0

## 获取按尺寸建议的 CD 范围
## Small: 2.0-3.0s, Medium: 3.0-5.0s, Large: 5.0-8.0s
func get_size_cd_range() -> Dictionary:
	match size:
		Size.SMALL: return {"min": 2.0, "max": 3.0}
		Size.MEDIUM: return {"min": 3.0, "max": 5.0}
		Size.LARGE: return {"min": 5.0, "max": 8.0}
		_: return {"min": 2.0, "max": 8.0}

## 应用稀有度加成到属性
func get_rarity_adjusted_damage() -> int:
	return maxi(damage, 0)

func get_rarity_adjusted_shield() -> int:
	return maxi(shield, 0)

func get_rarity_adjusted_heal() -> int:
	return maxi(heal, 0)

## 是否有特殊效果
func has_special_effect() -> bool:
	return poison_damage > 0 or burn_damage > 0 or regeneration > 0 or stun_duration > 0 or slow_count > 0 or freeze_count > 0 or haste_count > 0 or is_immune

## 获取特殊效果描述
func get_special_effect_description() -> String:
	var effects: Array[String] = []
	if poison_damage > 0:
		effects.append("中毒 +%.0f" % poison_damage)
	if burn_damage > 0:
		effects.append("燃烧 +%.0f" % burn_damage)
	if regeneration > 0:
		effects.append("再生 +%.0f" % regeneration)
	if stun_duration > 0:
		effects.append("眩晕(%.1fs)" % stun_duration)
	if slow_count > 0:
		effects.append("减速 %d件(%.1fs)" % [slow_count, slow_duration])
	if freeze_count > 0:
		effects.append("冻结 %d件(%.1fs)" % [freeze_count, freeze_duration])
	if haste_count > 0:
		effects.append("急速 %d件(%.1fs)" % [haste_count, haste_duration])
	if is_immune:
		effects.append("免疫控制")
	return ", ".join(effects)
