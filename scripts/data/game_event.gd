class_name GameEvent
extends RefCounted

## 游戏事件数据类 — 描述一个可触发的事件

## 事件ID
var event_id: String = ""

## 事件名称
var event_name: String = ""

## 事件描述
var event_description: String = ""

## 事件图标（用于 UI 显示）
var event_icon: String = ""

## 事件权重（影响随机出现概率，0=不随机出现）
var weight: int = 10

## 最低触发天数（0=任意天）
var min_day: int = 0

## 最高触发天数（0=无限制）
var max_day: int = 0

## 是否为特殊事件（Futura 等）
var is_special: bool = false

## 事件类型
enum EventType {
	SHOP,           ## 商人
	MONSTER,        ## 怪物战斗
	PVP,            ## PvP 对战
	RANDOM_EVENT,   ## 随机事件
	TREASURE,       ## 宝库
	CAMP,           ## 营地
	FUTURA,         ## Futura 事件（声望归零触发）
}

var event_type: EventType = EventType.RANDOM_EVENT

## 创建事件
static func create(id: String, name: String, icon: String, type: EventType, weight: int = 10) -> GameEvent:
	var event = GameEvent.new()
	event.event_id = id
	event.event_name = name
	event.event_icon = icon
	event.event_type = type
	event.weight = weight
	return event

func is_valid() -> bool:
	return not event_id.is_empty() and not event_name.is_empty()
