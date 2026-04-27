extends Node

## 游戏流程服务 - 从 main.gd 提取
## 职责：事件选项生成、事件选择、自动推进小时

const EventManagerClass = preload("res://scripts/data/event_manager.gd")

## 事件管理器引用（由main.gd注入）
var event_manager

## 当前事件选项（供handle_event_selection使用）
var _current_event_options: Array[Dictionary] = []
var _current_random_event_id: String = ""
var _current_selected_option: Dictionary = {}

## 信号：通知主UI刷新
signal event_options_generated(options: Array[Dictionary])
signal event_selected(option: Dictionary)

func _init() -> void:
	## 初始化时创建事件管理器实例
	event_manager = EventManagerClass.new()

func generate_event_options() -> Array[Dictionary]:
	## 生成随机事件选项，返回选项文本列表供main.gd显示
	var hour = RunStateService.current_hour
	var day = RunStateService.current_day
	var options: Array[Dictionary] = event_manager.generate_options(hour, day)
	_current_event_options = options
	_current_random_event_id = ""
	_current_selected_option = {}
	event_options_generated.emit(options)
	return options

func get_current_options() -> Array[Dictionary]:
	return _current_event_options

func handle_event_selection(index: int) -> Dictionary:
	## 处理事件选项选择，返回选中的option供main.gd执行
	if index < 0 or index >= _current_event_options.size():
		return {}
	var option: Dictionary = _current_event_options[index]
	_current_random_event_id = str(option.get("event_id", ""))
	_current_selected_option = option.duplicate(true)
	print("GameFlow: selected event %s" % option.get("text", ""))
	event_selected.emit(option)
	return option

func get_selected_event_id() -> String:
	return _current_random_event_id

func get_selected_option() -> Dictionary:
	return _current_selected_option.duplicate(true)

func get_event_type_at(index: int) -> String:
	if index < 0 or index >= _current_event_options.size():
		return "random_event"
	return str(_current_event_options[index].get("type", "random_event"))

func execute_random_event_fallback(day: int) -> Dictionary:
	## 当event_id为空时的fallback随机选择
	var evt = event_manager._pick_random_event(day)
	if evt.is_empty():
		return {}
	return evt
