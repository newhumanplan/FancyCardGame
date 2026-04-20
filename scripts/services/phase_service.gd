extends Node

## PhaseService - 统一阶段规则
## 所有 hour-based 阶段判断集中在此，避免散落

## 阶段常量: 0=采购, 1=采购, 2=打怪, 3=采购, 4=PvP
const PHASE_SHOP: int = 0
const PHASE_MONSTER: int = 2
const PHASE_PVP: int = 4

func get_current_phase_name(hour: int) -> String:
	var h = hour % 5
	match h:
		0: return "采购阶段"
		1: return "采购阶段"
		2: return "战斗阶段"
		3: return "采购阶段"
		4: return "PvP阶段"
	return "未知"

func can_shop(hour: int) -> bool:
	return (hour % 5) in [PHASE_SHOP, 1, 3]

func can_battle(hour: int) -> bool:
	return (hour % 5) == PHASE_MONSTER

func is_pvp_phase(hour: int) -> bool:
	return (hour % 5) == PHASE_PVP

func get_phase_color(hour: int) -> Color:
	match hour % 5:
		0, 1, 3: return Color(0.2, 0.5, 0.8, 1.0)  # 蓝-采购
		2: return Color(0.8, 0.3, 0.2, 1.0)           # 红-战斗
		4: return Color(0.8, 0.7, 0.2, 1.0)           # 金-PvP
	return Color.WHITE
