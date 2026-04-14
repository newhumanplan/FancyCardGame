class_name EndingManager
extends RefCounted

## 终局管理器 — 处理最终Boss战和结局判定

## 结局类型
enum EndingType {
	VICTORY,           ## 胜利结局：10场PvP胜利
	DEFEAT,            ## 失败结局：声望第二次归零
	PERFECT,           ## 完美结局：满声望通关
	SPEEDRUN,          ## 速通结局：10天以内通关
	SURVIVOR,          ## 生存结局：存活30天以上
}

## 游戏结束数据
var ending_type: EndingType = EndingType.VICTORY
var days_survived: int = 1
var total_gold: int = 0
var pvp_wins: int = 0
var pvp_losses: int = 0
var total_battles: int = 0
var prestige_at_end: int = 0

static func _has_victory(game_manager: Node) -> bool:
	return game_manager != null and game_manager.pvp_wins >= 10

## 判断结局类型
static func determine_ending(game_manager: Node) -> EndingType:
	if game_manager == null:
		return EndingType.DEFEAT
	if _has_victory(game_manager) and game_manager.prestige >= game_manager.max_prestige:
		return EndingType.PERFECT
	elif _has_victory(game_manager) and game_manager.current_day <= 10:
		return EndingType.SPEEDRUN
	elif _has_victory(game_manager) and game_manager.current_day > 30:
		return EndingType.SURVIVOR
	elif _has_victory(game_manager):
		return EndingType.VICTORY
	else:
		return EndingType.DEFEAT

## 获取结局描述
static func get_ending_description(ending: EndingType) -> String:
	match ending:
		EndingType.VICTORY: return "🎉 胜利! 你成功击败了所有对手，成为了大巴扎的传奇英雄!"
		EndingType.DEFEAT: return "💀 失败... 你的声望尽失，大巴扎不再欢迎你。"
		EndingType.PERFECT: return "🏆 完美通关! 以满声望的姿态称霸大巴扎，无人能敌!"
		EndingType.SPEEDRUN: return "⚡ 速通大师! 仅用10天就征服了所有对手!"
		EndingType.SURVIVOR: return "🛡️ 坚韧不拔! 在大巴扎存活30天以上并取得胜利，真正的幸存者!"
		_: return "游戏结束"

## 获取结局标题
static func get_ending_title(ending: EndingType) -> String:
	match ending:
		EndingType.VICTORY: return "传奇英雄"
		EndingType.DEFEAT: return "黯然离场"
		EndingType.PERFECT: return "无冕之王"
		EndingType.SPEEDRUN: return "闪电征服者"
		EndingType.SURVIVOR: return "永恒守卫"
		_: return "游戏结束"

## 生成结算统计文本
static func generate_summary(game_manager: Node, ending: EndingType) -> String:
	if game_manager == null:
		return get_ending_description(ending)
	var title = get_ending_title(ending)
	var desc = get_ending_description(ending)
	var summary = "%s\n\n%s\n\n" % [title, desc]
	summary += "═══ 战绩总结 ═══\n"
	summary += "存活天数: %d\n" % game_manager.current_day
	summary += "PvP胜场: %d/10\n" % game_manager.pvp_wins
	summary += "总胜利: %d\n" % game_manager.stats_total_wins
	summary += "总失败: %d\n" % game_manager.stats_total_losses
	summary += "总金币: %d\n" % game_manager.stats_total_gold_earned
	summary += "最终声望: %d/%d\n" % [game_manager.prestige, game_manager.max_prestige]

	if ending == EndingType.PERFECT:
		summary += "\n⭐ 获得成就: 完美通关!"
	elif ending == EndingType.SPEEDRUN:
		summary += "\n⭐ 获得成就: 速通大师!"
	elif ending == EndingType.SURVIVOR:
		summary += "\n⭐ 获得成就: 坚韧不拔!"

	return summary

## 从游戏管理器收集结束数据
func collect_data(game_manager: Node) -> void:
	ending_type = determine_ending(game_manager)
	days_survived = game_manager.current_day
	total_gold = game_manager.stats_total_gold_earned
	pvp_wins = game_manager.pvp_wins
	pvp_losses = game_manager.losses
	total_battles = game_manager.stats_total_battles
	prestige_at_end = game_manager.prestige
