extends Control

## 主场景

## UI 节点
@onready var gold_label: Label = $VBox/GoldLabel
@onready var round_label: Label = $VBox/RoundLabel
@onready var inventory_ui: Control = $InventoryUI
@onready var shop_button: Button = $VBox/ButtonBox/ShopButton
@onready var battle_button: Button = $VBox/ButtonBox/BattleButton

## 背包 UI
var backpack_ui: Control

func _ready() -> void:
	_connect_signals()
	_update_ui()
	_setup_inventory()

## 连接信号
func _connect_signals() -> void:
	shop_button.pressed.connect(_on_shop_pressed)
	battle_button.pressed.connect(_on_battle_pressed)

## 更新 UI
func _update_ui() -> void:
	gold_label.text = "金币: %d" % GameManager.gold
	round_label.text = "回合: %d / %d" % [GameManager.current_round, GameManager.max_rounds]

## 设置背包
func _setup_inventory() -> void:
	backpack_ui = inventory_ui
	# InventoryUI 已经在 _ready 中添加了测试物品

## 商店按钮
func _on_shop_pressed() -> void:
	print("打开商店")

## 战斗按钮
func _on_battle_pressed() -> void:
	print("开始战斗")
	_calculate_stats()

## 计算属性（背包中所有物品加成）
func _calculate_stats() -> void:
	if backpack_ui and backpack_ui.has_method("get_inventory"):
		var inventory = backpack_ui.get_inventory()
		var total_damage = 0
		var total_shield = 0
		var total_heal = 0
		for item in inventory.items:
			total_damage += item.damage
			total_shield += item.shield
			total_heal += item.heal
		print("总攻击力: %d, 总防御力: %d, 总治疗: %d" % [total_damage, total_shield, total_heal])
