extends Control

## 主场景脚本
## 负责初始化游戏并管理场景切换

## 引用 Combat 系统节点
@onready var combat_system: Node = $CombatSystem
@onready var start_button: Button = $VBox/StartButton
@onready var status_label: Label = $VBox/StatusLabel

## 预加载战斗场景
var combat_scene: PackedScene

func _ready() -> void:
	# 加载战斗场景
	combat_scene = load("res://scenes/combat.tscn")
	
	# 连接开始按钮信号
	start_button.pressed.connect(_on_start_button_pressed)
	
	print("FancyCardGame 已就绪！")
	status_label.text = "点击上方按钮开始战斗"

## 开始战斗按钮回调
func _on_start_button_pressed() -> void:
	# 创建测试单位：战士 vs 史莱姆
	var warrior = Unit.new("战士", 120, 15, 8, 10, 0.1, 1.5)
	var slime = Unit.new("史莱姆", 80, 8, 3, 5, 0.05, 1.5)
	
	print("初始化战斗: %s vs %s" % [warrior.name, slime.name])
	status_label.text = "战斗进行中..."
	
	# 切换到战斗场景
	_change_to_combat(warrior, slime)

## 切换到战斗场景
func _change_to_combat(player: Unit, enemy: Unit) -> void:
	# 实例化战斗场景
	var combat = combat_scene.instantiate()
	
	# 添加到当前场景
	add_child(combat)
	
	# 获取 CombatUI 节点并初始化
	var combat_ui = combat.get_node("CombatUI")
	var combat_sys = combat.get_node("CombatSystem")
	
	# 先初始化 UI（连接信号）
	combat_ui.init(combat_sys, player, enemy)
	# 再初始化战斗系统（会触发信号）
	combat_sys.init_combat(player, enemy)
	
	# 隐藏主 UI
	$VBox.visible = false
	
	# 连接战斗结束信号
	combat_sys.combat_ended.connect(_on_combat_ended)

## 战斗结束回调
func _on_combat_ended(victory: bool) -> void:
	if victory:
		status_label.text = "🎉 胜利！"
	else:
		status_label.text = "💀 失败..."
	
	# 显示主 UI
	$VBox.visible = true
	
	# 延迟后重新加载场景（清除战斗状态）
	await get_tree().create_timer(2.0).timeout
	get_tree().reload_current_scene()
