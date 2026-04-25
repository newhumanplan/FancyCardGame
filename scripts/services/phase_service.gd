extends Node

## PhaseService - 统一阶段规则
## 所有 hour-based 阶段判断集中在此，避免散落

const MAX_HOURS_PER_DAY: int = 6

## 阶段常量: 0/1/3/4=构筑, 2=PvE, 5=PvP
const PHASE_SHOP_A: int = 0
const PHASE_SHOP_B: int = 1
const PHASE_PVE: int = 2
const PHASE_SHOP_C: int = 3
const PHASE_SHOP_D: int = 4
const PHASE_PVP: int = 5

func get_hour_index(hour: int) -> int:
	return posmod(hour, MAX_HOURS_PER_DAY)

func get_current_phase_name(hour: int) -> String:
	var h: int = get_hour_index(hour)
	match h:
		PHASE_SHOP_A: return "构筑阶段"
		PHASE_SHOP_B: return "构筑阶段"
		PHASE_PVE: return "PvE战斗"
		PHASE_SHOP_C: return "构筑阶段"
		PHASE_SHOP_D: return "构筑阶段"
		PHASE_PVP: return "PvP战斗"
	return "未知"

func can_shop(hour: int) -> bool:
	var h: int = get_hour_index(hour)
	return h == PHASE_SHOP_A or h == PHASE_SHOP_B or h == PHASE_SHOP_C or h == PHASE_SHOP_D

func can_battle(hour: int) -> bool:
	return is_pve_phase(hour) or is_pvp_phase(hour)

func is_pve_phase(hour: int) -> bool:
	return get_hour_index(hour) == PHASE_PVE

func is_pvp_phase(hour: int) -> bool:
	return get_hour_index(hour) == PHASE_PVP

func get_phase_color(hour: int) -> Color:
	match get_hour_index(hour):
		PHASE_SHOP_A, PHASE_SHOP_B, PHASE_SHOP_C, PHASE_SHOP_D:
			return Color(0.2, 0.5, 0.8, 1.0)
		PHASE_PVE:
			return Color(0.8, 0.3, 0.2, 1.0)
		PHASE_PVP:
			return Color(0.8, 0.7, 0.2, 1.0)
	return Color.WHITE
