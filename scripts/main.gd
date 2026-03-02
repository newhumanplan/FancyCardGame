extends Control

## 主场景脚本
## 负责初始化游戏并管理场景切换

## 引用 Combat 系统节点
@onready var combat_system: Node = $CombatSystem
@onready var start_button: Button = $VBox/StartButton
@onready var shop_button: Button = $VBox/ShopButton
@onready var status_label: Label = $VBox/StatusLabel
@onready var gold_label: Label = $VBox/GoldLabel

## 预加载场景
var combat_scene: PackedScene
var character_panel_scene: PackedScene
var shop_scene: PackedScene

## 背包和装备
var inventory: Inventory
var equipment: Equipment
var shop: Shop

## 角色面板实例
var character_panel = null
var shop_ui = null

func _ready() -> void:
	# 加载场景
	combat_scene = load("res://scenes/combat.tscn")
	character_panel_scene = load("res://scenes/character_panel.tscn")
	shop_scene = load("res://scenes/shop.tscn")
	
	# 初始化背包和装备
	inventory = Inventory.new()
	equipment = Equipment.new()
	shop = Shop.new()
	add_child(shop)
	
	# 初始化金币（战士初始金币 100）
	GoldManager.reset()
	_update_gold_display()
	
	# 连接金币变化信号
	GoldManager.gold_changed.connect(_on_gold_changed)
	
	# 添加初始装备（战士：铁剑 + 皮甲）
	_add_initial_items()
	
	# 连接按钮信号
	start_button.pressed.connect(_on_start_button_pressed)
	shop_button.pressed.connect(_on_shop_button_pressed)
	
	# 创建角色面板
	_create_character_panel()
	
	# 创建商店 UI（隐藏）
	_create_shop_ui()
	
	print("FancyCardGame 已就绪！")
	status_label.text = "点击上方按钮开始战斗"

## 添加初始物品
func _add_initial_items() -> void:
	# 铁剑
	var iron_sword = Weapon.new("铁剑", 10, 1)
	iron_sword.icon_path = "res://assets/items/iron_sword.png"
	iron_sword.description = "新手战士的标准武器"
	inventory.add_item(iron_sword)
	equipment.equip_item(iron_sword)
	
	# 皮甲
	var leather_armor = Armor.new("皮甲", 5, 1)
	leather_armor.icon_path = "res://assets/items/leather_armor.png"
	leather_armor.description = "提供基本防护的皮制护甲"
	inventory.add_item(leather_armor)
	equipment.equip_item(leather_armor)
	
	# 治疗药水
	var health_potion = Consumable.new("治疗药水", 30, 3, 1)
	health_potion.icon_path = "res://assets/items/health_potion.png"
	health_potion.description = "恢复 30 点生命值"
	inventory.add_item(health_potion)
	
	# 匕首
	var dagger = Weapon.new("匕首", 6, 1)
	dagger.icon_path = "res://assets/items/dagger.png"
	dagger.description = "轻便的副手武器"
	inventory.add_item(dagger)
	
	print("已添加初始物品")
	print(inventory.get_inventory_info())

## 创建角色面板
func _create_character_panel() -> void:
	character_panel = character_panel_scene.instantiate()
	add_child(character_panel)
	character_panel.set_equipment(equipment)
	character_panel.set_inventory(inventory)
	
	# 放置在右侧
	character_panel.position = Vector2(600, 100)

## 创建商店 UI
func _create_shop_ui() -> void:
	shop_ui = shop_scene.instantiate()
	add_child(shop_ui)
	shop_ui.set_data(shop, inventory, GoldManager)
	shop_ui.visible = false
	
	# 连接商店关闭信号
	if shop_ui.has_signal("shop_closed"):
		shop_ui.shop_closed.connect(_on_shop_closed)

## 开始战斗按钮回调
func _on_start_button_pressed() -> void:
	# 创建测试单位：战士 vs 史莱姆
	var warrior = Unit.new("战士", 120, 15, 8, 10, 0.1, 1.5)
	var slime = Unit.new("史莱姆", 80, 8, 3, 5, 0.05, 1.5)
	
	print("初始化战斗: %s vs %s" % [warrior.name, slime.name])
	status_label.text = "战斗进行中..."
	
	# 切换到战斗场景
	_change_to_combat(warrior, slime)

## 商店按钮回调
func _on_shop_button_pressed() -> void:
	_open_shop()

## 打开商店
func _open_shop() -> void:
	if shop_ui:
		shop_ui.visible = true
		shop_ui.refresh()
		# 隐藏其他 UI
		$VBox.visible = false
		character_panel.visible = false

## 商店关闭回调
func _on_shop_closed() -> void:
	# 显示主 UI
	$VBox.visible = true
	character_panel.visible = true

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
	character_panel.visible = false
	
	# 连接战斗结束信号
	combat_sys.combat_ended.connect(_on_combat_ended)

## 战斗结束回调
func _on_combat_ended(victory: bool) -> void:
	if victory:
		status_label.text = "🎉 胜利！"
		# 战斗胜利后打开商店
		await get_tree().create_timer(1.0).timeout
		_open_shop()
	else:
		status_label.text = "💀 失败..."
		# 显示主 UI
		$VBox.visible = true
		character_panel.visible = true

## 金币变化回调
func _on_gold_changed(_amount: int) -> void:
	_update_gold_display()

## 更新金币显示
func _update_gold_display() -> void:
	gold_label.text = "金币: %d" % GoldManager.get_gold()
