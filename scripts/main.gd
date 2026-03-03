extends Control

## 主场景

## UI 节点
@onready var gold_label: Label = $VBox/GoldLabel
@onready var round_label: Label = $VBox/RoundLabel
@onready var backpack_panel: Control = $Backpack
@onready var shop_button: Button = $VBox/ButtonBox/ShopButton
@onready var battle_button: Button = $VBox/ButtonBox/BattleButton

## 背包 UI
var backpack_ui: Control

func _ready() -> void:
	_connect_signals()
	_update_ui()
	_setup_backpack()

## 连接信号
func _connect_signals() -> void:
	shop_button.pressed.connect(_on_shop_pressed)
	battle_button.pressed.connect(_on_battle_pressed)

## 更新 UI
func _update_ui() -> void:
	gold_label.text = "金币: %d" % GameManager.gold
	round_label.text = "回合: %d / %d" % [GameManager.current_round, GameManager.max_rounds]

## 设置背包
func _setup_backpack() -> void:
	backpack_ui = backpack_panel
	if backpack_ui and backpack_ui.has_method("add_test_items"):
		backpack_ui.add_test_items()

## 商店按钮
func _on_shop_pressed() -> void:
	print("打开商店")

## 战斗按钮
func _on_battle_pressed() -> void:
	print("开始战斗")
	_calculate_stats()

## 计算属性（背包中所有物品加成）
func _calculate_stats() -> void:
	if backpack_ui and "backpack" in backpack_ui:
		var backpack = backpack_ui.backpack
		var total_attack = backpack.get_total_attack()
		var total_defense = backpack.get_total_defense()
		print("总攻击力: %d, 总防御力: %d" % [total_attack, total_defense])
